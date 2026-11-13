import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/xboard/core/core.dart';

final _logger = FileLogger('ip_quality_service.dart');

/// IP 质量等级（基于出口 IP 的风险画像，与延迟无关）
enum IpQualityLevel {
  /// 未评估
  unknown,

  /// 差：被标记为代理 / VPN / 滥用
  poor,

  /// 一般：机房 IP 且带风险标记
  fair,

  /// 良：机房 IP，未被标记
  good,

  /// 优：原生干净 IP
  excellent,
}

/// IP 归属类型，对应上游「商业」这类标签
enum IpUsageType {
  unknown('未知'),
  residential('住宅'),
  business('商业'),
  hosting('机房'),
  mobile('移动'),
  education('教育'),
  government('政府');

  const IpUsageType(this.label);

  final String label;
}

/// 一次出口 IP 质量评估结果
class IpQuality {
  const IpQuality({
    required this.level,
    required this.usage,
    required this.score,
    this.ip,
    this.countryCode,
    this.asnOrg,
    this.isDatacenter = false,
    this.isProxy = false,
    this.checkedAt,
  });

  final IpQualityLevel level;
  final IpUsageType usage;

  /// 综合评分 0~100
  final int score;

  final String? ip;
  final String? countryCode;
  final String? asnOrg;

  /// 数据中心 / 机房 IP
  final bool isDatacenter;

  /// 被识别为代理或 VPN
  final bool isProxy;

  final DateTime? checkedAt;

  bool get isKnown => level != IpQualityLevel.unknown;

  String get levelLabel => switch (level) {
        IpQualityLevel.excellent => '质量优',
        IpQualityLevel.good => '质量良',
        IpQualityLevel.fair => '质量一般',
        IpQualityLevel.poor => '质量差',
        IpQualityLevel.unknown => '质量评估中',
      };

  String get usageLabel => usage.label;

  static const unknown = IpQuality(
    level: IpQualityLevel.unknown,
    usage: IpUsageType.unknown,
    score: 0,
  );

  @override
  String toString() => 'IpQuality(${level.name}, ${usage.name}, score=$score, '
      'ip=$ip, dc=$isDatacenter, proxy=$isProxy)';
}

class _IpQualityCacheEntry {
  const _IpQualityCacheEntry(this.quality, this.time);

  final IpQuality quality;
  final DateTime time;
}

/// 出口 IP 质量评估。
///
/// 连接成功后走当前节点请求 IP 画像接口，拿到出口 IP 的风险标记
/// （机房 / 代理 / VPN），据此给出「质量优 / 良 / 一般 / 差」。
class IpQualityService {
  static final IpQualityService _instance = IpQualityService._internal();

  factory IpQualityService() => _instance;

  IpQualityService._internal();

  static const Duration _cacheTtl = Duration(minutes: 5);
  static const Duration _timeout = Duration(seconds: 12);

  /// 主源：字段最实用（proxy / hosting / mobile / asn），体积小、无需 key
  static const String _primaryUrl =
      'http://ip-api.com/json/?fields=status,country,countryCode,isp,org,as,'
      'proxy,hosting,mobile,query';

  /// 备用源：HTTPS，只有归属信息，没有风险标记
  static const String _fallbackUrl = 'https://ipwho.is/';

  /// 机房 / 云厂商 / IDC 关键词
  static const List<String> _hostingHints = [
    'idc',
    'cloud',
    'hosting',
    'host',
    'server',
    'datacenter',
    'data center',
    'vps',
    'colo',
    'cdn',
    'amazon',
    'aws',
    'google',
    'microsoft',
    'azure',
    'oracle',
    'digitalocean',
    'linode',
    'vultr',
    'ovh',
    'hetzner',
    'contabo',
    'leaseweb',
    'm247',
    'alibaba',
    'aliyun',
    'tencent',
    'huawei',
    'cloudflare',
    'akamai',
    'fastly',
    'choopa',
    'racknerd',
    'virmach',
    'sharktech',
    'psychz',
    'colocrossing',
    'bandwagon',
    'hosthatch',
    'equinix',
    'serverius',
    'worldstream',
    'zenlayer',
    'gcore',
    'kamatera',
  ];

  /// 运营商 / 家宽关键词
  static const List<String> _ispHints = [
    'telecom',
    'telecommunication',
    'communications',
    'broadband',
    'cable',
    'fiber',
    'fibre',
    'network',
    'internet',
    'comcast',
    'verizon',
    'chinanet',
    'unicom',
    'kddi',
    'softbank',
    'ntt',
    'sk broadband',
    'singtel',
    'viettel',
    'vnpt',
    'fpt',
    'telkom',
    'indihome',
    'globe',
    'pldt',
    'maxis',
    'digi',
    'optus',
    'telstra',
    'vodafone',
    'telefonica',
    'swisscom',
    'kpn',
    'telia',
    'telenor',
    'rogers',
    'telus',
    'true internet',
    'ais fibre',
  ];

  /// 移动网络关键词
  static const List<String> _mobileHints = [
    'mobile',
    'cellular',
    'wireless',
    'lte',
    '4g',
    '5g',
    'gsm',
  ];

  final Map<String, _IpQualityCacheEntry> _cache = {};
  final Map<String, Future<IpQuality>> _inflight = {};

  IpQuality? peek(String proxyName) {
    final entry = _cache[proxyName];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.time) > _cacheTtl) {
      _cache.remove(proxyName);
      return null;
    }
    return entry.quality;
  }

  Future<IpQuality> evaluate(String proxyName, {bool force = false}) {
    if (proxyName.isEmpty) {
      return Future.value(IpQuality.unknown);
    }

    if (!force) {
      final cached = peek(proxyName);
      if (cached != null) return Future.value(cached);
    }

    final running = _inflight[proxyName];
    if (running != null) return running;

    final future = _run(proxyName);
    _inflight[proxyName] = future;
    return future.whenComplete(() {
      _inflight.remove(proxyName);
    });
  }

  void invalidate([String? proxyName]) {
    if (proxyName == null) {
      _cache.clear();
      return;
    }
    _cache.remove(proxyName);
  }

  Future<IpQuality> _run(String proxyName) async {
    var quality = await _queryPrimary(proxyName);
    if (!quality.isKnown) {
      _logger.debug('主源评估失败，尝试备用源: $proxyName');
      quality = await _queryFallback(proxyName);
    }
    if (quality.isKnown) {
      _cache[proxyName] = _IpQualityCacheEntry(quality, DateTime.now());
    }
    _logger.debug('出口 IP 质量评估完成 $proxyName -> $quality');
    return quality;
  }

  Future<IpQuality> _queryPrimary(String proxyName) async {
    final body = await _fetch(proxyName, _primaryUrl);
    if (body == null) return IpQuality.unknown;
    try {
      final decoded = json.decode(body);
      if (decoded is! Map) return IpQuality.unknown;
      return _fromIpApiCom(decoded.cast<String, dynamic>());
    } catch (e) {
      _logger.debug('ip-api.com 解析失败: $e');
      return IpQuality.unknown;
    }
  }

  Future<IpQuality> _queryFallback(String proxyName) async {
    final body = await _fetch(proxyName, _fallbackUrl);
    if (body == null) return IpQuality.unknown;
    try {
      final decoded = json.decode(body);
      if (decoded is! Map) return IpQuality.unknown;
      return _fromIpWhoIs(decoded.cast<String, dynamic>());
    } catch (e) {
      _logger.debug('ipwho.is 解析失败: $e');
      return IpQuality.unknown;
    }
  }

  Future<String?> _fetch(String proxyName, String url) async {
    try {
      final result = await clashCore.outboundIp(
        proxyName: proxyName,
        urls: [url],
        timeout: _timeout,
      );
      if (result == null || result.error != null || result.body.isEmpty) {
        return null;
      }
      return result.body;
    } catch (e) {
      _logger.debug('出口 IP 请求失败: $e');
      return null;
    }
  }

  IpQuality _fromIpApiCom(Map<String, dynamic> json) {
    if (_string(json['status']) == 'fail') return IpQuality.unknown;

    final isDatacenter = json['hosting'] == true;
    final isProxy = json['proxy'] == true;
    final isMobile = json['mobile'] == true;

    final orgText = [
      _string(json['org']),
      _string(json['isp']),
      _string(json['as']),
    ].whereType<String>().join(' ');

    final usage = _guessUsage(
      text: orgText,
      isMobile: isMobile,
      isDatacenter: isDatacenter,
    );

    final score = _score(
      usage: usage,
      isDatacenter: isDatacenter,
      isProxy: isProxy,
    );

    return IpQuality(
      level: _levelOf(score),
      usage: usage,
      score: score,
      ip: _string(json['query']),
      countryCode: _string(json['countryCode']),
      asnOrg: _string(json['org']) ?? _string(json['isp']),
      isDatacenter: isDatacenter || usage == IpUsageType.hosting,
      isProxy: isProxy,
      checkedAt: DateTime.now(),
    );
  }

  IpQuality _fromIpWhoIs(Map<String, dynamic> json) {
    if (json['success'] == false) return IpQuality.unknown;

    final connection = _map(json['connection']);
    final security = _map(json['security']);

    final orgText = [
      _string(connection?['org']),
      _string(connection?['isp']),
      _string(connection?['domain']),
    ].whereType<String>().join(' ');

    final isDatacenter = security?['hosting'] == true;
    final isProxy = security?['proxy'] == true ||
        security?['vpn'] == true ||
        security?['tor'] == true;

    final usage = _guessUsage(
      text: orgText,
      isMobile: false,
      isDatacenter: isDatacenter,
    );

    final score = _score(
      usage: usage,
      isDatacenter: isDatacenter,
      isProxy: isProxy,
    );

    return IpQuality(
      level: _levelOf(score),
      usage: usage,
      score: score,
      ip: _string(json['ip']),
      countryCode: _string(json['country_code']),
      asnOrg: _string(connection?['org']),
      isDatacenter: isDatacenter || usage == IpUsageType.hosting,
      isProxy: isProxy,
      checkedAt: DateTime.now(),
    );
  }

  /// 归属类型判定：移动 → 机房 → 住宅 → 商业（兜底，保证一定有标签）
  IpUsageType _guessUsage({
    required String text,
    required bool isMobile,
    required bool isDatacenter,
  }) {
    final lower = text.toLowerCase();
    if (isMobile || _containsAny(lower, _mobileHints)) {
      return IpUsageType.mobile;
    }
    if (isDatacenter || _containsAny(lower, _hostingHints)) {
      return IpUsageType.hosting;
    }
    if (_containsAny(lower, _ispHints)) {
      return IpUsageType.residential;
    }
    return IpUsageType.business;
  }

  bool _containsAny(String text, List<String> hints) {
    if (text.isEmpty) return false;
    for (final hint in hints) {
      if (text.contains(hint)) return true;
    }
    return false;
  }

  int _score({
    required IpUsageType usage,
    required bool isDatacenter,
    required bool isProxy,
  }) {
    var score = 100;
    if (isProxy) score -= 45;
    if (isDatacenter || usage == IpUsageType.hosting) score -= 10;
    return score.clamp(0, 100);
  }

  IpQualityLevel _levelOf(int score) {
    if (score >= 88) return IpQualityLevel.excellent;
    if (score >= 72) return IpQualityLevel.good;
    if (score >= 55) return IpQualityLevel.fair;
    return IpQualityLevel.poor;
  }

  Map<String, dynamic>? _map(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  String? _string(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }
}

final ipQualityService = IpQualityService();

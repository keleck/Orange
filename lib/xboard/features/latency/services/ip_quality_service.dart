import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/xboard/core/core.dart';

final _logger = FileLogger('ip_quality_service.dart');

/// IP 质量等级（基于出口 IP 的风险画像，与延迟无关）
enum IpQualityLevel {
  /// 未评估
  unknown,

  /// 差：被标记为滥用 / 代理 / Tor
  poor,

  /// 一般：VPN 出口或高风险段
  fair,

  /// 良：机房 IP，但未被标记
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
    this.isVpn = false,
    this.isAbuser = false,
    this.checkedAt,
  });

  final IpQualityLevel level;
  final IpUsageType usage;

  /// 综合评分 0~100
  final int score;

  final String? ip;
  final String? countryCode;
  final String? asnOrg;

  final bool isDatacenter;
  final bool isProxy;
  final bool isVpn;
  final bool isAbuser;

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

  static const unknown =
      IpQuality(level: IpQualityLevel.unknown, usage: IpUsageType.unknown, score: 0);

  @override
  String toString() => 'IpQuality(${level.name}, ${usage.name}, score=$score, '
      'ip=$ip, dc=$isDatacenter, proxy=$isProxy, vpn=$isVpn, abuser=$isAbuser)';
}

class _IpQualityCacheEntry {
  const _IpQualityCacheEntry(this.quality, this.time);

  final IpQuality quality;
  final DateTime time;
}

/// 出口 IP 质量评估。
///
/// 连接成功后走当前节点请求 IP 画像接口，拿到出口 IP 的风险标记
/// （机房 / 代理 / VPN / 滥用），据此给出「质量优 / 良 / 一般 / 差」。
class IpQualityService {
  static final IpQualityService _instance = IpQualityService._internal();

  factory IpQualityService() => _instance;

  IpQualityService._internal();

  static const Duration _cacheTtl = Duration(minutes: 5);
  static const Duration _timeout = Duration(seconds: 12);

  /// 主源：字段最全（is_datacenter / is_vpn / is_proxy / is_abuser / company.type）
  static const String _primaryUrl = 'https://api.ipapi.is/';

  /// 备用源：免费、体积小，只有 proxy / hosting / mobile 三个标记
  static const String _fallbackUrl =
      'http://ip-api.com/json/?fields=status,country,countryCode,isp,org,as,'
      'proxy,hosting,mobile,query';

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
    var quality = await _query(proxyName);
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

  Future<IpQuality> _query(String proxyName) async {
    final body = await _fetch(proxyName, _primaryUrl);
    if (body == null) return IpQuality.unknown;
    try {
      final decoded = json.decode(body);
      if (decoded is! Map) return IpQuality.unknown;
      return _fromIpApiIs(decoded.cast<String, dynamic>());
    } catch (e) {
      _logger.debug('ipapi.is 解析失败: $e');
      return IpQuality.unknown;
    }
  }

  Future<IpQuality> _queryFallback(String proxyName) async {
    final body = await _fetch(proxyName, _fallbackUrl);
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

  IpQuality _fromIpApiIs(Map<String, dynamic> json) {
    final company = _map(json['company']);
    final asn = _map(json['asn']);
    final location = _map(json['location']);

    final companyType = _string(company?['type']);
    final asnType = _string(asn?['type']);

    final isDatacenter = json['is_datacenter'] == true;
    final isAbuser = json['is_abuser'] == true;
    final isTor = json['is_tor'] == true;
    final isProxy = json['is_proxy'] == true || isTor;
    final isVpn = json['is_vpn'] == true;
    final isMobile = json['is_mobile'] == true;

    final usage = _resolveUsage(
      companyType: companyType,
      asnType: asnType,
      isMobile: isMobile,
      isDatacenter: isDatacenter,
    );

    final score = _score(
      isDatacenter: isDatacenter,
      isProxy: isProxy,
      isVpn: isVpn,
      isAbuser: isAbuser || isTor,
    );

    return IpQuality(
      level: _levelOf(score),
      usage: usage,
      score: score,
      ip: _string(json['ip']),
      countryCode: _string(location?['country_code']),
      asnOrg: _string(company?['name']) ?? _string(asn?['org']),
      isDatacenter: isDatacenter,
      isProxy: isProxy,
      isVpn: isVpn,
      isAbuser: isAbuser || isTor,
      checkedAt: DateTime.now(),
    );
  }

  IpQuality _fromIpApiCom(Map<String, dynamic> json) {
    if (_string(json['status']) == 'fail') return IpQuality.unknown;

    final isDatacenter = json['hosting'] == true;
    final isProxy = json['proxy'] == true;
    final isMobile = json['mobile'] == true;

    final usage = _resolveUsage(
      companyType: null,
      asnType: null,
      isMobile: isMobile,
      isDatacenter: isDatacenter,
    );

    final score = _score(
      isDatacenter: isDatacenter,
      isProxy: isProxy,
      isVpn: false,
      isAbuser: false,
    );

    return IpQuality(
      level: _levelOf(score),
      usage: usage,
      score: score,
      ip: _string(json['query']),
      countryCode: _string(json['countryCode']),
      asnOrg: _string(json['org']) ?? _string(json['isp']),
      isDatacenter: isDatacenter,
      isProxy: isProxy,
      checkedAt: DateTime.now(),
    );
  }

  IpUsageType _resolveUsage({
    required String? companyType,
    required String? asnType,
    required bool isMobile,
    required bool isDatacenter,
  }) {
    if (isMobile) return IpUsageType.mobile;
    final type = (companyType ?? asnType ?? '').toLowerCase();
    switch (type) {
      case 'hosting':
      case 'datacenter':
      case 'cloud':
        return IpUsageType.hosting;
      case 'business':
      case 'commercial':
        return IpUsageType.business;
      case 'education':
      case 'university':
        return IpUsageType.education;
      case 'government':
        return IpUsageType.government;
      case 'isp':
      case 'residential':
        return IpUsageType.residential;
    }
    return isDatacenter ? IpUsageType.hosting : IpUsageType.unknown;
  }

  int _score({
    required bool isDatacenter,
    required bool isProxy,
    required bool isVpn,
    required bool isAbuser,
  }) {
    var score = 100;
    if (isAbuser) score -= 45;
    if (isProxy) score -= 40;
    if (isVpn) score -= 30;
    if (isDatacenter) score -= 10;
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

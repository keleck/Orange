import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/xboard/core/core.dart';

final _logger = FileLogger('ip_quality_service.dart');

/// IP 质量等级
enum IpQualityLevel {
  unknown,
  poor,
  fair,
  good,
  excellent,
}

/// IP 归属类型，对应上游「机房 / 住宅」这类标签
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
    this.risk,
    this.isNative,
    this.isDatacenter = false,
    this.isProxy = false,
    this.source,
    this.checkedAt,
  });

  final IpQualityLevel level;
  final IpUsageType usage;

  /// 综合评分 0~100（越大越好）
  final int score;

  final String? ip;
  final String? countryCode;
  final String? asnOrg;

  /// 风控值 0~100（越小越干净）
  final int? risk;

  /// 是否原生 IP（false = 广播 IP）
  final bool? isNative;

  final bool isDatacenter;
  final bool isProxy;

  /// 数据来源，便于排查
  final String? source;

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
      'ip=$ip, risk=$risk, native=$isNative, src=$source)';
}

class _IpQualityCacheEntry {
  const _IpQualityCacheEntry(this.quality, this.time);

  final IpQuality quality;
  final DateTime time;
}

/// 出口 IP 质量评估。
///
/// 与上游一致，以 ping0.cc 的 IP 段级画像为准（它能区分「IDC 机房」与
/// 「家庭宽带」，并给出风控值 / 原生广播），拿不到时再退回 ip-api.com。
class IpQualityService {
  static final IpQualityService _instance = IpQualityService._internal();

  factory IpQualityService() => _instance;

  IpQualityService._internal();

  static const Duration _cacheTtl = Duration(minutes: 5);
  static const Duration _timeout = Duration(seconds: 20);

  /// 取出口 IP：cloudflare trace 体积小、响应快
  static const String _ipUrl = 'https://www.cloudflare.com/cdn-cgi/trace';

  /// ping0 详情页（服务端渲染，含 IP 类型 / 原生 / 风控值）
  static String _ping0Url(String ip) => 'https://ping0.cc/ip/$ip';

  /// 备用源：免费、体积小，只有 proxy / hosting / mobile
  static const String _fallbackUrl =
      'http://ip-api.com/json/?fields=status,country,countryCode,isp,org,as,'
      'proxy,hosting,mobile,query';

  /// 机房 / 云厂商 / IDC 关键词（备用源判定用）
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
  ];

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
    var quality = await _queryPing0(proxyName);
    if (!quality.isKnown) {
      _logger.debug('ping0 评估失败，回退 ip-api.com: $proxyName');
      quality = await _queryFallback(proxyName);
    }
    if (quality.isKnown) {
      _cache[proxyName] = _IpQualityCacheEntry(quality, DateTime.now());
    }
    _logger.debug('出口 IP 质量评估完成 $proxyName -> $quality');
    return quality;
  }

  // ---------------------------------------------------------------- ping0

  Future<IpQuality> _queryPing0(String proxyName) async {
    final ip = await _fetchOutboundIp(proxyName);
    if (ip == null || ip.isEmpty) return IpQuality.unknown;

    // 首次失败（超时 / 限流）再试一次，避免直接掉到精度较低的备用源
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future.delayed(const Duration(milliseconds: 800));
      }
      final html = await _fetch(proxyName, _ping0Url(ip));
      if (html == null || html.isEmpty) continue;
      try {
        final quality = _parsePing0(html, ip);
        if (quality.isKnown) return quality;
        _logger.debug('ping0 页面无有效字段（第 ${attempt + 1} 次）');
      } catch (e) {
        _logger.debug('ping0 页面解析失败: $e');
      }
    }
    return IpQuality.unknown;
  }

  Future<String?> _fetchOutboundIp(String proxyName) async {
    final body = await _fetch(proxyName, _ipUrl);
    if (body == null) return null;
    for (final line in body.split('\n')) {
      if (line.startsWith('ip=')) {
        final ip = line.substring(3).trim();
        if (ip.isNotEmpty) return ip;
      }
    }
    return null;
  }

  IpQuality _parsePing0(String html, String ip) {
    final typeLabel = _sectionLabel(html, 'line-iptype');
    final nativeLabel = _sectionLabel(html, 'line-nativeip');
    final risk = _parseRisk(html);

    if (typeLabel == null && risk == null) {
      return IpQuality.unknown;
    }

    final isNative = switch (nativeLabel) {
      final label? when label.contains('原生') => true,
      final label? when label.contains('广播') => false,
      _ => null,
    };

    var usage = IpUsageType.unknown;
    if (typeLabel != null) {
      if (typeLabel.contains('IDC') || typeLabel.contains('机房')) {
        usage = IpUsageType.hosting;
      } else if (typeLabel.contains('家庭') || typeLabel.contains('宽带')) {
        usage = IpUsageType.residential;
      }
    }
    if (usage == IpUsageType.unknown && isNative == false) {
      // 广播 IP 基本都是跨国 IDC 段
      usage = IpUsageType.hosting;
    }
    if (usage == IpUsageType.unknown) {
      usage = IpUsageType.business;
    }

    var level = _levelOfRisk(risk);
    // 广播 IP 容易被风控，降一档
    if (isNative == false) {
      level = _downgrade(level);
    }

    final score = (100 - (risk ?? 50)).clamp(0, 100);

    return IpQuality(
      level: level,
      usage: usage,
      score: score,
      ip: ip,
      risk: risk,
      isNative: isNative,
      isDatacenter: usage == IpUsageType.hosting,
      source: 'ping0',
      checkedAt: DateTime.now(),
    );
  }

  /// 取某个区块里第一个 label 文本（如 line-iptype -> "IDC机房 IP"）
  String? _sectionLabel(String html, String sectionClass) {
    final pattern = RegExp(
      '$sectionClass[\\s\\S]{0,3000}?<span class="label[^"]*"[^>]*>\\s*([^<]{1,24}?)\\s*</span>',
    );
    final match = pattern.firstMatch(html);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  /// 风控值：取当前档位的区间起点（0-15 / 15-25 / 25-40 / 40-50 / 50-70 / 70-100）
  int? _parseRisk(String html) {
    final match = RegExp(
      r'riskcurrent[^>]*title="(\d+)\s*-\s*(\d+)',
    ).firstMatch(html);
    if (match == null) return null;
    final start = int.tryParse(match.group(1) ?? '');
    final end = int.tryParse(match.group(2) ?? '');
    if (start == null) return null;
    // 用区间中点更贴近真实值
    if (end == null) return start;
    return ((start + end) / 2).round();
  }

  IpQualityLevel _levelOfRisk(int? risk) {
    if (risk == null) return IpQualityLevel.unknown;
    if (risk < 25) return IpQualityLevel.excellent;
    if (risk < 40) return IpQualityLevel.good;
    if (risk < 50) return IpQualityLevel.fair;
    return IpQualityLevel.poor;
  }

  IpQualityLevel _downgrade(IpQualityLevel level) {
    return switch (level) {
      IpQualityLevel.excellent => IpQualityLevel.good,
      IpQualityLevel.good => IpQualityLevel.fair,
      IpQualityLevel.fair => IpQualityLevel.poor,
      IpQualityLevel.poor => IpQualityLevel.poor,
      IpQualityLevel.unknown => IpQualityLevel.unknown,
    };
  }

  // ------------------------------------------------------------ 备用源

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

    var level = IpQualityLevel.excellent;
    if (isProxy) {
      level = IpQualityLevel.poor;
    } else if (usage == IpUsageType.hosting) {
      level = IpQualityLevel.good;
    }

    return IpQuality(
      level: level,
      usage: usage,
      score: isProxy ? 45 : (usage == IpUsageType.hosting ? 90 : 100),
      ip: _string(json['query']),
      countryCode: _string(json['countryCode']),
      asnOrg: _string(json['org']) ?? _string(json['isp']),
      isDatacenter: isDatacenter || usage == IpUsageType.hosting,
      isProxy: isProxy,
      source: 'ip-api',
      checkedAt: DateTime.now(),
    );
  }

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

  // ------------------------------------------------------------- 通用

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

  String? _string(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }
}

final ipQualityService = IpQualityService();

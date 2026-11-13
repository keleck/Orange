import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/xboard/core/core.dart';

import '../../shared/services/service_probe.dart';

final _logger = FileLogger('ip_quality_service.dart');

/// IP 质量等级，与 FlClash 的三档一致：优 / 一般 / 差
enum IpQualityLevel { unknown, poor, fair, good, excellent }

/// IP 归属类型，对应「住宅 / 商业 / 机房 / 移动」标签
enum IpUsageType {
  unknown('未知'),
  residential('住宅'),
  business('商业'),
  hosting('机房'),
  mobile('移动');

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
    this.asnOrg,
    this.asn,
    this.isProxy = false,
    this.isVpn = false,
    this.isTor = false,
    this.isAbuser = false,
    this.source,
    this.checkedAt,
  });

  final IpQualityLevel level;
  final IpUsageType usage;

  /// 综合评分 0~100（越大越好）
  final int score;

  final String? ip;
  final String? asnOrg;
  final int? asn;

  final bool isProxy;
  final bool isVpn;
  final bool isTor;
  final bool isAbuser;

  /// 类型数据来源，便于排查
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
      'ip=$ip, src=$source)';
}

class _CacheEntry {
  const _CacheEntry(this.quality, this.time);

  final IpQuality quality;
  final DateTime time;
}

// ---------------------------------------------------------------- 多源查询

class _SourceFailure implements Exception {
  const _SourceFailure(this.status);

  final String status;
}

typedef _Answer = ({IpQuality quality, bool inferred});

enum _Source {
  identMe('ident.me'),
  ipApiCom('ip-api.com'),
  ipQuery('ipquery.io'),
  ipLocate('iplocate.io'),
  ipApiIs('ipapi.is'),
  proxyCheck('proxycheck.io');

  const _Source(this.label);

  final String label;
}

/// 与 FlClash 一致的波次：配额最紧的源放最后，前一波没答上来才启动下一波
const _waves = <List<_Source>>[
  [_Source.identMe, _Source.ipApiCom, _Source.ipQuery],
  [_Source.ipLocate],
  [_Source.ipApiIs],
  [_Source.proxyCheck],
];

String _urlOf(_Source source, String ip) {
  return switch (source) {
    _Source.identMe => 'https://ident.me/json',
    // ip-api.com 的 HTTPS 只在付费版提供
    _Source.ipApiCom =>
      'http://ip-api.com/json/$ip?fields=status,isp,org,as,mobile,proxy,hosting',
    _Source.ipQuery => 'https://api.ipquery.io/$ip?format=json',
    _Source.ipLocate => 'https://iplocate.io/api/lookup/$ip',
    _Source.proxyCheck => 'https://proxycheck.io/v3/$ip',
    _Source.ipApiIs => 'https://api.ipapi.is/?q=$ip',
  };
}

_Answer? _parse(_Source source, String ip, Map<String, dynamic> json) {
  return switch (source) {
    _Source.identMe => _fromIdentMe(ip, json),
    _Source.ipApiCom => _fromIpApiCom(ip, json),
    _Source.ipQuery => _fromIpQuery(ip, json),
    _Source.ipLocate => _fromIpLocate(ip, json),
    _Source.proxyCheck => _fromProxyCheck(ip, json),
    _Source.ipApiIs => _fromIpApiIs(ip, json),
  };
}

_Answer? _fromIdentMe(String ip, Map<String, dynamic> json) {
  if (json['ip'] != ip) {
    throw const _SourceFailure('ipMismatch');
  }
  return _answer(
    ip,
    _Source.identMe,
    _declaredType(json['type']),
    organization: _text(json['aso']),
    asn: _asn(json['asn']),
  );
}

_Answer? _fromIpApiCom(String ip, Map<String, dynamic> json) {
  if (json['status'] != 'success') {
    throw const _SourceFailure('failed');
  }
  final type = _pickType(
    hosting: _flag(json['hosting']),
    mobile: _flag(json['mobile']),
  );
  return _answer(
    ip,
    _Source.ipApiCom,
    type ?? IpUsageType.residential,
    inferred: type == null,
    organization: _text(json['org']) ?? _text(json['isp']),
    asn: _asn(json['as']),
    isProxy: _flag(json['proxy']),
  );
}

_Answer? _fromIpQuery(String ip, Map<String, dynamic> json) {
  final risk = _object(json['risk']);
  final isp = _object(json['isp']);
  final type = _pickType(
    hosting: _flag(risk['is_datacenter']),
    mobile: _flag(risk['is_mobile']),
  );
  return _answer(
    ip,
    _Source.ipQuery,
    type ?? IpUsageType.residential,
    inferred: type == null,
    organization: _text(isp['org']) ?? _text(isp['isp']),
    asn: _asn(isp['asn']),
    isProxy: _flag(risk['is_proxy']),
    isVpn: _flag(risk['is_vpn']),
    isTor: _flag(risk['is_tor']),
  );
}

_Answer? _fromIpLocate(String ip, Map<String, dynamic> json) {
  final privacy = _object(json['privacy']);
  final company = _object(json['company']);
  final asn = _object(json['asn']);
  return _answer(
    ip,
    _Source.ipLocate,
    _pickType(
      hosting: _flag(privacy['is_hosting']),
      declared: _declaredType(company['type']) ?? _declaredType(asn['type']),
    ),
    organization: _text(company['name']) ?? _text(asn['name']),
    asn: _asn(asn['asn']),
    isProxy: _flag(privacy['is_proxy']),
    isVpn: _flag(privacy['is_vpn']),
    isTor: _flag(privacy['is_tor']),
    isAbuser: _flag(privacy['is_abuser']),
  );
}

_Answer? _fromProxyCheck(String ip, Map<String, dynamic> json) {
  final status = json['status'];
  if (status == 'denied') {
    throw const _SourceFailure('rateLimited');
  }
  if (status != 'ok' && status != 'warning') {
    throw const _SourceFailure('failed');
  }
  final result = _object(json[ip]);
  final network = _object(result['network']);
  final detections = _object(result['detections']);
  final networkType = network['type'];
  return _answer(
    ip,
    _Source.proxyCheck,
    _pickType(
      hosting: _flag(detections['hosting']) || networkType == 'Hosting',
      mobile: networkType == 'Wireless',
      declared: switch (networkType) {
        'Residential' => IpUsageType.residential,
        'Business' => IpUsageType.business,
        _ => null,
      },
    ),
    organization: _text(network['organisation']),
    asn: _asn(network['asn']),
    isProxy: _flag(detections['proxy']),
    isVpn: _flag(detections['vpn']),
    isTor: _flag(detections['tor']),
  );
}

_Answer? _fromIpApiIs(String ip, Map<String, dynamic> json) {
  final company = _object(json['company']);
  final asn = _object(json['asn']);
  return _answer(
    ip,
    _Source.ipApiIs,
    _pickType(
      hosting: _flag(json['is_datacenter']),
      mobile: _flag(json['is_mobile']),
      declared: _declaredType(company['type']) ?? _declaredType(asn['type']),
    ),
    organization: _text(company['name']) ?? _text(asn['org']),
    asn: _asn(asn['asn']),
    isProxy: _flag(json['is_proxy']),
    isVpn: _flag(json['is_vpn']),
    isTor: _flag(json['is_tor']),
    isAbuser: _flag(json['is_abuser']),
  );
}

/// 源没有明确表态机房/移动时按住宅推断，标记 inferred，只有其它源都失败才用
_Answer? _answer(
  String ip,
  _Source source,
  IpUsageType? type, {
  bool inferred = false,
  String? organization,
  int? asn,
  bool isProxy = false,
  bool isVpn = false,
  bool isTor = false,
  bool isAbuser = false,
}) {
  if (type == null) return null;
  return (
    quality: IpQuality(
      level: _levelOf(type, isTor: isTor, isAbuser: isAbuser),
      usage: type,
      score: _scoreOf(type, isProxy, isVpn, isTor, isAbuser),
      ip: ip,
      asnOrg: organization,
      asn: asn,
      isProxy: isProxy,
      isVpn: isVpn,
      isTor: isTor,
      isAbuser: isAbuser,
      source: source.label,
      checkedAt: DateTime.now(),
    ),
    inferred: inferred,
  );
}

IpUsageType? _pickType({
  required bool hosting,
  bool mobile = false,
  IpUsageType? declared,
}) {
  if (hosting || declared == IpUsageType.hosting) {
    return IpUsageType.hosting;
  }
  if (mobile) return IpUsageType.mobile;
  return declared;
}

IpUsageType? _declaredType(Object? value) {
  return switch (value) {
    'isp' => IpUsageType.residential,
    'business' ||
    'education' ||
    'government' ||
    'banking' =>
      IpUsageType.business,
    'hosting' => IpUsageType.hosting,
    _ => null,
  };
}

Map<String, dynamic> _object(Object? value) {
  return value is Map<String, dynamic> ? value : const {};
}

bool _flag(Object? value) => value == true;

String? _text(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

int? _asn(Object? value) {
  final asn = switch (value) {
    final int number => number,
    final String text =>
      int.tryParse(RegExp(r'\d+').firstMatch(text)?[0] ?? ''),
    _ => null,
  };
  return asn == 0 ? null : asn;
}

// ---------------------------------------------------------------- 等级映射

/// 与 FlClash 的 `IpQuality.level` 完全一致：
/// Tor / 滥用 → 差；机房 → 一般；住宅 / 移动 / 商业 → 优
IpQualityLevel _levelOf(
  IpUsageType type, {
  required bool isTor,
  required bool isAbuser,
}) {
  if (isTor || isAbuser) return IpQualityLevel.poor;
  return switch (type) {
    IpUsageType.residential ||
    IpUsageType.mobile ||
    IpUsageType.business =>
      IpQualityLevel.excellent,
    IpUsageType.hosting => IpQualityLevel.fair,
    IpUsageType.unknown => IpQualityLevel.unknown,
  };
}

int _scoreOf(
  IpUsageType type,
  bool isProxy,
  bool isVpn,
  bool isTor,
  bool isAbuser,
) {
  if (isTor || isAbuser) return 30;
  if (type == IpUsageType.hosting) return 70;
  if (isProxy || isVpn) return 60;
  return 100;
}

/// 出口 IP 质量评估。
///
/// 逻辑照搬 FlClash：走当前节点取出口 IP，再用六源波次竞速拿 IP 类型，
/// 类型决定标签（住宅 / 商业 / 移动 → 质量优，机房 → 质量一般），
/// Tor / 滥用标记直接判「质量差」。
class IpQualityService {
  static final IpQualityService _instance = IpQualityService._internal();

  factory IpQualityService() => _instance;

  IpQualityService._internal();

  static const Duration _cacheTtl = Duration(minutes: 5);
  static const Duration _ipCacheTtl = Duration(days: 3);
  static const Duration _failureCooldown = Duration(minutes: 5);
  static const Duration _sourceTimeout = Duration(seconds: 8);
  static const Duration _hedge = Duration(seconds: 1);

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, _CacheEntry> _ipCache = {};
  final Map<String, DateTime> _failures = {};
  final Map<String, Future<IpQuality>> _inflight = {};

  final Dio _dio = Dio(
    BaseOptions(
      headers: {'User-Agent': browserUa},
      connectTimeout: _sourceTimeout,
      receiveTimeout: _sourceTimeout,
      sendTimeout: _sourceTimeout,
    ),
  );

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
    if (proxyName.isEmpty) return Future.value(IpQuality.unknown);

    if (!force) {
      final cached = peek(proxyName);
      if (cached != null) return Future.value(cached);
      // 失败后冷却，避免每次重建都打一轮接口（与 FlClash 一致）
      final failedAt = _failures[proxyName];
      if (failedAt != null &&
          DateTime.now().difference(failedAt) < _failureCooldown) {
        return Future.value(IpQuality.unknown);
      }
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
    final ip = await _fetchOutboundIp(proxyName);
    if (ip == null || ip.isEmpty) {
      _logger.debug('取出口 IP 失败: $proxyName');
      return IpQuality.unknown;
    }

    // 同一 IP 的结果 3 天内复用，与 FlClash 的本地缓存一致
    final cached = _ipCache[ip];
    if (cached != null &&
        DateTime.now().difference(cached.time) < _ipCacheTtl) {
      _cache[proxyName] = _CacheEntry(cached.quality, DateTime.now());
      return cached.quality;
    }

    final quality = await _lookupType(ip).catchError((Object e) {
      _logger.debug('IP 质量查询失败: $e');
      return null;
    });
    if (quality == null || !quality.isKnown) {
      _logger.debug('IP 质量查询无结果: $ip');
      _failures[proxyName] = DateTime.now();
      return IpQuality.unknown;
    }

    final now = DateTime.now();
    _failures.remove(proxyName);
    _cache[proxyName] = _CacheEntry(quality, now);
    _ipCache[ip] = _CacheEntry(quality, now);
    _logger.debug('出口 IP 质量评估完成 $proxyName -> $quality');
    return quality;
  }

  Future<String?> _fetchOutboundIp(String proxyName) async {
    try {
      // 与 FlClash 一致：cloudflare trace / ip.sb / ipinfo.io / ipwho.is /
      // geojs / country.is / ipquery.io / ident.me 八源竞速
      final info = await lookupOutboundIp(
        proxyName: proxyName,
        timeout: const Duration(seconds: 6),
      );
      final ip = info?.ip;
      if (ip == null || ip.isEmpty) return null;
      return ip;
    } catch (e) {
      _logger.debug('出口 IP 请求失败: $e');
      return null;
    }
  }

  /// 六源波次竞速，先答上来的非推断结果直接胜出
  Future<IpQuality?> _lookupType(String ip) {
    final completer = Completer<IpQuality?>();
    var wave = 0;
    var inFlight = 0;
    IpQuality? fallback;
    Timer? timer;

    void finish() {
      timer?.cancel();
      if (!completer.isCompleted) completer.complete(fallback);
    }

    void launch() {
      timer?.cancel();
      if (completer.isCompleted) return;
      if (wave == _waves.length) {
        if (inFlight == 0) finish();
        return;
      }
      final sources = _waves[wave++];
      inFlight += sources.length;
      for (final source in sources) {
        _query(source, ip).then((answer) {
          inFlight--;
          if (completer.isCompleted) return;
          if (answer.inferred) {
            fallback ??= answer.quality;
            if (inFlight == 0) launch();
            return;
          }
          timer?.cancel();
          completer.complete(answer.quality);
        }, onError: (Object error) {
          inFlight--;
          if (completer.isCompleted) return;
          if (inFlight == 0) launch();
        });
      }
      if (wave < _waves.length) {
        timer = Timer(_hedge, launch);
      }
    }

    launch();
    return completer.future;
  }

  Future<_Answer> _query(_Source source, String ip) async {
    final response = await _dio
        .get<String>(
          _urlOf(source, ip),
          options: Options(
            responseType: ResponseType.plain,
            validateStatus: (_) => true,
          ),
        )
        .timeout(_sourceTimeout);
    if (response.statusCode == HttpStatus.tooManyRequests) {
      throw const _SourceFailure('rateLimited');
    }
    if (response.statusCode != HttpStatus.ok) {
      throw const _SourceFailure('failed');
    }
    final decoded = json.decode(response.data ?? '');
    if (decoded is! Map) {
      throw const _SourceFailure('failed');
    }
    final answer = _parse(source, ip, decoded.cast<String, dynamic>());
    if (answer == null) {
      throw const _SourceFailure('noType');
    }
    return answer;
  }
}

final ipQualityService = IpQualityService();

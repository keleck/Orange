import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/xboard/core/core.dart';

final _logger = FileLogger('ip_quality_service.dart');

/// IP 质量等级
enum IpQualityLevel { unknown, poor, fair, good, excellent }

/// IP 归属类型，对应上游「住宅 / 商业 / 机房 / 移动」标签
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
    this.risk,
    this.isNative,
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

  /// ping0 风控值 0~100（越小越干净），没有则为空
  final int? risk;

  /// 是否原生 IP（false = 广播 IP）
  final bool? isNative;

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
      'ip=$ip, risk=$risk, src=$source)';
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

/// 与上游一致的波次：配额最紧的源放最后，前一波没答上来才启动下一波
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
      level: _levelOfType(type, isProxy, isVpn, isTor, isAbuser),
      usage: type,
      score: _scoreOfType(type, isProxy, isVpn, isTor, isAbuser),
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

IpQualityLevel _levelOfType(
  IpUsageType type,
  bool isProxy,
  bool isVpn,
  bool isTor,
  bool isAbuser,
) {
  if (isTor || isAbuser) return IpQualityLevel.poor;
  if (isProxy || isVpn) return IpQualityLevel.fair;
  // 与上游标签一致：干净的机房 IP 同样算「质量优」
  return switch (type) {
    IpUsageType.hosting ||
    IpUsageType.residential ||
    IpUsageType.business ||
    IpUsageType.mobile =>
      IpQualityLevel.excellent,
    IpUsageType.unknown => IpQualityLevel.unknown,
  };
}

int _scoreOfType(
  IpUsageType type,
  bool isProxy,
  bool isVpn,
  bool isTor,
  bool isAbuser,
) {
  var score = 100;
  if (isAbuser) score -= 45;
  if (isTor) score -= 45;
  if (isProxy) score -= 40;
  if (isVpn) score -= 30;
  if (type == IpUsageType.hosting) score -= 10;
  return score.clamp(0, 100);
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

/// 出口 IP 质量评估。
///
/// 1. 走当前节点取出口 IP
/// 2. 与上游一致：ident.me / ip-api.com / ipquery.io 三源竞速，失败再依次补
///    iplocate.io、ipapi.is、proxycheck.io，拿到 IP 类型与代理/机房标记
/// 3. 同时查 ping0.cc 的风控值，有风控值时以它为准细化「优 / 良 / 一般 / 差」
class IpQualityService {
  static final IpQualityService _instance = IpQualityService._internal();

  factory IpQualityService() => _instance;

  IpQualityService._internal();

  static const Duration _cacheTtl = Duration(minutes: 5);
  static const Duration _sourceTimeout = Duration(seconds: 8);
  static const Duration _hedge = Duration(seconds: 1);
  static const Duration _ping0Timeout = Duration(seconds: 20);

  static const String _ipUrl = 'https://www.cloudflare.com/cdn-cgi/trace';

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future<IpQuality>> _inflight = {};

  final Dio _dio = Dio(
    BaseOptions(
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

    // 类型走多源竞速，风控值走 ping0，两边并行
    final results = await Future.wait<IpQuality?>([
      _lookupType(ip).catchError((Object e) {
        _logger.debug('多源类型查询失败: $e');
        return null;
      }),
      _lookupPing0(proxyName, ip).catchError((Object e) {
        _logger.debug('ping0 风控查询失败: $e');
        return null;
      }),
    ]);

    final typeAnswer = results[0];
    final riskAnswer = results[1];

    if (typeAnswer == null && riskAnswer == null) {
      _logger.debug('IP 质量评估失败: $ip');
      return IpQuality.unknown;
    }

    final quality = _merge(typeAnswer, riskAnswer, ip);
    if (quality.isKnown) {
      _cache[proxyName] = _CacheEntry(quality, DateTime.now());
    }
    _logger.debug('出口 IP 质量评估完成 $proxyName -> $quality');
    return quality;
  }

  /// 类型以多源为准，风控值以 ping0 为准，两者互相补位
  IpQuality _merge(IpQuality? type, IpQuality? risk, String ip) {
    if (type == null) {
      // 只有 ping0：类型和风控都来自它
      return risk!;
    }
    if (risk == null) {
      return type;
    }

    final riskValue = risk.risk;
    var level = type.level;
    if (riskValue != null) {
      level = _levelOfRisk(riskValue);
      if (risk.isNative == false) {
        level = _downgrade(level);
      }
      // 多源已经识别出代理 / VPN / 滥用时，不允许被风控值抬高
      if (type.isTor || type.isAbuser) {
        level = IpQualityLevel.poor;
      } else if ((type.isProxy || type.isVpn) &&
          level.index > IpQualityLevel.fair.index) {
        level = IpQualityLevel.fair;
      }
    }

    // ping0 能区分「家庭宽带」和「机房」，类型上更贴近实际使用场景
    final usage = risk.usage != IpUsageType.unknown ? risk.usage : type.usage;

    return IpQuality(
      level: level,
      usage: usage,
      score: riskValue != null ? (100 - riskValue).clamp(0, 100) : type.score,
      ip: ip,
      asnOrg: type.asnOrg,
      asn: type.asn,
      risk: riskValue,
      isNative: risk.isNative,
      isProxy: type.isProxy,
      isVpn: type.isVpn,
      isTor: type.isTor,
      isAbuser: type.isAbuser,
      source: riskValue != null ? '${type.source}+ping0' : type.source,
      checkedAt: DateTime.now(),
    );
  }

  // ------------------------------------------------------------ 出口 IP

  Future<String?> _fetchOutboundIp(String proxyName) async {
    try {
      final result = await clashCore.outboundIp(
        proxyName: proxyName,
        urls: [_ipUrl],
        timeout: const Duration(seconds: 12),
      );
      if (result == null || result.error != null || result.body.isEmpty) {
        return null;
      }
      for (final line in result.body.split('\n')) {
        if (line.startsWith('ip=')) {
          final ip = line.substring(3).trim();
          if (ip.isNotEmpty) return ip;
        }
      }
    } catch (e) {
      _logger.debug('出口 IP 请求失败: $e');
    }
    return null;
  }

  // ------------------------------------------------------------ 多源竞速

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

  // ---------------------------------------------------------------- ping0

  Future<IpQuality?> _lookupPing0(String proxyName, String ip) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future.delayed(const Duration(milliseconds: 800));
      }
      final html = await _fetchPing0(proxyName, ip);
      if (html == null || html.isEmpty) continue;
      final quality = _parsePing0(html, ip);
      if (quality != null) return quality;
    }
    return null;
  }

  Future<String?> _fetchPing0(String proxyName, String ip) async {
    try {
      final result = await clashCore.outboundIp(
        proxyName: proxyName,
        urls: ['https://ping0.cc/ip/$ip'],
        timeout: _ping0Timeout,
      );
      if (result == null || result.error != null || result.body.isEmpty) {
        return null;
      }
      return result.body;
    } catch (e) {
      _logger.debug('ping0 请求失败: $e');
      return null;
    }
  }

  IpQuality? _parsePing0(String html, String ip) {
    final typeLabel = _sectionLabel(html, 'line-iptype');
    final nativeLabel = _sectionLabel(html, 'line-nativeip');
    final risk = _parseRisk(html);

    if (typeLabel == null && risk == null) return null;

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
      usage = IpUsageType.hosting;
    }

    var level = _levelOfRisk(risk);
    if (isNative == false && level != IpQualityLevel.unknown) {
      level = _downgrade(level);
    }

    return IpQuality(
      level: level,
      usage: usage,
      score: risk != null ? (100 - risk).clamp(0, 100) : 0,
      ip: ip,
      risk: risk,
      isNative: isNative,
      source: 'ping0',
      checkedAt: DateTime.now(),
    );
  }

  String? _sectionLabel(String html, String sectionClass) {
    final pattern = RegExp(
      '$sectionClass[\\s\\S]{0,3000}?<span class="label[^"]*"[^>]*>\\s*([^<]{1,24}?)\\s*</span>',
    );
    final value = pattern.firstMatch(html)?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  int? _parseRisk(String html) {
    final match = RegExp(
      r'riskcurrent[^>]*title="(\d+)\s*-\s*(\d+)',
    ).firstMatch(html);
    if (match == null) return null;
    final start = int.tryParse(match.group(1) ?? '');
    final end = int.tryParse(match.group(2) ?? '');
    if (start == null) return null;
    if (end == null) return start;
    return ((start + end) / 2).round();
  }
}

final ipQualityService = IpQualityService();

import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/clash/clash.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';

/// 与 core/service_check.go 里注册的 checker 名称一一对应。
enum ServiceTarget {
  google('google', 'Google', 'google'),
  github('github', 'GitHub', 'github'),
  youtube('youtube', 'YouTube', 'youtube'),
  chatgpt('chatgpt', 'ChatGPT', 'openai'),
  claude('claude', 'Claude', 'claude'),
  gemini('gemini', 'Gemini', 'gemini'),
  netflix('netflix', 'Netflix', 'netflix'),
  disneyPlus('disney-plus', 'Disney+', 'disneyplus'),
  primeVideo('prime-video', 'Prime Video', 'primevideo'),
  spotify('spotify', 'Spotify', 'spotify'),
  tiktok('tiktok', 'TikTok', 'tiktok'),
  discord('discord', 'Discord', 'discord'),
  bilibili('bilibili', 'Bilibili', 'bilibili');

  const ServiceTarget(this.id, this.label, this.icon);

  final String id;
  final String label;
  final String icon;

  String get iconPath => 'assets/images/services/$icon.svg';

  static ServiceTarget? byId(String id) {
    for (final target in values) {
      if (target.id == id) {
        return target;
      }
    }
    return null;
  }
}

/// 与 core/service_check.go 的状态常量一一对应。
enum ServiceProbeStatus {
  available('available', '可用'),
  unavailable('unavailable', '不可用'),
  restricted('restricted', '受限'),
  disallowedIsp('disallowed-isp', 'ISP 受限'),
  blocked('blocked', '已封锁'),
  unsupportedRegion('unsupported-region', '地区不支持'),
  originalsOnly('originals-only', '仅自制剧'),
  comingSoon('coming-soon', '即将上线'),
  timeout('timeout', '超时'),
  failed('failed', '检测失败');

  const ServiceProbeStatus(this.id, this.label);

  final String id;
  final String label;

  /// 只有 available 算正常，其余都计入异常数（与上游一致）。
  bool get isOk => this == ServiceProbeStatus.available;

  static ServiceProbeStatus byId(String id) {
    for (final status in values) {
      if (status.id == id) {
        return status;
      }
    }
    return ServiceProbeStatus.failed;
  }
}

class ServiceCheck {
  const ServiceCheck({
    required this.status,
    this.delay,
    this.region,
    this.checkedAt,
  });

  final ServiceProbeStatus status;
  final int? delay;
  final String? region;
  final DateTime? checkedAt;

  factory ServiceCheck.of(ServiceCheckItem item) {
    return ServiceCheck(
      status: ServiceProbeStatus.byId(item.status),
      delay: (item.delay ?? 0) > 0 ? item.delay : null,
      region: item.region,
      checkedAt: (item.checkedAt ?? 0) > 0
          ? DateTime.fromMillisecondsSinceEpoch(item.checkedAt!)
          : null,
    );
  }

  bool get isOk => status.isOk;
}

/// 探测一轮服务。[targets] 为空表示检测全部。
///
/// [proxyName] 传当前选中的节点/组名，让请求真正从该节点出去；
/// 传空则由内核按分流规则路由。
Future<Map<ServiceTarget, ServiceCheck>> checkServices({
  required String proxyName,
  required List<ServiceTarget> targets,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final items = await clashCore.serviceCheck(
    proxyName: proxyName,
    names: targets.map((target) => target.id).toList(),
    timeout: timeout,
  );
  return {
    for (final item in items)
      if (ServiceTarget.byId(item.name) case final target?)
        target: ServiceCheck.of(item),
  };
}

/// 出口 IP 源：既要能给出 IP，也要能给出归属地，省掉二次查询。
final Map<String, IpInfo Function(String)> ipInfoSources = {
  'https://www.cloudflare.com/cdn-cgi/trace': _parseCloudflareTrace,
  'https://api.ip.sb/geoip': (body) => IpInfo.fromIpSbJson(_json(body)),
  'https://ipinfo.io/json': (body) => IpInfo.fromIpInfoIoJson(_json(body)),
  'https://ipwho.is': (body) => IpInfo.fromIpwhoIsJson(_json(body)),
  'https://api.ipapi.co/json': (body) => IpInfo.fromIpApiCoJson(_json(body)),
};

Map<String, dynamic> _json(String body) {
  return json.decode(body) as Map<String, dynamic>;
}

/// cloudflare 的 trace 是纯文本 kv，响应最快，放在首位。
IpInfo _parseCloudflareTrace(String body) {
  var ip = '';
  var loc = '';
  for (final line in body.split('\n')) {
    if (line.startsWith('ip=')) {
      ip = line.substring(3).trim();
    } else if (line.startsWith('loc=')) {
      loc = line.substring(4).trim();
    }
  }
  if (ip.isEmpty || loc.isEmpty) {
    throw const FormatException('invalid cloudflare trace');
  }
  return IpInfo(ip: ip, countryCode: loc);
}

/// 走 [proxyName] 取出口 IP 与归属地，失败返回 null。
Future<IpInfo?> lookupOutboundIp({
  required String proxyName,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final result = await clashCore.outboundIp(
    proxyName: proxyName,
    urls: ipInfoSources.keys.toList(),
    timeout: timeout,
  );
  if (result == null || result.error != null || result.body.isEmpty) {
    return null;
  }
  final parse = ipInfoSources[result.url];
  if (parse == null) {
    return null;
  }
  try {
    return parse(result.body);
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}

/// 「管理服务」里勾选的目标，持久化到数据目录，重启后保留。
class ServiceStatusPrefs {
  ServiceStatusPrefs._();

  static const _fileName = 'service_status_prefs.json';

  static Set<String>? _cache;

  static Future<File> _file() async {
    final home = await appPath.homeDirPath;
    return File('$home/$_fileName');
  }

  /// 返回已启用（需要检测/显示）的服务 id 集合，默认全部启用。
  static Future<Set<String>> load() async {
    final cached = _cache;
    if (cached != null) {
      return cached;
    }
    try {
      final file = await _file();
      if (await file.exists()) {
        final decoded = json.decode(await file.readAsString());
        if (decoded is List) {
          final ids = decoded.whereType<String>().toSet();
          final valid = ids
              .where((id) => ServiceTarget.byId(id) != null)
              .toSet();
          _cache = valid;
          return valid;
        }
      }
    } catch (e) {
      commonPrint.log('读取服务状态设置失败: $e');
    }
    final all = ServiceTarget.values.map((target) => target.id).toSet();
    _cache = all;
    return all;
  }

  static Future<void> save(Set<String> ids) async {
    _cache = ids;
    try {
      final file = await _file();
      await file.writeAsString(json.encode(ids.toList()));
    } catch (e) {
      commonPrint.log('保存服务状态设置失败: $e');
    }
  }
}

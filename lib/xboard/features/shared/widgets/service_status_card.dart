import 'dart:async';

import 'package:fl_clash/clash/clash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;

/// 服务状态检测项
class ServiceTarget {
  const ServiceTarget({
    required this.id,
    required this.label,
    required this.icon,
    required this.url,
  });

  final String id;
  final String label;
  final String icon;
  final String url;
}

/// 全部检测项（顺序与上游 FlClash 一致）
const serviceTargets = <ServiceTarget>[
  ServiceTarget(
    id: 'google',
    label: 'Google',
    icon: 'google',
    url: 'https://www.google.com/generate_204',
  ),
  ServiceTarget(
    id: 'github',
    label: 'GitHub',
    icon: 'github',
    url: 'https://github.com',
  ),
  ServiceTarget(
    id: 'youtube',
    label: 'YouTube',
    icon: 'youtube',
    url: 'https://www.youtube.com/generate_204',
  ),
  ServiceTarget(
    id: 'chatgpt',
    label: 'ChatGPT',
    icon: 'openai',
    url: 'https://chatgpt.com',
  ),
  ServiceTarget(
    id: 'claude',
    label: 'Claude',
    icon: 'claude',
    url: 'https://claude.ai',
  ),
  ServiceTarget(
    id: 'gemini',
    label: 'Gemini',
    icon: 'gemini',
    url: 'https://gemini.google.com',
  ),
  ServiceTarget(
    id: 'netflix',
    label: 'Netflix',
    icon: 'netflix',
    url: 'https://www.netflix.com',
  ),
  ServiceTarget(
    id: 'disney-plus',
    label: 'Disney+',
    icon: 'disneyplus',
    url: 'https://www.disneyplus.com',
  ),
  ServiceTarget(
    id: 'prime-video',
    label: 'Prime Video',
    icon: 'primevideo',
    url: 'https://www.primevideo.com',
  ),
  ServiceTarget(
    id: 'spotify',
    label: 'Spotify',
    icon: 'spotify',
    url: 'https://www.spotify.com',
  ),
  ServiceTarget(
    id: 'tiktok',
    label: 'TikTok',
    icon: 'tiktok',
    url: 'https://www.tiktok.com',
  ),
  ServiceTarget(
    id: 'discord',
    label: 'Discord',
    icon: 'discord',
    url: 'https://discord.com',
  ),
  ServiceTarget(
    id: 'bilibili',
    label: 'Bilibili',
    icon: 'bilibili',
    url: 'https://www.bilibili.com',
  ),
];

/// 卡片上展示的数量
const _cardServiceCount = 2;

const _amber = Color(0xFFF59E0B);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);
const _cardSurface = Color(0xFF141226);

/// 逐个探测服务，返回 id -> 延迟（<=0 表示失败）
Future<Map<String, int>> probeServices(
  List<ServiceTarget> targets,
  String proxyName, {
  void Function(String id, int delay)? onResult,
}) async {
  final result = <String, int>{};
  await Future.wait(
    targets.map((target) async {
      var value = -1;
      try {
        final delay = await clashCore
            .getDelay(target.url, proxyName)
            .timeout(const Duration(seconds: 8));
        value = delay.value ?? -1;
      } catch (_) {
        value = -1;
      }
      result[target.id] = value;
      onResult?.call(target.id, value);
    }),
  );
  return result;
}

/// 获取当前出口 IP 与归属国家代码
Future<(String?, String?)> fetchEgressIp() async {
  for (final endpoint in const [
    'https://api.ipify.org',
    'https://ifconfig.me/ip',
  ]) {
    try {
      final res = await http
          .get(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) continue;
      final ip = res.body.trim();
      if (!RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(ip)) continue;
      String? code;
      try {
        final info = await clashCore.getCountryCode(ip);
        code = info?.countryCode;
      } catch (_) {}
      return (ip, code);
    } catch (_) {
      continue;
    }
  }
  return (null, null);
}

String countryFlagEmoji(String? code) {
  if (code == null || code.length != 2) return '';
  final upper = code.toUpperCase();
  final first = upper.codeUnitAt(0) - 0x41 + 0x1F1E6;
  final second = upper.codeUnitAt(1) - 0x41 + 0x1F1E6;
  if (first < 0x1F1E6 || second < 0x1F1E6) return '';
  return String.fromCharCode(first) + String.fromCharCode(second);
}

/// 服务状态卡片：展示前两项，点击打开完整列表
class ServiceStatusCard extends StatefulWidget {
  const ServiceStatusCard({
    super.key,
    required this.proxyName,
  });

  /// 用于测速的节点 / 策略组名称
  final String proxyName;

  @override
  State<ServiceStatusCard> createState() => _ServiceStatusCardState();
}

class _ServiceStatusCardState extends State<ServiceStatusCard> {
  final Map<String, int?> _delays = {};
  bool _probing = false;

  List<ServiceTarget> get _targets =>
      serviceTargets.take(_cardServiceCount).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _probe();
    });
  }

  @override
  void didUpdateWidget(ServiceStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proxyName != widget.proxyName) {
      _probe();
    }
  }

  Future<void> _probe() async {
    if (_probing || widget.proxyName.isEmpty) return;
    setState(() {
      _probing = true;
      for (final target in _targets) {
        _delays[target.id] = null;
      }
    });
    await probeServices(_targets, widget.proxyName, onResult: (id, value) {
      if (mounted) setState(() => _delays[id] = value);
    });
    if (mounted) setState(() => _probing = false);
  }

  bool get _isDone =>
      _targets.every((t) => _delays[t.id] != null);

  int get _abnormalCount =>
      _targets.where((t) => (_delays[t.id] ?? 0) <= 0).length;

  Widget _buildVerdict() {
    if (!_isDone) {
      return _Verdict(
        label: '检测中',
        color: Colors.white.withValues(alpha: 0.55),
      );
    }
    final abnormal = _abnormalCount;
    if (abnormal > 0) {
      return _Verdict(label: '$abnormal 项异常', color: _amber);
    }
    return const _Verdict(label: '全部正常', color: _green);
  }

  void _openSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ServiceStatusSheet(proxyName: widget.proxyName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openSheet,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                const Text(
                  '服务状态',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                _buildVerdict(),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < _targets.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _buildCell(_targets[i])),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(ServiceTarget target) {
    final delay = _delays[target.id];
    final loading = delay == null;
    final failed = !loading && delay <= 0;
    final color = loading
        ? Colors.white.withValues(alpha: 0.55)
        : failed
            ? _red
            : Colors.white.withValues(alpha: 0.85);
    final label = loading
        ? '检测中'
        : failed
            ? '检测失败'
            : '$delay ms';

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          ServiceIconBadge(
            icon: target.icon,
            size: 26,
            radius: 8,
            dotColor: loading ? null : (failed ? _red : _green),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 完整服务状态列表
class ServiceStatusSheet extends StatefulWidget {
  const ServiceStatusSheet({
    super.key,
    required this.proxyName,
  });

  final String proxyName;

  @override
  State<ServiceStatusSheet> createState() => _ServiceStatusSheetState();
}

class _ServiceStatusSheetState extends State<ServiceStatusSheet> {
  final Map<String, int?> _delays = {};
  String? _ip;
  String? _countryCode;
  bool _probing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_probing) return;
    setState(() {
      _probing = true;
      for (final target in serviceTargets) {
        _delays[target.id] = null;
      }
    });
    unawaited(_loadIp());
    await probeServices(serviceTargets, widget.proxyName, onResult: (id, v) {
      if (mounted) setState(() => _delays[id] = v);
    });
    if (mounted) setState(() => _probing = false);
  }

  Future<void> _loadIp() async {
    final (ip, code) = await fetchEgressIp();
    if (mounted) {
      setState(() {
        _ip = ip;
        _countryCode = code;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Container(
      height: media.size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0E1D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      '服务状态',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _probing ? null : _refresh,
                  tooltip: '重新检测',
                  icon: _probing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.bolt,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: 12 + media.padding.bottom,
              ),
              itemCount: serviceTargets.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 60,
                color: Colors.white.withValues(alpha: 0.07),
              ),
              itemBuilder: (_, index) =>
                  _buildRow(serviceTargets[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(ServiceTarget target) {
    final delay = _delays[target.id];
    final loading = delay == null;
    final failed = !loading && delay <= 0;
    final flag = countryFlagEmoji(_countryCode);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          ServiceIconBadge(
            icon: target.icon,
            size: 42,
            radius: 12,
            dotColor: loading ? null : (failed ? _red : _green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (flag.isNotEmpty) ...[
                      Text(
                        flag,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        _ip ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: _ip == null
                              ? Colors.white.withValues(alpha: 0.4)
                              : _green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            loading
                ? '检测中'
                : failed
                    ? '检测失败'
                    : '$delay ms',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: loading
                  ? Colors.white.withValues(alpha: 0.5)
                  : failed
                      ? _red
                      : Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// 服务图标 + 右下角状态点
class ServiceIconBadge extends StatelessWidget {
  const ServiceIconBadge({
    super.key,
    required this.icon,
    required this.size,
    required this.radius,
    this.dotColor,
  });

  final String icon;
  final double size;
  final double radius;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final dot = size / 4.5;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: SvgPicture.asset(
              'assets/images/services/$icon.svg',
              width: size * 0.55,
              height: size * 0.55,
              colorFilter: ColorFilter.mode(
                Colors.white.withValues(alpha: 0.85),
                BlendMode.srcIn,
              ),
            ),
          ),
          if (dotColor != null)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  border: Border.all(color: _cardSurface, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

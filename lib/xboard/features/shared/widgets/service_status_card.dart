import 'dart:async';

import 'package:fl_clash/clash/clash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

const _serviceTargets = <ServiceTarget>[
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
];

const _amber = Color(0xFFF59E0B);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);

/// 服务状态卡片
///
/// 通过内核的延迟测试接口（走当前代理）探测各服务是否可用，
/// 用于直观判断当前节点能否正常访问常用服务。
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
  /// id -> 延迟；null 表示检测中，<=0 表示失败
  final Map<String, int?> _delays = {};
  bool _probing = false;

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
    if (_probing) return;
    if (widget.proxyName.isEmpty) return;
    setState(() {
      _probing = true;
      for (final target in _serviceTargets) {
        _delays[target.id] = null;
      }
    });
    await Future.wait(
      _serviceTargets.map((target) async {
        var value = -1;
        try {
          final delay = await clashCore
              .getDelay(target.url, widget.proxyName)
              .timeout(const Duration(seconds: 8));
          value = delay.value ?? -1;
        } catch (_) {
          value = -1;
        }
        if (mounted) {
          setState(() => _delays[target.id] = value);
        }
      }),
    );
    if (mounted) {
      setState(() => _probing = false);
    }
  }

  bool get _isDone =>
      _serviceTargets.every((target) => _delays.containsKey(target.id) && _delays[target.id] != null);

  int get _abnormalCount => _serviceTargets
      .where((target) => (_delays[target.id] ?? 0) <= 0)
      .length;

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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _probing ? null : _probe,
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
                for (var i = 0; i < _serviceTargets.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _buildCell(_serviceTargets[i])),
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
          SizedBox(
            width: 26,
            height: 26,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SvgPicture.asset(
                    'assets/images/services/${target.icon}.svg',
                    width: 15,
                    height: 15,
                    colorFilter: ColorFilter.mode(
                      Colors.white.withValues(alpha: 0.85),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                if (!loading)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: failed ? _red : _green,
                        border: Border.all(
                          color: const Color(0xFF141226),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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

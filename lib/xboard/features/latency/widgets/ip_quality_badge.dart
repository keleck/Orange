import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ip_quality_service.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/widgets/app_colors.dart';

/// 出口 IP 质量标签
///
/// 连接成功后走当前节点请求出口 IP 画像，展示两个胶囊：
/// 归属类型（住宅 / 商业 / 机房 …）与质量（质量优 / 良 / 一般 / 差）。
class IpQualityBadge extends ConsumerStatefulWidget {
  const IpQualityBadge({
    super.key,
    required this.proxyName,
    required this.enabled,
  });

  /// 当前展示的节点名（可能是组名，内部会解析到真实节点）
  final String proxyName;

  /// 是否已连接，未连接不展示也不评估
  final bool enabled;

  @override
  ConsumerState<IpQualityBadge> createState() => _IpQualityBadgeState();
}

class _IpQualityBadgeState extends ConsumerState<IpQualityBadge> {
  IpQuality? _quality;
  bool _evaluating = false;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted && widget.enabled) _evaluate();
      });
    }
  }

  @override
  void didUpdateWidget(covariant IpQualityBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      if (_quality != null || _evaluating) {
        _token++;
        _quality = null;
        _evaluating = false;
      }
      return;
    }
    final nodeChanged = oldWidget.proxyName != widget.proxyName;
    final justConnected = !oldWidget.enabled && widget.enabled;
    if (justConnected) {
      // 刚连上，等链路稳定后再查出口 IP
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted && widget.enabled) _evaluate(force: true);
      });
    } else if (nodeChanged) {
      _evaluate(force: true);
    }
  }

  Future<void> _evaluate({bool force = false}) async {
    final token = ++_token;
    final name = widget.proxyName;
    if (name.isEmpty || name == '未选择') {
      if (mounted) {
        setState(() {
          _quality = null;
          _evaluating = false;
        });
      }
      return;
    }

    final realName = ref.read(getProxyCardStateProvider(name)).proxyName;
    if (realName.isEmpty) return;

    if (mounted) {
      setState(() => _evaluating = true);
    }

    final result = await ipQualityService
        .evaluate(realName, force: force)
        .catchError((_) => IpQuality.unknown);

    if (!mounted || token != _token) return;
    setState(() {
      _quality = result;
      _evaluating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    final quality = _quality;
    if (!_evaluating && (quality == null || !quality.isKnown)) {
      return const SizedBox.shrink();
    }

    final level = quality?.level ?? IpQualityLevel.unknown;
    final usage = quality?.usage ?? IpUsageType.unknown;
    final (background, foreground) = _levelColors(level);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: quality == null ? null : () => _showDetail(quality),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: Row(
          key: ValueKey('${usage.name}-${level.name}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (usage != IpUsageType.unknown) ...[
              _pill(
                text: usage.label,
                background: AppColors.isDark(context)
                    ? Colors.white.withValues(alpha: 0.10)
                    : AppColors.lightSurfaceSubtle,
                foreground: AppColors.isDark(context)
                    ? Colors.white.withValues(alpha: 0.75)
                    : const Color(0xFF5A6270),
                borderColor: AppColors.outline(context),
              ),
              const SizedBox(width: 6),
            ],
            _pill(
              text: quality?.levelLabel ?? '质量评估中',
              background: background,
              foreground: foreground,
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(IpQuality quality) {
    final flags = <String>[
      if (quality.isProxy) '代理',
      if (quality.isVpn) 'VPN',
      if (quality.isTor) 'Tor',
      if (quality.isAbuser) '滥用',
    ];
    final rows = <String, String>{
      '出口 IP': quality.ip ?? '-',
      'IP 类型': quality.usageLabel,
      '所属组织': quality.asnOrg ?? '-',
      'ASN': quality.asn == null ? '-' : 'AS${quality.asn}',
      '风险标记': flags.isEmpty ? '无' : flags.join(' / '),
      '数据来源': quality.source ?? '-',
      '评估时间': quality.checkedAt == null
          ? '-'
          : '${quality.checkedAt!.hour.toString().padLeft(2, '0')}:'
              '${quality.checkedAt!.minute.toString().padLeft(2, '0')}',
    };

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B1A28),
        title: Text(
          'IP 质量详情',
          style: TextStyle(color: AppColors.fg(context), fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in rows.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          color: AppColors.fg(context).withValues(alpha: 0.55),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: AppColors.fg(context),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).xboardGotIt),
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required String text,
    required Color background,
    required Color foreground,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor, width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.15,
          letterSpacing: 0.2,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  (Color, Color) _levelColors(IpQualityLevel level) {
    return switch (level) {
      IpQualityLevel.excellent => (
          const Color(0xFF3DDC97),
          const Color(0xFF04281A),
        ),
      IpQualityLevel.good => (
          const Color(0xFF22C55E),
          const Color(0xFF04240F),
        ),
      IpQualityLevel.fair => (
          const Color(0xFFF0A93B),
          const Color(0xFF3A2400),
        ),
      IpQualityLevel.poor => (
          const Color(0xFFEF5350),
          const Color(0xFF3A0A0A),
        ),
      IpQualityLevel.unknown => (
          AppColors.surface(context, 0.12),
          AppColors.fg(context).withValues(alpha: 0.62),
        ),
    };
  }
}

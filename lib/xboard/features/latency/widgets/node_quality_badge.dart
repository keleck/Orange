import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/node_quality_service.dart';

/// 节点质量标签
///
/// 连接成功后自动对当前节点做质量评估（延迟 / 抖动 / 丢包），
/// 以胶囊标签的形式展示在节点名称下方，样式对齐上游「质量优」标签。
class NodeQualityBadge extends ConsumerStatefulWidget {
  const NodeQualityBadge({
    super.key,
    required this.proxyName,
    this.testUrl,
    required this.enabled,
  });

  /// 当前展示的节点名（可能是组名，内部会解析到真实节点）
  final String proxyName;

  /// 组自带的测速地址，为空时使用全局设置
  final String? testUrl;

  /// 是否已连接，未连接不展示也不评估
  final bool enabled;

  @override
  ConsumerState<NodeQualityBadge> createState() => _NodeQualityBadgeState();
}

class _NodeQualityBadgeState extends ConsumerState<NodeQualityBadge> {
  NodeQuality? _quality;
  bool _evaluating = false;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      // 内核刚启动时立即测速容易失败，稍等一下再评估
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted && widget.enabled) _evaluate();
      });
    }
  }

  @override
  void didUpdateWidget(covariant NodeQualityBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      if (_quality != null || _evaluating) {
        _token++;
        // didUpdateWidget 之后必然重建，直接清状态即可
        _quality = null;
        _evaluating = false;
      }
      return;
    }
    final nodeChanged = oldWidget.proxyName != widget.proxyName;
    final justConnected = !oldWidget.enabled && widget.enabled;
    if (justConnected) {
      // 刚连上，等链路稳定后再评估
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

    final cardState = ref.read(getProxyCardStateProvider(name));
    final realName = cardState.proxyName;
    if (realName.isEmpty) return;

    final url = cardState.testUrl.getSafeValue(
      ref.read(getRealTestUrlProvider(widget.testUrl)),
    );

    if (mounted) {
      setState(() => _evaluating = true);
    }

    final result = await nodeQualityService
        .evaluate(realName, url, force: force)
        .catchError((_) => NodeQuality.unknown);

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

    final level = quality?.level ?? NodeQualityLevel.unknown;
    final (background, foreground) = _colors(level);
    final text = quality?.label ?? '质量评估中';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: foreground,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            height: 1.15,
            letterSpacing: 0.2,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  (Color, Color) _colors(NodeQualityLevel level) {
    return switch (level) {
      NodeQualityLevel.excellent => (
          const Color(0xFF3DDC97),
          const Color(0xFF04281A),
        ),
      NodeQualityLevel.good => (
          const Color(0xFF22C55E),
          const Color(0xFF04240F),
        ),
      NodeQualityLevel.fair => (
          const Color(0xFFF0A93B),
          const Color(0xFF3A2400),
        ),
      NodeQualityLevel.poor => (
          const Color(0xFFEF5350),
          const Color(0xFF3A0A0A),
        ),
      NodeQualityLevel.unknown => (
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.62),
        ),
    };
  }
}

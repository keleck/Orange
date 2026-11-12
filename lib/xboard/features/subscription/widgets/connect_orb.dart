import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 连接按钮的圆盘直径
const double kConnectDiscSize = 180;

/// 顺时针但不规则的绕圈位移。
///
/// 频率全部取整数倍：theta 走满 2π 时正好回到起点，
/// 循环播放不会有接缝跳变（非整数倍会在每圈末尾突然跳一下）。
Offset connectOrbitOffset(double t, {double phase = 0}) {
  final theta = t * 2 * math.pi;
  final angle = theta +
      0.55 * math.sin(theta * 2 + phase) +
      0.30 * math.sin(theta * 3 + phase);
  final radius =
      8 + 2 * math.sin(theta * 2 + phase) + 1.5 * math.sin(theta * 3 + phase);
  return Offset(math.cos(angle) * radius, math.sin(angle) * radius);
}

/// 圆盘背后叠着的三个半透明圆。
///
/// 逐帧量实机得到：绿色从盘边一直铺到盘径 +25 左右，但覆盖率从 52% 平滑衰减到 5%，
/// 说明它不是一条实边，而是几个半透明圆错相位叠出来的：
/// 重叠多的地方浓、重叠少的地方淡，边缘自然渐隐，转动时就会呈现「圆角」般的柔和过渡。
/// 每层的透明度还随角度轻微呼吸，进一步打散硬边。
class ConnectRingPainter extends CustomPainter {
  final double progress;
  final bool active;
  final double opacity;
  final double discSize;

  const ConnectRingPainter({
    required this.progress,
    required this.active,
    this.opacity = 1,
    this.discSize = kConnectDiscSize,
  });

  static const Color _mint = Color(0xFF7FE3C6);
  static const Color _teal = Color(0xFF1E7F66);
  static const Color _deep = Color(0xFF0E4B3E);
  static const Color _greyLight = Color(0xFF4A535E);
  static const Color _greyMid = Color(0xFF3A424C);
  static const Color _greyDeep = Color(0xFF262C34);

  // 三层：半径增量 / 相位 / 基础透明度
  static const List<double> _radiusStep = [3, 8, 14];
  static const List<double> _phase = [0.0, 2.1, 4.2];
  static const List<double> _baseAlpha = [0.55, 0.45, 0.38];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final colors = active
        ? const [_mint, _teal, _deep]
        : const [_greyLight, _greyMid, _greyDeep];
    final theta = progress * 2 * math.pi;

    for (var i = 0; i < 3; i++) {
      // 透明度随转动轻微呼吸，让叠加处一直在变，边缘不会出现固定硬边
      final breathe = 1 + 0.18 * math.sin(theta * 2 + _phase[i]);
      final alpha = (_baseAlpha[i] * breathe).clamp(0.18, 0.85) * opacity;
      canvas.drawCircle(
        center + connectOrbitOffset(progress, phase: _phase[i]),
        discSize * 0.5 + _radiusStep[i],
        Paint()..color = colors[i].withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(ConnectRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.active != active ||
        oldDelegate.opacity != opacity ||
        oldDelegate.discSize != discSize;
  }
}

/// 手绘感闪电：粗笔触多边形 + 米白描边 + 外发光。
class HandDrawnBoltPainter extends CustomPainter {
  final Color color;
  final Color outline;

  const HandDrawnBoltPainter({
    this.color = const Color(0xFFFFE52E),
    this.outline = const Color(0xFFFFF7C9),
  });

  static const List<Offset> _points = [
    Offset(0.60, 0.03),
    Offset(0.21, 0.56),
    Offset(0.46, 0.56),
    Offset(0.38, 0.97),
    Offset(0.83, 0.42),
    Offset(0.55, 0.42),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    // 外发光
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.14),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.05),
    );
    // 主体：左上亮、右下略暗，避免整块纯色显得平
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFFFF27A), color],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.fill
        ..strokeJoin = StrokeJoin.round,
    );
    // 米白描边
    canvas.drawPath(
      path,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.032
        ..strokeJoin = StrokeJoin.round,
    );
  }

  Path _buildPath(Size size) {
    final points = _points
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();
    final center = size.center(Offset.zero);
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      final mid = Offset(
        (current.dx + next.dx) / 2,
        (current.dy + next.dy) / 2,
      );
      final direction = mid - center;
      final push = direction.distance == 0
          ? Offset.zero
          : direction / direction.distance * (size.width * 0.015);
      path.quadraticBezierTo(
        mid.dx + push.dx,
        mid.dy + push.dy,
        next.dx,
        next.dy,
      );
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(HandDrawnBoltPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.outline != outline;
  }
}

/// 连接后的黑色圆盘 + 手绘闪电
///
/// 盘自身带一层向下投影，压在背后的绿环上，形成「盘浮在环上」的层次。
class ConnectActiveDisc extends StatelessWidget {
  final double size;

  const ConnectActiveDisc({super.key, this.size = kConnectDiscSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.25, -0.3),
          radius: 0.95,
          colors: [Color(0xFF1B1815), Color(0xFF0B0A09), Color(0xFF060606)],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: Center(
        child: Transform.rotate(
          angle: 0.10,
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size(size * 0.68, size * 0.90),
              painter: const HandDrawnBoltPainter(),
            ),
          ),
        ),
      ),
    );
  }
}

/// 未连接的圆盘：深灰蓝实色 + 内缩一圈细白线
class ConnectIdleDisc extends StatelessWidget {
  final double size;
  final Color color;

  const ConnectIdleDisc({
    super.key,
    this.size = kConnectDiscSize,
    this.color = const Color(0xFF1D2229),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: Padding(
        // 实机里那圈细白线是内缩的，不是贴着盘边
        padding: EdgeInsets.all(size * 0.045),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 1.4,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.power_settings_new_rounded,
              size: size * 0.42,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ),
      ),
    );
  }
}

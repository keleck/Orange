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
      9 + 4 * math.sin(theta * 2 + phase) + 3 * math.sin(theta * 3 + phase);
  return Offset(math.cos(angle) * radius, math.sin(angle) * radius);
}

/// 圆盘背后那两层环。
///
/// 实机放大图里是两圈：外圈浅薄荷、内圈深青绿，两者圆心有偏移，
/// 所以在同一侧露出两道月牙；圆盘压在上面并投下阴影，层次就是这么来的。
/// 未连接时同样的结构换成灰色。
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

  // 连接后
  static const Color _outerActive = Color(0xFF5CC3A4);
  static const Color _innerActive = Color(0xFF17594C);
  // 未连接
  static const Color _outerIdle = Color(0xFF343B44);
  static const Color _innerIdle = Color(0xFF262C34);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final t = progress;

    // 外圈：偏得更多一点，露出更宽的一道
    final outerCenter = center + connectOrbitOffset(t, phase: 0);
    final outerRadius = discSize * 0.5 + 14;
    canvas.drawCircle(
      outerCenter,
      outerRadius,
      Paint()
        ..color = (active ? _outerActive : _outerIdle)
            .withValues(alpha: (active ? 0.42 : 0.85) * opacity),
    );

    // 内圈：偏移相位错开，两道月牙不会完全重合
    final innerCenter = center + connectOrbitOffset(t, phase: 2.1);
    final innerRadius = discSize * 0.5 + 6;
    canvas.drawCircle(
      innerCenter,
      innerRadius,
      Paint()
        ..color = (active ? _innerActive : _innerIdle)
            .withValues(alpha: (active ? 0.95 : 0.95) * opacity),
    );
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
    // 主体
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..strokeJoin = StrokeJoin.round,
    );
    // 米白描边
    canvas.drawPath(
      path,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.028
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 6),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Transform.rotate(
          angle: 0.10,
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size(size * 0.68, size * 0.74),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 6),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
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

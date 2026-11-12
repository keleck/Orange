import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 连接按钮的圆盘直径
const double kConnectDiscSize = 180;

/// 顺时针但不规则的绕圈位移：
/// 基础角速度 theta 上叠加两条不同频率的正弦，让角速度时快时慢；
/// 半径也做周期伸缩，避免看起来像机械匀速转圈。
Offset connectOrbitOffset(double t) {
  final theta = t * 2 * math.pi;
  final angle = theta +
      0.55 * math.sin(theta * 2.0) +
      0.30 * math.sin(theta * 3.3 + 1.1);
  final radius =
      17 + 8 * math.sin(theta * 1.6 + 0.4) + 5 * math.sin(theta * 2.7 + 2.0);
  return Offset(math.cos(angle) * radius, math.sin(angle) * radius);
}

/// 连接后的光晕：手绘感的不规则圆环。
///
/// 参考效果里它不是一圈均匀的模糊发光，而像用马克笔绕着圆盘画了一圈：
/// 边界有轻微起伏、整体偏离圆心、内侧是暗青绿色带、外沿是一条薄荷色描边。
/// 这里用一条「半径带谐波扰动」的闭合路径来画，并让它顺时针缓慢转动。
class ConnectHaloPainter extends CustomPainter {
  final double progress;
  final double opacity;

  final double discSize;

  const ConnectHaloPainter({
    required this.progress,
    this.opacity = 1,
    this.discSize = kConnectDiscSize,
  });

  static const Color _band = Color(0xFF1B7A61);
  static const Color _edge = Color(0xFF7FE3C6);

  @override
  void paint(Canvas canvas, Size size) {
    final theta = progress * 2 * math.pi;
    final angle = theta +
        0.55 * math.sin(theta * 2.0) +
        0.30 * math.sin(theta * 3.3 + 1.1);
    // 偏移要明显大于环与圆盘的半径差，才会露出参考图里那种偏心的月牙带
    final orbitRadius =
        21 + 6 * math.sin(theta * 1.6 + 0.4) + 4 * math.sin(theta * 2.7 + 2.0);
    final center = size.center(Offset.zero) +
        Offset(math.cos(angle) * orbitRadius, math.sin(angle) * orbitRadius);
    final baseRadius = discSize * 0.5 + 9;

    final path = _blobPath(center, baseRadius, theta * 0.55);

    // 实心青绿环带：叠在页面底色上偏暗，但不像发光那样发虚
    canvas.drawPath(
      path,
      Paint()
        ..color = _band.withValues(alpha: 0.92 * opacity)
        ..style = PaintingStyle.fill,
    );
    // 外沿薄荷色细描边
    canvas.drawPath(
      path,
      Paint()
        ..color = _edge.withValues(alpha: 0.75 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// 半径做三组不同频率的谐波扰动，形成「手画歪了一点」的闭合轮廓
  Path _blobPath(Offset center, double radius, double phase) {
    final path = Path();
    const steps = 200;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * 2 * math.pi;
      final wobble = 1 +
          0.030 * math.sin(a * 3 + phase * 1.3) +
          0.019 * math.sin(a * 5 - phase * 0.9) +
          0.010 * math.sin(a * 8 + phase * 1.7);
      final r = radius * wobble;
      final point = Offset(
        center.dx + math.cos(a) * r,
        center.dy + math.sin(a) * r,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(ConnectHaloPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.opacity != opacity;
  }
}

/// 手绘感闪电：粗笔触多边形 + 米白描边 + 外发光。
///
/// 直接用品字形图标会太「标准」，参考里的闪电边缘是手画的、有粗细变化，
/// 所以这里自己描一条闭合路径，顶点连线用二次贝塞尔轻微外鼓模拟笔触。
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

    // 两层外发光：大范围柔光 + 紧贴笔画的一层亮边
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.50)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.13),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.40)
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
        ..strokeWidth = size.width * 0.030
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
class ConnectActiveDisc extends StatelessWidget {
  final double size;

  const ConnectActiveDisc({super.key, this.size = kConnectDiscSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.2, -0.25),
          radius: 0.9,
          colors: [Color(0xFF141210), Color(0xFF070605)],
        ),
      ),
      child: Center(
        child: Transform.rotate(
          angle: 0.10,
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size(size * 0.56, size * 0.74),
              painter: const HandDrawnBoltPainter(),
            ),
          ),
        ),
      ),
    );
  }
}

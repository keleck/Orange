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

/// 连接后的光晕：圆盘背后那圈青绿色带子。
///
/// 实机效果里它不是一条均匀描边，而是一圈有体积的带子：
/// 内侧压暗、外侧提亮到薄荷色，整体偏离圆心缓慢绕行，
/// 再叠上圆盘自己投下的阴影，才有「环在后面、盘浮在上面」的层次。
class ConnectHaloPainter extends CustomPainter {
  final double progress;
  final double opacity;
  final double discSize;

  const ConnectHaloPainter({
    required this.progress,
    this.opacity = 1,
    this.discSize = kConnectDiscSize,
  });

  static const Color _inner = Color(0xFF0B3F33);
  static const Color _mid = Color(0xFF1E7F66);
  static const Color _edge = Color(0xFF79E0BF);

  @override
  void paint(Canvas canvas, Size size) {
    final theta = progress * 2 * math.pi;
    final angle = theta +
        0.55 * math.sin(theta * 2.0) +
        0.30 * math.sin(theta * 3.3 + 1.1);
    // 环只比圆盘大一点点，再整体偏移，露出来的才是月牙状的一条带
    final orbitRadius =
        7 + 4 * math.sin(theta * 1.6 + 0.4) + 2.5 * math.sin(theta * 2.7 + 2.0);
    final center = size.center(Offset.zero) +
        Offset(math.cos(angle) * orbitRadius, math.sin(angle) * orbitRadius);
    final baseRadius = discSize * 0.5 + 6;

    final path = _blobPath(center, baseRadius, theta * 0.55);
    final rect = Rect.fromCircle(center: center, radius: baseRadius);

    // 带子的体积感：由内到外 深青 -> 青 -> 薄荷
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _inner.withValues(alpha: opacity),
            _mid.withValues(alpha: opacity),
            _edge.withValues(alpha: opacity),
          ],
          stops: const [0.86, 0.955, 1.0],
        ).createShader(rect),
    );

    // 外沿再压一条极细的高光，边界更利落
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFA5F0D6).withValues(alpha: 0.55 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
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
          0.022 * math.sin(a * 3 + phase * 1.3) +
          0.014 * math.sin(a * 5 - phase * 0.9) +
          0.008 * math.sin(a * 8 + phase * 1.7);
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
    return oldDelegate.progress != progress ||
        oldDelegate.opacity != opacity ||
        oldDelegate.discSize != discSize;
  }
}

/// 手绘感闪电：粗笔触多边形 + 米白描边 + 外发光。
///
/// 直接用品字形图标会太「标准」，实机里闪电边缘是手画的、有粗细变化，
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
        ..color = color.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.16),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.06),
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
/// 圆盘自身带一层向下的投影，会压在背后的青绿环带上，
/// 这样「环在下面、盘浮在上面」的层次才出来。
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
          colors: [Color(0xFF1A1714), Color(0xFF0A0908), Color(0xFF050505)],
          stops: [0.0, 0.62, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            offset: const Offset(0, 7),
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
              size: Size(size * 0.57, size * 0.59),
              painter: const HandDrawnBoltPainter(),
            ),
          ),
        ),
      ),
    );
  }
}

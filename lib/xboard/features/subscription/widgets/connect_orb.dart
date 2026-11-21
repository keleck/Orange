import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_clash/widgets/app_colors.dart';

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
      10 + 3 * math.sin(theta * 2 + phase) + 2 * math.sin(theta * 3 + phase);
  return Offset(math.cos(angle) * radius, math.sin(angle) * radius);
}

/// 圆盘背后三层整圆（被盘盖住，只露出外面那一部分）。
///
/// 是完整的圆、不是切出来的弧段，所以露出的两端自然收窄、没有硬边。
/// 三层半径与偏移依次加大，露出宽度逐层递减；整体绕盘顺时针旋转。
/// 偏移量是固定的（只有方向在转），不能做成呼吸式，否则转到某些角度
/// 三层会缩回去、看起来又变成一圈均匀环。
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

  static const Color _mint = Color(0xFF9BE7C4);
  static const Color _teal = Color(0xFF3EA34B);
  static const Color _deep = Color(0xFF2E7D32);
  static const Color _greySolid = Color(0xFF5A636E);
  static const Color _greyMid = Color(0xFF454E58);
  static const Color _greyDeep = Color(0xFF333A42);

  // 半径增量 / 固定偏移距离 / 透明度
  static const List<double> _radiusStep = [3, 7, 11];
  static const List<double> _orbitDistance = [8, 12, 16];
  static const List<double> _alpha = [0.40, 0.28, 0.20];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final colors = active
        ? const [_mint, _teal, _deep]
        : const [_greySolid, _greyMid, _greyDeep];
    final theta = progress * 2 * math.pi;

    for (var i = 0; i < 3; i++) {
      // 方向随转动走，距离固定
      final angle = theta + i * 2.1;
      final orbit = Offset(
        math.cos(angle) * _orbitDistance[i],
        math.sin(angle) * _orbitDistance[i],
      );
      canvas.drawCircle(
        center + orbit,
        discSize * 0.5 + _radiusStep[i],
        Paint()..color = colors[i].withValues(alpha: _alpha[i] * opacity),
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

/// 连接后的圆盘：深绿色底 + 与未连接一致的白色线条电源图标
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
          center: Alignment(-0.3, -0.35),
          radius: 1.0,
          colors: [Color(0xFF4CAF50), Color(0xFF3EA34B), Color(0xFF348C40)],
          stops: [0.0, 0.62, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // 内缩的细白圈，与未连接保持一致
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(size * 0.045),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.power_settings_new_rounded,
              size: size * 0.42,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// 未连接的圆盘：深灰蓝实色 + 内缩一圈细白线
class ConnectIdleDisc extends StatelessWidget {
  final double size;
  final Color? color;
  final double progress;

  const ConnectIdleDisc({
    super.key,
    this.size = kConnectDiscSize,
    this.color,
    this.progress = 0,
  });

  @override
  Widget build(BuildContext context) {
    // 白天用柔和白盘 + 深色描边，夜间保持深灰蓝
    final discColor = color ??
        (AppColors.isDark(context)
            ? const Color(0xFF1D2229)
            : AppColors.lightSurface);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // 盘面
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: discColor,
            ),
          ),
          // 内缩的细白圈（正圆）
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(size * 0.045),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.fg(context).withValues(alpha: 0.85),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.power_settings_new_rounded,
              size: size * 0.42,
              color: AppColors.fg(context).withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

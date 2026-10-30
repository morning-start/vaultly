import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/theme/vaultly_colors.dart';

/// 保险库表盘徽记（原型 `.dial`）
///
/// 外层虚线刻度环 + 内环 + 核心圆（surface 底、line-strong 描边、投影），
/// 中心为盾牌图标。解锁页（128）、创建页（96）、启动页（104）复用。
class VaultDial extends StatelessWidget {
  final double size;
  final IconData icon;

  const VaultDial({
    super.key,
    this.size = 128,
    this.icon = Icons.shield_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final coreInset = size * 17 / 128;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DialTicksPainter(color: colorScheme.hairlineStrong),
          ),
          Padding(
            padding: EdgeInsets.all(coreInset),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surfaceCard,
                border: Border.all(color: colorScheme.hairlineStrong),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(90),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: size * 40 / 128,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 绘制虚线刻度环与内环
class _DialTicksPainter extends CustomPainter {
  _DialTicksPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = size.width / 2 - 3;

    final ticksPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color;

    const dash = 2.0;
    const gap = 7.4;
    final circumference = 2 * math.pi * outerRadius;
    final count = (circumference / (dash + gap)).floor();
    final step = 2 * math.pi / count;
    final dashAngle = dash / outerRadius;
    final rect = Rect.fromCircle(center: center, radius: outerRadius);

    for (var i = 0; i < count; i++) {
      canvas.drawArc(rect, i * step, dashAngle, false, ticksPaint);
    }

    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withAlpha(153);
    canvas.drawCircle(center, size.width * 50 / 128, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _DialTicksPainter oldDelegate) =>
      oldDelegate.color != color;
}

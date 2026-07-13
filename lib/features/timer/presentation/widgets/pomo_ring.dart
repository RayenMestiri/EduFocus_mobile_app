import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Glowing gradient progress ring — the visual heart of the timer screen.
class PomoRing extends StatelessWidget {
  const PomoRing({
    super.key,
    required this.progress,
    required this.isBreak,
    required this.child,
  });

  /// 1 → full ring, 0 → empty.
  final double progress;
  final bool isBreak;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RingPainter(progress: progress, isBreak: isBreak),
      child: Center(child: child),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.isBreak});

  final double progress;
  final bool isBreak;

  static const _stroke = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - _stroke) / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final colors = isBreak
        ? const [AppColors.green, Color(0xFF059669)]
        : const [AppColors.accentBright, AppColors.indigo];

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..color = AppColors.surfaceHover,
    );

    if (progress <= 0) return;
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);

    // Soft glow underneath the arc
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke + 8
        ..strokeCap = StrokeCap.round
        ..color = colors.first.withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Gradient arc
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [colors.first, colors.last, colors.first],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.isBreak != isBreak;
}

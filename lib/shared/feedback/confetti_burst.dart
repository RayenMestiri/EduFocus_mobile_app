import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lightweight, dependency-free confetti burst — rectangles and circles
/// falling with gravity, drift and rotation, staggered by delay. Plays once
/// on mount; wrap in a fixed-size [SizedBox] positioned behind a modal card.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.colors, this.particleCount = 70});

  final List<Color>? colors;
  final int particleCount;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();

  late final List<_Particle> _particles = _generate();

  List<_Particle> _generate() {
    final rand = math.Random();
    final palette =
        widget.colors ??
        const [
          Color(0xFF8B5CF6),
          Color(0xFFF59E0B),
          Color(0xFF34D399),
          Color(0xFF60A5FA),
          Color(0xFFF87171),
          Color(0xFFFBBF24),
        ];
    return List.generate(widget.particleCount, (_) {
      return _Particle(
        x: rand.nextDouble(),
        delay: rand.nextDouble() * .25,
        fallSpeed: .7 + rand.nextDouble() * .6,
        drift: (rand.nextDouble() - .5) * .5,
        size: 5 + rand.nextDouble() * 6,
        color: palette[rand.nextInt(palette.length)],
        spin: (rand.nextDouble() - .5) * 10,
        isCircle: rand.nextBool(),
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(_particles, _c.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.delay,
    required this.fallSpeed,
    required this.drift,
    required this.size,
    required this.color,
    required this.spin,
    required this.isCircle,
  });

  final double x, delay, fallSpeed, drift, size, spin;
  final Color color;
  final bool isCircle;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.particles, this.t);

  final List<_Particle> particles;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = size.height * local * p.fallSpeed - size.height * .15;
      if (y < -20 || y > size.height + 20) continue;
      final x = size.width * p.x + size.width * p.drift * local;
      final fadeOut = local > .82 ? (1 - local) / .18 : 1.0;
      final paint = Paint()
        ..color = p.color.withValues(alpha: fadeOut.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local * math.pi);
      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * .6,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}

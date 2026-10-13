import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'palette.dart';

/// First-launch artwork with real, clearly visible animation.
/// Decorative orbit lights are not members, location dots, or fake activity.
class AnimatedHeartHero extends StatefulWidget {
  const AnimatedHeartHero({this.size = 228, super.key});

  final double size;

  @override
  State<AnimatedHeartHero> createState() => _AnimatedHeartHeroState();
}

class _AnimatedHeartHeroState extends State<AnimatedHeartHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = .18;
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        key: const ValueKey('dilemin-animated-heart-hero'),
        width: widget.size,
        height: widget.size,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
              final progress = _motion.value;
              final pulse = math.sin(progress * math.pi * 2);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: HeartOrbitPainter(progress: progress),
                    ),
                  ),
                  Transform.scale(
                    scale: 1 + pulse * .035,
                    child: Container(
                      width: widget.size * .38,
                      height: widget.size * .38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFF84AF),
                            Palette.rose,
                            Color(0xFF9A48CB),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .45),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Palette.rose.withValues(alpha: .32 + pulse * .08),
                            blurRadius: 34,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: widget.size * .19,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Painted vector rings, an orbiting highlight, particles and a rotating arc.
/// No network assets or native animation runtimes are required.
class HeartOrbitPainter extends CustomPainter {
  const HeartOrbitPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .43;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final aura = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFF4B96).withValues(alpha: .18),
          const Color(0xFF844EE8).withValues(alpha: .07),
          Colors.transparent,
        ],
        stops: const [0, .58, 1],
      ).createShader(bounds);
    canvas.drawCircle(center, radius, aura);

    for (var i = 1; i <= 3; i++) {
      final r = radius * (.43 + i * .19);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 3 ? 1.5 : 1
          ..color = (i.isEven ? Palette.rose : const Color(0xFF9B7DFF))
              .withValues(alpha: i == 3 ? .40 : .23),
      );
    }

    final sweep = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.5
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Palette.rose.withValues(alpha: .0),
          const Color(0xFFFFAED1).withValues(alpha: .95),
          Colors.transparent,
        ],
        stops: const [0, .55, .78, 1],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(bounds);
    canvas.drawArc(bounds, 0, math.pi * 2, false, sweep);

    final starAngles = [0.1, 1.7, 3.25, 4.9, 5.8];
    for (var i = 0; i < starAngles.length; i++) {
      final theta = starAngles[i] + progress * math.pi * (i.isEven ? 2 : -2);
      final r = radius * (i.isEven ? .86 : .65);
      final pos = Offset(
        center.dx + math.cos(theta) * r,
        center.dy + math.sin(theta) * r,
      );
      final alpha = .42 + .40 * ((1 + math.sin(progress * 2 * math.pi + i)) / 2);
      canvas.drawCircle(pos, i.isEven ? 3.2 : 2.3,
          Paint()..color = Colors.white.withValues(alpha: alpha));
      canvas.drawCircle(pos, i.isEven ? 7 : 5,
          Paint()..color = Palette.rose.withValues(alpha: alpha * .14));
    }
  }

  @override
  bool shouldRepaint(covariant HeartOrbitPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

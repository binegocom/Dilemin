import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// Subtle Flame particle field around visible profiles, independent of GPS.
class RadarParticleGame extends FlameGame {
  RadarParticleGame() {
    final rng = math.Random(0xD11E);
    _particles = List.generate(16, (_) => _Particle(
      angle: rng.nextDouble() * math.pi * 2,
      distance: .17 + rng.nextDouble() * .25,
      phase: rng.nextDouble() * math.pi * 2,
      radius: .9 + rng.nextDouble() * 1.6,
    ));
  }

  late final List<_Particle> _particles;
  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed = (_elapsed + dt) % 1000;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final side = math.min(size.x, size.y);
    if (side <= 0) return;
    for (final spark in _particles) {
      final glow = (math.sin(_elapsed * 1.2 + spark.phase) + 1) / 2;
      final distance = side * (spark.distance + glow * .015);
      final center = Offset(
        size.x / 2 + math.cos(spark.angle) * distance,
        size.y / 2 + math.sin(spark.angle) * distance,
      );
      canvas.drawCircle(
        center,
        spark.radius,
        Paint()..color = const Color(0xFFFFA5C5).withValues(alpha: .12 + glow * .55),
      );
    }
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.distance,
    required this.phase,
    required this.radius,
  });

  final double angle;
  final double distance;
  final double phase;
  final double radius;
}

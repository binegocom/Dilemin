import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flame/game.dart';

import '../../core/models.dart';
import '../../core/api_client.dart';
import '../photos/private_avatar.dart';
import '../animations/radar_glow.dart';
import '../animations/radar_particles.dart';

// Display positions are stable, schematic markers and never user coordinates.
Offset markerPosition(String userId, Size size) {
  final hash = userId.codeUnits.fold<int>(2166136261, (value, code) =>
      ((value ^ code) * 16777619) & 0xffffffff);
  final angle = ((hash & 0xffff) / 65535) * math.pi * 2;
  final fraction = .30 + (((hash >> 16) & 0xffff) / 65535) * .55;
  return Offset(
    size.width / 2 + math.cos(angle) * size.shortestSide * .43 * fraction,
    size.height / 2 + math.sin(angle) * size.shortestSide * .43 * fraction,
  );
}

class RadarCanvas extends StatefulWidget {
  const RadarCanvas({
    required this.people,
    required this.centerName,
    this.api,
    this.centerUserId,
    this.centerPhotoId,
    this.onPersonTap,
    super.key,
  });
  final List<OnlinePerson> people;
  final String centerName;
  final ApiClient? api;
  final String? centerUserId;
  final String? centerPhotoId;
  final ValueChanged<OnlinePerson>? onPersonTap;

  @override
  State<RadarCanvas> createState() => _RadarCanvasState();
}

class _RadarCanvasState extends State<RadarCanvas> with SingleTickerProviderStateMixin {
  final RadarParticleGame _particles = RadarParticleGame();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(builder: (context, constraints) {
        final side = constraints.maxWidth;
        final size = Size(side, side);
        final people = widget.people.take(10).toList(growable: false);
        return Stack(
          children: [
            Positioned.fill(child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => CustomPaint(painter: _RadarPainter(progress: _controller.value)),
            )),
            Positioned.fill(
              child: IgnorePointer(child: RadarGlow(progress: _controller)),
            ),
            if (!reduceMotion && people.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(child: GameWidget(game: _particles)),
              ),
            for (final person in people)
              _avatar(person: person, position: markerPosition(person.id, size), size: 48),
            _avatar(person: OnlinePerson(
                id: widget.centerUserId ?? 'me',
                name: widget.centerName,
                photoId: widget.centerPhotoId,
              ),
              position: Offset(side / 2, side / 2), size: 68, center: true),
          ],
        );
      }),
    );
  }

  Widget _avatar({required OnlinePerson person, required Offset position,
      required double size, bool center = false}) {
    final label = person.name.trim();
    return Positioned(
      left: position.dx - size / 2, top: position.dy - size / 2,
      child: Semantics(
        label: label,
        button: !center,
        child: GestureDetector(
          onTap: center ? null : () => widget.onPersonTap?.call(person),
          child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: center ? const Color(0xFFFF79AB) : const Color(0xFF47DFB4), width: 2),
            gradient: const LinearGradient(colors: [Color(0xFF6D355A), Color(0xFF363763)]),
            boxShadow: [BoxShadow(color: const Color(0xFFFF4B86).withValues(alpha: center ? .34 : .14),
              blurRadius: 20, spreadRadius: 3)],
          ),
          child: Center(
            child: widget.api != null && person.photoId != null
                ? PrivateAvatar(
                    api: widget.api!,
                    userId: person.id,
                    name: person.name,
                    photoId: person.photoId,
                    size: size - 5,
                    isOnline: false,
                  )
                : Text(label.isEmpty ? '•' : label.characters.first.toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: center ? 26 : 17)),
          ),
        )),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .47;
    final circle = Paint()..style = PaintingStyle.stroke;
    final glow = Paint()..shader = RadialGradient(
      colors: [const Color(0xFFED3E82).withValues(alpha: .17), Colors.transparent],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glow);
    for (var index = 1; index <= 4; index++) {
      circle
        ..strokeWidth = index == 4 ? 1.3 : 1
        ..color = const Color(0xFFB75893).withValues(alpha: index == 4 ? .38 : .20);
      canvas.drawCircle(center, radius * index / 4, circle);
    }
    final crosshair = Paint()..strokeWidth = 1
      ..color = const Color(0xFF934F86).withValues(alpha: .15);
    canvas.drawLine(Offset(center.dx - radius, center.dy),
        Offset(center.dx + radius, center.dy), crosshair);
    canvas.drawLine(Offset(center.dx, center.dy - radius),
        Offset(center.dx, center.dy + radius), crosshair);

    final sweepPaint = Paint()..shader = SweepGradient(
      startAngle: 0, endAngle: math.pi * 2,
      colors: [Colors.transparent, const Color(0xFFFF66A3).withValues(alpha: .02),
        const Color(0xFFFF66A3).withValues(alpha: .20), Colors.transparent],
      stops: const [0, .55, .94, 1],
      transform: GradientRotation(progress * math.pi * 2),
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => oldDelegate.progress != progress;
}

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// GPU light layer. Radar coordinates are illustrative, never geolocation.
class RadarGlow extends StatefulWidget {
  const RadarGlow({required this.progress, super.key});

  final Animation<double> progress;

  @override
  State<RadarGlow> createState() => _RadarGlowState();
}

class _RadarGlowState extends State<RadarGlow> {
  ui.FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/radar_glow.frag');
      if (mounted) setState(() => _program = program);
    } catch (_) {
      // Base radar remains functional on unsupported GPU/renderers.
    }
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;
    if (program == null) return const SizedBox.expand();
    return AnimatedBuilder(
      animation: widget.progress,
      builder: (context, _) => CustomPaint(
        painter: _RadarGlowPainter(
          program: program,
          progress: widget.progress.value,
          strength: MediaQuery.disableAnimationsOf(context) ? 0.2 : 1,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _RadarGlowPainter extends CustomPainter {
  _RadarGlowPainter({
    required this.program,
    required this.progress,
    required this.strength,
  });

  final ui.FragmentProgram program;
  final double progress;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shader = program.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, progress)
      ..setFloat(3, strength);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _RadarGlowPainter other) =>
      other.program != program ||
      other.progress != progress ||
      other.strength != strength;
}

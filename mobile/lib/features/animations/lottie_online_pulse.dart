import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieOnlinePulse extends StatelessWidget {
  const LottieOnlinePulse({super.key});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4CE0B6)),
      );
    }
    return Lottie.asset(
      'assets/lottie/online_pulse.json',
      repeat: true,
      frameRate: FrameRate.max,
      fit: BoxFit.contain,
    );
  }
}

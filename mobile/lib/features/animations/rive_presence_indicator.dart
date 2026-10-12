import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

/// A locally bundled Rive icon; never blocks app startup on native load failure.
class RivePresenceIndicator extends StatefulWidget {
  const RivePresenceIndicator({super.key});

  @override
  State<RivePresenceIndicator> createState() => _RivePresenceIndicatorState();
}

class _RivePresenceIndicatorState extends State<RivePresenceIndicator> {
  rive.FileLoader? _loader;

  @override
  void initState() {
    super.initState();
    _initializeRive();
  }

  Future<void> _initializeRive() async {
    try {
      await rive.RiveNative.init();
      if (!mounted) return;
      final loader = rive.FileLoader.fromAsset(
        'assets/rive/web_icons_pack.riv',
        riveFactory: rive.Factory.flutter,
      );
      setState(() => _loader = loader);
    } catch (_) {
      // Display the accessible native Flutter fallback instead.
    }
  }

  @override
  void dispose() {
    _loader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loader = _loader;
    if (MediaQuery.disableAnimationsOf(context) || loader == null) {
      return const Icon(Icons.wifi_rounded, color: Color(0xFF4CE0B6));
    }
    return rive.RiveWidgetBuilder(
      fileLoader: loader,
      artboardSelector: const rive.ArtboardNamed('wifi'),
      builder: (context, state) {
        if (state is rive.RiveLoaded) {
          return rive.RiveWidget(controller: state.controller, fit: rive.Fit.contain);
        }
        return const Icon(Icons.wifi_rounded, color: Color(0xFF4CE0B6));
      },
    );
  }
}

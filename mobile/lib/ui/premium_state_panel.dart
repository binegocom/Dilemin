import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'palette.dart';

/// Polished empty/error state. Decorative motion is not a synthetic user or
/// activity indicator and never implies that the service has online members.
class PremiumStatePanel extends StatefulWidget {
  const PremiumStatePanel({
    required this.message,
    required this.icon,
    this.retryLabel,
    this.onRetry,
    this.compact = false,
    super.key,
  });

  final String message;
  final IconData icon;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  State<PremiumStatePanel> createState() => _PremiumStatePanelState();
}

class _PremiumStatePanelState extends State<PremiumStatePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _animation.value = 0;
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: widget.onRetry != null,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: widget.compact ? 18 : 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: widget.compact ? 92 : 116,
                  height: widget.compact ? 92 : 116,
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, _) {
                      final phase = _animation.value;
                      final halo = (1 + math.sin(phase * math.pi * 2)) / 2;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 106 + halo * 8,
                            height: 106 + halo * 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Palette.rose
                                    .withValues(alpha: .12 + halo * .22),
                              ),
                            ),
                          ),
                          Container(
                            width: 83,
                            height: 83,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF392441),
                                  Color(0xFF1A2341),
                                ],
                              ),
                              border: Border.all(
                                color: Palette.rose.withValues(alpha: .25),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Palette.rose.withValues(
                                    alpha: .08 + halo * .12,
                                  ),
                                  blurRadius: 22 + halo * 12,
                                ),
                              ],
                            ),
                            child: Icon(
                              widget.icon,
                              size: 36,
                              color: const Color(0xFFFF99BF),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Palette.secondary,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                if (widget.onRetry != null && widget.retryLabel != null) ...[
                  const SizedBox(height: 17),
                  OutlinedButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(widget.retryLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ---------------------------------------------------------------------------
/// PRESS SCALE: smooth tap / scale effect for anything pressable.
/// Wrap any widget with PressScale to give it a gentle shrink-on-tap feel.
///
/// A light haptic fires on press so the shrink is felt as well as seen. Set
/// [haptic] to false where the tap already produces its own feedback and a
/// second buzz would read as a stutter.
/// ---------------------------------------------------------------------------
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool haptic;

  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.haptic = true,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        // On press rather than on tap, so the feedback lands with the finger
        // going down — that is what makes it feel physical.
        if (widget.haptic) HapticFeedback.lightImpact();
        setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

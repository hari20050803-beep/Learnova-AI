import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// LIGHTWEIGHT ANIMATIONS (built only from Flutter's own animation widgets —
/// no third-party packages). Reused across Learnova AI for entrance reveals,
/// counting numbers and the chatbot typing indicator.
/// ---------------------------------------------------------------------------

/// One-shot entrance: fade + slide-up + slight scale.
///
/// Pass a small [delay] (e.g. `Duration(milliseconds: 30 * index)`) to stagger
/// a list. The child is built once and passed through the transitions, so it is
/// not rebuilt on every frame.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  /// Slide distance as a fraction of the child's own height (0.12 = 12%).
  final double slideFraction;
  final double beginScale;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 340),
    this.delay = Duration.zero,
    this.slideFraction = 0.12,
    this.beginScale = 0.97,
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fade = curve;
    _slide = Tween<Offset>(
      begin: Offset(0, widget.slideFraction),
      end: Offset.zero,
    ).animate(curve);
    _scale = Tween<double>(begin: widget.beginScale, end: 1.0).animate(curve);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}

/// Smoothly counts a number up to [value] when first shown (and re-animates
/// from the current number whenever [value] changes). Used for analytics.
class CountUpText extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  final String prefix;
  final String suffix;

  const CountUpText(
    this.value, {
    super.key,
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, current, _) =>
          Text('$prefix${current.round()}$suffix', style: style),
    );
  }
}

/// Three pulsing dots — the chatbot "typing…" indicator.
class TypingDots extends StatefulWidget {
  final Color color;
  final double size;

  const TypingDots({super.key, required this.color, this.size = 8});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot is a third of a cycle behind the previous one.
            final double phase = (_controller.value - i * 0.2) % 1.0;
            final double wave = 0.5 + 0.5 * math.sin(phase * 2 * math.pi);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.size * 0.25),
              child: Opacity(
                opacity: 0.35 + 0.65 * wave,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

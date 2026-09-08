import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// ---------------------------------------------------------------------------
/// BRAND BACKDROP
/// A soft brand glow behind a screen: one blue bloom in the top left, one
/// purple bloom in the bottom right. Both are heavily feathered and
/// low-opacity, so they read as depth rather than decoration and never
/// compete with the content on top.
///
/// It also gives frosted surfaces something to actually blur — a [GlassCard]
/// over a flat background shows nothing, but over these blooms it frosts
/// properly.
///
/// Purely decorative: it ignores pointers, so every field and button behind
/// it still receives taps normally.
/// ---------------------------------------------------------------------------
class BrandBackdrop extends StatefulWidget {
  final Widget child;

  /// Multiplies the bloom opacity. Lower it on busy screens where the glow
  /// would fight the content.
  final double intensity;

  /// Drifts the blooms slowly so the background feels alive.
  ///
  /// Off by default: on a scrolling dashboard a moving background competes
  /// with the content and costs a repaint every frame. Worth it on the calm
  /// sign-in screens, where there is nothing else moving.
  final bool animated;

  const BrandBackdrop({
    super.key,
    required this.child,
    this.intensity = 1.0,
    this.animated = false,
  });

  @override
  State<BrandBackdrop> createState() => _BrandBackdropState();
}

class _BrandBackdropState extends State<BrandBackdrop>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      // Deliberately slow — at 14s a full cycle the drift is felt rather than
      // noticed, which is the point.
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 14),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDark(context);
    // Dark navy swallows colour, so the blooms need to be a little stronger
    // there to be felt at all.
    final double strength = (isDark ? 0.22 : 0.13) * widget.intensity;

    Widget blooms(double t) {
      // t is 0..1; map it to a small offset so each bloom drifts a little way
      // and back, in opposite directions.
      final double drift = Curves.easeInOut.transform(t);
      return Stack(
        children: [
          _bloom(
            alignment: Alignment(-1.1 + 0.18 * drift, -0.95 + 0.12 * drift),
            color: AppColors.blue,
            opacity: strength,
          ),
          _bloom(
            alignment: Alignment(1.15 - 0.18 * drift, 0.9 - 0.12 * drift),
            color: AppColors.purple,
            opacity: strength,
          ),
        ],
      );
    }

    final AnimationController? controller = _controller;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: controller == null
                ? blooms(0)
                : AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) => blooms(controller.value),
                  ),
          ),
        ),
        widget.child,
      ],
    );
  }

  Widget _bloom({
    required Alignment alignment,
    required Color color,
    required double opacity,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 320,
        height: 320,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// The sign-in screens' name for [BrandBackdrop].
///
/// These screens are calm and static, so the blooms drift here — there is
/// nothing else on screen for the movement to compete with.
class AuthBackdrop extends StatelessWidget {
  final Widget child;

  const AuthBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) =>
      BrandBackdrop(animated: true, child: child);
}

import 'package:flutter/material.dart';

import '../models/feature.dart';
import '../theme/app_colors.dart';

/// ---------------------------------------------------------------------------
/// GRADIENT PROGRESS BAR
/// A rounded bar that fills in a module's own gradient and animates to its
/// value the first time it is shown (and again whenever the value changes).
///
/// Used for daily progress, XP and any other 0..1 measure. Replaces the flat
/// single-colour LinearProgressIndicator so progress reads as brand rather
/// than as a stock Material widget.
/// ---------------------------------------------------------------------------
class GradientProgressBar extends StatelessWidget {
  /// 0..1. Values outside the range are clamped.
  final double value;
  final ModuleAccent accent;
  final double height;
  final Duration duration;

  const GradientProgressBar({
    super.key,
    required this.value,
    required this.accent,
    this.height = 10,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDark(context);
    final double target = value.clamp(0.0, 1.0);
    final double radius = height / 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: target),
          duration: duration,
          curve: Curves.easeOutCubic,
          builder: (context, current, _) {
            return Stack(
              children: [
                // Track.
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
                // Fill. A zero-width container would still paint its glow, so
                // the bar is only drawn once there is something to show.
                if (current > 0)
                  Container(
                    height: height,
                    width: constraints.maxWidth * current,
                    decoration: BoxDecoration(
                      gradient: accent.gradient,
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

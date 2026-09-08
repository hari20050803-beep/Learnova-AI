import 'package:flutter/material.dart';

import '../models/feature.dart';
import '../theme/app_colors.dart';
import 'press_scale.dart';

/// ---------------------------------------------------------------------------
/// GRADIENT BUTTON: main action button with smooth tap/scale animation.
/// Set [isLoading] to true to show a spinner and ignore taps (used while
/// waiting for Firebase).
///
/// Pass an [accent] to give the button a module's own colours; without one it
/// uses the Learnova brand gradient, so every existing call site is unchanged.
/// ---------------------------------------------------------------------------
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final ModuleAccent? accent;

  /// Optional leading icon, for actions that read better with one.
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.accent,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Gradient gradient = accent?.gradient ?? AppColors.mainGradient;
    final Color glowColor = accent?.start ?? AppColors.indigo;

    return PressScale(
      onTap: isLoading ? () {} : onPressed,
      child: AnimatedOpacity(
        // Dim slightly while working, so the busy state is felt as well as seen.
        opacity: isLoading ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.glow(context, glowColor, strength: 0.9),
          ),
          child: Center(
            // Cross-fades between the label and the spinner rather than
            // swapping them abruptly.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      key: const ValueKey('label'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 19),
                          const SizedBox(width: 9),
                        ],
                        Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

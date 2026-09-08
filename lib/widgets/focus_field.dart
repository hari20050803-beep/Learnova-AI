import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// ---------------------------------------------------------------------------
/// FOCUS FIELD
/// Wraps a TextField so it lifts with a soft accent glow while focused.
///
/// The theme already draws a focused border; this adds the depth cue that
/// makes a form feel responsive — the active field reads as raised rather
/// than just outlined.
///
/// It only decorates: the child keeps its own controller, validation,
/// obscureText and decoration, so wrapping an existing field changes nothing
/// about how it behaves.
/// ---------------------------------------------------------------------------
class FocusField extends StatefulWidget {
  final Widget child;

  /// Glow colour. Defaults to the brand indigo.
  final Color? accent;

  const FocusField({super.key, required this.child, this.accent});

  @override
  State<FocusField> createState() => _FocusFieldState();
}

class _FocusFieldState extends State<FocusField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.accent ?? AppColors.indigo;

    return Focus(
      // Listens only; the child's own FocusNode still owns the interaction.
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (hasFocus) {
        if (hasFocus != _focused) setState(() => _focused = hasFocus);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: accent.withValues(
                      alpha: AppColors.isDark(context) ? 0.30 : 0.18,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}

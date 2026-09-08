import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// ---------------------------------------------------------------------------
/// GLASS CARD
/// A frosted surface: whatever sits behind it is blurred, then a translucent
/// tint and a hairline highlight are laid on top.
///
/// Only worth blurring where something is ACTUALLY behind it — a bar over
/// scrolling content, a panel over a gradient.
///
/// Set [blur] to 0 for the same frosted LOOK with no BackdropFilter: the
/// translucent tint and hairline highlight are what the eye reads as glass,
/// while the blur is the expensive part. That matters here — a list of cards
/// each running its own BackdropFilter is very costly, especially when the
/// emulator falls back to software rendering (swiftshader).
/// ---------------------------------------------------------------------------
class GlassCard extends StatelessWidget {
  final Widget child;

  /// Blur radius behind the card. 0 skips the BackdropFilter entirely and
  /// renders as a cheap translucent card — use this in scrolling lists.
  final double blur;

  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;

  /// Extra opacity for the tint. Raise it when text on the glass needs to stay
  /// readable over busy content.
  final double opacity;

  /// Soft drop shadow under the card. Off for bars, on for floating panels.
  final bool elevated;

  const GlassCard({
    super.key,
    required this.child,
    this.blur = 18,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding,
    this.opacity = 1.0,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDark(context);

    // The tint is the theme's own card colour at partial opacity, so glass
    // still reads as "this app" rather than as generic grey.
    final Color tint = (isDark ? AppColors.darkCard : Colors.white).withValues(
      alpha: (isDark ? 0.62 : 0.68) * opacity,
    );

    Widget surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: borderRadius,
        // A hairline highlight is what actually sells the "glass" read.
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: child,
    );

    if (blur > 0) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: surface,
      );
    }

    surface = ClipRRect(borderRadius: borderRadius, child: surface);

    if (elevated) {
      // The shadow has to sit OUTSIDE the ClipRRect or it would be clipped away.
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: AppColors.shadowMd(context),
        ),
        child: surface,
      );
    }

    return surface;
  }
}

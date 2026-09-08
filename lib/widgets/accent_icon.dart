import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// ---------------------------------------------------------------------------
/// ACCENT ICON
/// A small rounded tile holding an icon, tinted with a module's accent colour.
///
/// Calmer than a full gradient tile, so a screen can use several of them
/// without turning into a rainbow — gradients stay reserved for hero headers
/// and primary actions. The icon itself is lightened on dark backgrounds so it
/// never disappears into the navy.
/// ---------------------------------------------------------------------------
class AccentIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const AccentIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.isDark(context) ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        icon,
        color: AppColors.readable(context, color),
        size: size * 0.55,
      ),
    );
  }
}

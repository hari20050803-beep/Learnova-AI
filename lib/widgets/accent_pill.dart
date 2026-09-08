import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// ---------------------------------------------------------------------------
/// ACCENT PILL
/// Small rounded chip carrying an icon and a label in a module's accent.
///
/// Two weights:
///  * soft (default) — accent tint background, accent text. Use for several
///    pills together (badges, streaks) so a row of them stays calm.
///  * [filled] — solid accent background, white text. Use for the ONE pill
///    that should stand out (e.g. the "Student" badge on Profile).
/// ---------------------------------------------------------------------------
class AccentPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;

  const AccentPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDark(context);
    final Color foreground = filled
        ? Colors.white
        : AppColors.readable(context, color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: isDark ? 0.20 : 0.10),
        borderRadius: BorderRadius.circular(20),
        boxShadow: filled
            ? AppColors.glow(context, color, strength: 0.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

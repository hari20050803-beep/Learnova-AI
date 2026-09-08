import 'package:flutter/material.dart';

import '../models/feature.dart';
import '../theme/app_colors.dart';

/// ---------------------------------------------------------------------------
/// GRADIENT HEADER
/// A premium brand-gradient header (frosted icon tile + title + optional
/// subtitle). Reused across the AI screens for a unified look.
/// ---------------------------------------------------------------------------
class GradientHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  /// Optional module accent. Defaults to the Learnova brand gradient, so
  /// every existing header is unchanged.
  final ModuleAccent? accent;

  /// When set, the frosted icon tile is the landing point for a [Hero] flying
  /// in from the Study Hub card that opened this screen. Must match the tag
  /// given to that card.
  final Object? heroTag;

  const GradientHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.accent,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconTile = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: Colors.white, size: 26),
    );

    if (heroTag != null) {
      iconTile = Hero(tag: heroTag!, child: iconTile);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: accent?.gradient ?? AppColors.mainGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (accent?.start ?? AppColors.indigo).withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Frosted icon tile (the Hero landing point when a tag is given).
          iconTile,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

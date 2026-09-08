import 'package:flutter/material.dart';

import '../models/feature.dart';
import '../theme/app_colors.dart';
import 'press_scale.dart';

/// ---------------------------------------------------------------------------
/// DASHBOARD CARD: one feature card in the dashboard grid.
/// Rounded corners, soft shadow, gradient icon.
/// ---------------------------------------------------------------------------
class DashboardCard extends StatelessWidget {
  final Feature feature;
  final VoidCallback onTap;

  /// When set, the icon tile flies into the destination screen's header.
  /// The same tag must be given to that screen's [GradientHeader].
  ///
  /// Leave null (the default) if two cards with this tag could ever be on
  /// screen at once — Flutter throws on duplicate Hero tags.
  final Object? heroTag;

  const DashboardCard({
    super.key,
    required this.feature,
    required this.onTap,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconTile = Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        // Each module has its own accent, so the grid reads at a
        // glance without colouring the card itself.
        gradient: feature.accent.gradient,
        borderRadius: BorderRadius.circular(16),
        // Soft glow in the module's own colour, for depth.
        boxShadow: [
          BoxShadow(
            color: feature.accent.start.withValues(alpha: 0.32),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(feature.icon, color: Colors.white, size: 24),
    );

    if (heroTag != null) {
      iconTile = Hero(tag: heroTag!, child: iconTile);
    }

    return PressScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow(context),
          border: AppColors.cardBorder(context),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            iconTile,
            // A fixed gap, not a Spacer.
            //
            // Spacer pushed every leftover pixel between the icon and the
            // text, so the icon sat pinned to the top and the text to the
            // bottom with a hole between them that grew with the card. The
            // icon and its label now read as one block, and any slack falls
            // BELOW the text where it looks like padding rather than a gap.
            const SizedBox(height: 14),
            Text(
              feature.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                height: 1.25,
                fontWeight: FontWeight.bold,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 4),
            // Flexible rather than fixed: a card whose title wraps to two
            // lines gives the description less room, and this lets it shrink
            // instead of overflowing.
            Flexible(
              child: Text(
                feature.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.subText(context),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

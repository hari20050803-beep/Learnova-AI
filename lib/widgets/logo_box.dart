import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// ---------------------------------------------------------------------------
/// LOGO BOX: the Learnova AI logo inside a clean white box.
/// Keeps the logo clear and premium in BOTH light and dark mode.
/// ---------------------------------------------------------------------------
class LogoBox extends StatelessWidget {
  final double width;

  const LogoBox({super.key, this.width = 220});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        // Soft brand glow so the logo feels premium on both themes
        // (a static echo of the splash logo's glow).
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Image.asset('assets/images/learnova_logo.png', width: width),
    );
  }
}

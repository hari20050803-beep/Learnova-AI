import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// SMOOTH PAGE TRANSITION (fade + slight slide up)
/// Used by every screen so navigation feels consistent.
/// ---------------------------------------------------------------------------
Route<T> smoothRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: animation.drive(slide), child: child),
      );
    },
  );
}

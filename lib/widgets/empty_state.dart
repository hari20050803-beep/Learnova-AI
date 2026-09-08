import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// ---------------------------------------------------------------------------
/// EMPTY STATE
/// A clean, centered "nothing here yet" placeholder — a soft circular icon
/// badge, a title and an optional message. Reused across list screens.
///
/// The badge breathes gently so an empty screen still feels alive, and takes
/// an optional [accent] so each module's empty state can match its own colour.
/// Existing call sites that pass no accent keep the brand indigo.
/// ---------------------------------------------------------------------------
class EmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Color? accent;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.accent,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _entrance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    // The entrance rides the first pass of the same controller, so the widget
    // needs only one ticker.
    _entrance = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.18, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.accent ?? AppColors.indigo;
    final bool isDark = AppColors.isDark(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final double breathe = Curves.easeInOut.transform(
                  _controller.value,
                );
                // Float and breathe together: the badge drifts up as it
                // expands, so it reads as hovering rather than pulsing in
                // place.
                return Transform.translate(
                  offset: Offset(0, -5 * breathe),
                  child: Transform.scale(
                    scale: 0.97 + 0.06 * breathe,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.18 : 0.08),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(
                              alpha: (isDark ? 0.26 : 0.16) * breathe,
                            ),
                            blurRadius: 20 + 14 * breathe,
                            spreadRadius: 1,
                            // The shadow lags the float, which is what sells
                            // the sense of height.
                            offset: Offset(0, 4 * breathe),
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  ),
                );
              },
              child: Icon(
                widget.icon,
                size: 40,
                color: AppColors.readable(context, accent),
              ),
            ),
            const SizedBox(height: 18),
            FadeTransition(
              opacity: _entrance,
              child: Column(
                children: [
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                  ),
                  if (widget.message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: AppColors.subText(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

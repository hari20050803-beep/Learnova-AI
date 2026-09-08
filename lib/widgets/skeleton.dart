import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// ---------------------------------------------------------------------------
/// SKELETON LOADING
/// A shimmering placeholder shaped like the content that is about to arrive.
///
/// Preferred over a bare spinner: the screen keeps its layout, so nothing
/// jumps when the data lands, and the wait reads as "almost there" instead of
/// "nothing is happening".
///
/// Built from a plain AnimationController + LinearGradient — no package.
/// ---------------------------------------------------------------------------

/// Drives one shared shimmer sweep for everything beneath it.
///
/// Wrap a group of [SkeletonBox]es in this so they all shimmer in step; a
/// SkeletonBox used on its own animates itself.
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerScope(controller: _controller, child: widget.child);
  }
}

class _ShimmerScope extends InheritedWidget {
  final AnimationController controller;

  const _ShimmerScope({required this.controller, required super.child});

  static AnimationController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.controller;

  @override
  bool updateShouldNotify(_ShimmerScope oldWidget) =>
      oldWidget.controller != controller;
}

/// One shimmering block. Give it the size of the real content it stands in for.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  /// Only created when there is no [Shimmer] ancestor to borrow from.
  AnimationController? _own;

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AnimationController? controller = _ShimmerScope.of(context);
    if (controller == null) {
      _own ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat();
      controller = _own;
    }

    final bool isDark = AppColors.isDark(context);
    final Color base = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);
    final Color highlight = isDark
        ? Colors.white.withValues(alpha: 0.13)
        : Colors.white.withValues(alpha: 0.75);

    return AnimatedBuilder(
      animation: controller!,
      builder: (context, _) {
        // Sweep the highlight from off-left to off-right.
        final double t = controller!.value * 2 - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(t - 0.6, 0),
              end: Alignment(t + 0.6, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// A card-shaped skeleton: a title line, a few body lines, all inside the
/// app's normal card surface so the page keeps its rhythm while loading.
class SkeletonCard extends StatelessWidget {
  final int lines;
  final double height;

  const SkeletonCard({super.key, this.lines = 3, this.height = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow(context),
        border: AppColors.cardBorder(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonBox(
                width: 34,
                height: 34,
                borderRadius: BorderRadius.all(Radius.circular(11)),
              ),
              const SizedBox(width: 11),
              SkeletonBox(width: 140, height: 14),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < lines; i++) ...[
            SkeletonBox(
              width: i == lines - 1 ? 180 : double.infinity,
              height: 11,
            ),
            if (i != lines - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

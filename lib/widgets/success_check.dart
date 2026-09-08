import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// SUCCESS CHECK
/// An animated confirmation mark: a ring draws itself, then a tick strokes on
/// inside it, finishing with a small settle.
///
/// Drawn with CustomPainter so it scales cleanly and needs no asset or
/// animation package.
/// ---------------------------------------------------------------------------
class SuccessCheck extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;

  const SuccessCheck({
    super.key,
    this.size = 72,
    this.color = const Color(0xFF2E9E4F),
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _ring;
  late final Animation<double> _tick;
  late final Animation<double> _pop;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    // Ring sweeps first, tick follows, then the whole mark settles.
    _ring = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    );
    _tick = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic),
    );
    _pop = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.06), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.scale(
          scale: _pop.value,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _SuccessPainter(
              ring: _ring.value,
              tick: _tick.value,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

class _SuccessPainter extends CustomPainter {
  final double ring;
  final double tick;
  final Color color;

  _SuccessPainter({
    required this.ring,
    required this.tick,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double stroke = size.width * 0.075;
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Soft disc behind the mark.
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - stroke / 2,
      Paint()..color = color.withValues(alpha: 0.12),
    );

    // Ring, drawn from 12 o'clock.
    if (ring > 0) {
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: size.width / 2 - stroke / 2,
        ),
        -math.pi / 2,
        2 * math.pi * ring,
        false,
        paint,
      );
    }

    // Tick: two segments, stroked in as one continuous run.
    if (tick > 0) {
      final Offset p1 = Offset(size.width * 0.30, size.height * 0.52);
      final Offset p2 = Offset(size.width * 0.44, size.height * 0.66);
      final Offset p3 = Offset(size.width * 0.71, size.height * 0.37);

      final double firstLen = (p2 - p1).distance;
      final double secondLen = (p3 - p2).distance;
      final double total = firstLen + secondLen;
      final double drawn = total * tick;

      final Path path = Path()..moveTo(p1.dx, p1.dy);
      if (drawn <= firstLen) {
        final double f = drawn / firstLen;
        path.lineTo(p1.dx + (p2.dx - p1.dx) * f, p1.dy + (p2.dy - p1.dy) * f);
      } else {
        path.lineTo(p2.dx, p2.dy);
        final double f = ((drawn - firstLen) / secondLen).clamp(0.0, 1.0);
        path.lineTo(p2.dx + (p3.dx - p2.dx) * f, p2.dy + (p3.dy - p2.dy) * f);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SuccessPainter old) =>
      old.ring != ring || old.tick != tick || old.color != color;
}

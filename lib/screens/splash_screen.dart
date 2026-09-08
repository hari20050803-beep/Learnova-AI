import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/smooth_route.dart';
import 'main_shell.dart';
import 'login_screen.dart';

/// ---------------------------------------------------------------------------
/// 1. ANIMATED SPLASH SCREEN
/// Shows the logo for 3 seconds, then auto-routes: a user who is already
/// signed in goes straight to the Dashboard, otherwise to the Login screen.
///
/// The reveal is staged so it reads as one motion rather than several:
///   logo fades and scales in -> an accent ring sweeps around it ->
///   subtitle and progress fade up -> the bar fills over the wait.
///
/// The progress bar is deliberately DETERMINATE and tied to the same 3s wait
/// as the routing, so it shows how long is actually left instead of spinning
/// indefinitely.
/// ---------------------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const Duration _hold = Duration(seconds: 3);

  late final AnimationController _introController; // fade + scale (runs once)
  late final AnimationController _glowController; // soft glow (pulses)
  late final AnimationController _ringController; // accent ring (rotates)
  late final AnimationController _progressController; // the 3s wait

  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _textFadeAnimation;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    // Logo: smooth fade + gentle zoom-in (no bounce) over the first part.
    _fadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );
    // Subtitle + progress fade in just after the logo (subtle stagger).
    _textFadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.45, 1.0, curve: Curves.easeIn),
    );
    _introController.forward();

    // The glow gently pulses while the splash is visible.
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    // A single accent arc sweeping around the logo — the "thinking" cue,
    // slow enough to feel considered rather than busy.
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    // Fills across the same 3 seconds the splash actually waits.
    _progressController = AnimationController(vsync: this, duration: _hold)
      ..forward();

    // Wait 3 seconds (keeps the splash animation), then auto-login:
    // already signed in -> Dashboard, otherwise -> Login.
    Future.delayed(_hold, () async {
      if (!mounted) return;
      final bool loggedIn = AuthService.instance.currentUser != null;
      // Read the profile photo off the device before the dashboard paints, so
      // a returning student sees their own picture rather than their initials
      // for the first second.
      if (loggedIn) await AuthService.instance.loadLocalAvatar();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        smoothRoute(loggedIn ? const MainShell() : const LoginScreen()),
      );
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    _glowController.dispose();
    _ringController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = AppColors.isDark(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          // Light gradient in light mode, dark navy gradient in dark mode.
          gradient: LinearGradient(
            colors: dark
                ? const [Color(0xFF0B1023), Color(0xFF1B2148)]
                : const [Colors.white, Color(0xFFEDEBFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo: fade + gentle scale-in, glow pulse, sweeping accent ring.
              FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // The ring sits behind and slightly outside the card.
                      AnimatedBuilder(
                        animation: _ringController,
                        builder: (context, _) => CustomPaint(
                          size: const Size.square(320),
                          painter: _SweepRingPainter(
                            progress: _ringController.value,
                            color: AppColors.purple,
                            opacity: dark ? 0.55 : 0.38,
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          final double t = _glowController.value;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.indigo.withValues(
                                    alpha: 0.20 + 0.25 * t,
                                  ),
                                  blurRadius: 24 + 28 * t,
                                  spreadRadius: 2 + 4 * t,
                                ),
                              ],
                            ),
                            child: child,
                          );
                        },
                        child: Image.asset(
                          'assets/images/learnova_logo.png',
                          width: 240,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Subtitle: staggered fade-in after the logo.
              FadeTransition(
                opacity: _textFadeAnimation,
                child: Text(
                  'AI-Powered Student Academic Assistant',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.subText(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              // Determinate progress in the brand gradient — it shows how much
              // of the wait is left rather than spinning with no meaning.
              FadeTransition(
                opacity: _textFadeAnimation,
                child: SizedBox(
                  width: 168,
                  child: AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, _) => Stack(
                      children: [
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: dark
                                ? Colors.white.withValues(alpha: 0.10)
                                : AppColors.indigo.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Container(
                          height: 4,
                          width: 168 * _progressController.value,
                          decoration: BoxDecoration(
                            gradient: AppColors.mainGradient,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints one accent arc travelling around a circle, fading out along its
/// tail — a comet rather than a full ring, so it reads as motion instead of
/// a loading spinner.
class _SweepRingPainter extends CustomPainter {
  /// 0..1 around the circle.
  final double progress;
  final Color color;
  final double opacity;

  _SweepRingPainter({
    required this.progress,
    required this.color,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - 4,
    );
    final double start = progress * 2 * math.pi - math.pi / 2;

    // Draw the tail as a few segments of decreasing opacity — cheaper and
    // crisper than a SweepGradient shader at this size.
    const int segments = 14;
    const double tail = math.pi * 0.55;
    for (int i = 0; i < segments; i++) {
      final double f = i / segments;
      final Paint paint = Paint()
        ..color = color.withValues(alpha: opacity * (1 - f) * 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start - tail * f, -tail / segments, false, paint);
    }
  }

  @override
  bool shouldRepaint(_SweepRingPainter old) =>
      old.progress != progress || old.opacity != opacity;
}

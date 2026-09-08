import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/reset_password_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'services/deep_link_service.dart';
import 'services/notification_service.dart';
import 'services/preferences_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase. Wrapped in try/catch so a startup failure is logged
  // and NEVER blocks runApp() — otherwise an uncaught error here would leave
  // the app stuck on the native splash screen (no first frame is ever drawn).
  try {
    await Firebase.initializeApp();
  } catch (e, stack) {
    debugPrint('[Learnova] Firebase.initializeApp failed: $e');
    debugPrint('$stack');
  }

  // Prepare local notifications for study reminders (fails safe internally).
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('[Learnova] NotificationService.init failed: $e');
  }

  // Load saved settings (dark mode + notifications) from the device.
  try {
    await PreferencesService.instance.init();
    themeNotifier.value = PreferencesService.instance.darkMode
        ? ThemeMode.dark
        : ThemeMode.light;
    NotificationService.instance.notificationsEnabled.value =
        PreferencesService.instance.notificationsEnabled;
  } catch (e) {
    debugPrint('[Learnova] PreferencesService.init failed: $e');
  }

  // From now on, save the choice automatically whenever it changes anywhere
  // in the app (Settings toggle, dashboard quick toggle, etc.).
  themeNotifier.addListener(() {
    PreferencesService.instance.setDarkMode(
      themeNotifier.value == ThemeMode.dark,
    );
  });
  NotificationService.instance.notificationsEnabled.addListener(() {
    PreferencesService.instance.setNotificationsEnabled(
      NotificationService.instance.notificationsEnabled.value,
    );
  });

  runApp(const LearnovaApp());
}

/// ---------------------------------------------------------------------------
/// ROOT APP WIDGET
/// Listens to themeNotifier so light/dark mode changes apply app-wide.
/// The app starts from the SplashScreen.
/// ---------------------------------------------------------------------------
class LearnovaApp extends StatefulWidget {
  const LearnovaApp({super.key});

  @override
  State<LearnovaApp> createState() => _LearnovaAppState();
}

class _LearnovaAppState extends State<LearnovaApp> {
  /// Lets a password-reset link push a screen from anywhere in the app.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    DeepLinkService.instance.pendingResetCode.addListener(_onResetLink);
    DeepLinkService.instance.init();
  }

  @override
  void dispose() {
    DeepLinkService.instance.pendingResetCode.removeListener(_onResetLink);
    super.dispose();
  }

  /// Opens the Learnova reset screen when the emailed link is tapped.
  Future<void> _onResetLink() async {
    final String? code = DeepLinkService.instance.pendingResetCode.value;
    if (code == null || code.isEmpty) return;

    // On a cold start the link can arrive before the first frame, so the
    // navigator does not exist yet. Wait for it instead of dropping the code —
    // clearing it here would lose the reset entirely.
    if (_navigatorKey.currentState == null) {
      debugPrint('[DeepLink] Navigator not ready — retrying after first frame');
      WidgetsBinding.instance.addPostFrameCallback((_) => _onResetLink());
      return;
    }

    // Safe to consume now that we can actually act on it.
    DeepLinkService.instance.clearPendingReset();

    // Ask Firebase which address this code belongs to. This also proves the
    // code is still valid before showing the form.
    String email = '';
    String? error;
    try {
      email = await AuthService.instance.verifyPasswordResetCode(code);
    } on AuthException catch (e) {
      error = e.message;
    }

    // The navigator may have gone away while we were waiting on Firebase.
    final current = _navigatorKey.currentState;
    if (current == null) return;

    if (error != null) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(current.context)?.showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    current.push(
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(email: email, oobCode: code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Learnova AI',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: mode,
          home: const SplashScreen(),
        );
      },
    );
  }
}

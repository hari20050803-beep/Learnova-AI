import 'package:flutter/foundation.dart';

/// ---------------------------------------------------------------------------
/// DEV LOG
/// Diagnostic logging that exists ONLY in debug builds.
///
/// Flutter's `debugPrint` still runs in release, so anything passed to it ends
/// up in logcat on a shipped app. That matters here because the auth and
/// deep-link paths log real user data:
///
///   * the signed-in email address, and
///   * the password-reset link, which carries a live `oobCode` — a one-time
///     credential that can change the account password.
///
/// Guarding on [kDebugMode] lets the compiler drop these calls from a release
/// build entirely, so the strings are never built and never printed. Use
/// [devLog] for anything diagnostic; use `debugPrint` only for messages that
/// are safe to ship.
/// ---------------------------------------------------------------------------
void devLog(String message) {
  if (kDebugMode) debugPrint(message);
}

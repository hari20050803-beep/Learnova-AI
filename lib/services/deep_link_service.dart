import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import '../utils/dev_log.dart';

/// ---------------------------------------------------------------------------
/// DEEP LINK SERVICE
/// Catches the link from Firebase's password-reset email so the reset happens
/// inside Learnova AI instead of on Firebase's own web page.
///
/// The link looks like:
///   `https://PROJECT.firebaseapp.com/__/auth/action`
///   `?mode=resetPassword&oobCode=XXXX&apiKey=YYYY`
///
/// Only `mode=resetPassword` is handled; anything else is ignored so the app
/// never hijacks a link it does not understand.
/// ---------------------------------------------------------------------------
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  /// The last code acted on. A cold start delivers the same link twice (once
  /// on the stream, once from getInitialLink), and each delivery would push
  /// its own reset screen. Two different links still have two different
  /// codes, so only genuine repeats are skipped.
  String? _lastHandledCode;

  /// Fires with the oobCode when a password-reset link is opened.
  final ValueNotifier<String?> pendingResetCode = ValueNotifier<String?>(null);

  /// Starts listening. Safe to call more than once.
  Future<void> init() async {
    if (_subscription != null) {
      devLog('[DeepLink] Service already initialized');
      return;
    }

    // Subscribe FIRST, so a link arriving during startup is never missed.
    _subscription = _appLinks.uriLinkStream.listen(
      (uri) => _handle(uri, source: 'stream'),
      onError: (Object e) => devLog('[DeepLink] stream error: $e'),
    );
    devLog('[DeepLink] Service initialized');

    // A link that launched the app from cold.
    try {
      final Uri? initial = await _appLinks.getInitialLink();
      if (initial != null) {
        devLog('[DeepLink] Initial link received');
        _handle(initial, source: 'initial');
      } else {
        devLog('[DeepLink] No initial link (app opened normally)');
      }
    } catch (e) {
      devLog('[DeepLink] getInitialLink failed: $e');
    }
  }

  void _handle(Uri uri, {required String source}) {
    devLog('[DeepLink] URL received: $uri  (via $source)');
    final String? mode = uri.queryParameters['mode'];
    final String? code = uri.queryParameters['oobCode'];

    if (mode == 'resetPassword' && code != null && code.isNotEmpty) {
      if (code == _lastHandledCode) {
        devLog('[DeepLink] Duplicate delivery ignored (via $source)');
        return;
      }
      _lastHandledCode = code;
      devLog('[DeepLink] oobCode extracted: length=${code.length}');
      devLog('[DeepLink] Navigating to Reset Password');
      pendingResetCode.value = code;
    } else {
      devLog('[DeepLink] Ignored — mode=$mode hasCode=${code != null}');
    }
  }

  /// Clears the code once it has been used, so it is not handled twice.
  void clearPendingReset() => pendingResetCode.value = null;

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}

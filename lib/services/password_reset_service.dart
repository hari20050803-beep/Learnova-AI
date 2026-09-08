import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/reset_config.dart';
import '../utils/dev_log.dart';

/// Thrown by [PasswordResetService] with a message safe to show to the user.
class PasswordResetException implements Exception {
  final String message;

  PasswordResetException(this.message);

  @override
  String toString() => message;
}

/// ---------------------------------------------------------------------------
/// PASSWORD RESET SERVICE
///
/// Drives the three steps of a forgotten password, all of them inside the
/// application:
///
///   1. [requestCode]  the endpoint emails a six digit code
///   2. [verifyCode]   the endpoint checks it and returns a short-lived ticket
///   3. [setPassword]  the endpoint sets the new password against that ticket
///
/// The code is generated and checked on the server, not here, so a modified
/// copy of the application cannot skip the check. This device never sees the
/// code except as the digits the student types, and never holds anything that
/// could change another account's password.
///
/// Registration still uses [OtpService], whose code is generated on the device.
/// That is safe because a wrong code there only creates an unverified account;
/// here it would hand over an existing one.
/// ---------------------------------------------------------------------------
class PasswordResetService {
  PasswordResetService._();

  static final PasswordResetService instance = PasswordResetService._();

  static const Duration _timeout = Duration(seconds: 20);

  /// Asks the endpoint to email a fresh code to [email].
  ///
  /// Throws [PasswordResetException] when no account uses that address, which
  /// is the case the old flow could not report: Firebase answers the same way
  /// whether or not the address is registered, so the screen used to promise
  /// an email that was never sent.
  Future<void> requestCode(String email) async {
    final data = await _post('/otp', {'email': email.trim()});
    devLog('[Reset] code requested for ${email.trim()}');
    if (data['ok'] != true) {
      throw PasswordResetException('Could not send the code. Please try again.');
    }
  }

  /// Checks [code] and returns the ticket that authorises the change.
  ///
  /// The ticket is meaningless to this application: it is signed by the
  /// endpoint, names one address, and expires in fifteen minutes.
  Future<String> verifyCode({
    required String email,
    required String code,
  }) async {
    final data = await _post('/verify', {
      'email': email.trim(),
      'code': code.trim(),
    });
    final ticket = data['ticket'];
    if (ticket is! String || ticket.isEmpty) {
      throw PasswordResetException('Could not verify the code. Please retry.');
    }
    devLog('[Reset] code accepted, ticket issued');
    return ticket;
  }

  /// Sets the new password for [email] against a ticket from [verifyCode].
  Future<void> setPassword({
    required String email,
    required String ticket,
    required String newPassword,
  }) async {
    await _post('/reset', {
      'email': email.trim(),
      'ticket': ticket,
      'newPassword': newPassword,
    });
    devLog('[Reset] password updated through the endpoint');
  }

  // -----------------------------------------------------------------------

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    if (ResetConfig.isMissing) {
      throw PasswordResetException(
        'Password reset is not configured yet. Add the endpoint address in '
        'lib/config/reset_config.dart.',
      );
    }

    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('${ResetConfig.endpoint}$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (e) {
      devLog('[Reset] $path network failure: $e');
      throw PasswordResetException(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    Map<String, dynamic> data = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      // A non-JSON body means something upstream failed; _friendly() covers it.
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    devLog('[Reset] $path failed ${response.statusCode}: ${data['error']}');
    throw PasswordResetException(_friendly(data, response.statusCode));
  }

  /// Turns the endpoint's short error names into something a student can act
  /// on. Anything unrecognised falls back to a plain message rather than a
  /// status code.
  String _friendly(Map<String, dynamic> data, int status) {
    switch (data['error']) {
      case 'no-account':
        return 'No Learnova AI account uses this email address. Please check '
            'the spelling, or register instead.';
      case 'bad-email':
        return 'That does not look like a valid email address.';
      case 'expired':
        return 'That code has expired. Please send a new one.';
      case 'wrong-code':
        final left = data['attemptsLeft'];
        if (left is int && left > 0) {
          return 'Incorrect code. $left ${left == 1 ? 'try' : 'tries'} left.';
        }
        return 'Incorrect code. Please check and try again.';
      case 'too-many-attempts':
        return 'Too many incorrect codes. Please send a new one.';
      case 'too-soon':
        return 'A code was just sent. Please wait a moment before asking for '
            'another, and check your spam folder.';
      case 'not-configured':
        return 'Password reset is not set up on the server yet. Please tell '
            'your administrator.';
      case 'bad-ticket':
        return 'This reset has expired. Please start again.';
      case 'weak-password':
        final detail = data['detail'];
        return detail is String ? detail : 'Please choose a stronger password.';
      default:
        return status >= 500
            ? 'The server could not complete the reset. Please try again.'
            : 'Could not complete the reset. Please try again.';
    }
  }
}

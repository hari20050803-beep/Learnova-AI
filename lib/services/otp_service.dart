import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/email_config.dart';
import '../utils/dev_log.dart';

/// What a code is being sent for — decides which EmailJS template is used.
enum OtpPurpose { registration, passwordReset }

/// Thrown by [OtpService] with a message that is safe to show to the user.
class OtpException implements Exception {
  final String message;

  OtpException(this.message);

  @override
  String toString() => message;
}

/// ---------------------------------------------------------------------------
/// OTP SERVICE
/// Creates, emails and checks the 6-digit code used during registration.
///
/// The code is generated on the device, emailed through EmailJS (see
/// [EmailConfig]) and kept in memory only until it is verified. It is never
/// written to Firestore and never shown anywhere in the UI.
/// ---------------------------------------------------------------------------
class OtpService {
  OtpService._();

  /// Single shared instance used by the registration screens.
  static final OtpService instance = OtpService._();

  /// How long a code stays valid.
  static const Duration validity = Duration(minutes: 5);

  /// How long the user must wait before asking for a new code.
  static const Duration resendCooldown = Duration(seconds: 30);

  final Random _random = Random.secure();

  /// The active code. Private on purpose — nothing outside this class can
  /// read it, so it cannot leak into the UI or logs.
  String? _code;
  String? _email;
  DateTime? _issuedAt;

  /// True when the active code is older than [validity].
  bool get isExpired {
    final issuedAt = _issuedAt;
    if (issuedAt == null) return true;
    return DateTime.now().difference(issuedAt) > validity;
  }

  /// Creates a fresh 6-digit code for [email] and emails it.
  ///
  /// [purpose] picks the EmailJS template: registration uses
  /// [EmailConfig.templateId], password reset uses
  /// [EmailConfig.resetTemplateId]. Everything else is identical.
  ///
  /// Throws [OtpException] if the email could not be sent — the caller must
  /// NOT continue to the OTP screen in that case.
  Future<void> sendCode(
    String email, {
    OtpPurpose purpose = OtpPurpose.registration,
  }) async {
    final String target = email.trim();

    // Drop the previous code before sending a new one. Without this a failed
    // resend would leave the old code still accepted, and a resend that the
    // user never receives would keep working.
    clear();

    // 100000..999999 — always six digits. A fresh one on every call, so a
    // resend never repeats the previous code.
    final String code = (100000 + _random.nextInt(900000)).toString();

    await _sendEmail(email: target, code: code, purpose: purpose);

    // Only remember the code once the email actually went out.
    _code = code;
    _email = target.toLowerCase();
    _issuedAt = DateTime.now();
  }

  /// Checks the code the user typed. Throws [OtpException] when it is wrong,
  /// expired, or was issued for a different email.
  void verifyCode({required String email, required String entered}) {
    final String? active = _code;
    if (active == null || _email != email.trim().toLowerCase()) {
      throw OtpException('No code was sent to this email. Please resend.');
    }
    if (isExpired) {
      throw OtpException('This code has expired. Please request a new one.');
    }
    if (entered.trim() != active) {
      throw OtpException('Incorrect code. Please check and try again.');
    }
  }

  /// Forgets the active code (after a successful registration, or on exit).
  void clear() {
    _code = null;
    _email = null;
    _issuedAt = null;
  }

  /// Emails [code] to [email] through EmailJS.
  Future<void> _sendEmail({
    required String email,
    required String code,
    required OtpPurpose purpose,
  }) async {
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(EmailConfig.endpoint),
            headers: {
              'Content-Type': 'application/json',
              // Without this EmailJS rejects the call as "non-browser".
              'origin': EmailConfig.origin,
            },
            body: jsonEncode({
              'service_id': EmailConfig.serviceId,
              'template_id': purpose == OtpPurpose.passwordReset
                  ? EmailConfig.resetTemplateId
                  : EmailConfig.templateId,
              'user_id': EmailConfig.publicKey,
              // Must match the EmailJS template variables exactly:
              //   {{to_email}}  -> the template's "To Email" field
              //   {{otp_code}}  -> the code in the subject / body
              //   {{app_name}}  -> optional, for the body text
              'template_params': {
                'to_email': email,
                'otp_code': code,
                'app_name': EmailConfig.appName,
              },
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw OtpException(
        'Could not send the verification email. Check your internet '
        'connection and try again.',
      );
    }

    // Temporary diagnostic: EmailJS reply only. Never logs the keys, the
    // recipient or the OTP — only what the server sent back.
    if (kDebugMode) {
      // Masked fingerprint proves which credentials this BUILD compiled in
      // (String.fromEnvironment defaults are baked in at compile time, so a
      // stale build can otherwise silently use an old key).
      final String k = EmailConfig.publicKey;
      final String masked = k.length <= 6
          ? '***'
          : '${k.substring(0, 3)}...${k.substring(k.length - 3)}';
      devLog(
        '[Learnova][EmailJS] status=${response.statusCode} '
        'body="${response.body.trim()}" '
        'svc=${EmailConfig.serviceId} tpl=${EmailConfig.templateId} '
        'key=$masked len=${k.length}',
      );
    }

    if (response.statusCode != 200) {
      throw OtpException(_friendlyError(response.body.trim()));
    }
  }

  /// Turns an EmailJS failure into something a student can act on.
  /// The raw reason is appended so the developer can still see it.
  String _friendlyError(String detail) {
    final String reason = detail.toLowerCase();

    // EmailJS checks the public key before anything else, so this means the
    // key is wrong — not the service or template ID.
    if (reason.contains('account not found')) {
      return 'Email account not recognised. Re-copy the Public Key from '
          'EmailJS > Account > General into lib/config/email_config.dart.';
    }
    if (reason.contains('non-browser')) {
      return 'Email service blocked the request. In EmailJS open '
          'Account > Security and allow API requests from non-browser apps.';
    }
    if (reason.contains('public key') || reason.contains('user_id')) {
      return 'Email service rejected the app key. Check the public key in '
          'lib/config/email_config.dart.';
    }
    if (reason.contains('service id') || reason.contains('service_id')) {
      return 'Email service ID not found. Check the service ID in '
          'lib/config/email_config.dart.';
    }
    if (reason.contains('template id') || reason.contains('template_id')) {
      return 'Email template not found. Check the template ID in '
          'lib/config/email_config.dart.';
    }
    if (reason.contains('recipient') || reason.contains('empty')) {
      return 'The email template has no recipient. Set its "To Email" field '
          'to {{to_email}} in EmailJS.';
    }
    if (reason.contains('limit') || reason.contains('quota')) {
      return 'Too many emails have been sent for now. Please try again later.';
    }
    return 'Could not send the verification email'
        '${detail.isEmpty ? '.' : ': $detail'}';
  }
}

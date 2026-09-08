import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/feature.dart';
import '../services/otp_service.dart';
import '../services/password_reset_service.dart';
import '../theme/app_colors.dart';
import '../utils/smooth_route.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/auth_entrance.dart';
import '../widgets/gradient_button.dart';
import '../widgets/logo_box.dart';
import '../utils/dev_log.dart';
import 'reset_password_screen.dart';

/// ---------------------------------------------------------------------------
/// RESET OTP SCREEN
/// Middle step of the Forgot Password flow: the student types the 6-digit code
/// emailed to them, and on success continues straight to
/// [ResetPasswordScreen] inside the application.
///
/// The code is checked by the reset endpoint rather than on the device, and
/// the endpoint answers with a short-lived ticket that authorises the change.
/// There is no email to open at this step.
///
/// Deliberately separate from the registration OTP screen so the working
/// Register flow is untouched.
/// ---------------------------------------------------------------------------
class ResetOtpScreen extends StatefulWidget {
  final String email;

  const ResetOtpScreen({super.key, required this.email});

  @override
  State<ResetOtpScreen> createState() => _ResetOtpScreenState();
}

class _ResetOtpScreenState extends State<ResetOtpScreen> {
  static const int _otpLength = 6;

  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  int _secondsLeft = 0;
  Timer? _timer;
  bool _isResending = false;
  bool _isVerifying = false;


  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = OtpService.resendCooldown.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _isResending) return;
    _timer?.cancel();
    setState(() {
      _isResending = true;
      _secondsLeft = 0;
      _codeController.clear();
    });
    try {
      await PasswordResetService.instance.requestCode(widget.email);
      if (!mounted) return;
      _startCooldown();
      _showMessage('A new code has been sent to your email.', isError: false);
    } on PasswordResetException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (e) {
      if (mounted) _showMessage('Could not resend the code. ($e)');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  /// Checks the emailed code and, on success, opens the Reset Password screen.
  ///
  /// The check happens at the endpoint, which returns a ticket naming this
  /// address and expiring in fifteen minutes. The ticket is what authorises
  /// the change, so the code itself never has to be carried forward and can
  /// never be used twice.
  Future<void> _verify() async {
    final String entered = _codeController.text.trim();
    if (entered.length < _otpLength) {
      _showMessage('Please enter the $_otpLength-digit code.');
      return;
    }

    setState(() => _isVerifying = true);
    try {
      final String ticket = await PasswordResetService.instance.verifyCode(
        email: widget.email,
        code: entered,
      );
      devLog('[Reset] OTP verified, opening the reset screen');
      if (!mounted) return;
      await Navigator.of(context).push(
        smoothRoute(
          ResetPasswordScreen(email: widget.email, ticket: ticket),
        ),
      );
    } on PasswordResetException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (e) {
      if (mounted) _showMessage('Could not verify the code. ($e)');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Code')),
      body: AuthBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AuthEntrance(
                header: const LogoBox(width: 180),
                card: _card(),
                footer: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Change email',
                    style: TextStyle(
                      color: AppColors.readable(context, AppColors.indigo),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow(context),
        border: AppColors.cardBorder(context),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: ModuleAccent.profile.gradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: ModuleAccent.profile.start.withValues(alpha: 0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.mark_email_read_rounded,
                size: 38,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Check your email',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a 6-digit reset code to',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.subText(context)),
          ),
          const SizedBox(height: 2),
          Text(
            widget.email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.indigo,
            ),
          ),
          const SizedBox(height: 20),

          _otpBoxes(),
          const SizedBox(height: 20),
          GradientButton(
            text: 'Verify Code',
            isLoading: _isVerifying,
            onPressed: _verify,
          ),
          const SizedBox(height: 12),
          Center(child: _resendRow()),
        ],
      ),
    );
  }

  /// Six boxes driven by one hidden field, so paste and backspace still work.
  Widget _otpBoxes() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (int i = 0; i < _otpLength; i++) _digitBox(i)],
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _codeController,
              focusNode: _codeFocus,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_otpLength),
              ],
              showCursor: false,
              enableInteractiveSelection: false,
              decoration: const InputDecoration(
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ],
    );
  }

  Widget _digitBox(int index) {
    final String text = _codeController.text;
    final bool filled = index < text.length;
    final bool active = index == text.length && text.length < _otpLength;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.isDark(context)
            ? const Color(0xFF222A4D)
            : const Color(0xFFF3F4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active || filled ? AppColors.indigo : Colors.transparent,
          width: active ? 1.8 : 1.2,
        ),
      ),
      child: Text(
        filled ? text[index] : '',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.text(context),
        ),
      ),
    );
  }

  Widget _resendRow() {
    if (_secondsLeft > 0) {
      return Text(
        'Resend code in ${_secondsLeft}s',
        style: TextStyle(fontSize: 13, color: AppColors.subText(context)),
      );
    }
    return TextButton(
      onPressed: _isResending ? null : _resend,
      child: _isResending
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.purple,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Sending...',
                  style: TextStyle(color: AppColors.subText(context)),
                ),
              ],
            )
          : Text(
              'Resend code',
              style: TextStyle(
                color: AppColors.readable(context, AppColors.purple),
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}

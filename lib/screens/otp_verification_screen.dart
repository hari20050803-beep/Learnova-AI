import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/otp_service.dart';
import '../theme/app_colors.dart';
import '../utils/smooth_route.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/auth_entrance.dart';
import '../widgets/gradient_button.dart';
import '../widgets/logo_box.dart';
import 'login_screen.dart';

/// ---------------------------------------------------------------------------
/// OTP VERIFICATION SCREEN
/// Second step of registration: the student types the 6-digit code sent to
/// their email. Only after the code is correct is the Firebase account
/// actually created — then the app goes back to Login.
///
/// Entrance matches Login / Register: the logo fades in, then the card fades
/// and slides up (1000ms).
/// ---------------------------------------------------------------------------
class OtpVerificationScreen extends StatefulWidget {
  final String fullName;
  final String email;
  final String password;
  final String gender;
  final String address;
  final String university;

  const OtpVerificationScreen({
    super.key,
    required this.fullName,
    required this.email,
    required this.password,
    required this.gender,
    required this.address,
    required this.university,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _otpLength = 6;

  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  /// Seconds left before "Resend code" becomes tappable again.
  int _secondsLeft = 0;
  Timer? _timer;

  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    // The code was already sent by the Register screen — just start the timer.
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

  /// Restarts the "Resend code in Ns" countdown.
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

  /// Asks for a brand new code for the SAME email address.
  Future<void> _resend() async {
    // Blocks a second tap while one send is already in flight, and taps made
    // during the countdown.
    if (_secondsLeft > 0 || _isResending) return;

    // Clear the old attempt up front: stop the countdown and empty the boxes,
    // so the screen can never show a stale code as still valid.
    _timer?.cancel();
    setState(() {
      _isResending = true;
      _secondsLeft = 0;
      _codeController.clear();
    });

    try {
      await OtpService.instance.sendCode(widget.email);
      if (!mounted) return;
      _startCooldown();
      _showMessage('A new code has been sent to your email.', isError: false);
    } on OtpException catch (e) {
      // Sending failed — report it and leave the button tappable so the user
      // can retry, instead of starting a countdown for an email that never
      // went out.
      if (mounted) _showMessage(e.message);
    } catch (e) {
      if (mounted) _showMessage('Could not resend the code. ($e)');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  /// Checks the code and, when it matches, creates the Firebase account.
  Future<void> _verify() async {
    final String entered = _codeController.text.trim();
    if (entered.length < _otpLength) {
      _showMessage('Please enter the $_otpLength-digit code.');
      return;
    }

    setState(() => _isVerifying = true);
    try {
      // 1. Check the code.
      OtpService.instance.verifyCode(email: widget.email, entered: entered);

      // 2. Only now create the account + Firestore profile.
      await AuthService.instance.register(
        fullName: widget.fullName,
        email: widget.email,
        password: widget.password,
        gender: widget.gender,
        address: widget.address,
        university: widget.university,
      );

      OtpService.instance.clear();
      if (!mounted) return;
      _showMessage(
        'Account created successfully! Please login.',
        isError: false,
      );
      Navigator.of(
        context,
      ).pushAndRemoveUntil(smoothRoute(const LoginScreen()), (route) => false);
    } on OtpException catch (e) {
      if (mounted) _showMessage(e.message);
    } on AuthException catch (e) {
      if (!mounted) return;
      // The code was right, but the address already has an account. Don't
      // strand the student on the OTP screen — give them a way straight to
      // Login instead.
      if (e.message.toLowerCase().contains('already registered')) {
        OtpService.instance.clear();
        _showEmailTakenMessage(e.message);
      } else {
        _showMessage(e.message);
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  /// Error + a one-tap route to Login, for an email that is already in use.
  void _showEmailTakenMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Go to Login',
          textColor: Colors.white,
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            smoothRoute(const LoginScreen()),
            (route) => false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: AuthBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AuthEntrance(
                header: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.indigo.withValues(
                          alpha: AppColors.isDark(context) ? 0.38 : 0.20,
                        ),
                        blurRadius: 30,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const LogoBox(width: 180),
                ),
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
          // Gradient badge, same language as the Forgot Password header.
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.mainGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.indigo.withValues(alpha: 0.30),
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
            'Verify your email',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a 6-digit code to',
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
            text: 'Verify OTP',
            isLoading: _isVerifying,
            onPressed: _verify,
          ),
          const SizedBox(height: 12),
          Center(child: _resendRow()),
        ],
      ),
    );
  }

  /// Six digit boxes driven by one hidden field, so the whole row behaves
  /// like a single input (paste and backspace keep working).
  Widget _otpBoxes() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (int i = 0; i < _otpLength; i++) _digitBox(i)],
        ),
        // Transparent field on top: captures taps and shows the keyboard.
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
    // The next empty box is the "active" one.
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

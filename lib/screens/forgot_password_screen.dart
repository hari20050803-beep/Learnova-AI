import 'package:flutter/material.dart';

import '../services/password_reset_service.dart';
import '../theme/app_colors.dart';
import '../utils/smooth_route.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/auth_entrance.dart';
import '../widgets/gradient_button.dart';
import 'reset_otp_screen.dart';

/// ---------------------------------------------------------------------------
/// 4. FORGOT PASSWORD SCREEN
/// Asks the reset endpoint to email a six digit code. The whole reset then
/// happens inside the application: code, then new password, with no link to
/// open. See [PasswordResetService].
/// Entrance matches Login / Register: the header (icon + title) fades in,
/// then the card fades + slides up.
/// ---------------------------------------------------------------------------
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();

  /// True while we are waiting for Firebase to send the email.
  bool _isSending = false;

  @override
  void dispose() {
    _emailController.dispose();
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

  /// Validates the email, emails a 6-digit reset code through EmailJS, then
  /// continues to the in-app verification screen.
  Future<void> _sendResetEmail() async {
    final String email = _emailController.text.trim();

    // ----- Email validation -----
    if (email.isEmpty) {
      _showMessage('Please enter your email.');
      return;
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    setState(() => _isSending = true);
    try {
      // The endpoint checks the address is registered before it sends
      // anything, so an unknown address is reported here rather than being
      // met with a promise of an email that never arrives.
      await PasswordResetService.instance.requestCode(email);
      if (!mounted) return;
      _showMessage('Reset code sent to $email', isError: false);
      Navigator.of(context).push(smoothRoute(ResetOtpScreen(email: email)));
    } on PasswordResetException catch (e) {
      // The email never went out — stay here rather than stranding the user
      // on a code screen.
      if (mounted) _showMessage(e.message);
    } catch (e) {
      if (mounted) _showMessage('Could not send the reset code. ($e)');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: AuthBackdrop(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AuthEntrance(
              headerGap: 24,
              footerGap: 8,
              header: Column(
                children: [
                  // Premium gradient badge (matches the app's icon language).
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: AppColors.mainGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.indigo.withValues(alpha: 0.30),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Reset Your Password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your registered email and we will\nsend you a 6-digit reset code.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.subText(context),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              card: Container(
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
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                    GradientButton(
                      text: 'Reset Password',
                      isLoading: _isSending,
                      onPressed: _sendResetEmail,
                    ),
                  ],
                ),
              ),
              footer: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Back to Login',
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
    );
  }
}

import 'package:flutter/material.dart';

import '../models/feature.dart';
import '../services/auth_service.dart';
import '../services/password_reset_service.dart';
import '../theme/app_colors.dart';
import '../utils/password_strength.dart';
import '../utils/smooth_route.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/auth_entrance.dart';
import '../widgets/gradient_button.dart';
import '../widgets/logo_box.dart';
import 'login_screen.dart';

/// ---------------------------------------------------------------------------
/// RESET PASSWORD SCREEN
/// Final step of the Forgot Password flow, opened as soon as the emailed code
/// has been accepted. Same Learnova AI card style, logo and 1000ms entrance
/// as Login / Register.
///
/// It is reached two ways, and carries whichever authorisation brought it
/// there. Normally that is a [ticket] from the reset endpoint, issued the
/// moment the code was verified. A reset link from an older Firebase email
/// still works too and arrives with an [oobCode] instead; exactly one of the
/// two is ever set.
///
/// Password rules, the live checklist and the strength meter all come from
/// [PasswordRules], so they are identical to the Register screen.
/// ---------------------------------------------------------------------------
class ResetPasswordScreen extends StatefulWidget {
  /// The address whose password is being changed.
  final String email;

  /// Signed permission from the reset endpoint, issued when the emailed code
  /// was accepted. This is the normal path.
  final String? ticket;

  /// Firebase's own one-time code, taken from the link in a reset email. Only
  /// set when the screen was opened by such a link.
  final String? oobCode;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    this.ticket,
    this.oobCode,
  }) : assert(
         (ticket == null) != (oobCode == null),
         'Give exactly one of ticket or oobCode',
       );

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _isSaving = false;

  /// Set when the submitted password turned out to be the current one.
  /// Cleared as soon as the field is edited.
  bool _sameAsOld = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
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

  /// True only when every rule passes, both fields match, and the password is
  /// not already known to be the current one.
  ///
  /// "Different from the old password" cannot be judged locally — it needs a
  /// server round-trip — so it is checked in [_submit] and remembered here.
  bool get _canSubmit {
    if (_sameAsOld) return false;
    final String password = _passwordController.text;
    if (!PasswordRules.check(password).allMet) return false;
    return _confirmController.text == password;
  }

  /// Applies the new password, then returns to Login.
  Future<void> _submit() async {
    if (!_canSubmit || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      // The new password must differ from the current one. This needs a
      // network round-trip, so it runs here rather than in _canSubmit.
      final bool isSame = await AuthService.instance.isCurrentPassword(
        email: widget.email,
        password: _passwordController.text,
      );
      if (isSame) {
        if (mounted) {
          setState(() => _sameAsOld = true);
          _showMessage('New password must be different from old password');
        }
        return;
      }
      if (mounted) setState(() => _sameAsOld = false);

      // The real password change, made with whichever authorisation opened
      // this screen.
      final String? ticket = widget.ticket;
      if (ticket != null) {
        await PasswordResetService.instance.setPassword(
          email: widget.email,
          ticket: ticket,
          newPassword: _passwordController.text,
        );
      } else {
        await AuthService.instance.applyPasswordReset(
          oobCode: widget.oobCode!,
          newPassword: _passwordController.text,
        );
      }
      if (!mounted) return;
      _showMessage(
        'Password updated. Please login with your new password.',
        isError: false,
      );
      Navigator.of(
        context,
      ).pushAndRemoveUntil(smoothRoute(const LoginScreen()), (route) => false);
    } on PasswordResetException catch (e) {
      if (mounted) _showMessage(e.message);
    } on AuthException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (e) {
      if (mounted) _showMessage('Could not update the password. ($e)');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
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
          // Gradient badge in the profile accent, matching Forgot Password.
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
                Icons.lock_reset_rounded,
                size: 38,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Set a new password',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.email,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.readable(context, AppColors.indigo),
            ),
          ),
          const SizedBox(height: 20),

          // ----- New password -----
          TextField(
            controller: _passwordController,
            obscureText: _hidePassword,
            // Typing a different password clears the "same as old" error.
            onChanged: (_) => setState(() => _sameAsOld = false),
            decoration: InputDecoration(
              hintText: 'New Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _hidePassword ? 'Show password' : 'Hide password',
                icon: Icon(
                  _hidePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.subText(context),
                ),
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
              ),
            ),
          ),
          _passwordFeedback(),
          const SizedBox(height: 16),

          // ----- Confirm password -----
          TextField(
            controller: _confirmController,
            obscureText: _hideConfirm,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Confirm New Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _hideConfirm ? 'Show password' : 'Hide password',
                icon: Icon(
                  _hideConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.subText(context),
                ),
                onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
              ),
            ),
          ),
          _confirmFeedback(),
          const SizedBox(height: 22),

          // Enabled only once every rule passes and both fields match.
          AnimatedOpacity(
            opacity: _canSubmit ? 1.0 : 0.5,
            duration: const Duration(milliseconds: 200),
            child: GradientButton(
              text: 'Reset Password',
              isLoading: _isSaving,
              onPressed: _canSubmit ? _submit : () {},
            ),
          ),
        ],
      ),
    );
  }

  /// Strength bar + rating + live checklist (same as Register).
  Widget _passwordFeedback() {
    final String password = _passwordController.text;
    if (password.isEmpty) return const SizedBox.shrink();

    final rules = PasswordRules.check(password);
    final strength = rules.strength;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: strength.fraction),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: AppColors.isDark(context)
                          ? const Color(0xFF2A3358)
                          : const Color(0xFFE6E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(strength.color),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                strength.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: strength.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ruleRow(
            '${PasswordRules.minLength} characters minimum',
            rules.hasMinLength,
          ),
          _ruleRow('One uppercase letter', rules.hasUppercase),
          _ruleRow('One lowercase letter', rules.hasLowercase),
          _ruleRow('One number', rules.hasNumber),
          _ruleRow('One special symbol', rules.hasSymbol),

          // Only known after submitting, so it sits below the checklist.
          if (_sameAsOld) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.cancel_rounded,
                  size: 15,
                  color: Color(0xFFE53935),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'New password must be different from old password',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE53935),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _ruleRow(String text, bool met) {
    final Color color = met
        ? const Color(0xFF2E9E4F)
        : AppColors.subText(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _confirmFeedback() {
    final String confirm = _confirmController.text;
    if (confirm.isEmpty) return const SizedBox.shrink();

    final bool matches = confirm == _passwordController.text;
    final Color color = matches
        ? const Color(0xFF2E9E4F)
        : const Color(0xFFE53935);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            matches ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            matches ? 'Passwords match' : 'Passwords do not match',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

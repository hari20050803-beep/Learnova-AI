import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/otp_service.dart';
import '../theme/app_colors.dart';
import '../utils/password_strength.dart';
import '../utils/smooth_route.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/auth_entrance.dart';
import '../widgets/gradient_button.dart';
import '../widgets/logo_box.dart';
import 'login_screen.dart';
import 'otp_verification_screen.dart';

/// ---------------------------------------------------------------------------
/// 3. REGISTER SCREEN (card slide-up + fade animation)
/// Step 1 of registration: collect the student's details, then send a 6-digit
/// code and continue on the OTP Verification screen, which is where the
/// Firebase account is actually created.
///
/// The logo, the "Join Learnova AI" title and the Register button stay fixed —
/// only the form fields scroll.
/// ---------------------------------------------------------------------------
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _universityController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  /// Chosen gender (null until the student picks one).
  String? _gender;

  /// Eye toggles for the two password fields.
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  /// True while we are waiting for Firebase.
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _universityController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Shows a message at the bottom of the screen.
  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Checks the form, sends the email code, then opens OTP verification.
  /// The Firebase account is created only after the code is verified.
  Future<void> _register() async {
    final String fullName = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String university = _universityController.text.trim();
    final String address = _addressController.text.trim();
    final String? gender = _gender;
    final String password = _passwordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    // ----- Simple form validation -----
    if (fullName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showMessage('Please fill in all fields.');
      return;
    }
    // Catches typos like "abc@", "abc.com" before Firebase is called.
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      _showMessage('Please enter a valid email address.');
      return;
    }
    if (gender == null || gender.isEmpty) {
      _showMessage('Please select your gender.');
      return;
    }
    if (university.isEmpty) {
      _showMessage('Please enter your university name.');
      return;
    }
    if (address.isEmpty) {
      _showMessage('Please enter your home address.');
      return;
    }
    // All five password rules must pass; report the first one that fails.
    final String? passwordProblem = PasswordRules.check(password).firstProblem;
    if (passwordProblem != null) {
      _showMessage(passwordProblem);
      return;
    }
    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Email the 6-digit code, then hand the details to the OTP screen.
      // Nothing is written to Firebase until the code is verified there.
      await OtpService.instance.sendCode(email);

      if (!mounted) return;
      _showMessage('Verification code sent to $email', isError: false);
      Navigator.of(context).push(
        smoothRoute(
          OtpVerificationScreen(
            fullName: fullName,
            email: email,
            password: password,
            gender: gender,
            address: address,
            university: university,
          ),
        ),
      );
    } on OtpException catch (e) {
      // The email did not go out — stay here so the user is never stranded
      // on an OTP screen waiting for a code that will never arrive.
      if (mounted) _showMessage(e.message);
    } catch (e) {
      // Anything unexpected, so the button never just silently does nothing.
      if (mounted) _showMessage('Could not send the code. ($e)');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Strength bar + rating + the live rule checklist, shown while typing.
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
          // ----- Strength bar -----
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

          // ----- Live checklist -----
          _ruleRow(
            '${PasswordRules.minLength} characters minimum',
            rules.hasMinLength,
          ),
          _ruleRow('One uppercase letter', rules.hasUppercase),
          _ruleRow('One lowercase letter', rules.hasLowercase),
          _ruleRow('One number', rules.hasNumber),
          _ruleRow('One special symbol', rules.hasSymbol),
        ],
      ),
    );
  }

  /// One line of the password checklist.
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

  /// "Password matches" / "Passwords do not match", shown while typing.
  Widget _confirmFeedback() {
    final String confirm = _confirmPasswordController.text;
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
            matches ? 'Password matches' : 'Passwords do not match',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: AuthBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            // The card is Expanded so the fields inside it scroll within a
            // fixed frame, keeping the logo, title and Register button pinned.
            child: AuthEntrance(
              expandCard: true,
              // ----- FIXED: logo -----
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
              card: Container(
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppColors.cardShadow(context),
                  border: AppColors.cardBorder(context),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ----- FIXED: title -----
                    Text(
                      'Join Learnova AI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // ----- SCROLLS: form fields only -----
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                hintText: 'Full Name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Gender: dropdown keeps the form compact.
                            DropdownButtonFormField<String>(
                              initialValue: _gender,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                hintText: 'Gender',
                                prefixIcon: Icon(Icons.wc_outlined),
                              ),
                              items: [
                                for (final option in kGenderOptions)
                                  DropdownMenuItem(
                                    value: option,
                                    child: Text(option),
                                  ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _gender = value),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _universityController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                hintText: 'Enter your university name',
                                prefixIcon: Icon(Icons.school_outlined),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Address: starts at two lines and grows up to four,
                            // so long addresses fit without a tall empty box.
                            TextField(
                              controller: _addressController,
                              minLines: 2,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              keyboardType: TextInputType.streetAddress,
                              decoration: const InputDecoration(
                                hintText: 'Enter your home address',
                                prefixIcon: Icon(Icons.home_outlined),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: _hidePassword,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _hidePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.subText(context),
                                  ),
                                  onPressed: () => setState(
                                    () => _hidePassword = !_hidePassword,
                                  ),
                                ),
                              ),
                            ),
                            _passwordFeedback(),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: _hideConfirmPassword,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Confirm Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _hideConfirmPassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                    _hideConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.subText(context),
                                  ),
                                  onPressed: () => setState(
                                    () => _hideConfirmPassword =
                                        !_hideConfirmPassword,
                                  ),
                                ),
                              ),
                            ),
                            _confirmFeedback(),
                          ],
                        ),
                      ),
                    ),
                    // ----- FIXED: Register button -----
                    const SizedBox(height: 20),
                    GradientButton(
                      text: 'Register',
                      isLoading: _isLoading,
                      onPressed: _register,
                    ),
                  ],
                ),
              ),
              // ----- FIXED: bottom row -----
              footer: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: TextStyle(color: AppColors.subText(context)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        smoothRoute(const LoginScreen()),
                        (route) => false,
                      );
                    },
                    child: Text(
                      'Login',
                      style: TextStyle(
                        color: AppColors.readable(context, AppColors.purple),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

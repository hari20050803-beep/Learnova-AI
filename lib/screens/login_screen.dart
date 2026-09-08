import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/smooth_route.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/auth_entrance.dart';
import '../widgets/focus_field.dart';
import '../widgets/gradient_button.dart';
import '../widgets/logo_box.dart';
import 'main_shell.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

/// ---------------------------------------------------------------------------
/// 2. LOGIN SCREEN (card slide-up + fade animation)
/// Connected to Firebase Authentication.
/// ---------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _hidePassword = true;

  /// True while we are waiting for Firebase.
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  /// Checks the form, then signs the user in with Firebase.
  /// Only a correct email + password combination opens the Dashboard.
  Future<void> _login() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    // ----- Simple form validation -----
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter your email and password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.instance.signIn(email: email, password: password);
      // Bring this account's saved photo into memory for the dashboard.
      await AuthService.instance.loadLocalAvatar();

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushAndRemoveUntil(smoothRoute(const MainShell()), (route) => false);
    } on AuthException catch (e) {
      // Friendly Firebase errors: wrong email/password, invalid email,
      // no internet, too many attempts, ...
      if (!mounted) return;
      _showMessage(e.message);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AuthEntrance(
                headerGap: 28,
                footerGap: 20,
                header: Column(
                  children: [
                    _glowingLogo(200),
                    const SizedBox(height: 16),
                    Text(
                      'A smart AI learning assistant that helps students\nlearn in a new and brighter way.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Welcome Back',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FocusField(
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FocusField(
                        child: TextField(
                          controller: _passwordController,
                          obscureText: _hidePassword,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.subText(context),
                              ),
                              onPressed: () {
                                setState(() {
                                  _hidePassword = !_hidePassword;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).push(smoothRoute(const ForgotPasswordScreen()));
                          },
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: AppColors.readable(
                                context,
                                AppColors.indigo,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GradientButton(
                        text: 'Login',
                        isLoading: _isLoading,
                        onPressed: _login,
                      ),
                    ],
                  ),
                ),
                footer: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: TextStyle(color: AppColors.subText(context)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).push(smoothRoute(const RegisterScreen()));
                      },
                      child: Text(
                        'Register',
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
      ),
    );
  }

  /// The Learnova mark with a soft brand glow behind it, matching the splash
  /// screen and the chat welcome orb.
  Widget _glowingLogo(double width) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo.withValues(
              alpha: AppColors.isDark(context) ? 0.38 : 0.20,
            ),
            blurRadius: 34,
            spreadRadius: 2,
          ),
        ],
      ),
      child: LogoBox(width: width),
    );
  }
}

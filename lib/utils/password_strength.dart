import 'package:flutter/material.dart';

/// How strong a password is, used by the Register screen indicator.
enum PasswordStrength { empty, weak, medium, strong, veryStrong }

/// ---------------------------------------------------------------------------
/// PASSWORD RULES
/// The five rules a Learnova AI password must satisfy, plus the strength
/// rating shown live while the student types.
/// ---------------------------------------------------------------------------
class PasswordRules {
  /// Minimum number of characters.
  static const int minLength = 8;

  /// A password this long (with every rule met) counts as "Very Strong".
  static const int veryStrongLength = 12;

  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSymbol;
  final int length;

  const PasswordRules._({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSymbol,
    required this.length,
  });

  /// Checks [password] against every rule.
  factory PasswordRules.check(String password) {
    return PasswordRules._(
      hasMinLength: password.length >= minLength,
      hasUppercase: password.contains(RegExp(r'[A-Z]')),
      hasLowercase: password.contains(RegExp(r'[a-z]')),
      hasNumber: password.contains(RegExp(r'[0-9]')),
      // Anything that is not a letter, a digit or a space.
      hasSymbol: password.contains(RegExp(r'[^A-Za-z0-9\s]')),
      length: password.length,
    );
  }

  /// How many of the five rules are satisfied.
  int get satisfiedCount => [
    hasMinLength,
    hasUppercase,
    hasLowercase,
    hasNumber,
    hasSymbol,
  ].where((met) => met).length;

  /// True only when the password may be used to register.
  bool get allMet => satisfiedCount == 5;

  /// The rating shown under the field.
  PasswordStrength get strength {
    if (length == 0) return PasswordStrength.empty;
    if (allMet) {
      return length >= veryStrongLength
          ? PasswordStrength.veryStrong
          : PasswordStrength.strong;
    }
    return satisfiedCount >= 3
        ? PasswordStrength.medium
        : PasswordStrength.weak;
  }

  /// The first unmet rule, as a message for the Register button. Null when
  /// the password is acceptable.
  String? get firstProblem {
    if (!hasMinLength) {
      return 'Password must be at least $minLength characters.';
    }
    if (!hasUppercase) return 'Password needs an uppercase letter.';
    if (!hasLowercase) return 'Password needs a lowercase letter.';
    if (!hasNumber) return 'Password needs a number.';
    if (!hasSymbol) return 'Password needs a special symbol.';
    return null;
  }
}

/// Label + colour for each rating.
extension PasswordStrengthDisplay on PasswordStrength {
  String get label {
    switch (this) {
      case PasswordStrength.empty:
        return '';
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.medium:
        return 'Medium';
      case PasswordStrength.strong:
        return 'Strong';
      case PasswordStrength.veryStrong:
        return 'Very Strong';
    }
  }

  Color get color {
    switch (this) {
      case PasswordStrength.empty:
        return Colors.grey;
      case PasswordStrength.weak:
        return const Color(0xFFE53935); // red
      case PasswordStrength.medium:
        return const Color(0xFFF57C00); // orange
      case PasswordStrength.strong:
        return const Color(0xFF2E9E4F); // green
      case PasswordStrength.veryStrong:
        return const Color(0xFF1E88E5); // blue
    }
  }

  /// How much of the strength bar is filled (0..1).
  double get fraction {
    switch (this) {
      case PasswordStrength.empty:
        return 0;
      case PasswordStrength.weak:
        return 0.25;
      case PasswordStrength.medium:
        return 0.55;
      case PasswordStrength.strong:
        return 0.8;
      case PasswordStrength.veryStrong:
        return 1.0;
    }
  }
}

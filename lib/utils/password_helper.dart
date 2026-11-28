import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PasswordValidationResult {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecialChar;

  const PasswordValidationResult({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecialChar,
  });

  bool get isStrong =>
      hasMinLength && hasUppercase && hasLowercase && hasDigit && hasSpecialChar;
}

class PasswordHelper {
  PasswordHelper._();

  static PasswordValidationResult check(String password) {
    return PasswordValidationResult(
      hasMinLength: password.length >= 8 && password.length <= 72,
      hasUppercase: RegExp(r'[A-Z]').hasMatch(password),
      hasLowercase: RegExp(r'[a-z]').hasMatch(password),
      hasDigit: RegExp(r'\d').hasMatch(password),
      hasSpecialChar: RegExp(r'[^A-Za-z0-9]').hasMatch(password),
    );
  }

  static String? validateStrongPassword(String? password) {
    final value = password ?? '';
    if (value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (value.length > 72) {
      return 'Password must be at most 72 characters';
    }
    final res = check(value);
    if (!res.hasUppercase) {
      return 'Include at least 1 uppercase letter (A-Z)';
    }
    if (!res.hasLowercase) {
      return 'Include at least 1 lowercase letter (a-z)';
    }
    if (!res.hasDigit) {
      return 'Include at least 1 number (0-9)';
    }
    if (!res.hasSpecialChar) {
      return 'Include at least 1 special character (e.g. @, #, \$, !)';
    }
    return null;
  }
}

class PasswordRulesChecklist extends StatelessWidget {
  final String password;

  const PasswordRulesChecklist({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final res = PasswordHelper.check(password);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          _RuleChip(label: '8+ chars', met: res.hasMinLength),
          _RuleChip(label: 'A-Z uppercase', met: res.hasUppercase),
          _RuleChip(label: 'a-z lowercase', met: res.hasLowercase),
          _RuleChip(label: '0-9 number', met: res.hasDigit),
          _RuleChip(label: '@#\$! special', met: res.hasSpecialChar),
        ],
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  final String label;
  final bool met;

  const _RuleChip({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 13,
          color: met ? AppColors.secondary : AppColors.slate400,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: met ? FontWeight.w700 : FontWeight.w500,
            color: met ? AppColors.secondary : AppColors.slate500,
          ),
        ),
      ],
    );
  }
}

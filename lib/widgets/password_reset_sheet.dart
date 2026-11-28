import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../theme/app_theme.dart';
import '../utils/password_helper.dart';
import 'common_widgets.dart';
import 'custom_button.dart';

class ProfileSettingsSheet {
  ProfileSettingsSheet._();

  static Future<void> show(BuildContext context) async {
    final authMethod = await AuthStorage.getAuthMethod();
    final hasPassword = await AuthStorage.getHasPassword();
    if (!context.mounted) return;

    final isGoogle = authMethod == 'GOOGLE';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.slate300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.indigo50,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.settings_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Profile Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.slate900,
                            ),
                          ),
                          Text(
                            'Manage account password & login security',
                            style: TextStyle(fontSize: 12, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isGoogle ? Icons.verified_user_rounded : Icons.lock_rounded,
                        size: 20,
                        color: isGoogle ? AppColors.secondary : AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isGoogle ? 'Signed in with Google' : 'Signed in with Mobile & Password',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.slate900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hasPassword
                                  ? 'Strong password is set for mobile login'
                                  : 'Set a strong password to also log in with your mobile number',
                              style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.slate200),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.orange500.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: AppColors.orange500, size: 20),
                  ),
                  title: Text(
                    hasPassword ? 'Reset / Change Password' : 'Set Strong Password',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate900,
                    ),
                  ),
                  subtitle: Text(
                    isGoogle
                        ? 'Google verified — reset directly without old password'
                        : 'Update password for your mobile login',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.slate500),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.slate400),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    showResetPasswordModal(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> showResetPasswordModal(BuildContext context) async {
    final authMethod = await AuthStorage.getAuthMethod();
    final hasPassword = await AuthStorage.getHasPassword();
    if (!context.mounted) return;

    final requireCurrent = authMethod != 'GOOGLE' && hasPassword;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalCtx) {
        return _ResetPasswordForm(requireCurrentPassword: requireCurrent);
      },
    );
  }
}

class ProfileSettingsTile extends StatelessWidget {
  const ProfileSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => ProfileSettingsSheet.show(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.indigo50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.settings_rounded, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile Settings & Password',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate900,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Reset or update your login password',
                    style: TextStyle(fontSize: 11.5, color: AppColors.slate500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }
}

class _ResetPasswordForm extends StatefulWidget {
  final bool requireCurrentPassword;

  const _ResetPasswordForm({required this.requireCurrentPassword});

  @override
  State<_ResetPasswordForm> createState() => _ResetPasswordFormState();
}

class _ResetPasswordFormState extends State<_ResetPasswordForm> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _isSaving = false;

  String? _currentErr;
  String? _newErr;
  String? _confirmErr;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text;
    final newPwd = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    String? cErr;
    if (widget.requireCurrentPassword && current.isEmpty) {
      cErr = 'Enter your current password';
    }
    final nErr = PasswordHelper.validateStrongPassword(newPwd);
    String? cfErr;
    if (confirm.isEmpty) {
      cfErr = 'Please confirm your new password';
    } else if (confirm != newPwd) {
      cfErr = 'Passwords do not match';
    }

    setState(() {
      _currentErr = cErr;
      _newErr = nErr;
      _confirmErr = cfErr;
    });

    if (cErr != null || nErr != null || cfErr != null) return;

    setState(() => _isSaving = true);
    final res = await ApiService.resetPassword(
      currentPassword: widget.requireCurrentPassword ? current : null,
      newPassword: newPwd,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res.success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully!'),
          backgroundColor: AppColors.secondary,
        ),
      );
    } else {
      setState(() {
        if (res.code == 'INVALID_CURRENT_PASSWORD') {
          _currentErr = res.message;
        } else {
          _newErr = res.message ?? 'Failed to update password';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 16, 22, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reset Password',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.requireCurrentPassword
                    ? AppColors.indigo50
                    : AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.requireCurrentPassword
                    ? 'Enter your current password to change it. Forgot it? Log out and sign in with Google to reset directly.'
                    : 'Verified via Google — enter a new strong password for your mobile login.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.requireCurrentPassword ? AppColors.indigo800 : AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (widget.requireCurrentPassword) ...[
              FormFieldWidget(
                controller: _currentCtrl,
                label: 'Current Password *',
                placeholder: 'Enter current password',
                obscureText: _hideCurrent,
                errorText: _currentErr,
                suffixIcon: IconButton(
                  icon: Icon(
                    _hideCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                    color: AppColors.slate500,
                  ),
                  onPressed: () => setState(() => _hideCurrent = !_hideCurrent),
                ),
                onChanged: (_) {
                  if (_currentErr != null) setState(() => _currentErr = null);
                },
              ),
              const SizedBox(height: 14),
            ],
            FormFieldWidget(
              controller: _newCtrl,
              label: 'New Strong Password *',
              placeholder: 'Min 8 chars, upper, lower, number, symbol',
              obscureText: _hideNew,
              errorText: _newErr,
              suffixIcon: IconButton(
                icon: Icon(
                  _hideNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.slate500,
                ),
                onPressed: () => setState(() => _hideNew = !_hideNew),
              ),
              onChanged: (_) => setState(() => _newErr = null),
            ),
            const SizedBox(height: 10),
            PasswordRulesChecklist(password: _newCtrl.text),
            const SizedBox(height: 14),
            FormFieldWidget(
              controller: _confirmCtrl,
              label: 'Confirm New Password *',
              placeholder: 'Re-enter new password',
              obscureText: _hideConfirm,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              errorText: _confirmErr,
              suffixIcon: IconButton(
                icon: Icon(
                  _hideConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.slate500,
                ),
                onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
              ),
              onChanged: (_) {
                if (_confirmErr != null) setState(() => _confirmErr = null);
              },
            ),
            const SizedBox(height: 22),
            CustomButton(
              label: _isSaving ? 'Updating password...' : 'Update Password',
              onPressed: _isSaving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

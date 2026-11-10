import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_button.dart';

class MobileScreen extends StatefulWidget {
  final UserRole role;
  final VoidCallback onBack;
  final ValueChanged<String> onContinue;

  const MobileScreen({
    super.key,
    required this.role,
    required this.onBack,
    required this.onContinue,
  });

  @override
  State<MobileScreen> createState() => _MobileScreenState();
}

class _MobileScreenState extends State<MobileScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _phoneError;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String val) {
    final clean = val.trim();
    if (clean.isEmpty) {
      return 'Mobile number is required';
    }
    if (clean.length < 10) {
      return 'Mobile number must be exactly 10 digits (currently ${clean.length})';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(clean)) {
      return 'Please enter a valid 10-digit number starting with 6, 7, 8, or 9';
    }
    return null;
  }

  Future<void> _handleGetOtp() async {
    final phone = _phoneController.text.trim();
    final err = _validatePhone(phone);
    if (err != null) {
      setState(() => _phoneError = err);
      return;
    }

    setState(() {
      _phoneError = null;
      _isLoading = true;
    });

    try {
      final res = await ApiService.sendOtp(mobile: phone, role: widget.role);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.success) {
        final devOtp = res.data?['devOtp'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(devOtp != null
                ? 'OTP sent! Test OTP is: $devOtp'
                : 'OTP sent to +91 $phone'),
            backgroundColor: AppColors.secondary,
          ),
        );
        // Only move to next screen on success!
        widget.onContinue(phone);
      } else {
        setState(() => _phoneError = res.message ?? 'Failed to send OTP. Please check your number.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? 'Failed to send OTP. Please check your number.'),
            backgroundColor: AppColors.rose600,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _phoneError = 'Connection failed. Please check network and retry.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection failed. Please retry.'),
          backgroundColor: AppColors.rose600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role == UserRole.admin;
    final hasError = _phoneError != null && _phoneError!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            BackBar(onBack: widget.onBack, step: 'Step 1 of 2'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandLogo(height: 38),
                    const SizedBox(height: 20),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.indigo50,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isAdmin ? Icons.apartment : Icons.school,
                        size: 28,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'What’s your\nmobile number?',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate900,
                        height: 1.15,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We’ll send a one-time password to verify your ${isAdmin ? "owner" : "student"} account.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.slate500,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Phone input label
                    Text(
                      'Mobile number',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: hasError ? AppColors.rose600 : AppColors.slate700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: hasError ? AppColors.rose500 : AppColors.slate200,
                          width: hasError ? 1.5 : 1.2,
                        ),
                        boxShadow: hasError
                            ? [
                                BoxShadow(
                                  color: AppColors.rose500.withOpacity(0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: hasError ? AppColors.rose500.withOpacity(0.3) : AppColors.slate200,
                                ),
                              ),
                            ),
                            child: const Text(
                              '+91',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.slate800,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              autofocus: true,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              maxLength: 10,
                              onChanged: (val) {
                                if (_phoneError != null) {
                                  setState(() => _phoneError = null);
                                }
                              },
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: AppColors.slate900,
                              ),
                              decoration: const InputDecoration(
                                hintText: '98765 43210',
                                hintStyle: TextStyle(
                                  color: AppColors.slate300,
                                  fontWeight: FontWeight.w700,
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                border: InputBorder.none,
                                counterText: '',
                              ),
                            ),
                          ),
                          if (_phoneController.text.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(_phoneController.text))
                            const Padding(
                              padding: EdgeInsets.only(right: 14),
                              child: Icon(Icons.check_circle_rounded, color: AppColors.secondary, size: 22),
                            ),
                        ],
                      ),
                    ),

                    if (hasError) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.rose600),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _phoneError!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.rose600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),
                    CustomButton(
                      label: _isLoading ? 'Sending code...' : 'Get OTP',
                      trailing: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white),
                      onPressed: _isLoading ? null : _handleGetOtp,
                    ),

                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.slate50,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.slate100),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield, color: AppColors.secondary, size: 18),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Protected & Private',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.slate800,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'We never share your phone number. It is exclusively used for secure biometric and OTP authentication.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.slate500,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

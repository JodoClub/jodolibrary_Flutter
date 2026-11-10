import 'dart:async';
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
  int _lockRemainingSeconds = 0;
  Timer? _lockTimer;

  @override
  void dispose() {
    _lockTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  void _startLockCountdown(int seconds) {
    _lockTimer?.cancel();
    setState(() {
      _lockRemainingSeconds = seconds;
      _phoneError = 'Rate limit locked. Please wait ${_formatCountdown(seconds)} before retrying.';
    });

    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_lockRemainingSeconds > 1) {
          _lockRemainingSeconds--;
          _phoneError = 'Rate limit locked. Please wait ${_formatCountdown(_lockRemainingSeconds)} before retrying.';
        } else {
          _lockRemainingSeconds = 0;
          _phoneError = null;
          timer.cancel();
        }
      });
    });
  }

  String _formatCountdown(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
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
    if (_lockRemainingSeconds > 0) return;

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
        _lockTimer?.cancel();
        _lockRemainingSeconds = 0;
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
        if (res.retryAfterSeconds != null && res.retryAfterSeconds! > 0) {
          _startLockCountdown(res.retryAfterSeconds!);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rate limit locked. Please wait ${_formatCountdown(res.retryAfterSeconds!)}.'),
              backgroundColor: AppColors.rose600,
            ),
          );
        } else {
          setState(() => _phoneError = res.message ?? 'Failed to send OTP. Please check your number.');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message ?? 'Failed to send OTP. Please check your number.'),
              backgroundColor: AppColors.rose600,
            ),
          );
        }
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

                    if (_lockRemainingSeconds > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE4E6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.lock_clock_rounded, color: AppColors.rose600, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Security Lock Active (1 min cooldown)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.rose600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Unlocks in ${_formatCountdown(_lockRemainingSeconds)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.rose600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.rose600,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _formatCountdown(_lockRemainingSeconds),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (hasError) ...[
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
                      label: _lockRemainingSeconds > 0
                          ? 'Locked • Wait ${_formatCountdown(_lockRemainingSeconds)}'
                          : (_isLoading ? 'Sending code...' : 'Get OTP'),
                      trailing: _lockRemainingSeconds > 0
                          ? const Icon(Icons.timer_outlined, size: 16, color: Colors.white)
                          : (_isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white)),
                      onPressed: (_isLoading || _lockRemainingSeconds > 0) ? null : _handleGetOtp,
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

                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'By continuing, you agree to our ',
                          style: TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.w500),
                        ),
                        InkWell(
                          onTap: () => _showTermsModal(context),
                          child: const Text(
                            'Terms & Conditions',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Text(
                          ' and ',
                          style: TextStyle(fontSize: 11, color: AppColors.slate500, fontWeight: FontWeight.w500),
                        ),
                        InkWell(
                          onTap: () => _showPrivacyModal(context),
                          child: const Text(
                            'Privacy Policy',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const Text(
                          '.',
                          style: TextStyle(fontSize: 11, color: AppColors.slate500),
                        ),
                      ],
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

  void _showTermsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ListView(
                controller: scrollCtrl,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.slate300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.article_outlined, color: AppColors.primary, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Terms & Conditions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.slate900,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Welcome to Jodo Library. By logging in and using this platform, you agree to comply with and be bound by the following terms of service:',
                    style: TextStyle(fontSize: 13, color: AppColors.slate600, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  _buildLegalPoint('1. Library Membership & Seat Allocation',
                      'Seats and study spaces are allocated based on active subscription plans. Allotment is non-transferable without written consent from the library administration.'),
                  _buildLegalPoint('2. Digital Attendance & Gate QR Pass',
                      'Members must scan the digital QR standee at entry and exit gates. Any fraudulent attendance punching may lead to immediate suspension of library access.'),
                  _buildLegalPoint('3. Code of Conduct & Study Decorum',
                      'Libraries are silent study zones. Members must maintain strict silence, keep mobile phones in silent mode, avoid loud phone calls, and respect the study environment of fellow aspirants.'),
                  _buildLegalPoint('4. Fees, Validity & Renewals',
                      'Subscription fees must be settled prior to or on the due date. Expired memberships release the reserved seat for other waitlisted students.'),
                  _buildLegalPoint('5. Property & Safety',
                      'Members are responsible for their personal belongings (laptops, books, chargers). Library administration is not liable for unattended items.'),
                  const SizedBox(height: 20),
                  CustomButton(
                    label: 'I Understand & Agree',
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPrivacyModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ListView(
                controller: scrollCtrl,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.slate300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.privacy_tip_outlined, color: AppColors.secondary, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Privacy Policy',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.slate900,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'At Jodo Library, safeguarding your privacy and personal data is our foundational commitment:',
                    style: TextStyle(fontSize: 13, color: AppColors.slate600, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  _buildLegalPoint('1. Information We Collect',
                      'We collect your mobile number for OTP authentication, full name, target examination, emergency contact, and automated timestamp logs for library attendance.'),
                  _buildLegalPoint('2. How We Use Your Data',
                      'Your data is solely used to allocate your study desk, generate digital attendance QR passes, and send important renewal or library schedule notifications.'),
                  _buildLegalPoint('3. Data Protection & Security',
                      'All communication between your app and the Jodo Library backend is encrypted using industry-standard protocols. We never sell, lease, or monetize your contact details.'),
                  _buildLegalPoint('4. Strict Access Control',
                      'Library owners can only view details of students actively enrolled in their hub. Student personal data is protected from unauthorized multi-tenant access.'),
                  _buildLegalPoint('5. Your Rights',
                      'You can review, edit, and update your personal profile information anytime directly from the Profile tab in the application.'),
                  const SizedBox(height: 20),
                  CustomButton(
                    label: 'Close',
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegalPoint(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.slate600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

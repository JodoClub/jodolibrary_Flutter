import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_button.dart';

class OTPScreen extends StatefulWidget {
  final UserRole role;
  final String phone;
  final VoidCallback onBack;
  final ValueChanged<AccountType> onVerify;

  const OTPScreen({
    super.key,
    required this.role,
    required this.phone,
    required this.onBack,
    required this.onVerify,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCooldownSeconds = 0;
  Timer? _resendTimer;
  String? _otpError;

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendCooldown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendCooldownSeconds = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCooldownSeconds > 1) {
          _resendCooldownSeconds--;
        } else {
          _resendCooldownSeconds = 0;
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

  String get _otpCode => _controllers.map((c) => c.text.trim()).join();

  Future<void> _handleVerify() async {
    final code = _otpCode;
    if (code.length != 4) {
      setState(() => _otpError = 'Please enter all 4 digits of the OTP');
      return;
    }

    setState(() {
      _otpError = null;
      _isLoading = true;
    });

    try {
      final res = await ApiService.verifyOtp(
        mobile: widget.phone,
        otp: code,
        role: widget.role,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.success && res.data != null) {
        final acctTypeStr = res.data!['accountType']?.toString().toLowerCase();
        final isReturning = acctTypeStr == 'returning';
        final resolvedType = isReturning ? AccountType.returning : AccountType.firstTime;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isReturning ? 'Welcome back! Logging in...' : 'Verified! Completing profile...'),
            backgroundColor: AppColors.secondary,
          ),
        );
        // ONLY navigate on verified success!
        widget.onVerify(resolvedType);
        return;
      } else {
        // STRICT VALIDATION: OTP failed - DO NOT move to next screen!
        setState(() {
          _otpError = res.message ?? 'Invalid OTP code. Please enter the correct code.';
          for (var c in _controllers) {
            c.clear();
          }
        });
        _focusNodes[0].requestFocus();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_otpError!),
            backgroundColor: AppColors.rose600,
          ),
        );
        return;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpError = 'Verification failed. Please check network and retry.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_otpError!),
          backgroundColor: AppColors.rose600,
        ),
      );
      return;
    }
  }

  Future<void> _handleResendOtp() async {
    if (_isResending || _resendCooldownSeconds > 0) return;
    setState(() => _isResending = true);

    try {
      final res = await ApiService.sendOtp(mobile: widget.phone, role: widget.role);
      if (!mounted) return;
      setState(() => _isResending = false);

      if (res.success) {
        _startResendCooldown(res.retryAfterSeconds ?? 60);
        final devOtp = res.data?['devOtp'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(devOtp != null ? 'New OTP sent! Code: $devOtp' : 'OTP resent to +91 ${widget.phone}'),
            backgroundColor: AppColors.secondary,
          ),
        );
      } else {
        if (res.retryAfterSeconds != null && res.retryAfterSeconds! > 0) {
          _startResendCooldown(res.retryAfterSeconds!);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Rate limit locked. Please wait ${_formatCountdown(res.retryAfterSeconds!)}.'),
              backgroundColor: AppColors.rose600,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message ?? 'Could not resend OTP. Please wait a moment.'),
              backgroundColor: AppColors.rose600,
            ),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _otpError != null && _otpError!.isNotEmpty;
    final displayPhone = widget.phone.length == 10
        ? '+91 ${widget.phone.substring(0, 5)} ${widget.phone.substring(5)}'
        : '+91 ${widget.phone}';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            BackBar(onBack: widget.onBack, step: 'Step 2 of 2'),
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
                        color: hasError ? AppColors.rose100 : AppColors.indigo50,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        hasError ? Icons.lock_clock_outlined : Icons.lock_outline,
                        size: 28,
                        color: hasError ? AppColors.rose600 : AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Verify your number',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    RichText(
                      text: TextSpan(
                        text: 'Enter the 4-digit code sent to ',
                        style: const TextStyle(fontSize: 14, color: AppColors.slate500, height: 1.5),
                        children: [
                          TextSpan(
                            text: displayPhone,
                            style: const TextStyle(
                              color: AppColors.slate800,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: AppColors.secondary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Test Mode Active: Universal testing OTP is 4321',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryDark,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 4-digit OTP row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(4, (index) {
                        return Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: hasError ? AppColors.rose500 : AppColors.slate200,
                              width: hasError ? 2.0 : 1.5,
                            ),
                            boxShadow: hasError
                                ? [
                                    BoxShadow(
                                      color: AppColors.rose500.withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: AppColors.slate200.withOpacity(0.5),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: hasError ? AppColors.rose600 : AppColors.slate900,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                            ),
                            onChanged: (val) {
                              if (_otpError != null) {
                                setState(() => _otpError = null);
                              }
                              if (val.isNotEmpty && index < 3) {
                                _focusNodes[index + 1].requestFocus();
                              } else if (val.isEmpty && index > 0) {
                                _focusNodes[index - 1].requestFocus();
                              }
                            },
                          ),
                        );
                      }),
                    ),

                    if (hasError) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.rose600),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _otpError!,
                              textAlign: TextAlign.center,
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

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: (_isResending || _resendCooldownSeconds > 0) ? null : _handleResendOtp,
                          child: Text(
                            _isResending
                                ? 'Sending...'
                                : (_resendCooldownSeconds > 0
                                    ? 'Resend in ${_formatCountdown(_resendCooldownSeconds)}'
                                    : 'Resend OTP Code'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: (_isResending || _resendCooldownSeconds > 0)
                                  ? AppColors.slate400
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            const devOtp = '4321';
                            for (int i = 0; i < 4; i++) {
                              _controllers[i].text = devOtp[i];
                            }
                            if (_otpError != null) {
                              setState(() => _otpError = null);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.indigo50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Auto-fill 4321',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    CustomButton(
                      label: _isLoading ? 'Verifying OTP...' : 'Verify & Continue',
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
                      onPressed: _isLoading ? null : _handleVerify,
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

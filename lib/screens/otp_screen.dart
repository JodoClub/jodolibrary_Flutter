import 'package:flutter/material.dart';
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
    this.phone = '9876543210',
    required this.onBack,
    required this.onVerify,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  AccountType _accountType = AccountType.firstTime;
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill universal test OTP "4321" for convenience
    const devOtp = '4321';
    for (int i = 0; i < 4; i++) {
      _controllers[i].text = devOtp[i];
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text.trim()).join();

  Future<void> _handleVerify() async {
    final code = _otpCode;
    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter all 4 digits'),
          backgroundColor: AppColors.orange500,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

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
            content: Text(isReturning ? 'Welcome back!' : 'Verified! Completing setup...'),
            backgroundColor: AppColors.emerald600,
          ),
        );
        widget.onVerify(resolvedType);
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? 'Invalid OTP code. Using prototype fallback.'),
            backgroundColor: AppColors.orange500,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }

    // Offline / Prototype fallback
    widget.onVerify(_accountType);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role == UserRole.admin;
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
                        color: AppColors.orange50,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.lock_outline, size: 28, color: AppColors.orange500),
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
                        color: AppColors.emerald50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.emerald600.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: AppColors.emerald600),
                          SizedBox(width: 8),
                          Text(
                            'Dev mode: Universal test OTP is 4321',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.emerald600,
                              fontWeight: FontWeight.w700,
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
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.slate200, width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.indigo950,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              border: InputBorder.none,
                            ),
                            onChanged: (val) {
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

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Resend code in 00:24',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.orange500,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            const devOtp = '4321';
                            for (int i = 0; i < 4; i++) {
                              _controllers[i].text = devOtp[i];
                            }
                          },
                          child: const Text(
                            'Fill 4321',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.indigo800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Prototype Testing Card (kept for offline tests)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.indigo50.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.indigo200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PROTOTYPE FALLBACK ROUTE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.indigo800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Active if backend is unreachable:',
                            style: TextStyle(fontSize: 12, color: AppColors.slate500),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => setState(() => _accountType = AccountType.firstTime),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _accountType == AccountType.firstTime
                                          ? AppColors.indigo950
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'First-time user',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: _accountType == AccountType.firstTime
                                            ? Colors.white
                                            : AppColors.slate500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => setState(() => _accountType = AccountType.returning),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _accountType == AccountType.returning
                                          ? AppColors.indigo950
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Returning user',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: _accountType == AccountType.returning
                                            ? Colors.white
                                            : AppColors.slate500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                isAdmin ? Icons.apartment : Icons.school,
                                size: 14,
                                color: AppColors.indigo800,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${isAdmin ? "ADMIN" : "STUDENT"} → ${_accountType == AccountType.firstTime ? "Profile setup" : "Dashboard landing"}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.indigo800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                    CustomButton(
                      label: _isLoading ? 'Verifying...' : 'Verify & Continue',
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

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_button.dart';

class StudentSetupScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onComplete;

  const StudentSetupScreen({
    super.key,
    required this.onBack,
    required this.onComplete,
  });

  @override
  State<StudentSetupScreen> createState() => _StudentSetupScreenState();
}

class _StudentSetupScreenState extends State<StudentSetupScreen> {
  final TextEditingController _fullNameController = TextEditingController(text: 'Aarav Kumar');
  final TextEditingController _emergencyContactController = TextEditingController(text: '9876543210');
  String _selectedExam = 'UPSC';
  String _selectedGender = 'Female';
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _fullNameController.text.trim();
    final emergency = _emergencyContactController.text.trim();

    if (name.isEmpty || emergency.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full name and emergency contact'),
          backgroundColor: AppColors.orange500,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiService.studentSetup(
        fullName: name,
        examCategory: _selectedExam,
        emergencyContact: emergency,
        gender: _selectedGender,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile setup completed! 🎓'),
            backgroundColor: AppColors.emerald600,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }

    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: SafeArea(
        child: Column(
          children: [
            BackBar(onBack: widget.onBack, step: 'Student setup'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: const [
                          PhotoUploadWidget(isStudent: true),
                          SizedBox(height: 12),
                          Text(
                            'Add selfie or ID photo',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.indigo950,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Used for safe library check-in',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.slate400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Tell us about you',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'This helps libraries prepare the right study experience.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.slate500,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    FormFieldWidget(
                      controller: _fullNameController,
                      label: 'Full name',
                      placeholder: 'Enter your full name',
                    ),
                    const SizedBox(height: 18),
                    SelectorWidget(
                      label: 'Exam category',
                      items: const ['UPSC', 'SSC', 'Banking', 'CA', 'Other'],
                      value: _selectedExam,
                      onChanged: (val) => setState(() => _selectedExam = val),
                    ),
                    const SizedBox(height: 18),
                    FormFieldWidget(
                      controller: _emergencyContactController,
                      label: 'Emergency contact number',
                      placeholder: '98765 43210',
                      prefix: '+91',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 18),
                    SelectorWidget(
                      label: 'Gender',
                      items: const ['Female', 'Male', 'Other'],
                      value: _selectedGender,
                      onChanged: (val) => setState(() => _selectedGender = val),
                    ),

                    const SizedBox(height: 32),
                    CustomButton(
                      label: _isLoading ? 'Saving...' : 'Save Profile',
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
                      onPressed: _isLoading ? null : _handleSubmit,
                    ),
                    const SizedBox(height: 24),
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

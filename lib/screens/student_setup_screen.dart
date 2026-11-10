import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
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
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();

  String _selectedExam = 'UPSC';
  String _selectedGender = 'Male';
  DateTime _dob = DateTime(2002, 5, 15);
  bool _isLoading = false;

  String? _nameError;
  String? _emergencyError;

  final List<String> _exams = const [
    'UPSC',
    'BPSC / State PSC',
    'SSC CGL / CHSL',
    'Banking / IBPS',
    'CA / CS',
    'NEET / JEE',
    'Law / CLAT',
    'Other Competitive',
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    bool isValid = true;
    final name = _fullNameController.text.trim();
    final emergency = _emergencyContactController.text.trim();

    setState(() {
      // 1. Full Name Validation
      if (name.isEmpty) {
        _nameError = 'Full name is required';
        isValid = false;
      } else if (name.length < 3) {
        _nameError = 'Name must be at least 3 characters long';
        isValid = false;
      } else if (!RegExp(r"^[a-zA-Z\s\.]+$").hasMatch(name)) {
        _nameError = 'Name must only contain letters and spaces';
        isValid = false;
      } else {
        _nameError = null;
      }

      // 2. Emergency Contact Validation
      if (emergency.isEmpty) {
        _emergencyError = 'Emergency contact is required';
        isValid = false;
      } else if (emergency.length != 10) {
        _emergencyError = 'Mobile number must be exactly 10 digits';
        isValid = false;
      } else if (!RegExp(r'^[6-9]\d{9}$').hasMatch(emergency)) {
        _emergencyError = 'Number must start with 6, 7, 8, or 9';
        isValid = false;
      } else {
        _emergencyError = null;
      }
    });

    return isValid;
  }

  Future<void> _handleSubmit() async {
    if (!_validateForm()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please correct the highlighted form errors'),
          backgroundColor: AppColors.rose600,
        ),
      );
      return;
    }

    final name = _fullNameController.text.trim();
    final emergency = _emergencyContactController.text.trim();

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
        await AuthStorage.saveStudentProfile(
          fullName: name,
          examCategory: _selectedExam,
          emergencyContact: emergency,
          gender: _selectedGender,
          studentCode: res.data?['studentCode']?.toString(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile setup completed! 🎓'),
            backgroundColor: AppColors.secondary,
          ),
        );
        widget.onComplete();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? 'Setup failed. Please try again.'),
            backgroundColor: AppColors.rose600,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection failed. Please check your internet.'),
          backgroundColor: AppColors.rose600,
        ),
      );
    }
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
                    const Center(
                      child: Column(
                        children: [
                          PhotoUploadWidget(isStudent: true),
                          SizedBox(height: 12),
                          Text(
                            'Add selfie or ID photo',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Used for safe biometric & library check-in',
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
                      'This helps libraries prepare the right study environment and quiet zones.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.slate500,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    FormFieldWidget(
                      controller: _fullNameController,
                      label: 'Student Full Name *',
                      placeholder: 'e.g. Aarav Kumar',
                      errorText: _nameError,
                      onChanged: (val) {
                        if (_nameError != null) setState(() => _nameError = null);
                      },
                    ),
                    const SizedBox(height: 18),

                    DropdownFieldWidget(
                      label: 'Target Exam / Preparation *',
                      value: _selectedExam,
                      items: _exams,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedExam = val);
                      },
                    ),
                    const SizedBox(height: 18),

                    DateFieldWidget(
                      label: 'Date of Birth *',
                      selectedDate: _dob,
                      firstDate: DateTime(1980),
                      lastDate: DateTime.now(),
                      onDateSelected: (date) {
                        setState(() => _dob = date);
                      },
                    ),
                    const SizedBox(height: 18),

                    FormFieldWidget(
                      controller: _emergencyContactController,
                      label: 'Emergency / Guardian Contact *',
                      placeholder: '98765 43210',
                      prefix: '+91',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      errorText: _emergencyError,
                      onChanged: (val) {
                        if (_emergencyError != null) setState(() => _emergencyError = null);
                      },
                    ),
                    const SizedBox(height: 18),

                    SelectorWidget(
                      label: 'Gender *',
                      items: const ['Male', 'Female', 'Other'],
                      value: _selectedGender,
                      onChanged: (val) => setState(() => _selectedGender = val),
                    ),

                    const SizedBox(height: 32),
                    CustomButton(
                      label: _isLoading ? 'Saving profile...' : 'Save & Continue',
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

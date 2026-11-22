import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/enquiry_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_button.dart';

class EnquiryScreen extends StatefulWidget {
  const EnquiryScreen({super.key});

  @override
  State<EnquiryScreen> createState() => _EnquiryScreenState();
}

class _EnquiryScreenState extends State<EnquiryScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  String _selectedUserType = 'Library Owner'; // 'Student', 'Library Owner', 'Other'
  String _selectedEnquiryType = 'List Your Library'; 
  // 'Open New Library', 'List Your Library', 'List Someone\'s Library', 'Other'

  bool _isSubmitting = false;
  Timer? _autoCloseTimer;
  int _countdownSeconds = 60;

  final List<Map<String, dynamic>> _userTypes = [
    {'label': 'Library Owner', 'icon': Icons.apartment_rounded},
    {'label': 'Student', 'icon': Icons.school_rounded},
    {'label': 'Other', 'icon': Icons.person_outline_rounded},
  ];

  final List<String> _enquiryTypes = [
    'Open New Library',
    'List Your Library',
    'List Someone\'s Library',
    'Other Enquiry',
  ];

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final res = await EnquiryService.submitEnquiry(
      fullName: _nameController.text.trim(),
      userType: _selectedUserType,
      enquiryType: _selectedEnquiryType,
      mobile: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      message: _messageController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.success) {
      _showSuccessDialog();
    } else {
      _showErrorDialog(res.message);
    }
  }

  void _showSuccessDialog() {
    _countdownSeconds = 60;
    _autoCloseTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _autoCloseTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
              if (!mounted) {
                timer.cancel();
                return;
              }
              if (_countdownSeconds > 1) {
                setDialogState(() {
                  _countdownSeconds--;
                });
              } else {
                timer.cancel();
                if (Navigator.of(dialogCtx).canPop()) {
                  Navigator.of(dialogCtx).pop(); // close dialog
                }
                if (Navigator.of(this.context).canPop()) {
                  Navigator.of(this.context).pop(); // return to login screen
                }
              }
            });

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF16A34A),
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Enquiry Submitted! 🎉',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Thank you, ${_nameController.text.trim()}!\nYour enquiry has been saved and sent to our team. We will get back to you shortly.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.slate600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.slate100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, size: 16, color: AppColors.slate600),
                          const SizedBox(width: 6),
                          Text(
                            'Returning to login in $_countdownSeconds s',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          _autoCloseTimer?.cancel();
                          Navigator.of(dialogCtx).pop(); // close dialog
                          if (Navigator.of(this.context).canPop()) {
                            Navigator.of(this.context).pop(); // return to login
                          }
                        },
                        child: const Text(
                          'Close & Go to Login',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showErrorDialog(String errorMsg) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE4E6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFE11D48),
                    size: 34,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Submission Failed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  errorMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.slate600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: AppColors.slate300),
                        ),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(dialogCtx).pop();
                          _submitForm();
                        },
                        child: const Text(
                          'Try Again',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.slate800, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Contact & Enquiry Form',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppColors.slate900,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.slate200, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F4DD2), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.add_business_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Partner & General Enquiry',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Want to list your library in your city or have questions? Fill the form below.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFE2E8F0),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Card Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.slate200),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Type Selector
                      _buildSectionTitle('I am a:', required: true),
                      const SizedBox(height: 8),
                      Row(
                        children: _userTypes.map((item) {
                          final isSelected = _selectedUserType == item['label'];
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedUserType = item['label']),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : AppColors.slate50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : AppColors.slate200,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      item['icon'] as IconData,
                                      size: 18,
                                      color: isSelected ? Colors.white : AppColors.slate600,
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        item['label'],
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? Colors.white : AppColors.slate700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Enquiry Type Selector
                      _buildSectionTitle('Enquiry Type:', required: true),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _enquiryTypes.map((type) {
                          final isSelected = _selectedEnquiryType == type;
                          return ChoiceChip(
                            label: Text(
                              type,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : AppColors.slate700,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.slate50,
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : AppColors.slate200,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (val) {
                              if (val) setState(() => _selectedEnquiryType = type);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Full Name
                      _buildSectionTitle('Full Name', required: true),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _buildInputDecoration(
                          hint: 'Enter your full name',
                          icon: Icons.person_rounded,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          if (val.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Contact Phone / WhatsApp
                      _buildSectionTitle('Mobile / WhatsApp Number', required: true),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: _buildInputDecoration(
                          hint: '10-digit mobile number',
                          icon: Icons.phone_android_rounded,
                          prefixText: '+91 ',
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter your mobile number';
                          }
                          if (val.trim().length != 10) {
                            return 'Enter a valid 10-digit mobile number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Email Address (Optional)
                      _buildSectionTitle('Email Address (Optional)', required: false),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _buildInputDecoration(
                          hint: 'e.g. name@example.com',
                          icon: Icons.mail_outline_rounded,
                        ),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                            if (!emailRegex.hasMatch(val.trim())) {
                              return 'Enter a valid email address';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Address / City / Location
                      _buildSectionTitle('City & Address / Location', required: true),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _addressController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _buildInputDecoration(
                          hint: 'e.g. Boring Road, Patna, Bihar',
                          icon: Icons.location_on_rounded,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter your city / address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Enquiry Details / Message
                      _buildSectionTitle('What is your enquiry? / Details', required: true),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _messageController,
                        maxLines: 4,
                        minLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Describe your requirements, library details, or any questions...',
                          hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
                          filled: true,
                          fillColor: AppColors.slate50,
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.slate200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.slate200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please describe your enquiry';
                          }
                          if (val.trim().length < 5) {
                            return 'Please provide more details (at least 5 characters)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      CustomButton(
                        label: _isSubmitting ? 'Submitting Enquiry...' : 'Submit Enquiry',
                        leading: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                              )
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        onPressed: _isSubmitting ? null : _submitForm,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Back to Login Link
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.slate600),
                    label: const Text(
                      'Back to Login',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {required bool required}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: AppColors.slate800,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFFE11D48),
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    String? prefixText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate400),
      prefixIcon: Icon(icon, color: AppColors.slate400, size: 20),
      prefixText: prefixText,
      prefixStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppColors.slate800,
      ),
      filled: true,
      fillColor: AppColors.slate50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.slate200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

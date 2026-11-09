import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_button.dart';

class OwnerSetupScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onComplete;

  const OwnerSetupScreen({
    super.key,
    required this.onBack,
    required this.onComplete,
  });

  @override
  State<OwnerSetupScreen> createState() => _OwnerSetupScreenState();
}

class _OwnerSetupScreenState extends State<OwnerSetupScreen> {
  final TextEditingController _ownerNameController = TextEditingController(text: 'Rajesh Kumar');
  final TextEditingController _libraryNameController = TextEditingController(text: 'Saraswati Study Hub');
  final TextEditingController _addressController = TextEditingController(text: 'Boring Road, Patna');
  final TextEditingController _seatCapacityController = TextEditingController(text: '60');
  bool _isLoading = false;

  @override
  void dispose() {
    _ownerNameController.dispose();
    _libraryNameController.dispose();
    _addressController.dispose();
    _seatCapacityController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final ownerName = _ownerNameController.text.trim();
    final libraryName = _libraryNameController.text.trim();
    final address = _addressController.text.trim();
    final seats = int.tryParse(_seatCapacityController.text.trim()) ?? 60;

    if (ownerName.isEmpty || libraryName.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all library details'),
          backgroundColor: AppColors.orange500,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await ApiService.ownerSetup(
        ownerName: ownerName,
        libraryName: libraryName,
        address: address,
        city: 'Patna',
        totalSeats: seats,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Library registered and seats generated! 🎉'),
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
            BackBar(onBack: widget.onBack, step: 'Owner setup'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: const [
                          PhotoUploadWidget(isStudent: false),
                          SizedBox(height: 12),
                          Text(
                            'Add owner photo',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.indigo950,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tap to upload · JPG or PNG',
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
                      'Set up your library',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Just the essentials for now. Desks and entrance standee QR will be created automatically.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.slate500,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    FormFieldWidget(
                      controller: _ownerNameController,
                      label: 'Owner name',
                      placeholder: 'Enter your full name',
                    ),
                    const SizedBox(height: 16),
                    FormFieldWidget(
                      controller: _libraryNameController,
                      label: 'Library name',
                      placeholder: 'e.g. Saraswati Study Hub',
                    ),
                    const SizedBox(height: 16),
                    FormFieldWidget(
                      controller: _addressController,
                      label: 'Full address / area',
                      placeholder: 'e.g. Boring Road, Patna',
                    ),
                    const SizedBox(height: 16),
                    FormFieldWidget(
                      controller: _seatCapacityController,
                      label: 'Total seat capacity',
                      placeholder: 'e.g. 60',
                      keyboardType: TextInputType.number,
                    ),

                    const SizedBox(height: 28),
                    CustomButton(
                      label: _isLoading ? 'Setting up...' : 'Complete Setup',
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
                    const SizedBox(height: 20),
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

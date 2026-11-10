import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
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
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _libraryNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _seatCapacityController = TextEditingController(text: '60');

  String? _selectedCity = 'Patna';
  DateTime _openingDate = DateTime.now();
  bool _isLoading = false;

  String? _ownerNameError;
  String? _libraryNameError;
  String? _cityError;
  String? _addressError;
  String? _seatCapacityError;

  final List<String> _cities = const [
    'Patna',
    'Delhi NCR',
    'Lucknow',
    'Prayagraj',
    'Varanasi',
    'Jaipur',
    'Indore',
    'Kota',
    'Gaya',
    'Muzaffarpur',
    'Other',
  ];

  @override
  void dispose() {
    _ownerNameController.dispose();
    _libraryNameController.dispose();
    _addressController.dispose();
    _seatCapacityController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    bool isValid = true;
    final owner = _ownerNameController.text.trim();
    final lib = _libraryNameController.text.trim();
    final addr = _addressController.text.trim();
    final seatsStr = _seatCapacityController.text.trim();
    final seats = int.tryParse(seatsStr);

    setState(() {
      // 1. Owner Name validation
      if (owner.isEmpty) {
        _ownerNameError = 'Owner full name is required';
        isValid = false;
      } else if (owner.length < 3) {
        _ownerNameError = 'Full name must be at least 3 characters';
        isValid = false;
      } else if (!RegExp(r"^[a-zA-Z\s\.]+$").hasMatch(owner)) {
        _ownerNameError = 'Name must only contain letters and spaces';
        isValid = false;
      } else {
        _ownerNameError = null;
      }

      // 2. Library Name validation
      if (lib.isEmpty) {
        _libraryNameError = 'Library name is required';
        isValid = false;
      } else if (lib.length < 3) {
        _libraryNameError = 'Library name must be at least 3 characters';
        isValid = false;
      } else {
        _libraryNameError = null;
      }

      // 3. City dropdown validation
      if (_selectedCity == null || _selectedCity!.isEmpty) {
        _cityError = 'Please select a city from the list';
        isValid = false;
      } else {
        _cityError = null;
      }

      // 4. Address validation
      if (addr.isEmpty) {
        _addressError = 'Full address/area is required';
        isValid = false;
      } else if (addr.length < 5) {
        _addressError = 'Please enter a complete address (min 5 chars)';
        isValid = false;
      } else {
        _addressError = null;
      }

      // 5. Seat Capacity validation
      if (seatsStr.isEmpty) {
        _seatCapacityError = 'Seat capacity is required';
        isValid = false;
      } else if (seats == null || seats <= 0) {
        _seatCapacityError = 'Seat capacity must be a positive number greater than 0';
        isValid = false;
      } else if (seats > 1000) {
        _seatCapacityError = 'Maximum allowed seat capacity per library is 1000';
        isValid = false;
      } else {
        _seatCapacityError = null;
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

    final ownerName = _ownerNameController.text.trim();
    final libraryName = _libraryNameController.text.trim();
    final address = _addressController.text.trim();
    final seats = int.parse(_seatCapacityController.text.trim());

    setState(() => _isLoading = true);

    try {
      final res = await ApiService.ownerSetup(
        ownerName: ownerName,
        libraryName: libraryName,
        address: address,
        city: _selectedCity!,
        totalSeats: seats,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.success) {
        await AuthStorage.saveOwnerProfile(
          ownerName: ownerName,
          libraryName: libraryName,
          address: address,
          city: _selectedCity!,
          totalSeats: seats,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Library registered and seats generated! 🎉'),
            backgroundColor: AppColors.secondary,
          ),
        );
        widget.onComplete();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? 'Registration failed. Please try again.'),
            backgroundColor: AppColors.rose600,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server connection error. Please try again.'),
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
            BackBar(onBack: widget.onBack, step: 'Owner setup'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Column(
                        children: [
                          PhotoUploadWidget(isStudent: false),
                          SizedBox(height: 12),
                          Text(
                            'Add owner photo',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate900,
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
                      label: 'Owner Full Name *',
                      placeholder: 'e.g. Rajesh Kumar',
                      errorText: _ownerNameError,
                      onChanged: (val) {
                        if (_ownerNameError != null) setState(() => _ownerNameError = null);
                      },
                    ),
                    const SizedBox(height: 16),

                    FormFieldWidget(
                      controller: _libraryNameController,
                      label: 'Library Name *',
                      placeholder: 'e.g. Saraswati Study Hub',
                      errorText: _libraryNameError,
                      onChanged: (val) {
                        if (_libraryNameError != null) setState(() => _libraryNameError = null);
                      },
                    ),
                    const SizedBox(height: 16),

                    DropdownFieldWidget(
                      label: 'City / Location *',
                      value: _selectedCity,
                      items: _cities,
                      errorText: _cityError,
                      onChanged: (val) {
                        setState(() {
                          _selectedCity = val;
                          _cityError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    FormFieldWidget(
                      controller: _addressController,
                      label: 'Full Address / Area *',
                      placeholder: 'e.g. 2nd Floor, Boring Road, Patna',
                      errorText: _addressError,
                      onChanged: (val) {
                        if (_addressError != null) setState(() => _addressError = null);
                      },
                    ),
                    const SizedBox(height: 16),

                    FormFieldWidget(
                      controller: _seatCapacityController,
                      label: 'Total Seat Capacity *',
                      placeholder: 'e.g. 60',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      errorText: _seatCapacityError,
                      onChanged: (val) {
                        if (_seatCapacityError != null) setState(() => _seatCapacityError = null);
                      },
                    ),
                    const SizedBox(height: 16),

                    DateFieldWidget(
                      label: 'Establishment / Opening Date',
                      selectedDate: _openingDate,
                      onDateSelected: (date) {
                        setState(() => _openingDate = date);
                      },
                    ),

                    const SizedBox(height: 32),
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

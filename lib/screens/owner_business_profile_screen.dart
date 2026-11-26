import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/library_business_model.dart';
import '../models/library_facilities.dart';
import '../services/api_config.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_button.dart';
import '../utils/safe_url.dart';
import '../services/location_service.dart';
import 'library_details_screen.dart';

/// Full Profile & Business Details Editor for Library Owners
class OwnerBusinessProfileScreen extends StatefulWidget {
  final LibraryBusinessModel initialProfile;
  final Function(LibraryBusinessModel updatedProfile)? onProfileUpdated;

  const OwnerBusinessProfileScreen({
    super.key,
    required this.initialProfile,
    this.onProfileUpdated,
  });

  @override
  State<OwnerBusinessProfileScreen> createState() => _OwnerBusinessProfileScreenState();
}

class _OwnerBusinessProfileScreenState extends State<OwnerBusinessProfileScreen> {
  final _picker = ImagePicker();

  late TextEditingController _nameCtrl;
  late TextEditingController _branchCtrl;
  late TextEditingController _addrCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _seatsCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _mapsCtrl;
  late TextEditingController _timingCtrl;
  late TextEditingController _daysCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _waCtrl;
  late TextEditingController _webCtrl;
  late TextEditingController _instaCtrl;
  late TextEditingController _fbCtrl;
  late TextEditingController _ytCtrl;

  late List<String> _photos;
  late Set<String> _selectedFacilities;

  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  final List<String> _timingPresets = [
    '24 Hours Open (24×7)',
    '06:00 AM - 11:00 PM',
    '07:00 AM - 10:00 PM',
    '08:00 AM - 08:00 PM',
    'Custom Timing',
  ];

  final List<String> _daysPresets = [
    'Mon - Sun (All 7 Days Open)',
    'Mon - Sat (Sundays Closed)',
    'Open 365 Days (No Holidays)',
    'Mon - Fri (Weekdays Only)',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _nameCtrl = TextEditingController(text: p.name);
    _branchCtrl = TextEditingController(text: p.branchName ?? '');
    _addrCtrl = TextEditingController(text: p.address);
    _areaCtrl = TextEditingController(text: p.area ?? '');
    _cityCtrl = TextEditingController(text: p.city);
    _seatsCtrl = TextEditingController(text: p.totalSeats.toString());
    _priceCtrl = TextEditingController(text: p.monthlyPrice.toInt().toString());
    _mapsCtrl = TextEditingController(text: p.googleMapsUrl ?? '');
    _timingCtrl = TextEditingController(text: p.timing);
    _daysCtrl = TextEditingController(text: p.operatingDays);
    _phoneCtrl = TextEditingController(text: (p.contactPhone ?? '').replaceAll('+91', '').trim());
    _emailCtrl = TextEditingController(text: p.contactEmail ?? '');
    _waCtrl = TextEditingController(text: (p.whatsappNumber ?? '').replaceAll('+91', '').trim());
    _webCtrl = TextEditingController(text: p.websiteUrl ?? '');
    _instaCtrl = TextEditingController(text: p.instagramUrl ?? '');
    _fbCtrl = TextEditingController(text: p.facebookUrl ?? '');
    _ytCtrl = TextEditingController(text: p.youtubeUrl ?? '');

    _photos = List<String>.from(p.photos);
    _selectedFacilities = Set<String>.from(p.amenities);

    if (_selectedFacilities.isEmpty) {
      // Default initial amenities
      _selectedFacilities = {
        'wifi', 'ac', 'ro_water', 'power_backup', 'lockers', 'ergonomic_chairs',
        'charging_points', 'cctv', 'biometric', 'open_24_7', 'silent_zone',
        'dining_area', 'newspapers', 'book_bank', 'washrooms', 'two_wheeler_parking',
      };
    }
  }

  String? _resolvePhotoUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) {
      final host = ApiConfig.baseUrl.replaceAll('/api/v1', '');
      return '$host$trimmed';
    }
    return trimmed;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _branchCtrl.dispose();
    _addrCtrl.dispose();
    _areaCtrl.dispose();
    _cityCtrl.dispose();
    _seatsCtrl.dispose();
    _priceCtrl.dispose();
    _mapsCtrl.dispose();
    _timingCtrl.dispose();
    _daysCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _waCtrl.dispose();
    _webCtrl.dispose();
    _instaCtrl.dispose();
    _fbCtrl.dispose();
    _ytCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    // 5-Photo Limit Validation
    if (_photos.length >= 5) {
      _showToast('Limit Reached', 'You can upload maximum 5 photos. Remove a photo to add a new one.');
      return;
    }

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (file == null) return;

      setState(() => _isUploadingPhoto = true);

      final uploadRes = await ApiService.uploadLibraryPhoto(File(file.path));

      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);

      if (uploadRes.success && uploadRes.data != null) {
        setState(() {
          if (_photos.length < 5) {
            _photos.add(uploadRes.data!);
          }
        });
        _showToast('Photo added successfully!', 'Uploaded to your library gallery.');
      } else {
        _showToast('Upload note', uploadRes.message ?? 'Photo queued for saving.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        _showToast('Photo pick error', '$e');
      }
    }
  }

  void _showPhotoSourceSheet() {
    if (_photos.length >= 5) {
      _showToast('Limit Reached', 'You have already added 5 photos (maximum limit reached).');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Library Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Upload photo ${_photos.length + 1} of 5. Showcase study desks, hall, AC, or entrance.',
                style: const TextStyle(fontSize: 12, color: AppColors.slate500),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 22),
                ),
                title: const Text('Take Photo via Camera', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                subtitle: const Text('Capture live photo of study desks or hall', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickPhoto(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.emerald600, size: 22),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                subtitle: const Text('Select high-res photos from your phone gallery', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  Future<void> _testGoogleMaps() async {
    final link = _mapsCtrl.text.trim();
    if (link.isEmpty) {
      _showToast('Enter link first', 'Please enter your Google Maps location URL above.');
      return;
    }
    try {
      final normalized = SafeUrl.normalizeWebLink(link);
      final uri = normalized == null ? null : SafeUrl.parseLaunchable(normalized);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showToast('Invalid URL', 'Please enter a valid Google Maps link (https://...).');
      }
    } catch (_) {
      _showToast('Invalid link format', 'Please check the Google Maps URL.');
    }
  }

  bool _isCapturingGps = false;

  Future<void> _captureGateGpsLocation() async {
    setState(() => _isCapturingGps = true);
    final loc = await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() => _isCapturingGps = false);

    if (loc.isSuccess && loc.position != null) {
      final lat = loc.latitude!;
      final lng = loc.longitude!;
      final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      setState(() {
        _mapsCtrl.text = mapsUrl;
      });
      _showToast(
        'Gate GPS Captured! 📍',
        'Coordinates: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}. Save profile to activate geofence.',
      );
    } else {
      _showToast(
        loc.isServiceDisabled ? 'Turn On GPS 📍' : 'Location Error 📍',
        loc.errorMessage ?? 'Could not obtain gate GPS coordinates.',
      );
    }
  }

  LibraryBusinessModel _constructCurrentModel() {
    return LibraryBusinessModel(
      id: widget.initialProfile.id,
      name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : widget.initialProfile.name,
      branchName: _branchCtrl.text.trim().isNotEmpty ? _branchCtrl.text.trim() : null,
      address: _addrCtrl.text.trim().isNotEmpty ? _addrCtrl.text.trim() : widget.initialProfile.address,
      area: _areaCtrl.text.trim().isNotEmpty ? _areaCtrl.text.trim() : widget.initialProfile.area,
      city: _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : widget.initialProfile.city,
      totalSeats: int.tryParse(_seatsCtrl.text.trim()) ?? widget.initialProfile.totalSeats,
      monthlyPrice: double.tryParse(_priceCtrl.text.trim()) ?? widget.initialProfile.monthlyPrice,
      rating: widget.initialProfile.rating,
      photos: _photos,
      googleMapsUrl: _mapsCtrl.text.trim().isNotEmpty ? _mapsCtrl.text.trim() : null,
      timing: _timingCtrl.text.trim().isNotEmpty ? _timingCtrl.text.trim() : '24 Hours Open (24×7)',
      operatingDays: _daysCtrl.text.trim().isNotEmpty ? _daysCtrl.text.trim() : 'Mon - Sun (All 7 Days Open)',
      contactPhone: _phoneCtrl.text.trim().isNotEmpty ? '+91${_phoneCtrl.text.trim()}' : null,
      contactEmail: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
      websiteUrl: _webCtrl.text.trim().isNotEmpty ? _webCtrl.text.trim() : null,
      whatsappNumber: _waCtrl.text.trim().isNotEmpty ? '+91${_waCtrl.text.trim()}' : null,
      instagramUrl: _instaCtrl.text.trim().isNotEmpty ? _instaCtrl.text.trim() : null,
      facebookUrl: _fbCtrl.text.trim().isNotEmpty ? _fbCtrl.text.trim() : null,
      youtubeUrl: _ytCtrl.text.trim().isNotEmpty ? _ytCtrl.text.trim() : null,
      amenities: _selectedFacilities.toList(),
      ownerName: widget.initialProfile.ownerName,
      ownerUserId: widget.initialProfile.ownerUserId,
      qrPayload: widget.initialProfile.qrPayload,
    );
  }

  void _previewPublicProfile() {
    final model = _constructCurrentModel();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => LibraryDetailsScreen(
          initialData: model,
          isOwnerPreview: true,
        ),
      ),
    );
  }

  /// Normalises every link field; returns false (and shows a toast) if any is invalid.
  bool _validateLinks() {
    final fields = <String, TextEditingController>{
      'Google Maps link': _mapsCtrl,
      'Website': _webCtrl,
      'Instagram link': _instaCtrl,
      'Facebook link': _fbCtrl,
      'YouTube link': _ytCtrl,
    };
    for (final entry in fields.entries) {
      final normalized = SafeUrl.normalizeWebLink(entry.value.text);
      if (normalized == null) {
        _showToast('Invalid ${entry.key}', 'Please enter a valid web link (https://...).');
        return false;
      }
      if (normalized != entry.value.text.trim()) entry.value.text = normalized;
    }
    return true;
  }

  Future<void> _saveBusinessProfile() async {
    if (!_validateLinks()) return;
    setState(() => _isSaving = true);
    final model = _constructCurrentModel();

    try {
      final res = await ApiService.updateOwnerBusinessProfile(
        libraryName: model.name,
        branchName: model.branchName,
        address: model.address,
        area: model.area,
        city: model.city,
        totalSeats: model.totalSeats,
        monthlyPrice: model.monthlyPrice,
        photos: model.photos,
        googleMapsUrl: model.googleMapsUrl,
        timing: model.timing,
        operatingDays: model.operatingDays,
        contactPhone: model.contactPhone,
        contactEmail: model.contactEmail,
        websiteUrl: model.websiteUrl,
        whatsappNumber: model.whatsappNumber,
        instagramUrl: model.instagramUrl,
        facebookUrl: model.facebookUrl,
        youtubeUrl: model.youtubeUrl,
        amenities: model.amenities,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (res.success) {
        LibraryBusinessModel savedModel = model;
        if (res.data != null) {
          try {
            savedModel = LibraryBusinessModel.fromJson(res.data!);
          } catch (_) {}
        }
        widget.onProfileUpdated?.call(savedModel);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Library profile saved successfully! 🎉'),
            backgroundColor: AppColors.secondaryDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? 'Failed to update library profile'),
            backgroundColor: AppColors.rose600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showToast('Update error', '$e');
      }
    }
  }

  void _showToast(String title, String subtitle) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            Text(subtitle, style: const TextStyle(fontSize: 11)),
          ],
        ),
        backgroundColor: AppColors.slate900,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // --- Facilities Modal Popup (Scroll large 24 items) ---
  void _showFacilitiesSelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allFacilities = LibraryFacilitiesCatalog.all;
            // Group by category
            final categories = <String, List<LibraryFacility>>{};
            for (final f in allFacilities) {
              categories.putIfAbsent(f.category, () => []).add(f);
            }

            return Container(
              height: MediaQuery.sizeOf(context).height * 0.85,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'All Library Facilities',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.slate900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_selectedFacilities.length} of ${allFacilities.length} Facilities Selected',
                              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: AppColors.slate500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Select All / Clear All row
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.select_all_rounded, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Select All (24)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                        onPressed: () {
                          setModalState(() {
                            _selectedFacilities = allFacilities.map((f) => f.id).toSet();
                          });
                          setState(() {});
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.clear_all_rounded, size: 16, color: AppColors.rose600),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Clear All', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.rose600)),
                        ),
                        onPressed: () {
                          setModalState(() {
                            _selectedFacilities.clear();
                          });
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 1, color: AppColors.slate200),
                  const SizedBox(height: 8),
                  // Scrollable Facilities List
                  Expanded(
                    child: ListView.builder(
                      itemCount: categories.keys.length,
                      itemBuilder: (context, catIdx) {
                        final catName = categories.keys.elementAt(catIdx);
                        final list = categories[catName]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.slate100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  catName.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.slate600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                            ...list.map((fac) {
                              final isChecked = _selectedFacilities.contains(fac.id);
                              return CheckboxListTile(
                                value: isChecked,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                activeColor: AppColors.primary,
                                secondary: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isChecked ? AppColors.primaryLight : AppColors.slate100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    fac.icon,
                                    size: 20,
                                    color: isChecked ? AppColors.primary : AppColors.slate500,
                                  ),
                                ),
                                title: Text(
                                  fac.name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isChecked ? FontWeight.w800 : FontWeight.w600,
                                    color: isChecked ? AppColors.slate900 : AppColors.slate700,
                                  ),
                                ),
                                subtitle: Text(
                                  fac.description,
                                  style: const TextStyle(fontSize: 11, color: AppColors.slate400),
                                ),
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true) {
                                      _selectedFacilities.add(fac.id);
                                    } else {
                                      _selectedFacilities.remove(fac.id);
                                    }
                                  });
                                  setState(() {});
                                },
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    label: 'Done (${_selectedFacilities.length} Selected)',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text(
          'Edit Library Profile & Photos',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.slate900),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.slate900),
        actions: [
          TextButton.icon(
            onPressed: _previewPublicProfile,
            icon: const Icon(Icons.visibility_rounded, size: 16, color: AppColors.primary),
            label: const Text('Preview', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary)),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP: Library Photos (Validation: Max 5 photos hide upload button)
              _buildPhotoSection(),

              const SizedBox(height: 16),

              // 2. Facilities (App-icon style circles with labels, 8 shown + "+ More" popup)
              _buildFacilitiesSection(),

              const SizedBox(height: 16),

              // 3. Basic Library Details & Seats (One field per row)
              _buildBasicDetailsSection(),

              const SizedBox(height: 16),

              // 4. Google Maps Navigation Section (One field per row)
              _buildGoogleMapsSection(),

              const SizedBox(height: 16),

              // 5. Operating Schedule & Timings (One field per row)
              _buildTimingsSection(),

              const SizedBox(height: 16),

              // 6. Contact & Social Channels (One field per row - Phone & WhatsApp separated)
              _buildContactSection(),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _previewPublicProfile,
                  icon: const Icon(Icons.remove_red_eye_rounded, size: 16),
                  label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Live Preview')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.slate700,
                    side: const BorderSide(color: AppColors.slate300),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: CustomButton(
                  label: _isSaving ? 'Saving...' : 'Save Profile',
                  onPressed: _isSaving ? null : _saveBusinessProfile,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. Top Photo Section with 5-Photo Limit Validation ---
  Widget _buildPhotoSection() {
    final bool canAddMore = _photos.length < 5;
    final int displayItemCount = canAddMore ? _photos.length + 1 : _photos.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.photo_library_rounded, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Library Photos',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.slate900),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _photos.length >= 5 ? AppColors.emerald50 : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_photos.length}/5 Photos ${_photos.length >= 5 ? "(Max reached)" : "(Min. 5 recommended)"}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _photos.length >= 5 ? AppColors.emerald600 : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload up to 5 photos of study desks, air-conditioned hall, lockers, and entrance. Images auto-adjust to look good on all screens.',
            style: TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.35),
          ),
          const SizedBox(height: 16),

          // Photos Grid (Auto-adjusted Aspect Ratio)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: displayItemCount,
            itemBuilder: (context, idx) {
              if (idx == _photos.length && canAddMore) {
                // Add Photo Tile (ONLY shown when _photos.length < 5)
                return InkWell(
                  onTap: _isUploadingPhoto ? null : _showPhotoSourceSheet,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _isUploadingPhoto
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 22),
                              SizedBox(height: 6),
                              Text(
                                'Add Photo',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              }

              // Photo Item with Delete Action
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      _resolvePhotoUrl(_photos[idx]) ?? _photos[idx],
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.slate200,
                        child: const Icon(Icons.broken_image_rounded, color: AppColors.slate400),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removePhoto(idx),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${idx + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- 2. Facilities Section (Circular App-Icon Style, 8 shown + "+ More" Popup) ---
  Widget _buildFacilitiesSection() {
    final allFacilities = LibraryFacilitiesCatalog.all;
    // Top 8 facilities to show directly
    final top8 = allFacilities.take(8).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.check_circle_rounded, color: AppColors.emerald600, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Provided Facilities',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.slate900),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_selectedFacilities.length}/${allFacilities.length} Selected',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap an icon to toggle. Tap "+ More Facilities" below to view & select from all 24 amenities.',
            style: TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.35),
          ),
          const SizedBox(height: 16),

          // 8 Circular App-Icon Tiles (4 columns x 2 rows)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 8,
              childAspectRatio: 0.78,
            ),
            itemCount: top8.length,
            itemBuilder: (context, idx) {
              final fac = top8[idx];
              final isSelected = _selectedFacilities.contains(fac.id);

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedFacilities.remove(fac.id);
                    } else {
                      _selectedFacilities.add(fac.id);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Circular Icon Container with Checkmark
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryLight : AppColors.slate100,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.slate200,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Icon(
                            fac.icon,
                            size: 22,
                            color: isSelected ? AppColors.primary : AppColors.slate400,
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, size: 10, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Facility Name Below Icon
                    Text(
                      _getShortFacilityName(fac.name),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? AppColors.slate900 : AppColors.slate500,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 14),

          // Interactive Button to View & Scroll all 24 in Popup
          InkWell(
            onTap: _showFacilitiesSelectionModal,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.apps_rounded, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '+ View & Select All 24 Facilities',
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
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getShortFacilityName(String fullName) {
    if (fullName.contains('Wi-Fi')) return '5G Wi-Fi';
    if (fullName.contains('Air-Conditioned')) return 'Full AC';
    if (fullName.contains('RO')) return 'RO Water';
    if (fullName.contains('Power Backup')) return 'Power Backup';
    if (fullName.contains('Lockers')) return 'Lockers';
    if (fullName.contains('Chairs')) return 'Comfort Chairs';
    if (fullName.contains('Charging')) return 'Charging Port';
    if (fullName.contains('CCTV')) return '24×7 CCTV';
    return fullName.split(' ').take(2).join(' ');
  }

  // --- 3. Basic Library Details & Seats (One field per row) ---
  Widget _buildBasicDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Core Details & Pricing',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.slate900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FormFieldWidget(
            label: 'LIBRARY NAME',
            placeholder: 'e.g. Achievers Study Hub',
            controller: _nameCtrl,
          ),
          const SizedBox(height: 12),
          FormFieldWidget(
            label: 'BRANCH NAME (OPTIONAL)',
            placeholder: 'e.g. Boring Road Campus',
            controller: _branchCtrl,
          ),
          const SizedBox(height: 12),
          FormFieldWidget(
            label: 'COMPLETE ADDRESS',
            placeholder: 'Street, Landmark, City',
            controller: _addrCtrl,
          ),
          const SizedBox(height: 12),
          FormFieldWidget(
            label: 'AREA / LOCALITY',
            placeholder: 'e.g. Boring Road',
            controller: _areaCtrl,
          ),
          const SizedBox(height: 12),
          FormFieldWidget(
            label: 'CITY',
            placeholder: 'e.g. Patna',
            controller: _cityCtrl,
          ),
          const SizedBox(height: 12),
          FormFieldWidget(
            label: 'TOTAL SEATS',
            placeholder: 'e.g. 60',
            controller: _seatsCtrl,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          FormFieldWidget(
            label: 'MONTHLY PRICE (₹)',
            placeholder: 'e.g. 1499',
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  // --- 4. Google Maps Section (One field per row) ---
  Widget _buildGoogleMapsSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.location_on_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Google Maps Navigation Link',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.slate900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Paste your Google Maps location URL so students can click "Directions" to navigate to your library gate.',
            style: TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.35),
          ),
          const SizedBox(height: 14),
          FormFieldWidget(
            label: 'GOOGLE MAPS URL OR SHARE LINK',
            placeholder: 'https://maps.app.goo.gl/...',
            controller: _mapsCtrl,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: _isCapturingGps ? null : _captureGateGpsLocation,
                icon: _isCapturingGps
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.my_location_rounded, size: 14),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(_isCapturingGps ? 'Capturing GPS...' : '📍 Use Current GPS as Gate'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _testGoogleMaps,
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Test Maps Link')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.indigo200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () {
                  final auto = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("${_nameCtrl.text}, ${_addrCtrl.text}, ${_cityCtrl.text}")}';
                  setState(() => _mapsCtrl.text = auto);
                },
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Auto-Generate from Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 5. Operating Hours & Days (One field per row) ---
  Widget _buildTimingsSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.schedule_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Operating Hours & Days',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.slate900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FormFieldWidget(
            label: 'DAILY SHIFT TIMING',
            placeholder: 'e.g. 24 Hours Open (24×7)',
            controller: _timingCtrl,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _timingPresets.map((t) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    backgroundColor: _timingCtrl.text == t ? AppColors.primaryLight : AppColors.slate100,
                    side: BorderSide(color: _timingCtrl.text == t ? AppColors.primary : Colors.transparent),
                    onPressed: () => setState(() => _timingCtrl.text = t),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          FormFieldWidget(
            label: 'WORKING DAYS',
            placeholder: 'e.g. Mon - Sun (All 7 Days Open)',
            controller: _daysCtrl,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _daysPresets.map((d) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(d, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    backgroundColor: _daysCtrl.text == d ? AppColors.primaryLight : AppColors.slate100,
                    side: BorderSide(color: _daysCtrl.text == d ? AppColors.primary : Colors.transparent),
                    onPressed: () => setState(() => _daysCtrl.text = d),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- 6. Contact & Social Channels (One field per row - Phone & WhatsApp separated) ---
  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.contact_phone_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Business Contact & Social Links',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.slate900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Each contact field has its own full-width row for clear, comfortable editing.',
            style: TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.35),
          ),
          const SizedBox(height: 14),
          // Single row for Calling Number
          FormFieldWidget(
            label: 'CONTACT CALLING NUMBER',
            placeholder: '10-digit calling number',
            prefix: '+91',
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            maxLength: 10,
          ),
          const SizedBox(height: 12),
          // Single row for WhatsApp Number
          FormFieldWidget(
            label: 'WHATSAPP BUSINESS NUMBER',
            placeholder: '10-digit WhatsApp number',
            prefix: '+91',
            controller: _waCtrl,
            keyboardType: TextInputType.phone,
            maxLength: 10,
          ),
          const SizedBox(height: 12),
          FormFieldWidget(
            label: 'BUSINESS EMAIL',
            placeholder: 'contact@yourlibrary.com',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          FormFieldWidget(
            label: 'OFFICIAL WEBSITE',
            placeholder: 'https://24sevenlibrary.in',
            controller: _webCtrl,
          ),
          const SizedBox(height: 12),
          FormFieldWidget(
            label: 'INSTAGRAM LINK',
            placeholder: 'https://instagram.com/your_library',
            controller: _instaCtrl,
          ),
          const SizedBox(height: 12),
          FormFieldWidget(
            label: 'FACEBOOK PAGE',
            placeholder: 'https://facebook.com/your_library',
            controller: _fbCtrl,
          ),
          const SizedBox(height: 12),
          FormFieldWidget(
            label: 'YOUTUBE CHANNEL (OPTIONAL)',
            placeholder: 'https://youtube.com/@your_library',
            controller: _ytCtrl,
          ),
        ],
      ),
    );
  }
}

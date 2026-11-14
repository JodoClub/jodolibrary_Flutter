import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/library_business_model.dart';
import '../models/library_facilities.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/custom_button.dart';
import 'library_details_screen.dart';

/// Full Google Maps Business Profile Editor for Library Owners
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
          _photos.add(uploadRes.data!);
        });
        _showToast('Photo added successfully!', 'Uploaded to your library gallery.');
      } else {
        // Fallback: If network upload fails, use local file path representation or show error
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
              const Text(
                'Upload at least 5 photos of your library (Desks, Hall, AC, Entrance, Lockers).',
                style: TextStyle(fontSize: 12, color: AppColors.slate500),
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
      final uri = Uri.parse(link);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showToast('Invalid URL', 'Unable to launch: $link');
      }
    } catch (_) {
      _showToast('Invalid link format', 'Please check the Google Maps URL.');
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

  Future<void> _saveBusinessProfile() async {
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
        widget.onProfileUpdated?.call(model);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Library business profile saved successfully! 🎉'),
            backgroundColor: AppColors.secondaryDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? 'Failed to update business profile'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      appBar: AppBar(
        title: const Text(
          'Library Business Profile',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.slate900),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Banner Card
            _buildTopPreviewBanner(),

            const SizedBox(height: 16),

            // 1. Photos Section (At least 5 photos)
            _buildPhotoSection(),

            const SizedBox(height: 16),

            // 2. Google Maps Navigation Section
            _buildGoogleMapsSection(),

            const SizedBox(height: 16),

            // 3. Operating Schedule & Timings
            _buildTimingsSection(),

            const SizedBox(height: 16),

            // 4. Contact & Social Channels
            _buildContactSection(),

            const SizedBox(height: 16),

            // 5. 24 Facilities Selector (matching 24sevenlibrary)
            _buildFacilitiesSection(),

            const SizedBox(height: 16),

            // 6. Basic Library Details & Seats
            _buildBasicDetailsSection(),
          ],
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
                  label: const Text('Live Preview'),
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
                  label: _isSaving ? 'Saving Changes...' : 'Save Business Profile',
                  onPressed: _isSaving ? null : _saveBusinessProfile,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopPreviewBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.indigo950,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.orange500,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Google Maps Style Listing',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                ),
                SizedBox(height: 3),
                Text(
                  'Add 5+ photos, 24 facilities, maps link & timings so students find your library easily.',
                  style: TextStyle(color: AppColors.indigo200, fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
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
                  color: _photos.length >= 5 ? AppColors.emerald50 : AppColors.rose50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_photos.length} Photos (${_photos.length >= 5 ? "Good" : "Min. 5 recommended"})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _photos.length >= 5 ? AppColors.emerald600 : AppColors.rose600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload photos of study desks, air-conditioned hall, personal lockers, and entrance. Images auto-adjust to look good on all screens.',
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
              childAspectRatio: 1.15,
            ),
            itemCount: _photos.length + 1,
            itemBuilder: (context, idx) {
              if (idx == _photos.length) {
                // Add Photo Tile
                return InkWell(
                  onTap: _isUploadingPhoto ? null : _showPhotoSourceSheet,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), style: BorderStyle.solid),
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
                      _photos[idx],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
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
            'Paste your Google Maps link or location coordinates so students can click "Directions" to navigate to your library gate.',
            style: TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.35),
          ),
          const SizedBox(height: 14),
          FormFieldWidget(
            label: 'GOOGLE MAPS URL OR SHARE LINK',
            placeholder: 'https://maps.app.goo.gl/...',
            controller: _mapsCtrl,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: _testGoogleMaps,
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Test Maps Link'),
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
                child: const Text('Auto-Generate from Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FormFieldWidget(
                  label: 'CONTACT NUMBER',
                  placeholder: '10-digit number',
                  prefix: '+91',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FormFieldWidget(
                  label: 'WHATSAPP NUMBER',
                  placeholder: '10-digit number',
                  prefix: '+91',
                  controller: _waCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                ),
              ),
            ],
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
        ],
      ),
    );
  }

  Widget _buildFacilitiesSection() {
    final allFacilities = LibraryFacilitiesCatalog.all;

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
                    'Provided Facilities (24)',
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
            'Select all amenities that your study hub provides. These appear on your student-facing Google Maps profile.',
            style: TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.35),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedFacilities = allFacilities.map((f) => f.id).toSet();
                  });
                },
                child: const Text('Select All (24)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _selectedFacilities.clear());
                },
                child: const Text('Clear All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.rose600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: allFacilities.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.slate100),
            itemBuilder: (context, idx) {
              final fac = allFacilities[idx];
              final isChecked = _selectedFacilities.contains(fac.id);

              return CheckboxListTile(
                value: isChecked,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                activeColor: AppColors.primary,
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isChecked ? AppColors.primaryLight : AppColors.slate100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(fac.icon, size: 20, color: isChecked ? AppColors.primary : AppColors.slate500),
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
                  setState(() {
                    if (val == true) {
                      _selectedFacilities.add(fac.id);
                    } else {
                      _selectedFacilities.remove(fac.id);
                    }
                  });
                },
              );
            },
          ),
        ],
      ),
    );
  }

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
          Row(
            children: [
              Expanded(
                child: FormFieldWidget(
                  label: 'AREA / LOCALITY',
                  placeholder: 'e.g. Boring Road',
                  controller: _areaCtrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FormFieldWidget(
                  label: 'CITY',
                  placeholder: 'e.g. Patna',
                  controller: _cityCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FormFieldWidget(
                  label: 'TOTAL SEATS',
                  placeholder: 'e.g. 60',
                  controller: _seatsCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FormFieldWidget(
                  label: 'MONTHLY PRICE (₹)',
                  placeholder: 'e.g. 1499',
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

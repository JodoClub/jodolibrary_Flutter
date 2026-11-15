import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/library_business_model.dart';
import '../models/library_facilities.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Full Google Maps Business Profile screen for Library (Student View & Public View)
class LibraryDetailsScreen extends StatefulWidget {
  final String? libraryId;
  final LibraryBusinessModel? initialData;
  final bool isOwnerPreview;

  const LibraryDetailsScreen({
    super.key,
    this.libraryId,
    this.initialData,
    this.isOwnerPreview = false,
  });

  @override
  State<LibraryDetailsScreen> createState() => _LibraryDetailsScreenState();
}

class _LibraryDetailsScreenState extends State<LibraryDetailsScreen> {
  late LibraryBusinessModel _library;
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPhotoIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _library = widget.initialData!;
    } else {
      _library = const LibraryBusinessModel(
        id: 'default',
        name: 'Achievers Study Hub',
        branchName: 'Main Branch',
        address: 'Boring Road, Patna, Bihar',
        area: 'Boring Road',
        city: 'Patna',
        totalSeats: 60,
        rating: 4.9,
        monthlyPrice: 1499,
        timing: '24 Hours Open (24×7)',
        operatingDays: 'Mon - Sun (All 7 Days Open)',
        contactPhone: '+91 98765 43210',
        contactEmail: 'contact@achieversstudyhub.com',
        websiteUrl: 'https://24sevenlibrary.in',
        whatsappNumber: '+919876543210',
        googleMapsUrl: 'https://maps.google.com/?q=25.6127,85.1296',
        amenities: [
          'wifi', 'ac', 'ro_water', 'power_backup', 'lockers', 'ergonomic_chairs',
          'charging_points', 'cctv', 'biometric', 'open_24_7', 'silent_zone',
          'dining_area', 'newspapers', 'book_bank', 'washrooms', 'two_wheeler_parking',
          'four_wheeler_parking', 'discussion_room', 'tea_coffee', 'reserved_desk',
          'fire_safety', 'printing', 'phone_booth', 'girls_section'
        ],
      );
    }

    if (widget.libraryId != null && widget.libraryId!.isNotEmpty) {
      _fetchLibraryDetails();
    }
  }

  Future<void> _fetchLibraryDetails() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getPublicLibraryDetails(widget.libraryId!);
      if (res.success && res.data != null && mounted) {
        final libJson = res.data!['library'] as Map<String, dynamic>? ?? res.data!;
        setState(() {
          _library = LibraryBusinessModel.fromJson(libJson);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = res.message;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchUrlString(String? url, {String? fallbackScheme}) async {
    if (url == null || url.trim().isEmpty) {
      _showToast('Link not available', 'The library owner has not configured this link yet.');
      return;
    }
    String target = url.trim();
    if (fallbackScheme != null && !target.startsWith('http://') && !target.startsWith('https://')) {
      target = '$fallbackScheme$target';
    }

    try {
      final uri = Uri.parse(target);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {
      _showToast('Could not open link', 'Unable to launch: $target');
    }
  }

  void _openGoogleMaps() {
    if (_library.googleMapsUrl != null && _library.googleMapsUrl!.trim().isNotEmpty) {
      _launchUrlString(_library.googleMapsUrl!);
    } else {
      final q = Uri.encodeComponent('${_library.name}, ${_library.address}, ${_library.city}');
      _launchUrlString('https://www.google.com/maps/search/?api=1&query=$q');
    }
  }

  void _callPhone() {
    final phone = _library.contactPhone?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (phone.isNotEmpty) {
      _launchUrlString('tel:+$phone');
    } else {
      _showToast('Phone number unavailable', 'Contact number has not been provided.');
    }
  }

  void _openWhatsApp() {
    String wa = _library.whatsappNumber?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (wa.isEmpty) {
      wa = _library.contactPhone?.replaceAll(RegExp(r'\D'), '') ?? '';
    }
    if (wa.length == 10) wa = '91$wa';

    if (wa.isNotEmpty) {
      final text = Uri.encodeComponent('Hi ${_library.name}, I am interested in joining your library.');
      _launchUrlString('https://wa.me/$wa?text=$text');
    } else {
      _showToast('WhatsApp unavailable', 'WhatsApp number has not been provided.');
    }
  }

  void _shareLibrary() {
    _showShareModal();
  }

  void _showShareModal() {
    final info = '${_library.displayName}\n'
        '📍 Address: ${_library.address}\n'
        '⏰ Timings: ${_library.timing} (${_library.operatingDays})\n'
        '📞 Phone: ${_library.contactPhone ?? "Available on JodoLibrary"}\n'
        '${_library.whatsappNumber != null && _library.whatsappNumber!.isNotEmpty ? "💬 WhatsApp: ${_library.whatsappNumber}\n" : ""}'
        '${_library.googleMapsUrl != null && _library.googleMapsUrl!.isNotEmpty ? "🗺️ Maps: ${_library.googleMapsUrl}\n" : ""}'
        '🚀 Discover & Book seats on JodoLibrary: https://jodolibrary.com';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  const Text(
                    'Share Library',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.slate900,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.slate500),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Text(
                'Share library details and address directly with friends or students.',
                style: TextStyle(fontSize: 13, color: AppColors.slate500),
              ),
              const SizedBox(height: 24),
              // App Icons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // WhatsApp
                  _buildShareAppTarget(
                    icon: Icons.chat_bubble_rounded,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () {
                      Navigator.pop(ctx);
                      final encoded = Uri.encodeComponent(info);
                      _launchUrlString('whatsapp://send?text=$encoded', fallbackScheme: 'https://wa.me/?text=$encoded');
                    },
                  ),
                  // Messages (SMS)
                  _buildShareAppTarget(
                    icon: Icons.sms_rounded,
                    label: 'Messages',
                    color: AppColors.orange500,
                    onTap: () {
                      Navigator.pop(ctx);
                      final encoded = Uri.encodeComponent(info);
                      _launchUrlString('sms:?body=$encoded');
                    },
                  ),
                  // Copy Link / Text
                  _buildShareAppTarget(
                    icon: Icons.copy_rounded,
                    label: 'Copy Details',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      Clipboard.setData(ClipboardData(text: info));
                      _showToast('Copied to Clipboard', 'Library details copied and ready to share!');
                    },
                  ),
                  // More Apps (System Chooser)
                  _buildShareAppTarget(
                    icon: Icons.share_rounded,
                    label: 'More Apps',
                    color: AppColors.indigo950,
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        const channel = MethodChannel('com.jodo.library/app_install');
                        await channel.invokeMethod('shareText', {
                          'text': info,
                          'title': 'Share ${_library.displayName}',
                        });
                      } catch (_) {
                        Clipboard.setData(ClipboardData(text: info));
                        _showToast('Copied to Clipboard', 'Library details copied!');
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 22),
              // Quick Preview card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_library_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _library.displayName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _library.address,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.slate500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareAppTarget({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.slate800,
              ),
            ),
          ],
        ),
      ),
    );
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

  void _openFullScreenPhoto(int initialIndex) {
    if (_library.photos.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              '${_library.name} Photos (${initialIndex + 1}/${_library.photos.length})',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          body: PageView.builder(
            itemCount: _library.photos.length,
            controller: PageController(initialPage: initialIndex),
            itemBuilder: (context, idx) {
              return InteractiveViewer(
                child: Center(
                  child: Image.network(
                    _library.photos[idx],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = _library.photos.isNotEmpty
        ? _library.photos
        : [
            'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?auto=format&fit=crop&w=1200&q=80',
          ];

    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // 1. Hero Image App Bar / Carousel (Auto-adjust aspect ratio)
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  backgroundColor: AppColors.indigo950,
                  leading: Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Page View Image Carousel
                        PageView.builder(
                          controller: _pageController,
                          physics: const BouncingScrollPhysics(),
                          itemCount: photos.length,
                          onPageChanged: (idx) => setState(() => _currentPhotoIndex = idx),
                          itemBuilder: (context, idx) {
                            return GestureDetector(
                              onTap: () => _openFullScreenPhoto(idx),
                              child: Hero(
                                tag: 'lib_photo_$idx',
                                child: Image.network(
                                  photos[idx],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppColors.slate900,
                                    child: const Center(
                                      child: Icon(Icons.image_not_supported_rounded, color: Colors.white54, size: 48),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        // Gradient protection overlay - wrapped in IgnorePointer to allow horizontal swipe
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.4),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.75),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Left & Right Carousel Slide Arrows
                        if (photos.length > 1) ...[
                          Positioned(
                            left: 10,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  if (_currentPhotoIndex > 0) {
                                    _pageController.previousPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                  ),
                                  child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 24),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  if (_currentPhotoIndex < photos.length - 1) {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                  ),
                                  child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Photo Counter Badge (e.g. 1/5)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_library_rounded, size: 14, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  '${_currentPhotoIndex + 1}/${photos.length} Photos',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Carousel Dots Indicator
                        if (photos.length > 1)
                          Positioned(
                            left: 16,
                            bottom: 16,
                            child: Row(
                              children: List.generate(
                                photos.length,
                                (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  width: _currentPhotoIndex == i ? 18 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _currentPhotoIndex == i ? Colors.white : Colors.white.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // 2. Main Content Body
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.rose50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.rose100),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: AppColors.rose600, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: AppColors.rose600, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        // Header Card: Name, Branch, Rating & Badges
                        _buildHeaderCard(),

                        const SizedBox(height: 14),

                        // Google Maps Style Action Bar (Directions, Call, WhatsApp, Website, Share)
                        _buildGoogleActionPills(),

                        const SizedBox(height: 16),

                        // Operating Timings & Schedule
                        _buildTimingsCard(),

                        const SizedBox(height: 16),

                        // Facilities & Amenities (20+ List from 24sevenlibrary)
                        _buildFacilitiesSection(),

                        const SizedBox(height: 16),

                        // Location & Google Maps Navigation Card
                        _buildLocationCard(),

                        const SizedBox(height: 16),

                        // Business Contact & Social Links
                        _buildContactCard(),

                        const SizedBox(height: 16),

                        // Pricing & Seat Availability
                        _buildPricingCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),

      // Bottom Sticky Booking / Contact Bar
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STARTING FROM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slate400,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '₹${_library.monthlyPrice.toInt()}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const Text(
                          ' / month',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.slate500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton.icon(
                onPressed: _openWhatsApp,
                icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                label: const Text('Enquire on WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _library.displayName,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (_library.area != null && _library.area!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            '${_library.area}, ${_library.city}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.slate600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.indigo950,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _library.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.slate100),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBadge(
                icon: Icons.check_circle_rounded,
                text: 'Verified Study Space',
                bgColor: AppColors.emerald50,
                textColor: AppColors.emerald600,
              ),
              _buildBadge(
                icon: Icons.access_time_filled_rounded,
                text: _library.timing,
                bgColor: AppColors.primaryLight,
                textColor: AppColors.primary,
              ),
              _buildBadge(
                icon: Icons.event_available_rounded,
                text: _library.operatingDays,
                bgColor: AppColors.slate100,
                textColor: AppColors.slate700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String text,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleActionPills() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildActionPill(
            icon: Icons.directions_rounded,
            label: 'Directions',
            color: AppColors.primary,
            isPrimary: true,
            onTap: _openGoogleMaps,
          ),
          const SizedBox(width: 10),
          _buildActionPill(
            icon: Icons.phone_rounded,
            label: 'Call',
            color: AppColors.slate700,
            onTap: _callPhone,
          ),
          const SizedBox(width: 10),
          _buildActionPill(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'WhatsApp',
            color: AppColors.secondaryDark,
            onTap: _openWhatsApp,
          ),
          const SizedBox(width: 10),
          _buildActionPill(
            icon: Icons.share_rounded,
            label: 'Share',
            color: AppColors.slate700,
            onTap: _shareLibrary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? color : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isPrimary ? color : AppColors.slate200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isPrimary ? Colors.white : color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isPrimary ? Colors.white : AppColors.slate800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingsCard() {
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
                'Operating Hours & Schedule',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  title: 'Daily Timing',
                  subtitle: _library.timing,
                  icon: Icons.access_time_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoTile(
                  title: 'Operating Days',
                  subtitle: _library.operatingDays,
                  icon: Icons.calendar_month_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.slate500),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.slate900,
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
    if (fullName.contains('Biometric')) return 'Biometric Access';
    if (fullName.contains('24/7') || fullName.contains('Open 24')) return 'Open 24/7';
    if (fullName.contains('Silent')) return 'Silent Zone';
    if (fullName.contains('Dining')) return 'Cafeteria';
    if (fullName.contains('Newspaper')) return 'Daily News';
    if (fullName.contains('Parking')) return 'Safe Parking';
    if (fullName.contains('Washroom')) return 'Clean Restroom';
    if (fullName.contains('Discussion')) return 'Discussion Room';
    return fullName.split(' ').take(2).join(' ');
  }

  void _showAllFacilitiesModal(List<LibraryFacility> allFacs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Provided Facilities',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${allFacs.length} Verified Amenities for Students',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.slate500),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 20),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: allFacs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                  itemBuilder: (context, idx) {
                    final fac = allFacs[idx];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(fac.icon, size: 20, color: AppColors.primary),
                      ),
                      title: Text(
                        fac.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: AppColors.slate900,
                        ),
                      ),
                      subtitle: Text(
                        fac.description,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.slate500,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.emerald500,
                        size: 20,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.slate300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.slate700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFacilitiesSection() {
    final activeAmenities = _library.amenities;
    final facilities = activeAmenities.isNotEmpty
        ? activeAmenities
            .map((id) => LibraryFacilitiesCatalog.findById(id) ?? LibraryFacility(
                  id: id,
                  name: LibraryFacilitiesCatalog.getName(id),
                  description: 'Verified facility provided by library',
                  icon: Icons.check_circle_outline_rounded,
                  category: 'General',
                ))
            .toList()
        : LibraryFacilitiesCatalog.all.take(16).toList();

    final displayFacs = facilities.length > 8 ? facilities.take(8).toList() : facilities;

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
                  Icon(Icons.stars_rounded, color: AppColors.orange500, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Facilities & Amenities',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${facilities.length} Verified',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Premium student-first study amenities configured by the library owner.',
            style: TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
          const SizedBox(height: 18),
          // 4-Column Grid with Circular Icon at Top and Label Directly Below
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayFacs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 14,
              crossAxisSpacing: 8,
              mainAxisExtent: 82,
            ),
            itemBuilder: (context, idx) {
              final fac = displayFacs[idx];
              return InkWell(
                onTap: () => _showAllFacilitiesModal(facilities),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(fac.icon, size: 22, color: AppColors.primary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getShortFacilityName(fac.name),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate800,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (facilities.length > 8) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _showAllFacilitiesModal(facilities),
              icon: const Icon(Icons.grid_view_rounded, size: 16),
              label: Text('View All Available Facilities (${facilities.length})'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
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
              Icon(Icons.location_on_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Location & Address',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place_outlined, color: AppColors.slate500, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _library.address,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    final hasEmail = _library.contactEmail != null && _library.contactEmail!.isNotEmpty;
    final hasWebsite = _library.websiteUrl != null && _library.websiteUrl!.isNotEmpty;
    final hasInstagram = _library.instagramUrl != null && _library.instagramUrl!.isNotEmpty;
    final hasFacebook = _library.facebookUrl != null && _library.facebookUrl!.isNotEmpty;
    final hasYoutube = _library.youtubeUrl != null && _library.youtubeUrl!.isNotEmpty;
    final hasPhone = _library.contactPhone != null && _library.contactPhone!.isNotEmpty;
    final hasWhatsapp = _library.whatsappNumber != null && _library.whatsappNumber!.isNotEmpty;

    if (!hasEmail && !hasWebsite && !hasInstagram && !hasFacebook && !hasYoutube && !hasPhone && !hasWhatsapp) {
      return const SizedBox.shrink();
    }

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
              Icon(Icons.contact_mail_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Business & Social Contact',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Contact details: Email, Website, Instagram, Facebook, YouTube
          if (hasEmail)
            _buildContactRow(
              icon: Icons.mail_rounded,
              title: 'Email Address',
              value: _library.contactEmail!,
              onTap: () => _launchUrlString(_library.contactEmail, fallbackScheme: 'mailto:'),
            ),
          if (hasWebsite)
            _buildContactRow(
              icon: Icons.language_rounded,
              title: 'Official Website',
              value: _library.websiteUrl!,
              onTap: () => _launchUrlString(_library.websiteUrl),
            ),
          if (hasInstagram)
            _buildContactRow(
              icon: Icons.camera_alt_rounded,
              title: 'Instagram',
              value: _library.instagramUrl!,
              onTap: () => _launchUrlString(_library.instagramUrl),
            ),
          if (hasFacebook)
            _buildContactRow(
              icon: Icons.facebook_rounded,
              title: 'Facebook Page',
              value: _library.facebookUrl!,
              onTap: () => _launchUrlString(_library.facebookUrl),
            ),
          if (hasYoutube)
            _buildContactRow(
              icon: Icons.video_collection_rounded,
              title: 'YouTube Channel',
              value: _library.youtubeUrl!,
              onTap: () => _launchUrlString(_library.youtubeUrl),
            ),
          if (hasPhone || hasWhatsapp) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent_rounded, size: 18, color: AppColors.slate600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Direct Line: ${hasPhone ? _library.contactPhone : _library.whatsappNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: AppColors.slate700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 10, color: AppColors.slate400, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 13, color: AppColors.slate900, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.slate400),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard() {
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
              Icon(Icons.chair_alt_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Desk Capacity & Membership',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildInfoTile(
                  title: 'Total Capacity',
                  subtitle: '${_library.totalSeats} Desks',
                  icon: Icons.meeting_room_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoTile(
                  title: 'Monthly Fee',
                  subtitle: '₹${_library.monthlyPrice.toInt()} / mo',
                  icon: Icons.payments_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

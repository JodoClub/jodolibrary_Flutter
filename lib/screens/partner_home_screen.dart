import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_models.dart';
import '../models/library_business_model.dart';
import '../models/library_facilities.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/custom_button.dart';
import '../widgets/qr_code_widget.dart';
import '../widgets/common_widgets.dart';
import 'library_details_screen.dart';
import 'owner_business_profile_screen.dart';

class PartnerHomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final List<ActivityItem> activities;

  const PartnerHomeScreen({
    super.key,
    required this.onLogout,
    required this.activities,
  });

  @override
  State<PartnerHomeScreen> createState() => _PartnerHomeScreenState();
}

class _PartnerHomeScreenState extends State<PartnerHomeScreen> {
  PartnerTab _activeTab = PartnerTab.overview;
  int _selectedSeat = 14;
  String _seatFilter = 'all'; // 'all', 'occupied', 'reserved', 'available'
  String _memberSearch = '';

  // Real Owner Profile State
  String _ownerName = 'Library Owner';
  String _libraryName = 'My Study Hub';
  String _address = 'Boring Road, Patna';
  String _city = 'Patna';
  int _totalSeats = 60;
  String _ownerPhone = '';
  LibraryBusinessModel? _businessProfile;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final stored = await AuthStorage.getStoredProfile();
    if (mounted) {
      setState(() {
        if (stored['name'] != null && stored['name'].toString().trim().isNotEmpty) {
          _ownerName = stored['name'].toString().trim();
        }
        if (stored['libraryName'] != null && stored['libraryName'].toString().trim().isNotEmpty) {
          _libraryName = stored['libraryName'].toString().trim();
        }
        if (stored['address'] != null && stored['address'].toString().trim().isNotEmpty) {
          _address = stored['address'].toString().trim();
        }
        if (stored['city'] != null && stored['city'].toString().trim().isNotEmpty) {
          _city = stored['city'].toString().trim();
        }
        if (stored['totalSeats'] != null && stored['totalSeats'] is int) {
          _totalSeats = stored['totalSeats'] as int;
        }
        if (stored['phone'] != null) {
          _ownerPhone = stored['phone'].toString().trim();
        }
      });
    }

    try {
      final res = await ApiService.getMe();
      if (res.success && res.data != null && mounted) {
        final user = res.data!['user'] as Map<String, dynamic>?;
        final profile = res.data!['profile'] as Map<String, dynamic>?;
        setState(() {
          if (user?['name'] != null && user!['name'].toString().trim().isNotEmpty) {
            _ownerName = user['name'].toString().trim();
          }
          if (user?['mobile'] != null) {
            _ownerPhone = user!['mobile'].toString().trim();
          }
          if (profile?['name'] != null && profile!['name'].toString().trim().isNotEmpty) {
            _libraryName = profile['name'].toString().trim();
          }
          if (profile?['address'] != null && profile!['address'].toString().trim().isNotEmpty) {
            _address = profile['address'].toString().trim();
          }
          if (profile?['city'] != null && profile!['city'].toString().trim().isNotEmpty) {
            _city = profile['city'].toString().trim();
          }
          if (profile?['totalSeats'] != null) {
            _totalSeats = profile!['totalSeats'] as int;
          }
        });
        await AuthStorage.saveOwnerProfile(
          ownerName: _ownerName,
          libraryName: _libraryName,
          address: _address,
          city: _city,
          totalSeats: _totalSeats,
        );
      }
    } catch (_) {}

    try {
      final bizRes = await ApiService.getOwnerBusinessProfile();
      if (bizRes.success && bizRes.data != null && mounted) {
        setState(() {
          _businessProfile = LibraryBusinessModel.fromJson(bizRes.data!);
          _libraryName = _businessProfile!.name;
          _address = _businessProfile!.address;
          _city = _businessProfile!.city;
          _totalSeats = _businessProfile!.totalSeats;
          if (_businessProfile!.contactPhone != null &&
              _businessProfile!.contactPhone!.trim().isNotEmpty) {
            _ownerPhone = _businessProfile!.contactPhone!.trim();
          }
        });
      }
    } catch (_) {}
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'LO';
  }

  String _getFirstName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0];
    }
    return 'Partner';
  }

  // Add Member State
  final List<MemberInfo> _members = [
    const MemberInfo(name: 'Aarav Kumar', seat: 'Seat #B-14', status: 'Present', plan: 'Full Day Dedicated', phone: '+91 98765 43210'),
    const MemberInfo(name: 'Ananya Verma', seat: 'Seat #B-24', status: 'Present', plan: 'Morning Shift', phone: '+91 98111 22334'),
    const MemberInfo(name: 'Rahul Kumar', seat: 'Seat #A-06', status: 'Present', plan: 'Full Day Dedicated', phone: '+91 97222 33445'),
    const MemberInfo(name: 'Priya Singh', seat: 'Seat #C-12', status: 'Renewal Due', plan: 'Evening Shift', phone: '+91 99333 44556'),
    const MemberInfo(name: 'Vikram Raj', seat: 'Seat #A-18', status: 'Absent', plan: 'Full Day Dedicated', phone: '+91 98444 55667'),
    const MemberInfo(name: 'Sneha Roy', seat: 'Seat #B-02', status: 'Present', plan: 'Morning Shift', phone: '+91 97555 66778'),
  ];

  SeatInfo _getSeatInfo(int num) {
    if (num == 14) {
      return SeatInfo(
        number: num,
        student: 'Aarav Kumar',
        plan: 'Full Day Dedicated Desk',
        status: 'Occupied · Present Inside',
        time: 'Checked in at 08:15 AM',
        validTill: '25/10/2026',
      );
    }
    if (num == 24) {
      return SeatInfo(
        number: num,
        student: 'Ananya Verma',
        plan: 'Morning Shift (6AM - 2PM)',
        status: 'Occupied · Present Inside',
        time: 'Checked in at 09:42 AM',
        validTill: '30/10/2026',
      );
    }
    if (num <= 42) {
      return SeatInfo(
        number: num,
        student: 'Student #$num',
        plan: 'Monthly Dedicated Desk',
        status: 'Occupied',
        time: 'Checked in today',
        validTill: '15/11/2026',
      );
    }
    if (num <= 48) {
      return SeatInfo(
        number: num,
        student: 'Reserved Desk',
        plan: 'Reserved for Walk-in Booking',
        status: 'Reserved',
        time: 'Available from Evening',
        validTill: 'N/A',
      );
    }
    return SeatInfo(
      number: num,
      student: 'Unallocated',
      plan: 'Open for New Admission',
      status: 'Available',
      time: 'Empty desk',
      validTill: 'N/A',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: SizedBox(
            width: double.infinity,
            child: _buildCurrentTab(),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _buildBottomNav(),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_activeTab) {
      case PartnerTab.overview:
        return _buildOverviewTab();
      case PartnerTab.seats:
        return _buildSeatsTab();
      case PartnerTab.members:
        return _buildMembersTab();
      case PartnerTab.profile:
        return _buildProfileTab();
    }
  }

  // ==========================================
  // TAB 1: OVERVIEW DASHBOARD
  // ==========================================
  Widget _buildOverviewTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Indigo Header
        Container(
          width: double.infinity,
          color: AppColors.indigo950,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.orange500,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.orange500.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _getInitials(_ownerName),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OWNER PORTAL',
                            style: TextStyle(
                              color: AppColors.orange400,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Hello, ${_getFirstName(_ownerName)} 👋',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  OutlinedButton(
                    onPressed: widget.onLogout,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text(
                      'Switch',
                      style: TextStyle(color: AppColors.indigo200, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Library Status Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.orange500.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.apartment, color: AppColors.orange400, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _libraryName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '$_address, $_city · $_totalSeats Desks',
                              style: const TextStyle(color: AppColors.indigo300, fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.emerald500.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '42/60 Occupied',
                        style: TextStyle(
                          color: AppColors.emerald300,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Actions
              Row(
                children: [
                  Expanded(
                    child: _buildOwnerAction(
                      icon: Icons.person_add_alt_1,
                      label: 'Add Member',
                      bg: AppColors.orange50,
                      color: AppColors.orange500,
                      onTap: () => _openAddMemberModal(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildOwnerAction(
                      icon: Icons.camera_alt,
                      label: 'Scan Pass',
                      bg: AppColors.indigo50,
                      color: AppColors.indigo950,
                      onTap: () => _openDeskScannerModal(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildOwnerAction(
                      icon: Icons.qr_code,
                      label: 'Standee QR',
                      bg: AppColors.emerald50,
                      color: AppColors.emerald600,
                      onTap: () => _openStandeeQRModal(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 4 Stat Cards in 2x2 grid
              Row(
                children: [
                  Expanded(
                    child: _buildOwnerStatCard(
                      icon: Icons.people_alt,
                      tag: '+12 new',
                      tagColor: AppColors.emerald600,
                      tagBg: AppColors.emerald50,
                      label: 'ACTIVE MEMBERS',
                      val: '148',
                      iconBg: AppColors.indigo50,
                      iconColor: AppColors.indigo950,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildOwnerStatCard(
                      icon: Icons.grid_view_rounded,
                      tag: '70% full',
                      tagColor: AppColors.orange600,
                      tagBg: AppColors.orange50,
                      label: 'LIVE OCCUPANCY',
                      val: '42 / 60',
                      iconBg: AppColors.orange50,
                      iconColor: AppColors.orange600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildOwnerStatCard(
                      icon: Icons.account_balance_wallet,
                      tag: '₹2.18L mo',
                      tagColor: AppColors.indigo800,
                      tagBg: AppColors.indigo50,
                      label: 'TODAY COLLECTION',
                      val: '₹18,400',
                      iconBg: AppColors.emerald50,
                      iconColor: AppColors.emerald600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildOwnerStatCard(
                      icon: Icons.event,
                      tag: '7 Days',
                      tagColor: AppColors.rose600,
                      tagBg: AppColors.rose50,
                      label: 'RENEWALS DUE',
                      val: '18',
                      iconBg: AppColors.rose50,
                      iconColor: AppColors.rose600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Live Seat Occupancy Bar Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'LIVE FLOOR STATUS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.slate400,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Seat Occupancy',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppColors.slate900,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _activeTab = PartnerTab.seats),
                          icon: const Icon(Icons.map_outlined, size: 14, color: AppColors.orange500),
                          label: const Text(
                            'Floor Map',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: AppColors.orange500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Occupied: 42', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.slate700)),
                        Text('Available: 18', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.slate500)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Progress Bar (70% Occupied, 10% Reserved, 20% Available)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        height: 10,
                        child: Row(
                          children: const [
                            Expanded(flex: 70, child: ColoredBox(color: AppColors.indigo950)),
                            Expanded(flex: 10, child: ColoredBox(color: AppColors.orange400)),
                            Expanded(flex: 20, child: ColoredBox(color: AppColors.slate200)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        _DotLegend(color: AppColors.indigo950, label: '42 Occupied'),
                        _DotLegend(color: AppColors.orange400, label: '6 Reserved'),
                        _DotLegend(color: AppColors.slate300, label: '12 Available'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Real-time Activity Feed
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'LIVE ATTENDANCE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.slate400,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Recent Activity',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppColors.slate900,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.emerald50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Live Sync',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.emerald600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    ...widget.activities.take(5).map((act) {
                      Color bg = AppColors.slate50;
                      Color iconColor = AppColors.slate600;
                      IconData iconData = Icons.schedule;

                      if (act.icon == 'check') {
                        bg = AppColors.emerald50;
                        iconColor = AppColors.emerald600;
                        iconData = Icons.check_circle_outline;
                      } else if (act.icon == 'wallet') {
                        bg = AppColors.indigo50;
                        iconColor = AppColors.indigo950;
                        iconData = Icons.account_balance_wallet_outlined;
                      } else if (act.icon == 'users') {
                        bg = AppColors.orange50;
                        iconColor = AppColors.orange600;
                        iconData = Icons.person_add_outlined;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: act.isHighlight ? AppColors.emerald50 : AppColors.slate50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: act.isHighlight ? AppColors.emerald400 : AppColors.slate100,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Icon(iconData, size: 18, color: iconColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    act.title,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.slate900,
                                    ),
                                  ),
                                  Text(
                                    act.detail,
                                    style: const TextStyle(fontSize: 10, color: AppColors.slate400),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOwnerAction({
    required IconData icon,
    required String label,
    required Color bg,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.slate800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerStatCard({
    required IconData icon,
    required String tag,
    required Color tagColor,
    required Color tagBg,
    required String label,
    required String val,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: iconColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tag,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: tagColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.slate400,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            val,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.slate900,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: SEATS & FLOOR MAP
  // ==========================================
  Widget _buildSeatsTab() {
    final seatData = _getSeatInfo(_selectedSeat);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          color: AppColors.indigo950,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Floor Map & Seats',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.emerald500.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '60 Total Desks',
                      style: TextStyle(
                        color: AppColors.emerald300,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap any desk to see member allocation',
                style: TextStyle(color: AppColors.indigo200, fontSize: 11),
              ),
              const SizedBox(height: 14),

              // Filter pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterPill('all', 'All (60)'),
                    _buildFilterPill('occupied', 'Occupied (42)'),
                    _buildFilterPill('reserved', 'Reserved (6)'),
                    _buildFilterPill('available', 'Available (12)'),
                  ],
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // 60-seats Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: 60,
                  itemBuilder: (ctx, i) {
                    final num = i + 1;
                    final isOccupied = num <= 42;
                    final isReserved = num > 42 && num <= 48;
                    final isAvailable = num > 48;

                    if (_seatFilter == 'occupied' && !isOccupied) return const SizedBox();
                    if (_seatFilter == 'reserved' && !isReserved) return const SizedBox();
                    if (_seatFilter == 'available' && !isAvailable) return const SizedBox();

                    final isSelected = _selectedSeat == num;

                    Color bg = isOccupied
                        ? AppColors.indigo950
                        : isReserved
                            ? AppColors.orange100
                            : AppColors.slate100;
                    Color txt = isOccupied
                        ? Colors.white
                        : isReserved
                            ? AppColors.orange600
                            : AppColors.slate500;

                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _selectedSeat = num),
                      child: Container(
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(color: AppColors.orange500, width: 2.5)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$num',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: txt,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),

              // Selected Seat Inspector Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.indigo50.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.indigo100),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.orange500,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Seat #$_selectedSeat',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              seatData.status,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: AppColors.indigo950,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          seatData.time,
                          style: const TextStyle(fontSize: 10, color: AppColors.slate500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildSeatRow('Student Name', seatData.student),
                    _buildSeatRow('Membership Plan', seatData.plan),
                    _buildSeatRow('Validity', seatData.validTill, isGreen: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill(String id, String label) {
    final isSel = _seatFilter == id;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _seatFilter = id),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? AppColors.orange500 : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isSel ? Colors.white : AppColors.indigo200,
          ),
        ),
      ),
    );
  }

  Widget _buildSeatRow(String label, String value, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: isGreen ? AppColors.emerald600 : AppColors.slate900,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: MEMBERS & ATTENDANCE
  // ==========================================
  Widget _buildMembersTab() {
    final filtered = _members.where((m) {
      return '${m.name} ${m.seat} ${m.plan}'.toLowerCase().contains(_memberSearch.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          color: AppColors.indigo950,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Members & Students',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openAddMemberModal(),
                    icon: const Icon(Icons.add, size: 14, color: Colors.white),
                    label: const Text(
                      'Add',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange500,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage 148 registered study hub members',
                style: TextStyle(color: AppColors.indigo200, fontSize: 11),
              ),
              const SizedBox(height: 14),

              // Search Input
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _memberSearch = val),
                  decoration: const InputDecoration(
                    hintText: 'Search member, seat, or mobile',
                    hintStyle: TextStyle(color: AppColors.slate400, fontSize: 12),
                    prefixIcon: Icon(Icons.search, color: AppColors.slate400, size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: filtered.map((m) {
              Color statusBg = AppColors.slate100;
              Color statusColor = AppColors.slate600;

              if (m.status == 'Present') {
                statusBg = AppColors.emerald50;
                statusColor = AppColors.emerald600;
              } else if (m.status == 'Renewal Due') {
                statusBg = AppColors.amber50;
                statusColor = AppColors.amber600;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.indigo50,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            m.name.substring(0, 2).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.indigo950,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppColors.slate900,
                              ),
                            ),
                            Text(
                              '${m.seat} · ${m.plan}',
                              style: const TextStyle(fontSize: 10, color: AppColors.slate400),
                            ),
                            Text(
                              m.phone,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        m.status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 4: PROFILE & SETTINGS
  // ==========================================
  Widget _buildProfileTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          color: AppColors.indigo950,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandLogo(compact: true, inverse: true),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.orange500,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.orange500.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _getInitials(_ownerName),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _ownerName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Library Owner · $_libraryName',
                          style: const TextStyle(fontSize: 12, color: AppColors.indigo200),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _openOwnerBusinessProfileScreen,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildUnifiedLibrarySection(),
              const SizedBox(height: 14),

              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openStandeeQRModal(),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Row(
                        children: [
                          Icon(Icons.qr_code, color: AppColors.orange500, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'View & Print Gate Attendance Standee QR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate800,
                            ),
                          ),
                        ],
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.slate400),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              CustomButton(
                label: 'Log out / Switch Account',
                variant: ButtonVariant.ghost,
                leading: const Icon(Icons.logout, size: 18, color: AppColors.rose600),
                onPressed: widget.onLogout,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openOwnerBusinessProfileScreen() {
    final initial = _businessProfile ??
        LibraryBusinessModel(
          id: 'owner-lib',
          name: _libraryName,
          address: _address,
          city: _city,
          totalSeats: _totalSeats,
          contactPhone: _ownerPhone,
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerBusinessProfileScreen(
          initialProfile: initial,
          onProfileUpdated: (updated) {
            setState(() {
              _businessProfile = updated;
              _libraryName = updated.name;
              _address = updated.address;
              _city = updated.city;
              _totalSeats = updated.totalSeats;
            });
          },
        ),
      ),
    ).then((_) => _loadProfileData());
  }

  void _openStudentPreview() {
    final profile = _businessProfile ??
        LibraryBusinessModel(
          id: 'owner-lib',
          name: _libraryName,
          address: _address,
          city: _city,
          totalSeats: _totalSeats,
          contactPhone: _ownerPhone,
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryDetailsScreen(
          initialData: profile,
          isOwnerPreview: true,
        ),
      ),
    );
  }

  Widget _buildUnifiedLibrarySection() {
    final photos = _businessProfile?.photos ?? const [];
    final amenities = _businessProfile?.amenities ?? const [];
    final hasMaps = _businessProfile?.googleMapsUrl != null &&
        _businessProfile!.googleMapsUrl!.trim().isNotEmpty;
    final timing = _businessProfile?.timing ?? '24 Hours Open (24×7)';
    final days = _businessProfile?.operatingDays ?? 'Mon - Sun (All 7 Days Open)';
    final phone = _businessProfile?.contactPhone ?? (_ownerPhone.isNotEmpty ? _ownerPhone : '+91 98765 43210');
    final whatsapp = _businessProfile?.whatsappNumber ?? (_ownerPhone.isNotEmpty ? _ownerPhone : null);
    final price = _businessProfile?.monthlyPrice ?? 1499.0;
    final branch = _businessProfile?.branchName;

    // Top facilities from catalog matching active amenities or defaults
    final activeFacs = (amenities.isNotEmpty ? amenities : [
      'wifi', 'ac', 'ro_water', 'power_backup', 'lockers', 'ergonomic_chairs', 'charging_points', 'cctv'
    ]).map((id) => LibraryFacilitiesCatalog.findById(id) ?? LibraryFacility(
      id: id,
      name: LibraryFacilitiesCatalog.getName(id),
      description: 'Verified amenity',
      icon: LibraryFacilitiesCatalog.getIcon(id),
      category: 'General',
    )).toList();

    final top8Facs = activeFacs.take(8).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP: Library Photos Section
          if (photos.isNotEmpty)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(12),
                      itemCount: photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              Image.network(
                                photos[i],
                                width: 220,
                                height: 136,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 220,
                                  height: 136,
                                  color: AppColors.slate200,
                                  child: const Icon(Icons.broken_image_rounded, size: 28, color: AppColors.slate400),
                                ),
                              ),
                              Positioned(
                                left: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#${i + 1}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 18,
                  right: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${photos.length}/5 Photos',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                    ),
                  ),
                ),
              ],
            )
          else
            // Empty photo banner prompt
            InkWell(
              onTap: _openOwnerBusinessProfileScreen,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Upload Library Photos (Up to 5)',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.slate900),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Showcase study desks, AC hall & entrance to attract students.',
                      style: TextStyle(fontSize: 11, color: AppColors.slate600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // 2. Library Identity Header (No separate "Google Business Profile" title)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _libraryName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate900,
                        ),
                      ),
                      if (branch != null && branch.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          branch,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emerald50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 3, backgroundColor: AppColors.emerald500),
                      SizedBox(width: 5),
                      Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.emerald600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.slate100),
          const SizedBox(height: 12),

          // 3. Address & Maps (No duplicates)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_address, $_city',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.slate800, height: 1.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final mapsLink = _businessProfile?.googleMapsUrl ??
                        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent("$_libraryName, $_address, $_city")}';
                    final uri = Uri.parse(mapsLink);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: hasMaps ? AppColors.indigo50 : AppColors.slate100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: hasMaps ? AppColors.indigo200 : AppColors.slate200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasMaps ? Icons.directions_rounded : Icons.search_rounded,
                          size: 13,
                          color: hasMaps ? AppColors.primary : AppColors.slate600,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          hasMaps ? 'Google Maps Navigation Linked' : 'Search Location on Google Maps',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: hasMaps ? AppColors.primary : AppColors.slate700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.open_in_new_rounded, size: 11, color: hasMaps ? AppColors.primary : AppColors.slate500),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.slate100),
          const SizedBox(height: 14),

          // 4. Unified Specifications (Total Desks, Timings, Days, Contact, WhatsApp, Plan)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                _buildUnifiedInfoRow(Icons.chair_alt_rounded, 'Total Desks', '$_totalSeats Dedicated Desks'),
                _buildUnifiedInfoRow(Icons.access_time_rounded, 'Daily Timings', timing),
                _buildUnifiedInfoRow(Icons.calendar_month_rounded, 'Working Days', days),
                _buildUnifiedInfoRow(Icons.phone_rounded, 'Calling Contact', phone),
                if (whatsapp != null && whatsapp.isNotEmpty)
                  _buildUnifiedInfoRow(Icons.chat_rounded, 'WhatsApp Support', whatsapp),
                _buildUnifiedInfoRow(Icons.currency_rupee_rounded, 'Standard Plan', '₹${price.toInt()} / student / month'),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.slate100),
          const SizedBox(height: 14),

          // 5. Facilities Section (Circular App-Icon Grid, 8 items + "+ More" Popup)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PROVIDED FACILITIES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate400,
                        letterSpacing: 1,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${activeFacs.length} Facilities',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 8 App-Icon Circular Tiles (4 columns x 2 rows)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: top8Facs.length,
                  itemBuilder: (context, idx) {
                    final fac = top8Facs[idx];
                    return InkWell(
                      onTap: () => _showAllFacilitiesModal(activeFacs),
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
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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
                              fontSize: 10,
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

                const SizedBox(height: 12),

                // "+X More Facilities" Interactive Button -> opens bottom sheet modal
                InkWell(
                  onTap: () => _showAllFacilitiesModal(activeFacs),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.apps_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              activeFacs.length > 8
                                  ? '+${activeFacs.length - 8} More Facilities Provided'
                                  : 'View All Available Facilities (${activeFacs.length})',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primary),
                            ),
                          ],
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.slate400),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          const Divider(height: 1, color: AppColors.slate100),
          const SizedBox(height: 16),

          // 6. Action Buttons (Full width stacked for responsive, zero-overflow design)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomButton(
                  height: 48,
                  label: 'Edit Library Profile & Photos',
                  leading: const Icon(Icons.edit_note_rounded, size: 18),
                  onPressed: _openOwnerBusinessProfileScreen,
                ),
                const SizedBox(height: 10),
                CustomButton(
                  height: 46,
                  label: 'Preview Student View',
                  variant: ButtonVariant.ghost,
                  leading: const Icon(Icons.remove_red_eye_outlined, size: 18, color: AppColors.primary),
                  onPressed: _openStudentPreview,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.slate400),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.slate800),
            ),
          ),
        ],
      ),
    );
  }

  void _showAllFacilitiesModal(List<LibraryFacility> facilities) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
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
                        '${facilities.length} Verified Amenities for Students',
                        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: AppColors.slate500),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.slate200),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: facilities.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.slate100),
                  itemBuilder: (context, idx) {
                    final fac = facilities[idx];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.slate900),
                      ),
                      subtitle: Text(
                        fac.description,
                        style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                      ),
                      trailing: const Icon(Icons.check_circle_rounded, color: AppColors.emerald500, size: 18),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: 'Close',
                variant: ButtonVariant.ghost,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
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

  // ==========================================
  // BOTTOM NAV
  // ==========================================
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.slate200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavTab(PartnerTab.overview, Icons.grid_view_rounded, 'Overview'),
          _buildNavTab(PartnerTab.seats, Icons.apartment, 'Seats'),
          _buildNavTab(PartnerTab.members, Icons.people_alt_rounded, 'Members'),
          _buildNavTab(PartnerTab.profile, Icons.person_rounded, 'Profile'),
        ],
      ),
    );
  }

  Widget _buildNavTab(PartnerTab tab, IconData icon, String label) {
    final isActive = _activeTab == tab;
    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? AppColors.orange500 : AppColors.slate400,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                color: isActive ? AppColors.orange500 : AppColors.slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // OWNER MODALS
  // ==========================================
  void _openStandeeQRModal() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'OFFICIAL GATE QR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.orange500,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'Attendance Standee',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate900,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const QRCodeGraphic(size: 180),
              const SizedBox(height: 16),
              const Text(
                'Achievers Study Hub - Gate 1',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Display this standee at library entrance desk.',
                style: TextStyle(fontSize: 11, color: AppColors.slate500),
              ),
              const SizedBox(height: 20),
              CustomButton(
                label: 'Done / Close',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDeskScannerModal() {
    bool scanDone = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setScanState) {
          return Dialog(
            backgroundColor: AppColors.slate950,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'DESK SCANNER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.orange400,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            'Scan Student Gate Pass',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (!scanDone) ...[
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      alignment: Alignment.center,
                      child: const QRCodeGraphic(size: 110),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Point phone camera at student’s digital pass.',
                      style: TextStyle(fontSize: 11, color: AppColors.slate400),
                    ),
                    const SizedBox(height: 20),
                    CustomButton(
                      label: 'Simulate Student Pass Scan',
                      onPressed: () => setScanState(() => scanDone = true),
                    ),
                  ] else ...[
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.emerald500,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.check, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Student Pass Verified!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Aarav Kumar (Seat #B-14)',
                      style: TextStyle(fontSize: 12, color: AppColors.emerald400),
                    ),
                    const SizedBox(height: 20),
                    CustomButton(
                      label: 'Done',
                      variant: ButtonVariant.secondary,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openAddMemberModal() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String? selectedDesk = 'Seat #B-15';
    String? selectedPlan = 'Full Day Dedicated (₹1,499/mo)';
    DateTime? selectedDate = DateTime.now();

    String? nameError;
    String? phoneError;
    String? deskError;
    String? planError;
    String? dateError;

    final deskOptions = [
      'Seat #A-01',
      'Seat #A-02',
      'Seat #A-05',
      'Seat #B-15',
      'Seat #B-16',
      'Seat #C-01',
      'Seat #C-05',
      'Seat #D-08',
      'Seat #D-12',
    ];

    final planOptions = [
      'Full Day Dedicated (₹1,499/mo)',
      'Morning Shift (₹899/mo)',
      'Evening Shift (₹899/mo)',
      'Night Owl Shift (₹999/mo)',
      '24x7 Dedicated (₹1,999/mo)',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'ADMISSION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.orange500,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            'Add New Member',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.slate900,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FormFieldWidget(
                    label: 'STUDENT FULL NAME',
                    placeholder: 'e.g. Manisha Kumari',
                    controller: nameCtrl,
                    errorText: nameError,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ],
                    onChanged: (val) {
                      if (nameError != null) {
                        setModalState(() => nameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  FormFieldWidget(
                    label: 'MOBILE NUMBER',
                    placeholder: '10-digit mobile number',
                    prefix: '+91',
                    keyboardType: TextInputType.phone,
                    controller: phoneCtrl,
                    maxLength: 10,
                    errorText: phoneError,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onChanged: (val) {
                      if (phoneError != null) {
                        setModalState(() => phoneError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownFieldWidget(
                    label: 'ASSIGN DESK',
                    value: selectedDesk,
                    items: deskOptions,
                    errorText: deskError,
                    hint: 'Select Desk',
                    onChanged: (val) {
                      setModalState(() {
                        selectedDesk = val;
                        deskError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownFieldWidget(
                    label: 'MEMBERSHIP PLAN',
                    value: selectedPlan,
                    items: planOptions,
                    errorText: planError,
                    hint: 'Select Plan',
                    onChanged: (val) {
                      setModalState(() {
                        selectedPlan = val;
                        planError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  DateFieldWidget(
                    label: 'JOINING DATE',
                    selectedDate: selectedDate,
                    errorText: dateError,
                    placeholder: 'Select Joining Date',
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                    onDateSelected: (date) {
                      setModalState(() {
                        selectedDate = date;
                        dateError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 22),
                  CustomButton(
                    label: 'Register & Allocate Seat',
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();

                      bool hasError = false;
                      String? newNameError;
                      String? newPhoneError;
                      String? newDeskError;
                      String? newPlanError;
                      String? newDateError;

                      if (name.isEmpty) {
                        newNameError = 'Student name is required';
                        hasError = true;
                      } else if (name.length < 3) {
                        newNameError = 'Name must be at least 3 characters';
                        hasError = true;
                      }

                      if (phone.isEmpty) {
                        newPhoneError = 'Mobile number is required';
                        hasError = true;
                      } else if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
                        newPhoneError = 'Enter a valid 10-digit mobile number';
                        hasError = true;
                      }

                      if (selectedDesk == null || selectedDesk!.isEmpty) {
                        newDeskError = 'Please assign a desk';
                        hasError = true;
                      }

                      if (selectedPlan == null || selectedPlan!.isEmpty) {
                        newPlanError = 'Please select a plan';
                        hasError = true;
                      }

                      if (selectedDate == null) {
                        newDateError = 'Please choose a joining date';
                        hasError = true;
                      }

                      if (hasError) {
                        setModalState(() {
                          nameError = newNameError;
                          phoneError = newPhoneError;
                          deskError = newDeskError;
                          planError = newPlanError;
                          dateError = newDateError;
                        });
                        return; // DO NOT PROCEED
                      }

                      setState(() {
                        _members.insert(
                          0,
                          MemberInfo(
                            name: name,
                            seat: selectedDesk!,
                            status: 'Present',
                            plan: selectedPlan!.split(' (')[0],
                            phone: '+91 $phone',
                          ),
                        );
                      });

                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Member $name registered successfully!'),
                          backgroundColor: AppColors.emerald500,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DotLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _DotLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.slate500),
        ),
      ],
    );
  }
}

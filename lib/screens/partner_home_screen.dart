import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_models.dart';
import '../models/library_business_model.dart';
import '../models/library_facilities.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../theme/app_theme.dart';
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
  int _selectedSeat = 1;
  String _seatFilter = 'all'; // 'all', 'occupied', 'reserved', 'available'
  String _memberSearch = '';

  // Real Owner Profile State
  String _ownerName = 'Library Owner';
  String? _ownerPhotoUrl;
  String _libraryName = 'My Study Hub';
  String _address = 'Boring Road, Patna';
  String _city = 'Patna';
  int _totalSeats = 60;
  String _ownerPhone = '';
  LibraryBusinessModel? _businessProfile;

  // Real Members & Admission Requests State
  List<MemberInfo> _members = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _loadingMembers = false;
  bool _loadingFloorMap = false;
  List<SeatInfo> _floorMapSeats = [];
  int _occupiedSeatsCount = 0;
  int _reservedSeatsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadMembersData();
    _loadFloorMapData();
  }

  Future<void> _loadMembersData() async {
    if (!mounted) return;
    setState(() => _loadingMembers = true);
    try {
      final res = await ApiService.getMembers(size: 100);
      if (res.success && res.data != null && mounted) {
        final list = (res.data!['members'] as List?) ?? [];
        setState(() {
          _members = list.map((m) => MemberInfo.fromJson(m as Map<String, dynamic>)).toList();
        });
      }
    } catch (_) {}

    try {
      final reqRes = await ApiService.getOwnerAdmissionRequests();
      if (reqRes.success && reqRes.data != null && mounted) {
        setState(() {
          _pendingRequests = reqRes.data!
              .where((r) => r is Map<String, dynamic> && r['status'] == 'PENDING')
              .map((r) => r as Map<String, dynamic>)
              .toList();
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _loadingMembers = false);
    }
  }

  Future<void> _loadFloorMapData() async {
    if (!mounted) return;
    setState(() => _loadingFloorMap = true);
    try {
      final res = await ApiService.getFloorMap(filter: _seatFilter);
      if (res.success && res.data != null && mounted) {
        final seatsList = (res.data!['seats'] as List?) ?? [];
        setState(() {
          _floorMapSeats = seatsList.map((s) => SeatInfo.fromJson(s as Map<String, dynamic>)).toList();
          _occupiedSeatsCount = (res.data!['occupied'] as num?)?.toInt() ?? 0;
          _reservedSeatsCount = (res.data!['reserved'] as num?)?.toInt() ?? 0;
          if (res.data!['totalSeats'] != null) {
            _totalSeats = (res.data!['totalSeats'] as num).toInt();
          }
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loadingFloorMap = false);
    }
  }

  Future<void> _loadProfileData() async {
    final stored = await AuthStorage.getStoredProfile();
    if (mounted) {
      setState(() {
        if (stored['ownerPhoto'] != null && stored['ownerPhoto'].toString().trim().isNotEmpty) {
          _ownerPhotoUrl = stored['ownerPhoto'].toString().trim();
        }
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
          if (user?['avatarUrl'] != null && user!['avatarUrl'].toString().trim().isNotEmpty) {
            _ownerPhotoUrl = user['avatarUrl'].toString().trim();
          } else if (user?['photoUrl'] != null && user!['photoUrl'].toString().trim().isNotEmpty) {
            _ownerPhotoUrl = user['photoUrl'].toString().trim();
          } else if (user?['avatar'] != null && user!['avatar'].toString().trim().isNotEmpty) {
            _ownerPhotoUrl = user['avatar'].toString().trim();
          }
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
          ownerPhoto: _ownerPhotoUrl,
        );
        if (_ownerPhotoUrl != null && _ownerPhotoUrl!.isNotEmpty) {
          await AuthStorage.saveOwnerPhoto(_ownerPhotoUrl!);
        }
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

  SeatInfo _getSeatInfo(int num) {
    if (_floorMapSeats.isNotEmpty) {
      final matches = _floorMapSeats.where((s) => s.number == num);
      if (matches.isNotEmpty) {
        return matches.first;
      }
    }
    return SeatInfo(
      number: num,
      student: 'Desk #$num',
      plan: 'Open for Admission',
      status: 'Available',
      time: 'Empty desk',
      validTill: 'N/A',
      shiftTiming: 'Available all shifts',
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
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        child: _ownerPhotoUrl != null && _ownerPhotoUrl!.isNotEmpty
                            ? Image.network(
                                _ownerPhotoUrl!,
                                fit: BoxFit.cover,
                                width: 48,
                                height: 48,
                                errorBuilder: (_, __, ___) => Text(
                                  _getInitials(_ownerName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : Text(
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
                      child: Text(
                        '$_occupiedSeatsCount/$_totalSeats Occupied',
                        style: const TextStyle(
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

              // Dynamic calculations for seat occupancy
              Builder(
                builder: (context) {
                  final totalSeats = _totalSeats > 0 ? _totalSeats : 10;
                  final occupied = _occupiedSeatsCount.clamp(0, totalSeats);
                  final reserved = _reservedSeatsCount.clamp(0, totalSeats - occupied);
                  final available = (totalSeats - occupied - reserved).clamp(0, totalSeats);
                  final occFlex = totalSeats > 0 ? (occupied * 100 ~/ totalSeats) : 0;
                  final resFlex = totalSeats > 0 ? (reserved * 100 ~/ totalSeats) : 0;
                  final availFlex = (100 - occFlex - resFlex).clamp(0, 100);

                  return Column(
                    children: [
                      // 4 Stat Cards in 2x2 grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildOwnerStatCard(
                              icon: Icons.people_alt,
                              tag: '${_members.length} enrolled',
                              tagColor: AppColors.emerald600,
                              tagBg: AppColors.emerald50,
                              label: 'ACTIVE MEMBERS',
                              val: '${_members.length}',
                              iconBg: AppColors.indigo50,
                              iconColor: AppColors.indigo950,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildOwnerStatCard(
                              icon: Icons.grid_view_rounded,
                              tag: '${totalSeats == 0 ? 0 : (occupied * 100 ~/ totalSeats)}% full',
                              tagColor: AppColors.orange600,
                              tagBg: AppColors.orange50,
                              label: 'LIVE OCCUPANCY',
                              val: '$occupied / $totalSeats',
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
                              children: [
                                Text('Occupied: $occupied', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.slate700)),
                                Text('Available: $available', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.slate500)),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Progress Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                height: 10,
                                child: Row(
                                  children: [
                                    if (occFlex > 0)
                                      Expanded(flex: occFlex, child: const ColoredBox(color: AppColors.indigo950)),
                                    if (resFlex > 0)
                                      Expanded(flex: resFlex, child: const ColoredBox(color: AppColors.orange400)),
                                    if (availFlex > 0)
                                      Expanded(flex: availFlex, child: const ColoredBox(color: AppColors.slate200)),
                                    if (occFlex == 0 && resFlex == 0 && availFlex == 0)
                                      const Expanded(child: ColoredBox(color: AppColors.slate200)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _DotLegend(color: AppColors.indigo950, label: '$occupied Occupied'),
                                _DotLegend(color: AppColors.orange400, label: '$reserved Reserved'),
                                _DotLegend(color: AppColors.slate300, label: '$available Available'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
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
    final totalSeats = _totalSeats > 0 ? _totalSeats : 10;
    final seatData = _getSeatInfo(_selectedSeat);
    final availCount = (totalSeats - _occupiedSeatsCount - _reservedSeatsCount).clamp(0, totalSeats);

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
                    child: Text(
                      '$totalSeats Total Desks',
                      style: const TextStyle(
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
                'Tap any desk to see member allocation and shift timings',
                style: TextStyle(color: AppColors.indigo200, fontSize: 11),
              ),
              const SizedBox(height: 14),

              // Filter pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterPill('all', 'All ($totalSeats)'),
                    _buildFilterPill('occupied', 'Occupied ($_occupiedSeatsCount)'),
                    _buildFilterPill('reserved', 'Reserved ($_reservedSeatsCount)'),
                    _buildFilterPill('available', 'Available ($availCount)'),
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
              // Seats Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: _loadingFloorMap
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(color: AppColors.orange500),
                        ),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: totalSeats,
                        itemBuilder: (ctx, i) {
                          final num = i + 1;
                          final seat = _getSeatInfo(num);
                          final stLower = seat.status.toLowerCase();
                          final isOccupied = stLower.contains('occupied');
                          final isReserved = stLower.contains('reserved');
                          final isAvailable = !isOccupied && !isReserved;

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
                    if (seatData.shiftTiming != null && seatData.shiftTiming!.isNotEmpty)
                      _buildSeatRow('Shift Timing', seatData.shiftTiming!),
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
      return '${m.name} ${m.seat} ${m.plan} ${m.phone}'.toLowerCase().contains(_memberSearch.toLowerCase());
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
              Text(
                'Manage ${_members.length} registered study hub members',
                style: const TextStyle(color: AppColors.indigo200, fontSize: 11),
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
            children: [
              // Pending Admission Requests Section
              if (_pendingRequests.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.amber50.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.amber200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.hourglass_top_rounded, size: 16, color: AppColors.amber700),
                              const SizedBox(width: 6),
                              Text(
                                'PENDING ADMISSIONS (${_pendingRequests.length})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.amber800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.amber100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Awaiting Student',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.amber800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._pendingRequests.map((req) {
                        final sName = req['studentName']?.toString() ?? 'Student';
                        final sPhone = req['studentPhone']?.toString() ?? '';
                        final seatLbl = req['seatLabel']?.toString() ?? 'Seat';
                        final plan = req['planName']?.toString() ?? 'Monthly Plan';
                        final timing = req['shiftTiming']?.toString() ?? 'Full Day';
                        final fee = req['monthlyFee']?.toString() ?? '';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.amber100),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.amber50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  sName.isNotEmpty ? sName.substring(0, 1).toUpperCase() : 'S',
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.amber800),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.slate900)),
                                    Text('$seatLbl · $plan', style: const TextStyle(fontSize: 10.5, color: AppColors.slate600)),
                                    Text('Timing: $timing', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                    if (sPhone.isNotEmpty)
                                      Text(sPhone, style: const TextStyle(fontSize: 10, color: AppColors.slate400)),
                                  ],
                                ),
                              ),
                              if (fee.isNotEmpty)
                                Text('₹$fee/mo', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.emerald600)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

              // Loading Spinner
              if (_loadingMembers)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppColors.orange500),
                  ),
                )
              // Empty State
              else if (filtered.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.indigo50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.people_outline_rounded, size: 36, color: AppColors.indigo950),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _members.isEmpty ? 'No Members Enrolled Yet' : 'No matching members found',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.slate900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _members.isEmpty
                            ? 'Your study hub currently has 0 members.\nAdd a student via mobile number to allot a seat & timing.'
                            : 'Try searching by different name, desk number, or mobile number.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.4),
                      ),
                      if (_members.isEmpty) ...[
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _openAddMemberModal(),
                          icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
                          label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.orange500,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              // Members List
              else
                ...filtered.map((m) {
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
                                m.name.isNotEmpty
                                    ? m.name.substring(0, m.name.length >= 2 ? 2 : 1).toUpperCase()
                                    : 'M',
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
                                  style: const TextStyle(fontSize: 10.5, color: AppColors.slate600),
                                ),
                                if (m.shiftTiming != null && m.shiftTiming!.isNotEmpty)
                                  Text(
                                    'Timing: ${m.shiftTiming}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                Text(
                                  m.phone,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.slate400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Status & Attendance Column
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Enrollment Status Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (m.membershipStatus.toUpperCase() == 'ACTIVE') ? AppColors.emerald50 : AppColors.slate100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: (m.membershipStatus.toUpperCase() == 'ACTIVE') ? AppColors.emerald200 : AppColors.slate200),
                                  ),
                                  child: Text(
                                    (m.membershipStatus.toUpperCase() == 'ACTIVE') ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: (m.membershipStatus.toUpperCase() == 'ACTIVE') ? AppColors.emerald700 : AppColors.slate600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                // Punch status
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      m.status.toLowerCase().contains('present') ? Icons.circle : Icons.circle_outlined,
                                      size: 7,
                                      color: m.status.toLowerCase().contains('present') ? AppColors.emerald600 : AppColors.slate400,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      m.status.toLowerCase().contains('present')
                                          ? (m.checkInTime != null ? 'In: ${m.checkInTime}' : 'Present')
                                          : m.status,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: m.status.toLowerCase().contains('present') ? AppColors.emerald700 : AppColors.slate500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),

                            // Direct Profile Button
                            InkWell(
                              onTap: m.studentId != null ? () => _openMemberProfileModal(m) : null,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.indigo50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.visibility_outlined, size: 12, color: AppColors.indigo950),
                                    SizedBox(width: 3),
                                    Text('Profile', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.indigo950)),
                                  ],
                                ),
                              ),
                            ),

                            // 3-dots Menu
                            if (m.studentId != null)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.slate600),
                                onSelected: (action) async {
                                  if (action == 'VIEW_PROFILE') {
                                    _openMemberProfileModal(m);
                                  } else if (action == 'REALLOT_SEAT') {
                                    _openReallotSeatModal(m);
                                  } else if (action == 'TOGGLE_STATUS') {
                                    _toggleMemberStatus(m);
                                  } else if (action == 'RELEASE_SEAT' || action == 'REMOVE') {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: Text(action == 'RELEASE_SEAT' ? 'Release Seat?' : 'Remove Member?'),
                                        content: Text(action == 'RELEASE_SEAT'
                                            ? 'Are you sure you want to release ${m.name}\'s seat? The student remains registered.'
                                            : 'Are you sure you want to remove ${m.name} from the library?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                          TextButton(
                                            onPressed: () => Navigator.pop(c, true),
                                            child: Text(action == 'RELEASE_SEAT' ? 'Release' : 'Remove', style: const TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final res = await ApiService.removeMember(m.studentId!, action: action);
                                      if (res.success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(res.message ?? 'Action completed successfully'),
                                            backgroundColor: AppColors.emerald500,
                                          ),
                                        );
                                        _loadMembersData();
                                        _loadFloorMapData();
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(res.message ?? 'Operation failed'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'VIEW_PROFILE',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_outline_rounded, size: 16, color: AppColors.indigo950),
                                        SizedBox(width: 8),
                                        Text('View Student Profile', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'REALLOT_SEAT',
                                    child: Row(
                                      children: [
                                        Icon(Icons.chair_alt_rounded, size: 16, color: AppColors.orange600),
                                        SizedBox(width: 8),
                                        Text('Re-allot / Edit Seat', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'TOGGLE_STATUS',
                                    child: Row(
                                      children: [
                                        Icon((m.membershipStatus.toUpperCase() == 'ACTIVE') ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                                            size: 16, color: (m.membershipStatus.toUpperCase() == 'ACTIVE') ? AppColors.amber700 : AppColors.emerald600),
                                        const SizedBox(width: 8),
                                        Text((m.membershipStatus.toUpperCase() == 'ACTIVE') ? 'Make Student Inactive' : 'Make Student Active',
                                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(
                                    value: 'RELEASE_SEAT',
                                    child: Row(
                                      children: [
                                        Icon(Icons.event_seat_outlined, size: 16, color: AppColors.slate600),
                                        SizedBox(width: 8),
                                        Text('Release Seat Only', style: TextStyle(fontSize: 12.5)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'REMOVE',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_remove_rounded, size: 16, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Remove from Library', style: TextStyle(fontSize: 12.5, color: Colors.red, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF090D1A), // Deep midnight black
                Color(0xFF0F172A), // Dark slate
                Color(0xFF1E1B4B), // Deep indigo
              ],
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // JodoLibrary Branded Background Banner Watermark in Top Back of Owner Profile
              Positioned(
                right: -20,
                top: -8,
                bottom: -8,
                child: Opacity(
                  opacity: 0.18,
                  child: Image.asset(
                    'assets/images/logo_transparent.png',
                    fit: BoxFit.contain,
                    height: 105,
                  ),
                ),
              ),
              // Subtle Banner Brand Badge on Top Right
              Positioned(
                top: 14,
                right: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 12, color: AppColors.orange400),
                      SizedBox(width: 4),
                      Text(
                        'JodoLibrary Partner',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Main Owner Profile Row Content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                child: Row(
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
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      child: _ownerPhotoUrl != null && _ownerPhotoUrl!.isNotEmpty
                          ? Image.network(
                              _ownerPhotoUrl!,
                              fit: BoxFit.cover,
                              width: 60,
                              height: 60,
                              errorBuilder: (_, __, ___) => Text(
                                _getInitials(_ownerName),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Text(
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
                          const Text(
                            'Library Owner',
                            style: TextStyle(fontSize: 12, color: AppColors.indigo200),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _showEditOwnerProfileDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

  Future<void> _showEditOwnerProfileDialog() async {
    final nameCtrl = TextEditingController(text: _ownerName);
    String? tempPhotoUrl = _ownerPhotoUrl;
    bool isUploadingPhoto = false;
    bool isSaving = false;
    final picker = ImagePicker();

    await showDialog(
      context: context,
      barrierDismissible: !isSaving && !isUploadingPhoto,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickAndUploadImage(ImageSource source) async {
              try {
                final picked = await picker.pickImage(
                  source: source,
                  imageQuality: 80,
                  maxWidth: 1024,
                );
                if (picked == null) return;

                setDialogState(() => isUploadingPhoto = true);

                final uploadRes = await ApiService.uploadLibraryPhoto(File(picked.path));
                if (uploadRes.success && uploadRes.data != null) {
                  setDialogState(() {
                    tempPhotoUrl = uploadRes.data!;
                    isUploadingPhoto = false;
                  });
                } else {
                  setDialogState(() => isUploadingPhoto = false);
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(uploadRes.message ?? 'Photo upload failed'),
                        backgroundColor: AppColors.rose600,
                      ),
                    );
                  }
                }
              } catch (e) {
                setDialogState(() => isUploadingPhoto = false);
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to pick photo: $e'),
                      backgroundColor: AppColors.rose600,
                    ),
                  );
                }
              }
            }

            void showPhotoSourceSheet() {
              showModalBottomSheet(
                context: dialogContext,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (sheetContext) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppColors.slate300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const Text(
                          'Update Profile Photo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                          ),
                          title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w700)),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            pickAndUploadImage(ImageSource.camera);
                          },
                        ),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.emerald50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.photo_library_rounded, color: AppColors.emerald600),
                          ),
                          title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            pickAndUploadImage(ImageSource.gallery);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 8,
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Owner Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slate900,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.slate400),
                          onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 1. Owner Photo with Camera Badge
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        GestureDetector(
                          onTap: isUploadingPhoto || isSaving ? null : showPhotoSourceSheet,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: AppColors.orange500,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.orange500.withValues(alpha: 0.25),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: isUploadingPhoto
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : (tempPhotoUrl != null && tempPhotoUrl!.isNotEmpty
                                    ? Image.network(
                                        tempPhotoUrl!,
                                        fit: BoxFit.cover,
                                        width: 90,
                                        height: 90,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                            _getInitials(nameCtrl.text.isNotEmpty ? nameCtrl.text : _ownerName),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          _getInitials(nameCtrl.text.isNotEmpty ? nameCtrl.text : _ownerName),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      )),
                          ),
                        ),
                        GestureDetector(
                          onTap: isUploadingPhoto || isSaving ? null : showPhotoSourceSheet,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: isUploadingPhoto || isSaving ? null : showPhotoSourceSheet,
                      child: Text(
                        tempPhotoUrl != null ? 'Change Photo' : 'Upload Photo',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // 2. Owner Name Field
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Owner Full Name',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        hintText: 'Enter your name',
                        hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
                        prefixIcon: const Icon(Icons.person_rounded, color: AppColors.slate500, size: 20),
                        filled: true,
                        fillColor: AppColors.slate50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.slate300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: AppColors.slate600, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSaving || isUploadingPhoto
                                ? null
                                : () async {
                                    final newName = nameCtrl.text.trim();
                                    if (newName.isEmpty) {
                                      ScaffoldMessenger.of(this.context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please enter owner name'),
                                          backgroundColor: AppColors.rose600,
                                        ),
                                      );
                                      return;
                                    }

                                    setDialogState(() => isSaving = true);

                                    try {
                                      // 1. Update in backend
                                      if (tempPhotoUrl != null && tempPhotoUrl!.trim().isNotEmpty) {
                                        await ApiService.updateOwnerPhoto(tempPhotoUrl!.trim());
                                      }
                                      await ApiService.updateOwnerBusinessProfile(
                                        ownerName: newName,
                                        ownerPhoto: tempPhotoUrl,
                                      );
                                      await ApiService.updateOwnerProfile(
                                        ownerName: newName,
                                        libraryName: _libraryName,
                                        address: _address,
                                        city: _city,
                                        totalSeats: _totalSeats,
                                        ownerPhoto: tempPhotoUrl,
                                      );

                                      // 2. Persist locally
                                      await AuthStorage.saveOwnerProfile(
                                        ownerName: newName,
                                        libraryName: _libraryName,
                                        address: _address,
                                        city: _city,
                                        totalSeats: _totalSeats,
                                        ownerPhoto: tempPhotoUrl,
                                      );
                                      if (tempPhotoUrl != null) {
                                        await AuthStorage.saveOwnerPhoto(tempPhotoUrl!);
                                      }

                                      // 3. Update main state
                                      if (mounted) {
                                        setState(() {
                                          _ownerName = newName;
                                          if (tempPhotoUrl != null) {
                                            _ownerPhotoUrl = tempPhotoUrl;
                                          }
                                        });
                                      }

                                      Navigator.of(dialogContext).pop();

                                      if (mounted) {
                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Owner profile updated successfully!'),
                                            backgroundColor: AppColors.emerald600,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setDialogState(() => isSaving = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to update: $e'),
                                            backgroundColor: AppColors.rose600,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Save Changes',
                                    style: TextStyle(fontWeight: FontWeight.w800),
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
      },
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

  void _openMemberProfileModal(MemberInfo m) {
    if (m.studentId == null) return;
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<ApiResponse<Map<String, dynamic>>>(
        future: ApiService.getMemberProfile(m.studentId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Dialog(
              child: Padding(
                padding: EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text('Loading Student Profile...', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data?.data;
          final studentName = data?['fullName']?.toString() ?? m.name;
          final phone = data?['phone']?.toString() ?? m.phone;
          final code = data?['studentCode']?.toString() ?? 'N/A';
          final seat = data?['seat']?.toString() ?? m.seat;
          final shift = data?['shiftTiming']?.toString() ?? m.shiftTiming ?? 'N/A';
          final plan = data?['planName']?.toString() ?? m.plan;
          final validTill = data?['validTill']?.toString() ?? 'N/A';
          final gender = data?['gender']?.toString() ?? 'N/A';
          final exam = data?['examCategory']?.toString() ?? 'N/A';
          final emergency = data?['emergencyContact']?.toString() ?? 'None';
          final attToday = data?['attendanceToday']?.toString() ?? m.status;
          final memStatus = data?['membershipStatus']?.toString() ?? m.membershipStatus;
          final isActive = memStatus.toUpperCase() == 'ACTIVE';

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.indigo50,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                              style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.indigo950, fontSize: 18),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(studentName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                              Text('ID: $code · $phone', style: const TextStyle(fontSize: 11, color: AppColors.slate500)),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.emerald50 : AppColors.slate100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isActive ? AppColors.emerald200 : AppColors.slate200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Membership: ${isActive ? "Active" : "Inactive"}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isActive ? AppColors.emerald800 : AppColors.slate700)),
                        Text('Today: $attToday',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slate600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildProfileField('Assigned Desk', seat),
                  _buildProfileField('Shift Timing', shift),
                  _buildProfileField('Subscription Plan', plan),
                  _buildProfileField('Valid Till', validTill),
                  _buildProfileField('Target Exam', exam),
                  _buildProfileField('Gender', gender),
                  _buildProfileField('Emergency Contact', emergency),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openReallotSeatModal(m);
                          },
                          icon: const Icon(Icons.chair_alt_rounded, size: 14),
                          label: const Text('Re-allot Seat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.orange600,
                            side: const BorderSide(color: AppColors.orange300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      ),
    );
  }

  Widget _buildProfileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.slate500)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.slate900)),
        ],
      ),
    );
  }

  void _openReallotSeatModal(MemberInfo m) {
    if (m.studentId == null) return;
    final total = _totalSeats > 0 ? _totalSeats : 10;
    List<int> availableSeats = [];
    if (_floorMapSeats.isNotEmpty) {
      availableSeats = _floorMapSeats
          .where((s) => s.status.toLowerCase() == 'available' && s.number <= total)
          .map((s) => s.number)
          .toList();
    }
    if (availableSeats.isEmpty) {
      availableSeats = List.generate(total, (i) => i + 1);
    }

    int selectedNewSeat = availableSeats.first;
    String selectedShift = m.shiftTiming ?? 'Full Day (08:00 AM - 08:00 PM)';
    bool isSaving = false;
    String? modalError;

    final timingOptions = [
      'Full Day (08:00 AM - 08:00 PM)',
      'Morning Shift (06:00 AM - 02:00 PM)',
      'Evening Shift (02:00 PM - 10:00 PM)',
      'Night Owl Shift (10:00 PM - 06:00 AM)',
      '24 Hours Dedicated (24x7)',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Re-allot Seat for ${m.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Current Seat: ${m.seat} · Select from available seats (1 - $total):',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.slate500)),
                const SizedBox(height: 14),
                if (modalError != null) ...[
                  Text(modalError!, style: const TextStyle(color: Colors.red, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                ],
                const Text('NEW SEAT NUMBER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate500)),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: selectedNewSeat,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: availableSeats
                      .map((n) => DropdownMenuItem(value: n, child: Text('Seat #$n (Available)')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedNewSeat = v);
                  },
                ),
                const SizedBox(height: 14),
                const Text('SHIFT TIMING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate500)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: timingOptions.contains(selectedShift) ? selectedShift : timingOptions.first,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: timingOptions
                      .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedShift = v);
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);
                            final res = await ApiService.changeMemberSeat(
                              studentId: m.studentId!,
                              newSeatNumber: selectedNewSeat,
                              shiftTiming: selectedShift,
                            );
                            setModalState(() => isSaving = false);
                            if (res.success) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message ?? 'Seat changed successfully to Seat #$selectedNewSeat'),
                                  backgroundColor: AppColors.emerald500,
                                ),
                              );
                              _loadMembersData();
                              _loadFloorMapData();
                            } else {
                              setModalState(() => modalError = res.message ?? 'Failed to change seat');
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange500,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(isSaving ? 'Updating...' : 'Confirm Re-allotment',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleMemberStatus(MemberInfo m) async {
    if (m.studentId == null) return;
    final isActive = m.membershipStatus.toUpperCase() == 'ACTIVE';
    final actionText = isActive ? 'Make Inactive' : 'Make Active';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('$actionText?'),
        content: Text(isActive
            ? 'Making ${m.name} inactive will release their seat #${m.seat} for new admissions. The student remains registered.'
            : 'Reactivate ${m.name}\'s membership?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(actionText, style: TextStyle(color: isActive ? Colors.orange : AppColors.emerald600)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final res = await ApiService.toggleMemberStatus(m.studentId!);
      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? 'Status updated successfully'),
            backgroundColor: AppColors.emerald500,
          ),
        );
        _loadMembersData();
        _loadFloorMapData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? 'Operation failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openAddMemberModal() {
    int step = 1; // 1: Search & verify student, 2: Seat, shift & plan allocation
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final feeCtrl = TextEditingController(
      text: _businessProfile != null && _businessProfile!.monthlyPrice > 0
          ? '${_businessProfile!.monthlyPrice.toInt()}'
          : '1499',
    );

    bool isSearching = false;
    bool isRegistering = false;
    bool isSendingRequest = false;
    String? phoneError;
    String? nameError;
    String? globalError;

    Map<String, dynamic>? studentData;
    bool showQuickSignup = false;

    String? selectedDesk;
    String selectedTiming = 'Full Day (08:00 AM - 08:00 PM)';
    String selectedPlan = 'Full Day Dedicated Desk';
    String selectedDuration = '1m';
    String selectedExamCategory = 'UPSC / Civil Services';
    String selectedGender = 'Male';

    // Generate desk options from available seats
    final total = _totalSeats > 0 ? _totalSeats : 10;
    List<String> deskOptions = [];
    if (_floorMapSeats.isNotEmpty) {
      deskOptions = _floorMapSeats
          .where((s) => s.status.toLowerCase() == 'available' && s.number <= total)
          .map((s) => 'Seat #${s.number}')
          .toList();
    }
    if (deskOptions.isEmpty) {
      deskOptions = List.generate(total, (i) => 'Seat #${i + 1}');
    }
    selectedDesk = deskOptions.first;

    final timingOptions = [
      'Full Day (08:00 AM - 08:00 PM)',
      'Morning Shift (06:00 AM - 02:00 PM)',
      'Evening Shift (02:00 PM - 10:00 PM)',
      'Night Owl Shift (10:00 PM - 06:00 AM)',
      '24 Hours Dedicated (24x7)',
    ];

    final planOptions = [
      'Full Day Dedicated Desk',
      'Morning Shift Desk',
      'Evening Shift Desk',
      'Night Owl Dedicated Desk',
      '24x7 Flexi Desk',
    ];

    final examOptions = [
      'UPSC / Civil Services',
      'SSC / Railway / Banking',
      'NEET / Medical Entrance',
      'JEE / Engineering Entrance',
      'State PCS / State Exams',
      'CA / CS / Commerce',
      'School / College Exams',
      'Other Competitive Exams',
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.orange50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  step == 1 ? 'STEP 1 OF 2 · STUDENT SEARCH' : 'STEP 2 OF 2 · ALLOT SEAT & PLAN',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.orange600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            step == 1 ? 'Add Student Member' : 'Allot Seat & Shift Timing',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.slate900,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded, color: AppColors.slate500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (globalError != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.rose50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.rose100),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.rose600, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              globalError!,
                              style: const TextStyle(color: AppColors.rose600, fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ----------------------------------------------------
                  // STEP 1: Search student or Quick Signup
                  // ----------------------------------------------------
                  if (step == 1) ...[
                    const Text(
                      'Search a registered student by mobile number. If the student does not exist, you can quickly create an account for them.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.slate500, height: 1.35),
                    ),
                    const SizedBox(height: 16),

                    FormFieldWidget(
                      label: 'STUDENT MOBILE NUMBER',
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
                        if (studentData != null || showQuickSignup) {
                          setModalState(() {
                            studentData = null;
                            showQuickSignup = false;
                            globalError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    if (!showQuickSignup && studentData == null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isSearching
                              ? null
                              : () async {
                                  final phone = phoneCtrl.text.trim();
                                  if (phone.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
                                    setModalState(() => phoneError = 'Enter a valid 10-digit mobile number');
                                    return;
                                  }
                                  setModalState(() {
                                    isSearching = true;
                                    phoneError = null;
                                    globalError = null;
                                  });
                                  final res = await ApiService.searchStudentByPhone(phone);
                                  setModalState(() => isSearching = false);

                                  if (res.success && res.data != null) {
                                    final isOwnerOrAdmin = res.data!['isOwnerOrAdmin'] == true;
                                    if (isOwnerOrAdmin) {
                                      setModalState(() {
                                        studentData = null;
                                        showQuickSignup = false;
                                        globalError = '⚠️ ' + (res.data!['message']?.toString() ??
                                            'This mobile number is registered as a Library Owner / Admin and cannot be registered as a student member.');
                                      });
                                      return;
                                    }
                                    final found = res.data!['found'] == true;
                                    if (found) {
                                      setModalState(() {
                                        studentData = res.data;
                                        showQuickSignup = false;
                                      });
                                    } else {
                                      setModalState(() {
                                        studentData = null;
                                        showQuickSignup = true;
                                      });
                                    }
                                  } else {
                                    setModalState(() => globalError = res.message ?? 'Search failed');
                                  }
                                },
                          icon: isSearching
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.search_rounded, size: 16, color: Colors.white),
                          label: Text(
                            isSearching ? 'Searching...' : 'Search Student',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 0,
                          ),
                        ),
                      ),

                    // Found Student Profile Card
                    if (studentData != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.emerald50.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.emerald200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    (studentData!['fullName']?.toString().isNotEmpty ?? false)
                                        ? studentData!['fullName'].toString().substring(0, 1).toUpperCase()
                                        : 'S',
                                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.emerald800, fontSize: 16),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        studentData!['fullName']?.toString() ?? 'Student',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.slate900),
                                      ),
                                      Text(
                                        'Code: ${studentData!['studentCode'] ?? "STU"} · +91 ${phoneCtrl.text.trim()}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                                      ),
                                      if (studentData!['examCategory'] != null)
                                        Text(
                                          'Exam: ${studentData!['examCategory']}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.emerald700),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (studentData!['hasActiveMembership'] == true) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.rose50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.rose200),
                                ),
                                child: Text(
                                  '⚠️ Active member in ${studentData!['activeLibraryName'] ?? "another library"}. Please resolve previous membership first.',
                                  style: const TextStyle(color: AppColors.rose600, fontSize: 10.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ] else if (studentData!['hasPendingRequest'] == true) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.amber50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.amber200),
                                ),
                                child: const Text(
                                  '⏳ An admission request is already pending for this student in this library.',
                                  style: TextStyle(color: AppColors.amber800, fontSize: 10.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (studentData!['hasActiveMembership'] != true && studentData!['hasPendingRequest'] != true)
                        CustomButton(
                          label: 'Continue to Allot Seat & Shift →',
                          onPressed: () => setModalState(() => step = 2),
                        ),
                    ],

                    // Quick Signup Form for New Student
                    if (showQuickSignup) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.indigo50.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.indigo200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.person_add_rounded, size: 16, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text(
                                  'NEW STUDENT REGISTRATION',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 0.8),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No student account found for +91 ${phoneCtrl.text.trim()}. Fill details below to register:',
                              style: const TextStyle(fontSize: 11, color: AppColors.slate600),
                            ),
                            const SizedBox(height: 12),
                            FormFieldWidget(
                              label: 'STUDENT FULL NAME',
                              placeholder: 'e.g. Rahul Sharma',
                              controller: nameCtrl,
                              errorText: nameError,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                              ],
                              onChanged: (val) {
                                if (nameError != null) setModalState(() => nameError = null);
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownFieldWidget(
                              label: 'EXAM PREPARATION CATEGORY',
                              value: selectedExamCategory,
                              items: examOptions,
                              hint: 'Select exam category',
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedExamCategory = val);
                              },
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'GENDER',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: ['Male', 'Female', 'Other'].map((g) {
                                final isSel = selectedGender == g;
                                return InkWell(
                                  onTap: () => setModalState(() => selectedGender = g),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSel ? AppColors.primary : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isSel ? AppColors.primary : AppColors.slate200),
                                    ),
                                    child: Text(
                                      g,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isSel ? Colors.white : AppColors.slate700,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isRegistering
                                    ? null
                                    : () async {
                                        final name = nameCtrl.text.trim();
                                        if (name.isEmpty || name.length < 3) {
                                          setModalState(() => nameError = 'Enter student name (at least 3 characters)');
                                          return;
                                        }
                                        setModalState(() {
                                          isRegistering = true;
                                          globalError = null;
                                        });
                                        final regRes = await ApiService.quickRegisterStudent(
                                          fullName: name,
                                          mobile: phoneCtrl.text.trim(),
                                          examCategory: selectedExamCategory,
                                          gender: selectedGender,
                                        );
                                        setModalState(() => isRegistering = false);

                                        if (regRes.success && regRes.data != null) {
                                          setModalState(() {
                                            studentData = regRes.data;
                                            step = 2;
                                          });
                                        } else {
                                          setModalState(() => globalError = regRes.message ?? 'Registration failed');
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.emerald600,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  elevation: 0,
                                ),
                                child: Text(
                                  isRegistering ? 'Registering...' : 'Register Student & Proceed →',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  // ----------------------------------------------------
                  // STEP 2: Allot Seat, Shift Timing & Plan
                  // ----------------------------------------------------
                  if (step == 2) ...[
                    // Student Header Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.indigo50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 16, color: AppColors.indigo950),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${studentData?['fullName'] ?? "Student"} · +91 ${phoneCtrl.text.trim()}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.indigo950),
                            ),
                          ),
                          InkWell(
                            onTap: () => setModalState(() => step = 1),
                            child: const Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Desk Selector
                    DropdownFieldWidget(
                      label: 'ASSIGN AVAILABLE DESK',
                      value: selectedDesk,
                      items: deskOptions,
                      hint: 'Select Available Desk',
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedDesk = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Shift Timing Selector
                    DropdownFieldWidget(
                      label: 'SHIFT TIMING',
                      value: selectedTiming,
                      items: timingOptions,
                      hint: 'Select Shift Timing',
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedTiming = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Membership Plan Selector
                    DropdownFieldWidget(
                      label: 'MEMBERSHIP PLAN',
                      value: selectedPlan,
                      items: planOptions,
                      hint: 'Select Membership Plan',
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedPlan = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Plan Duration
                    const Text(
                      'PLAN DURATION',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        {'label': '1 Month', 'val': '1m'},
                        {'label': '3 Months', 'val': '3m'},
                        {'label': '6 Months', 'val': '6m'},
                      ].map((d) {
                        final isSel = selectedDuration == d['val'];
                        return Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => selectedDuration = d['val']!),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isSel ? AppColors.primary : AppColors.slate200),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                d['label']!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSel ? Colors.white : AppColors.slate700,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Monthly Fee
                    FormFieldWidget(
                      label: 'MONTHLY FEE (₹)',
                      placeholder: 'e.g. 1499',
                      controller: feeCtrl,
                      prefix: '₹',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 22),

                    // Send Request Button
                    CustomButton(
                      label: isSendingRequest ? 'Sending Admission Request...' : 'Send Admission Request to Student',
                      onPressed: isSendingRequest
                          ? () {}
                          : () async {
                              final feeText = feeCtrl.text.trim();
                              final fee = double.tryParse(feeText) ?? 1499;

                              if (selectedDesk == null || selectedDesk!.isEmpty) {
                                setModalState(() => globalError = 'Please select a desk');
                                return;
                              }

                              setModalState(() {
                                isSendingRequest = true;
                                globalError = null;
                              });

                              final sId = studentData?['studentId']?.toString();
                              final res = await ApiService.sendAdmissionRequest(
                                studentId: sId,
                                mobile: phoneCtrl.text.trim(),
                                fullName: studentData?['fullName']?.toString(),
                                assignedSeat: selectedDesk!,
                                planName: selectedPlan,
                                shiftTiming: selectedTiming,
                                monthlyFee: fee,
                                duration: selectedDuration,
                              );

                              setModalState(() => isSendingRequest = false);

                              if (res.success) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Admission request sent to ${studentData?['fullName'] ?? "student"}! Seat ${selectedDesk!} is reserved pending student acceptance.',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    backgroundColor: AppColors.emerald500,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                _loadMembersData();
                                _loadFloorMapData();
                              } else {
                                setModalState(() => globalError = res.message ?? 'Failed to send request');
                              }
                            },
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

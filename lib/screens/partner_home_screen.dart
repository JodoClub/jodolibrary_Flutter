import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_models.dart';
import '../models/library_business_model.dart';
import '../models/library_facilities.dart';
import '../models/library_rate_card.dart';
import '../services/api_config.dart';
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
  bool _seatsListView = true; // Default to the requested List View (Left: Seat #, Right: Alloted to)
  String _seatSearch = '';
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
  List<Map<String, dynamic>> _removedMembers = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _loadingMembers = false;
  bool _loadingRemovedMembers = false;
  String _membersSubTab = 'active'; // 'active' or 'removed'
  bool _loadingFloorMap = false;
  List<SeatInfo> _floorMapSeats = [];
  int _occupiedSeatsCount = 0;
  int _reservedSeatsCount = 0;

  // Fee Collections & Payment Tracking State
  List<FeeCollectionItem> _feeCollections = [];
  num _totalCollectedAmount = 0;
  num _todayCollectedAmount = 0;
  num _thisMonthCollectedAmount = 0;
  int _renewalsDueCount = 0;
  bool _loadingCollections = false;
  String _memberValidityFilter = 'all'; // 'all', 'due_soon', 'active'
  int _feeCollectionTab = 0; // 0: All, 1: Active Members, 2: Removed Members

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadMembersData();
    _loadCollectionsData();
    _loadFloorMapData();
  }

  Future<void> _refreshAllData() async {
    await Future.wait([
      _loadProfileData(),
      _loadMembersData(),
      _loadCollectionsData(),
      _loadFloorMapData(),
    ]);
  }

  Future<void> _loadCollectionsData() async {
    if (!mounted) return;
    setState(() => _loadingCollections = true);
    try {
      final res = await ApiService.getOwnerCollections();
      if (res.success && res.data != null && mounted) {
        final d = res.data!;
        final itemsList = (d['items'] as List?) ?? [];
        setState(() {
          _feeCollections = itemsList
              .map((item) => FeeCollectionItem.fromJson(item as Map<String, dynamic>))
              .toList();
          _totalCollectedAmount = d['totalCollected'] != null
              ? num.tryParse(d['totalCollected'].toString()) ?? 0
              : 0;
          _todayCollectedAmount = d['todayCollected'] != null
              ? num.tryParse(d['todayCollected'].toString()) ?? 0
              : 0;
          _thisMonthCollectedAmount = d['thisMonthCollected'] != null
              ? num.tryParse(d['thisMonthCollected'].toString()) ?? 0
              : 0;
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loadingCollections = false);
    }
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
          _renewalsDueCount = _members.where((m) => m.isDueSoon).length;
        });
        _loadCollectionsData();
      }
    } catch (_) {}

    try {
      final remRes = await ApiService.getRemovedMembers();
      if (remRes.success && remRes.data != null && mounted) {
        setState(() {
          _removedMembers = remRes.data!;
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

  Future<void> _loadRemovedMembers() async {
    if (!mounted) return;
    setState(() => _loadingRemovedMembers = true);
    try {
      final res = await ApiService.getRemovedMembers();
      if (res.success && res.data != null && mounted) {
        setState(() {
          _removedMembers = res.data!;
          _loadingRemovedMembers = false;
        });
      } else if (mounted) {
        setState(() => _loadingRemovedMembers = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRemovedMembers = false);
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

  Future<void> _loadProfileData() async {
    final stored = await AuthStorage.getStoredProfile();
    if (mounted) {
      setState(() {
        if (stored['ownerPhoto'] != null && stored['ownerPhoto'].toString().trim().isNotEmpty) {
          _ownerPhotoUrl = _resolvePhotoUrl(stored['ownerPhoto'].toString().trim());
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
            _ownerPhotoUrl = _resolvePhotoUrl(user['avatarUrl'].toString().trim());
          } else if (user?['photoUrl'] != null && user!['photoUrl'].toString().trim().isNotEmpty) {
            _ownerPhotoUrl = _resolvePhotoUrl(user['photoUrl'].toString().trim());
          } else if (user?['avatar'] != null && user!['avatar'].toString().trim().isNotEmpty) {
            _ownerPhotoUrl = _resolvePhotoUrl(user['avatar'].toString().trim());
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
      } else if (!res.success && mounted) {
        if (res.code == 'UNAUTHORIZED' || (res.message?.contains('Authentication required') ?? false)) {
          await AuthStorage.clearSession();
          widget.onLogout();
          return;
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

  MemberInfo? _getMemberForSeat(int seatNumber) {
    for (final m in _members) {
      final s = m.seat.toLowerCase();
      final digits = RegExp(r'\d+').allMatches(s).map((match) => match.group(0)).toList();
      if (digits.contains('$seatNumber')) {
        return m;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refreshAllData,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: SizedBox(
              width: double.infinity,
              child: _buildCurrentTab(),
            ),
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

  bool _isCollectionFromRemovedMember(FeeCollectionItem col) {
    // 1. Check if matches currently active member
    final matchingActive = _members.where((m) {
      if (m.studentId != null && m.studentId == col.studentId) return true;
      final cleanMemberPhone = m.phone.replaceAll(RegExp(r'\D'), '');
      final cleanColPhone = (col.studentPhone ?? '').replaceAll(RegExp(r'\D'), '');
      if (cleanMemberPhone.isNotEmpty && cleanColPhone.isNotEmpty && cleanMemberPhone == cleanColPhone) {
        return true;
      }
      return false;
    }).toList();

    // 2. Check if matches removed member record
    final matchingRemoved = _removedMembers.where((rm) {
      final sId = rm['studentId']?.toString();
      if (sId != null && sId == col.studentId) return true;
      final cleanRmPhone = (rm['phone']?.toString() ?? '').replaceAll(RegExp(r'\D'), '');
      final cleanColPhone = (col.studentPhone ?? '').replaceAll(RegExp(r'\D'), '');
      if (cleanRmPhone.isNotEmpty && cleanColPhone.isNotEmpty && cleanRmPhone == cleanColPhone) {
        return true;
      }
      return false;
    }).toList();

    if (matchingActive.isNotEmpty) {
      final activeMember = matchingActive.first;
      final colPlan = (col.planName ?? '').toLowerCase().trim();
      final actPlan = activeMember.plan.toLowerCase().trim();
      final colSeat = (col.seatLabel ?? '').toLowerCase().trim();
      final actSeat = activeMember.seat.toLowerCase().trim();

      // If matches active member's current seat and plan, it is definitively an Active Member collection
      if (colPlan == actPlan && (colSeat == actSeat || actSeat.contains(colSeat) || colSeat.contains(actSeat))) {
        return false;
      }

      // If student has previous removed records and this collection matches a removed plan/seat
      if (matchingRemoved.isNotEmpty) {
        final matchesRemoved = matchingRemoved.any((rm) {
          final rmPlan = (rm['planName']?.toString() ?? '').toLowerCase().trim();
          final rmSeat = (rm['seatLabel']?.toString() ?? '').toLowerCase().trim();
          if (rmPlan.isNotEmpty && colPlan.isNotEmpty && rmPlan == colPlan && colPlan != actPlan) {
            return true;
          }
          if (rmSeat.isNotEmpty && colSeat.isNotEmpty && rmSeat == colSeat && colSeat != actSeat) {
            return true;
          }
          if (colSeat.isNotEmpty && actSeat.isNotEmpty && colSeat != actSeat) {
            return true;
          }
          return false;
        });
        if (matchesRemoved) {
          return true; // Belongs to previous removed membership
        }
      }

      // Default for active student: Active
      return false;
    }

    // If not in active members, it is removed
    return true;
  }

  List<ActivityItem> _getRealActivities() {
    final List<ActivityItem> list = [];

    // 1. Real member attendance check-in / check-out
    for (final m in _members) {
      final st = m.status.toLowerCase();
      if (st.contains('present')) {
        list.add(ActivityItem(
          icon: 'check',
          title: '${m.name} checked in',
          detail: '${m.seat} · ${m.checkInTime != null && m.checkInTime!.isNotEmpty ? m.checkInTime : "Active Inside"}',
          isHighlight: true,
        ));
      } else if (st.contains('out') || st.contains('checked out')) {
        list.add(ActivityItem(
          icon: 'clock',
          title: '${m.name} checked out',
          detail: '${m.seat} · Session completed',
        ));
      } else if (m.startDate != null && m.startDate!.isNotEmpty) {
        list.add(ActivityItem(
          icon: 'users',
          title: 'Member enrolled: ${m.name}',
          detail: '${m.seat} · ${m.plan}',
        ));
      }
    }

    // 2. Real fee collections
    for (final col in _feeCollections.take(4)) {
      list.add(ActivityItem(
        icon: 'wallet',
        title: 'Fee collected: ₹${col.collectedAmount.toInt()}',
        detail: '${col.studentName} (${col.seatLabel ?? "Desk"}) · ${col.collectionDate}',
      ));
    }

    // 3. Real renewal due alerts
    for (final m in _members) {
      if (m.isDueSoon || m.daysRemaining <= 5) {
        list.add(ActivityItem(
          icon: 'clock',
          title: 'Plan renewal due',
          detail: '${m.name} · ${m.daysRemaining} days remaining',
        ));
      }
    }

    // Add any non-dummy dynamic activities passed in
    for (final act in widget.activities) {
      final t = act.title.toLowerCase();
      if (!t.contains('ananya') && !t.contains('rahul kumar') && !t.contains('priya singh') && !t.contains('vikram raj')) {
        list.add(act);
      }
    }

    return list;
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
                  Expanded(
                    child: Row(
                      children: [
                        AppAvatar(
                          size: 48,
                          isOwner: true,
                          photoUrl: _ownerPhotoUrl,
                          borderColor: AppColors.orange400,
                          borderWidth: 2.5,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                    Expanded(
                      child: Row(
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _libraryName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '$_address, $_city · $_totalSeats Desks',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppColors.indigo300, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.emerald500.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$_occupiedSeatsCount/$_totalSeats Occupied',
                            style: const TextStyle(
                              color: AppColors.emerald300,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOwnerAction(
                      icon: Icons.qr_code_2_rounded,
                      label: 'Attendance QR',
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
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _activeTab = PartnerTab.profile;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: _buildOwnerStatCard(
                                icon: Icons.account_balance_wallet,
                                tag: _todayCollectedAmount > 0
                                    ? '₹${_todayCollectedAmount.toInt()} today'
                                    : '₹${_thisMonthCollectedAmount.toInt()} this month',
                                tagColor: AppColors.emerald700,
                                tagBg: AppColors.emerald50,
                                label: 'TOTAL COLLECTION',
                                val: '₹${_totalCollectedAmount.toInt()}',
                                iconBg: AppColors.emerald50,
                                iconColor: AppColors.emerald600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _activeTab = PartnerTab.members;
                                  _membersSubTab = 'active';
                                  _memberValidityFilter = 'due_soon';
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: _buildOwnerStatCard(
                                icon: Icons.event,
                                tag: '5 Days window',
                                tagColor: _renewalsDueCount > 0 ? AppColors.rose600 : AppColors.emerald600,
                                tagBg: _renewalsDueCount > 0 ? AppColors.rose50 : AppColors.emerald50,
                                label: 'RENEWALS DUE',
                                val: '$_renewalsDueCount',
                                iconBg: _renewalsDueCount > 0 ? AppColors.rose50 : AppColors.slate100,
                                iconColor: _renewalsDueCount > 0 ? AppColors.rose600 : AppColors.slate600,
                              ),
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

                    Builder(
                      builder: (context) {
                        final realActivities = _getRealActivities();
                        if (realActivities.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.slate50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.slate100),
                            ),
                            child: Column(
                              children: const [
                                Icon(Icons.history_rounded, size: 30, color: AppColors.slate400),
                                SizedBox(height: 8),
                                Text(
                                  'No recent activity yet',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slate700),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Student check-ins, check-outs, and fee collections will appear here in real-time.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, color: AppColors.slate400),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: realActivities.take(5).map((act) {
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
                          }).toList(),
                        );
                      },
                    ),
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
      padding: const EdgeInsets.all(12),
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
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: tagBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tag,
                      maxLines: 1,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: tagColor),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppColors.slate400,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              val,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: AppColors.slate900,
              ),
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

    // Compute list of seats to display
    final List<int> seatNumbers = List.generate(totalSeats, (i) => i + 1);
    final filteredSeats = seatNumbers.where((seatNo) {
      final seat = _getSeatInfo(seatNo);
      final stLower = seat.status.toLowerCase();
      final isOccupied = stLower.contains('occupied');
      final isReserved = stLower.contains('reserved');
      final isAvailable = !isOccupied && !isReserved;

      if (_seatFilter == 'occupied' && !isOccupied) return false;
      if (_seatFilter == 'reserved' && !isReserved) return false;
      if (_seatFilter == 'available' && !isAvailable) return false;

      if (_seatSearch.trim().isNotEmpty) {
        final q = _seatSearch.trim().toLowerCase();
        final member = _getMemberForSeat(seatNo);
        final name = (member?.name ?? seat.student).toLowerCase();
        final numStr = '$seatNo';
        if (!numStr.contains(q) && !name.contains(q)) return false;
      }

      return true;
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
                    'Floor Map & Seats',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  // View mode toggle: List (default) vs Grid
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _seatsListView = true),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _seatsListView ? AppColors.orange500 : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.view_agenda_rounded, size: 13, color: Colors.white),
                                SizedBox(width: 4),
                                Text('List', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _seatsListView = false),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: !_seatsListView ? AppColors.orange500 : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.grid_view_rounded, size: 13, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Grid', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                      ],
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

              const SizedBox(height: 12),

              // Search bar
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  onChanged: (v) => setState(() => _seatSearch = v),
                  decoration: InputDecoration(
                    hintText: 'Search seat number or student name...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.6), size: 18),
                    suffixIcon: _seatSearch.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70, size: 16),
                            onPressed: () => setState(() => _seatSearch = ''),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: _loadingFloorMap
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppColors.orange500),
                  ),
                )
              : _seatsListView
                  // ==========================================
                  // REQUESTED LIST LAYOUT:
                  // Left side Seat No & Right side Allotted To
                  // (e.g. "1 vishal kr", "2 is not alloted 2 -")
                  // ==========================================
                  ? Column(
                      children: [
                        if (filteredSeats.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.slate200),
                            ),
                            alignment: Alignment.center,
                            child: const Column(
                              children: [
                                Icon(Icons.search_off_rounded, size: 40, color: AppColors.slate400),
                                SizedBox(height: 10),
                                Text(
                                  'No seats found',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.slate800),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Try selecting a different filter or clearing search.',
                                  style: TextStyle(fontSize: 12, color: AppColors.slate500),
                                ),
                              ],
                            ),
                          )
                        else
                          ...filteredSeats.map((seatNum) {
                            final seat = _getSeatInfo(seatNum);
                            final stLower = seat.status.toLowerCase();
                            final isOccupied = stLower.contains('occupied');
                            final isReserved = stLower.contains('reserved');

                            final member = _getMemberForSeat(seatNum);

                            String studentName = '—';
                            if (isOccupied) {
                              if (member != null && member.name.isNotEmpty) {
                                studentName = member.name;
                              } else if (seat.student.isNotEmpty &&
                                  seat.student != 'Available Desk' &&
                                  !seat.student.startsWith('Desk #')) {
                                studentName = seat.student;
                              } else {
                                studentName = 'Occupied Desk';
                              }
                            } else if (isReserved) {
                              studentName = 'Reserved';
                            } else {
                              studentName = '—'; // User requested: "2 is not alloted 2 - , like this"
                            }

                            final planName = member?.plan ?? (seat.plan != 'Open for Admission' ? seat.plan : '');
                            final shiftTiming = member?.shiftTiming ??
                                (seat.shiftTiming != null && seat.shiftTiming != 'Available all shifts' ? seat.shiftTiming! : '');

                            return InkWell(
                              onTap: () {
                                _openSeatDetailModal(seatNum, seat, isOccupied, isReserved, studentName, member);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isOccupied
                                        ? AppColors.indigo200
                                        : isReserved
                                            ? AppColors.orange200
                                            : AppColors.slate200,
                                    width: isOccupied ? 1.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.slate900.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Left Side: Seat Number
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: isOccupied
                                            ? AppColors.indigo950
                                            : isReserved
                                                ? AppColors.orange100
                                                : AppColors.slate100,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isOccupied
                                              ? AppColors.indigo900
                                              : isReserved
                                                  ? AppColors.orange300
                                                  : AppColors.slate200,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.chair_rounded,
                                            size: 14,
                                            color: isOccupied
                                                ? Colors.white70
                                                : isReserved
                                                    ? AppColors.orange600
                                                    : AppColors.slate400,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$seatNum',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w900,
                                              color: isOccupied
                                                  ? Colors.white
                                                  : isReserved
                                                      ? AppColors.orange700
                                                      : AppColors.slate700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 14),

                                    // Right Side: Allotted To & Status
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  isOccupied ? studentName : '—',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w900,
                                                    color: isOccupied ? AppColors.slate900 : AppColors.slate400,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Status Pill
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isOccupied
                                                      ? AppColors.indigo50
                                                      : isReserved
                                                          ? AppColors.orange50
                                                          : AppColors.emerald50,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isOccupied
                                                        ? AppColors.indigo200
                                                        : isReserved
                                                            ? AppColors.orange200
                                                            : AppColors.emerald200,
                                                  ),
                                                ),
                                                child: Text(
                                                  isOccupied
                                                      ? 'Occupied'
                                                      : isReserved
                                                          ? 'Reserved'
                                                          : 'Available',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    color: isOccupied
                                                        ? AppColors.indigo950
                                                        : isReserved
                                                            ? AppColors.orange700
                                                            : AppColors.emerald700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          if (isOccupied) ...[
                                            Row(
                                              children: [
                                                if (shiftTiming.isNotEmpty) ...[
                                                  const Icon(Icons.access_time_rounded, size: 11, color: AppColors.orange500),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    shiftTiming,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.orange600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                ],
                                                if (planName.isNotEmpty) ...[
                                                  Flexible(
                                                    child: Text(
                                                      planName,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w500,
                                                        color: AppColors.slate500,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ] else ...[
                                            Text(
                                              isReserved
                                                  ? 'Admission pending'
                                                  : 'Not allotted · Ready to assign',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.slate400,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 18,
                                      color: isOccupied ? AppColors.indigo950 : AppColors.slate300,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    )
                  // Grid View fallback
                  : Column(
                      children: [
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
                                    border: isSelected ? Border.all(color: AppColors.orange500, width: 2.5) : null,
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
                            color: AppColors.indigo50.withValues(alpha: 0.6),
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

  void _openSeatDetailModal(
    int seatNum,
    SeatInfo seatData,
    bool isOccupied,
    bool isReserved,
    String studentName,
    MemberInfo? member,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isOccupied ? AppColors.indigo950 : AppColors.slate100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Seat #$seatNum',
                        style: TextStyle(
                          color: isOccupied ? Colors.white : AppColors.slate800,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOccupied
                            ? AppColors.indigo50
                            : (isReserved ? AppColors.orange50 : AppColors.emerald50),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isOccupied
                              ? AppColors.indigo200
                              : (isReserved ? AppColors.orange200 : AppColors.emerald200),
                        ),
                      ),
                      child: Text(
                        isOccupied ? 'Occupied' : (isReserved ? 'Reserved' : 'Available'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isOccupied
                              ? AppColors.indigo950
                              : (isReserved ? AppColors.orange700 : AppColors.emerald700),
                        ),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (isOccupied) ...[
              _buildSeatRow('Allotted Student', studentName),
              if (member != null && member.phone.isNotEmpty)
                _buildSeatRow('Mobile Number', member.phone),
              _buildSeatRow('Membership Plan', member?.plan ?? seatData.plan),
              if ((seatData.shiftTiming != null && seatData.shiftTiming!.isNotEmpty) ||
                  (member?.shiftTiming != null && member!.shiftTiming!.isNotEmpty))
                _buildSeatRow('Shift Timing', member?.shiftTiming ?? seatData.shiftTiming ?? 'N/A'),
              _buildSeatRow('Validity', seatData.validTill, isGreen: true),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (member != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openReallotSeatModal(member);
                        },
                        icon: const Icon(Icons.chair_alt_rounded, size: 14),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Re-allot Seat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.orange600,
                          side: const BorderSide(color: AppColors.orange300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openMemberProfileModal(member);
                        },
                        icon: const Icon(Icons.person_outline_rounded, size: 14),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.indigo950,
                          side: const BorderSide(color: AppColors.indigo200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: AppColors.emerald600, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Seat #$seatNum is Vacant',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.slate900)),
                          const SizedBox(height: 2),
                          const Text('This desk is open and ready to be allotted to a student.',
                              style: TextStyle(fontSize: 11, color: AppColors.slate600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openAddMemberModal();
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
                  label: const Text('Allot this Seat to a Student',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange500,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
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
    final dueCount = _members.where((m) => m.isDueSoon).length;
    final paidCount = _members.where((m) => !m.isDueSoon).length;
    final filtered = _members.where((m) {
      final matchesSearch = '${m.name} ${m.seat} ${m.plan} ${m.phone}'.toLowerCase().contains(_memberSearch.toLowerCase());
      if (!matchesSearch) return false;
      if (_memberValidityFilter == 'due_soon') return m.isDueSoon;
      if (_memberValidityFilter == 'paid') return !m.isDueSoon;
      return true;
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              const SizedBox(height: 14),

              // Sub-tab switcher: Active Members vs Removed / Ex-Members
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _membersSubTab = 'active'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: _membersSubTab == 'active' ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _membersSubTab == 'active'
                                ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Active Members (${_members.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _membersSubTab == 'active' ? AppColors.indigo950 : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() => _membersSubTab = 'removed');
                          _loadRemovedMembers();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: _membersSubTab == 'removed' ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _membersSubTab == 'removed'
                                ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4, offset: const Offset(0, 2))]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Removed Members (${_removedMembers.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _membersSubTab == 'removed' ? AppColors.indigo950 : Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter pills for Active tab: All, Due Soon, Paid
              if (_membersSubTab == 'active') ...[
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMemberFilterPill('all', 'All (${_members.length})', null),
                      const SizedBox(width: 8),
                      _buildMemberFilterPill('due_soon', '⚠️ Renewal Due ($dueCount)', Colors.red.shade400),
                      const SizedBox(width: 8),
                      _buildMemberFilterPill('paid', '✅ Paid & Valid ($paidCount)', AppColors.emerald500),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (_membersSubTab == 'removed')
                _buildRemovedMembersList()
              else ...[
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
                  final isDue = m.isDueSoon;
                  final isActive = m.membershipStatus.toUpperCase() == 'ACTIVE';
                  final isPresent = m.status.toLowerCase().contains('present');

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDue ? Colors.red.shade400 : AppColors.slate200,
                        width: isDue ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDue
                              ? Colors.red.withOpacity(0.06)
                              : AppColors.slate900.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Red Top Banner if Expiring in <= 5 Days
                        if (isDue)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            color: const Color(0xFFFEF2F2),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '⚠️ Renewal Due in ${m.daysRemaining} days (Valid till: ${m.validTill ?? "Soon"}) · Fee: ₹${m.monthlyFee?.toInt() ?? 499}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Row 1: Avatar + Name & Phone + Status Badge & Punch Indicator
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isDue ? const Color(0xFFFEF2F2) : AppColors.indigo50,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: isDue ? const Color(0xFFFECACA) : AppColors.indigo100),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      m.name.isNotEmpty
                                          ? m.name.substring(0, m.name.length >= 2 ? 2 : 1).toUpperCase()
                                          : 'M',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: isDue ? Colors.red.shade900 : AppColors.indigo950,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.slate900,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.phone_rounded, size: 11, color: AppColors.slate400),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                m.phone,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.slate500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDue
                                              ? const Color(0xFFFEF2F2)
                                              : (isActive ? AppColors.emerald50 : AppColors.slate100),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isDue
                                                ? Colors.red.shade300
                                                : (isActive ? AppColors.emerald200 : AppColors.slate200),
                                          ),
                                        ),
                                        child: Text(
                                          isDue
                                              ? 'Due in ${m.daysRemaining}d'
                                              : (isActive ? 'Paid · Active' : 'Inactive'),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: isDue
                                                ? Colors.red
                                                : (isActive ? AppColors.emerald700 : AppColors.slate600),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isPresent ? Icons.circle : Icons.circle_outlined,
                                            size: 7,
                                            color: isPresent ? AppColors.emerald600 : AppColors.slate400,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isPresent
                                                ? (m.checkInTime != null ? 'In: ${m.checkInTime}' : 'Present')
                                                : m.status,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: isPresent ? AppColors.emerald700 : AppColors.slate500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Row 2: Informational Chips (Seat, Plan, Shift, Validity)
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.indigo50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.indigo200.withValues(alpha: 0.5)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.chair_rounded, size: 12, color: AppColors.indigo950),
                                        const SizedBox(width: 4),
                                        Text(
                                          m.seat,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.indigo950,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.slate100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.slate200),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.card_membership_rounded, size: 12, color: AppColors.slate700),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${m.plan} · ₹${m.monthlyFee?.toInt() ?? 499}/mo',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.slate700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (m.shiftTiming != null && m.shiftTiming!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.orange50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.orange200),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.access_time_rounded, size: 12, color: AppColors.orange600),
                                          const SizedBox(width: 4),
                                          Text(
                                            m.shiftTiming!,
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.orange700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (m.validTill != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDue ? const Color(0xFFFEF2F2) : AppColors.emerald50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: isDue ? const Color(0xFFFECACA) : AppColors.emerald200),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.calendar_today_rounded,
                                            size: 11,
                                            color: isDue ? Colors.red : AppColors.emerald700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Valid till ${m.validTill}',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              color: isDue ? Colors.red : AppColors.emerald700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),

                              // Dedicated Action Bar when Renewal is Due
                              if (isDue) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _sendWhatsAppReminder(m),
                                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.white),
                                        label: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'WhatsApp Reminder',
                                            maxLines: 1,
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF16A34A),
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _openCollectDueModal(m),
                                        icon: const Icon(Icons.payments_rounded, size: 14, color: Colors.white),
                                        label: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'Collect ₹${m.monthlyFee?.toInt() ?? 499}',
                                            maxLines: 1,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.orange500,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 12),
                              const Divider(height: 1, color: AppColors.slate100),
                              const SizedBox(height: 10),

                              // Row 3: Standard Action Buttons (Profile, Seat, Remove, Menu)
                              Row(
                                children: [
                                  // View Profile Button
                                  Expanded(
                                    child: InkWell(
                                      onTap: m.studentId != null ? () => _openMemberProfileModal(m) : null,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.indigo50,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.indigo100),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.visibility_outlined, size: 13, color: AppColors.indigo950),
                                            SizedBox(width: 4),
                                            Text(
                                              'Profile',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.indigo950,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Re-allot Seat Button
                                  Expanded(
                                    child: InkWell(
                                      onTap: m.studentId != null ? () => _openReallotSeatModal(m) : null,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: AppColors.orange50,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.orange200),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.chair_alt_rounded, size: 13, color: AppColors.orange600),
                                            SizedBox(width: 4),
                                            Text(
                                              'Seat',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.orange700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Direct Remove Button
                                  Expanded(
                                    child: InkWell(
                                      onTap: m.studentId != null ? () => _confirmRemoveMember(m) : null,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFFECACA)),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.delete_outline_rounded, size: 13, color: Colors.red),
                                            SizedBox(width: 4),
                                            Text(
                                              'Remove',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 3-dots Menu for secondary actions
                                  if (m.studentId != null) ...[
                                    const SizedBox(width: 4),
                                    PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.slate600),
                                      onSelected: (action) async {
                                        if (action == 'COLLECT_DUE') {
                                          _openCollectDueModal(m);
                                        } else if (action == 'WHATSAPP_REMINDER') {
                                          _sendWhatsAppReminder(m);
                                        } else if (action == 'VIEW_PROFILE') {
                                          _openMemberProfileModal(m);
                                        } else if (action == 'REALLOT_SEAT') {
                                          _openReallotSeatModal(m);
                                        } else if (action == 'TOGGLE_STATUS') {
                                          _toggleMemberStatus(m);
                                        } else if (action == 'RELEASE_SEAT') {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (c) => AlertDialog(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                              title: const Text('Release Seat?'),
                                              content: Text(
                                                'Are you sure you want to release ${m.name}\'s seat? The student remains registered.',
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(c, true),
                                                  child: const Text('Release', style: TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            final res = await ApiService.removeMember(m.studentId!, action: 'RELEASE_SEAT');
                                            if (res.success) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(res.message ?? 'Seat released successfully'),
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
                                        } else if (action == 'REMOVE') {
                                          _confirmRemoveMember(m);
                                        }
                                      },
                                      itemBuilder: (c) => [
                                        PopupMenuItem(
                                          value: 'COLLECT_DUE',
                                          child: Row(
                                            children: const [
                                              Icon(Icons.payments_outlined, size: 16, color: AppColors.emerald600),
                                              SizedBox(width: 8),
                                              Text('Collect Fee / Due', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'WHATSAPP_REMINDER',
                                          child: Row(
                                            children: const [
                                              Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF16A34A)),
                                              SizedBox(width: 8),
                                              Text('WhatsApp Reminder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuDivider(),
                                        PopupMenuItem(
                                          value: 'VIEW_PROFILE',
                                          child: Row(
                                            children: const [
                                              Icon(Icons.person_outline_rounded, size: 16, color: AppColors.primary),
                                              SizedBox(width: 8),
                                              Text('View Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'REALLOT_SEAT',
                                          child: Row(
                                            children: const [
                                              Icon(Icons.chair_alt_rounded, size: 16, color: AppColors.orange600),
                                              SizedBox(width: 8),
                                              Text('Re-allot Seat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'TOGGLE_STATUS',
                                          child: Row(
                                            children: [
                                              Icon(isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                                                  size: 16, color: isActive ? AppColors.slate600 : AppColors.emerald600),
                                              const SizedBox(width: 8),
                                              Text(isActive ? 'Mark Inactive' : 'Mark Active',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'RELEASE_SEAT',
                                          child: Row(
                                            children: [
                                              Icon(Icons.event_seat_outlined, size: 16, color: Colors.orange),
                                              SizedBox(width: 8),
                                              Text('Release Seat Only', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.orange)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuDivider(),
                                        const PopupMenuItem(
                                          value: 'REMOVE',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_forever_rounded, size: 16, color: Colors.red),
                                              SizedBox(width: 8),
                                              Text('Remove Member', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRemovedMembersList() {
    if (_loadingRemovedMembers) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.orange500),
        ),
      );
    }

    final query = _memberSearch.trim().toLowerCase();
    final list = _removedMembers.where((m) {
      if (query.isEmpty) return true;
      final name = m['studentName']?.toString().toLowerCase() ?? '';
      final phone = m['phone']?.toString().toLowerCase() ?? '';
      final code = m['studentCode']?.toString().toLowerCase() ?? '';
      final seat = m['seatLabel']?.toString().toLowerCase() ?? '';
      return name.contains(query) || phone.contains(query) || code.contains(query) || seat.contains(query);
    }).toList();

    if (list.isEmpty) {
      return Container(
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
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.slate100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_off_rounded, size: 30, color: AppColors.slate500),
            ),
            const SizedBox(height: 14),
            const Text(
              'No Removed Members',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Students who leave or are removed from your library will appear here with enrollment join & left history.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.4),
            ),
          ],
        ),
      );
    }

    return Column(
      children: list.map((m) {
        final name = m['studentName']?.toString() ?? 'Ex-Member';
        final phone = m['phone']?.toString() ?? '';
        final code = m['studentCode']?.toString() ?? '';
        final seat = m['seatLabel']?.toString() ?? 'Seat Released';
        final plan = m['planName']?.toString() ?? 'Monthly Plan';
        final enrolled = m['enrolledDate']?.toString() ?? '-';
        final left = m['leftDate']?.toString() ?? '-';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.slate200),
            boxShadow: [
              BoxShadow(
                color: AppColors.slate900.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: Initials avatar + Name & Student Code + Removed Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.slate300),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.isNotEmpty ? name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase() : 'EX',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (code.isNotEmpty) ...[
                              Text(
                                code,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slate600),
                              ),
                              const Text(' · ', style: TextStyle(color: AppColors.slate400)),
                            ],
                            Text(
                              phone,
                              style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2), // Rose 50
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECDD3)), // Rose 200
                    ),
                    child: const Text(
                      'Ex-Member',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE11D48), // Rose 600
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Past Plan & Seat info chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chair_outlined, size: 12, color: AppColors.slate600),
                        const SizedBox(width: 4),
                        Text(
                          seat,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.slate700),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.workspace_premium_outlined, size: 12, color: AppColors.slate600),
                        const SizedBox(width: 4),
                        Text(
                          plan,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.slate700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 3: Enroll In & Enroll Out Dates (Join & Left history)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.slate200.withOpacity(0.6)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.login_rounded, size: 12, color: AppColors.emerald600),
                              SizedBox(width: 4),
                              Text(
                                'ENROLLED IN',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.emerald700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            enrolled,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.slate900),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 28, width: 1, color: AppColors.slate200),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.logout_rounded, size: 12, color: Color(0xFFE11D48)),
                              SizedBox(width: 4),
                              Text(
                                'LEFT LIBRARY',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFE11D48),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            left,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.slate900),
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
      }).toList(),
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
          child: Stack(
            children: [
              // Subtle Partner Badge on Top Right
              Positioned(
                top: 14,
                right: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
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
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Main Owner Profile Row Content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppAvatar(
                      size: 64,
                      isOwner: true,
                      photoUrl: _ownerPhotoUrl,
                      borderColor: AppColors.orange400,
                      borderWidth: 2.5,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _ownerName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Library Owner',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.indigo200,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _showEditOwnerProfileDialog,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 19,
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

              _buildFeeCollectionsSection(),
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

                    // 1. Owner Default Avatar
                    const Center(
                      child: AppAvatar(
                        size: 80,
                        isOwner: true,
                        borderColor: AppColors.orange400,
                        borderWidth: 3.0,
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
                                            _ownerPhotoUrl = _resolvePhotoUrl(tempPhotoUrl);
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
    final String libId = (_businessProfile?.id != null &&
            _businessProfile!.id.isNotEmpty &&
            _businessProfile!.id != 'owner-lib')
        ? _businessProfile!.id
        : '39051c53-663d-40e0-85b5-8894539d3328';

    final profile = (_businessProfile != null)
        ? _businessProfile!.copyWith(
            id: libId,
            totalSeats: _totalSeats,
            name: _libraryName,
            address: _address,
            city: _city,
            contactPhone: _ownerPhone,
          )
        : LibraryBusinessModel(
            id: libId,
            name: _libraryName,
            address: _address,
            city: _city,
            totalSeats: _totalSeats,
            contactPhone: _ownerPhone,
          );

    final initialSeatsList = _floorMapSeats.map((s) => {
      'seatNumber': s.number,
      'label': 'Seat #${s.number}',
      'status': s.status.toLowerCase().contains('occupied')
          ? 'occupied'
          : (s.status.toLowerCase().contains('reserved') ? 'reserved' : 'available'),
      'studentName': s.student.isNotEmpty && s.student != 'Available' && s.student != '-' ? s.student : null,
      'plan': s.plan.isNotEmpty && s.plan != '-' ? s.plan : null,
      'validTill': s.validTill.isNotEmpty && s.validTill != '-' ? s.validTill : null,
      'shiftTiming': s.shiftTiming ?? 'Full Day (08:00 AM - 08:00 PM)',
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryDetailsScreen(
          libraryId: libId,
          initialData: profile,
          initialSeats: initialSeatsList.isNotEmpty ? initialSeatsList : null,
          isOwnerPreview: true,
        ),
      ),
    ).then((_) {
      _loadFloorMapData();
      _loadMembersData();
    });
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
                                _resolvePhotoUrl(photos[i]) ?? photos[i],
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: _buildNavTab(PartnerTab.overview, Icons.grid_view_rounded, 'Overview')),
          Expanded(child: _buildNavTab(PartnerTab.seats, Icons.apartment, 'Seats')),
          Expanded(child: _buildNavTab(PartnerTab.members, Icons.people_alt_rounded, 'Members')),
          Expanded(child: _buildNavTab(PartnerTab.profile, Icons.person_rounded, 'Profile')),
        ],
      ),
    );
  }

  Widget _buildNavTab(PartnerTab tab, IconData icon, String label) {
    final isActive = _activeTab == tab;
    return InkWell(
      onTap: () {
        setState(() => _activeTab = tab);
        if (tab == PartnerTab.overview) {
          _loadCollectionsData();
          _loadMembersData();
          _loadFloorMapData();
        } else if (tab == PartnerTab.seats) {
          _loadFloorMapData();
        } else if (tab == PartnerTab.members) {
          _loadMembersData();
        } else if (tab == PartnerTab.profile) {
          _loadCollectionsData();
          _loadProfileData();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? AppColors.orange500 : AppColors.slate400,
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                  color: isActive ? AppColors.orange500 : AppColors.slate400,
                ),
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
  Future<void> _openStandeeQRModal() async {
    Timer? countdownTimer;
    int remainingSeconds = 120;
    bool isLoading = true;
    String? qrPayload;
    String? randomCode;
    String? errorMessage;

    void startTimer(void Function(void Function()) setModalState) {
      countdownTimer?.cancel();
      countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (remainingSeconds > 1) {
          setModalState(() {
            remainingSeconds--;
          });
        } else {
          timer.cancel();
          setModalState(() {
            remainingSeconds = 0;
          });
        }
      });
    }

    Future<void> generateQr(void Function(void Function()) setModalState) async {
      countdownTimer?.cancel();
      setModalState(() {
        isLoading = true;
        errorMessage = null;
      });

      final res = await ApiService.generateDynamicAttendanceQr();
      if (!mounted) return;

      if (res.success && res.data != null) {
        final data = res.data!;
        setModalState(() {
          isLoading = false;
          qrPayload = data['qrCodePayload']?.toString() ?? data['qrPayload']?.toString() ?? '';
          randomCode = data['randomCode']?.toString() ?? '';
          final inSec = (data['expiresInSeconds'] as num?)?.toInt() ?? 120;
          remainingSeconds = inSec > 0 ? inSec : 120;
        });
        startTimer(setModalState);
      } else {
        setModalState(() {
          isLoading = false;
          errorMessage = res.message ?? 'Failed to generate dynamic attendance QR';
        });
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          if (isLoading && qrPayload == null && errorMessage == null) {
            generateQr(setModalState);
          }

          final isExpired = remainingSeconds <= 0 && !isLoading && qrPayload != null;
          final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
          final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
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
                            'LIVE ATTENDANCE QR',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.orange500,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            'Dynamic Attendance',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.slate900,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () {
                          countdownTimer?.cancel();
                          Navigator.of(ctx).pop();
                        },
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (isLoading) ...[
                    Container(
                      height: 220,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          CircularProgressIndicator(color: AppColors.orange500),
                          SizedBox(height: 16),
                          Text(
                            'Generating Secure Dynamic QR...',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Valid for 2 minutes on student scan',
                            style: TextStyle(fontSize: 11, color: AppColors.slate400),
                          ),
                        ],
                      ),
                    ),
                  ] else if (errorMessage != null) ...[
                    Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 42),
                          const SizedBox(height: 12),
                          Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.orange500,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => generateQr(setModalState),
                            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                            label: const Text('Retry Generation', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ] else if (isExpired) ...[
                    // Expired State
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.withOpacity(0.2)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.timer_off_outlined, color: Colors.red, size: 40),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'QR Code Expired',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'The 2-minute dynamic attendance window has expired. Press the button below to generate a new QR code.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11.5, color: AppColors.slate500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      label: 'Regenerate Attendance QR',
                      onPressed: () => generateQr(setModalState),
                    ),
                  ] else ...[
                    // Active Dynamic QR
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QRCodeGraphic(
                        size: 190,
                        data: qrPayload,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Countdown timer & Passcode
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: remainingSeconds < 30 ? Colors.red.withOpacity(0.1) : AppColors.orange50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: remainingSeconds < 30 ? Colors.red.withOpacity(0.3) : AppColors.orange200,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: remainingSeconds < 30 ? Colors.red : AppColors.orange600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Expires in: $minutes:$seconds',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: remainingSeconds < 30 ? Colors.red : AppColors.orange700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (randomCode != null && randomCode!.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Passcode: ',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500),
                          ),
                          Text(
                            '${randomCode!.substring(0, 3)} ${randomCode!.substring(3)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.slate900,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],

                    Text(
                      _businessProfile?.displayName ?? 'Study Hub Library',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Students must scan within 2 minutes to verify attendance.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5, color: AppColors.slate500),
                    ),
                    const SizedBox(height: 14),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.orange600,
                              side: const BorderSide(color: AppColors.orange300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => generateQr(setModalState),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Regenerate QR',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.slate800,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              countdownTimer?.cancel();
                              Navigator.of(ctx).pop();
                            },
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Close',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      countdownTimer?.cancel();
    });
  }

  Future<void> _confirmRemoveMember(MemberInfo m) async {
    if (m.studentId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Remove Member?'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove ${m.name} from the library?\n\nThis will vacate their allotted seat (${m.seat}) and cancel their active membership and booking.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove Member', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await ApiService.removeMember(m.studentId!, action: 'REMOVE');
      if (res.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message ?? 'Member removed and seat vacated successfully'),
              backgroundColor: AppColors.emerald500,
            ),
          );
        }
        _loadMembersData();
        _loadFloorMapData();
        _loadProfileData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message ?? 'Failed to remove member'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
          final monthlyFee = data?['monthlyFee'];
          String planDisplay = plan;
          if (monthlyFee != null) {
            final feeNum = num.tryParse(monthlyFee.toString());
            if (feeNum != null) {
              planDisplay = '$plan · ₹${feeNum.toInt()}/mo';
            }
          }
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
                      Expanded(
                        child: Row(
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    studentName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    'ID: $code · $phone',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                  _buildProfileField('Subscription Plan', planDisplay),
                  if (monthlyFee != null)
                    _buildProfileField('Monthly Fee', '₹${num.tryParse(monthlyFee.toString())?.toInt() ?? monthlyFee} / month'),
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
                          label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Re-allot Seat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.orange600,
                            side: const BorderSide(color: AppColors.orange300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmRemoveMember(m);
                          },
                          icon: const Icon(Icons.delete_outline_rounded, size: 14),
                          label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Remove', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Color(0xFFFECACA)),
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
    String selectedShift = m.shiftTiming ?? LibraryRateCard.defaultSlot.timing;
    bool isSaving = false;
    String? modalError;

    final timingOptions = LibraryRateCard.allSlots.map((s) => s.timing).toSet().toList();
    if (!timingOptions.contains(selectedShift)) {
      timingOptions.insert(0, selectedShift);
    }

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

    // Rate card & shift state as per PDF
    String selectedCategory = '6 Hours';
    LibraryShiftSlot selectedSlot = LibraryRateCard.defaultSlot;
    String selectedDuration = '1m'; // '1m', '3m', '6m', '1y'
    bool assignDedicatedSeat = false; // Floating seat for 1m, dedicated seat for 3m/6m/1y/24h

    final feeCtrl = TextEditingController(
      text: '${selectedSlot.fee1m.toInt()}',
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
                  // STEP 2: Allot Seat, Shift Timing & Duration Plan
                  // ----------------------------------------------------
                  if (step == 2) ...[
                    // Student Header Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.slate50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: Row(
                        children: [
                          AppAvatar(
                            isOwner: false,
                            gender: studentData?['gender']?.toString() ?? selectedGender,
                            name: studentData?['fullName']?.toString() ?? 'Student',
                            size: 38,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  studentData?['fullName']?.toString() ?? "Student",
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.slate900),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '+91 ${phoneCtrl.text.trim()} · ${studentData?['examCategory'] ?? selectedExamCategory}',
                                  style: const TextStyle(fontSize: 10.5, color: AppColors.slate500, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => setModalState(() => step = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Change',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 1. Shift Duration Category Chips
                    const Text(
                      '1. SELECT SHIFT DURATION',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: LibraryRateCard.categories.map((cat) {
                          final isSel = selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
                                  color: isSel ? Colors.white : AppColors.slate700,
                                ),
                              ),
                              selected: isSel,
                              selectedColor: AppColors.primary,
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: isSel ? AppColors.primary : AppColors.slate200),
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setModalState(() {
                                    selectedCategory = cat;
                                    final slots = LibraryRateCard.getSlotsForCategory(cat);
                                    if (slots.isNotEmpty) {
                                      selectedSlot = slots.first;
                                    }
                                    if (selectedSlot.isDedicatedSeat || selectedDuration != '1m') {
                                      assignDedicatedSeat = true;
                                    }
                                    feeCtrl.text = selectedSlot.getFeeForDuration(selectedDuration).toInt().toString();
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Choose Shift Timing & Slot Choices
                    const Text(
                      '2. CHOOSE SHIFT TIMING & SLOT',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 6),
                    Column(
                      children: LibraryRateCard.getSlotsForCategory(selectedCategory).map((slot) {
                        final isSel = selectedSlot.timing == slot.timing && selectedSlot.planName == slot.planName;
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              selectedSlot = slot;
                              if (slot.isDedicatedSeat || selectedDuration != '1m') {
                                assignDedicatedSeat = true;
                              }
                              feeCtrl.text = slot.getFeeForDuration(selectedDuration).toInt().toString();
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? AppColors.orange50.withOpacity(0.5) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel ? AppColors.orange500 : AppColors.slate200,
                                width: isSel ? 1.6 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSel ? Icons.radio_button_checked : Icons.radio_button_off,
                                  size: 16,
                                  color: isSel ? AppColors.orange500 : AppColors.slate400,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              slot.displayTiming,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                                color: isSel ? AppColors.slate900 : AppColors.slate800,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: slot.tag.contains('Rush')
                                                  ? AppColors.rose50
                                                  : (slot.tag.contains('VIP') ? AppColors.amber50 : AppColors.slate100),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              slot.tag,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: slot.tag.contains('Rush')
                                                    ? AppColors.rose600
                                                    : (slot.tag.contains('VIP') ? AppColors.amber800 : AppColors.slate700),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${slot.planName} · Base ₹${slot.fee1m.toInt()}/mo (${slot.effectiveHourly})',
                                        style: const TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // 3. Plan Tenure & Long-Term Offers (PDF Section 2)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          '3. PLAN TENURE & OFFERS',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 0.8),
                        ),
                        Text(
                          'Long-Term Discount Offers',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.emerald600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: LibraryRateCard.durationOptions.map((dur) {
                        final code = dur['code']!;
                        final isSel = selectedDuration == code;
                        final feeForDur = selectedSlot.getFeeForDuration(code).toInt();
                        return Expanded(
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedDuration = code;
                                if (code != '1m' || selectedSlot.isDedicatedSeat) {
                                  assignDedicatedSeat = true;
                                } else {
                                  assignDedicatedSeat = false;
                                }
                                feeCtrl.text = selectedSlot.getFeeForDuration(code).toInt().toString();
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
                              decoration: BoxDecoration(
                                color: isSel ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? AppColors.primary : AppColors.slate200,
                                  width: isSel ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    dur['label']!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: isSel ? Colors.white : AppColors.slate800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isSel ? Colors.white.withOpacity(0.2) : AppColors.emerald50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      dur['sub']!,
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        color: isSel ? Colors.white : AppColors.emerald700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '₹$feeForDur',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      color: isSel ? Colors.white : AppColors.slate900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // 4. Seat Allocation Rule (PDF Section 3 Rule 3)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (selectedDuration != '1m' || selectedSlot.isDedicatedSeat)
                            ? AppColors.emerald50.withOpacity(0.6)
                            : AppColors.slate50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: (selectedDuration != '1m' || selectedSlot.isDedicatedSeat)
                              ? AppColors.emerald200
                              : AppColors.slate200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                (selectedDuration != '1m' || selectedSlot.isDedicatedSeat)
                                    ? Icons.workspace_premium_rounded
                                    : Icons.airline_seat_recline_normal_rounded,
                                size: 15,
                                color: (selectedDuration != '1m' || selectedSlot.isDedicatedSeat)
                                    ? AppColors.emerald700
                                    : AppColors.slate600,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  (selectedDuration != '1m' || selectedSlot.isDedicatedSeat)
                                      ? 'FIXED SEAT + PERSONAL LOCKER FREE 🔐'
                                      : '1-MONTH FLOATING / UNRESERVED SEAT',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: (selectedDuration != '1m' || selectedSlot.isDedicatedSeat)
                                        ? AppColors.emerald800
                                        : AppColors.slate700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (selectedDuration != '1m' || selectedSlot.isDedicatedSeat)
                                ? 'Rule 3: Multi-month ($selectedDuration) members get a guaranteed fixed seat number and personal locker included for free!'
                                : 'Rule 3: 1-Month members sit on unreserved/floating seats during their slot. You can also assign a dedicated seat if preferred.',
                            style: const TextStyle(fontSize: 10, color: AppColors.slate600, height: 1.3),
                          ),
                          const SizedBox(height: 10),
                          DropdownFieldWidget(
                            label: (selectedDuration != '1m' || selectedSlot.isDedicatedSeat)
                                ? 'ALLOT DEDICATED SEAT NUMBER'
                                : 'ASSIGN SEAT (FLOATING / FLEXI)',
                            value: selectedDesk,
                            items: deskOptions,
                            hint: 'Select Seat Number',
                            onChanged: (val) {
                              if (val != null) setModalState(() => selectedDesk = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 5. Total Fee & Savings Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.indigo50.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.indigo100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TOTAL PAYABLE FEE',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 0.8),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    selectedSlot.getSavingsPitch(selectedDuration),
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.emerald700),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${selectedSlot.effectiveHourly} · ${selectedDuration.toUpperCase()}',
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FormFieldWidget(
                            label: 'EDIT TOTAL FEE (₹)',
                            placeholder: 'e.g. ${selectedSlot.getFeeForDuration(selectedDuration).toInt()}',
                            controller: feeCtrl,
                            prefix: '₹',
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedDuration == '1m'
                                ? 'Standard monthly rate: ₹${selectedSlot.fee1m.toInt()}/month'
                                : 'Effective monthly rate: ₹${selectedSlot.getEffectiveMonthly(selectedDuration).toInt()}/mo (Standard rate was ₹${selectedSlot.fee1m.toInt()}/mo)',
                            style: const TextStyle(fontSize: 9.5, color: AppColors.slate500, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Send Request Button
                    CustomButton(
                      label: isSendingRequest
                          ? 'Sending Admission Request...'
                          : 'Send Admission Request to Student',
                      onPressed: isSendingRequest
                          ? () {}
                          : () async {
                              final feeText = feeCtrl.text.trim();
                              final totalFee = double.tryParse(feeText) ?? selectedSlot.getFeeForDuration(selectedDuration);

                              if (selectedDesk == null || selectedDesk!.isEmpty) {
                                setModalState(() => globalError = 'Please select a desk number');
                                return;
                              }

                              setModalState(() {
                                isSendingRequest = true;
                                globalError = null;
                              });

                              final sId = studentData?['studentId']?.toString();
                              final isFloating = selectedDuration == '1m' && !selectedSlot.isDedicatedSeat;
                              final planDisplayName = '${selectedSlot.planName}${isFloating ? " (Floating)" : " (Dedicated)"}';

                              int months = 1;
                              if (selectedDuration == '3m') months = 3;
                              if (selectedDuration == '6m') months = 6;
                              if (selectedDuration == '1y' || selectedDuration == '12m') months = 12;
                              final monthlyEquivalent = totalFee / months;

                              final res = await ApiService.sendAdmissionRequest(
                                studentId: sId,
                                mobile: phoneCtrl.text.trim(),
                                fullName: studentData?['fullName']?.toString(),
                                assignedSeat: selectedDesk!,
                                planName: planDisplayName,
                                shiftTiming: selectedSlot.timing,
                                monthlyFee: monthlyEquivalent,
                                duration: selectedDuration,
                              );

                              setModalState(() => isSendingRequest = false);

                              if (res.success) {
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Admission request sent to ${studentData?['fullName'] ?? "student"}! ${selectedDesk!} reserved for ${selectedSlot.timing} ($selectedDuration).',
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

  Widget _buildMemberFilterPill(String filterKey, String label, Color? accentColor) {
    final isSelected = _memberValidityFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _memberValidityFilter = filterKey),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (accentColor ?? Colors.white)
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: isSelected
                ? (accentColor != null ? Colors.white : AppColors.indigo950)
                : Colors.white70,
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }

  Widget _buildModeChip(String mode, String label, String selected, ValueChanged<String> onSelected) {
    final isSel = mode == selected;
    return Expanded(
      child: InkWell(
        onTap: () => onSelected(mode),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? AppColors.indigo950 : AppColors.slate100,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isSel ? Colors.white : AppColors.slate700,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendWhatsAppReminder(MemberInfo m) async {
    final cleanPhone = m.phone.replaceAll(RegExp(r'\D'), '');
    final phoneWithCode = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
    final fee = m.monthlyFee?.toInt() ?? 499;
    final validDate = m.validTill ?? 'soon';
    final msg =
        'Hello ${m.name},\nYour library membership at $_libraryName (${m.seat}) is due for renewal on $validDate.\nPlease pay your monthly fee of ₹$fee to continue your seat without interruption.\n\nThank you,\n$_libraryName';
    final uri = Uri.parse('whatsapp://send?phone=$phoneWithCode&text=${Uri.encodeComponent(msg)}');
    final fallback = Uri.parse('https://wa.me/$phoneWithCode?text=${Uri.encodeComponent(msg)}');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildFeeCollectionsSection() {
    final activeCols = _feeCollections.where((c) => !_isCollectionFromRemovedMember(c)).toList();
    final removedCols = _feeCollections.where((c) => _isCollectionFromRemovedMember(c)).toList();

    final double activeTotal = activeCols.fold(0.0, (sum, c) => sum + c.collectedAmount);
    final double removedTotal = removedCols.fold(0.0, (sum, c) => sum + c.collectedAmount);

    return Container(
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
                children: [
                  const Text(
                    'TOTAL COLLECTION DETAILS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.slate400,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Text(
                        'Fee Collections',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.emerald50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.emerald200),
                        ),
                        child: Text(
                          '₹${_totalCollectedAmount.toInt()}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.emerald700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: _loadCollectionsData,
                icon: _loadingCollections
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orange500),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18, color: AppColors.slate500),
                tooltip: 'Refresh Collections',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Sub-totals for Active vs Removed Member Collections
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.check_circle_rounded, size: 12, color: AppColors.emerald600),
                          SizedBox(width: 4),
                          Text(
                            'Active Members',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.slate600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '₹${activeTotal.toInt()}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.emerald700),
                      ),
                      Text(
                        '${activeCols.length} receipts',
                        style: const TextStyle(fontSize: 9.5, color: AppColors.slate400),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.slate200),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.person_off_rounded, size: 12, color: AppColors.slate500),
                          SizedBox(width: 4),
                          Text(
                            'Removed Members',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.slate600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '₹${removedTotal.toInt()}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.slate700),
                      ),
                      Text(
                        '${removedCols.length} receipts',
                        style: const TextStyle(fontSize: 9.5, color: AppColors.slate400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_feeCollections.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.slate200),
              ),
              child: Column(
                children: const [
                  Icon(Icons.receipt_long_outlined, size: 28, color: AppColors.slate400),
                  SizedBox(height: 6),
                  Text(
                    'No Fee Collections Yet',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.slate700),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Receipts collected from members will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.5, color: AppColors.slate400),
                  ),
                ],
              ),
            )
          else ...[
            // Top 2 recent collection receipts as preview
            ..._feeCollections.take(2).map((col) => _buildReceiptCard(col)),

            const SizedBox(height: 4),

            // "View All Available Collections" Interactive Button -> opens modal bottom sheet
            InkWell(
              onTap: () => _showAllFeeCollectionsModal(),
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
                        const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'View All Available Collections (${_feeCollections.length})',
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
        ],
      ),
    );
  }

  Widget _buildReceiptCard(FeeCollectionItem col) {
    final isRemoved = _isCollectionFromRemovedMember(col);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isRemoved ? AppColors.slate200 : AppColors.emerald50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isRemoved ? AppColors.slate300 : AppColors.emerald200),
            ),
            alignment: Alignment.center,
            child: Icon(
              isRemoved ? Icons.person_off_rounded : Icons.receipt_rounded,
              size: 20,
              color: isRemoved ? AppColors.slate600 : AppColors.emerald600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              col.studentName,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: AppColors.slate900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isRemoved ? AppColors.slate200 : AppColors.emerald50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isRemoved ? 'Removed' : 'Active',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isRemoved ? AppColors.slate600 : AppColors.emerald700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${col.collectedAmount.toInt()}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isRemoved ? AppColors.slate700 : AppColors.emerald700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      col.seatLabel ?? 'Desk',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.indigo950,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('·', style: TextStyle(color: AppColors.slate400)),
                    const SizedBox(width: 6),
                    Text(
                      '📅 ${col.collectionDate}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.indigo50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            col.paymentMode,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.indigo950,
                            ),
                          ),
                        ),
                        if (col.originalAmount > col.collectedAmount) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(Orig: ₹${col.originalAmount.toInt()})',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.slate400,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Edit Button (Amount and Date only - NO delete)
                    InkWell(
                      onTap: () => _openEditCollectionModal(col),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.slate200),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 12, color: AppColors.slate600),
                            SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.slate700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (col.remarks != null && col.remarks!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Note: ${col.remarks!}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: AppColors.slate500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAllFeeCollectionsModal() {
    int localFilterTab = _feeCollectionTab;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final activeCols = _feeCollections.where((c) => !_isCollectionFromRemovedMember(c)).toList();
            final removedCols = _feeCollections.where((c) => _isCollectionFromRemovedMember(c)).toList();
            final double activeTotal = activeCols.fold(0.0, (sum, c) => sum + c.collectedAmount);
            final double removedTotal = removedCols.fold(0.0, (sum, c) => sum + c.collectedAmount);

            final displayedCols = localFilterTab == 1
                ? activeCols
                : (localFilterTab == 2 ? removedCols : _feeCollections);

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
                            'Fee Collections',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.slate900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total ₹${_totalCollectedAmount.toInt()} · ${_feeCollections.length} Receipts Tracked',
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

                  // Sub-totals for Active vs Removed Member Collections
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.emerald600),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Active Members', style: TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.w600)),
                                  Text('₹${activeTotal.toInt()} (${activeCols.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.emerald700)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 28, color: AppColors.slate200),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.person_off_rounded, size: 14, color: AppColors.slate500),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Removed Members', style: TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.w600)),
                                  Text('₹${removedTotal.toInt()} (${removedCols.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate700)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Segment Buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCollectionFilterPill(
                          title: 'All (${_feeCollections.length})',
                          isSelected: localFilterTab == 0,
                          onTap: () {
                            setModalState(() => localFilterTab = 0);
                            setState(() => _feeCollectionTab = 0);
                          },
                        ),
                        const SizedBox(width: 6),
                        _buildCollectionFilterPill(
                          title: 'Active Members (${activeCols.length})',
                          isSelected: localFilterTab == 1,
                          activeColor: AppColors.emerald600,
                          onTap: () {
                            setModalState(() => localFilterTab = 1);
                            setState(() => _feeCollectionTab = 1);
                          },
                        ),
                        const SizedBox(width: 6),
                        _buildCollectionFilterPill(
                          title: 'Removed Members (${removedCols.length})',
                          isSelected: localFilterTab == 2,
                          activeColor: AppColors.slate700,
                          onTap: () {
                            setModalState(() => localFilterTab = 2);
                            setState(() => _feeCollectionTab = 2);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Scrollable List of Collections
                  Expanded(
                    child: displayedCols.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.slate400),
                                const SizedBox(height: 8),
                                Text(
                                  localFilterTab == 1
                                      ? 'No Collections from Active Members'
                                      : (localFilterTab == 2
                                          ? 'No Collections from Removed Members'
                                          : 'No Fee Collections Yet'),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slate700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  localFilterTab == 2
                                      ? 'Collections from members who later left the library will appear here.'
                                      : 'Receipts collected from members will appear here.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, color: AppColors.slate400),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: displayedCols.length,
                            itemBuilder: (context, idx) {
                              final col = displayedCols[idx];
                              return _buildReceiptCard(col);
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
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
      },
    );
  }

  Widget _buildCollectionFilterPill({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    Color activeColor = AppColors.orange500,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppColors.slate100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.slate700,
          ),
        ),
      ),
    );
  }

  void _openCollectDueModal(MemberInfo m) {
    if (m.studentId == null) return;
    final originalAmount = m.monthlyFee ?? 499;
    final amountController = TextEditingController(text: originalAmount.toInt().toString());
    final remarksController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedMode = 'CASH';
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final dateStr =
              '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
          final dateDisplay = '${selectedDate.day} ${_getMonthName(selectedDate.month)} ${selectedDate.year}';

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.emerald50,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.payments_rounded, color: AppColors.emerald600, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Collect Due Fee',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.slate900),
                              ),
                              Text(
                                'Record offline fee & renew desk',
                                style: TextStyle(fontSize: 11, color: AppColors.slate500),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Student & Plan Info Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              m.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.slate900),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.indigo50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                m.seat,
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.indigo950),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${m.plan} · Standard: ₹${originalAmount.toInt()}/month',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.slate600),
                        ),
                        if (m.validTill != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Current validity: ${m.validTill}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: m.isDueSoon ? Colors.red.shade700 : AppColors.slate500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount Input
                  const Text(
                    'AMOUNT RECEIVED (₹)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.emerald300, width: 1.5),
                    ),
                    child: TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.slate900),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppColors.emerald600),
                        hintText: 'Enter amount (e.g. 400 or 499)',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'You can enter discounted amount if agreed with student.',
                    style: TextStyle(fontSize: 10.5, color: AppColors.slate400),
                  ),
                  const SizedBox(height: 16),

                  // Collection Date Picker
                  const Text(
                    'COLLECTION DATE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: isSubmitting
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2025, 1, 1),
                              lastDate: DateTime(2030, 12, 31),
                            );
                            if (picked != null) {
                              setModalState(() => selectedDate = picked);
                            }
                          },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.slate300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: AppColors.orange500, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              dateDisplay,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slate900),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: AppColors.slate400),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Mode
                  const Text(
                    'PAYMENT MODE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildModeChip('CASH', 'Cash 💵', selectedMode, (m) => setModalState(() => selectedMode = m)),
                      const SizedBox(width: 8),
                      _buildModeChip('UPI', 'UPI 📱', selectedMode, (m) => setModalState(() => selectedMode = m)),
                      const SizedBox(width: 8),
                      _buildModeChip('OFFLINE', 'Offline 🏦', selectedMode, (m) => setModalState(() => selectedMode = m)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Remarks (Optional)
                  const Text(
                    'REMARKS (OPTIONAL)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.slate300),
                    ),
                    child: TextField(
                      controller: remarksController,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Paid in cash with special discount',
                        hintStyle: TextStyle(fontSize: 11.5, color: AppColors.slate400),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 48),
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final amt = num.tryParse(amountController.text.trim());
                              if (amt == null || amt <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: Colors.red),
                                );
                                return;
                              }
                              setModalState(() => isSubmitting = true);
                              final res = await ApiService.recordFeeCollection(
                                studentId: m.studentId!,
                                membershipId: m.id,
                                originalAmount: originalAmount,
                                collectedAmount: amt,
                                collectionDate: dateStr,
                                paymentMode: selectedMode,
                                remarks: remarksController.text.trim().isNotEmpty ? remarksController.text.trim() : null,
                              );
                              if (res.success) {
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('₹${amt.toInt()} collected from ${m.name}! Membership renewed to next month.'),
                                      backgroundColor: AppColors.emerald600,
                                    ),
                                  );
                                  _loadMembersData();
                                  _loadCollectionsData();
                                }
                              } else {
                                setModalState(() => isSubmitting = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res.message ?? 'Failed to record collection'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange500,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Confirm Collection & Renew',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openEditCollectionModal(FeeCollectionItem item) {
    final amountController = TextEditingController(text: item.collectedAmount.toInt().toString());
    final remarksController = TextEditingController(text: item.remarks ?? '');
    DateTime selectedDate = DateTime.tryParse(item.collectionDate) ?? DateTime.now();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final dateStr =
              '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
          final dateDisplay = '${selectedDate.day} ${_getMonthName(selectedDate.month)} ${selectedDate.year}';

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.indigo50,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.edit_note_rounded, color: AppColors.indigo950, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Edit Collection',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.slate900),
                              ),
                              Text(
                                'Modify amount and date only',
                                style: TextStyle(fontSize: 11, color: AppColors.slate500),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Readonly details
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.studentName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.slate900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.seatLabel ?? "Desk"} · ${item.planName ?? "Monthly Plan"} · Original: ₹${item.originalAmount.toInt()}',
                          style: const TextStyle(fontSize: 11, color: AppColors.slate600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount
                  const Text(
                    'COLLECTED AMOUNT (₹)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.emerald300, width: 1.5),
                    ),
                    child: TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.slate900),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppColors.emerald600),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date
                  const Text(
                    'COLLECTION DATE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: isSubmitting
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2025, 1, 1),
                              lastDate: DateTime(2030, 12, 31),
                            );
                            if (picked != null) {
                              setModalState(() => selectedDate = picked);
                            }
                          },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.slate300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: AppColors.orange500, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              dateDisplay,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slate900),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: AppColors.slate400),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Remarks
                  const Text(
                    'REMARKS (OPTIONAL)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.slate300),
                    ),
                    child: TextField(
                      controller: remarksController,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Corrected entered amount',
                        hintStyle: TextStyle(fontSize: 11.5, color: AppColors.slate400),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Security note
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.indigo50.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.shield_outlined, size: 14, color: AppColors.indigo950),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Receipt records cannot be deleted. Only amount and collection date can be corrected.',
                            style: TextStyle(fontSize: 10.5, color: AppColors.slate600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Save Button
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 48),
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final amt = num.tryParse(amountController.text.trim());
                              if (amt == null || amt <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: Colors.red),
                                );
                                return;
                              }
                              setModalState(() => isSubmitting = true);
                              final res = await ApiService.updateFeeCollection(
                                item.id,
                                collectedAmount: amt,
                                collectionDate: dateStr,
                                remarks: remarksController.text.trim().isNotEmpty ? remarksController.text.trim() : null,
                              );
                              if (res.success) {
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Receipt updated: ₹${amt.toInt()} on $dateDisplay'),
                                      backgroundColor: AppColors.emerald600,
                                    ),
                                  );
                                  _loadCollectionsData();
                                }
                              } else {
                                setModalState(() => isSubmitting = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res.message ?? 'Failed to update receipt'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.indigo950,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Save Changes',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ),
                    ),
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

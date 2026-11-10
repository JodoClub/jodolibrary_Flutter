import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/custom_button.dart';
import '../widgets/qr_code_widget.dart';
import '../widgets/common_widgets.dart';

class StudentHomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final Function(String time, String type)? onAttendanceMarked;

  const StudentHomeScreen({
    super.key,
    required this.onLogout,
    this.onAttendanceMarked,
  });

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  StudentTab _activeTab = StudentTab.home;
  String _searchQuery = '';

  // Real Student Profile State
  String _studentName = 'Student Member';
  String _studentPhone = '';
  String _examCategory = 'UPSC / Civil Services';
  String _emergencyContact = '';
  String _gender = 'Other';
  String _studentCode = 'JODO-STU-8842';
  String _activeLibrary = 'Achievers Study Hub (Desk #B-14)';

  @override
  void initState() {
    super.initState();
    _loadStudentProfileData();
  }

  Future<void> _loadStudentProfileData() async {
    final stored = await AuthStorage.getStoredProfile();
    if (mounted) {
      setState(() {
        if (stored['name'] != null && stored['name'].toString().trim().isNotEmpty) {
          _studentName = stored['name'].toString().trim();
        }
        if (stored['phone'] != null) {
          _studentPhone = stored['phone'].toString().trim();
        }
        if (stored['examCategory'] != null && stored['examCategory'].toString().trim().isNotEmpty) {
          _examCategory = stored['examCategory'].toString().trim();
        }
        if (stored['emergencyContact'] != null && stored['emergencyContact'].toString().trim().isNotEmpty) {
          _emergencyContact = stored['emergencyContact'].toString().trim();
        }
        if (stored['gender'] != null && stored['gender'].toString().trim().isNotEmpty) {
          final g = stored['gender'].toString().trim().toLowerCase();
          if (g == 'male') {
            _gender = 'Male';
          } else if (g == 'female') {
            _gender = 'Female';
          } else {
            _gender = 'Other';
          }
        }
        if (stored['studentCode'] != null && stored['studentCode'].toString().trim().isNotEmpty) {
          _studentCode = stored['studentCode'].toString().trim();
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
            _studentName = user['name'].toString().trim();
          }
          if (user?['mobile'] != null) {
            _studentPhone = user!['mobile'].toString().trim();
          }
          if (profile?['examCategory'] != null && profile!['examCategory'].toString().trim().isNotEmpty) {
            _examCategory = profile['examCategory'].toString().trim();
          }
          if (profile?['emergencyContact'] != null && profile!['emergencyContact'].toString().trim().isNotEmpty) {
            _emergencyContact = profile['emergencyContact'].toString().trim();
          }
          if (profile?['gender'] != null && profile!['gender'].toString().trim().isNotEmpty) {
            final g = profile['gender'].toString().trim().toLowerCase();
            if (g == 'male') {
              _gender = 'Male';
            } else if (g == 'female') {
              _gender = 'Female';
            } else {
              _gender = 'Other';
            }
          }
          if (profile?['code'] != null && profile!['code'].toString().trim().isNotEmpty) {
            _studentCode = profile['code'].toString().trim();
          }
        });
        await AuthStorage.saveStudentProfile(
          studentCode: _studentCode,
          fullName: _studentName,
          examCategory: _examCategory,
          emergencyContact: _emergencyContact,
          gender: _gender,
        );
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
    return 'SM';
  }

  String _getFirstName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0];
    }
    return 'Student';
  }

  // Interactive attendance state
  bool _isCheckedIn = true;
  String _checkInTime = '08:15 AM';
  int _selectedCalendarDay = 20;
  String _attendanceViewMode = 'scanner'; // 'scanner' or 'pass'

  // Plan State
  int _planDaysLeft = 5;
  String _planValidityDate = '25/10/2026';
  String _selectedPlanDuration = '1m';

  // Analytics
  int _activeBarDay = 1; // 1 = Tue (Today)

  String _scannerStage = 'aiming'; // 'aiming', 'scanning', 'success'
  bool _torchOn = false;

  // Toast
  String? _toastTitle;
  String? _toastSubtitle;

  void _showToast(String title, String subtitle) {
    setState(() {
      _toastTitle = title;
      _toastSubtitle = subtitle;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _toastTitle = null;
          _toastSubtitle = null;
        });
      }
    });
  }

  void _performPunchIn() {
    setState(() => _scannerStage = 'scanning');
    Future.delayed(const Duration(milliseconds: 1000), () {
      final now = TimeOfDay.now();
      final timeStr =
          '${now.hourOfPeriod.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}';
      setState(() {
        _checkInTime = timeStr;
        _isCheckedIn = true;
        _scannerStage = 'success';
      });
      widget.onAttendanceMarked?.call(timeStr, 'check-in');
      _showToast('Attendance Marked as PRESENT! 🎉', 'Recorded at $timeStr · Library owner notified');
    });
  }

  void _performPunchOut() {
    setState(() => _scannerStage = 'scanning');
    Future.delayed(const Duration(milliseconds: 1000), () {
      final now = TimeOfDay.now();
      final timeStr =
          '${now.hourOfPeriod.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}';
      setState(() {
        _isCheckedIn = false;
        _scannerStage = 'success';
      });
      widget.onAttendanceMarked?.call(timeStr, 'check-out');
      _showToast('Punch Out Recorded Successfully', 'Exit recorded at $timeStr · Owner updated');
    });
  }

  void _handleRenewPlan() {
    setState(() {
      if (_selectedPlanDuration == '1m') {
        _planDaysLeft = 35;
        _planValidityDate = '25/11/2026';
      } else if (_selectedPlanDuration == '3m') {
        _planDaysLeft = 95;
        _planValidityDate = '25/01/2027';
      } else {
        _planDaysLeft = 185;
        _planValidityDate = '25/04/2027';
      }
    });
    Navigator.of(context).pop();
    _showToast('Plan Renewed Successfully! 🎉', 'Membership extended to $_planValidityDate');
  }

  final List<CalendarDayInfo> _calendarDays = [
    const CalendarDayInfo(day: 1, status: 'present', inTime: '08:15 AM', outTime: '07:30 PM', hours: '11h 15m'),
    const CalendarDayInfo(day: 2, status: 'present', inTime: '08:20 AM', outTime: '08:00 PM', hours: '11h 40m'),
    const CalendarDayInfo(day: 3, status: 'present', inTime: '09:00 AM', outTime: '06:30 PM', hours: '9h 30m'),
    const CalendarDayInfo(day: 4, status: 'holiday', note: 'Sunday · Weekly Off'),
    const CalendarDayInfo(day: 5, status: 'present', inTime: '08:05 AM', outTime: '07:45 PM', hours: '11h 40m'),
    const CalendarDayInfo(day: 6, status: 'present', inTime: '08:10 AM', outTime: '08:10 PM', hours: '12h 00m'),
    const CalendarDayInfo(day: 7, status: 'present', inTime: '08:30 AM', outTime: '07:15 PM', hours: '10h 45m'),
    const CalendarDayInfo(day: 8, status: 'present', inTime: '08:15 AM', outTime: '07:30 PM', hours: '11h 15m'),
    const CalendarDayInfo(day: 9, status: 'present', inTime: '08:00 AM', outTime: '08:00 PM', hours: '12h 00m'),
    const CalendarDayInfo(day: 10, status: 'present', inTime: '08:45 AM', outTime: '07:00 PM', hours: '10h 15m'),
    const CalendarDayInfo(day: 11, status: 'half-day', inTime: '09:00 AM', outTime: '01:30 PM', hours: '4h 30m', note: 'Optional Sunday Shift'),
    const CalendarDayInfo(day: 12, status: 'present', inTime: '08:10 AM', outTime: '07:50 PM', hours: '11h 40m'),
    const CalendarDayInfo(day: 13, status: 'present', inTime: '08:15 AM', outTime: '08:00 PM', hours: '11h 45m'),
    const CalendarDayInfo(day: 14, status: 'absent', note: 'Medical Leave (Prior notice)'),
    const CalendarDayInfo(day: 15, status: 'present', inTime: '08:30 AM', outTime: '07:30 PM', hours: '11h 00m'),
    const CalendarDayInfo(day: 16, status: 'present', inTime: '08:00 AM', outTime: '08:15 PM', hours: '12h 15m'),
    const CalendarDayInfo(day: 17, status: 'present', inTime: '08:30 AM', outTime: '07:00 PM', hours: '10h 30m'),
    const CalendarDayInfo(day: 18, status: 'half-day', inTime: '10:00 AM', outTime: '02:45 PM', hours: '4h 45m', note: 'Afternoon Revision Shift'),
    const CalendarDayInfo(day: 19, status: 'present', inTime: '08:10 AM', outTime: '08:00 PM', hours: '11h 50m'),
    const CalendarDayInfo(day: 20, status: 'present', inTime: '08:15 AM', outTime: 'Active (Inside)', hours: '6h 45m so far', note: 'Today'),
    ...List.generate(11, (i) {
      final day = 21 + i;
      return CalendarDayInfo(
        day: day,
        status: day == 25 ? 'holiday' : 'upcoming',
        note: day == 25 ? 'Sunday · Library Maintenance' : 'Scheduled Shift',
      );
    }),
  ];

  final List<StudyHoursInfo> _weeklyStudyHours = const [
    StudyHoursInfo(day: 'Mon', fullDay: 'Monday, 19 Oct', hours: 8.5, focus: 'Indian Polity & Laxmikanth revision'),
    StudyHoursInfo(day: 'Tue', fullDay: 'Tuesday, 20 Oct (Today)', hours: 7.0, focus: 'Economics & Budget Analysis', isToday: true),
    StudyHoursInfo(day: 'Wed', fullDay: 'Wednesday, 14 Oct', hours: 9.2, focus: 'Geography Mapping & Answer Writing'),
    StudyHoursInfo(day: 'Thu', fullDay: 'Thursday, 15 Oct', hours: 6.5, focus: 'Modern History & Test Series'),
    StudyHoursInfo(day: 'Fri', fullDay: 'Friday, 16 Oct', hours: 8.0, focus: 'CSAT Math & Comprehension'),
    StudyHoursInfo(day: 'Sat', fullDay: 'Saturday, 17 Oct', hours: 10.5, focus: 'Full Length Mock & Evaluation'),
    StudyHoursInfo(day: 'Sun', fullDay: 'Sunday, 18 Oct', hours: 4.8, focus: 'Weekly Current Affairs Digest'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.slate50,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: SizedBox(
                width: double.infinity,
                child: _buildCurrentTab(),
              ),
            ),
          ),

          // Floating Top Toast Notification
          if (_toastTitle != null)
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.indigo950,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.orange500.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.orange500,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.check, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _toastTitle!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _toastSubtitle!,
                              style: const TextStyle(
                                color: AppColors.orange100,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _buildBottomNav(),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_activeTab) {
      case StudentTab.home:
        return _buildHomeTab();
      case StudentTab.explore:
        return _buildExploreTab();
      case StudentTab.bookings:
        return _buildBookingsTab();
      case StudentTab.profile:
        return _buildProfileTab();
    }
  }

  // ==========================================
  // TAB 1: HOME (DASHBOARD)
  // ==========================================
  Widget _buildHomeTab() {
    final selectedDayInfo = _calendarDays.firstWhere((d) => d.day == _selectedCalendarDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Indigo Top Header
        Container(
          width: double.infinity,
          color: AppColors.indigo950,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.orange500,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.orange500.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _getInitials(_studentName),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: _isCheckedIn ? AppColors.emerald500 : AppColors.slate400,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.indigo950, width: 2.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back',
                            style: TextStyle(
                              color: AppColors.indigo300,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Hello, ${_getFirstName(_studentName)} 👋',
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
                  InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () => _openNotificationsModal(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: const [
                          Icon(Icons.notifications_none, color: Colors.white, size: 22),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: CircleAvatar(
                              radius: 4,
                              backgroundColor: AppColors.orange500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Library Status Chip
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
                          children: const [
                            Text(
                              'Achievers Study Hub - Branch 1',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Boring Road · Desk Dedicated',
                              style: TextStyle(
                                color: AppColors.indigo300,
                                fontSize: 10,
                              ),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircleAvatar(radius: 3, backgroundColor: AppColors.emerald400),
                          SizedBox(width: 4),
                          Text(
                            'Active',
                            style: TextStyle(
                              color: AppColors.emerald300,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
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
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SECTION 2: ACTIVE MEMBERSHIP HERO CARD
              _buildMembershipCard(),
              const SizedBox(height: 20),

              // SECTION 3: GATE ATTENDANCE & PASS
              _buildAttendanceSection(),
              const SizedBox(height: 20),

              // SECTION 4: ATTENDANCE CALENDAR
              _buildCalendarSection(selectedDayInfo),
              const SizedBox(height: 20),

              // SECTION 5: STUDY PRODUCTIVITY ANALYTICS
              _buildProductivitySection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMembershipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.indigo900, AppColors.indigo950, AppColors.slate900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.indigo800.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo950.withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppColors.orange400, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'ACTIVE MEMBERSHIP',
                        style: TextStyle(
                          color: AppColors.orange400,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Full Day Dedicated Desk',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Morning & Evening Shift (6:00 AM – 11:00 PM)',
                    style: TextStyle(
                      color: AppColors.indigo200,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _planDaysLeft <= 5
                      ? AppColors.amber500.withOpacity(0.25)
                      : AppColors.emerald500.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _planDaysLeft <= 5 ? AppColors.amber500 : AppColors.emerald400,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, color: AppColors.amber300, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Expires in $_planDaysLeft days',
                      style: const TextStyle(
                        color: AppColors.amber300,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Badges: Assigned Desk & Locker
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.orange500,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange500.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.grid_view_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ASSIGNED DESK',
                          style: TextStyle(
                            color: AppColors.orange100,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Seat #B-14',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.lock_outline, color: AppColors.indigo200, size: 16),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LOCKER SPACE',
                          style: TextStyle(
                            color: AppColors.indigo300,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Locker #L-08',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Validity and Renew CTA
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.12))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Plan Validity',
                      style: TextStyle(
                        color: AppColors.indigo300,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Valid till: $_planValidityDate',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _openRenewPlanModal(),
                  icon: const Icon(Icons.refresh, size: 14, color: AppColors.orange500),
                  label: const Text(
                    'Renew Plan',
                    style: TextStyle(
                      color: AppColors.indigo950,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
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
                    'GATE ATTENDANCE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.slate400,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Attendance & Gate Pass',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.slate900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _isCheckedIn ? AppColors.emerald50 : AppColors.slate100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isCheckedIn ? AppColors.emerald100 : AppColors.slate200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 3.5,
                      backgroundColor: _isCheckedIn ? AppColors.emerald500 : AppColors.slate400,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isCheckedIn ? 'Checked-in at $_checkInTime' : 'Not inside premises',
                      style: TextStyle(
                        color: _isCheckedIn ? AppColors.emerald600 : AppColors.slate600,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Switcher: Scan Library QR vs Show Pass
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _attendanceViewMode = 'scanner'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _attendanceViewMode == 'scanner' ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _attendanceViewMode == 'scanner'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 16,
                            color: _attendanceViewMode == 'scanner'
                                ? AppColors.orange600
                                : AppColors.slate500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Scan Library QR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: _attendanceViewMode == 'scanner'
                                  ? AppColors.orange600
                                  : AppColors.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _attendanceViewMode = 'pass'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _attendanceViewMode == 'pass' ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _attendanceViewMode == 'pass'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code,
                            size: 16,
                            color: _attendanceViewMode == 'pass'
                                ? AppColors.indigo950
                                : AppColors.slate500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Show My Pass',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: _attendanceViewMode == 'pass'
                                  ? AppColors.indigo950
                                  : AppColors.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Content of Switcher
          if (_attendanceViewMode == 'scanner') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.indigo950, AppColors.indigo900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.orange500,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Scan Library Attendance QR',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Scan entrance standee or desk #B-14 QR code. Owner dashboard updates in real-time.',
                              style: TextStyle(
                                color: AppColors.indigo200,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          label: 'Open Camera Scanner',
                          height: 46,
                          leading: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                          onPressed: () => _openScannerModal(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _isCheckedIn ? _performPunchOut : _performPunchIn,
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.15)),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            children: [
                              const Icon(Icons.bolt, color: AppColors.amber400, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _isCheckedIn ? 'Punch Out' : 'Quick Punch',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
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
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.indigo100),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _openQRModal(),
                    child: const QRCodeGraphic(size: 130),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Scan at library gate scanner',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: AppColors.slate800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Pass ID: JODO-STU-8842 · Tap QR to expand',
                    style: TextStyle(fontSize: 10, color: AppColors.slate500),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          label: _isCheckedIn ? 'Punch Out Now' : 'Punch In (Simulate)',
                          height: 44,
                          variant: _isCheckedIn ? ButtonVariant.ghost : ButtonVariant.primary,
                          onPressed: () {
                            if (_isCheckedIn) {
                              _performPunchOut();
                            } else {
                              _performPunchIn();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _openQRModal(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.indigo200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.fullscreen, size: 16, color: AppColors.indigo950),
                            SizedBox(width: 4),
                            Text(
                              'Expand',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.indigo950,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarSection(CalendarDayInfo selectedDayInfo) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
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
                    'ATTENDANCE LOG',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.slate400,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'October 2026',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.slate900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.indigo50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Total: 20 Days Recorded',
                  style: TextStyle(
                    color: AppColors.indigo800,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Days of week header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                .map((d) => SizedBox(
                      width: 36,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate400,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // 7-column calendar grid
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              // 3 empty placeholders for Thursday start
              const SizedBox(width: 36, height: 36),
              const SizedBox(width: 36, height: 36),
              const SizedBox(width: 36, height: 36),
              ..._calendarDays.map((item) {
                final isSelected = item.day == _selectedCalendarDay;
                final isToday = item.day == 20;

                Color dotColor;
                if (item.status == 'present') {
                  dotColor = AppColors.emerald500;
                } else if (item.status == 'absent') {
                  dotColor = AppColors.rose500;
                } else if (item.status == 'half-day') {
                  dotColor = AppColors.amber500;
                } else if (item.status == 'holiday') {
                  dotColor = AppColors.slate300;
                } else {
                  dotColor = AppColors.slate200;
                }

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _selectedCalendarDay = item.day),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.indigo50 : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.indigo950
                            : isToday
                                ? AppColors.orange500
                                : Colors.transparent,
                        width: isSelected ? 2 : 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${item.day}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                            color: item.status == 'upcoming'
                                ? AppColors.slate300
                                : AppColors.slate800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        CircleAvatar(radius: 2, backgroundColor: dotColor),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 14),

          // Day Inspector Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 5,
                      backgroundColor: selectedDayInfo.status == 'present'
                          ? AppColors.emerald500
                          : selectedDayInfo.status == 'absent'
                              ? AppColors.rose500
                              : selectedDayInfo.status == 'half-day'
                                  ? AppColors.amber500
                                  : AppColors.slate400,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Oct ${selectedDayInfo.day}, 2026 ${selectedDayInfo.day == 20 ? "(Today)" : ""} · ${selectedDayInfo.status.toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slate900,
                          ),
                        ),
                        Text(
                          selectedDayInfo.inTime != null && selectedDayInfo.outTime != null
                              ? 'In: ${selectedDayInfo.inTime} • Out: ${selectedDayInfo.outTime} (${selectedDayInfo.hours})'
                              : selectedDayInfo.note ?? 'No log recorded',
                          style: const TextStyle(fontSize: 10, color: AppColors.slate500),
                        ),
                      ],
                    ),
                  ],
                ),
                if (selectedDayInfo.hours != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Text(
                      selectedDayInfo.hours!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.indigo950,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _LegendItem(color: AppColors.emerald500, label: 'Present: 22 Days'),
              _LegendItem(color: AppColors.rose500, label: 'Absent: 4 Days'),
              _LegendItem(color: AppColors.amber500, label: 'Half-day: 2 Days'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductivitySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRODUCTIVITY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.slate400,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Study Hours & Analytics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 16),

          // 3 Metric Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.schedule,
                  label: 'Avg. Daily',
                  val: '7.5 hrs',
                  tag: '+1.2 hrs/wk',
                  tagColor: AppColors.emerald600,
                  iconBg: AppColors.indigo50,
                  iconColor: AppColors.indigo950,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.calendar_today,
                  label: 'This Month',
                  val: '164 hrs',
                  tag: 'Goal: 200h',
                  tagColor: AppColors.indigo800,
                  iconBg: AppColors.orange50,
                  iconColor: AppColors.orange600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.local_fire_department,
                  label: 'Streak',
                  val: '6 Days 🔥',
                  tag: 'Best: 14d',
                  tagColor: AppColors.orange600,
                  iconBg: AppColors.rose50,
                  iconColor: AppColors.rose600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 7-day Bar Chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.slate100),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Hours Spent in Library',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slate900,
                          ),
                        ),
                        Text(
                          'Last 7 Days (Monday to Sunday)',
                          style: TextStyle(fontSize: 10, color: AppColors.slate400),
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
                        'Total: 54.5 hrs',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.emerald600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Chart Bars
                SizedBox(
                  height: 120,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _weeklyStudyHours.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final isSelected = _activeBarDay == idx;
                      final heightPct = (item.hours / 12.0).clamp(0.0, 1.0);

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeBarDay = idx),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${item.hours}h',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected
                                      ? AppColors.orange600
                                      : AppColors.slate500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 24,
                                height: 80 * heightPct,
                                decoration: BoxDecoration(
                                  color: item.isToday
                                      ? AppColors.orange500
                                      : isSelected
                                          ? AppColors.indigo950
                                          : AppColors.indigo200,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.day,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: item.isToday
                                      ? AppColors.orange600
                                      : isSelected
                                          ? AppColors.indigo950
                                          : AppColors.slate500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // Active Bar info
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _weeklyStudyHours[_activeBarDay].fullDay,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: AppColors.slate900,
                            ),
                          ),
                          Text(
                            'Focus: ${_weeklyStudyHours[_activeBarDay].focus}',
                            style: const TextStyle(fontSize: 10, color: AppColors.slate500),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.indigo50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_weeklyStudyHours[_activeBarDay].hours} hrs',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.indigo950,
                          ),
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
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String val,
    required String tag,
    required Color tagColor,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.slate400),
          ),
          const SizedBox(height: 2),
          Text(
            val,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.slate900),
          ),
          const SizedBox(height: 4),
          Text(
            tag,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: tagColor),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: EXPLORE TAB
  // ==========================================
  Widget _buildExploreTab() {
    final nearby = [
      ['Gyan Niketan Library', 'Kankarbagh · 2.4 km', '12 seats'],
      ['The Focus Room', 'Rajendra Nagar · 3.1 km', '7 seats'],
      ['Apex Study Zone', 'Bailey Road · 4.0 km', '15 seats'],
    ];

    final filtered = nearby.where((n) {
      return '${n[0]} ${n[1]}'.toLowerCase().contains(_searchQuery.toLowerCase());
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
              const BrandLogo(compact: true, inverse: true),
              const SizedBox(height: 20),
              Row(
                children: const [
                  Icon(Icons.location_on, color: AppColors.indigo300, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Patna, Bihar',
                    style: TextStyle(
                      color: AppColors.indigo200,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Explore\nStudy Spaces',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Find your focus space for today.',
                style: TextStyle(color: AppColors.indigo200, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Search libraries or areas',
                    hintStyle: TextStyle(color: AppColors.slate400, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: AppColors.slate400),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3 Quick Action tiles
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.calendar_month,
                      label: 'Book a seat',
                      isOrange: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.schedule,
                      label: 'My bookings',
                      onTap: () => setState(() => _activeTab = StudentTab.bookings),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickActionCard(
                      icon: Icons.location_on_outlined,
                      label: 'Near me',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recommended section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Recommended for you',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900),
                  ),
                  Text(
                    'See all',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.orange500),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Recommended Library Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.slate200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 150,
                      decoration: const BoxDecoration(
                        color: AppColors.indigo950,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        image: DecorationImage(
                          image: NetworkImage(
                            'https://images.unsplash.com/photo-1762857995550-1fc51c8fbf2d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 12,
                            top: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '18 seats available',
                                style: TextStyle(
                                  color: AppColors.emerald600,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            top: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.indigo950.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '★ 4.9',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'Saraswati Study Hub',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.slate900,
                                ),
                              ),
                              Text(
                                '₹1,499/mo',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.slate900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: const [
                              Icon(Icons.location_on_outlined, size: 14, color: AppColors.slate400),
                              SizedBox(width: 4),
                              Text(
                                'Boring Road · 1.2 km',
                                style: TextStyle(fontSize: 11, color: AppColors.slate400),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: const ['24×7', 'Wi-Fi', 'AC', 'Silent Zone'].map((amenity) {
                              return Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.slate100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  amenity,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.slate600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Nearby study spaces list
              const Text(
                'Nearby study spaces',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900),
              ),
              const SizedBox(height: 12),
              ...filtered.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.slate200),
                  ),
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
                        child: const Icon(Icons.apartment, color: AppColors.indigo950, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item[0],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppColors.slate900,
                              ),
                            ),
                            Text(
                              item[1],
                              style: const TextStyle(fontSize: 11, color: AppColors.slate400),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        item[2],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.emerald600,
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
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    bool isOrange = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isOrange ? AppColors.orange50 : AppColors.indigo50,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 18,
                color: isOrange ? AppColors.orange500 : AppColors.indigo950,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.slate800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: BOOKINGS TAB
  // ==========================================
  Widget _buildBookingsTab() {
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
                  const BrandLogo(compact: true, inverse: true),
                  InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () => _openNotificationsModal(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.notifications_none, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'My Bookings',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Track and manage your desk reservations',
                style: TextStyle(color: AppColors.indigo200, fontSize: 12),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.indigo100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.emerald50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Active Membership',
                            style: TextStyle(
                              color: AppColors.emerald600,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const Text(
                          '₹1,499/mo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.indigo950,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Achievers Study Hub - Branch 1',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Seat #B-14 · Locker #L-08 · Full Day Shift',
                      style: TextStyle(fontSize: 12, color: AppColors.slate500),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.only(top: 14),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.slate100)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Valid till: $_planValidityDate',
                            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                          ),
                          TextButton(
                            onPressed: () => _openRenewPlanModal(),
                            child: const Text(
                              'Renew Plan',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: AppColors.orange500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                label: 'Book Another Desk or Shift',
                variant: ButtonVariant.secondary,
                leading: const Icon(Icons.add, size: 18, color: AppColors.slate800),
                onPressed: () => setState(() => _activeTab = StudentTab.explore),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 4: PROFILE TAB
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
                      _getInitials(_studentName),
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
                          _studentName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_examCategory Aspirant',
                          style: const TextStyle(fontSize: 12, color: AppColors.indigo200),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _openEditStudentProfileModal,
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
              Container(
                width: double.infinity,
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
                        const Text(
                          'STUDENT PROFILE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.slate400,
                            letterSpacing: 1,
                          ),
                        ),
                        InkWell(
                          onTap: _openEditStudentProfileModal,
                          child: const Text(
                            'Edit Info',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildProfileRow('Full Name', _studentName),
                    _buildProfileRow('Mobile', _studentPhone.isNotEmpty ? _studentPhone : '+91 98765 43210'),
                    _buildProfileRow('Active Library', _activeLibrary),
                    _buildProfileRow('Student ID', _studentCode),
                    _buildProfileRow('Target Exam', _examCategory),
                    _buildProfileRow('Emergency Contact', _emergencyContact.isNotEmpty ? _emergencyContact : 'Not specified'),
                    _buildProfileRow('Gender', _gender),
                    _buildProfileRow('Status', 'Active Member', isStatus: true),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              CustomButton(
                label: 'Log out / Switch account',
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

  void _openEditStudentProfileModal() {
    final nameCtrl = TextEditingController(text: _studentName);
    final emergencyCtrl = TextEditingController(text: _emergencyContact.replaceAll('+91', '').trim());
    String selectedExam = _examCategory;
    String selectedGender = 'Other';
    final currentGenderLower = _gender.trim().toLowerCase();
    if (currentGenderLower == 'male') {
      selectedGender = 'Male';
    } else if (currentGenderLower == 'female') {
      selectedGender = 'Female';
    } else {
      selectedGender = 'Other';
    }
    bool isSaving = false;
    String? nameError;
    String? emergencyError;

    final exams = [
      'UPSC / Civil Services',
      'JEE / Engineering',
      'NEET / Medical',
      'SSC / CGL / CHSL',
      'Banking / IBPS',
      'State PSC',
      'Other / Self Study',
    ];
    if (!exams.contains(selectedExam)) {
      exams.insert(0, selectedExam);
    }

    final genders = ['Male', 'Female', 'Other'];

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
                            'STUDENT PROFILE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.orange500,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            'Edit Your Profile',
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
                    label: 'FULL NAME',
                    placeholder: 'e.g. Aarav Kumar',
                    controller: nameCtrl,
                    errorText: nameError,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownFieldWidget(
                    label: 'TARGET EXAMINATION',
                    value: selectedExam,
                    items: exams,
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedExam = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  FormFieldWidget(
                    label: 'EMERGENCY CONTACT',
                    placeholder: '10-digit mobile number',
                    prefix: '+91',
                    controller: emergencyCtrl,
                    errorText: emergencyError,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownFieldWidget(
                    label: 'GENDER',
                    value: selectedGender,
                    items: genders,
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedGender = val);
                    },
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    label: isSaving ? 'Saving Changes...' : 'Save Profile Changes',
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            final emergency = emergencyCtrl.text.trim();

                            bool hasErr = false;
                            String? nErr;
                            String? eErr;

                            if (name.length < 3) {
                              nErr = 'Name must be at least 3 characters';
                              hasErr = true;
                            }
                            if (emergency.isNotEmpty && !RegExp(r'^[6-9]\d{9}$').hasMatch(emergency)) {
                              eErr = 'Enter a valid 10-digit emergency number';
                              hasErr = true;
                            }

                            if (hasErr) {
                              setModalState(() {
                                nameError = nErr;
                                emergencyError = eErr;
                              });
                              return;
                            }

                            setModalState(() => isSaving = true);

                            final res = await ApiService.updateStudentProfile(
                              fullName: name,
                              examCategory: selectedExam,
                              emergencyContact: emergency.isNotEmpty
                                  ? emergency
                                  : (_emergencyContact.isNotEmpty ? _emergencyContact : null),
                              gender: selectedGender,
                            );

                            if (!mounted) return;

                            if (res.success) {
                              setState(() {
                                _studentName = name;
                                _examCategory = selectedExam;
                                if (emergency.isNotEmpty) {
                                  _emergencyContact = emergency;
                                }
                                _gender = selectedGender;
                              });
                              await AuthStorage.saveStudentProfile(
                                studentCode: _studentCode,
                                fullName: _studentName,
                                examCategory: _examCategory,
                                emergencyContact: _emergencyContact,
                                gender: _gender,
                              );
                              if (!mounted) return;
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile updated successfully! 🎉'),
                                  backgroundColor: AppColors.secondary,
                                ),
                              );
                            } else {
                              setModalState(() => isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message ?? 'Update failed'),
                                  backgroundColor: AppColors.rose600,
                                ),
                              );
                            }
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

  Widget _buildProfileRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.slate400)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isStatus ? AppColors.emerald600 : AppColors.slate800,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BOTTOM NAVIGATION BAR
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
          _buildNavTab(StudentTab.home, Icons.home_rounded, 'Home'),
          _buildNavTab(StudentTab.explore, Icons.search_rounded, 'Explore'),
          _buildNavTab(StudentTab.bookings, Icons.calendar_today_rounded, 'Bookings'),
          _buildNavTab(StudentTab.profile, Icons.person_rounded, 'Profile'),
        ],
      ),
    );
  }

  Widget _buildNavTab(StudentTab tab, IconData icon, String label) {
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
  // MODALS & DIALOGS
  // ==========================================
  void _openScannerModal() {
    setState(() {
      _scannerStage = 'aiming';
      _torchOn = false;
    });
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Dialog(
            backgroundColor: AppColors.slate950,
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            child: Container(
              padding: const EdgeInsets.all(20),
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
                            'LIBRARY ATTENDANCE',
                            style: TextStyle(
                              color: AppColors.orange400,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'Scan Standee QR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => setModalState(() => _torchOn = !_torchOn),
                            icon: Icon(
                              Icons.bolt,
                              color: _torchOn ? AppColors.amber400 : Colors.white,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_scannerStage != 'success') ...[
                    // Viewfinder box
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _torchOn ? AppColors.amber400 : AppColors.orange500,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const QRCodeGraphic(size: 130),
                          if (_scannerStage == 'scanning')
                            const CircularProgressIndicator(color: AppColors.orange500),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Camera Active · Point at gate standee or desk #B-14 QR code',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.slate400),
                    ),
                    const SizedBox(height: 20),
                    CustomButton(
                      label: _isCheckedIn ? 'Scan to Punch Out (Mark Exit)' : 'Scan & Mark Attendance (PRESENT)',
                      onPressed: () {
                        setModalState(() => _scannerStage = 'scanning');
                        Future.delayed(const Duration(milliseconds: 1200), () {
                          if (!mounted) return;
                          final now = TimeOfDay.now();
                          final timeStr =
                              '${now.hourOfPeriod.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}';
                          setState(() {
                            if (_isCheckedIn) {
                              _isCheckedIn = false;
                            } else {
                              _isCheckedIn = true;
                              _checkInTime = timeStr;
                            }
                          });
                          widget.onAttendanceMarked?.call(timeStr, _isCheckedIn ? 'check-in' : 'check-out');
                          setModalState(() => _scannerStage = 'success');
                        });
                      },
                    ),
                  ] else ...[
                    // Success View
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: AppColors.emerald500,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.check, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _isCheckedIn ? 'Marked as PRESENT! 🎉' : 'Punch Out Recorded',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isCheckedIn
                          ? 'Attendance recorded and synced with library owner.'
                          : 'Exit time recorded. Have a great day!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.slate300, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    CustomButton(
                      label: 'Done · Back to Home',
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

  void _openQRModal() {
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
                    children: [
                      const Text(
                        'LIBRARY GATE PASS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate400,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        _studentName,
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
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const QRCodeGraphic(size: 180),
              const SizedBox(height: 16),
              const Text(
                'Seat #B-14 · Locker #L-08',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Achievers Study Hub - Branch 1',
                style: TextStyle(fontSize: 11, color: AppColors.slate500),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 3.5,
                      backgroundColor: _isCheckedIn ? AppColors.emerald500 : AppColors.slate400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isCheckedIn ? 'Inside · Checked in at $_checkInTime' : 'Outside Premises',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.emerald600,
                      ),
                    ),
                  ],
                ),
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

  void _openRenewPlanModal() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setRenewState) {
          final plans = [
            {'id': '1m', 'title': '1 Month Renewal', 'price': '₹1,499', 'tag': 'Standard Plan', 'detail': '30 Days extension'},
            {'id': '3m', 'title': '3 Months (Quarterly)', 'price': '₹3,999', 'tag': 'Save 11%', 'detail': '90 Days extension + Free locker'},
            {'id': '6m', 'title': '6 Months (Semester)', 'price': '₹7,499', 'tag': 'Save 17%', 'detail': '180 Days extension + Priority desk'},
          ];

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
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
                            'EXTEND VALIDITY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.orange500,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            'Renew Plan for Desk #B-14',
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
                  const SizedBox(height: 18),

                  ...plans.map((p) {
                    final isSel = _selectedPlanDuration == p['id'];
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setRenewState(() => _selectedPlanDuration = p['id']!),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.orange50 : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSel ? AppColors.orange500 : AppColors.slate200,
                            width: isSel ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  p['title']!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.slate900,
                                  ),
                                ),
                                Text(
                                  p['price']!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.orange600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(p['detail']!, style: const TextStyle(fontSize: 10, color: AppColors.slate500)),
                                Text(
                                  p['tag']!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.emerald600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 12),
                  CustomButton(
                    label: 'Confirm & Renew Plan',
                    onPressed: _handleRenewPlan,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openNotificationsModal() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.slate900,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildNotifItem(
                Icons.schedule,
                'Plan Renewal Reminder',
                'Your desk #B-14 plan expires in $_planDaysLeft days ($_planValidityDate). Renew now to retain your seat.',
                AppColors.amber50,
                AppColors.amber500,
              ),
              const SizedBox(height: 10),
              _buildNotifItem(
                Icons.check_circle_outline,
                'Attendance Punch Recorded',
                'Gate punch confirmed at $_checkInTime. Have a focused study session!',
                AppColors.emerald50,
                AppColors.emerald600,
              ),
              const SizedBox(height: 10),
              _buildNotifItem(
                Icons.notifications_none,
                'Library Notice',
                'Air conditioner filter servicing scheduled this Sunday 2:00 PM - 3:00 PM.',
                AppColors.slate50,
                AppColors.slate600,
              ),
              const SizedBox(height: 18),
              CustomButton(
                label: 'Dismiss',
                variant: ButtonVariant.ghost,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotifItem(IconData icon, String title, String body, Color bg, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(fontSize: 10, color: AppColors.slate600, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 3, backgroundColor: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.slate600,
          ),
        ),
      ],
    );
  }
}

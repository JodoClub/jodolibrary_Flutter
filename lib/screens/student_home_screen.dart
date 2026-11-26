import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/app_models.dart';
import '../models/library_business_model.dart';
import '../services/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/custom_button.dart';
import '../widgets/common_widgets.dart';
import '../widgets/double_back_exit_scope.dart';
import '../utils/app_haptics.dart';
import 'library_details_screen.dart';

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

class _StudentHomeScreenState extends State<StudentHomeScreen> with WidgetsBindingObserver {
  StudentTab _activeTab = StudentTab.home;
  String _searchQuery = '';
  final TextEditingController _exploreSearchController = TextEditingController();

  // Real Student Profile State
  String _studentName = 'Student Member';
  String _studentPhone = '';
  String? _studentPhotoUrl;
  String _examCategory = 'UPSC / Civil Services';
  String _emergencyContact = '';
  String _gender = 'Other';
  String _studentCode = '';
  String _activeLibrary = 'Not enrolled';
  LibraryBusinessModel? _activeLibraryModel;
  Map<String, dynamic>? _exploreRecommended;
  List<Map<String, dynamic>> _exploreNearby = [];
  bool _isLoadingExplore = false;

  // Real Pending Admission Requests & Bookings State
  List<Map<String, dynamic>> _pendingAdmissionRequests = [];
  List<Map<String, dynamic>> _membershipHistory = [];
  bool _loadingPendingRequests = false;
  Map<String, dynamic>? _activeMembershipData;
  Map<String, dynamic>? _activeLibraryData;
  bool _hasActiveMembership = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDefaultCalendarAndWeekly();
    _loadStudentProfileData();
    _fetchExploreLibraries();
    _loadStudentRequestsAndBookings();
    _loadAttendanceAndProductivity();
  }

  @override
  void dispose() {
    _exploreSearchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStudentRequestsAndBookings();
      _loadStudentProfileData();
      _loadAttendanceAndProductivity();
    }
  }

  Future<void> _loadStudentRequestsAndBookings() async {
    if (!mounted) return;
    setState(() => _loadingPendingRequests = true);
    try {
      final reqRes = await ApiService.getStudentAdmissionRequests();
      if (reqRes.success && reqRes.data != null && mounted) {
        setState(() {
          _pendingAdmissionRequests = reqRes.data!
              .where((r) => r is Map<String, dynamic> && r['status'] == 'PENDING')
              .map((r) => r as Map<String, dynamic>)
              .toList();
        });
      }
    } catch (_) {}

    try {
      final histRes = await ApiService.getStudentMembershipHistory();
      if (histRes.success && histRes.data != null && mounted) {
        setState(() {
          _membershipHistory = histRes.data!;
        });
      }
    } catch (_) {}

    try {
      final dashRes = await ApiService.getStudentDashboard();
      if (dashRes.success && dashRes.data != null && mounted) {
        final d = dashRes.data!;
        final mem = d['membership'] as Map<String, dynamic>?;
        final lib = (d['activeLibrary'] ?? d['library']) as Map<String, dynamic>?;
        final att = d['attendance'] as Map<String, dynamic>?;

        if (att != null) {
          setState(() {
            _isCheckedIn = att['isCheckedIn'] == true;
            if (att['checkInTime'] != null && att['checkInTime'].toString().isNotEmpty) {
              _checkInTime = att['checkInTime'].toString();
            }
          });
        }

        if (mem != null && lib != null) {
          setState(() {
            _hasActiveMembership = true;
            _activeMembershipData = mem;
            _activeLibraryData = lib;
            _planValidityDate = mem['validTill']?.toString() ?? _planValidityDate;
            if (mem['daysRemaining'] != null) {
              _planDaysLeft = (mem['daysRemaining'] as num).toInt();
            }
            final seat = mem['seatLabel'] ?? 'Desk';
            _activeLibrary = '${lib['name'] ?? "Study Hub"} ($seat)';
          });
        } else {
          setState(() {
            _hasActiveMembership = false;
            _activeMembershipData = null;
            _activeLibraryData = null;
            _activeLibrary = 'Not enrolled';
          });
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _loadingPendingRequests = false);
    }
  }

  Future<void> _acceptAdmissionRequest(String requestId) async {
    final res = await ApiService.acceptAdmissionRequest(requestId);
    if (res.success) {
      _showToast('Admission Accepted! 🎉', 'Welcome to ${res.data?['libraryName'] ?? "your library"}!');
      await _loadStudentRequestsAndBookings();
      await _loadStudentProfileData();
    } else {
      _showToast('Failed to Accept', res.message ?? 'Please try again');
    }
  }

  Future<void> _rejectAdmissionRequest(String requestId) async {
    final res = await ApiService.rejectAdmissionRequest(requestId, reason: 'Declined by student');
    if (res.success) {
      _showToast('Request Declined', 'Admission offer was declined.');
      await _loadStudentRequestsAndBookings();
    } else {
      _showToast('Failed to Decline', res.message ?? 'Please try again');
    }
  }

  Future<void> _fetchExploreLibraries([String? query]) async {
    setState(() => _isLoadingExplore = true);
    try {
      final res = await ApiService.exploreLibraries(query: query);
      if (res.success && res.data != null && mounted) {
        final rec = res.data!['recommended'] as Map<String, dynamic>?;
        final list = (res.data!['nearby'] as List?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        setState(() {
          _exploreRecommended = rec;
          _exploreNearby = list;
          _isLoadingExplore = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingExplore = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingExplore = false);
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

  Future<void> _loadStudentProfileData() async {
    final stored = await AuthStorage.getStoredProfile();
    if (mounted) {
      setState(() {
        if (stored['name'] != null && stored['name'].toString().trim().isNotEmpty) {
          _studentName = stored['name'].toString().trim();
        }
        if (stored['avatarUrl'] != null && stored['avatarUrl'].toString().trim().isNotEmpty) {
          _studentPhotoUrl = _resolvePhotoUrl(stored['avatarUrl'].toString().trim());
        } else if (stored['photoUrl'] != null && stored['photoUrl'].toString().trim().isNotEmpty) {
          _studentPhotoUrl = _resolvePhotoUrl(stored['photoUrl'].toString().trim());
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
          if (user?['avatarUrl'] != null && user!['avatarUrl'].toString().trim().isNotEmpty) {
            _studentPhotoUrl = _resolvePhotoUrl(user['avatarUrl'].toString().trim());
          } else if (user?['photoUrl'] != null && user!['photoUrl'].toString().trim().isNotEmpty) {
            _studentPhotoUrl = _resolvePhotoUrl(user['photoUrl'].toString().trim());
          } else if (user?['avatar'] != null && user!['avatar'].toString().trim().isNotEmpty) {
            _studentPhotoUrl = _resolvePhotoUrl(user['avatar'].toString().trim());
          } else if (profile?['photoUrl'] != null && profile!['photoUrl'].toString().trim().isNotEmpty) {
            _studentPhotoUrl = _resolvePhotoUrl(profile['photoUrl'].toString().trim());
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
      } else if (!res.success && mounted) {
        if (res.code == 'UNAUTHORIZED' || (res.message?.contains('Authentication required') ?? false)) {
          await AuthStorage.clearSession();
          widget.onLogout();
          return;
        }
      }
    } catch (_) {}

    try {
      final libRes = await ApiService.getActiveLibraryDetails();
      if (libRes.success && libRes.data != null && mounted) {
        setState(() {
          _activeLibraryModel = LibraryBusinessModel.fromJson(libRes.data!);
          if (_hasActiveMembership) {
            final seat = _activeMembershipData?['seatLabel'] ?? 'Desk';
            _activeLibrary = '${_activeLibraryModel!.displayName} ($seat)';
          }
        });
      } else if (mounted) {
        setState(() {
          _activeLibraryModel = null;
          if (!_hasActiveMembership) {
            _activeLibrary = 'Not enrolled';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _activeLibraryModel = null;
          if (!_hasActiveMembership) {
            _activeLibrary = 'Not enrolled';
          }
        });
      }
    }
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
    _openScannerModal();
  }

  Future<void> _performPunchOut() async {
    setState(() => _scannerStage = 'scanning');
    final res = await ApiService.punchOut();
    if (!mounted) return;
    if (res.success && res.data != null) {
      final timeStr = res.data!['punchOutTime']?.toString() ?? '';
      final session = res.data!['sessionDuration']?.toString();
      setState(() {
        _isCheckedIn = false;
        _scannerStage = 'success';
      });
      widget.onAttendanceMarked?.call(timeStr, 'check-out');
      _showToast(
        'Punch Out Recorded Successfully',
        session != null && session.isNotEmpty ? 'Session: $session · Exit recorded at $timeStr' : 'Recorded at $timeStr',
      );
      _loadStudentRequestsAndBookings();
      _loadAttendanceAndProductivity();
    } else {
      setState(() => _scannerStage = 'aiming');
      _showToast('Punch Out Failed', res.message ?? 'Failed to punch out');
    }
  }

  Future<void> _handleQrAttendanceScan(String qrPayload, [void Function(void Function())? setModalState]) async {
    if (setModalState != null) {
      setModalState(() => _scannerStage = 'scanning');
    } else {
      setState(() => _scannerStage = 'scanning');
    }

    final res = await ApiService.scanAttendanceQr(qrPayload: qrPayload);
    if (!mounted) return;

    if (res.success && res.data != null) {
      final data = res.data!;
      final punchType = data['punchType']?.toString() ?? (_isCheckedIn ? 'CHECK_OUT' : 'CHECK_IN');
      final timeStr = data['time']?.toString() ?? '';
      final sessionDuration = data['sessionDuration']?.toString();

      setState(() {
        if (punchType == 'CHECK_OUT') {
          _isCheckedIn = false;
        } else {
          _isCheckedIn = true;
          _checkInTime = timeStr;
        }
        _scannerStage = 'success';
      });

      if (setModalState != null) {
        setModalState(() => _scannerStage = 'success');
      }

      widget.onAttendanceMarked?.call(timeStr, punchType == 'CHECK_OUT' ? 'check-out' : 'check-in');

      if (punchType == 'CHECK_OUT') {
        _showToast(
          'Punch Out Recorded Successfully',
          sessionDuration != null && sessionDuration.isNotEmpty
              ? 'Session: $sessionDuration · Exit at $timeStr'
              : 'Exit recorded at $timeStr',
        );
      } else {
        _showToast(
          'Attendance Marked as PRESENT! 🎉',
          'Checked in at $timeStr · Library owner updated in real-time',
        );
      }

      _loadStudentRequestsAndBookings();
      _loadAttendanceAndProductivity();
    } else {
      if (setModalState != null) {
        setModalState(() => _scannerStage = 'aiming');
      } else {
        setState(() => _scannerStage = 'aiming');
      }

      final code = res.code;
      final msg = res.message ?? 'Failed to record attendance';

      String errorTitle = 'Verification Failed ❌';
      String errorBody = msg;

      if (code == 'QR_EXPIRED' || msg.toLowerCase().contains('expired') || code == 'INVALID_QR') {
        errorTitle = 'QR Expired or Invalid ❌';
        errorBody =
            'This attendance QR code is not valid or has expired (valid for 2 minutes). Please ask the library owner to generate a fresh QR code.';
      } else if (code == 'NO_ACTIVE_MEMBERSHIP') {
        errorTitle = 'Not Enrolled in Library ❌';
        errorBody =
            'You do not have an active membership in this library.\nPlease contact the library owner to enroll and allot your seat.';
      } else if (code == 'WRONG_LIBRARY') {
        errorTitle = 'Wrong Library QR ❌';
        errorBody =
            'This QR code belongs to a different library than the one you are currently enrolled in.';
      } else if (code == 'MEMBERSHIP_EXPIRED') {
        errorTitle = 'Membership Expired ❌';
        errorBody =
            'Your library membership has expired. Please renew your plan to continue marking attendance.';
      } else if (code == 'OUTSIDE_GEOFENCE') {
        errorTitle = 'Outside Library Boundary ❌';
        errorBody = 'You must be physically present at the library to mark attendance.';
      }

      _showAttendanceErrorDialog(errorTitle, errorBody);
    }
  }

  void _showAttendanceErrorDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: Text(body, style: const TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(c),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange500,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('OK / Understood', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
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

  // Real Attendance Log State
  String _calendarMonthLabel = '';
  int _calendarFirstDayOffset = 0;
  List<CalendarDayInfo> _calendarDays = [];
  int _presentDaysCount = 0;
  int _absentDaysCount = 0;
  int _halfDaysCount = 0;
  int _holidaysCount = 0;
  int _totalRecordedDays = 0;

  // Real Productivity Analytics State
  double _avgDailyHours = 0.0;
  String _weeklyTrendTag = '+0.0 hrs/wk';
  double _thisMonthStudyHours = 0.0;
  int _monthlyGoalHours = 200;
  int _currentStreakDays = 0;
  int _bestStreakDays = 0;
  double _totalWeeklyHours = 0.0;
  List<StudyHoursInfo> _weeklyStudyHours = [];

  CalendarDayInfo get _currentSelectedDayInfo {
    if (_calendarDays.isEmpty) {
      return CalendarDayInfo(
        day: DateTime.now().day,
        status: _isCheckedIn ? 'present' : 'upcoming',
        inTime: _isCheckedIn ? _checkInTime : null,
        outTime: _isCheckedIn ? 'Active (Inside)' : null,
        hours: _isCheckedIn ? 'In Progress' : null,
        note: _isCheckedIn ? 'Today · Active Inside' : 'Today',
      );
    }
    return _calendarDays.firstWhere(
      (d) => d.day == _selectedCalendarDay,
      orElse: () => _calendarDays.first,
    );
  }

  StudyHoursInfo get _currentActiveBarInfo {
    if (_weeklyStudyHours.isEmpty) {
      return const StudyHoursInfo(
        day: 'Today',
        fullDay: 'Today',
        hours: 0.0,
        focus: 'No sessions recorded yet',
        isToday: true,
      );
    }
    final idx = _activeBarDay.clamp(0, _weeklyStudyHours.length - 1);
    return _weeklyStudyHours[idx];
  }

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _monthAbbrs = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static const List<String> _weekdayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  String _getMonthName(int month) => (month >= 1 && month <= 12) ? _monthNames[month - 1] : '';
  String _getMonthAbbr(int month) => (month >= 1 && month <= 12) ? _monthAbbrs[month - 1] : '';
  String _getWeekdayName(int weekday) => (weekday >= 1 && weekday <= 7) ? _weekdayNames[weekday - 1] : '';

  void _initDefaultCalendarAndWeekly() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday;
    _calendarFirstDayOffset = (firstWeekday - 1) % 7;
    _calendarMonthLabel = '${_getMonthName(month)} $year';
    _selectedCalendarDay = now.day.clamp(1, daysInMonth);

    _calendarDays = List.generate(daysInMonth, (i) {
      final day = i + 1;
      final isSunday = DateTime(year, month, day).weekday == DateTime.sunday;
      if (day == now.day) {
        return CalendarDayInfo(
          day: day,
          status: _isCheckedIn ? 'present' : 'upcoming',
          inTime: _isCheckedIn ? _checkInTime : null,
          outTime: _isCheckedIn ? 'Active (Inside)' : null,
          hours: _isCheckedIn ? 'In Progress' : null,
          note: _isCheckedIn ? 'Today · Active Inside' : 'Today',
        );
      }
      return CalendarDayInfo(
        day: day,
        status: isSunday ? 'holiday' : (day < now.day ? 'absent' : 'upcoming'),
        note: isSunday ? 'Sunday · Weekly Off' : (day < now.day ? 'No Log Recorded' : 'Scheduled Shift'),
      );
    });

    _presentDaysCount = _isCheckedIn ? 1 : 0;
    _absentDaysCount = 0;
    _halfDaysCount = 0;
    _holidaysCount = _calendarDays.where((d) => d.status == 'holiday').length;
    _totalRecordedDays = _presentDaysCount;

    // Default 7 days of current week
    final currentWeekday = now.weekday; // 1 = Mon ... 7 = Sun
    final monday = now.subtract(Duration(days: currentWeekday - 1));
    _weeklyStudyHours = List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
      final dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i];
      final full = '${_getWeekdayName(d.weekday)}, ${d.day} ${_getMonthAbbr(d.month)}${isToday ? ' (Today)' : ''}';
      return StudyHoursInfo(
        day: dayAbbr,
        fullDay: full,
        hours: 0.0,
        focus: isToday ? 'Self Study & Library Session' : 'Rest / No Session Recorded',
        isToday: isToday,
      );
    });
    _activeBarDay = (currentWeekday - 1).clamp(0, 6);
  }

  Future<void> _loadAttendanceAndProductivity() async {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // Load Attendance
    try {
      final attRes = await ApiService.getStudentMonthlyAttendance(
        month: currentMonth,
        year: currentYear,
      );
      if (attRes.success && attRes.data != null && mounted) {
        final data = attRes.data!;
        final monthStr = data['month']?.toString() ?? '${_getMonthName(currentMonth)} $currentYear';
        final summary = data['summary'] as Map<String, dynamic>? ?? {};
        final rawDays = (data['days'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];

        final daysMap = <int, Map<String, dynamic>>{};
        for (final item in rawDays) {
          final d = (item['day'] as num?)?.toInt();
          if (d != null) daysMap[d] = item;
        }

        final daysInMonth = DateTime(currentYear, currentMonth + 1, 0).day;
        final firstWeekday = DateTime(currentYear, currentMonth, 1).weekday; // 1 = Mon, 7 = Sun
        final firstOffset = (firstWeekday - 1) % 7;

        final newCalendarDays = <CalendarDayInfo>[];
        for (int d = 1; d <= daysInMonth; d++) {
          final dayDate = DateTime(currentYear, currentMonth, d);
          final isSunday = dayDate.weekday == DateTime.sunday;
          final isToday = d == now.day;
          final isPast = d < now.day;

          if (isToday && _isCheckedIn) {
            newCalendarDays.add(CalendarDayInfo(
              day: d,
              status: 'present',
              inTime: _checkInTime,
              outTime: 'Active (Inside)',
              hours: 'In Progress',
              note: 'Today · Active Inside Library',
            ));
          } else if (daysMap.containsKey(d)) {
            final entry = daysMap[d]!;
            final rawStatus = (entry['status'] ?? 'present').toString().toLowerCase().replaceAll('_', '-');
            newCalendarDays.add(CalendarDayInfo(
              day: d,
              status: rawStatus,
              inTime: entry['inTime']?.toString(),
              outTime: entry['outTime']?.toString(),
              hours: entry['hours']?.toString(),
              note: entry['note']?.toString() ?? (rawStatus == 'present' ? 'Present' : null),
            ));
          } else if (isPast) {
            newCalendarDays.add(CalendarDayInfo(
              day: d,
              status: isSunday ? 'holiday' : 'absent',
              note: isSunday ? 'Sunday · Weekly Off' : 'No Log Recorded',
            ));
          } else {
            newCalendarDays.add(CalendarDayInfo(
              day: d,
              status: isSunday ? 'holiday' : 'upcoming',
              note: isSunday ? 'Sunday · Library Maintenance' : 'Scheduled Shift',
            ));
          }
        }

        final pCount = (summary['presentDays'] as num?)?.toInt() ??
            newCalendarDays.where((d) => d.status == 'present').length;
        final aCount = (summary['absentDays'] as num?)?.toInt() ??
            newCalendarDays.where((d) => d.status == 'absent').length;
        final hfCount = (summary['halfDays'] as num?)?.toInt() ??
            newCalendarDays.where((d) => d.status == 'half-day').length;
        final holCount = (summary['holidays'] as num?)?.toInt() ??
            newCalendarDays.where((d) => d.status == 'holiday').length;

        setState(() {
          _calendarMonthLabel = monthStr;
          _calendarFirstDayOffset = firstOffset;
          _calendarDays = newCalendarDays;
          _presentDaysCount = pCount;
          _absentDaysCount = aCount;
          _halfDaysCount = hfCount;
          _holidaysCount = holCount;
          _totalRecordedDays = pCount + aCount + hfCount;
          if (_selectedCalendarDay < 1 || _selectedCalendarDay > daysInMonth) {
            _selectedCalendarDay = now.day.clamp(1, daysInMonth);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading attendance: $e');
    }

    // Load Productivity
    try {
      final prodRes = await ApiService.getStudentProductivity();
      if (prodRes.success && prodRes.data != null && mounted) {
        final data = prodRes.data!;
        final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
        final weeklyGraph = data['weeklyGraph'] as Map<String, dynamic>? ?? {};
        final graphDays = (weeklyGraph['days'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];

        final newWeekly = <StudyHoursInfo>[];
        int todayIdx = -1;

        for (int i = 0; i < graphDays.length; i++) {
          final g = graphDays[i];
          final dayAbbr = g['day']?.toString() ?? '';
          final dateStr = g['date']?.toString() ?? '';
          final hrs = (g['hours'] as num?)?.toDouble() ?? 0.0;
          final isToday = g['isToday'] == true;

          String fullDayLabel = dayAbbr;
          if (dateStr.isNotEmpty) {
            final parsedDate = DateTime.tryParse(dateStr);
            if (parsedDate != null) {
              fullDayLabel = '${_getWeekdayName(parsedDate.weekday)}, ${parsedDate.day} ${_getMonthAbbr(parsedDate.month)}';
            }
          }
          if (isToday) {
            fullDayLabel = '$fullDayLabel (Today)';
            todayIdx = i;
          }

          final focusStr = g['focus']?.toString() ??
              (hrs > 0 ? 'Self Study & Library Session' : 'Rest / No Session Recorded');

          newWeekly.add(StudyHoursInfo(
            day: dayAbbr,
            fullDay: fullDayLabel,
            hours: hrs,
            focus: focusStr,
            isToday: isToday,
          ));
        }

        setState(() {
          _avgDailyHours = (metrics['avgDailyHours'] as num?)?.toDouble() ?? 0.0;
          _weeklyTrendTag = metrics['weeklyTrend']?.toString() ?? '+0.0 hrs/wk';
          _thisMonthStudyHours = (metrics['thisMonthHours'] as num?)?.toDouble() ?? 0.0;
          _monthlyGoalHours = (metrics['monthlyGoalHours'] as num?)?.toInt() ?? 200;
          _currentStreakDays = (metrics['currentStreakDays'] as num?)?.toInt() ?? 0;
          _bestStreakDays = (metrics['bestStreakDays'] as num?)?.toInt() ?? 0;
          _totalWeeklyHours = (weeklyGraph['totalWeeklyHours'] as num?)?.toDouble() ?? 0.0;
          if (newWeekly.isNotEmpty) {
            _weeklyStudyHours = newWeekly;
            if (todayIdx != -1) {
              _activeBarDay = todayIdx;
            } else if (_activeBarDay >= newWeekly.length) {
              _activeBarDay = newWeekly.length - 1;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading productivity: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DoubleBackExitScope(
      canPopFallback: _activeTab != StudentTab.home,
      onBackFallback: () {
        setState(() => _activeTab = StudentTab.home);
      },
      child: Scaffold(
        backgroundColor: AppColors.slate50,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadStudentRequestsAndBookings();
                await _loadStudentProfileData();
                await _loadAttendanceAndProductivity();
                if (_activeTab == StudentTab.explore) {
                  await _fetchExploreLibraries();
                }
              },
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
    final selectedDayInfo = _currentSelectedDayInfo;

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
                  Expanded(
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AppAvatar(
                              size: 48,
                              gender: _gender,
                              photoUrl: _studentPhotoUrl,
                              borderColor: AppColors.orange400,
                              borderWidth: 2.5,
                            ),
                            Positioned(
                              right: -1,
                              bottom: -1,
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
                        Expanded(
                          child: Column(
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

              // Library Status Chip (Interactive Google Business Profile)
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _hasActiveMembership ? _openActiveLibraryDetails : () => setState(() => _activeTab = StudentTab.explore),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.orange400, width: 2),
                              ),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: AppColors.orange500,
                                  shape: BoxShape.circle,
                                ),
                                clipBehavior: Clip.antiAlias,
                                alignment: Alignment.center,
                                child: const Icon(Icons.apartment, color: Colors.white, size: 18),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _activeLibraryModel?.displayName ??
                                        (_hasActiveMembership
                                            ? (_activeLibraryData?['name']?.toString() ?? 'Study Hub Library')
                                            : 'No Active Membership'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _activeLibraryModel != null
                                        ? '${_activeLibraryModel!.area ?? _activeLibraryModel!.city} · ${_activeLibraryModel!.timing}'
                                        : (_hasActiveMembership ? 'Patna · 24×7 Open' : 'Tap to explore & find a study hub'),
                                    style: const TextStyle(
                                      color: AppColors.indigo300,
                                      fontSize: 10,
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
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.orange500.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.orange400.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'Profile',
                              style: TextStyle(
                                color: AppColors.orange400,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.chevron_right, size: 12, color: AppColors.orange400),
                          ],
                        ),
                      ),
                    ],
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
              // SECTION 1.5: PENDING ADMISSION OFFERS (IF ANY)
              _buildPendingAdmissionRequestsCard(),

              // SECTION 2: ACTIVE MEMBERSHIP HERO CARD
              _buildMembershipCard(),
              const SizedBox(height: 20),

              // SECTION 3: ATTENDANCE SCANNER
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

  Widget _buildPendingAdmissionRequestsCard() {
    if (_loadingPendingRequests) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }
    if (_pendingAdmissionRequests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final req in _pendingAdmissionRequests) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.orange500.withOpacity(0.08),
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.orange500.withOpacity(0.35), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.orange500.withOpacity(0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
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
                        color: AppColors.orange500,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.mail_rounded, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'ADMISSION OFFER RECEIVED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (req['monthlyFee'] != null)
                      Text(
                        '₹${req['monthlyFee']}/mo',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.indigo950,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  req['libraryName']?.toString() ?? 'Study Hub Library',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.slate900,
                  ),
                ),
                if (req['libraryAddress'] != null && req['libraryAddress'].toString().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: AppColors.slate500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          req['libraryAddress'].toString(),
                          style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.indigo50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.indigo100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chair_rounded, size: 14, color: AppColors.indigo600),
                          const SizedBox(width: 4),
                          Text(
                            'Seat: ${req['seatNumber'] ?? 'Allotted'}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.indigo950,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (req['shiftTiming'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.emerald50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.emerald100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 14, color: AppColors.emerald600),
                            const SizedBox(width: 4),
                            Text(
                              req['shiftTiming'].toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.emerald800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (req['planName'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.slate100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          req['planName'].toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: () => _acceptAdmissionRequest(req['requestId']?.toString() ?? ''),
                        icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Accept Admission',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald600,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectAdmissionRequest(req['requestId']?.toString() ?? ''),
                        icon: const Icon(Icons.close_rounded, size: 15, color: AppColors.slate600),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Decline',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate700,
                            ),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.slate300),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMembershipCard() {
    if (!_hasActiveMembership) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.indigo100),
          boxShadow: [
            BoxShadow(
              color: AppColors.indigo950.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.orange500.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chair_outlined, color: AppColors.orange500, size: 28),
            ),
            const SizedBox(height: 14),
            const Text(
              'No Active Library Membership',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'You are not currently enrolled in any library desk or shift. Once a library owner admits you or sends an offer, it will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.slate500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() => _activeTab = StudentTab.explore),
              icon: const Icon(Icons.explore_outlined, size: 16, color: Colors.white),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Explore Top Libraries Near You',
                  maxLines: 1,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange500,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      );
    }

    final planTitle = _activeMembershipData?['planName']?.toString() ?? 'Full Day Dedicated Desk';
    final shiftTitle = _activeMembershipData?['shiftTiming']?.toString() ?? 'Morning & Evening Shift';
    final seatLabel = _activeMembershipData?['seatNumber']?.toString() ??
        _activeMembershipData?['seatLabel']?.toString() ??
        'Desk';
    final lockerLabel = _activeMembershipData?['lockerNumber']?.toString() ?? 'Locker #L-08';
    final validDate = _activeMembershipData?['validTill']?.toString() ?? _planValidityDate;
    final daysRemaining = _activeMembershipData?['daysRemaining'] != null
        ? (_activeMembershipData!['daysRemaining'] as num).toInt()
        : _planDaysLeft;
    final isDueSoon = _activeMembershipData?['isExpiringSoon'] == true || daysRemaining <= 5;
    final paymentStatus = _activeMembershipData?['paymentStatus']?.toString() ?? (isDueSoon ? 'DUE' : 'PAID');
    final monthlyFee = _activeMembershipData?['monthlyFee']?.toString() ?? '499';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 5-Day Renewal Alert Banner if Expiring Soon
        if (isDueSoon) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Renewal Due in $daysRemaining Days',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Colors.red.shade900,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '₹$monthlyFee/mo',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.red.shade900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your desk plan expires on $validDate. Please pay your monthly fee of ₹$monthlyFee to library owner to retain your seat without interruption.',
                        style: TextStyle(fontSize: 11, color: Colors.red.shade800, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.indigo900, AppColors.indigo950, AppColors.slate900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDueSoon ? Colors.red.withOpacity(0.5) : AppColors.indigo800.withOpacity(0.5),
            ),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.auto_awesome, color: AppColors.orange400, size: 14),
                        SizedBox(width: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'ACTIVE MEMBERSHIP',
                              style: TextStyle(
                                color: AppColors.orange400,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
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
                        color: isDueSoon
                            ? Colors.red.withValues(alpha: 0.25)
                            : AppColors.emerald500.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDueSoon ? Colors.redAccent : AppColors.emerald400,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isDueSoon ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                            color: isDueSoon ? Colors.redAccent : AppColors.emerald300,
                            size: 11,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isDueSoon
                                    ? 'Renewal Due · ${daysRemaining}d left'
                                    : 'Fee Paid · ${daysRemaining}d left',
                                maxLines: 1,
                                style: TextStyle(
                                  color: isDueSoon ? Colors.red.shade200 : AppColors.emerald300,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                planTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                shiftTitle,
                style: const TextStyle(
                  color: AppColors.indigo200,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 18),

              // Badges: Assigned Desk & Locker
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        children: [
                          const Icon(Icons.grid_view_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'ASSIGNED DESK',
                                    style: TextStyle(
                                      color: AppColors.orange100,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Seat #$seatLabel',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline, color: AppColors.indigo200, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'LOCKER SPACE',
                                    style: TextStyle(
                                      color: AppColors.indigo300,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    lockerLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                    Expanded(
                      child: Column(
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
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Valid till: $validDate',
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _openRenewPlanModal(),
                      icon: Icon(
                        isDueSoon ? Icons.payments_rounded : Icons.refresh,
                        size: 14,
                        color: isDueSoon ? Colors.white : AppColors.orange500,
                      ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isDueSoon ? 'Pay / Renew' : 'Renew Plan',
                          style: TextStyle(
                            color: isDueSoon ? Colors.white : AppColors.indigo950,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDueSoon ? AppColors.orange500 : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        elevation: 0,
                      ),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'ATTENDANCE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate400,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Daily Attendance',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isCheckedIn ? AppColors.emerald50 : AppColors.slate100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isCheckedIn ? AppColors.emerald200 : AppColors.slate200,
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
                      _isCheckedIn ? 'Checked-in · $_checkInTime' : 'Not inside',
                      style: TextStyle(
                        color: _isCheckedIn ? AppColors.emerald700 : AppColors.slate600,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Attendance Scanner Card
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
                            'Scan the attendance QR code displayed by library owner to record check-in and punch-out.',
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
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openScannerModal(),
                  child: Container(
                    height: 46,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Scan Attendance QR',
                              maxLines: 1,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ATTENDANCE LOG',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate400,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _calendarMonthLabel.isNotEmpty
                            ? _calendarMonthLabel
                            : '${_getMonthName(DateTime.now().month)} ${DateTime.now().year}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate900,
                        ),
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
                    color: AppColors.indigo50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Total: $_totalRecordedDays Days Recorded',
                      maxLines: 1,
                      style: const TextStyle(
                        color: AppColors.indigo800,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Days of week header
          Row(
            children: const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                .map((d) => Expanded(
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

          // 7-column responsive calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _calendarFirstDayOffset + _calendarDays.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              if (index < _calendarFirstDayOffset) {
                return const SizedBox.shrink();
              }
              final item = _calendarDays[index - _calendarFirstDayOffset];
              final isSelected = item.day == _selectedCalendarDay;
              final isToday = item.day == DateTime.now().day;

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
            },
          ),
          const SizedBox(height: 14),

          // Day Inspector Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.slate200),
            ),
            child: Row(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_getMonthAbbr(DateTime.now().month)} ${selectedDayInfo.day}, ${DateTime.now().year} ${selectedDayInfo.day == DateTime.now().day ? "(Today)" : ""} · ${selectedDayInfo.status.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedDayInfo.inTime != null && selectedDayInfo.outTime != null
                            ? 'In: ${selectedDayInfo.inTime} • Out: ${selectedDayInfo.outTime}'
                            : selectedDayInfo.note ?? 'No log recorded',
                        style: const TextStyle(fontSize: 10, color: AppColors.slate500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (selectedDayInfo.hours != null) ...[
                  const SizedBox(width: 8),
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
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LegendItem(color: AppColors.emerald500, label: 'Present: $_presentDaysCount Days'),
              _LegendItem(color: AppColors.rose500, label: 'Absent: $_absentDaysCount Days'),
              _LegendItem(color: AppColors.amber500, label: 'Half-day: $_halfDaysCount Days'),
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
                  val: '${_avgDailyHours.toStringAsFixed(1)} hrs',
                  tag: _weeklyTrendTag,
                  tagColor: _weeklyTrendTag.contains('-') ? AppColors.rose500 : AppColors.emerald600,
                  iconBg: AppColors.indigo50,
                  iconColor: AppColors.indigo950,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.calendar_today,
                  label: 'This Month',
                  val: '${_thisMonthStudyHours % 1 == 0 ? _thisMonthStudyHours.toInt() : _thisMonthStudyHours.toStringAsFixed(1)} hrs',
                  tag: 'Goal: ${_monthlyGoalHours}h',
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
                  val: '$_currentStreakDays Days 🔥',
                  tag: 'Best: ${_bestStreakDays}d',
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
                      child: Text(
                        'Total: ${_totalWeeklyHours.toStringAsFixed(1)} hrs',
                        style: const TextStyle(
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
                      final maxHours = _weeklyStudyHours.fold<double>(8.0, (prev, elem) => elem.hours > prev ? elem.hours : prev);
                      final heightPct = (item.hours / (maxHours > 0 ? maxHours : 8.0)).clamp(0.0, 1.0);

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _activeBarDay = idx),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${item.hours % 1 == 0 ? item.hours.toInt() : item.hours.toStringAsFixed(1)}h',
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentActiveBarInfo.fullDay,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.slate900,
                              ),
                            ),
                            Text(
                              'Focus: ${_currentActiveBarInfo.focus}',
                              style: const TextStyle(fontSize: 10, color: AppColors.slate500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.indigo50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_currentActiveBarInfo.hours % 1 == 0 ? _currentActiveBarInfo.hours.toInt() : _currentActiveBarInfo.hours.toStringAsFixed(1)} hrs',
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.slate400),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              val,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.slate900),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              tag,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: tagColor),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: EXPLORE TAB
  // ==========================================
  Widget _buildExploreTab() {
    final q = _searchQuery.trim().toLowerCase();
    final recName = (_exploreRecommended?['name']?.toString() ?? '').toLowerCase();
    final recArea = (_exploreRecommended?['area']?.toString() ?? '').toLowerCase();
    final bool showRecommended = _exploreRecommended != null &&
        (q.isEmpty || recName.contains(q) || recArea.contains(q));

    final filteredNearby = _exploreNearby.where((lib) {
      final name = (lib['name']?.toString() ?? '').toLowerCase();
      final area = (lib['area']?.toString() ?? '').toLowerCase();
      return q.isEmpty || name.contains(q) || area.contains(q);
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
                  controller: _exploreSearchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search libraries or areas',
                    hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: AppColors.slate400),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel, color: AppColors.slate400, size: 20),
                            onPressed: () {
                              AppHaptics.light();
                              _exploreSearchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              // Recommended section
              if (showRecommended) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Recommended for you',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900),
                    ),
                    Text(
                      'Verified',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.orange500),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Recommended Library Card
                InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _openRecommendedLibraryDetails,
                  child: Container(
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
                          decoration: BoxDecoration(
                            color: AppColors.indigo950,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            image: DecorationImage(
                              image: NetworkImage(
                                (_exploreRecommended?['photoUrl'] != null && _exploreRecommended!['photoUrl'].toString().isNotEmpty)
                                    ? (_exploreRecommended!['photoUrl'].toString().startsWith('/')
                                        ? '${ApiConfig.baseUrl.replaceAll('/api/v1', '')}${_exploreRecommended!['photoUrl']}'
                                        : _exploreRecommended!['photoUrl'].toString())
                                    : 'https://images.unsplash.com/photo-1762857995550-1fc51c8fbf2d?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixlib=rb-4.1.0&q=80&w=1080',
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
                                  child: Text(
                                    '${_exploreRecommended?['seatsAvailable'] ?? 0} seats available',
                                    style: const TextStyle(
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
                                  child: Text(
                                    '★ ${((_exploreRecommended?['rating'] as num?)?.toDouble() ?? 5.0).toStringAsFixed(1)}',
                                    style: const TextStyle(
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
                                children: [
                                  Expanded(
                                    child: Text(
                                      _exploreRecommended?['name']?.toString() ?? 'Study Hub Library',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.slate900,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '₹${((_exploreRecommended?['monthlyPrice'] as num?)?.toInt() ?? 0)}/mo',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.slate900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 14, color: AppColors.slate400),
                                  const SizedBox(width: 4),
                                  Text(
                                    _exploreRecommended?['area']?.toString() ?? 'Patna',
                                    style: const TextStyle(fontSize: 11, color: AppColors.slate400),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: ['24×7', 'Wi-Fi', 'AC', 'Silent Zone'].map((amenity) {
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
                ),
                const SizedBox(height: 24),
              ],

              // Other library spaces list
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Other Library Spaces',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.slate900),
                  ),
                  if (_isLoadingExplore)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (filteredNearby.isNotEmpty)
                ...filteredNearby.map((item) {
                  final String? photo = item['photoUrl']?.toString();
                  final String resolvedPhoto = (photo != null && photo.isNotEmpty)
                      ? (photo.startsWith('/') ? '${ApiConfig.baseUrl.replaceAll('/api/v1', '')}$photo' : photo)
                      : '';
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _openLibraryDetailsById(item['id']?.toString()),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: resolvedPhoto.isNotEmpty
                                ? Image.network(
                                    resolvedPhoto,
                                    width: 46,
                                    height: 46,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: AppColors.indigo50,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.apartment, color: AppColors.indigo950, size: 20),
                                    ),
                                  )
                                : Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: AppColors.indigo50,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.apartment, color: AppColors.indigo950, size: 20),
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.slate900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item['area'] ?? 'Patna'} · ₹${((item['monthlyPrice'] as num?)?.toInt() ?? 0)}/mo · ★ ${((item['rating'] as num?)?.toDouble() ?? 5.0).toStringAsFixed(1)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.slate400),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.emerald50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${item['seatsAvailable'] ?? 0} seats',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.emerald600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                })
              else if (showRecommended)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.indigo50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.verified_outlined, color: AppColors.indigo950, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'All Verified Libraries Listed Above',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slate900),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Tap the recommended library to view desks, shift timings, and admission details.',
                              style: TextStyle(fontSize: 11, color: AppColors.slate500, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: AppColors.indigo50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.apartment_outlined, color: AppColors.indigo950, size: 26),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        q.isNotEmpty ? 'No Libraries Matching "$_searchQuery"' : 'No Libraries Found',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        q.isNotEmpty
                            ? 'Try searching by a different name or area.'
                            : 'Currently registered libraries will show here as they join the platform.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppColors.slate500),
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
            children: const [
              Text(
                'My Bookings',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
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
              // Pending Admission Offers (if any)
              _buildPendingAdmissionRequestsCard(),

              if (_hasActiveMembership) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.indigo100),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.indigo950.withOpacity(0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
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
                              border: Border.all(color: AppColors.emerald200),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 12, color: AppColors.emerald600),
                                SizedBox(width: 4),
                                Text(
                                  'Active Membership',
                                  style: TextStyle(
                                    color: AppColors.emerald600,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_activeMembershipData?['monthlyFee'] != null)
                            Text(
                              '₹${_activeMembershipData!['monthlyFee']}/mo',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.indigo950,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _activeLibraryData?['name']?.toString() ?? 'Study Hub Library',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate900,
                        ),
                      ),
                      if (_activeLibraryData?['address'] != null && _activeLibraryData!['address'].toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _activeLibraryData!['address'].toString(),
                          style: const TextStyle(fontSize: 12, color: AppColors.slate500),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.orange50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.orange200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.chair_rounded, size: 14, color: AppColors.orange600),
                                const SizedBox(width: 4),
                                Text(
                                  'Seat: ${_activeMembershipData?['seatNumber'] ?? _activeMembershipData?['seatLabel'] ?? 'Desk'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.orange900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_activeMembershipData?['shiftTiming'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.indigo50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.indigo100),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.schedule, size: 14, color: AppColors.indigo600),
                                  const SizedBox(width: 4),
                                  Text(
                                    _activeMembershipData!['shiftTiming'].toString(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.indigo900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_activeMembershipData?['planName'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.slate100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _activeMembershipData!['planName'].toString(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate700,
                                ),
                              ),
                            ),
                        ],
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
                              'Valid till: ${_activeMembershipData?['validTill']?.toString() ?? _planValidityDate}',
                              style: const TextStyle(fontSize: 12, color: AppColors.slate500, fontWeight: FontWeight.w600),
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
              ] else if (_pendingAdmissionRequests.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.indigo50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bookmark_outline_rounded, color: AppColors.indigo600, size: 30),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Active Bookings',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'You do not have any active desk reservations or admission offers at the moment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.slate500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_membershipHistory.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 16, color: AppColors.slate500),
                    const SizedBox(width: 6),
                    Text(
                      'PAST MEMBERSHIPS & LEAVE HISTORY (${_membershipHistory.length})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate500,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._membershipHistory.map((hist) {
                  final libName = hist['libraryName']?.toString() ?? 'Library';
                  final branch = hist['branchName']?.toString() ?? '';
                  final address = hist['address']?.toString() ?? '';
                  final seat = hist['seatLabel']?.toString() ?? 'Unassigned';
                  final plan = hist['planName']?.toString() ?? 'Standard';
                  final joined = hist['joinedDate']?.toString() ?? 'N/A';
                  final left = hist['leftDate']?.toString() ?? 'N/A';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.slate200),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.slate900.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                libName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.slate900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: const Text(
                                'Ex-Member / Left',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (branch.isNotEmpty || address.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            branch.isNotEmpty && address.isNotEmpty
                                ? '$branch · $address'
                                : (branch.isNotEmpty ? branch : address),
                            style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.slate100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.chair_rounded, size: 12, color: AppColors.slate600),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Seat: $seat',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.slate700),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.indigo50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.card_membership_rounded, size: 12, color: AppColors.indigo800),
                                  const SizedBox(width: 4),
                                  Text(
                                    plan,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.indigo950),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.slate50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.slate100),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.login_rounded, size: 13, color: AppColors.emerald600),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Enrolled: $joined',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.slate700),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.logout_rounded, size: 13, color: Colors.red),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Left: $left',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.red),
                                  ),
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
                  AppAvatar(
                    size: 64,
                    gender: _gender,
                    photoUrl: _studentPhotoUrl,
                    borderColor: AppColors.orange400,
                    borderWidth: 2.5,
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
                    _buildProfileRow('Student ID', _studentCode.isNotEmpty ? _studentCode : 'Pending Admission'),
                    _buildProfileRow('Target Exam', _examCategory),
                    _buildProfileRow('Emergency Contact', _emergencyContact.isNotEmpty ? _emergencyContact : 'Not specified'),
                    _buildProfileRow('Gender', _gender),
                    _buildProfileRow('Status', _hasActiveMembership ? 'Active Member' : 'Not Enrolled', isStatus: true),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Enrolled Library Card
              if (_hasActiveMembership)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.orange500.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.orange500.withOpacity(0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.orange500, width: 2),
                                ),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: AppColors.orange500,
                                    shape: BoxShape.circle,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.apartment, color: Colors.white, size: 18),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'MY ENROLLED LIBRARY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.orange500,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  Text(
                                    'Library Details',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.slate900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.emerald500.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(radius: 3, backgroundColor: AppColors.emerald500),
                                SizedBox(width: 4),
                                Text(
                                  'Enrolled',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.emerald600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _activeLibraryData?['name']?.toString() ??
                            _activeLibraryModel?.displayName ??
                            'My Library',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _activeLibraryData?['address']?.toString() ??
                            (_activeLibraryModel != null
                                ? '${_activeLibraryModel!.address}, ${_activeLibraryModel!.city}'
                                : ''),
                        style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildStudentLibChip(
                            Icons.chair_alt_rounded,
                            _activeMembershipData?['seatLabel'] ?? 'Desk Assigned',
                          ),
                          _buildStudentLibChip(
                            Icons.schedule_outlined,
                            _activeMembershipData?['shiftTiming'] ?? _activeLibraryModel?.timing ?? '24×7 Open',
                          ),
                          _buildStudentLibChip(
                            Icons.map_outlined,
                            'Live Map Nav',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      CustomButton(
                        label: 'View Photos, Map & All Facilities',
                        leading: const Icon(Icons.storefront_rounded, size: 16),
                        onPressed: _openActiveLibraryDetails,
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.indigo50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.storefront_outlined, color: AppColors.indigo950, size: 24),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Not Enrolled in Any Library',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.slate900),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Find top-rated libraries nearby with verified WiFi, AC, and quiet study zones.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: AppColors.slate500, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      CustomButton(
                        label: 'Explore Libraries Near Me',
                        leading: const Icon(Icons.explore_outlined, size: 16),
                        onPressed: () => setState(() => _activeTab = StudentTab.explore),
                      ),
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
                  Center(
                    child: AppAvatar(
                      size: 72,
                      gender: selectedGender,
                      photoUrl: _studentPhotoUrl,
                      borderColor: AppColors.orange400,
                      borderWidth: 2.5,
                    ),
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

  Widget _buildStudentLibChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.slate600),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.slate700,
            ),
          ),
        ],
      ),
    );
  }

  void _openActiveLibraryDetails() {
    if (_activeLibraryModel != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LibraryDetailsScreen(
            libraryId: _activeLibraryModel?.id,
            initialData: _activeLibraryModel,
          ),
        ),
      );
      return;
    }
    final libId = _activeLibraryData?['id']?.toString();
    if (libId != null && libId.isNotEmpty) {
      _openLibraryDetailsById(libId);
    }
  }

  void _openLibraryDetailsById(String? id) {
    if (id == null || id.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LibraryDetailsScreen(
          libraryId: id,
        ),
      ),
    );
  }

  void _openRecommendedLibraryDetails() {
    final id = _exploreRecommended?['id']?.toString();
    if (id != null && id.isNotEmpty) {
      _openLibraryDetailsById(id);
    }
  }

  Widget _buildProfileRow(String label, String value, {bool isStatus = false, VoidCallback? onTap}) {
    final rowContent = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.slate400)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isStatus
                      ? AppColors.emerald600
                      : (onTap != null ? AppColors.primary : AppColors.slate800),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.primary),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, child: rowContent);
    }
    return rowContent;
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: _buildNavTab(StudentTab.home, Icons.home_rounded, 'Home')),
          Expanded(child: _buildNavTab(StudentTab.explore, Icons.search_rounded, 'Explore')),
          Expanded(child: _buildNavTab(StudentTab.bookings, Icons.calendar_today_rounded, 'Bookings')),
          Expanded(child: _buildNavTab(StudentTab.profile, Icons.person_rounded, 'Profile')),
        ],
      ),
    );
  }

  Widget _buildNavTab(StudentTab tab, IconData icon, String label) {
    final isActive = _activeTab == tab;
    return InkWell(
      onTap: () {
        AppHaptics.selection();
        setState(() => _activeTab = tab);
        _loadStudentRequestsAndBookings();
        _loadStudentProfileData();
        if (tab == StudentTab.explore) {
          _fetchExploreLibraries();
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
  // MODALS & DIALOGS
  // ==========================================
  double _scannerViewfinderSize(BuildContext ctx) {
    final size = MediaQuery.sizeOf(ctx);
    final byWidth = size.width * 0.62;
    final byHeight = size.height * 0.34;
    return (byWidth < byHeight ? byWidth : byHeight).clamp(180.0, 300.0);
  }

  void _showManualCodeInputDialog(BuildContext modalCtx, void Function(void Function()) setModalState) {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppColors.slate900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.pin_outlined, color: AppColors.orange500, size: 22),
            SizedBox(width: 8),
            Text(
              'Enter Passcode',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 6-digit dynamic passcode displayed on the library owner\'s Attendance QR screen:',
              style: TextStyle(color: AppColors.slate300, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (val) {
                final code = val.trim();
                if (code.length == 6) {
                  Navigator.of(dlgCtx).pop();
                  _handleQrAttendanceScan(code, setModalState);
                }
              },
              onChanged: (val) {
                if (val.trim().length == 6) {
                  Navigator.of(dlgCtx).pop();
                  _handleQrAttendanceScan(val.trim(), setModalState);
                }
              },
              maxLength: 6,
              autofocus: true,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                letterSpacing: 6,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                hintText: '000000',
                hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 6),
                filled: true,
                fillColor: AppColors.slate800,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.orange500, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.slate400)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange500,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              final code = codeCtrl.text.trim();
              if (code.length == 6) {
                Navigator.of(dlgCtx).pop();
                _handleQrAttendanceScan(code, setModalState);
              }
            },
            child: const Text('Verify & Punch In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openScannerModal() {
    setState(() {
      _scannerStage = 'aiming';
      _torchOn = false;
    });

    final MobileScannerController scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
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
                            onPressed: () {
                              scannerController.toggleTorch();
                              setModalState(() => _torchOn = !_torchOn);
                            },
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
                    // Real Camera Viewfinder box
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        // Scales with the screen: larger on big phones/tablets,
                        // still fits short screens without overflowing the dialog.
                        width: _scannerViewfinderSize(ctx),
                        height: _scannerViewfinderSize(ctx),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _torchOn ? AppColors.amber400 : AppColors.orange500,
                            width: 2.5,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            MobileScanner(
                              controller: scannerController,
                              onDetect: (capture) {
                                if (_scannerStage == 'scanning' || _scannerStage == 'success') return;
                                final barcodes = capture.barcodes;
                                for (final barcode in barcodes) {
                                  final raw = barcode.rawValue;
                                  if (raw != null && raw.trim().isNotEmpty) {
                                    _handleQrAttendanceScan(raw.trim(), setModalState);
                                    break;
                                  }
                                }
                              },
                              errorBuilder: (context, error) {
                                return Container(
                                  color: Colors.black87,
                                  padding: const EdgeInsets.all(16),
                                  alignment: Alignment.center,
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 36),
                                      SizedBox(height: 8),
                                      Text(
                                        'Camera Viewfinder',
                                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Point camera at library standee QR or use button below',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: AppColors.slate400, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            if (_scannerStage == 'scanning')
                              Container(
                                color: Colors.black54,
                                child: const Center(
                                  child: CircularProgressIndicator(color: AppColors.orange500),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 16,
                            color: _isCheckedIn ? AppColors.emerald500 : AppColors.orange500,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _isCheckedIn
                                  ? 'Point camera at attendance QR or punch out below'
                                  : 'Point camera at library\'s live 2-minute dynamic QR code',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.slate300,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_isCheckedIn) ...[
                      CustomButton(
                        label: 'Punch Out (Mark Exit)',
                        onPressed: () {
                          _performPunchOut();
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ] else ...[
                      TextButton.icon(
                        onPressed: () => _showManualCodeInputDialog(ctx, setModalState),
                        icon: const Icon(Icons.pin_outlined, size: 16, color: AppColors.orange400),
                        label: const Text(
                          'Enter 6-Digit Attendance Code',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.orange400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
    ).then((_) {
      scannerController.dispose();
    });
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
                'Attendance punch confirmed at $_checkInTime. Have a focused study session!',
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

import 'package:flutter/material.dart';
import 'models/app_models.dart';
import 'screens/dashboard_landing_screen.dart';
import 'screens/mobile_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/owner_setup_screen.dart';
import 'screens/partner_home_screen.dart';
import 'screens/student_home_screen.dart';
import 'screens/student_setup_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/api_service.dart';
import 'services/auth_storage.dart';
import 'services/network_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NetworkService.instance.initialize();
  runApp(const JodoApp());
}

class JodoApp extends StatelessWidget {
  const JodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'jodolibrary',
      debugShowCheckedModeBanner: false,
      navigatorKey: NetworkService.navigatorKey,
      scaffoldMessengerKey: NetworkService.scaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final clampedScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.10,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedScaler),
          child: Stack(
            children: [
              ?child,
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: OfflineBannerBar(),
              ),
            ],
          ),
        );
      },
      home: const JodoRootFlow(),
    );
  }
}

class JodoRootFlow extends StatefulWidget {
  const JodoRootFlow({super.key});

  @override
  State<JodoRootFlow> createState() => _JodoRootFlowState();
}

class _JodoRootFlowState extends State<JodoRootFlow> {
  AppScreen _currentScreen = AppScreen.welcome;
  UserRole? _role;
  String _phone = '9876543210';

  List<ActivityItem> _partnerActivities = [];

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final loggedIn = await AuthStorage.isLoggedIn();
    if (!loggedIn) return;

    final role = await AuthStorage.getRole();
    final phone = await AuthStorage.getPhone();
    if (role == null) return;

    if (mounted) {
      setState(() {
        _role = role;
        if (phone != null) _phone = phone;
      });
    }

    // 1. Check local stored profile first
    final storedProfile = await AuthStorage.getStoredProfile();
    bool hasProfile = role == UserRole.admin
        ? (storedProfile['libraryName'] != null && storedProfile['libraryName'].toString().trim().isNotEmpty)
        : (storedProfile['name'] != null && storedProfile['name'].toString().trim().isNotEmpty);

    if (hasProfile) {
      if (mounted) {
        setState(() {
          _currentScreen = role == UserRole.admin
              ? AppScreen.partnerHome
              : AppScreen.studentHome;
        });
      }
      // Refresh profile data from backend
      ApiService.getMe();
    } else {
      // 2. If local profile is empty, check backend before deciding screen
      try {
        final meRes = await ApiService.getMe();
        if (meRes.success && meRes.data != null) {
          final user = meRes.data!['user'] as Map<String, dynamic>?;
          final profile = meRes.data!['profile'] as Map<String, dynamic>?;
          final hasBackendProfile = role == UserRole.admin
              ? (profile?['name'] != null && profile!['name'].toString().trim().isNotEmpty)
              : (user?['name'] != null && user!['name'].toString().trim().isNotEmpty);

          if (hasBackendProfile) {
            hasProfile = true;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          if (hasProfile) {
            _currentScreen = role == UserRole.admin
                ? AppScreen.partnerHome
                : AppScreen.studentHome;
          } else {
            // New user who entered mobile + OTP but closed before completing profile setup
            _currentScreen = role == UserRole.admin
                ? AppScreen.ownerSetup
                : AppScreen.studentSetup;
          }
        });
      }
    }
  }

  void _handleStudentAttendanceMarked(String time, String type) {
    setState(() {
      final newActivity = ActivityItem(
        icon: type == 'check-in' ? 'check' : 'clock',
        title: 'Aarav Kumar ${type == 'check-in' ? "marked PRESENT (QR Scan)" : "checked out"}',
        detail: 'Seat #B-14 · Today at $time',
        isHighlight: type == 'check-in',
      );
      _partnerActivities = [
        newActivity,
        ..._partnerActivities.where((a) => !a.title.contains('Aarav Kumar')),
      ];
    });
  }

  void _selectRole(UserRole role) {
    setState(() {
      _role = role;
      _currentScreen = AppScreen.mobile;
    });
  }

  void _verifyOtp(AccountType accountType) {
    if (_role == null) return;
    setState(() {
      if (accountType == AccountType.returning) {
        _currentScreen = _role == UserRole.admin
            ? AppScreen.adminDashboard
            : AppScreen.studentDashboard;
      } else {
        _currentScreen = _role == UserRole.admin
            ? AppScreen.ownerSetup
            : AppScreen.studentSetup;
      }
    });
  }

  void _goTo(AppScreen screen) {
    setState(() => _currentScreen = screen);
  }

  Future<void> _restart() async {
    await ApiService.logout();
    if (!mounted) return;
    setState(() {
      _currentScreen = AppScreen.welcome;
      _role = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentScreen) {
      case AppScreen.welcome:
        return WelcomeScreen(onSelectRole: _selectRole);

      case AppScreen.mobile:
        return MobileScreen(
          role: _role ?? UserRole.student,
          onBack: _restart,
          onContinue: (phone) {
            setState(() {
              _phone = phone;
              _currentScreen = AppScreen.otp;
            });
          },
        );

      case AppScreen.otp:
        return OTPScreen(
          role: _role ?? UserRole.student,
          phone: _phone,
          onBack: () => _goTo(AppScreen.mobile),
          onVerify: _verifyOtp,
        );

      case AppScreen.ownerSetup:
        return OwnerSetupScreen(
          onBack: () => _goTo(AppScreen.otp),
          onComplete: () => _goTo(AppScreen.adminDashboard),
        );

      case AppScreen.studentSetup:
        return StudentSetupScreen(
          onBack: () => _goTo(AppScreen.otp),
          onComplete: () => _goTo(AppScreen.studentDashboard),
        );

      case AppScreen.adminDashboard:
        return DashboardLandingScreen(
          role: UserRole.admin,
          onContinue: () => _goTo(AppScreen.partnerHome),
          onRestart: _restart,
        );

      case AppScreen.studentDashboard:
        return DashboardLandingScreen(
          role: UserRole.student,
          onContinue: () => _goTo(AppScreen.studentHome),
          onRestart: _restart,
        );

      case AppScreen.studentHome:
        return StudentHomeScreen(
          onLogout: _restart,
          onAttendanceMarked: _handleStudentAttendanceMarked,
        );

      case AppScreen.partnerHome:
        return PartnerHomeScreen(
          onLogout: _restart,
          activities: _partnerActivities,
        );
    }
  }
}

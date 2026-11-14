import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Global singleton service for monitoring network connectivity and handling offline popup state.
class NetworkService {
  static final NetworkService instance = NetworkService._internal();
  NetworkService._internal();

  /// Global navigator key to allow showing dialogs without having context passed from callers
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  bool _isDialogShowing = false;
  bool get isDialogShowing => _isDialogShowing;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _controller.stream;

  /// Initialize real-time network listener
  void initialize() {
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChanged);
    // Check initial connectivity on startup
    checkConnection();
  }

  /// Handle connectivity state transitions
  Future<void> _handleConnectivityChanged(List<ConnectivityResult> results) async {
    final bool hasInterface = results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);

    if (!hasInterface) {
      _setOffline();
      return;
    }

    // Has network interface (Wi-Fi/Mobile) - verify actual internet access
    final bool hasAccess = await _pingInternet();
    if (hasAccess) {
      _setOnline();
    } else {
      _setOffline();
    }
  }

  /// Ping DNS to verify real internet connectivity
  Future<bool> _pingInternet() async {
    try {
      final res = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(seconds: 3));
      return res.isNotEmpty && res[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    } catch (_) {
      // Fallback: try one.one.one.one
      try {
        final res = await InternetAddress.lookup('one.one.one.one')
            .timeout(const Duration(seconds: 2));
        return res.isNotEmpty && res[0].rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  /// Force a manual check of connection status (e.g. from Retry button)
  Future<bool> checkConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final bool hasInterface = results.isNotEmpty &&
          !results.every((r) => r == ConnectivityResult.none);

      if (!hasInterface) {
        _setOffline();
        return false;
      }

      final bool hasAccess = await _pingInternet();
      if (hasAccess) {
        _setOnline();
        return true;
      } else {
        _setOffline();
        return false;
      }
    } catch (_) {
      _setOffline();
      return false;
    }
  }

  void _setOffline() {
    if (_isOnline) {
      _isOnline = false;
      _controller.add(false);
    }
    showNoInternetPopup();
  }

  void _setOnline() {
    final wasOffline = !_isOnline;
    _isOnline = true;
    _controller.add(true);

    if (_isDialogShowing) {
      dismissPopup();
    }

    if (wasOffline) {
      _showBackOnlineToast();
    }
  }

  /// Notifies the network service from API layer when a network failure occurs
  void notifyNetworkError() {
    _setOffline();
  }

  /// Displays the No Internet Connection popup dialog
  void showNoInternetPopup() {
    if (_isDialogShowing) return;

    final context = navigatorKey.currentContext;
    if (context == null) {
      // Retry in next frame if context not yet mounted
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isOnline && !_isDialogShowing) {
          showNoInternetPopup();
        }
      });
      return;
    }

    _isDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _NoInternetDialog(),
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  /// Dismisses popup if active
  void dismissPopup() {
    if (!_isDialogShowing) return;
    final context = navigatorKey.currentContext;
    if (context != null && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    _isDialogShowing = false;
  }

  void _showBackOnlineToast() {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: AppColors.secondaryDark,
        duration: const Duration(seconds: 3),
        content: Row(
          children: const [
            Icon(Icons.wifi_rounded, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Back online! Connection restored.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

/// The popup dialog presented when the device is offline
class _NoInternetDialog extends StatefulWidget {
  const _NoInternetDialog();

  @override
  State<_NoInternetDialog> createState() => _NoInternetDialogState();
}

class _NoInternetDialogState extends State<_NoInternetDialog> {
  bool _isChecking = false;

  Future<void> _handleRetry() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    final online = await NetworkService.instance.checkConnection();

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (online) {
      NetworkService.instance.dismissPopup();
    } else {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: AppColors.rose600,
          duration: const Duration(seconds: 2),
          content: Row(
            children: const [
              Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Still offline. Please check your Wi-Fi or cellular network.',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Badge with pulse glow effect
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.rose50,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.rose100, width: 2),
              ),
              child: const Center(
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 38,
                  color: AppColors.rose600,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'No Internet Connection',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),

            // Description
            const Text(
              'You appear to be offline. Please check your Wi-Fi or mobile data connection and try again to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.slate600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // Retry Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isChecking ? null : _handleRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isChecking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.refresh_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Retry Connection',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 10),

            // Dismiss Button
            SizedBox(
              width: double.infinity,
              height: 42,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.slate500,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slim top offline notification bar with animated transitions
class OfflineBannerBar extends StatefulWidget {
  const OfflineBannerBar({super.key});

  @override
  State<OfflineBannerBar> createState() => _OfflineBannerBarState();
}

class _OfflineBannerBarState extends State<OfflineBannerBar> {
  bool _isOnline = NetworkService.instance.isOnline;
  bool _showRestoredBanner = false;
  Timer? _restoredTimer;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = NetworkService.instance.onConnectivityChanged.listen((online) {
      if (!mounted) return;
      if (online && !_isOnline) {
        setState(() {
          _isOnline = true;
          _showRestoredBanner = true;
        });
        _restoredTimer?.cancel();
        _restoredTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showRestoredBanner = false);
        });
      } else if (!online && _isOnline) {
        _restoredTimer?.cancel();
        setState(() {
          _isOnline = false;
          _showRestoredBanner = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _restoredTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline && !_showRestoredBanner) {
      return const SizedBox.shrink();
    }

    final isOffline = !_isOnline;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          color: isOffline ? AppColors.rose600 : AppColors.secondaryDark,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                isOffline
                    ? 'No internet connection'
                    : 'Back online! Connection restored',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              if (isOffline) ...[
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    NetworkService.instance.showNoInternetPopup();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

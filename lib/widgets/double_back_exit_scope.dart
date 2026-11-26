import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/app_haptics.dart';

/// Wraps a screen with double-back-to-exit protection and tab back navigation.
///
/// Features:
/// 1. If [canPopFallback] is true and [onBackFallback] is provided, pressing back
///    switches back to the root tab (e.g., Home) rather than exiting.
/// 2. If already on the root tab/screen, the 1st back press shows a sleek floating
///    exit confirmation toast with an instant "Exit" action button.
/// 3. Pressing back a 2nd time within [timeout] smoothly exits the app.
class DoubleBackExitScope extends StatefulWidget {
  final Widget child;

  /// True if the screen can handle an inner back press (e.g., on a secondary tab).
  final bool canPopFallback;

  /// Action taken when [canPopFallback] is true (e.g. `_activeTab = StudentTab.home`).
  final VoidCallback? onBackFallback;

  /// Message shown on the 1st back press.
  final String message;

  /// Time window to press back a second time to exit.
  final Duration timeout;

  const DoubleBackExitScope({
    super.key,
    required this.child,
    this.canPopFallback = false,
    this.onBackFallback,
    this.message = 'Press back again to exit Jodo Library',
    this.timeout = const Duration(milliseconds: 2500),
  });

  @override
  State<DoubleBackExitScope> createState() => _DoubleBackExitScopeState();
}

class _DoubleBackExitScopeState extends State<DoubleBackExitScope> {
  DateTime? _lastBackPress;

  void _handlePopInvoked(bool didPop, dynamic result) {
    if (didPop) return;

    // 1. Inner tab back navigation (e.g., switch from Explore tab -> Home tab)
    if (widget.canPopFallback && widget.onBackFallback != null) {
      AppHaptics.selection();
      widget.onBackFallback!();
      return;
    }

    // 2. Check time since last back press
    final now = DateTime.now();
    if (_lastBackPress != null && now.difference(_lastBackPress!) <= widget.timeout) {
      // 2nd press within timeout -> exit app
      SystemNavigator.pop();
      return;
    }

    _lastBackPress = now;
    AppHaptics.warning();

    // 3. Show sleek floating toast with an instant "Exit" action button
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      SystemNavigator.pop();
      return;
    }

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.exit_to_app_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.message,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'EXIT',
          textColor: Colors.amberAccent,
          onPressed: () {
            SystemNavigator.pop();
          },
        ),
        backgroundColor: AppColors.slate900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        duration: widget.timeout,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handlePopInvoked,
      child: widget.child,
    );
  }
}

import 'package:flutter/services.dart';

/// Lightweight helper for tactile haptic feedback across the app.
class AppHaptics {
  AppHaptics._();

  /// Subtle click feedback for tab switching and segmented controls.
  static void selection() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Light impact for standard buttons, chips, and card taps.
  static void light() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Medium impact for pull-to-refresh and sheet presentation.
  static void medium() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Heavy impact for critical submissions or confirmations.
  static void heavy() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Vibrates once when warning the user (e.g., first back press before exit).
  static void warning() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Vibration for successful actions (attendance marked, enquiry sent, etc.).
  static void success() {
    try {
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 120), () {
        try {
          HapticFeedback.lightImpact();
        } catch (_) {}
      });
    } catch (_) {}
  }
}

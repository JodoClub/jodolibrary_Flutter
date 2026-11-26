import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'app_haptics.dart';

/// Helper to copy text to system clipboard with a tactile feedback and floating toast.
class ClipboardHelper {
  ClipboardHelper._();

  static Future<void> copy(
    BuildContext context,
    String text, {
    String? label,
  }) async {
    if (text.trim().isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: text.trim()));
      AppHaptics.selection();

      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.emerald500, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label != null ? 'Copied $label to clipboard' : 'Copied to clipboard',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.slate900,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {}
  }
}

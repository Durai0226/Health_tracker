import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Standard confirmation bottom sheet for critical actions
/// Replaces AlertDialog for delete, logout, and destructive actions
class ConfirmationBottomSheet {
  /// Show a confirmation sheet for destructive actions
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    IconData? icon,
    bool isDangerous = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dangerColor = Colors.red.shade400;
    final primaryColor = Theme.of(context).primaryColor;
    final buttonColor = isDangerous ? dangerColor : (confirmColor ?? primaryColor);

    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            if (icon != null) ...[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: buttonColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: buttonColor, size: 28),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context, false);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        cancelText,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Show delete confirmation
  static Future<bool?> showDelete({
    required BuildContext context,
    required String itemName,
    String? customMessage,
  }) {
    return show(
      context: context,
      title: 'Delete $itemName?',
      message: customMessage ?? 'This action cannot be undone. Are you sure you want to delete this $itemName?',
      confirmText: 'Delete',
      icon: Icons.delete_outline_rounded,
      isDangerous: true,
    );
  }

  /// Show sign out confirmation
  static Future<bool?> showSignOut({
    required BuildContext context,
  }) {
    return show(
      context: context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out? Your local data will be preserved.',
      confirmText: 'Sign Out',
      icon: Icons.logout_rounded,
      isDangerous: false,
    );
  }

  /// Show discard changes confirmation
  static Future<bool?> showDiscardChanges({
    required BuildContext context,
  }) {
    return show(
      context: context,
      title: 'Discard Changes?',
      message: 'You have unsaved changes. Are you sure you want to discard them?',
      confirmText: 'Discard',
      icon: Icons.warning_amber_rounded,
      isDangerous: true,
    );
  }

  /// Show reset confirmation
  static Future<bool?> showReset({
    required BuildContext context,
    required String featureName,
  }) {
    return show(
      context: context,
      title: 'Reset $featureName?',
      message: 'This will reset all $featureName data to default. This action cannot be undone.',
      confirmText: 'Reset',
      icon: Icons.refresh_rounded,
      isDangerous: true,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../design/app_design.dart';
import '../../services/notification_service.dart';
import 'app_card.dart';
import 'app_button.dart';

/// Calm Clarity warning banner shown when OS notifications are disabled.
///
/// Self-managing: checks [NotificationService.areNotificationsEnabled] on init
/// and renders nothing while loading or when notifications are enabled. Drop it
/// at the top of any dashboard (settings, reminders, medicine) and it stays out
/// of the way until permission is actually off.
///
/// The "Enable notifications" action re-requests the runtime permission and, if
/// the OS no longer shows a prompt (permanently denied), falls back to opening
/// the app's system settings page.
class NotificationPermissionBanner extends StatefulWidget {
  /// Outer margin around the banner card.
  final EdgeInsetsGeometry? margin;

  /// Called after every (re)check with the latest enabled state. Lets a parent
  /// mirror the status into its own UI (e.g. hide a duplicate gate).
  final ValueChanged<bool>? onStatusChanged;

  const NotificationPermissionBanner({
    super.key,
    this.margin,
    this.onStatusChanged,
  });

  @override
  State<NotificationPermissionBanner> createState() =>
      _NotificationPermissionBannerState();
}

class _NotificationPermissionBannerState
    extends State<NotificationPermissionBanner> {
  /// null = still checking; true/false = known state.
  bool? _enabled;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final enabled = await NotificationService().areNotificationsEnabled();
    if (!mounted) return;
    setState(() => _enabled = enabled);
    widget.onStatusChanged?.call(enabled);
  }

  Future<void> _enable() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      // First try a normal runtime re-request.
      await NotificationService().requestPermissionsIfNeeded();
      var enabled = await NotificationService().areNotificationsEnabled();

      // If still off, the prompt was likely suppressed (permanently denied) —
      // send the user to the system settings page.
      if (!enabled) {
        await openAppSettings();
        enabled = await NotificationService().areNotificationsEnabled();
      }

      if (!mounted) return;
      setState(() => _enabled = enabled);
      widget.onStatusChanged?.call(enabled);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide while loading and whenever notifications are enabled.
    if (_enabled != false) return const SizedBox.shrink();

    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final warning = ext.warning;

    return AppCard(
      margin: widget.margin,
      color: warning.container,
      pressEffect: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Symbols.notifications_off_rounded,
                color: warning.onContainer,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications are turned off',
                      style: tt.titleSmall?.copyWith(
                        color: warning.onContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Medicine and reminder alerts will not appear until you '
                      'enable notifications for DailyMinder.',
                      style: tt.bodySmall?.copyWith(color: warning.onContainer),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Enable notifications',
              leadingIcon: Symbols.notifications_active_rounded,
              size: AppButtonSize.sm,
              accent: warning,
              loading: _working,
              onPressed: _enable,
            ),
          ),
        ],
      ),
    );
  }
}

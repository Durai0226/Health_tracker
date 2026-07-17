import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/design/app_colors_ext.dart';
import '../../../../core/services/clean_storage_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/widgets/app/app_widgets.dart';

/// A one-tap "remind me to measure" control for a vitals tracker. Tapping when
/// off asks for a time and schedules a daily local notification; tapping when on
/// turns it off. Enabled state + time persist in app preferences.
class VitalsReminderButton extends StatefulWidget {
  final int id; // stable notification id
  final String prefKey; // e.g. 'vitals_bp_reminder'
  final String title; // notification title
  final String body;
  final AccentSwatch accent;
  final int defaultHour;

  const VitalsReminderButton({
    super.key,
    required this.id,
    required this.prefKey,
    required this.title,
    required this.body,
    required this.accent,
    this.defaultHour = 9,
  });

  @override
  State<VitalsReminderButton> createState() => _VitalsReminderButtonState();
}

class _VitalsReminderButtonState extends State<VitalsReminderButton> {
  bool _enabled = false;
  int _hour = 9;
  int _min = 0;

  @override
  void initState() {
    super.initState();
    _hour = widget.defaultHour;
    _enabled = CleanStorageService.getAppPreference('${widget.prefKey}_on', false) == true;
    _hour = CleanStorageService.getAppPreference('${widget.prefKey}_h', widget.defaultHour) as int? ?? widget.defaultHour;
    _min = CleanStorageService.getAppPreference('${widget.prefKey}_m', 0) as int? ?? 0;
  }

  Future<void> _toggle() async {
    HapticFeedback.selectionClick();
    if (_enabled) {
      await NotificationService().cancelNotification(widget.id);
      await CleanStorageService.setAppPreference('${widget.prefKey}_on', false);
      if (mounted) {
        setState(() => _enabled = false);
        _snack('Daily reminder turned off');
      }
      return;
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _min),
      helpText: 'Remind me to measure',
    );
    if (picked == null) return;
    await NotificationService().scheduleDailyNotification(
      id: widget.id,
      title: widget.title,
      body: widget.body,
      hour: picked.hour,
      minute: picked.minute,
    );
    await CleanStorageService.setAppPreference('${widget.prefKey}_on', true);
    await CleanStorageService.setAppPreference('${widget.prefKey}_h', picked.hour);
    await CleanStorageService.setAppPreference('${widget.prefKey}_m', picked.minute);
    if (mounted) {
      setState(() {
        _enabled = true;
        _hour = picked.hour;
        _min = picked.minute;
      });
      _snack('Daily reminder set for ${picked.format(context)}');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: _enabled ? Icons.alarm_on_rounded : Icons.alarm_add_rounded,
      filled: _enabled,
      accent: widget.accent,
      onPressed: _toggle,
    );
  }
}

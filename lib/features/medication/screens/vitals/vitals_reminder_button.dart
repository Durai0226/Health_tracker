import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../services/vitals_reminder_service.dart';

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

  // Build a spec from this button's params so the header button, the Vitals
  // reminder settings screen and the Reminders hub share one source of truth.
  VitalsReminderSpec get _spec => VitalsReminderSpec(
        id: widget.id,
        prefKey: widget.prefKey,
        title: widget.title,
        body: widget.body,
        defaultHour: widget.defaultHour,
      );

  @override
  void initState() {
    super.initState();
    _enabled = VitalsReminderService.isEnabled(_spec);
    final t = VitalsReminderService.timeOf(_spec);
    _hour = t.hour;
    _min = t.minute;
  }

  Future<void> _toggle() async {
    HapticFeedback.selectionClick();
    if (_enabled) {
      await VitalsReminderService.apply(_spec, enabled: false);
      if (mounted) {
        setState(() => _enabled = false);
        _snack('Daily reminder turned off');
      }
      return;
    }
    final picked = await AppTimePicker.show(
      context,
      initial: TimeOfDay(hour: _hour, minute: _min),
      title: 'Remind me to measure',
    );
    if (picked == null) return;
    await VitalsReminderService.apply(_spec,
        enabled: true, hour: picked.hour, minute: picked.minute);
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
      icon: _enabled ? Symbols.alarm_on_rounded : Symbols.alarm_add_rounded,
      filled: _enabled,
      accent: widget.accent,
      onPressed: _toggle,
    );
  }
}

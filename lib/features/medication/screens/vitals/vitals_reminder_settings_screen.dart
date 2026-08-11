import 'dart:io';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/services/health_data_service.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../services/vitals_reminder_service.dart';
import '../../services/vitals_storage_service.dart';

/// A clear, labeled home for the blood-pressure & blood-sugar "time to measure"
/// reminders — the same daily nudges the vitals screens' header button sets,
/// now discoverable from Settings / the Reminders hub. Instant-apply via
/// [VitalsReminderService] (one shared source of truth).
class VitalsReminderSettingsScreen extends StatefulWidget {
  const VitalsReminderSettingsScreen({super.key});

  @override
  State<VitalsReminderSettingsScreen> createState() =>
      _VitalsReminderSettingsScreenState();
}

class _VitalsReminderSettingsScreenState
    extends State<VitalsReminderSettingsScreen> {
  bool _syncEnabled = false;
  bool _syncLoaded = false;
  bool _syncToggleBusy = false;

  @override
  void initState() {
    super.initState();
    _loadSyncPref();
  }

  Future<void> _loadSyncPref() async {
    try {
      var enabled = await VitalsStorageService.isHealthConnectSyncEnabled();
      // Re-validate against the real OS grant, not just the persisted flag —
      // it can drift true if the user revoked access from the OS's own
      // Health Connect/Health app settings since last enabling sync here.
      if (enabled && !await HealthDataService.instance.hasVitalsWritePermission()) {
        enabled = false;
        await VitalsStorageService.setHealthConnectSyncEnabled(false);
      }
      if (mounted) setState(() {
        _syncEnabled = enabled;
        _syncLoaded = true;
      });
    } catch (e) {
      debugPrint('⚠️ Failed to load Health Connect sync preference: $e');
      if (mounted) setState(() => _syncLoaded = true);
    }
  }

  String get _healthAppName => Platform.isIOS ? 'Apple Health' : 'Health Connect';

  Future<void> _toggleSync(bool v) async {
    if (_syncToggleBusy) return;
    setState(() => _syncToggleBusy = true);
    try {
      if (v) {
        await HealthDataService.instance.requestVitalsWritePermission();
        // Re-check real grant state rather than trust requestAuthorization's
        // bool: on iOS it reports success once the consent sheet completed
        // without error, regardless of whether the user actually allowed
        // access — hasVitalsWritePermission queries WRITE status directly,
        // which iOS does disclose (unlike READ/READ_WRITE).
        final granted = await HealthDataService.instance.hasVitalsWritePermission();
        if (!granted) {
          if (mounted) {
            context.toastError(
                'Permission to write to $_healthAppName was not granted.');
          }
          return;
        }
      }
      await VitalsStorageService.setHealthConnectSyncEnabled(v);
      if (mounted) setState(() => _syncEnabled = v);
    } finally {
      if (mounted) setState(() => _syncToggleBusy = false);
    }
  }

  Future<void> _toggle(VitalsReminderSpec s, bool v) async {
    await VitalsReminderService.apply(s, enabled: v);
    if (mounted) setState(() {});
  }

  Future<void> _pickTime(VitalsReminderSpec s, AccentSwatch acc) async {
    final picked = await AppTimePicker.show(
      context,
      initial: VitalsReminderService.timeOf(s),
      accent: acc,
      minuteInterval: 5,
      title: 'Reminder time',
    );
    if (picked != null) {
      await VitalsReminderService.apply(s,
          enabled: true, hour: picked.hour, minute: picked.minute);
      if (mounted) setState(() {});
    }
  }

  List<Widget> _rows(
    VitalsReminderSpec s, {
    required IconData icon,
    required String title,
    required AccentSwatch acc,
  }) {
    final on = VitalsReminderService.isEnabled(s);
    return [
      SettingsTile(
        icon: icon,
        accent: acc,
        title: title,
        subtitle: 'A daily nudge to measure & log a reading',
        switchValue: on,
        onSwitchChanged: (v) => _toggle(s, v),
      ),
      if (on)
        SettingsTile(
          icon: Symbols.schedule_rounded,
          accent: acc,
          title: 'Reminder time',
          value: VitalsReminderService.timeOf(s).format(context),
          onTap: () => _pickTime(s, acc),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final acc = ext.medicine;
    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Vitals reminders',
            accent: acc,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              accent: acc,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, AppSpacing.xl),
              children: [
                SettingsSection(
                  title: 'Measurement reminders',
                  footer:
                      'A gentle daily reminder to take and log a reading, so your trends stay complete. Respects your notification settings.',
                  children: [
                    ..._rows(VitalsReminderService.bp,
                        icon: Symbols.favorite_rounded,
                        title: 'Blood pressure',
                        acc: acc),
                    ..._rows(VitalsReminderService.glucose,
                        icon: Symbols.bloodtype_rounded,
                        title: 'Blood sugar',
                        acc: acc),
                    ..._rows(VitalsReminderService.weight,
                        icon: Symbols.monitor_weight_rounded,
                        title: 'Weight',
                        acc: acc),
                    ..._rows(VitalsReminderService.mood,
                        icon: Symbols.mood_rounded,
                        title: 'Mood',
                        acc: acc),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (_syncLoaded)
                  SettingsSection(
                    title: 'Sync',
                    footer:
                        'New blood pressure, blood sugar and weight readings you log are shared with $_healthAppName. Mood has no equivalent in $_healthAppName, so it never syncs. Off by default; existing readings are not synced retroactively.',
                    children: [
                      SettingsTile(
                        icon: Symbols.sync_rounded,
                        accent: acc,
                        title: 'Share with $_healthAppName',
                        subtitle: 'Sync new vitals readings automatically',
                        switchValue: _syncEnabled,
                        onSwitchChanged: _syncToggleBusy ? null : _toggleSync,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

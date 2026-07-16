import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/widgets/app/app_widgets.dart';
import '../../services/medication_reminder_service.dart';
import '../../../../core/services/clean_storage_service.dart';

/// Real medicine reminder settings: master switch, sound/vibration, and snooze.
/// Persists to SharedPreferences + UserSettings and reschedules all reminders.
class MedicineReminderSettingsScreen extends StatefulWidget {
  const MedicineReminderSettingsScreen({super.key});

  @override
  State<MedicineReminderSettingsScreen> createState() =>
      _MedicineReminderSettingsScreenState();
}

class _MedicineReminderSettingsScreenState
    extends State<MedicineReminderSettingsScreen> {
  static const _snoozeOptions = [5, 10, 15, 30];

  bool _masterEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _snoozeEnabled = true;
  int _snoozeMinutes = 5;
  bool _isLoading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final s = CleanStorageService.getUserSettings();
    if (!mounted) return;
    setState(() {
      _masterEnabled =
          prefs.getBool(MedicationReminderService.masterEnabledKey) ?? true;
      _soundEnabled = s.soundEnabled;
      _vibrationEnabled = s.vibrationEnabled;
      _snoozeEnabled = s.snoozeEnabled;
      _snoozeMinutes = s.snoozeIntervalMinutes;
      _isLoading = false;
    });
  }

  Future<void> _saveAndReschedule() async {
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        MedicationReminderService.masterEnabledKey, _masterEnabled);
    // Keep the background-handler snooze key consistent.
    await prefs.setInt('snooze_interval_minutes', _snoozeMinutes);

    await CleanStorageService.saveUserSettings(
      CleanStorageService.getUserSettings().copyWith(
        soundEnabled: _soundEnabled,
        vibrationEnabled: _vibrationEnabled,
        snoozeEnabled: _snoozeEnabled,
        snoozeIntervalMinutes: _snoozeMinutes,
      ),
    );

    await MedicationReminderService().rescheduleAll();

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder settings saved')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    return AccentScope(
      feature: FeatureAccent.medicine,
      child: AppScaffold(
        body: Column(
          children: [
            AppHeader(
              title: 'Reminder Settings',
              icon: Icons.notifications_active_rounded,
              accent: ext.medicine,
              leading: AppIconButton(
                icon: Icons.arrow_back_rounded,
                filled: false,
                accent: ext.medicine,
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                AppButton(
                  label: 'Save',
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.tonal,
                  accent: ext.medicine,
                  loading: _saving,
                  onPressed: _saving ? null : _saveAndReschedule,
                ),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                          AppSpacing.md, AppSpacing.gutter, 40),
                      children: [
                        SectionHeader(
                          title: 'Reminders',
                          icon: Icons.medication_rounded,
                          accent: ext.medicine,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                          child: _switchRow(
                            icon: Icons.notifications_active_rounded,
                            title: 'Medicine reminders',
                            subtitle: 'Turn all medication reminders on/off',
                            value: _masterEnabled,
                            onChanged: (v) => setState(() => _masterEnabled = v),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        SectionHeader(
                          title: 'Alerts',
                          icon: Icons.volume_up_rounded,
                          accent: ext.medicine,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                          child: Column(
                            children: [
                              _switchRow(
                                icon: Icons.volume_up_rounded,
                                title: 'Sound',
                                subtitle: 'Play a sound with each reminder',
                                value: _soundEnabled,
                                onChanged: _masterEnabled
                                    ? (v) => setState(() => _soundEnabled = v)
                                    : null,
                              ),
                              _divider(ext),
                              _switchRow(
                                icon: Icons.vibration_rounded,
                                title: 'Vibration',
                                subtitle: 'Vibrate the device with each reminder',
                                value: _vibrationEnabled,
                                onChanged: _masterEnabled
                                    ? (v) =>
                                        setState(() => _vibrationEnabled = v)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        SectionHeader(
                          title: 'Snooze',
                          icon: Icons.snooze_rounded,
                          accent: ext.medicine,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppCard(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _switchRow(
                                icon: Icons.snooze_rounded,
                                title: 'Allow snooze',
                                subtitle: 'Show a snooze action on reminders',
                                value: _snoozeEnabled,
                                onChanged: _masterEnabled
                                    ? (v) => setState(() => _snoozeEnabled = v)
                                    : null,
                              ),
                              if (_masterEnabled && _snoozeEnabled) ...[
                                _divider(ext),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Snooze interval',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelLarge
                                      ?.copyWith(color: ext.textSecondary),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.sm,
                                  children: _snoozeOptions.map((m) {
                                    return AppChip(
                                      label: '$m min',
                                      selected: _snoozeMinutes == m,
                                      accent: ext.medicine,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() => _snoozeMinutes = m);
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          label: 'Save',
                          fullWidth: true,
                          accent: ext.medicine,
                          leadingIcon: Icons.check_rounded,
                          loading: _saving,
                          onPressed: _saving ? null : _saveAndReschedule,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(AppColorsExt ext) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Divider(height: 1, color: ext.outline),
      );

  Widget _switchRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final ext = AppColorsExt.of(context);
    final enabled = onChanged != null;
    final s = ext.medicine;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: enabled ? s.container : ext.surfaceVariant,
              borderRadius: AppRadius.brSm,
            ),
            child: Icon(icon,
                size: 20,
                color: enabled ? s.onContainer : ext.textTertiary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: enabled ? ext.textPrimary : ext.textDisabled,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              enabled ? ext.textSecondary : ext.textDisabled,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: ext.fillFg(s),
            activeTrackColor: ext.mark(s),
          ),
        ],
      ),
    );
  }
}

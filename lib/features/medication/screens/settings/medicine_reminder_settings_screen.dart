import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/nunito_theme.dart';
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
  static const _featureColor = Color(0xFF6366F1);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? NunitoTheme.backgroundDark : NunitoTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Reminder Settings',
            style: NunitoTheme.heading2.copyWith(
                color: isDark ? Colors.white : NunitoTheme.textPrimary)),
        iconTheme: IconThemeData(
            color: isDark ? Colors.white : NunitoTheme.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _card(isDark, [
                  SwitchListTile(
                    value: _masterEnabled,
                    activeColor: _featureColor,
                    title: const Text('Medicine reminders'),
                    subtitle: const Text('Turn all medication reminders on/off'),
                    onChanged: (v) => setState(() => _masterEnabled = v),
                  ),
                ]),
                const SizedBox(height: 12),
                _card(isDark, [
                  SwitchListTile(
                    value: _soundEnabled,
                    activeColor: _featureColor,
                    title: const Text('Sound'),
                    onChanged: _masterEnabled
                        ? (v) => setState(() => _soundEnabled = v)
                        : null,
                  ),
                  SwitchListTile(
                    value: _vibrationEnabled,
                    activeColor: _featureColor,
                    title: const Text('Vibration'),
                    onChanged: _masterEnabled
                        ? (v) => setState(() => _vibrationEnabled = v)
                        : null,
                  ),
                ]),
                const SizedBox(height: 12),
                _card(isDark, [
                  SwitchListTile(
                    value: _snoozeEnabled,
                    activeColor: _featureColor,
                    title: const Text('Allow snooze'),
                    subtitle: const Text('Show a snooze action on reminders'),
                    onChanged: _masterEnabled
                        ? (v) => setState(() => _snoozeEnabled = v)
                        : null,
                  ),
                  ListTile(
                    enabled: _masterEnabled && _snoozeEnabled,
                    title: const Text('Snooze interval'),
                    trailing: DropdownButton<int>(
                      value: _snoozeMinutes,
                      items: const [5, 10, 15, 30]
                          .map((m) => DropdownMenuItem(
                              value: m, child: Text('$m min')))
                          .toList(),
                      onChanged: (_masterEnabled && _snoozeEnabled)
                          ? (v) => setState(() => _snoozeMinutes = v ?? 5)
                          : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _featureColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _saving ? null : _saveAndReschedule,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _card(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? NunitoTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

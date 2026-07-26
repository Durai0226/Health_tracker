import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/widgets/app/app_widgets.dart';

/// Water Reminders Settings Screen
class WaterRemindersSettingsScreen extends StatefulWidget {
  const WaterRemindersSettingsScreen({super.key});

  @override
  State<WaterRemindersSettingsScreen> createState() =>
      _WaterRemindersSettingsScreenState();
}

class _WaterRemindersSettingsScreenState
    extends State<WaterRemindersSettingsScreen> {
  bool _remindersEnabled = true;
  int _intervalMinutes = 60;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);
  bool _smartReminders = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _remindersEnabled = prefs.getBool('water_reminders_enabled') ?? true;
        _intervalMinutes = prefs.getInt('water_interval') ?? 60;
        _startTime = _parseTime(prefs.getString('water_start_time')) ??
            const TimeOfDay(hour: 8, minute: 0);
        _endTime = _parseTime(prefs.getString('water_end_time')) ??
            const TimeOfDay(hour: 22, minute: 0);
        _smartReminders = prefs.getBool('water_smart_reminders') ?? true;
        _isLoading = false;
      });
    }
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null) return null;
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> _saveSettings() async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('water_reminders_enabled', _remindersEnabled);
    await prefs.setInt('water_interval', _intervalMinutes);
    await prefs.setString(
        'water_start_time', '${_startTime.hour}:${_startTime.minute}');
    await prefs.setString(
        'water_end_time', '${_endTime.hour}:${_endTime.minute}');
    await prefs.setBool('water_smart_reminders', _smartReminders);

    if (mounted) {
      context.toastSuccess('Reminders saved!');
      Navigator.pop(context);
    }
  }

  Future<void> _selectTime(
      TimeOfDay current, ValueChanged<TimeOfDay> onChanged) async {
    final picked = await AppTimePicker.show(context, initial: current);
    if (picked != null) {
      HapticFeedback.lightImpact();
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final water = ext.water;

    return AppScaffold(
      safeTop: true,
      body: Column(
        children: [
          AppHeader(
            title: 'Reminders',
            icon: Symbols.notifications_active_rounded,
            accent: water,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              accent: water,
              filled: false,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: ext.mark(water)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.gutter,
                        AppSpacing.sm, AppSpacing.gutter, AppSpacing.huge),
                    child: Column(
                      children: [
                        _buildMainToggle(ext, water),
                        if (_remindersEnabled) ...[
                          const SizedBox(height: AppSpacing.lg),
                          _buildIntervalCard(ext, water),
                          const SizedBox(height: AppSpacing.lg),
                          _buildTimeRangeCard(ext, water),
                          const SizedBox(height: AppSpacing.lg),
                          _buildSmartRemindersCard(ext, water),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          label: 'Save Reminders',
                          accent: water,
                          size: AppButtonSize.lg,
                          fullWidth: true,
                          leadingIcon: Symbols.check_rounded,
                          onPressed: _saveSettings,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required AppColorsExt ext,
    required AccentSwatch water,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: value ? water.container : ext.surfaceVariant,
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(icon,
                color: value ? water.onContainer : ext.textTertiary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: tt.titleMedium?.copyWith(color: ext.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
              ],
            ),
          ),
          AppSwitch(
            value: value,
            onChanged: (v) {
              HapticFeedback.lightImpact();
              onChanged(v);
            },
            accent: water,
          ),
        ],
      ),
    );
  }

  Widget _buildMainToggle(AppColorsExt ext, AccentSwatch water) {
    return _buildToggleRow(
      ext: ext,
      water: water,
      icon: Symbols.notifications_rounded,
      title: 'Drink Reminders',
      subtitle: 'Get notified to stay hydrated',
      value: _remindersEnabled,
      onChanged: (v) => setState(() => _remindersEnabled = v),
    );
  }

  Widget _buildIntervalCard(AppColorsExt ext, AccentSwatch water) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Reminder Interval',
            icon: Symbols.timer_rounded,
            accent: water,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Every $_intervalMinutes minutes',
              style: tt.titleMedium?.copyWith(
                color: ext.mark(water),
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: AppSpacing.sm),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: ext.mark(water),
              inactiveTrackColor: ext.surfaceVariant,
              thumbColor: ext.mark(water),
              overlayColor: water.base.withOpacity(0.15),
            ),
            child: Slider(
              value: _intervalMinutes.toDouble(),
              min: 15,
              max: 180,
              divisions: 11,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _intervalMinutes = v.round());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeCard(AppColorsExt ext, AccentSwatch water) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Active Hours',
            icon: Symbols.schedule_rounded,
            accent: water,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                  child: _buildTimeButton(ext, water, 'Start', _startTime,
                      (t) => setState(() => _startTime = t))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text('to',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: ext.textSecondary)),
              ),
              Expanded(
                  child: _buildTimeButton(ext, water, 'End', _endTime,
                      (t) => setState(() => _endTime = t))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeButton(AppColorsExt ext, AccentSwatch water, String label,
      TimeOfDay time, ValueChanged<TimeOfDay> onChanged) {
    final tt = Theme.of(context).textTheme;
    return Material(
      color: water.container,
      borderRadius: AppRadius.brMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _selectTime(time, onChanged),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            children: [
              Text(label,
                  style: tt.bodySmall?.copyWith(color: water.onContainer)),
              const SizedBox(height: 4),
              Text(time.format(context),
                  style: tt.titleMedium?.copyWith(
                    color: water.onContainer,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmartRemindersCard(AppColorsExt ext, AccentSwatch water) {
    return _buildToggleRow(
      ext: ext,
      water: water,
      icon: Symbols.auto_awesome_rounded,
      title: 'Smart Reminders',
      subtitle: 'Adjust based on your activity',
      value: _smartReminders,
      onChanged: (v) => setState(() => _smartReminders = v),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../services/step_service.dart';

/// Goal + body-profile settings: choose an adaptive or a fixed custom goal, see
/// exactly why the adaptive goal is what it is, and provide weight/height so
/// distance and calorie estimates are personalised.
class StepsGoalSettingsScreen extends StatefulWidget {
  const StepsGoalSettingsScreen({super.key});

  @override
  State<StepsGoalSettingsScreen> createState() =>
      _StepsGoalSettingsScreenState();
}

class _StepsGoalSettingsScreenState extends State<StepsGoalSettingsScreen> {
  late bool _useCustom;
  late int _customGoal;
  late bool _reminderEnabled;
  late int _reminderMinute;
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = StepService.getProfile();
    _useCustom = p.useCustomStepGoal;
    _customGoal = p.customStepGoal ?? 8000;
    _reminderEnabled = StepService.getReminderEnabled();
    _reminderMinute = StepService.getReminderMinuteOfDay();
    if (p.weightKg != null) {
      _weightController.text =
          p.weightKg! % 1 == 0 ? p.weightKg!.toInt().toString() : p.weightKg!.toString();
    }
    if (p.heightCm != null) _heightController.text = p.heightCm!.toString();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  int _previewGoal() {
    if (_useCustom) return _customGoal;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final samples = <int>[];
    for (int i = 1; i <= 14; i++) {
      final d = StepService.getDataForDate(today.subtract(Duration(days: i)));
      if (d != null && d.effectiveSteps > 0) samples.add(d.effectiveSteps);
    }
    if (samples.length < 3) return 8000;
    samples.sort();
    final mid = samples.length ~/ 2;
    final median = samples.length.isOdd
        ? samples[mid]
        : ((samples[mid - 1] + samples[mid]) / 2).round();
    final nudged = (median * 1.1).round();
    if (nudged < 4000) return 4000;
    if (nudged > 15000) return 15000;
    return nudged;
  }

  String _explanation() {
    if (_useCustom) {
      return 'Your goal is fixed at ${_fmt(_customGoal)} steps until you switch '
          'back to Adaptive.';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var tracked = 0;
    for (int i = 1; i <= 14; i++) {
      final d = StepService.getDataForDate(today.subtract(Duration(days: i)));
      if (d != null && d.effectiveSteps > 0) tracked++;
    }
    if (tracked < 3) {
      return 'Starting at 8,000 steps while we learn your routine. Log a few '
          'days and your goal adapts automatically.';
    }
    return 'Adapted from your last-14-day median, nudged up ~10% to keep you '
        'progressing — kept within 4,000–15,000. It shifts as your routine does.';
  }

  void _bumpCustom(int delta) {
    HapticFeedback.selectionClick();
    setState(() => _customGoal = (_customGoal + delta).clamp(1000, 30000));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final base = StepService.getProfile();
    final wText = _weightController.text.trim();
    final hText = _heightController.text.trim();
    final updated = base.copyWith(
      useCustomStepGoal: _useCustom,
      customStepGoal: _customGoal,
      weightKg: double.tryParse(wText),
      clearWeight: wText.isEmpty,
      heightCm: int.tryParse(hText),
      clearHeight: hText.isEmpty,
    );
    await StepService.saveProfile(updated);
    if (mounted) Navigator.of(context).pop();
  }

  /// Reminder settings persist immediately (independent of the profile save on
  /// pop) and reschedule the gentle evening nudge right away.
  void _updateReminder(bool enabled, int minute) {
    setState(() {
      _reminderEnabled = enabled;
      _reminderMinute = minute;
    });
    StepService.setReminder(enabled, minute);
    NotificationService().scheduleStepReminder(
      enabled: enabled,
      minuteOfDay: minute,
    );
  }

  Future<void> _pickReminderTime() async {
    final picked = await AppTimePicker.show(
      context,
      initial:
          TimeOfDay(hour: _reminderMinute ~/ 60, minute: _reminderMinute % 60),
    );
    if (picked != null) {
      _updateReminder(_reminderEnabled, picked.hour * 60 + picked.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccentScope(
      feature: FeatureAccent.steps,
      child: Builder(builder: _build),
    );
  }

  Widget _build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final s = ext.steps;
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Goal & profile',
            icon: Symbols.tune_rounded,
            leading: AppIconButton(
              icon: Symbols.arrow_back_rounded,
              filled: false,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 120),
              children: [
                SegmentedToggle(
                  accent: s,
                  index: _useCustom ? 1 : 0,
                  onChanged: (i) => setState(() => _useCustom = i == 1),
                  items: const [
                    SegmentItem(
                        icon: Symbols.auto_graph_rounded, label: 'Adaptive'),
                    SegmentItem(icon: Symbols.tune_rounded, label: 'Custom'),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Goal preview + explainer.
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Symbols.flag_rounded,
                              size: 18, color: ext.mark(s)),
                          const SizedBox(width: 8),
                          Text("Today's goal", style: tt.titleLarge),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '${_fmt(_previewGoal())} steps',
                        style: tt.displaySmall?.copyWith(
                          color: ext.mark(s),
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _explanation(),
                        style: tt.bodyMedium
                            ?.copyWith(color: ext.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),

                // Custom stepper.
                if (_useCustom) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Custom goal', style: tt.titleLarge),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppIconButton(
                              icon: Symbols.remove_rounded,
                              accent: s,
                              tooltip: 'Less',
                              onPressed: () => _bumpCustom(-500),
                            ),
                            Text(
                              _fmt(_customGoal),
                              style: tt.displaySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            AppIconButton(
                              icon: Symbols.add_rounded,
                              accent: s,
                              tooltip: 'More',
                              onPressed: () => _bumpCustom(500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),
                SectionHeader(
                  title: 'Body profile',
                  icon: Symbols.accessibility_new_rounded,
                  accent: s,
                ),
                AppCard(
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _weightController,
                        label: 'Weight (kg)',
                        hint: 'e.g. 70',
                        accent: s,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _heightController,
                        label: 'Height (cm)',
                        hint: 'e.g. 172',
                        accent: s,
                        keyboardType: TextInputType.number,
                        helperText:
                            'Used to estimate distance and active calories.',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                SectionHeader(
                  title: 'Reminder',
                  icon: Symbols.notifications_active_rounded,
                  accent: s,
                ),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      AppListTile(
                        icon: Symbols.notifications_active_rounded,
                        title: 'Daily step reminder',
                        subtitle: 'A gentle evening nudge to move',
                        accent: s,
                        trailing: AppSwitch(
                          value: _reminderEnabled,
                          onChanged: (v) =>
                              _updateReminder(v, _reminderMinute),
                          accent: s,
                        ),
                      ),
                      if (_reminderEnabled) ...[
                        Divider(height: 1, color: ext.outline),
                        AppListTile(
                          icon: Symbols.schedule_rounded,
                          title: 'Time',
                          accent: s,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                TimeOfDay(
                                        hour: _reminderMinute ~/ 60,
                                        minute: _reminderMinute % 60)
                                    .format(context),
                                style: tt.titleMedium
                                    ?.copyWith(color: ext.mark(s)),
                              ),
                              const SizedBox(width: 4),
                              Icon(Symbols.chevron_right_rounded,
                                  color: ext.textTertiary),
                            ],
                          ),
                          onTap: _pickReminderTime,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Save',
                  accent: s,
                  fullWidth: true,
                  loading: _saving,
                  leadingIcon: Symbols.check_rounded,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) {
    final str = n.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return '${n < 0 ? '-' : ''}$buf';
  }
}

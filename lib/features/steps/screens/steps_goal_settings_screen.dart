import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import '../models/health_profile.dart';
import '../services/step_service.dart';
import '../utils/step_format.dart';
import 'package:permission_handler/permission_handler.dart';

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
  String? _weightError;
  String? _heightError;
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

  /// The goal shown while editing. The adaptive half comes from the service,
  /// not a copy of its formula: this screen used to carry its own, which would
  /// have drifted the moment the real one learned about weekdays.
  int _previewGoal() =>
      _useCustom ? _customGoal : StepService.adaptiveGoalResult().goal;

  String _explanation() {
    if (_useCustom) {
      return 'Your goal is fixed at ${formatThousands(_customGoal)} steps until you switch '
          'back to Adaptive.';
    }
    return StepService.goalExplanation();
  }

  void _bumpCustom(int delta) {
    HapticFeedback.selectionClick();
    setState(() => _customGoal = (_customGoal + delta).clamp(1000, 30000));
  }

  Future<void> _save() async {
    if (_saving) return;
    final wText = _weightController.text.trim();
    final hText = _heightController.text.trim();

    // Validated BEFORE `_saving` flips, so a rejected save leaves the button
    // usable instead of spinning. These values are not decoration: height
    // becomes every distance the app reports and weight becomes every calorie
    // figure, so a stray `-5` would be shown back to the user as a confident
    // health number rather than as the typo it is.
    final wError = HealthProfile.validateWeightText(wText);
    final hError = HealthProfile.validateHeightText(hText);
    if (wError != null || hError != null) {
      setState(() {
        _weightError = wError;
        _heightError = hError;
      });
      return;
    }

    setState(() => _saving = true);
    final base = StepService.getProfile();
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
  Future<void> _updateReminder(bool enabled, int minute) async {
    setState(() {
      _reminderEnabled = enabled;
      _reminderMinute = minute;
    });
    StepService.setReminder(enabled, minute);

    // Believe the answer. `scheduleStepReminder` used to return void and bail
    // on a permission refusal with only a debugPrint, so the switch stayed ON
    // and the subtitle named a time for a nudge that was never scheduled.
    final armed = await NotificationService().scheduleStepReminder(
      enabled: enabled,
      minuteOfDay: minute,
    );
    // Being told "not armed" for a reminder just switched OFF is the expected
    // answer, not a failure.
    if (!enabled || armed) return;

    if (!mounted) return;
    setState(() => _reminderEnabled = false);
    StepService.setReminder(false, minute);
    context.toastWarning(
      'Notifications are off, so the step reminder could not be set.',
      action: AppToastAction(
        label: 'Open settings',
        onPressed: () => openAppSettings(),
      ),
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
            leading: AppHeader.backButton(context),
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
                        '${formatThousands(_previewGoal())} steps',
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
                              formatThousands(_customGoal),
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
                        errorText: _weightError,
                        // Cleared on edit rather than re-validated on every
                        // keystroke: typing "70" passes through "7", and an
                        // error that flashes while you type reads as the app
                        // arguing with you.
                        onChanged: _weightError == null
                            ? null
                            : (_) => setState(() => _weightError = null),
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
                        errorText: _heightError,
                        onChanged: _heightError == null
                            ? null
                            : (_) => setState(() => _heightError = null),
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
                        switchValue: _reminderEnabled,
                        onSwitchChanged: (v) =>
                            _updateReminder(v, _reminderMinute),
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
}

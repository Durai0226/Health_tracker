import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/auth_gate_sheet.dart';
import '../../water/services/water_service.dart';
import '../../home/screens/app_shell.dart';

/// Calm Clarity onboarding: a short, modern multi-pane flow.
///   1. Value / brand snapshot of the four features.
///   2. Quick setup — daily water goal + preferred reminder time.
///   3. Contextual "turn on reminders" opt-in (the only place notification
///      permission is ever requested from the UI).
/// Entrance-only motion, fully dark-aware, no hardcoded colors.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const int _paneCount = 3;
  static const int _minGoal = 500;
  static const int _maxGoal = 5000;
  static const int _goalStep = 250;

  final PageController _pager = PageController();
  int _page = 0;

  late int _waterGoal;
  late TimeOfDay _reminderTime;
  bool _requesting = false;
  bool _finishing = false;

  late final AnimationController _enter = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  );
  late final Animation<double> _fade = CurvedAnimation(
      parent: _enter, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
  late final Animation<double> _slide = Tween<double>(begin: 28, end: 0).animate(
      CurvedAnimation(
          parent: _enter,
          curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic)));

  @override
  void initState() {
    super.initState();

    // Seed the water goal from the existing profile (WATER-1 wiring), snapped
    // to the stepper increment and clamped to a sane range.
    final seeded = WaterService.getDailyGoal();
    final base = (seeded <= 0 ? 2500 : seeded).clamp(_minGoal, _maxGoal);
    _waterGoal = ((base / _goalStep).round() * _goalStep).clamp(_minGoal, _maxGoal);

    // Seed the preferred reminder time from any prior (resumable) choice.
    final h = CleanStorageService.getAppPreference('preferredReminderHour', 9);
    final m = CleanStorageService.getAppPreference('preferredReminderMinute', 0);
    _reminderTime =
        TimeOfDay(hour: h is int ? h : 9, minute: m is int ? m : 0);

    _enter.forward();
  }

  @override
  void dispose() {
    _pager.dispose();
    _enter.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------- navigation
  void _goToPage(int i) {
    HapticFeedback.selectionClick();
    _pager.animateToPage(i,
        duration: AppMotion.base, curve: AppMotion.emphasized);
  }

  Future<void> _next() async {
    if (_page == 1) await _saveSetup();
    if (_page < _paneCount - 1) _goToPage(_page + 1);
  }

  /// Persist the quick-setup choices via existing service methods.
  Future<void> _saveSetup() async {
    // Water goal → hydration profile custom goal (persisted by WaterService).
    final profile = WaterService.getProfile();
    await WaterService.saveProfile(
      profile.copyWith(customGoalMl: _waterGoal, useCustomGoal: true),
    );
    // Preferred reminder time → app preferences (JSON-safe, resumable).
    await CleanStorageService.setAppPreference(
        'preferredReminderHour', _reminderTime.hour);
    await CleanStorageService.setAppPreference(
        'preferredReminderMinute', _reminderTime.minute);
  }

  /// The only UI path that requests notification permission. Calls the existing
  /// NotificationService public method (do NOT edit that service).
  Future<void> _enableReminders() async {
    HapticFeedback.mediumImpact();
    setState(() => _requesting = true);
    try {
      await NotificationService().requestPermissionsIfNeeded();
    } catch (_) {
      // Non-fatal: user can still grant via system settings later.
    }
    if (mounted) setState(() => _requesting = false);
    await _finish();
  }

  /// Original entry behavior: auth gate → mark onboarding complete → AppShell.
  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    HapticFeedback.mediumImpact();
    final auth = AuthService();
    if (!auth.isAuthenticated) {
      final proceed = await AuthGateSheet.show(
        context: context,
        featureName: 'DailyMinder',
        featureColor: AppColorsExt.of(context).brand.base,
        featureIcon: Icons.event_available_rounded,
      );
      if (proceed != true) {
        _finishing = false;
        return;
      }
    }
    // Mark onboarding complete so returning users land straight on Home.
    await CleanStorageService.setFirstLaunchComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: AppMotion.slow,
        pageBuilder: (_, __, ___) => const AppShell(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  // ------------------------------------------------------------- setup actions
  void _adjustGoal(int delta) {
    final next = (_waterGoal + delta).clamp(_minGoal, _maxGoal);
    if (next == _waterGoal) return;
    HapticFeedback.selectionClick();
    setState(() => _waterGoal = next);
  }

  void _setGoal(int value) {
    if (value == _waterGoal) return;
    HapticFeedback.selectionClick();
    setState(() => _waterGoal = value.clamp(_minGoal, _maxGoal));
  }

  Future<void> _pickTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked != null && mounted) setState(() => _reminderTime = picked);
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  // --------------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: AnimatedBuilder(
            animation: _slide,
            builder: (context, child) =>
                Transform.translate(offset: Offset(0, _slide.value), child: child),
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pager,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      _brandPane(ext, tt),
                      _setupPane(ext, tt),
                      _remindersPane(ext, tt),
                    ],
                  ),
                ),
                _dots(ext),
                const SizedBox(height: AppSpacing.lg),
                _bottomBar(ext, tt),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- pane one
  Widget _brandPane(AppColorsExt ext, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        children: [
          const Spacer(flex: 3),
          Column(
            children: [
              const AppLogo.raster(size: 132, radius: 8),
              const SizedBox(height: AppSpacing.lg),
              Text('DailyMinder', style: tt.displayMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Medicine, water, focus & reminders —\nyour day, gently in order.',
                textAlign: TextAlign.center,
                style: tt.bodyLarge?.copyWith(color: ext.textSecondary, height: 1.4),
              ),
            ],
          ),
          const Spacer(flex: 2),
          _featureRow(ext, tt),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _featureRow(AppColorsExt ext, TextTheme tt) {
    final features = <(IconData, String, AccentSwatch)>[
      (Icons.medication_rounded, 'Medicine', ext.medicine),
      (Icons.water_drop_rounded, 'Water', ext.water),
      (Icons.self_improvement_rounded, 'Focus', ext.focus),
      (Icons.notifications_rounded, 'Reminders', ext.reminders),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (icon, label, s) in features)
          Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: s.container,
                  borderRadius: AppRadius.brLg,
                ),
                child: Icon(icon, color: s.onContainer, size: 26),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(label, style: tt.labelMedium?.copyWith(color: ext.textSecondary)),
            ],
          ),
      ],
    );
  }

  // ----------------------------------------------------------------- pane two
  Widget _setupPane(AppColorsExt ext, TextTheme tt) {
    final ringProgress = (_waterGoal / _maxGoal).clamp(0.0, 1.0);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl, vertical: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Quick setup', style: tt.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Two gentle defaults you can change anytime.',
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ---- Daily water goal ----
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.water_drop_rounded, color: ext.mark(ext.water), size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Daily water goal', style: tt.titleMedium),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppIconButton(
                      icon: Icons.remove_rounded,
                      accent: ext.water,
                      onPressed:
                          _waterGoal > _minGoal ? () => _adjustGoal(-_goalStep) : null,
                    ),
                    ProgressRing(
                      progress: ringProgress,
                      size: 116,
                      stroke: 9,
                      accent: ext.water,
                      center: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${(_waterGoal / 1000).toStringAsFixed(_waterGoal % 1000 == 0 ? 0 : 1)}',
                              style: tt.displaySmall),
                          Text('litres',
                              style: tt.labelMedium
                                  ?.copyWith(color: ext.textTertiary)),
                        ],
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.add_rounded,
                      accent: ext.water,
                      onPressed:
                          _waterGoal < _maxGoal ? () => _adjustGoal(_goalStep) : null,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text('$_waterGoal ml per day',
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final preset in const [2000, 2500, 3000]) ...[
                      AppChip(
                        label: '${(preset / 1000).toStringAsFixed(preset % 1000 == 0 ? 0 : 1)} L',
                        selected: _waterGoal == preset,
                        accent: ext.water,
                        onTap: () => _setGoal(preset),
                      ),
                      if (preset != 3000) const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ---- Preferred reminder time ----
          AppCard(
            onTap: _pickTime,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ext.reminders.container,
                    borderRadius: AppRadius.brMd,
                  ),
                  child: Icon(Icons.schedule_rounded,
                      color: ext.reminders.onContainer, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Preferred reminder time', style: tt.titleMedium),
                      const SizedBox(height: 2),
                      Text('When your day-check nudges arrive',
                          style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(_formatTime(_reminderTime),
                    style: tt.titleMedium?.copyWith(color: ext.mark(ext.reminders))),
                Icon(Icons.chevron_right_rounded, color: ext.textTertiary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- pane three
  Widget _remindersPane(AppColorsExt ext, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: ext.reminders.container,
              borderRadius: AppRadius.brLg,
            ),
            child: Icon(Icons.notifications_active_rounded,
                color: ext.reminders.onContainer, size: 44),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Turn on reminders', style: tt.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Get gentle nudges for your medicine, water and to-dos — right on time, never noisy. You are always in control and can turn them off anytime.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: ext.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- shared chrome
  Widget _dots(AppColorsExt ext) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < _paneCount; i++)
          AnimatedContainer(
            duration: AppMotion.base,
            curve: AppMotion.standard,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == _page ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == _page ? ext.mark(ext.brand) : ext.outline,
              borderRadius: AppRadius.brFull,
            ),
          ),
      ],
    );
  }

  Widget _bottomBar(AppColorsExt ext, TextTheme tt) {
    final isLast = _page == _paneCount - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        children: [
          if (isLast) ...[
            AppButton(
              label: 'Turn on reminders',
              leadingIcon: Icons.notifications_active_rounded,
              fullWidth: true,
              size: AppButtonSize.lg,
              accent: ext.reminders,
              loading: _requesting,
              onPressed: _requesting ? null : _enableReminders,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Skip for now',
              fullWidth: true,
              variant: AppButtonVariant.ghost,
              accent: ext.reminders,
              onPressed: _requesting ? null : _finish,
            ),
          ] else ...[
            AppButton(
              label: 'Continue',
              trailingIcon: Icons.arrow_forward_rounded,
              fullWidth: true,
              size: AppButtonSize.lg,
              accent: _page == 1 ? ext.water : ext.brand,
              onPressed: _next,
            ),
            if (_page == 0) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Private by default · no account required',
                style: tt.bodySmall?.copyWith(color: ext.textTertiary),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

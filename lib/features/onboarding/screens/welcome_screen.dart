import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/auth_gate_sheet.dart';
import '../../water/services/water_service.dart';
import '../../home/screens/app_shell.dart';

/// Onboarding — medication-first, low-friction, premium.
///   1. Hero — brand + the core promise ("never miss a dose"), private by default.
///   2. How it helps — three benefit-first rows (dose · one place · private).
///   3. Reminders opt-in — the ONLY place notification permission is requested.
///
/// Deliberately no goal/time config here (friction before value); sensible
/// defaults are seeded and fully editable later. A soft brand-glow backdrop +
/// entrance motion; dark-aware, no hardcoded colors.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const int _paneCount = 3;

  final PageController _pager = PageController();
  int _page = 0;

  // Seeded, sensible defaults — persisted on finish, editable anytime in-app.
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
    final seeded = WaterService.getDailyGoal();
    _waterGoal = (seeded <= 0 ? 2500 : seeded).clamp(500, 5000);
    final h = CleanStorageService.getAppPreference('preferredReminderHour', 9);
    final m = CleanStorageService.getAppPreference('preferredReminderMinute', 0);
    _reminderTime = TimeOfDay(hour: h is int ? h : 9, minute: m is int ? m : 0);
    _enter.forward();
  }

  @override
  void dispose() {
    _pager.dispose();
    _enter.dispose();
    super.dispose();
  }

  void _goToPage(int i) {
    HapticFeedback.selectionClick();
    _pager.animateToPage(i,
        duration: AppMotion.base, curve: AppMotion.emphasized);
  }

  void _next() {
    if (_page < _paneCount - 1) _goToPage(_page + 1);
  }

  Future<void> _saveSetup() async {
    final profile = WaterService.getProfile();
    await WaterService.saveProfile(
      profile.copyWith(customGoalMl: _waterGoal, useCustomGoal: true),
    );
    await CleanStorageService.setAppPreference(
        'preferredReminderHour', _reminderTime.hour);
    await CleanStorageService.setAppPreference(
        'preferredReminderMinute', _reminderTime.minute);
  }

  /// The only UI path that requests notification permission.
  Future<void> _enableReminders() async {
    HapticFeedback.mediumImpact();
    setState(() => _requesting = true);
    try {
      await NotificationService().requestPermissionsIfNeeded();
      await NotificationService().scheduleDailyNotification(
        id: 900001,
        title: 'Daily check-in',
        body: 'A gentle nudge for your medicine, water and to-dos.',
        hour: _reminderTime.hour,
        minute: _reminderTime.minute,
      );
    } catch (_) {
      // Non-fatal: user can still grant via system settings later.
    }
    if (mounted) setState(() => _requesting = false);
    await _finish();
  }

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
        featureIcon: Symbols.event_available_rounded,
      );
      if (proceed != true) {
        _finishing = false;
        return;
      }
    }
    await _saveSetup();
    await CleanStorageService.setFirstLaunchComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: AppMotion.slow,
        // Land a brand-new user on the Meds tab — its empty state guides them
        // straight to "Add your first medicine", so the "never miss a dose"
        // promise has an immediate next step instead of an empty Today.
        pageBuilder: (_, __, ___) => const AppShell(initialIndex: 1),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  // --------------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    return AppScaffold(
      body: Stack(
        children: [
          // Calm top-down brand wash (a clean gradient, not an amorphous blob).
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ext.brand.base.withOpacity(ext.isDark ? 0.18 : 0.10),
                    ext.background,
                    ext.background,
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: AnimatedBuilder(
                animation: _slide,
                builder: (context, child) => Transform.translate(
                    offset: Offset(0, _slide.value), child: child),
                child: Column(
                  children: [
                    Expanded(
                      child: PageView(
                        controller: _pager,
                        onPageChanged: (i) => setState(() => _page = i),
                        children: [
                          _heroPane(ext, tt),
                          _valuePane(ext, tt),
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
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ pane one
  Widget _heroPane(AppColorsExt ext, TextTheme tt) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: IntrinsicHeight(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  // The real app icon, on a soft brand halo with a lifted shadow.
                  SizedBox(
                    width: 168,
                    height: 168,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                ext.brand.base
                                    .withOpacity(ext.isDark ? 0.32 : 0.22),
                                ext.brand.base.withOpacity(0),
                              ],
                              stops: const [0.35, 1.0],
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: ext.brand.base
                                    .withOpacity(ext.isDark ? 0.38 : 0.26),
                                blurRadius: 34,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: const AppLogo.raster(size: 100, radius: 26),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('DAILYMINDER',
                      style: tt.labelMedium?.copyWith(
                          color: ext.mark(ext.brand),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.2)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Never miss a\ndose again.',
                    textAlign: TextAlign.center,
                    style: tt.displaySmall?.copyWith(
                        color: ext.textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.08),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Your medicines, vitals and daily health — '
                    'gently in order, and completely private.',
                    textAlign: TextAlign.center,
                    style: tt.bodyLarge
                        ?.copyWith(color: ext.textSecondary, height: 1.45),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Signature preview — SHOW the core moment (1-tap "Take").
                  _dosePeek(ext, tt),
                  const SizedBox(height: AppSpacing.lg),
                  _trustChip(ext, tt),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A tiny, elegant preview of the app's signature moment — the next dose with
  /// a one-tap "Take" — so the welcome shows what DailyMinder does, not just
  /// tells. Illustrative sample content.
  Widget _dosePeek(AppColorsExt ext, TextTheme tt) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: AppRadius.brLg,
        border: Border.all(color: ext.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(ext.isDark ? 0.30 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: ext.brand.container, borderRadius: AppRadius.brMd),
            child: Icon(Symbols.medication_rounded,
                color: ext.brand.onContainer, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Up next · 8:00 AM',
                    style: tt.labelSmall?.copyWith(
                        color: ext.mark(ext.brand),
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Metformin · 500 mg',
                    style: tt.titleSmall?.copyWith(
                        color: ext.textPrimary, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: ext.brand.base, borderRadius: AppRadius.brFull),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Symbols.check_rounded, size: 15, color: ext.brand.on),
                const SizedBox(width: 4),
                Text('Take',
                    style: tt.labelMedium?.copyWith(
                        color: ext.brand.on, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trustChip(AppColorsExt ext, TextTheme tt) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: ext.success.container,
        borderRadius: AppRadius.brFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.lock_rounded, size: 15, color: ext.success.onContainer),
          const SizedBox(width: 6),
          Text('Private · on-device · no account',
              style: tt.labelMedium?.copyWith(
                  color: ext.success.onContainer,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ pane two
  Widget _valuePane(AppColorsExt ext, TextTheme tt) {
    final benefits = <(IconData, AccentSwatch, String, String)>[
      (
        Symbols.medication_rounded,
        ext.medicine,
        'Never miss a dose',
        'Smart reminders with a full-screen alarm that\'s hard to ignore — take, skip or snooze in one tap.'
      ),
      (
        Symbols.favorite_rounded,
        ext.water,
        'All your health, one place',
        'Water, sleep, steps, blood pressure, glucose and your cycle — one calm daily view.'
      ),
      (
        Symbols.shield_rounded,
        ext.success,
        'Private by design',
        'Your health data stays on your phone. No account, works offline.'
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xxl,
                AppSpacing.xxl, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('How DailyMinder helps',
                    style: tt.headlineSmall
                        ?.copyWith(color: ext.textPrimary)),
                const SizedBox(height: AppSpacing.xl),
                for (final (icon, s, title, body) in benefits) ...[
                  _benefitRow(ext, tt, icon, s, title, body),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _benefitRow(AppColorsExt ext, TextTheme tt, IconData icon,
      AccentSwatch s, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration:
              BoxDecoration(color: s.container, borderRadius: AppRadius.brMd),
          child: Icon(icon, color: s.onContainer, size: 24),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: tt.titleMedium?.copyWith(
                      color: ext.textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(body,
                  style: tt.bodyMedium
                      ?.copyWith(color: ext.textSecondary, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- pane three
  Widget _remindersPane(AppColorsExt ext, TextTheme tt) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: ext.reminders.container,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Symbols.notifications_active_rounded,
                      color: ext.reminders.onContainer, size: 44),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Turn on reminders',
                    style: tt.headlineSmall?.copyWith(color: ext.textPrimary),
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Gentle nudges for your medicine, water and to-dos — right on '
                  'time, never noisy. You are always in control and can turn '
                  'them off anytime.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium
                      ?.copyWith(color: ext.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ),
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
              leadingIcon: Symbols.notifications_active_rounded,
              fullWidth: true,
              size: AppButtonSize.lg,
              accent: ext.reminders,
              emphasized: true,
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
              label: _page == 0 ? 'Get started' : 'Continue',
              trailingIcon: Symbols.arrow_forward_rounded,
              fullWidth: true,
              size: AppButtonSize.lg,
              accent: ext.brand,
              emphasized: true,
              onPressed: _next,
            ),
          ],
        ],
      ),
    );
  }
}

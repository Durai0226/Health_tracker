import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/services/daily_check_in.dart';
import '../../../core/services/health_data_service.dart';
import '../../../core/services/health_store_name.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/auth_gate_sheet.dart';
import '../../biometrics/services/biometrics_service.dart';
import '../../home/screens/app_shell.dart';
import '../../sleep/services/sleep_service.dart';
import '../../steps/services/step_service.dart';
import '../services/welcome_goals.dart';
import '../../../core/constants/app_strings.dart';

/// Onboarding — medication-first, low-friction, premium.
///   1. Hero — brand + the core promise ("never miss a dose"), private by default.
///   2. How it helps — three benefit-first rows (dose · one place · private).
///   3. What to start with — up to three of medicines, water, steps, sleep, focus,
///      reminders; skippable.
///   4. Health app — only where there is one to connect: an optional offer to
///      fill Today from the phone's health app, skippable and never forced.
///   5. Reminders opt-in — the ONLY place notification permission is requested.
///      The daily check-in time is on the pane, one tap to change.
///
/// There is a pane asking what to keep on top of (up to three, none is fine), but
/// it asks for no goal CONFIG: it only moves those cards up on Today and picks the
/// tab to open on — no figure is set and nothing is hidden or switched on.
/// Sensible defaults are seeded and fully editable later. A soft brand-glow backdrop +
/// entrance motion; dark-aware, no hardcoded colors.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    this.connectHealth,
    this.healthAvailability,
    this.importHealth,
  });

  /// Brings the health app's steps and sleep in once the person has connected it, so
  /// Today and Trends have numbers on the first day. Defaults to the three services'
  /// own syncs; a test hands its own.
  final Future<void> Function()? importHealth;

  /// Asks for the health app's permissions. Defaults to
  /// `HealthDataService.requestPermissions`; a test hands its own, because the
  /// platform plugin cannot run headless.
  final Future<bool> Function()? connectHealth;

  /// Whether there is a health app to offer. Defaults to
  /// `HealthDataService.availability`.
  final Future<HealthAvailability> Function()? healthAvailability;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  /// Four panes, and a fifth — the health app — only where there is one.
  int get _paneCount => _showHealth ? 5 : 4;

  /// Where the health pane sits: after what to start with, before the reminders.
  static const int _healthPaneIndex = 3;

  /// What the person asked to keep on top of, in the order they picked.
  List<WelcomeGoal> _picks = const [];

  final PageController _pager = PageController();
  int _page = 0;

  // The health pane: shown only when there is something to connect, and never a
  // gate. [_healthConnected] and [_healthDeclined] are what the pane says back.
  bool _showHealth = false;
  bool _connecting = false;
  bool _healthConnected = false;
  bool _healthDeclined = false;

  // Seeded, sensible default — persisted on finish, editable anytime in-app.
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
    _reminderTime = DailyCheckIn.time;
    _enter.forward();
    _probeHealth();
  }

  /// Offer the health pane only where the phone has a health app that can be
  /// connected. Unavailable (no Health Connect, a platform with none) shows no
  /// pane at all: an offer that cannot be taken up is clutter, not a choice.
  Future<void> _probeHealth() async {
    try {
      final status =
          await (widget.healthAvailability ?? HealthDataService.instance.availability)();
      if (!mounted) return;
      if (status == HealthAvailability.unavailable ||
          status == HealthAvailability.needsProviderUpdate) {
        return;
      }
      // The pane goes in at [_healthPaneIndex]. Once the person has got to it —
      // or past it, which a quick swipe can do before the platform has answered —
      // inserting it would make the page under them a different one: the reminders
      // pane they were reading becomes the health pane, the button changes, the
      // dots move. They are not offered it then; it is always in Settings.
      _offerHealthPane(status == HealthAvailability.available);
    } catch (e) {
      debugPrint('WelcomeScreen: health availability check failed: $e');
    }
  }

  /// Whether the pager is at rest on a page, and not part way to one.
  bool get _pagerSettled {
    if (!_pager.hasClients) return true;
    final page = _pager.page;
    return page == null || page == page.roundToDouble();
  }

  /// Put the health pane in — once the pager has stopped.
  ///
  /// [_page] only changes when a swipe or a tap has carried the pager past the
  /// midpoint, so while it is animating from the page before the pane toward the page
  /// the pane would take, it still says the person has not got there. Inserted then,
  /// the page they are travelling to becomes a different one: they were heading for
  /// the reminders pane and land on this. Wait for it to stop, and look again.
  void _offerHealthPane(bool connected, {int attempt = 0}) {
    if (!mounted) return;
    if (!_pagerSettled && attempt < 60) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _offerHealthPane(connected, attempt: attempt + 1));
      return;
    }
    if (_page >= _healthPaneIndex) return;
    setState(() {
      _showHealth = true;
      _healthConnected = connected;
    });
  }

  /// Whether this is an iPhone, where read access to health data is not
  /// disclosed to apps.
  bool get _onIPhone => defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _connectHealth() async {
    if (_connecting) return;
    HapticFeedback.mediumImpact();
    setState(() => _connecting = true);
    var granted = false;
    try {
      granted =
          await (widget.connectHealth ?? HealthDataService.instance.requestPermissions)();
    } catch (e) {
      debugPrint('WelcomeScreen: connecting the health app failed: $e');
    }
    // Not awaited: the numbers arrive on Today as they land, and a slow health app
    // must not hold the pane. Only once connected; a refusal reads nothing.
    if (granted) unawaited(_importHealth());
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _healthConnected = granted;
      _healthDeclined = !granted;
    });
  }

  /// Steps, sleep and the rest of the overnight record, the way the app does at
  /// start-up. Each is attempted on its own and none may stop the others: a health
  /// app with no sleep in it is still a health app with steps.
  Future<void> _importHealth() async {
    final custom = widget.importHealth;
    if (custom != null) {
      // Unawaited by the caller, so nothing may escape from here.
      try {
        await custom();
      } catch (e) {
        debugPrint('WelcomeScreen: importing from the health app failed: $e');
      }
      return;
    }
    for (final sync in <Future<Object?> Function()>[
      StepService.syncFromHealth,
      SleepService.syncFromHealth,
      BiometricsService.syncFromHealth,
    ]) {
      try {
        await sync();
      } catch (e) {
        debugPrint('WelcomeScreen: importing from the health app failed: $e');
      }
    }
  }

  void _toggleGoal(WelcomeGoal goal) {
    HapticFeedback.selectionClick();
    setState(() => _picks = WelcomeGoal.toggled(_picks, goal));
  }

  Future<void> _pickCheckInTime() async {
    final picked = await AppTimePicker.show(
      context,
      initial: _reminderTime,
      accent: AppColorsExt.of(context).reminders,
      minuteInterval: 5,
      title: 'Check-in time',
    );
    if (picked != null && mounted) setState(() => _reminderTime = picked);
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

  /// Persists only what onboarding actually asked about — the reminder time.
  ///
  /// The hydration profile is deliberately NOT written here. This screen has no
  /// water-goal UI (see the class comment), so the goal it used to save was
  /// never a user choice, and it saved it as `useCustomGoal: true` — an
  /// explicit override. That pinned every new user to a 2500 ml default they
  /// were never shown: `HydrationProfile.effectiveGoalMl` stops consulting the
  /// profile-calculated goal, and `WaterService.refreshWeatherGoal()` returns
  /// early on a custom goal, so the weather adjustment could never apply.
  /// Leaving the profile untouched lets the calculated goal stand until the
  /// user sets one themselves in Hydration profile.
  Future<void> _saveSetup() async {
    // What they asked to keep on top of: only the ORDER of Today's cards, and what
    // was asked, so Settings and later offers can read it. Nothing when nothing was
    // picked, which leaves the order exactly as it was.
    if (_picks.isNotEmpty) {
      await CleanStorageService.setAppPreference(
          WelcomeGoal.todayOrderKey, WelcomeGoal.todayOrderFor(_picks));
      await CleanStorageService.setAppPreference(
          WelcomeGoal.prefKey, WelcomeGoal.encode(_picks));
    }
    await CleanStorageService.setAppPreference(
        DailyCheckIn.hourKey, _reminderTime.hour);
    await CleanStorageService.setAppPreference(
        DailyCheckIn.minuteKey, _reminderTime.minute);
    // Said out loud, so Settings reads "off" for someone who skipped rather than
    // having to guess: "Turn on reminders" records "on" itself, below.
    if (CleanStorageService.getAppPreference(DailyCheckIn.enabledKey, null) == null) {
      await CleanStorageService.setAppPreference(DailyCheckIn.enabledKey, false);
    }
  }

  /// The only UI path that requests notification permission.
  Future<void> _enableReminders() async {
    HapticFeedback.mediumImpact();
    setState(() => _requesting = true);
    try {
      // Armed only if it can be shown: a check-in scheduled after the person said
      // no to the permission would be recorded as on, and never appear. Declined,
      // it is left off — Settings says so, and asks again when they turn it on.
      if (await NotificationService().ensurePermission()) {
        await DailyCheckIn.apply(enabled: true, time: _reminderTime);
      }
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
        featureName: AppStrings.productName,
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
        // promise has an immediate next step instead of an empty Today. Unless they
        // picked things other than medicines: then Today, with theirs on top.
        pageBuilder: (_, __, ___) =>
            AppShell(initialIndex: WelcomeGoal.landingTab(_picks)),
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
                          _goalsPane(ext, tt),
                          if (_showHealth) _healthPane(ext, tt),
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
  /// a one-tap "Take" — so the welcome shows what Dlyminder does, not just
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
          // This 31-character line is the widest single string in onboarding.
          // Unflexed it overran the pill by 179px on a 320pt phone — at
          // DEFAULT text size, on the first screen a new user ever sees.
          // Flexible lets it wrap to a second line inside the pill instead.
          Flexible(
            child: Text('Private by default · cloud sync is optional',
                style: tt.labelMedium?.copyWith(
                    color: ext.success.onContainer,
                    fontWeight: FontWeight.w600)),
          ),
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
        'Your health data stays on your phone unless you turn on cloud sync. Works offline.'
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
                Text('How ${AppStrings.productName} helps',
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

  // ----------------------------------------------------- what to start with pane
  Widget _goalsPane(AppColorsExt ext, TextTheme tt) {
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
                Text('What would you like to start with?',
                    style: tt.headlineSmall?.copyWith(color: ext.textPrimary)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Pick up to ${WelcomeGoal.maxPicks}. They go first on Today. '
                  'Nothing is hidden or switched on, and you can change it any '
                  'time with Customize on Today.',
                  style: tt.bodyMedium
                      ?.copyWith(color: ext.textSecondary, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final g in WelcomeGoal.values)
                      AppChip(
                        label: g.label,
                        icon: g.icon,
                        selected: _picks.contains(g),
                        accent: ext.brand,
                        onTap: () => _toggleGoal(g),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _picks.length >= WelcomeGoal.maxPicks
                      ? 'That is $_pickedOfMax. Tap one to swap it.'
                      : 'Optional — Continue to skip.',
                  style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _pickedOfMax => '${_picks.length} of ${WelcomeGoal.maxPicks}';

  // ------------------------------------------------------- the health app pane
  Widget _healthPane(AppColorsExt ext, TextTheme tt) {
    final store = healthStoreName();
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
                    color: ext.steps.container,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Symbols.monitor_heart_rounded,
                      color: ext.steps.onContainer, size: 44),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Bring in your health data',
                    style: tt.headlineSmall?.copyWith(color: ext.textPrimary),
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  // Only what the Connect button asks for — steps and sleep, with
                  // distance and active calories. Heart rate is a separate grant,
                  // asked for where it is shown, so it is not promised here.
                  'Connect $store to fill in steps and sleep from your phone '
                  'or watch, so Today has numbers from the first day. It only '
                  'reads, and you choose what to share.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium
                      ?.copyWith(color: ext.textSecondary, height: 1.5),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_healthConnected)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Symbols.check_circle_rounded,
                          color: ext.mark(ext.success), size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      // An iPhone never tells an app what a person allowed — not
                      // even that they allowed nothing — so "Connected" would be a
                      // claim nobody can check. Android's Health Connect does say.
                      Text(_onIPhone ? 'Asked' : 'Connected',
                          style: tt.titleMedium?.copyWith(
                              color: ext.textPrimary,
                              fontWeight: FontWeight.w700)),
                    ],
                  )
                else
                  AppButton(
                    label: _healthDeclined ? 'Try again' : 'Connect $store',
                    leadingIcon: Symbols.link_rounded,
                    variant: AppButtonVariant.tonal,
                    accent: ext.steps,
                    loading: _connecting,
                    onPressed: _connecting ? null : _connectHealth,
                  ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _healthDeclined
                      ? 'Not connected. You can try again from Today whenever '
                          'you like.'
                      : (_healthConnected && _onIPhone)
                          ? 'Apple Health keeps your choices private, so '
                              'DlyMinder cannot tell what you allowed. If steps '
                              'and sleep do not appear, check Health → Sharing → '
                              'Apps → DlyMinder.'
                          : 'Optional — you can skip this and connect later from '
                              'Today.',
                  textAlign: TextAlign.center,
                  style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
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
                const SizedBox(height: AppSpacing.lg),
                // One tap to move the daily check-in. It was fixed at 9:00 with
                // no way to see or change it.
                AppButton(
                  label: 'Daily check-in at ${_reminderTime.format(context)}',
                  leadingIcon: Symbols.schedule_rounded,
                  variant: AppButtonVariant.tonal,
                  accent: ext.reminders,
                  onPressed: _pickCheckInTime,
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

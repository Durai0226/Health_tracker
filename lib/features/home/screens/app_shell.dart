import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/reminder_reschedule_service.dart';
import '../../../core/services/home_widget_service.dart';
import '../../../core/services/app_lock_service.dart';
import '../../../core/services/app_shortcuts.dart';
import '../../../core/services/dose_action_queue.dart';
import '../../../core/services/water_action_queue.dart';
import '../../medication/models/medicine_log.dart' show moodRatingLabels;
import '../../medication/services/mood_answer_service.dart';
import '../../period/services/period_answer_service.dart';
import '../../reminders/services/reminder_action_service.dart';
import '../../medication/screens/vitals/blood_pressure_screen.dart';
import '../../medication/services/today_schedule_service.dart';
import '../../water/services/water_service.dart';
import '../../../core/services/health_sync_queue.dart';
import '../../steps/services/step_service.dart';
import '../../sleep/services/sleep_service.dart';
import '../../biometrics/services/biometrics_service.dart';
import '../../focus/screens/focus_screen.dart';
import '../../reminders/screens/reminders_screen.dart';
import '../../medication/screens/nunito_medication_dashboard.dart';
import '../../insights/screens/trends_dashboard_screen.dart';
import 'home_dashboard.dart';
import 'health_browse_screen.dart';
import '../widgets/log_something_sheet.dart';
import '../../medication/services/refill_loop.dart';
import '../../medication/services/visit_brief_link.dart';
import '../../medication/screens/appointments/visit_brief_screen.dart';
import '../../medication/models/doctor_pharmacy.dart' show Appointment;
import '../../medication/widgets/refill_request_sheet.dart';
import '../../water/screens/aqua_water_dashboard.dart';
import '../../../core/services/cloud_sync_runner.dart';
import '../../../core/services/queue_signal.dart';

/// The single persistent shell — one bottom nav with a center action:
/// **Today · Meds · ➕ Log · Health · Insights** over an [IndexedStack].
///
/// The nav has 5 slots but only 4 are destinations; slot 2 ("Log") is an action
/// that opens the unified quick-log sheet and never becomes the selection. So
/// the selected slot is always one of {0,1,3,4} and maps to a stack child via
/// [_stackIndex]. Focus & Reminders are no longer tabs — they're reached from
/// Today (and the Log sheet).
class AppShell extends StatefulWidget {
  final int initialIndex;

  const AppShell({super.key, this.initialIndex = 0})
      : assert(initialIndex >= 0 && initialIndex <= 4,
            'initialIndex must be a nav slot 0-4'),
        assert(initialIndex != 2,
            'slot 2 is the Log action, not a destination — it never becomes '
            'the selection, so it cannot be an initial tab');

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  // Selected NAV SLOT (never 2 — that's the Log action).
  late int _slot = widget.initialIndex;
  // Bumped when Today is re-selected so it refreshes sync-only surfaces
  // (reminders) — see HomeDashboard.refreshTick.
  int _homeTick = 0;

  /// One [ScrollController] per tab.
  ///
  /// This is load-bearing, not tidiness. `ModalRoute` wraps a route's content in
  /// exactly ONE [PrimaryScrollController], and any vertical `ScrollView` with no
  /// explicit controller silently attaches to it. Because [IndexedStack] keeps
  /// every tab alive simultaneously, Today, Health and Insights were all
  /// attaching their scroll views to that single controller at the same time.
  ///
  /// A controller driving three positions at once reports and corrects the wrong
  /// one, which is exactly what the two reported bugs were: skipping a dose on
  /// Today shrank the content, the offset correction landed on another tab's
  /// position, and Today was left unable to scroll — plus visible jumping when
  /// switching tabs. Giving each tab its own controller makes the offsets
  /// independent, and keeps per-tab scroll-to-top working.
  late final List<ScrollController> _tabScrollControllers =
      List<ScrollController>.generate(_tabCount, (_) => ScrollController());

  static const int _tabCount = 4;

  final AppShortcutsService _shortcuts = AppShortcutsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Registers the long-press launcher shortcuts and receives their taps,
    // including the one that cold-started the app.
    _shortcuts.init(_onShortcut);
    // A refill reminder that cold-started the app has already set this; one
    // tapped while the app is alive sets it later.
    RefillLoop.pendingOpen.addListener(_onRefillTap);
    VisitBriefLink.pendingOpen.addListener(_onVisitBriefTap);
    // A notification button tapped while the app is OPEN runs in a background
    // isolate and only queues its answer; nothing resumes, so without this a Done
    // tapped on a banner over the Reminders list would not show until the app was
    // next backgrounded and returned to.
    _stopListeningForQueues = QueueSignal.listen(_onQueueArrived);
    // Cold start needs draining too — and it is the MOST likely case, since a
    // notification action tapped while the app was dead is exactly what fills
    // the queue. `didChangeAppLifecycleState` does not fire for the initial
    // launch, so without this the doses sat unapplied until the user happened to
    // background and foreground the app.
    //
    // Post-frame rather than inline: the drain shows a toast, which needs a
    // mounted Scaffold.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onRefillTap();
      _onVisitBriefTap();
      _drainQueuedDoseActions();
      _drainQueuedWaterActions();
      _drainQueuedAnswers();
      _drainBackgroundHealthSync();
      _refreshAmbientData();
      _shortcuts.refresh();
    });
  }

  /// Stops [_onQueueArrived] being called; set in [initState].
  void Function()? _stopListeningForQueues;

  /// Something was just queued by a notification button: apply it now.
  void _onQueueArrived() {
    if (!mounted) return;
    _drainQueuedDoseActions();
    _drainQueuedWaterActions();
    _drainQueuedAnswers();
  }

  @override
  void dispose() {
    _stopListeningForQueues?.call();
    RefillLoop.pendingOpen.removeListener(_onRefillTap);
    VisitBriefLink.pendingOpen.removeListener(_onVisitBriefTap);
    _cancelPendingShortcut();
    for (final c in _tabScrollControllers) {
      c.dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A Take/Skip tapped on a notification is handled in a background isolate that
  /// can't reach Drift, so it lands in the dose-action queue instead. Draining it
  /// here (rather than inside a screen's own load) means the dose appears the
  /// moment the user comes back, not after they navigate or pull-to-refresh.
  /// Every affected surface listens to `revision`, which the drain's writes bump.
  ///
  /// **This is the only place that drains the dose queue.** The medicine
  /// dashboard used to drain it as well, inside its own load, with its own
  /// duplicate "Logged N doses · Undo" toast. `drainPendingDoseActions` is
  /// read-and-clear, so the two raced: on a resume into the Meds tab whichever
  /// ran first got the ids and reported them, and the other silently reported
  /// nothing — so whether the user was told a dose had been logged on their
  /// behalf depended on which tab they happened to open.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The launcher menu is read while the app is NOT running, so the shortcut
    // list has to be fresh at the moment the user leaves, not when they return.
    if (state == AppLifecycleState.paused) {
      _shortcuts.refresh();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    _drainQueuedDoseActions();
    _drainQueuedWaterActions();
    _drainQueuedAnswers();
    _drainBackgroundHealthSync();
    _rearmIfExactAlarmsWereGranted();
    _refreshAmbientData();
    // Back after a while: pick up what changed on other devices. Throttled, and
    // behind the same gates as the start-up run.
    unawaited(CloudSyncRunner.maybeSync());
  }

  /// Re-arm everything if the user has just granted SCHEDULE_EXACT_ALARM.
  ///
  /// Android 14+ denies it by default, so reminders armed before the grant are
  /// inexact — up to an hour late, which is fine for a nudge and not fine for a
  /// dose. The grant does not retroactively upgrade them; they have to be
  /// rescheduled, exactly as after a reboot.
  ///
  /// Done on resume rather than via a `ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_
  /// STATE_CHANGED` receiver deliberately. That broadcast would need a native
  /// BroadcastReceiver spinning up a Dart isolate, and this app has no native
  /// receivers at all today (MainActivity hosts MethodChannels and nothing
  /// else). It would only buy the case where the grant happens while the app is
  /// dead — and the only route to that settings page in this app is the
  /// "Allow exact alarms" button on `NotificationPermissionBanner`, which means
  /// the user leaves the app and comes back. Resume catches exactly that, with
  /// no native code to maintain.
  Future<void> _rearmIfExactAlarmsWereGranted() async {
    try {
      final downgraded =
          await NotificationService().remindersDowngradedToInexact();
      if (!downgraded) return;
      if (!await NotificationService().canScheduleExactAlarms()) return;
      // The flag still says "downgraded" but the permission is now granted —
      // so the grant landed while we were away. Rebuilding clears the flag as a
      // side effect, because every re-arm goes through the guarded scheduler.
      debugPrint('✓ Exact alarms granted while away — re-arming everything');
      await ReminderRescheduleService.rescheduleAllReminders();
    } catch (e) {
      debugPrint('⚠️ Exact-alarm re-arm check failed: $e');
    }
  }

  /// The background health worker cannot write to Drift — it drops a snapshot
  /// in SharedPreferences and sets a dirty flag instead (see
  /// [HealthSyncQueue]). This is where that gets turned into real rows, by
  /// running the ordinary foreground sync, which stays the only writer.
  ///
  /// Silent by design: unlike the dose drain above, nothing was done on the
  /// user's behalf that needs confirming — the numbers are just current.
  Future<void> _drainBackgroundHealthSync() async {
    try {
      if (!await HealthSyncQueue.takeDirty()) return;
      await StepService.syncFromHealth();
      // Fresh step numbers: the evening reminder can now say how far is left.
      unawaited(StepService.replanReminder());
      await SleepService.syncFromHealth();
      await BiometricsService.syncFromHealth();
    } catch (e) {
      debugPrint('Draining background health sync on resume failed: $e');
    }
  }

  Future<void> _drainQueuedDoseActions({String from = 'your reminder'}) async {
    List<String> ids;
    try {
      ids = await MedicineCleanStorageService.drainPendingDoseActions();
    } catch (e) {
      debugPrint('⚠️ Draining queued dose actions on resume failed: $e');
      return;
    }
    if (ids.isEmpty || !mounted) return;

    // Confirm what we applied on the user's behalf, with a way back — logging a
    // dose silently from a notification tap is not something to leave unsaid.
    final n = ids.length;
    context.toastSuccess(
      'Logged $n dose${n == 1 ? '' : 's'} from $from',
      action: AppToastAction(
        label: 'Undo',
        onPressed: () async {
          for (final id in ids) {
            // Put the units back before deleting, or Undo loses inventory.
            final log = await MedicineCleanStorageService.getLog(id);
            if (log != null && log.countsAsTaken) {
              await MedicineCleanStorageService.restoreStock(
                  log.medicineId, log.dosageTaken);
            }
            await MedicineCleanStorageService.deleteLog(id);
          }
        },
      ),
    );
  }

  /// Apply drinks logged without opening the app — a water reminder's action
  /// button or the home-screen widget's quick-add.
  ///
  /// Same hand-off as the dose drain above and confirmed the same way: writing
  /// on the user's behalf without saying so is not something to leave unsaid,
  /// and a mis-tap needs a way back.
  Future<void> _drainQueuedWaterActions() async {
    List<AppliedWaterAction> applied;
    try {
      // iOS first: its widget cannot start a Flutter isolate, so its taps are
      // sitting in the App Group rather than in the queue. Moving them across
      // before the drain means both platforms share one code path from here on.
      await HomeWidgetService.drainIosWidgetQueue();
      applied = await WaterService.drainPendingWaterActions();
    } catch (e) {
      debugPrint('⚠️ Draining queued water actions on resume failed: $e');
      return;
    }
    if (applied.isEmpty || !mounted) return;

    // The real total, not count × 250: the widget and the notification can both
    // send other volumes, so "2 × 250 ml" was simply wrong for a 500 ml tap.
    // And "from your reminder" was wrong for every home-screen quick-add.
    final ml = applied.fold<int>(0, (sum, a) => sum + a.amountMl);
    context.toastSuccess(
      'Logged $ml ml from your quick-add',
      action: AppToastAction(
        label: 'Undo',
        onPressed: () async {
          for (final a in applied) {
            // Remove it from the day it was FILED UNDER, not today. A reminder
            // answered at 23:30 and an app opened next morning logs to
            // yesterday; undoing against today deleted nothing that mattered
            // and left the drink standing in history and the weekly totals.
            await WaterService.removeWaterLogForDate(a.at, a.id);
          }
        },
      ),
    );
  }

  /// Apply the answers tapped on a notification — "Good / Okay / Bad" on the
  /// mood check-in, "Started today" on the period reminder, "Done" / "Later" on a
  /// reminder.
  ///
  /// The same hand-off as the dose and water drains above, confirmed the same
  /// way: something was written on the person's behalf, so it is said, with a
  /// way back. One toast for all of them, because a toast replaces the one before
  /// it.
  Future<void> _drainQueuedAnswers() async {
    var moods = const <AppliedMood>[];
    var reminders = const <AppliedReminderAction>[];
    var period = const PeriodAnswerOutcome();
    try {
      moods = await MoodAnswers.drainPending();
    } catch (e) {
      debugPrint('⚠️ Draining queued mood answers on resume failed: $e');
    }
    try {
      period = await PeriodAnswers.drainPending();
    } catch (e) {
      debugPrint('⚠️ Draining queued period starts on resume failed: $e');
    }
    try {
      reminders = await ReminderActionService.drainPending();
    } catch (e) {
      debugPrint('⚠️ Draining queued reminder answers on resume failed: $e');
    }
    if ((moods.isEmpty && period.isEmpty && reminders.isEmpty) || !mounted) {
      return;
    }
    // Today's Reminders card reads the list as it was when it last built.
    if (reminders.isNotEmpty) setState(() => _homeTick++);

    final said = <String>[
      if (moods.length == 1)
        'Logged your mood: ${moodRatingLabels[moods.single.moodIndex]}'
      else if (moods.length > 1)
        'Logged ${moods.length} moods',
      if (period.applied.isNotEmpty)
        'Period start logged'
      else if (period.tooSoon != null)
        // A start the Log sheet would have asked about; a button cannot ask.
        'Period start not logged: only ${period.tooSoon} days after your last. '
            'Open Period to log it',
      ?ReminderActionService.say(reminders),
    ];
    if (said.isEmpty) return;
    if (moods.isEmpty &&
        period.applied.isEmpty &&
        !ReminderActionService.canUndo(reminders)) {
      context.toastInfo(said.join(' · '));
      return;
    }
    context.toastSuccess(
      said.join(' · '),
      action: AppToastAction(
        label: 'Undo',
        onPressed: () async {
          await MoodAnswers.undo(moods);
          await PeriodAnswers.undo(period.applied);
          await ReminderActionService.undo(reminders);
          if (mounted) setState(() => _homeTick++);
        },
      ),
    );
  }

  /// A launcher-shortcut tap held back while app lock is engaged.
  VoidCallback? _pendingShortcutListener;

  void _cancelPendingShortcut() {
    final l = _pendingShortcutListener;
    if (l != null) {
      AppLockService().isLockedNotifier.removeListener(l);
      _pendingShortcutListener = null;
    }
  }

  /// A long-press shortcut was tapped.
  ///
  /// Deferred one frame, then held until unlock: the launcher menu works on a
  /// locked app, and a shortcut must not log a dose or a drink behind the PIN
  /// screen. The frame defer matters on resume, where the lock engages in the
  /// same breath as the tap arrives.
  void _onShortcut(AppShortcutTarget target) =>
      _runWhenUnlocked(() => _runShortcut(target));

  /// A tapped refill reminder: show the refill sheet for that medicine.
  void _onRefillTap() {
    final id = RefillLoop.pendingOpen.value;
    if (id == null) return;
    // Cleared first, so tapping the same notification again fires again.
    RefillLoop.pendingOpen.value = null;
    _runWhenUnlocked(() {
      if (mounted) RefillRequestFlow.run(context, id);
    });
  }

  /// A tapped "your visit brief is ready" notice: open that visit's brief.
  void _onVisitBriefTap() {
    final id = VisitBriefLink.pendingOpen.value;
    if (id == null) return;
    // Cleared first, so tapping the same notification again fires again.
    VisitBriefLink.pendingOpen.value = null;
    _runWhenUnlocked(() async {
      Appointment? appointment;
      try {
        final all = await MedicineCleanStorageService.getAllAppointments(
            scopeToActiveProfile: false);
        appointment = all.where((a) => a.id == id).firstOrNull;
      } catch (_) {}
      // A visit deleted since the notice was armed has no brief to open.
      if (appointment == null || !mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => VisitBriefScreen(appointment: appointment!)));
    });
  }

  /// Run [run] on the next frame, or — when app lock is engaged — once it
  /// releases. Shared by launcher shortcuts and notification taps: both work on
  /// a locked app, and neither may open health data behind the PIN screen.
  void _runWhenUnlocked(VoidCallback run) {
    // A post-frame callback only runs when a frame does, and an idle app may not
    // be drawing one.
    WidgetsBinding.instance.ensureVisualUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lock = AppLockService().isLockedNotifier;
      if (!lock.value) {
        run();
        return;
      }
      _cancelPendingShortcut();
      void whenUnlocked() {
        if (lock.value) return;
        _cancelPendingShortcut();
        if (mounted) run();
      }

      _pendingShortcutListener = whenUnlocked;
      lock.addListener(whenUnlocked);
    });
  }

  void _runShortcut(AppShortcutTarget target) {
    switch (target.kind) {
      case AppShortcutKind.takeDose:
        _takeDoseFromShortcut(target.medicineId!, target.scheduledTime!);
      case AppShortcutKind.logWater:
        _logWaterFromShortcut();
      case AppShortcutKind.logBloodPressure:
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const AccentScope(
                  feature: FeatureAccent.medicine,
                  child: BloodPressureScreen())),
        );
      case AppShortcutKind.startFocus:
        _legacyNavigate(2);
    }
  }

  /// Same hand-off as a notification's Take button, so the dose is written by
  /// the one code path that resolves its amount and titration, and the user
  /// gets the same "Logged · Undo" confirmation.
  ///
  /// The shortcut's label was written when the app last went to the
  /// background, so the slot is re-checked first: taken in the app since, or
  /// out of its window, and the tap explains instead of logging a second time.
  Future<void> _takeDoseFromShortcut(String medicineId, DateTime at) async {
    ScheduledDose? dose;
    try {
      final doses = await TodayScheduleService.getTodaysDoses(at);
      for (final d in doses) {
        if (d.medicine.id == medicineId && d.scheduledTime.isAtSameMomentAs(at)) {
          dose = d;
          break;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Reading doses for a shortcut failed: $e');
    }
    if (!mounted) return;
    if (dose == null) {
      context.toastInfo('That dose is no longer scheduled');
      return;
    }
    if (dose.isTaken || dose.isSkipped || dose.isPreLogged) {
      context.toastInfo('${dose.medicine.name} is already logged');
      return;
    }
    if (AppShortcuts.dueDose([dose], DateTime.now()) == null) {
      context.toastInfo(
          'That dose is outside its window. Open Medicines to log it.');
      return;
    }
    await DoseActionQueue.enqueue(
      medicineId: medicineId,
      scheduledTime: at,
      action: DoseActionQueue.actionTake,
    );
    await _drainQueuedDoseActions(from: 'the shortcut');
    _shortcuts.refresh();
  }

  /// One tap, 250 ml, unless a fluid limit is set — the same rule the Quick
  /// Settings tile and the widget follow.
  Future<void> _logWaterFromShortcut() async {
    if (WaterService.isFluidRestricted) {
      context.toastInfo(
          'A fluid limit is set. Log drinks in Water to see your total.');
      return;
    }
    await WaterActionQueue.enqueue(
      amountMl: WaterActionQueue.defaultQuickAddMl,
      at: DateTime.now(),
    );
    await _drainQueuedWaterActions();
  }

  /// Last time the home-screen widget was refreshed, for the debounce below.
  DateTime? _lastWidgetPush;

  /// How often a resume may re-push the widget snapshot. Resume fires on every
  /// return from a permission dialog, a share sheet or the app switcher, and
  /// the push reads services and hits a platform channel.
  static const _widgetPushInterval = Duration(minutes: 1);

  /// Work that keeps what the user sees CURRENT, rather than applying anything
  /// on their behalf. Silent by design, and safe to run on every resume.
  ///
  /// Both halves used to have no caller at all on this path:
  ///
  ///  * `refreshWeatherGoal` was reachable only from a button on the hydration
  ///    profile screen, so "adjust for the weather" raised the goal once and
  ///    then never again — not at launch, not on a hot afternoon, not on the
  ///    next day. The service caches its reading for three hours, which is the
  ///    rate limiting this needs.
  ///  * `pushSnapshot` ran only when a dashboard was opened, so the widget went
  ///    on drawing yesterday's steps as today's until the user happened to open
  ///    the steps or sleep tab.
  void _refreshAmbientData() {
    unawaited(WaterService.refreshWeatherGoal());

    final now = clock.now();
    final last = _lastWidgetPush;
    if (last != null && now.difference(last) < _widgetPushInterval) return;
    _lastWidgetPush = now;
    unawaited(HomeWidgetService.pushSnapshot());
  }

  // Slots {0,1,3,4} → stack children {0,1,2,3}.
  static int _stackIndexOf(int slot) => slot < 2 ? slot : slot - 1;
  int get _stackIndex => _stackIndexOf(_slot);

  /// Stack indices that have ever been selected.
  ///
  /// `IndexedStack` BUILDS AND KEEPS ALIVE every child — it only controls which
  /// one paints. So landing on Today also ran the Medication dashboard's full
  /// load (which additionally WRITES: it drains queued dose actions and
  /// reconciles missed doses), the Trends bundle (which awaits four service
  /// inits then four range queries), and the Health hub's tree — none of it
  /// visible, all of it on the critical path to first interaction.
  ///
  /// Deferring FIRST MOUNT only. Once a tab has been opened it stays alive for
  /// the session, which is what the per-tab `PrimaryScrollController` design
  /// depends on, so scroll positions and state behave exactly as before.
  ///
  /// Seeded from [AppShell.initialIndex], NOT hardcoded to Today. It was `{0}`,
  /// which shipped a blank first screen to every brand-new user: onboarding
  /// finishes into `AppShell(initialIndex: 1)`, whose `_stackIndex` is 1, and
  /// the `IndexedStack` below renders `SizedBox.shrink()` for any index this
  /// set does not contain. The lazy-mount optimisation and a non-zero initial
  /// tab were each correct alone and silently cancelled each other out.
  late final Set<int> _mounted = {_stackIndexOf(widget.initialIndex)};

  void _onTap(int slot) {
    if (slot == 2) {
      LogSomethingSheet.show(context);
      return;
    }
    setState(() {
      if (slot == 0 && _slot != 0) _homeTick++;
      _slot = slot;
      _mounted.add(slot < 2 ? slot : slot - 1);
    });
  }

  /// Translation shim for [HomeDashboard]'s legacy `onNavigate(index,{healthTab})`
  /// call sites (Batch 2 rewrites Today to call the new IA directly):
  /// meds → Meds tab; water, focus and reminders → pushed screens.
  void _legacyNavigate(int index, {int? healthTab}) {
    if (index == 1 && healthTab == 1) {
      // Hydration: the card and its "Set goal" button said "water" and landed on
      // the Health list, one tap short of the water screen. Open it.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AccentScope(
              feature: FeatureAccent.water, child: AquaWaterDashboard()),
        ),
      );
    } else if (index == 1) {
      setState(() {
        _slot = 1;
        _mounted.add(_slot < 2 ? _slot : _slot - 1);
      });
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AccentScope(
              feature: FeatureAccent.focus, child: FocusScreen()),
        ),
      );
    } else if (index == 3) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const RemindersScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final screens = [
      HomeDashboard(
        onNavigate: _legacyNavigate,
        refreshTick: _homeTick,
        onOpenTrends: () => _onTap(4),
      ),
      const NunitoMedicationDashboard(),
      HealthBrowseScreen(onOpenTrends: () => _onTap(4)),
      const TrendsDashboardScreen(isRoot: true),
    ];
    // Adding a tab without a matching controller would silently reintroduce the
    // shared-controller bug for the new tab only — fail loudly instead.
    assert(screens.length == _tabCount,
        'Add a ScrollController for every tab: ${screens.length} tabs vs $_tabCount controllers');

    return Scaffold(
      // Docked nav (not floating): keep the body ABOVE the nav so each tab's
      // FAB / bottom content isn't hidden behind the bar.
      extendBody: false,
      backgroundColor: ext.background,
      // Each tab gets its own PrimaryScrollController so the four live children
      // never share one scroll position. See [_tabScrollControllers].
      body: IndexedStack(
        index: _stackIndex,
        children: [
          for (var i = 0; i < screens.length; i++)
            if (_mounted.contains(i))
              PrimaryScrollController(
                controller: _tabScrollControllers[i],
                child: screens[i],
              )
            else
              const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        currentIndex: _slot,
        onTap: _onTap,
        items: [
          AppNavItem(
            icon: Symbols.today_rounded,
            activeIcon: Symbols.today_rounded,
            label: 'Today',
            accent: ext.brand,
          ),
          AppNavItem(
            icon: Symbols.medication_rounded,
            activeIcon: Symbols.medication_rounded,
            label: 'Meds',
            accent: ext.medicine,
          ),
          AppNavItem(
            icon: Symbols.add_rounded,
            activeIcon: Symbols.add_rounded,
            label: 'Log',
            accent: ext.brand,
            isAction: true,
          ),
          AppNavItem(
            icon: Symbols.favorite_rounded,
            activeIcon: Symbols.favorite_rounded,
            label: 'Health',
            accent: ext.water,
          ),
          AppNavItem(
            icon: Symbols.bar_chart_rounded,
            activeIcon: Symbols.bar_chart_rounded,
            label: 'Trends',
            accent: ext.brand,
          ),
        ],
      ),
    );
  }
}

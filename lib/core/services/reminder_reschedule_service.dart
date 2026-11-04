import 'dart:io' show Platform;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import '../database/daos/reminders_dao.dart'
    show genericReminderIdBase, genericReminderIdCapacity;
import '../health/hydration_pacer.dart';
import '../utils/coalesced_load.dart';
import '../utils/reminder_slot_spacing.dart';
import 'clean_storage_service.dart';
import 'daily_check_in.dart';
import 'notification_service.dart';
import '../../features/medication/services/appointment_reminder_service.dart';
import '../../features/medication/services/refill_reminder_service.dart';
import '../../features/medication/services/vitals_reminder_service.dart';
import '../../features/sleep/services/wind_down_service.dart';
import '../../features/reminders/models/reminder_model.dart';
import '../../features/reminders/services/reminder_alarm.dart';
import '../../features/medication/services/medication_reminder_service.dart';
import '../../features/medication/services/medicine_storage_service.dart';
import '../../features/sleep/services/sleep_service.dart';
import '../../features/water/services/water_service.dart';
import '../../features/reminders/services/reminder_pause_until.dart';

/// One reminder family's contribution to the "rebuild everything" pass.
///
/// The seam behind "shared core, feature-owned UIs": a feature keeps its own
/// service and settings screen and hands over exactly one thing — how to re-arm
/// itself. It does not hand over scheduling code, and the core does not reach
/// into its internals.
class ReminderFamily {
  const ReminderFamily(this.name, this.rearm);

  /// Human-readable, used only in logs.
  final String name;

  /// Re-arm everything this family owns; return how many were armed.
  ///
  /// Must be safe to call repeatedly — this runs on every app start, on an
  /// exact-alarm grant, and after a restore. Cancel-then-schedule, not
  /// schedule-again.
  final Future<int> Function() rearm;
}

/// What one [ReminderRescheduleService.rearmFamilies] pass actually achieved.
///
/// Returned rather than only logged: a pass that re-armed nothing and a pass
/// that re-armed everything printed different debug lines and were otherwise
/// indistinguishable to any caller — and to any test.
class RescheduleOutcome {
  const RescheduleOutcome({
    required this.armed,
    required this.failed,
    required this.attempted,
  });

  /// Reminders re-armed, summed across the families that succeeded.
  final int armed;

  /// Families that threw. Their reminders are NOT armed.
  final int failed;

  /// Families tried.
  final int attempted;

  /// Families that completed without throwing.
  int get succeeded => attempted - failed;
}

class ReminderRescheduleService {
  static const String _medicinesFamily = 'medicines';

  /// The families rebuilt by [rescheduleAllReminders], in order.
  ///
  /// This used to be five near-identical `try { … } catch { failCount++ }`
  /// blocks inline, which is how two families ended up missing entirely: adding
  /// one meant editing this method, and nothing made the omission visible.
  ///
  /// Order matters only for the budget: doses are armed before nudges, so if the
  /// OS pending-notification ceiling is reached it is a hydration reminder that
  /// does not fit, not a dose. See [ReminderBudget].
  static final List<ReminderFamily> _families = <ReminderFamily>[
    ReminderFamily(_medicinesFamily, _rescheduleMedicines),
    ReminderFamily('appointments', _rescheduleAppointments),
    ReminderFamily('generic reminders', rescheduleGenericReminders),
    ReminderFamily('vitals', VitalsReminderService.rescheduleAll),
    ReminderFamily('refills', RefillReminderService.rescheduleAll),
    ReminderFamily('water', rescheduleWaterReminders),
    // After the rest: a wind-down reminder that follows tonight's plan moves
    // with the sleep owed, so it is re-read here at every start.
    ReminderFamily('sleep wind-down', WindDownService.rearm),
    // The setup's one nudge a day, which is switchable now and so has to be
    // re-armed from what is recorded, not assumed.
    ReminderFamily('daily check-in', DailyCheckIn.rearm),
  ];

  /// Add a family. For anything defined outside this file's imports; the
  /// built-ins are registered above rather than at startup, so there is no
  /// ordering hazard and no way to boot with a family silently unregistered.
  static void register(ReminderFamily family) {
    if (_families.any((f) => f.name == family.name)) return;
    _families.add(family);
  }

  @visibleForTesting
  static List<String> get familyNames =>
      List.unmodifiable(_families.map((f) => f.name));

  /// The names of the families the last pass went through, so a test can tell a pass
  /// over everything from one over the medicines alone.
  @visibleForTesting
  static List<String> lastPassFamilies = const [];

  /// Rebuild every family's reminders.
  ///
  /// Runs on every app start (`main._initDeferredServices`, off the critical
  /// path), whenever an exact-alarm grant lands
  /// (`AppShell._rearmIfExactAlarmsWereGranted`), after a restore, and when the
  /// person changes how alerts look. Each family is isolated: one throwing must not
  /// stop the rest, which is the difference between losing one family's reminders
  /// and losing all of them.
  ///
  /// One pass at a time: a pass cancels and re-arms every reminder, so two running
  /// over each other — a start-up pass and a switch flipped during it, or two
  /// switches a few seconds apart — interleave their cancels and schedules. A call
  /// that arrives while one is running asks for ONE more pass behind it, and
  /// completes when that has finished.
  static Future<void> rescheduleAllReminders() {
    _reconcileWanted = true;
    _fullWanted = true;
    return _passes();
  }

  /// Arm every reminder again and do nothing else: [rescheduleAllReminders] without
  /// the missed-dose reconciliation that opens it.
  ///
  /// For when how an alert LOOKS has changed. Flipping Vibration is not a reason to
  /// close out every past-due dose as missed — which moves the adherence numbers at
  /// that moment, where the person is looking at a switch. It shares the one pass
  /// with [rescheduleAllReminders] (two passes must never interleave), and a pass
  /// reconciles if anyone who is waiting for it asked to.
  static Future<void> rearmReminders() {
    _fullWanted = true;
    return _passes();
  }

  /// Set by [rescheduleAllReminders], read and cleared by the pass that serves it.
  static bool _reconcileWanted = false;

  /// Set by every request for a pass over every family, read and cleared by the pass
  /// that serves it. A pass nobody asked that of — [rearmDosesIfStale]'s — re-arms
  /// the medicines only, so a pass for the doses does not cancel and re-arm every
  /// water, vitals and refill reminder too.
  static bool _fullWanted = false;

  /// Stands in for one pass, so the one-at-a-time rule can be driven without the
  /// platform and the database every real family reaches.
  @visibleForTesting
  static Future<void> Function()? passForTesting;

  /// Stand in for the missed-dose reconciliation and for the families, so what a
  /// pass does — and does not — can be driven without the platform.
  @visibleForTesting
  static Future<void> Function()? reconcileForTesting;

  @visibleForTesting
  static List<ReminderFamily>? familiesForTesting;

  static final CoalescedLoad _passes =
      CoalescedLoad(() => (passForTesting ?? _rescheduleOnce)());

  static Future<void> _rescheduleOnce() async {
    debugPrint('🔄 Rescheduling all reminders...');
    final reconcile = _reconcileWanted;
    _reconcileWanted = false;
    final full = _fullWanted;
    _fullWanted = false;

    // Close out past-due doses nobody answered, BEFORE anything reports on
    // them — the same denominator problem as `reconcileMissedReminders` below.
    //
    // Its only other caller is the Medication dashboard's load, so a user who
    // takes doses from the notification and never opens that tab accumulated
    // no `missed` rows at all: the streak, the adherence card, the report and
    // the CSV export every one of them read 100%. Running it here means it
    // happens at every app start and on an exact-alarm grant instead.
    //
    // Deliberately outside the family loop and separately guarded: it arms
    // nothing, and a reconcile failure must never stop reminders being
    // re-armed.
    if (reconcile) {
      try {
        await (reconcileForTesting ?? MedicineCleanStorageService.reconcileMissedDoses)();
      } catch (e) {
        debugPrint('⚠️ Missed-dose reconciliation failed: $e');
      }
    }

    final outcome = await rearmFamilies(familiesForTesting ??
        (full ? _families : _families.where((f) => f.name == _medicinesFamily).toList()));

    debugPrint('✓ Rescheduled ${outcome.armed} reminders across '
        '${outcome.succeeded}/${outcome.attempted} families');
    if (outcome.failed > 0) {
      debugPrint('⚠️ ${outcome.failed} reminder families failed to reschedule');
    }
  }

  /// Re-arm each of [families], isolating every one from the others.
  ///
  /// Split out of [rescheduleAllReminders] so the isolation can be *driven*
  /// rather than grepped. It used to be asserted by slicing this file's own
  /// source and checking it contained the substrings `try {`, `catch (e)` and
  /// `failed++` — which passes on a `try` whose `catch` rethrows, passes on a
  /// `failed++` in an unrelated branch, and fails on a rename that changed
  /// nothing. `rescheduleAllReminders` itself cannot be called headlessly
  /// because all six real families reach a platform channel or the database;
  /// this takes the families as an argument, so a test supplies its own.
  ///
  /// One family throwing must never stop the rest. That is the difference
  /// between losing one family's reminders and losing every reminder in the app.
  @visibleForTesting
  static Future<RescheduleOutcome> rearmFamilies(
      List<ReminderFamily> families) async {
    var armed = 0;
    var failed = 0;
    lastPassFamilies = [for (final f in families) f.name];

    for (final family in families) {
      try {
        final n = await family.rearm();
        armed += n;
        debugPrint('✓ ${family.name}: $n re-armed');
      } catch (e) {
        failed++;
        debugPrint('⚠️ ${family.name} rescheduling failed: $e');
      }
    }

    return RescheduleOutcome(
        armed: armed, failed: failed, attempted: families.length);
  }

  /// Unscoped by profile on purpose: every profile's reminders must be
  /// (re)scheduled, not just whichever one happens to be active — see
  /// `MedicationReminderService.rescheduleAll`'s doc for why.
  static Future<int> _rescheduleMedicines() async {
    final medicines = await MedicineCleanStorageService.getAllMedicines(
        scopeToActiveProfile: false);
    final reminderService = MedicationReminderService();
    // One-time: clear any medicine alarms left under the old hash-based IDs
    // before we reschedule with the new dense (collision-free) scheme.
    await reminderService.migrateNotificationIdsIfNeeded();
    final refused = await reminderService.scheduleAllReminders(medicines);
    // Written down whether or not every dose was armed, with whether any was refused:
    // [rearmDosesIfStale] reads both. A pass that armed none (notifications switched
    // off, one medicine the phone always refuses) must not count as one that armed
    // everything — and must not be run again on every return to the app either, which
    // is what leaving no stamp at all would do. So it counts, and is tried again
    // sooner.
    try {
      await CleanStorageService.setAppPreference(
          dosesArmedAtKey, clock.now().millisecondsSinceEpoch);
      await CleanStorageService.setAppPreference(dosesRefusedKey, refused > 0);
    } catch (e) {
      debugPrint('⚠️ Could not record when the dose reminders were armed: $e');
    }
    return medicines.where((m) => m.reminderEnabled).length;
  }

  /// App preference (milliseconds since the epoch): when the dose reminders were
  /// last armed.
  static const String dosesArmedAtKey = 'dose_reminders_armed_at';

  /// App preference (bool): whether the phone refused any of them that time.
  static const String dosesRefusedKey = 'dose_reminders_refused';

  /// How soon after a pass that the phone refused doses in, another is worth trying.
  /// Not never, which would leave the doses that run out alone for twelve hours; not
  /// at every return to the app either, which is a full read of the medicines and a
  /// round of cancels each time for something that will probably be refused again.
  static const Duration refusedRetryAfter = Duration(hours: 1);

  /// Stands in for "this is an iPhone", which `Platform.isIOS` cannot be made to
  /// say on the host the tests run on.
  @visibleForTesting
  static bool? isIosForTesting;

  /// Arm the dose reminders again if it has been [maxAge] since they were.
  ///
  /// For an iPhone, where a medicine that is not due every day is armed as one
  /// reminder per upcoming dose (see `IosDosePlan`) and so runs out: arming happens
  /// at every start of the app, but an app that stays alive in the background for
  /// weeks is never started. Coming back to the foreground is the other moment the
  /// app can look, and this is what it asks.
  ///
  /// Not Android, whose alarms decide when they fire whether the medicine is due and
  /// never run out. It re-arms the medicines and nothing else, through the same
  /// one-pass-at-a-time as everything here so it cannot interleave with a pass that is
  /// already running — and does nothing while one is, since that pass is arming the
  /// medicines now and will say so when it is done.
  static Future<void> rearmDosesIfStale(
      {Duration maxAge = const Duration(hours: 12)}) async {
    if (!(isIosForTesting ?? Platform.isIOS)) return;
    if (_passes.isRunning) return;
    final armed = CleanStorageService.getAppPreference(dosesArmedAtKey, null);
    if (armed is int) {
      final age = clock.now().difference(DateTime.fromMillisecondsSinceEpoch(armed));
      final refused =
          CleanStorageService.getAppPreference(dosesRefusedKey, false) == true;
      final limit = refused && refusedRetryAfter < maxAge ? refusedRetryAfter : maxAge;
      // A stamp from the future (a clock set back) is treated as stale, not fresh
      // for ever.
      if (!age.isNegative && age < limit) return;
    }
    await _passes();
  }

  /// A device reboot or app update can lose AndroidAlarmManager's pending
  /// alarms, and unlike medicine reminders (rebuilt from a full recompute)
  /// nothing else re-schedules these.
  static Future<int> _rescheduleAppointments() async {
    final upcoming = await MedicineCleanStorageService.getUpcomingAppointments(
        scopeToActiveProfile: false);
    for (final appointment in upcoming) {
      await AppointmentReminderService.schedule(appointment);
    }
    return upcoming.where((a) => a.reminderEnabled).length;
  }

  /// Re-arm every incomplete generic reminder, allocating a reserved
  /// notification id for any that predates schema v16.
  ///
  /// This is also what drains the legacy `id.hashCode` fallback: the old id is
  /// cancelled first, so an alarm armed under an unreserved id (which could sit
  /// on top of another family's block) is cleared rather than orphaned.
  ///
  /// Completed non-repeating reminders are skipped — re-arming one would ring
  /// for something the user already ticked off.
  /// [alarm] is injectable purely so this is testable — see [ReminderAlarm].
  /// Everything decided below (which reminders are skipped, that the old id is
  /// cancelled before a new one is allocated) is ordinary logic; only the
  /// delivery it hands off to is an OS behaviour.
  static Future<int> rescheduleGenericReminders({
    ReminderAlarm alarm = const NotificationReminderAlarm(),
  }) async {
    // Close out occurrences nobody ever answered, BEFORE anything reads the log.
    //
    // This is the denominator, and without it there isn't one: no `missed` rows
    // means every adherence figure reads 100% for everyone forever. Exactly the
    // failure `reconcileMissedDoses` exists to prevent on the medication side —
    // "a user who never opens the app would otherwise show 100% adherence
    // forever" — and it was reintroduced here by writing the sweep and never
    // calling it.
    //
    // Runs here rather than on a timer because this pass already runs at every
    // app start and on an exact-alarm grant, and a miss does not need to be
    // recorded the instant it happens — only before anything reports on it.
    //
    // ORDER MATTERS. The sweep only rewrites rows `pendingBefore` returns, and
    // nothing ever created a `pending` row — `recordReminderOutcome`'s single
    // production caller is the in-app tick, which writes `done`, and the alarm
    // isolate has no Drift connection. So the sweep always found zero rows and
    // the comment above described a denominator that did not exist: the card
    // read "100% of days fully covered" for someone who had ignored a daily
    // reminder for a month and ticked it once.
    //
    // Deriving the due occurrences first gives the sweep something to write
    // off. It is insert-if-absent, so it can never overwrite a tick.
    await CleanStorageService.recordDueReminderOccurrences();
    await CleanStorageService.reconcileMissedReminders();

    // Bring back anything paused "until" a date that has now arrived, BEFORE the
    // list is read, so it is armed in this very pass.
    await ReminderPauseUntil.resumeDue();

    final reminders = await separateClashingSlots(
        await CleanStorageService.getAllReminders(),
        alarm: alarm);
    final now = clock.now();
    var armed = 0;

    for (final reminder in reminders) {
      if (reminder.isCompleted && reminder.repeatType == RepeatType.none) {
        continue;
      }
      // Paused means paused. `isPaused` is stored and cloud-synced, and
      // ReminderHelper has always honoured it; this loop did not, so a paused
      // reminder was re-armed on every launch. `arm` disarms it for us.
      if (reminder.isPaused) {
        await alarm.disarm(
          id: reminder.notificationSlot,
          repeatType: reminder.repeatType,
          customDays: reminder.customDays,
        );
        continue;
      }
      // A one-off whose time has passed has nothing left to fire.
      //
      // `recurrenceRule == null` is load-bearing: Smart Add writes an RRULE
      // with `repeat` left at `none`, so this skip was silently retiring every
      // rule-based reminder the moment its FIRST instant passed. "Water the
      // plants every 3 days" fired once and then sat under Overdue forever.
      if (reminder.repeatType == RepeatType.none &&
          reminder.recurrenceRule == null &&
          reminder.scheduledTime.isBefore(now)) {
        continue;
      }
      try {
        // Clear whatever it is currently armed under BEFORE allocating, or the
        // old registration outlives the reminder with nothing able to cancel it.
        await alarm.disarm(
          id: reminder.notificationSlot,
          repeatType: reminder.repeatType,
          customDays: reminder.customDays,
        );
        final stored = reminder.notificationId == null
            ? await CleanStorageService.saveReminderAllocatingId(reminder)
            : reminder;
        // Resolves the RRULE / endsAt / isPaused the six-value RepeatType
        // cannot express. Null means there is nothing left to arm — the
        // reminder is paused, past its end date, its rule has run out, or the
        // user is on vacation — and the disarm above has already taken it off
        // the OS.
        final request = ReminderArmRequest.forNextOccurrence(stored);
        if (request == null) continue;
        final ok = await alarm.arm(request);
        if (ok) armed++;
      } catch (e) {
        debugPrint('⚠️ Re-arming reminder "${reminder.title}" failed: $e');
      }
    }
    debugPrint('✓ Generic reminders re-armed: $armed');
    return armed;
  }

  /// Move reminders whose slots share ids to places that do not.
  ///
  /// A reminder that repeats on chosen days is armed under its slot and the seven
  /// after it, and the OS holds one pending notification per id. Slots used to be
  /// handed out one apart, so a weekday reminder's Tuesday sat on the next
  /// reminder's slot and one of the two never fired. New slots are spaced
  /// ([ReminderSlotSpacing]); this puts right the ones already given out. The
  /// oldest reminder in a clashing group keeps its slot, the others get a clear
  /// one, and what was armed under the old slot is taken off first — the pass
  /// that calls this arms every reminder again straight after.
  ///
  /// Returns [reminders] with the moved ones replaced. A reminder that finds no
  /// clear place (the block is full) is left where it is.
  @visibleForTesting
  static Future<List<Reminder>> separateClashingSlots(
    List<Reminder> reminders, {
    required ReminderAlarm alarm,
  }) async {
    final slotted = [
      for (final r in reminders)
        if (r.notificationId != null) r
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final moving = ReminderSlotSpacing.clashing(slotted, (r) => r.notificationId!);
    if (moving.isEmpty) return reminders;

    final movingIds = {for (final r in moving) r.id};
    final taken = <int>[
      for (final r in slotted)
        if (!movingIds.contains(r.id)) r.notificationId!
    ];
    final replaced = <String, Reminder>{};
    for (final r in moving) {
      final slot = ReminderSlotSpacing.lowestFree(taken,
          base: genericReminderIdBase, capacity: genericReminderIdCapacity);
      if (slot == null) {
        debugPrint('⚠️ No clear reminder slot left for "${r.title}" — left as is');
        continue;
      }
      try {
        // Under the slot it is armed under now; its neighbour's alarm may go
        // with it, and is armed again by the pass this runs in.
        await alarm.disarm(
          id: r.notificationSlot,
          repeatType: r.repeatType,
          customDays: r.customDays,
        );
        final moved = r.copyWith(notificationId: slot);
        await CleanStorageService.saveReminder(moved);
        taken.add(slot);
        replaced[r.id] = moved;
      } catch (e) {
        debugPrint('⚠️ Moving reminder "${r.title}" to slot $slot failed: $e');
      }
    }
    debugPrint('✓ Reminder slots separated: ${replaced.length} moved');
    return [for (final r in reminders) replaced[r.id] ?? r];
  }

  /// (Re)schedule interval water reminders from the persisted config.
  ///
  /// Applies the adaptive behaviour:
  /// - disabled config → cancel everything.
  /// - `pauseWhenGoalReached` + today's goal already reached → cancel (they are
  ///   re-established next app start / next day when the goal is not yet met).
  /// - `respectQuietHours` → drop times outside the wake → bedtime window,
  ///   via the shared `QuietHours` primitive (core/utils/quiet_hours.dart) —
  ///   see its doc for why this is applied here and not to
  ///   medicine/vitals/generic/focus reminders, which are all user-time-picked
  ///   rather than auto-generated. The window itself defaults to the
  ///   hydration profile's fixed wake/bed hours, or — when
  ///   `useSleepSchedule` is on — a Sleep-feature-derived window: a real
  ///   average of logged nights when there's enough history, falling back to
  ///   the stated sleep schedule, falling back to the hydration profile hours.
  ///
  /// Returns the number of reminders actually scheduled.
  static Future<int> rescheduleWaterReminders() async {
    final notif = NotificationService();
    final config = CleanStorageService.getWaterReminderConfig();

    if (config == null || !config.enabled) {
      await notif.cancelAllWaterReminders();
      return 0;
    }

    // A prescribed fluid ceiling inverts the whole point of a reminder: the
    // user is trying to drink LESS, and a nudge to drink more is actively
    // against medical advice. Nothing is scheduled at all in that mode.
    if (WaterService.isFluidRestricted) {
      await notif.cancelAllWaterReminders();
      debugPrint('💧 Water reminders off — profile is on a fluid restriction');
      return 0;
    }

    final goalReached = WaterService.getTodayData().goalReached;
    if (config.pauseWhenGoalReached && goalReached) {
      await notif.cancelAllWaterReminders();
      debugPrint('💧 Water reminders paused — goal already reached today');
      return 0;
    }

    int wakeHour, wakeMinute, bedHour, bedMinute;
    if (config.useSleepSchedule) {
      final avg = SleepService.averageActualSchedule();
      if (avg != null) {
        wakeHour = avg.wakeHour;
        wakeMinute = avg.wakeMinute;
        bedHour = avg.bedHour;
        bedMinute = avg.bedMinute;
      } else {
        final schedule = SleepService.getSchedule();
        wakeHour = schedule.wakeHour;
        wakeMinute = schedule.wakeMinute;
        bedHour = schedule.bedtimeHour;
        bedMinute = schedule.bedtimeMinute;
      }
    } else {
      final profile = WaterService.getProfile();
      wakeHour = profile.wakeUpHour ?? 7;
      wakeMinute = 0;
      bedHour = profile.bedtimeHour ?? 22;
      bedMinute = 0;
    }

    final times = config.effectiveReminderMinutes(
      wakeHour: wakeHour,
      wakeMinute: wakeMinute,
      bedHour: bedHour,
      bedMinute: bedMinute,
    );

    return notif.scheduleWaterReminderTimes(
      _pruneToRemainingNeedFromWorld(times,
          bedHour: bedHour,
          bedMinute: bedMinute,
          // The user's real waking window, so pacing is measured against
          // their day and not against office hours — the same mistake
          // hydrationCoach was fixed for.
          wakeMinutes: wakeHour * 60 + wakeMinute),
    );
  }

  /// Drop reminders the user does not need.
  ///
  /// The schedule was generated once in the settings screen and then frozen:
  /// every slot fired every day regardless of whether the person had already
  /// drunk two litres. That is the fixed-interval nagging the whole category is
  /// criticised for, and notification fatigue is the top reason people disable
  /// hydration reminders entirely.
  ///
  /// Rather than reschedule on every sip — `scheduleWaterReminderTimes` first
  /// issues ~200 `cancel()` calls and then up to 100 `zonedSchedule`s, each
  /// preceded by its own permission check, so running it per drink would be
  /// absurd — this prunes at reschedule time using the same idea Hydro Coach
  /// uses: how many more drinks are actually needed to close today's gap?
  ///
  ///   drinksNeeded = ceil(remaining / typical drink size)
  ///
  /// If there are more remaining slots than drinks needed, keep an evenly
  /// spaced subset. Someone 200 ml short gets one more nudge instead of six;
  /// someone who has drunk nothing all day still gets the full schedule.
  ///
  /// Only slots still ahead of `now` are considered — a slot at 09:00 is not a
  /// candidate at 4pm.
  /// Reads the world, then hands the decision to [pruneToRemainingNeed].
  ///
  /// W-15 — this used to be one private method that BOTH fetched its inputs
  /// (`WaterService.getTodayData()`, `clock.now()`,
  /// `WaterService.typicalDrinkMl()`) and decided which slots survive. Nothing
  /// could test the decision without standing up the whole water service, so
  /// nothing did: the evenly-spaced-subset maths, the ahead-of-pace decrement
  /// and the floor-at-one were all unexercised. Splitting the read from the
  /// rule is the whole fix; the rule below is pure and directly testable.
  static List<int> _pruneToRemainingNeedFromWorld(
    List<int> times, {
    required int bedHour,
    required int bedMinute,
    int wakeMinutes = 7 * 60,
  }) {
    if (times.isEmpty) return times;
    final today = WaterService.getTodayData();
    final now = clock.now();
    return pruneToRemainingNeed(
      times,
      goalMl: today.dailyGoalMl,
      intakeMl: today.effectiveHydrationMl,
      nowMinutes: now.hour * 60 + now.minute,
      typicalDrinkMl: WaterService.typicalDrinkMl(),
      bedHour: bedHour,
      bedMinute: bedMinute,
      wakeMinutes: wakeMinutes,
    );
  }

  /// Which of [times] (minutes since midnight) still deserve a nudge.
  ///
  /// Pure: every input is a parameter, so a test can put the user at 8pm with
  /// 800 ml to go without a database, a clock or a service singleton.
  @visibleForTesting
  static List<int> pruneToRemainingNeed(
    List<int> times, {
    required int goalMl,
    required int intakeMl,
    required int nowMinutes,
    required int typicalDrinkMl,
    required int bedHour,
    required int bedMinute,
    int wakeMinutes = 7 * 60,
  }) {
    if (times.isEmpty) return times;

    final remaining = goalMl - intakeMl;
    if (remaining <= 0) return const [];

    final future = times.where((t) => t > nowMinutes).toList();
    // Everything left today has passed; the times still need to be registered
    // because they repeat daily, so leave the schedule alone.
    if (future.isEmpty) return times;

    final drink = typicalDrinkMl;
    var needed = (remaining / (drink <= 0 ? 250 : drink)).ceil();

    // Pace, not just total.
    //
    // Remaining volume alone says nothing about urgency: someone 800 ml short at
    // 10am is comfortably ahead, and someone 800 ml short at 8pm is not.
    // `HydrationPacer` already computes exactly that distinction and was wired
    // only to display — the reminder schedule, the one place it could change
    // behaviour, ignored it.
    //
    // Ahead of pace: one fewer nudge, floored at one so the schedule never goes
    // silent on someone who still has a gap to close. Projected to miss: keep
    // every remaining slot, because that is the case where nagging is the point.
    try {
      final pace = HydrationPacer.compute(
        intakeMl: intakeMl,
        goalMl: goalMl,
        nowMinutes: nowMinutes,
        wakeMinutes: wakeMinutes,
        sleepMinutes: bedHour * 60 + bedMinute,
      );
      if (pace.projectedToMiss) {
        return times;
      } else if (pace.status == 'ahead' && needed > 1) {
        needed -= 1;
      }
    } catch (e) {
      debugPrint('⚠️ Hydration pacing unavailable; pruning on volume only: $e');
    }

    if (needed >= future.length) return times;
    if (needed <= 0) return const [];

    // Evenly spaced subset of the remaining slots, always including the last
    // one so there is a final nudge before bed.
    final kept = <int>{};
    for (var i = 0; i < needed; i++) {
      final idx = ((i + 1) * future.length / needed).ceil() - 1;
      kept.add(future[idx.clamp(0, future.length - 1)]);
    }

    // Past slots stay scheduled: they repeat daily and will be re-pruned
    // tomorrow against tomorrow's progress.
    final past = times.where((t) => t <= nowMinutes);
    return [...past, ...kept]..sort();
  }
}

/// What the Today dashboard SAYS vs what is actually true.
///
/// The existing responsive sweep renders Home against an EMPTY database, so
/// every populated state — the one every real user sees — was never rendered by
/// any harness. This one seeds medicines at known offsets from `now` (so it is
/// wall-clock independent) and asserts the numbers on screen.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    MedicineCleanStorageService.revision.value = 0;
  });

  tearDown(() async => db.close());

  /// Today at 13:00, pinned for every test in this file.
  ///
  /// Today's real DATE is kept (the storage layer still resolves "today" through
  /// its own calendar reads, so the seeded slots must land on the same day), but
  /// the TIME is fixed at midday. That is what makes "two doses already due and
  /// one still to come" expressible at any hour — including the 00:01 run that
  /// caught this file out.
  final pinnedNow = () {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, 13, 0);
  }();

  /// `testWidgets` inside a pinned clock zone. Production code reads
  /// `clock.now()`, which resolves to [pinnedNow] here and to `DateTime.now()`
  /// in the app.
  void pinnedTest(String description, Future<void> Function(WidgetTester) body) {
    testWidgets(description,
        (tester) => withClock(Clock.fixed(pinnedNow), () => body(tester)));
  }

  /// One medicine with [past] slots already behind `now` and [future] slots
  /// still ahead of it, all inside today.
  ///
  /// `now` is the PINNED clock (see [pumpHome]), not the wall clock. Two earlier
  /// versions of this helper were wall-clock dependent and both broke:
  ///
  ///  * fixed offsets ("-2h / +3h") fell off the end of the day — the first
  ///    version asserted "3 of 3 doses" and failed at 20:51 because its `+4h`
  ///    slot had crossed midnight and been silently dropped;
  ///  * deriving positions from elapsed time fixed that but still could not
  ///    express "two doses already due" shortly after midnight, and duly failed
  ///    at 00:01 with only one distinct past minute available.
  ///
  /// Both failures read exactly like product bugs in the report. Pinning the
  /// clock removes the whole class: midday is always expressible. Slots stay
  /// minute-granular ([ScheduledTime]) so each lands on its own minute.
  Future<({List<DateTime> past, List<DateTime> future})> seedMed({
    int past = 0,
    int future = 0,
    String id = 'm1',
    String name = 'Metformin',
  }) async {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59);

    /// [count] distinct minutes spread evenly across the span, skipping both
    /// boundaries so nothing lands exactly on `now` — a slot at `now` is neither
    /// due nor upcoming, which is a different scenario.
    List<DateTime> spread(DateTime from, DateTime to, int count) {
      final minutes = to.difference(from).inMinutes;
      if (count <= 0 || minutes <= 1) return const [];
      final step = (minutes / (count + 1)).floor().clamp(1, 6 * 60);
      return [
        for (var i = 1; i <= count; i++)
          if (step * i < minutes) from.add(Duration(minutes: step * i)),
      ];
    }

    final pastSlots = spread(today, now, past);
    final futureSlots = spread(now, endOfDay, future);
    final slots = [...pastSlots, ...futureSlots]..sort();
    if (slots.isEmpty) {
      throw StateError('no in-day slots for past=$past future=$future at '
          '${now.hour}:${now.minute} — cannot express this scenario today');
    }
    await MedicineCleanStorageService.addMedicine(EnhancedMedicine(
      id: id,
      name: name,
      strength: '500mg',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      createdAt: today.subtract(const Duration(days: 7)),
      schedule: MedicineSchedule(
        // The slot list is what drives every number under test; the frequency
        // enum only feeds `isActiveOnDate`, so it just has to agree in count.
        frequencyType: switch (slots.length) {
          1 => FrequencyType.onceDaily,
          2 => FrequencyType.twiceDaily,
          3 => FrequencyType.thriceDaily,
          _ => FrequencyType.fourTimesDaily,
        },
        times: slots
            .map((t) => ScheduledTime(hour: t.hour, minute: t.minute))
            .toList(),
      ),
    ));
    return (past: pastSlots, future: futureSlots);
  }

  Future<void> markTaken(DateTime slot, {String medicineId = 'm1'}) =>
      MedicineCleanStorageService.addLog(MedicineLog.taken(
        id: MedicineCleanStorageService.doseLogId(medicineId, slot),
        medicineId: medicineId,
        scheduledTime: slot,
      ));

  Future<List<String>> pumpHome(
    WidgetTester tester, {
    double width = 375,
    double scale = 1.0,
    List<String>? overflowSink,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.exception.toString();
      if (s.contains('overflowed by')) {
        overflowSink?.add(
            '${width.toInt()}pt @${scale}x  ${s.split('\n').first.trim()}');
      }
    };
    try {
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(scale),
        ),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeDashboard(onNavigate: (int i, {int? healthTab}) {}),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
    } finally {
      FlutterError.onError = prev;
    }
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  /// Nothing on screen may claim a dose is finished while another is pending.
  ///
  /// This is one test rather than four because the defect was never in a single
  /// widget — the hero, the pulse ring and the Medicine card each read the same
  /// wrong denominator, and two of them ended up contradicting the third on the
  /// same screenful. Asserting them together is what pins that down.
  pinnedTest('a dose still to come today is never counted as done',
      (tester) async {
    // One dose taken earlier today, one still ahead.
    final slots = await seedMed(past: 1, future: 1);
    expect(slots.past, hasLength(1));
    expect(slots.future, hasLength(1),
        reason: 'this scenario needs a pending dose to exist');
    await markTaken(slots.past.first);

    final texts = await pumpHome(tester);
    final screen = texts.join(' | ');

    expect(texts, contains('1 of 2 taken today · See all'),
        reason: 'the hero counted only the doses already due, so it read '
            '"1 of 1 taken today" underneath its own "UP NEXT" line');
    expect(texts, contains('1/2'),
        reason: 'the Meds pulse ring counted 1/1 — a full ring at lunchtime');
    expect(texts, contains('1 of 2 doses left today'),
        reason: 'the Medicine card said "All doses taken — nice work"');

    expect(texts, isNot(contains('100%')),
        reason: 'the Medicine ring captioned itself 100% with a dose pending. '
            'Screen was: $screen');
    expect(texts, contains('50%'),
        reason: "the ring must caption today's real completion");
    expect(screen, isNot(contains('All doses taken')));
    expect(screen, isNot(contains('Perfect day')));
  });

  pinnedTest('doses that are all still ahead of you are not "none scheduled"',
      (tester) async {
    final slots = await seedMed(future: 3);
    final n = slots.future.length; // 3, unless run in the last minutes of a day
    expect(slots.past, isEmpty);

    final texts = await pumpHome(tester);
    final screen = texts.join(' | ');

    expect(screen, isNot(contains('No doses scheduled today')),
        reason: '$n doses are scheduled today — they just have not come round '
            'yet. Screen was: $screen');
    expect(texts, contains('$n of $n doses left today'));
    expect(texts, contains('0 of $n taken today · See all'));
    expect(texts, contains('0/$n'),
        reason: 'the Meds pulse cell rendered a muted em-dash and a FULL ring, '
            'reading as "nothing to do, all done"');
    expect(texts, contains('0%'));
  });

  pinnedTest('a genuinely finished day still reads as finished',
      (tester) async {
    // The fix must not simply move the goalposts: when the whole day really is
    // done, the celebratory copy and the closed ring have to survive.
    final slots = await seedMed(past: 2);
    final n = slots.past.length;
    expect(n, greaterThan(0));
    for (final s in slots.past) {
      await markTaken(s);
    }

    final texts = await pumpHome(tester);

    expect(texts, contains("Perfect day — everything's done"));
    expect(texts, contains('$n of $n today · nice work'));
    expect(texts, contains('$n/$n'));
    expect(texts, contains('All doses taken — nice work'));
    expect(texts, contains('100%'),
        reason: 'a real 100% day must still say 100%');
  });

  pinnedTest('a skipped dose resolves the day without claiming it was taken',
      (tester) async {
    // Skipping is terminal: nothing is left to do, but "All doses taken" would
    // be false and "0 left today" alone tells the user nothing.
    final slots = await seedMed(past: 2);
    expect(slots.past, hasLength(2));
    await markTaken(slots.past.first);
    await MedicineCleanStorageService.addLog(MedicineLog.skipped(
      id: MedicineCleanStorageService.doseLogId('m1', slots.past[1]),
      medicineId: 'm1',
      scheduledTime: slots.past[1],
      reason: SkipReason.values.first,
    ));

    final texts = await pumpHome(tester);
    final screen = texts.join(' | ');

    expect(texts, contains('Nothing left today · 1 of 2 taken'));
    expect(screen, isNot(contains('All doses taken')));
    expect(screen, isNot(contains('Perfect day')));
    expect(texts, contains('50%'),
        reason: 'a skip is resolved, not taken — the ring tracks TAKEN');
  });

  /// The populated states, across every supported phone and text scale. The
  /// existing responsive sweep renders Home on an empty database, so none of
  /// this geometry — a 48px ring captioned "100%", a two-line dose status —
  /// was ever measured at 320pt or at 1.3x.
  pinnedTest('every populated state fits every supported phone',
      (tester) async {
    final slots = await seedMed(
      past: 1,
      future: 1,
      name: 'Hydrochlorothiazide',
    );
    await markTaken(slots.past.first);

    final overflows = <String>[];
    for (final width in const [320.0, 360.0, 375.0, 428.0]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        await pumpHome(tester,
            width: width, scale: scale, overflowSink: overflows);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }

    expect(overflows, isEmpty,
        reason: 'the populated Today dashboard overflowed:\n'
            '${overflows.join('\n')}');
  });

  /// The nudge strip and the Medicine card must not describe the same doses
  /// two incompatible ways.
  ///
  /// Found on device: the Today screen showed "You still have 5 doses left — a
  /// good moment to take them before the evening winds down." directly above a
  /// Medicine card reading "Nothing left today · 1 of 6 taken". Both numbers
  /// came from ONE `DailyMedicineSummary`; they disagreed because the card
  /// branched on `outstanding` (`total - taken - skipped - missed`) while the
  /// strip was handed `taken` and subtracted it from `total` itself, which
  /// counts a resolved dose as one you still owe. Urging someone to take five
  /// doses they deliberately skipped is the part that makes this more than a
  /// wording bug.
  testWidgets('the nudge never claims doses are left once all are resolved',
      (tester) async {
    // 19:00: the strip's highest-priority branch is "unfinished doses after
    // 18:00", which is the sentence that appeared on the device.
    final evening = () {
      final n = DateTime.now();
      return DateTime(n.year, n.month, n.day, 19, 0);
    }();

    await withClock(Clock.fixed(evening), () async {
      // Six doses, all already due. One taken, five deliberately skipped —
      // so nothing is outstanding, but `total - taken` is still 5.
      final slots = await seedMed(past: 6);
      expect(slots.past, hasLength(6),
          reason: 'the scenario needs six past slots to be expressible');

      await markTaken(slots.past.first);
      for (final slot in slots.past.skip(1)) {
        await MedicineCleanStorageService.addLog(MedicineLog.skipped(
          id: MedicineCleanStorageService.doseLogId('m1', slot),
          medicineId: 'm1',
          scheduledTime: slot,
          reason: SkipReason.notNeeded,
        ));
      }

      final texts = await pumpHome(tester);
      final joined = texts.join(' | ');

      // Premise: this really is the state that produced the contradiction.
      // Without it the assertions below would pass on a screen with no doses.
      expect(joined, contains('1 of 6 taken'),
          reason: 'the Medicine card must be in the resolved-but-not-all-taken '
              'state for this test to be able to fail. Screen was:\n$joined');

      expect(joined, isNot(contains('doses left')),
          reason: 'every dose is resolved — five of them skipped on purpose. '
              'Nothing is left to take. Screen was:\n$joined');
      expect(joined, isNot(contains('still have')),
          reason: 'the strip must not urge a dose that was deliberately '
              'skipped. Screen was:\n$joined');
      expect(joined, isNot(contains('next dose')),
          reason: 'there is no next dose today. Screen was:\n$joined');
    });
  });
}

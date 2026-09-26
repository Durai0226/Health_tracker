/// The rebuilt Weekly Recap screen.
///
/// The load-bearing test is [every ring stands for a real limit]. The screen
/// this replaces drew nine radial gauges, four of which had no denominator:
/// `bpAvg != null ? 1 : 0`, the same for glucose, `focusMinutes / 150`, and
/// `readingsLogged / 14`. `ProgressRing`'s painter only closes the circle at
/// exactly `1.0`, so the first two rendered the most emphatic mark that widget
/// can draw to say "this field is not null".
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
import 'package:tablet_remainder/core/utils/calendar_day.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/core/widgets/app/insight_kit.dart' show KpiCell;
import 'package:tablet_remainder/features/insights/screens/weekly_recap_screen.dart';
import 'package:tablet_remainder/features/insights/services/weekly_recap_service.dart';
import 'package:tablet_remainder/features/insights/services/trends_data_service.dart';
import 'package:tablet_remainder/features/insights/widgets/trend_chart_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  final fixedNow = DateTime(2026, 8, 26, 14, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  Future<void> pump(WidgetTester tester, {double height = 2400}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(390, height);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const WeeklyRecapScreen(),
    ));
    // Not pumpAndSettle: the skeleton shimmer repeats forever.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Iterable<String> texts(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => (t.data ?? '').trim())
      .where((s) => s.isNotEmpty);

  // ------------------------------------------------------- the nine rings

  /// A week with data in every series, built by hand.
  ///
  /// Necessary rather than fussy: every card is gated on `series.hasData`, and
  /// these tests run against an empty in-memory database — so pumping the screen
  /// renders NO cards and any assertion about them passes vacuously. The first
  /// version of the ring test below stayed green while a deliberately fabricated
  /// focus ring sat in the tree.
  WeeklyRecap fullWeek() {
    final days = [
      for (var i = 0; i < 7; i++) DateTime(2026, 8, 20).add(Duration(days: i)),
    ];
    TrendSeries s(double v, {double? goal, double? v2}) => TrendSeries(
          [for (final d in days) TrendPoint(d, v, v2)],
          goal: goal,
        );

    return WeeklyRecap(
      bundle: TrendsBundle(
        range: TrendRange.d7,
        adherence: s(90, goal: 100),
        // Water and steps carry REAL stored goals — the only honest rings.
        water: s(2100, goal: 2500),
        steps: s(8200, goal: 10000),
        sleep: s(7.2, goal: 8),
        // Focus has no goal anywhere in this app, which is the whole point.
        focus: s(35),
        bloodPressure: s(128, v2: 82),
        glucose: s(112),
        glucoseTir: const GlucoseTir(low: 2, inRange: 30, high: 6),
        weight: s(70.5),
        period: const TrendSeries([]),
        cycle: null,
      ),
      hero: const RecapHero(
          kind: RecapHeroKind.adherence, value: 90, denominator: 'across 7 days'),
      highlights: const [],
      from: DateTime(2026, 8, 20),
      to: DateTime(2026, 8, 26),
    );
  }

  group('no ring without a limit', () {
    testWidgets('the KpiCell ledger is gone entirely', (tester) async {
      await withClock(Clock.fixed(fixedNow), () => pump(tester));
      // All nine fabricated gauges lived in KpiCell. None of them survives.
      expect(find.byType(KpiCell), findsNothing,
          reason: 'the four denominator-free rings were KpiCells; if any comes '
              'back, check what its progress expression is a fraction OF');
    });

    testWidgets('every ring stands for a real limit', (tester) async {
      final cards = WeeklyRecapScreen.cardsFor(AppColorsExt.light, fullWeek());
      expect(cards, isNotEmpty, reason: 'the fixture must produce cards, or '
          'this test is checking nothing');

      var rings = 0;
      for (final c in cards.whereType<TrendRingCard>()) {
        rings++;
        expect(c.series.goal, isNotNull,
            reason: '${c.title} drew a ring with no goal behind it');
        expect(c.series.goal! > 0, isTrue);
      }
      expect(rings, greaterThan(0),
          reason: 'if no rings render at all the assertion above is vacuous');
    });

    testWidgets('focus is a bar, never a ring', (tester) async {
      // 150 minutes a week was a target nobody set. Focus has no goal in this
      // app, so it must come out as a chart card.
      final cards = WeeklyRecapScreen.cardsFor(AppColorsExt.light, fullWeek());
      expect(cards.whereType<TrendRingCard>().where((c) => c.title == 'Focus'),
          isEmpty);
      final focus = cards
          .whereType<TrendChartCard>()
          .where((c) => c.title == 'Focus');
      expect(focus, hasLength(1));
      expect(focus.single.kind, TrendChartKind.bar);
    });

    testWidgets('blood pressure is a two-series line on ONE axis',
        (tester) async {
      // The old screen rendered it as `bpAvg != null ? 1 : 0` — a closed circle
      // meaning "a value exists", beside text like "150/95".
      final cards = WeeklyRecapScreen.cardsFor(AppColorsExt.light, fullWeek());
      final bp = cards
          .whereType<TrendChartCard>()
          .where((c) => c.title == 'Blood pressure');
      expect(bp, hasLength(1));
      expect(bp.single.kind, TrendChartKind.line);
      // Both series are mmHg, which is what makes one axis correct.
      expect(bp.single.seriesLabels, ['Sys', 'Dia']);
      expect(cards.whereType<TrendRingCard>()
          .where((c) => c.title == 'Blood pressure'), isEmpty);
    });

    testWidgets('glucose is time-in-range, not a "a value exists" ring',
        (tester) async {
      final cards = WeeklyRecapScreen.cardsFor(AppColorsExt.light, fullWeek());
      expect(cards.whereType<TrendTimeInRangeCard>(), hasLength(1));
    });

    testWidgets('a tracker never used gets no card at all', (tester) async {
      // Period is empty in the fixture: somebody who does not menstruate must
      // not meet a permanently empty Cycle card on a page about their week.
      final cards = WeeklyRecapScreen.cardsFor(AppColorsExt.light, fullWeek());
      final titles = [
        for (final c in cards)
          switch (c) {
            TrendChartCard c => c.title,
            TrendRingCard c => c.title,
            TrendTimeInRangeCard c => c.title,
            _ => '',
          },
      ];
      expect(titles, isNot(contains('Cycle')));
      expect(titles, isNot(contains('Period')));
    });
  });

  // ------------------------------------------------------------ em dashes

  testWidgets('nothing renders a bare em dash', (tester) async {
    await withClock(Clock.fixed(fixedNow), () => pump(tester));
    // The old screen had four reachable '—' sites. A dash is what a screen
    // shows when it has given up; every one of those cases now has words.
    expect(texts(tester).where((t) => t == '—'), isEmpty,
        reason: 'found: ${texts(tester).toList()}');
  });

  // -------------------------------------------------------------- states

  group('the four states are distinguishable', () {
    testWidgets('frame one is a skeleton, not a spinner', (tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme, home: const WeeklyRecapScreen()));
        await tester.pump(const Duration(milliseconds: 1));

        // The regression that matters: the old screen showed a centred
        // CircularProgressIndicator, which tells the user nothing about the
        // shape of what is loading.
        expect(find.byType(CircularProgressIndicator), findsNothing,
            reason: 'a centred spinner says nothing about what is coming');

        // Asserting the CONFIGURATION rather than a rendered skeleton, because
        // an in-memory Drift database resolves inside the first pump — the
        // loading state is real on a device and unobservable here. Checking
        // what the screen hands AsyncSection is the honest version of this
        // test; AsyncSection's own tests cover that it renders it.
        final section = tester.widget<AsyncSection<WeeklyRecap>>(
            find.byType(AsyncSection<WeeklyRecap>));
        expect(section.skeleton, isA<PageSkeleton>());
        expect(section.onRetry, isNotNull,
            reason: 'the retry panel was unreachable on the old screen');
        expect(section.loadingSemanticLabel, isNotEmpty);

        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      });
    });

    testWidgets('an empty week says the history is still there',
        (tester) async {
      await withClock(Clock.fixed(fixedNow), () => pump(tester));
      // "You stopped" and "you are new" are different messages, and the old
      // screen said the second to both — including on a database failure.
      // The cover carries it; a second card repeating it in different words
      // reads as a bug.
      expect(find.textContaining('Nothing logged yet this week'),
          findsOneWidget);
      expect(find.textContaining('history is still here'), findsOneWidget);
      expect(find.textContaining('Start logging and your recap fills in'),
          findsNothing,
          reason: 'that was the first-run copy the old screen showed to '
              'everyone, failures included');
    });

    testWidgets('pull to refresh is available', (tester) async {
      await withClock(Clock.fixed(fixedNow), () => pump(tester));
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('the cover states the window it is describing', (tester) async {
      await withClock(Clock.fixed(fixedNow), () => pump(tester));
      // Aug 20 – Aug 26 for a fixed Wednesday. Stating the range beats
      // implying one.
      expect(find.textContaining('AUG 20'), findsOneWidget);
      expect(find.textContaining('AUG 26'), findsOneWidget);
    });
  });

  // ------------------------------------------------------------ the hero

  testWidgets('the hero carries a denominator or no number at all',
      (tester) async {
    await withClock(Clock.fixed(fixedNow), () => pump(tester));
    final all = texts(tester).toList();
    // With nothing logged there is no percentage to show, and no 0% either —
    // 0% would say the user took nothing.
    expect(all.any((t) => t == '0%'), isFalse);
    expect(all.any((t) => t.contains('Nothing logged yet this week')), isTrue);
  });

  // ------------------------------------------- the cover vs. the cards

  /// A week with water, steps, sleep and weight logged and NO medicines.
  ///
  /// The hero is medicine-only — `WeeklyRecapService._hero` reads dose
  /// summaries and nothing else — so this is the ordinary shape of a week for
  /// anybody who tracks health without tracking pills: no hero figure, and a
  /// full run of day-by-day cards underneath it.
  WeeklyRecap weekWithoutDoses({Set<String> failedSources = const {}}) {
    final days = [
      for (var i = 0; i < 7; i++) dayOffset(DateTime(2026, 8, 20), i),
    ];
    TrendSeries s(double v, {double? goal}) =>
        TrendSeries([for (final d in days) TrendPoint(d, v)], goal: goal);

    return WeeklyRecap(
      bundle: TrendsBundle(
        range: TrendRange.d7,
        adherence: const TrendSeries([]),
        water: s(2100, goal: 2500),
        steps: s(8200, goal: 10000),
        sleep: s(7.2, goal: 8),
        focus: const TrendSeries([]),
        bloodPressure: const TrendSeries([]),
        glucose: const TrendSeries([]),
        glucoseTir: GlucoseTir.empty,
        weight: s(70.5),
        period: const TrendSeries([]),
        cycle: null,
      ),
      // What `_hero` returns when no day had a dose due or taken.
      hero: const RecapHero(kind: RecapHeroKind.daysLogged),
      highlights: const [],
      from: DateTime(2026, 8, 20),
      to: DateTime(2026, 8, 26),
      failedSources: failedSources,
    );
  }

  Future<void> pumpCover(WidgetTester tester, WeeklyRecap r,
      {required bool hasCards}) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => WeeklyRecapScreen.coverFor(
              context, AppColorsExt.of(context), r,
              hasCards: hasCards),
        ),
      ),
    ));
    await tester.pump();
  }

  group('the cover never contradicts the cards below it', () {
    testWidgets('a week with cards is not called an empty week',
        (tester) async {
      final r = weekWithoutDoses();
      final cards = WeeklyRecapScreen.cardsFor(AppColorsExt.light, r);
      // Without this the assertions below are about a screen with nothing on
      // it, which is the state that was never broken.
      expect(cards, isNotEmpty,
          reason: 'the fixture must produce day-by-day cards');
      expect(r.hero.hasValue, isFalse,
          reason: 'the medicine-only hero is what has no figure');

      await pumpCover(tester, r, hasCards: cards.isNotEmpty);

      expect(find.textContaining('Nothing logged yet this week'), findsNothing,
          reason: 'that sentence rendered directly above ${cards.length} '
              'populated cards — the screen disagreeing with itself inside one '
              'viewport');
      expect(find.text('No doses to report this week.'), findsOneWidget);
    });

    testWidgets('a genuinely empty week still says so', (tester) async {
      await pumpCover(tester, weekWithoutDoses(), hasCards: false);
      expect(find.text('Nothing logged yet this week.'), findsOneWidget);
      expect(find.textContaining('history is still here'), findsOneWidget);
    });

    testWidgets('a failed adherence read is not reported as a quiet week',
        (tester) async {
      // A throw is not a zero. The partial banner already names what failed;
      // the cover must not turn it into a claim about the user's week.
      await pumpCover(tester, weekWithoutDoses(failedSources: {'adherence'}),
          hasCards: true);
      expect(find.textContaining('Nothing logged yet this week'), findsNothing);
      expect(find.textContaining("couldn't be loaded"), findsOneWidget);
    });

    /// The three above pump [WeeklyRecapScreen.coverFor] directly, so they pin
    /// the COPY but not the argument the screen feeds it. This one pumps the
    /// real screen against a real database, which is the only thing that can
    /// catch `hasCards:` being wired to the wrong value — and that wiring is
    /// the whole of the bug: the sentence was never wrong on its own, only
    /// wrong about what was underneath it.
    ///
    /// Focus is the seedable series here: `FocusService` is a process
    /// singleton with an import seam, while water, steps and sleep all need
    /// their own stores warmed first.
    testWidgets('the real screen agrees with its own cards', (tester) async {
      await FocusService().reloadSessionsFromDb();
      await FocusService().importSessionsJson([
        for (var i = 0; i < 3; i++)
          FocusSession(
            id: 'recap-focus-$i',
            startedAt: DateTime(2026, 8, 23 + i, 9, 0),
            completedAt: DateTime(2026, 8, 23 + i, 9, 45),
            targetMinutes: 45,
            actualMinutes: 45,
            wasCompleted: true,
            activityType: FocusActivityType.values.first,
            plantType: PlantType.values.first,
          ).toJson(),
      ]);

      await withClock(Clock.fixed(fixedNow), () => pump(tester));

      // No medicines were seeded, so the hero has no figure — the branch the
      // sentence lives in. Without a card below it the assertion that follows
      // would be about the empty week, which was never broken.
      expect(find.text('Focus'), findsOneWidget,
          reason: 'the seed must reach a day-by-day card');
      expect(find.textContaining('Nothing logged yet this week'), findsNothing,
          reason: 'the cover claimed an empty week directly above a populated '
              'one');
      expect(find.text('No doses to report this week.'), findsOneWidget);
    });
  });

  // --------------------------------------------------- the disclaimer stays

  testWidgets('the safety bar is still on the page', (tester) async {
    await withClock(Clock.fixed(fixedNow), () => pump(tester));
    expect(find.textContaining('not medical advice'), findsWidgets);
  });
}

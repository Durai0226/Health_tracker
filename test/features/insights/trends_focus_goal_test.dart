/// Trends must not invent a focus goal.
///
/// `kFocusDailyGoalMinutes = 60` lived in `trends_data_service.dart`, was fed
/// to the focus series as `TrendSeries.goal`, and came out the other end as a
/// progress RING with "target 60m/day" printed beside it — a target the user
/// never set, cannot change, and is not told is made up. Nothing in this app
/// stores a per-day focus goal: `focusWeeklyGoalMinutes` in
/// `analytics_service.dart` is read with a default and never written.
///
/// The Weekly Recap already refused to draw this ring (`weekly_recap_screen`:
/// "a ring against an invented denominator is the most confident-looking way
/// to be wrong"). Trends was the last surface still drawing it.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/insights/services/trends_data_service.dart';
import 'package:tablet_remainder/features/insights/widgets/trend_chart_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final fixedNow = DateTime(2026, 8, 26, 14, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    // FocusService is a process singleton and `init()` is one-shot, so point it
    // back at the fresh in-memory database instead.
    await FocusService().reloadSessionsFromDb();
  });

  tearDown(() async => db.close());

  /// Three days of finished sessions inside the 7-day window.
  ///
  /// Load-bearing: every goal-derived getter on [TrendSeries] returns null when
  /// there is no logged data, so on an empty database the focus card falls back
  /// to a bar whatever the goal says — and an assertion about rings would pass
  /// with the invented goal still in place.
  Future<void> seedFocus() async {
    final sessions = <Map<String, dynamic>>[
      for (var i = 0; i < 3; i++)
        FocusSession(
          id: 'focus-$i',
          startedAt: DateTime(2026, 8, 23 + i, 9, 0),
          completedAt: DateTime(2026, 8, 23 + i, 9, 45),
          targetMinutes: 45,
          actualMinutes: 45,
          wasCompleted: true,
          activityType: FocusActivityType.values.first,
          plantType: PlantType.values.first,
        ).toJson(),
    ];
    await FocusService().importSessionsJson(sessions);
  }

  test('the focus series carries no goal', () async {
    await seedFocus();
    final b = await withClock(
        Clock.fixed(fixedNow), () => TrendsDataService.build(TrendRange.d7));

    expect(b.focus.hasData, isTrue,
        reason: 'without focus data the assertions below are vacuous');
    expect(b.focus.goal, isNull,
        reason: '60 minutes a day was this file\'s number, not the user\'s');
    // The two getters that turn a goal into a claim about the user's progress.
    expect(b.focus.goalProgress, isNull);
    expect(b.focus.goalPercent, isNull);
  });

  test('the goals that are real are untouched', () async {
    // The fix must not take the honest reference lines with it. Sleep is the
    // one this can assert on an empty database: it reads the schedule's nightly
    // target, which has a real stored default behind it.
    //
    // Water and steps are deliberately absent: both lift their goal off the
    // LOGGED ROWS (`_water` reads `dailyGoalMl` per day, `_steps` reads
    // `goalSteps` per day), so with nothing logged there is genuinely no goal
    // to report — which is the same honesty this test is defending, not a
    // regression.
    final b = await withClock(
        Clock.fixed(fixedNow), () => TrendsDataService.build(TrendRange.d7));
    expect(b.sleep.goal, isNotNull);
  });

  testWidgets('a focus card built from the real series is a bar, not a ring',
      (tester) async {
    await seedFocus();
    final b = await withClock(
        Clock.fixed(fixedNow), () => TrendsDataService.build(TrendRange.d7));

    // NOT the call the dashboard makes any more — it now builds the focus
    // `TrendChartCard` directly. This pins the shared decision instead: given
    // the series the dashboard is handed, the rule that decides ring-vs-bar
    // says bar. What actually reaches the user on the dashboard is the goal
    // LINE: `_TrendBarChart` draws a `HorizontalLine` at `series.goal`, so the
    // focus bars carried a 60-minute reference nobody set. `the focus series
    // carries no goal` above is the assertion that removes it.
    final card = TrendGoalCard.build(
      ext: AppColorsExt.light,
      accent: AppColorsExt.light.focus,
      icon: Symbols.self_improvement_rounded,
      title: 'Focus',
      series: b.focus,
      days: 7,
      featureName: 'focus',
      formatValue: (v) => '${v.round()} min',
      centerValue: (gp) => '${(gp * 100).round()}%',
      centerCaption: 'avg/day',
      ringHeadline: (_) => 'target',
      barHeadline: 'total',
    );

    expect(card, isNot(isA<TrendRingCard>()),
        reason: 'a ring promises a denominator; focus has none');
    expect(card, isA<TrendChartCard>());
    expect((card as TrendChartCard).kind, TrendChartKind.bar);
  });
}

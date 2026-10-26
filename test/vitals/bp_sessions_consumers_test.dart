import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/insights/services/insight_service.dart';
import 'package:tablet_remainder/features/insights/services/trends_data_service.dart';
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_report_screen.dart';
import 'package:tablet_remainder/features/medication/services/condition_library_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

/// Every place that AVERAGES or CLASSIFIES blood pressure reads measurement
/// sessions, not raw rows: two readings a minute apart are one measurement.
///
/// `bp_sessions_test` pins the grouping; this pins that each consumer actually
/// uses it. Each case is built so the raw-row answer and the session answer
/// differ, so it fails if a consumer goes back to raw rows.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  Future<void> save(String id, int s, int d, DateTime at) =>
      VitalsStorageService.saveBp(BloodPressureReading(
          id: id, systolic: s, diastolic: d, takenAt: at, createdAt: at));

  test('Trends: a day averages its SESSIONS, so a doubled morning does not '
      'outweigh the evening', () async {
    final now = DateTime(2026, 8, 26, 21, 0);
    // Raw mean of the three: (150+150+110)/3 = 136.7. Per session: 130.
    await save('m1', 150, 90, DateTime(2026, 8, 26, 8, 0));
    await save('m2', 150, 90, DateTime(2026, 8, 26, 8, 1));
    await save('e1', 110, 70, DateTime(2026, 8, 26, 20, 0));

    final bundle = await withClock(
        Clock.fixed(now), () => TrendsDataService.build(TrendRange.d7));
    final today = bundle.bloodPressure.points.last;
    expect(today.value, 130, reason: 'systolic');
    expect(today.value2, 80, reason: 'diastolic: (90+70)/2');
  });

  test('Insights: two readings a minute apart count as ONE point toward the '
      'pattern gate', () async {
    // Four raw readings rising sharply. As raw rows that is four points and
    // fires a trend; as sessions it is two points, under the three needed.
    final d1 = DateTime.now().subtract(const Duration(days: 2));
    final d2 = DateTime.now().subtract(const Duration(days: 1));
    await save('a1', 110, 70, d1);
    await save('a2', 112, 72, d1.add(const Duration(minutes: 1)));
    await save('b1', 150, 95, d2);
    await save('b2', 152, 96, d2.add(const Duration(minutes: 1)));

    final insights = await InsightService.gatherAll();
    expect(insights.where((i) => i.id.startsWith('bp_')), isEmpty,
        reason: 'two sessions are not enough to call a pattern');
  });

  test('Insights: the same four readings spread out DO make a pattern '
      '(the premise of the test above)', () async {
    final base = DateTime.now().subtract(const Duration(days: 4));
    final sys = [110, 112, 150, 152];
    for (var i = 0; i < 4; i++) {
      await save('r$i', sys[i], 70 + i * 8, base.add(Duration(days: i)));
    }
    final insights = await InsightService.gatherAll();
    expect(insights.where((i) => i.id.startsWith('bp_')), isNotEmpty,
        reason: 'if this fails the fixture no longer reaches a BP insight and '
            'the test above proves nothing');
  });

  test('Condition card: the latest value is the latest SESSION average',
      () async {
    final now = DateTime.now();
    await save('a', 125, 78, now.subtract(const Duration(minutes: 2)));
    await save('b', 141, 79, now.subtract(const Duration(minutes: 1)));

    final r = await ConditionLibraryService.readingsFor('hypertension');
    expect(r!.latestValue, '133/79');
    expect(r.count, 2, reason: 'the count stays the raw number of readings');
  });

  testWidgets('BP report: Average is per session, Readings is the raw count',
      (tester) async {
    final now = DateTime.now();
    // Raw mean sys = (150+150+110)/3 = 137; per session = 130.
    await save('m1', 150, 90, now.subtract(const Duration(days: 1, minutes: 1)));
    await save('m2', 150, 90, now.subtract(const Duration(days: 1)));
    await save('e1', 110, 70, now.subtract(const Duration(hours: 2)));

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 3000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme, home: const BloodPressureReportScreen()));
    await tester.pumpAndSettle();

    expect(find.text('130/80'), findsOneWidget, reason: 'session average');
    expect(find.text('3'), findsWidgets, reason: 'three raw readings');
    expect(find.text('137/83'), findsNothing, reason: 'the raw-row mean');
  });
}

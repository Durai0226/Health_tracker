import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/models/mood_entry.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_report_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_report_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/mood_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/vitals_trend_chart.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

/// The vitals trend charts spaced readings evenly by index, so a burst of
/// readings an hour apart and a fortnight's gap drew the same distance apart.
/// The chart has a real time axis; every series has to be stamped to use it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  // Irregular on purpose: two hours apart, then a week, then a day. Distinct
  // days and gaps over ten minutes, so nothing collapses into one BP session.
  List<DateTime> stamps() {
    final n = DateTime.now();
    final base = DateTime(n.year, n.month, n.day, 9);
    return [
      base.subtract(const Duration(days: 9)),
      base.subtract(const Duration(days: 9, hours: -2)),
      base.subtract(const Duration(days: 2)),
      base.subtract(const Duration(days: 1)),
    ];
  }

  Future<void> seed() async {
    final ts = stamps();
    for (var i = 0; i < ts.length; i++) {
      await VitalsStorageService.saveBp(
        BloodPressureReading(
            id: 'bp$i',
            systolic: 120 + i,
            diastolic: 80 + i,
            takenAt: ts[i],
            createdAt: ts[i]),
        syncToHealthConnect: false,
      );
      await VitalsStorageService.saveGlucose(
        GlucoseReading(
            id: 'g$i', valueMgdl: 100 + i, takenAt: ts[i], createdAt: ts[i]),
        syncToHealthConnect: false,
      );
      await VitalsStorageService.saveMood(MoodEntry(
          id: 'm$i', moodIndex: i % 5, takenAt: ts[i], createdAt: ts[i]));
    }
  }

  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 2400);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {}; // layout is the responsive suite's job
    addTearDown(() => FlutterError.onError = prev);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: screen));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void expectStamped(WidgetTester tester, {required int charts}) {
    final found = tester.widgetList<VitalsTrendChart>(find.byType(VitalsTrendChart));
    expect(found, hasLength(charts));
    for (final c in found) {
      for (final s in c.series) {
        expect(s.times, isNotNull,
            reason: '${s.label} is not on the time axis');
        expect(s.times, hasLength(s.values.length));
        expect(s.axisTimes, isNotNull, reason: 'a mismatched list is ignored');
        // Oldest first, like the values.
        for (var i = 1; i < s.times!.length; i++) {
          expect(s.times![i].isBefore(s.times![i - 1]), isFalse);
        }
      }
    }
  }

  testWidgets('Blood pressure: systolic and diastolic are both stamped',
      (tester) async {
    await seed();
    await open(tester, const BloodPressureScreen());
    expectStamped(tester, charts: 2);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('Blood pressure report', (tester) async {
    await seed();
    await open(tester, const BloodPressureReportScreen());
    expectStamped(tester, charts: 2);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('Blood sugar', (tester) async {
    await seed();
    await open(tester, const BloodSugarScreen());
    expectStamped(tester, charts: 1);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('Blood sugar report', (tester) async {
    await seed();
    await open(tester, const BloodSugarReportScreen());
    expectStamped(tester, charts: 1);
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('Mood', (tester) async {
    await seed();
    await open(tester, const MoodScreen());
    expectStamped(tester, charts: 1);
    await tester.pump(const Duration(seconds: 8));
  });
}

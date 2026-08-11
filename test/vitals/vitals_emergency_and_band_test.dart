import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/vitals_analyzer.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/vitals_trend_chart.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

/// Two clinically-wrong-information regressions on the vitals screens:
///
///  1. The BP trend chart shaded ONE 80–120 mmHg band across BOTH series, so a
///     diastolic of 100 — Stage 2 hypertension by this app's own classifier —
///     was painted inside the green "normal" band.
///  2. The severe-low glucose emergency card had no recency bound, so a
///     severe low from days ago re-fired a false medical emergency.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  GlucoseReading glucose(int mgdl, DateTime at) => GlucoseReading(
        id: 'g_${at.microsecondsSinceEpoch}',
        valueMgdl: mgdl,
        context: GlucoseContext.fasting,
        takenAt: at,
        createdAt: at,
      );

  BloodPressureReading bp(int sys, int dia, DateTime at) => BloodPressureReading(
        id: 'bp_${at.microsecondsSinceEpoch}',
        systolic: sys,
        diastolic: dia,
        takenAt: at,
        createdAt: at,
      );

  // -------------------------------------------------------------------------
  // 1. BP trend band
  // -------------------------------------------------------------------------
  group('BP trend band tracks the app\'s own classification', () {
    test('band ceilings are exactly the BpCategory.normal boundaries', () {
      // Just inside both ceilings is Normal…
      expect(
        VitalsAnalyzer.classifyBp(BloodPressureScreen.normalSystolicMax - 1,
            BloodPressureScreen.normalDiastolicMax - 1),
        BpCategory.normal,
      );
      // …and at either ceiling the app stops calling it Normal, so that is
      // exactly where each series' shading has to stop.
      expect(
        VitalsAnalyzer.classifyBp(BloodPressureScreen.normalSystolicMax, 70),
        isNot(BpCategory.normal),
      );
      expect(
        VitalsAnalyzer.classifyBp(110, BloodPressureScreen.normalDiastolicMax),
        isNot(BpCategory.normal),
      );
    });

    test('regression: a hypertensive diastolic sits OUTSIDE the diastolic band',
        () {
      // The old shared band was 80–120, which swallowed this value whole.
      expect(VitalsAnalyzer.classifyBp(130, 100), BpCategory.stage2);
      expect(100, greaterThan(BloodPressureScreen.normalDiastolicMax));
    });

    testWidgets('each series gets its own chart and its own band',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 2000);
      addTearDown(tester.view.reset);

      final now = DateTime.now();
      await VitalsStorageService.saveBp(
          bp(130, 100, now.subtract(const Duration(hours: 2))));
      await VitalsStorageService.saveBp(
          bp(118, 76, now.subtract(const Duration(days: 1))));

      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const BloodPressureScreen()));
      await tester.pumpAndSettle();

      final charts =
          tester.widgetList<VitalsTrendChart>(find.byType(VitalsTrendChart));
      expect(charts.length, 2, reason: 'one chart per series');

      // No chart may carry two series under one band — that was the bug.
      for (final c in charts) {
        expect(c.series.length, 1);
      }
      expect(charts.first.bandHigh, BloodPressureScreen.normalSystolicMax);
      expect(charts.last.bandHigh, BloodPressureScreen.normalDiastolicMax);
      expect(charts.last.bandHigh, lessThan(charts.first.bandHigh!));

      // And the shading is explained rather than left to be guessed at.
      expect(find.textContaining('normal systolic (under 120 mmHg)'),
          findsOneWidget);
      expect(find.textContaining('normal diastolic (under 80 mmHg)'),
          findsOneWidget);
    });

    testWidgets('the split trend section still fits the 320pt floor at 2x text',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);

      final now = DateTime.now();
      await VitalsStorageService.saveBp(bp(178, 118, now));
      await VitalsStorageService.saveBp(
          bp(118, 76, now.subtract(const Duration(days: 1))));

      await tester.pumpWidget(const MediaQuery(
        data: MediaQueryData(size: Size(320, 568), textScaler: TextScaler.linear(2.0)),
        child: MaterialApp(home: BloodPressureScreen()),
      ));
      await tester.pumpAndSettle();
      // A RenderFlex overflow would surface here as a test failure.
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 2. Severe-low glucose emergency recency
  // -------------------------------------------------------------------------
  group('severe-low glucose emergency is recency bounded', () {
    final now = DateTime(2026, 5, 20, 14);

    test('a severe low from minutes ago is a live emergency', () {
      expect(
        BloodSugarScreen.showsSevereLowEmergency(
            glucose(45, now.subtract(const Duration(minutes: 10))), now),
        isTrue,
      );
    });

    test('the same severe low from days ago is not', () {
      expect(
        BloodSugarScreen.showsSevereLowEmergency(
            glucose(45, now.subtract(const Duration(days: 4))), now),
        isFalse,
      );
    });

    test('boundary: just inside the window fires, just outside does not', () {
      const w = BloodSugarScreen.emergencyCardWindow;
      expect(
        BloodSugarScreen.showsSevereLowEmergency(
            glucose(45, now.subtract(w - const Duration(minutes: 1))), now),
        isTrue,
      );
      expect(
        BloodSugarScreen.showsSevereLowEmergency(
            glucose(45, now.subtract(w)), now),
        isFalse,
      );
    });

    test('a recent but non-severe reading never fires', () {
      // 54 is the severe-low boundary: low, but not the emergency class.
      expect(VitalsAnalyzer.classifyGlucose(54, GlucoseContext.fasting),
          GlucoseClass.low);
      expect(
        BloodSugarScreen.showsSevereLowEmergency(
            glucose(54, now.subtract(const Duration(minutes: 1))), now),
        isFalse,
      );
      expect(
        BloodSugarScreen.showsSevereLowEmergency(glucose(110, now), now),
        isFalse,
      );
    });

    test('both vitals screens expire an emergency on the same window', () {
      expect(BloodSugarScreen.emergencyCardWindow,
          BloodPressureScreen.emergencyCardWindow);
    });

    testWidgets('fresh severe low still shows the emergency card',
        (tester) async {
      await VitalsStorageService.saveGlucose(
          glucose(42, DateTime.now().subtract(const Duration(minutes: 5))));

      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const BloodSugarScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Severe low blood sugar'), findsOneWidget);
    });

    testWidgets('stale severe low: no emergency card, class still shown',
        (tester) async {
      await VitalsStorageService.saveGlucose(
          glucose(42, DateTime.now().subtract(const Duration(days: 4))));

      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const BloodSugarScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Severe low blood sugar'), findsNothing);
      // The reading is not hidden or re-classified — only the "this is
      // happening now" emergency claim is withdrawn.
      expect(find.textContaining('Severe Low'), findsWidgets);
    });
  });
}

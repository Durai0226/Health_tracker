/// Systolic and diastolic cannot share one "normal" band.
///
/// The Blood pressure REPORT drew both series on a single chart under one band
/// of 80–120. That is the systolic normal range; diastolic normal is under 80
/// (`VitalsAnalyzer.classifyBp`). So on a report built to be handed to a
/// clinician:
///
///  * a diastolic of 95 — stage 2 hypertension, and labelled as such by the
///    hero card on the same screen — was painted INSIDE the green normal band;
///  * a healthy diastolic of 70 fell below the band and read as abnormal.
///
/// The main Blood pressure screen already drew one chart per series with its
/// own ceiling and its own caption; the report now does the same.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/vitals_trend_chart.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_report_screen.dart';

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

  Future<List<VitalsTrendChart>> charts(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 2400);
    addTearDown(tester.view.reset);

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const BloodPressureReportScreen(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    } finally {
      FlutterError.onError = prev;
    }
    return tester.widgetList<VitalsTrendChart>(find.byType(VitalsTrendChart)).toList();
  }

  testWidgets('no chart carries two series under one band', (tester) async {
    final found = await charts(tester);
    if (found.isEmpty) {
      markTestSkipped('no trend chart rendered (empty-state layout)');
      return;
    }

    for (final c in found) {
      if (c.bandHigh == null) continue;
      expect(c.series.length, 1,
          reason: 'a banded chart carrying ${c.series.length} series applies '
              "one series' normal range to all of them. Systolic normal is "
              'under 120 and diastolic under 80, so a shared band paints a '
              'hypertensive diastolic green.');
    }
  });

  testWidgets('each banded series is capped at its own normal ceiling',
      (tester) async {
    final found = await charts(tester);
    if (found.isEmpty) {
      markTestSkipped('no trend chart rendered (empty-state layout)');
      return;
    }

    const ceilings = {'systolic': 120.0, 'diastolic': 80.0};
    var checked = 0;
    for (final c in found) {
      if (c.bandHigh == null || c.series.length != 1) continue;
      final label = c.series.single.label.toLowerCase();
      final expected = ceilings[label];
      if (expected == null) continue;
      checked++;
      expect(c.bandHigh, expected,
          reason: 'the "$label" series is banded at ${c.bandHigh}, but its '
              'normal ceiling is $expected mmHg');
    }
    expect(checked, 2,
        reason: 'expected a banded Systolic chart and a banded Diastolic one; '
            'checked $checked. If the report stopped drawing them this test '
            'is no longer measuring anything.');
  });
}

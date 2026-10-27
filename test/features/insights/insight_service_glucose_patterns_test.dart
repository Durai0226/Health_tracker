/// Blood sugar by meal and hour, at the layer that feeds Trends: the glucose
/// log, read in the unit the person reads it in.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/insight.dart';
import 'package:tablet_remainder/core/health/vitals_analyzer.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/insights/services/insight_service.dart';
import 'package:tablet_remainder/features/insights/services/pattern_insights.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await StepService.resetForTesting();
    await SleepService.resetForTesting();
  });

  tearDown(() async => database.close());

  var seq = 0;
  Future<void> afterBreakfast(int daysAgo, int mgdl) {
    final n = DateTime.now();
    final at = DateTime(n.year, n.month, n.day - daysAgo, 9, 30);
    return VitalsStorageService.saveGlucose(GlucoseReading(
      id: 'g${seq++}',
      valueMgdl: mgdl,
      context: GlucoseContext.afterMeal,
      takenAt: at,
      createdAt: at,
    ));
  }

  Future<Insight?> byId(String id) async {
    for (final i in await InsightService.gatherAll()) {
      if (i.id == id) return i;
    }
    return null;
  }

  test('readings that run high after breakfast become an insight', () async {
    for (var d = 1; d <= 6; d++) {
      await afterBreakfast(d, 200);
    }
    final i = (await byId('glucose_pattern_after_breakfast_high'))!;
    expect(i.title, 'After breakfast readings often run high');
    expect(i.feature, InsightFeature.bloodSugar);
    expect(i.detail, contains('200 mg/dL'));
  });

  test('in mmol/L when that is how the person reads', () async {
    await CleanStorageService.setAppPreference('glucose_unit', 'mmoll');
    for (var d = 1; d <= 6; d++) {
      await afterBreakfast(d, 198);
    }
    final i = (await byId('glucose_pattern_after_breakfast_high'))!;
    expect(i.detail, contains('11.0 mmol/L'));
    expect(i.detail, isNot(contains('mg/dL')));
  });

  test('too few readings say nothing', () async {
    for (var d = 1; d <= 4; d++) {
      await afterBreakfast(d, 200);
    }
    expect(await byId('glucose_pattern_after_breakfast_high'), isNull);
  });

  test('and every one it produces is a pattern, with the family prefix', () {
    expect(PatternInsights.isPattern('glucose_pattern_after_breakfast_high'),
        isTrue);
    expect(PatternInsights.isPattern('glucose_pattern_overnight_low'), isTrue);
    expect(PatternInsights.isPattern('x_glucose_pattern_fasting_low'), isFalse);
    expect(PatternInsights.isPattern('gl_lows'), isFalse,
        reason: 'the existing nudge is not one');
  });

  test('a low pattern is worth attention, a high one a note', () async {
    for (var d = 1; d <= 6; d++) {
      await afterBreakfast(d, 200);
    }
    final n = DateTime.now();
    for (var d = 1; d <= 6; d++) {
      final at = DateTime(n.year, n.month, n.day - d, 7, 30);
      await VitalsStorageService.saveGlucose(GlucoseReading(
        id: 'f$d',
        valueMgdl: d <= 3 ? 60 : 95,
        context: GlucoseContext.fasting,
        takenAt: at,
        createdAt: at,
      ));
    }
    final high = (await byId('glucose_pattern_after_breakfast_high'))!;
    final low = (await byId('glucose_pattern_fasting_low'))!;
    expect(high.severity, InsightSeverity.info);
    expect(low.severity, InsightSeverity.attention);
    final groups = PatternInsights.group([high, low]);
    expect(groups.needsAttention.map((i) => i.id), ['glucose_pattern_fasting_low']);
    expect(groups.patterns.map((i) => i.id), ['glucose_pattern_after_breakfast_high']);
  });
}

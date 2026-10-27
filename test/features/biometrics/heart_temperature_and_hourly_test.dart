/// Heart: temperature and the hours of the day — stored all along, now shown.
///
/// Body temperature, skin temperature and the 24 hourly heart rates were in the
/// database and on no screen. Skin temperature comes in two quantities (a change
/// from your baseline on Android, the wrist temperature itself on iPhone) which
/// must never share a chart.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/biometrics/models/biometric_day.dart';
import 'package:tablet_remainder/features/biometrics/models/biometric_metric.dart';
import 'package:tablet_remainder/features/biometrics/screens/heart_dashboard_screen.dart';
import 'package:tablet_remainder/features/biometrics/services/biometrics_service.dart';
import 'package:tablet_remainder/features/biometrics/widgets/hourly_heart_rate_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    BiometricsService.clearInMemory();
    await BiometricsService.resetForTesting();
  });

  tearDown(() async => database.close());

  DateTime daysAgo(int n) {
    final t = DateTime.now();
    return DateTime(t.year, t.month, t.day - n);
  }

  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> seed({
    int days = 30,
    double? Function(int ago)? body,
    double? Function(int ago)? skin,
    SkinTempMetric? Function(int ago)? skinMetric,
    List<int?>? hourlyToday,
  }) async {
    for (var ago = 0; ago < days; ago++) {
      final d = daysAgo(ago);
      final v = skin?.call(ago);
      await database.biometricsDao.upsertDay(BiometricDay(
        id: key(d),
        date: d,
        createdAt: d,
        updatedAt: d,
        restingHr: 60,
        bodyTempAvgC: body?.call(ago),
        skinTempC: v,
        skinTempMetric: v == null ? null : skinMetric?.call(ago),
        hrSampleCount: ago == 0 && hourlyToday != null ? 100 : 0,
        hourlyHr: ago == 0 && hourlyToday != null ? hourlyToday : const [],
      ).toCompanion());
    }
    await BiometricsService.reloadFromDb();
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 4000);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const HeartDashboardScreen()));
      await tester.pump(const Duration(seconds: 7));
      await tester.pump(const Duration(milliseconds: 400));
    } finally {
      FlutterError.onError = prev;
    }
  }

  group('skin temperature is one quantity at a time', () {
    test('the most recent day decides which', () async {
      await seed(
        skin: (ago) => ago.isEven ? 0.3 : 34.2,
        skinMetric: (ago) => ago.isEven ? SkinTempMetric.deltaFromBaseline : SkinTempMetric.absolute,
      );
      final s = BiometricsService.skinTempSeries()!;
      expect(s.metric, SkinTempMetric.deltaFromBaseline, reason: 'today is even');
      expect(s.points.every((p) => p.value == 0.3), isTrue,
          reason: 'not one absolute 34.2 among the changes');
      expect(s.points, hasLength(15));
    });

    test('a day with no skin temperature is a gap, not a zero', () async {
      await seed(
        skin: (ago) => ago % 3 == 0 ? 0.2 : null,
        skinMetric: (_) => SkinTempMetric.deltaFromBaseline,
      );
      final s = BiometricsService.skinTempSeries()!;
      expect(s.points, hasLength(10));
      expect(s.points.every((p) => p.value == 0.2), isTrue);
    });

    test('none at all is none', () async {
      await seed();
      expect(BiometricsService.skinTempSeries(), isNull);
    });

    test('oldest first', () async {
      await seed(
        skin: (ago) => 30.0 + ago,
        skinMetric: (_) => SkinTempMetric.absolute,
      );
      final dates = BiometricsService.skinTempSeries()!.points.map((p) => p.date).toList();
      for (var i = 1; i < dates.length; i++) {
        expect(dates[i].isAfter(dates[i - 1]), isTrue);
      }
    });
  });

  group('the screen', () {
    testWidgets('body temperature has a chart of its own, in °C', (tester) async {
      await seed(body: (ago) => 36.5 + (ago.isEven ? 0.1 : -0.1));
      await pump(tester);
      expect(find.text('Body temperature'), findsOneWidget);
      expect(find.textContaining('°C'), findsWidgets);
    });

    testWidgets('a change from baseline says it is a change', (tester) async {
      await seed(skin: (ago) => 0.2, skinMetric: (_) => SkinTempMetric.deltaFromBaseline);
      await pump(tester);
      expect(find.text('Skin temperature change'), findsOneWidget);
      expect(find.textContaining('from your own baseline'), findsOneWidget);
    });

    testWidgets('the wrist temperature says it is the temperature', (tester) async {
      await seed(skin: (ago) => 34.0 + ago * 0.01, skinMetric: (_) => SkinTempMetric.absolute);
      await pump(tester);
      expect(find.text('Skin temperature'), findsOneWidget);
      expect(find.textContaining('Overnight wrist temperature'), findsOneWidget);
      expect(find.text('Skin temperature change'), findsNothing);
    });

    testWidgets('neither is drawn when the wearable reports neither', (tester) async {
      await seed();
      await pump(tester);
      expect(find.text('Body temperature'), findsNothing);
      expect(find.textContaining('Skin temperature'), findsNothing);
    });

    testWidgets('the hours of today are drawn when the wearable gave them', (tester) async {
      await seed(hourlyToday: [
        for (var h = 0; h < 24; h++) h < 6 ? 52 + h : (h > 7 && h < 22 ? 70 + h : null)
      ]);
      await pump(tester);
      expect(find.byType(HourlyHeartRateCard), findsOneWidget);
      expect(find.text('Heart rate by hour'), findsOneWidget);
      expect(find.textContaining('Lowest 52 bpm around 12 am'), findsOneWidget);
    });

    testWidgets('and not when it did not', (tester) async {
      await seed();
      await pump(tester);
      expect(find.text('Heart rate by hour'), findsNothing);
    });
  });
}

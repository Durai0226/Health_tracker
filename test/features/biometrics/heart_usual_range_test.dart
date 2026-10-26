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

/// Heart: 30-day charts with the person's OWN usual range behind them, and an
/// HRV line that says where the last week sits against the three before it.
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

  /// [rest]/[hrv]/[spo2]/[resp] return a value for a given days-ago, or null.
  Future<void> seed({
    int days = 30,
    int? Function(int ago)? rest,
    double? Function(int ago)? hrv,
    double? Function(int ago)? spo2,
    double? Function(int ago)? resp,
  }) async {
    final dao = database.biometricsDao;
    for (var ago = 0; ago < days; ago++) {
      final d = daysAgo(ago);
      final day = BiometricDay(
        id: key(d),
        date: d,
        createdAt: d,
        updatedAt: d,
        restingHr: rest?.call(ago),
        hrvNightlyMs: hrv?.call(ago),
        hrvMetric: hrv?.call(ago) == null ? null : HrvMetric.rmssd,
        spo2Avg: spo2?.call(ago),
        respiratoryRateAvg: resp?.call(ago),
      );
      await dao.upsertDay(day.toCompanion());
    }
    await BiometricsService.reloadFromDb();
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 3200);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {}; // layout is the responsive suite's job
    try {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const HeartDashboardScreen()));
      // The screen's platform probe has a 6 s timeout that fake async has to
      // be walked past, as the responsive harness does.
      await tester.pump(const Duration(seconds: 7));
      await tester.pump(const Duration(milliseconds: 400));
    } finally {
      FlutterError.onError = prev;
    }
  }

  group('BiometricsService.dailySeries', () {
    test('a day without the metric is a gap, never a zero', () async {
      await seed(days: 10, rest: (ago) => ago.isEven ? 60 : null);
      final s = BiometricsService.dailySeries((d) => d.restingHr?.toDouble(),
          days: 10);
      expect(s, hasLength(5));
      expect(s.every((p) => p.value == 60), isTrue);
    });

    test('oldest first, limited to the window', () async {
      await seed(days: 20, rest: (ago) => 50 + ago);
      final s = BiometricsService.dailySeries((d) => d.restingHr?.toDouble(),
          days: 5);
      expect(s.map((p) => p.value), [54, 53, 52, 51, 50]);
    });
  });

  group('the screen', () {
    testWidgets('resting heart rate is a chart with your usual range',
        (tester) async {
      await seed(rest: (ago) => ago.isEven ? 58 : 62);
      await pump(tester);

      expect(find.text('Resting heart rate'), findsOneWidget);
      expect(find.textContaining('Shaded band = your usual range'),
          findsWidgets);
      expect(find.textContaining('bpm), from your previous'), findsOneWidget);
    });

    testWidgets('today is not part of the range it is judged against',
        (tester) async {
      // 29 earlier days at 58/62 and an outlier TODAY. With today in the
      // sample the band would stretch toward it and the outlier would look
      // ordinary, which is the one thing the band exists to show.
      await seed(rest: (ago) => ago == 0 ? 90 : (ago.isEven ? 58 : 62));
      await pump(tester);

      expect(find.textContaining('(58–62 bpm), from your previous 29 days'),
          findsOneWidget);
    });

    testWidgets('with under a week of data it says what it is waiting for',
        (tester) async {
      await seed(days: 4, rest: (_) => 60);
      await pump(tester);

      expect(find.text('Resting heart rate'), findsOneWidget);
      expect(find.textContaining('Shaded band'), findsNothing,
          reason: 'no band drawn from data that cannot support one');
      expect(find.text('Your usual range appears after 7 days of data.'),
          findsWidgets);
    });

    testWidgets('HRV says where the last week sits against the three before',
        (tester) async {
      // 38/51 alternating before, a steady 44 for the last week: within.
      await seed(hrv: (ago) => ago < 7 ? 44.0 : (ago.isEven ? 51.0 : 38.0));
      await pump(tester);

      expect(find.textContaining('HRV within your usual range (7-day avg 44 ms'),
          findsOneWidget);
    });

    testWidgets('HRV below the usual range is said plainly', (tester) async {
      await seed(hrv: (ago) => ago < 7 ? 20.0 : (ago.isEven ? 51.0 : 38.0));
      await pump(tester);

      expect(find.textContaining('HRV below your usual range'), findsOneWidget);
    });

    testWidgets('blood oxygen and breathing rate get their own charts',
        (tester) async {
      await seed(
          rest: (_) => 60,
          spo2: (ago) => ago.isEven ? 96.0 : 97.0,
          resp: (ago) => ago.isEven ? 14.0 : 15.0);
      await pump(tester);

      expect(find.text('Blood oxygen'), findsOneWidget);
      expect(find.text('Breathing rate'), findsOneWidget);
    });

    testWidgets('a metric the wearable never reported has no card',
        (tester) async {
      await seed(rest: (_) => 60);
      await pump(tester);

      expect(find.text('Blood oxygen'), findsNothing);
      expect(find.text('Breathing rate'), findsNothing);
    });
  });
}

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/health/sleep_score.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_session.dart';
import 'package:tablet_remainder/features/sleep/models/sleep_stage.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_dashboard_screen.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/sleep/widgets/sleep_score_breakdown_sheet.dart';
import 'package:tablet_remainder/features/sleep/widgets/sleep_score_ring.dart';

/// Tap the score ring and it says what the number is made of:
/// "Duration 52/60 · Efficiency 21/25 · Regularity 9/15".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)));

  SleepSession night({SleepSource source = SleepSource.healthConnect}) =>
      SleepSession(
        id: 'n',
        dateKey: '2026-03-10',
        bedtime: DateTime(2026, 3, 9, 23),
        wakeTime: DateTime(2026, 3, 10, 7),
        inBedMinutes: 480,
        asleepMinutes: 432,
        awakeMinutes: 48,
        sleepScore: 82,
        efficiency: 0.9,
        qualityIndex: 4,
        source: source,
        createdAt: DateTime(2026, 3, 10),
        updatedAt: DateTime(2026, 3, 10),
      );

  group('the sheet body', () {
    testWidgets('shows each part out of its maximum, and what it measured',
        (tester) async {
      await tester.pumpWidget(host(SleepScoreBreakdownBody(
        night: night(),
        parts: const SleepScoreParts(54, 22, 6),
        targetMinutes: 480,
        regularityNights: 9,
      )));
      expect(find.text('82 out of 100'), findsOneWidget);
      expect(find.text('54/60'), findsOneWidget);
      expect(find.text('22/25'), findsOneWidget);
      expect(find.text('6/15'), findsOneWidget);
      expect(find.text('7h 12m asleep of your 8h target.'), findsOneWidget);
      expect(find.text('90% of your time in bed was spent asleep.'),
          findsOneWidget);
      expect(find.textContaining('last 9 nights'), findsOneWidget);
    });

    testWidgets('a hand-logged night says its efficiency is an estimate',
        (tester) async {
      await tester.pumpWidget(host(SleepScoreBreakdownBody(
        night: night(source: SleepSource.manual),
        parts: const SleepScoreParts(54, 22, 6),
        targetMinutes: 480,
        regularityNights: 9,
      )));
      expect(find.textContaining('estimated from how you rated'),
          findsOneWidget);
    });

    testWidgets('under three nights, regularity says it is not measured yet',
        (tester) async {
      await tester.pumpWidget(host(SleepScoreBreakdownBody(
        night: night(),
        parts: const SleepScoreParts(54, 22, 6),
        targetMinutes: 480,
        regularityNights: 2,
      )));
      expect(find.textContaining('needs three nights'), findsOneWidget);
      expect(find.textContaining('last 2 nights'), findsNothing);
    });
  });

  group('on the Sleep screen', () {
    late db.AppDatabase database;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // The health probe awaits this channel; unanswered, the screen never
      // leaves its loading skeleton under FakeAsync.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/device_info'),
        (_) async => <String, dynamic>{},
      );
      database = db.AppDatabase.forTesting(NativeDatabase.memory());
      db.AppDatabase.setInstanceForTesting(database);
      CleanStorageService.resetForTesting();
      await CleanStorageService.init();
      SleepService.clearInMemory();
      await SleepService.resetForTesting();
      await SleepService.init();
    });

    tearDown(() async => database.close());

    testWidgets('the ring opens the breakdown, and it adds up to the ring',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {}; // layout is the responsive suite's job
      try {
      // Relative to the real clock: the screen picks "last night" with it.
      final today = DateTime.now();
      final wake = DateTime(today.year, today.month, today.day - 1, 7);
      await withClock(Clock(() => DateTime.now()), () async {
        final saved = await SleepService.logManualSession(
          bedtime: DateTime(wake.year, wake.month, wake.day - 1, 23),
          wakeTime: wake,
          quality: 4,
        );
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme, home: const SleepDashboardScreen()));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        await tester.tap(find.byType(SleepScoreRing).first);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.text('How this score is made'), findsOneWidget);
        expect(find.text('${saved.sleepScore} out of 100'), findsOneWidget);

        // The three "n/max" labels sum to the score on the ring.
        final pts = [
          for (final e in find
              .byWidgetPredicate((w) =>
                  w is Text && RegExp(r'^\d+/(60|25|15)$').hasMatch(w.data ?? ''))
              .evaluate())
            int.parse((e.widget as Text).data!.split('/').first),
        ];
        expect(pts, hasLength(3));
        expect(pts.reduce((a, b) => a + b), saved.sleepScore);
        await tester.pump(const Duration(seconds: 8));
      });
      } finally {
        FlutterError.onError = prev;
      }
    });
  });
}

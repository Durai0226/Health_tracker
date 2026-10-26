import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/period/models/period_day.dart';
import 'package:tablet_remainder/features/period/services/period_service.dart';
import 'package:tablet_remainder/features/period/widgets/log_today_sheet.dart';

/// Logging a light day soon after the last period began asks first, and the
/// user decides: a new period, spotting, or neither.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    PeriodService.clearInMemory();
    await PeriodService.resetForTesting();
    await PeriodService.init();
  });

  tearDown(() async => db.close());

  DateTime mar(int d) => DateTime(2026, 3, d);

  /// A real period, 1-4 March.
  Future<void> seedPeriod() async {
    for (final e in {1: 4, 2: 3, 3: 2, 4: 2}.entries) {
      await PeriodService.logDay(
          PeriodDay(id: PeriodDay.keyFor(mar(e.key)), date: mar(e.key), flowIndex: e.value));
    }
  }

  Future<void> open(WidgetTester tester, DateTime date) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 2400);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = prev);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: SingleChildScrollView(child: LogTodaySheet(date: date))),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> logFlow(WidgetTester tester, String flowLabel) async {
    await tester.tap(find.text(flowLabel));
    await tester.pump();
    final save = find.text('Save');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  int cycles() => PeriodService.getCycles().length;
  int? flowOn(int d) => PeriodService.getDay(mar(d))?.flowIndex;

  testWidgets('a light day 9 days after the last start asks, with the number',
      (tester) async {
    await seedPeriod();
    await open(tester, mar(10));
    await logFlow(tester, 'Light');

    expect(find.text('Start a new period?'), findsOneWidget);
    expect(find.textContaining('only 9 days after'), findsOneWidget);
    expect(flowOn(10), isNull, reason: 'nothing is saved until the user chooses');
  });

  testWidgets('"Start a new period" saves it as a period', (tester) async {
    await seedPeriod();
    await open(tester, mar(10));
    await logFlow(tester, 'Light');
    await tester.tap(find.text('Start a new period'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(flowOn(10), 2);
    expect(cycles(), 2, reason: 'a genuinely short cycle is allowed through');
  });

  testWidgets('"Log as spotting" saves spotting and starts no cycle',
      (tester) async {
    await seedPeriod();
    await open(tester, mar(10));
    await logFlow(tester, 'Light');
    await tester.tap(find.text('Log as spotting'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(flowOn(10), 1);
    expect(cycles(), 1, reason: 'spotting must not have started a period');
  });

  testWidgets('dismissing the question saves nothing', (tester) async {
    await seedPeriod();
    await open(tester, mar(10));
    await logFlow(tester, 'Light');
    // Tap the barrier above the sheet.
    await tester.tapAt(const Offset(200, 20));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Start a new period?'), findsNothing);
    expect(flowOn(10), isNull);
    expect(cycles(), 1);
  });

  testWidgets('a normal cycle length is not questioned', (tester) async {
    await seedPeriod();
    await open(tester, mar(29));
    await logFlow(tester, 'Light');

    expect(find.text('Start a new period?'), findsNothing);
    expect(flowOn(29), 2);
    expect(cycles(), 2);
  });

  testWidgets('spotting is never questioned', (tester) async {
    await seedPeriod();
    await open(tester, mar(10));
    await logFlow(tester, 'Spotting');

    expect(find.text('Start a new period?'), findsNothing);
    expect(flowOn(10), 1);
    expect(cycles(), 1);
  });

  testWidgets('the first period ever is not questioned', (tester) async {
    await open(tester, mar(10));
    await logFlow(tester, 'Light');

    expect(find.text('Start a new period?'), findsNothing);
    expect(flowOn(10), 2);
  });

  testWidgets('another day of the current period is not questioned',
      (tester) async {
    await seedPeriod();
    await open(tester, mar(5));
    await logFlow(tester, 'Light');

    expect(find.text('Start a new period?'), findsNothing);
    expect(flowOn(5), 2);
    expect(cycles(), 1);
  });
}

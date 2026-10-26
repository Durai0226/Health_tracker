import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/home/widgets/log_something_sheet.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/period/models/period_day.dart';
import 'package:tablet_remainder/features/period/services/period_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';

/// Steps, sleep and period were the three quick-logs that wrote silently, with
/// no confirmation and no way back short of finding the entry again. Water and
/// doses already had an Undo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    ActiveProfileService().resetForTesting();
    StepService.clearInMemory();
    await StepService.resetForTesting();
    await StepService.init();
    PeriodService.clearInMemory();
    await PeriodService.resetForTesting();
    await PeriodService.init();
  });

  tearDown(() async => db.close());

  Future<void> host(WidgetTester tester, Future<void> Function(BuildContext) log) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
                onPressed: () => log(context), child: const Text('open')),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('logging steps confirms what was added, and Undo takes it back',
      (tester) async {
    await host(tester, LogSomethingSheet.logSteps);
    expect(StepService.getTodayData().manualEntries, isEmpty);

    await tester.tap(find.text('+1K'));
    await tester.pump();
    await tester.tap(find.textContaining('Add').last);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(StepService.getTodayData().manualEntries, hasLength(1));
    expect(find.text('Added 1,000 steps'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(StepService.getTodayData().manualEntries, isEmpty,
        reason: 'the entry is gone, not just hidden');
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('steps added to an earlier day can be undone too', (tester) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await host(tester, LogSomethingSheet.logSteps);

    await tester.tap(find.text('Yesterday'));
    await tester.pump();
    await tester.tap(find.text('+1K'));
    await tester.pump();
    await tester.tap(find.textContaining('Add').last);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(StepService.getDataForDate(yesterday)!.manualEntries, hasLength(1));
    expect(StepService.getTodayData().manualEntries, isEmpty);

    await tester.tap(find.text('Undo'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(StepService.getDataForDate(yesterday)!.manualEntries, isEmpty,
        reason: 'removeManualEntry only looked at today, so this could never '
            'have been taken back');
    await tester.pump(const Duration(seconds: 8));
  });

  group('sleep', () {
    testWidgets('a new night is confirmed and Undo removes it', (tester) async {
      await host(tester, LogSomethingSheet.logSleep);
      expect(SleepService.getAllSessions(), isEmpty);

      await tester.tap(find.text('Save sleep'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(SleepService.getAllSessions(), hasLength(1));
      expect(find.text('Sleep logged'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(SleepService.getAllSessions(), isEmpty);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('a night that REPLACED an earlier one comes back as it was on '
        'Undo, not deleted', (tester) async {
      // Log once, then log again for the same night.
      await host(tester, LogSomethingSheet.logSleep);
      await tester.tap(find.text('Save sleep'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final first = SleepService.getAllSessions().single;

      await tester.tap(find.text('open'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // A different rating, so the second save is an edit with a different row.
      await tester.tap(find.bySemanticsLabel('Rate 1 of 5'));
      await tester.pump();
      await tester.tap(find.text('Save sleep'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(SleepService.getAllSessions().single.qualityIndex, 1,
          reason: 'premise: the second log replaced the first');

      await tester.tap(find.text('Undo'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final back = SleepService.getAllSessions();
      expect(back, hasLength(1), reason: 'the first night must not be lost');
      expect(back.single.qualityIndex, first.qualityIndex);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  group('period', () {
    testWidgets('a new day is confirmed and Undo removes it', (tester) async {
      await host(tester, LogSomethingSheet.logPeriod);
      expect(PeriodService.days, isEmpty);

      await tester.tap(find.text('Medium'));
      await tester.pump();
      final save = find.text('Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(PeriodService.days, hasLength(1));
      expect(find.text('Period log saved'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(PeriodService.days, isEmpty);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('an edited day goes back to what it was', (tester) async {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      await PeriodService.logDay(PeriodDay(
          id: PeriodDay.keyFor(day), date: day, flowIndex: 2));

      await host(tester, LogSomethingSheet.logPeriod);
      await tester.tap(find.text('Heavy'));
      await tester.pump();
      final save = find.text('Save');
      await tester.ensureVisible(save);
      await tester.tap(save);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(PeriodService.getDay(day)!.flowIndex, 4, reason: 'premise');

      await tester.tap(find.text('Undo'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(PeriodService.getDay(day)!.flowIndex, 2);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('closing the sheet without saving shows nothing', (tester) async {
      await host(tester, LogSomethingSheet.logPeriod);
      await tester.tapAt(const Offset(10, 10)); // the scrim
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Period log saved'), findsNothing);
      await tester.pump(const Duration(seconds: 8));
    });
  });
}

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/mood_entry.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:tablet_remainder/features/period/services/period_service.dart';
import 'package:tablet_remainder/features/period/widgets/log_today_sheet.dart';

/// One mood per day: the face tapped on the period sheet and the mood logged on
/// the mood screen are the same record, on scales that run in opposite
/// directions. These tests read back what was STORED, since a face that
/// highlights while a duplicate entry is written (or none at all) is the
/// failure worth catching.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  // Use today: the sheet treats "today" specially when stamping the entry.
  final today = DateTime.now();
  final date = DateTime(today.year, today.month, today.day);

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

  Future<void> open(WidgetTester tester, {DateTime? on}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
          body: SingleChildScrollView(child: LogTodaySheet(date: on ?? date))),
    ));
    // The in-memory database answers on microtasks, which pumps drain.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> save(WidgetTester tester) async {
    final b = find.text('Save');
    await tester.ensureVisible(b);
    await tester.tap(b);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// An entry logged a few minutes ago. Not "now": Drift keeps timestamps to
  /// the second, so an entry seeded in the same second as the one the sheet
  /// writes would tie on `createdAt` and "which was last" would be a coin flip.
  Future<void> logEntry(int moodIndex, {DateTime? at}) {
    final earlier = DateTime.now().subtract(const Duration(minutes: 5));
    return VitalsStorageService.saveMood(MoodEntry(
      id: 'm-${earlier.microsecondsSinceEpoch}',
      moodIndex: moodIndex,
      takenAt: at ?? earlier,
      createdAt: earlier,
    ));
  }

  Future<List<MoodEntry>> entries() => VitalsStorageService.getAllMood();

  Finder face(IconData i) => find.byIcon(i);

  /// A widget test whose layout-overflow reports are dropped and, crucially,
  /// restored in a `finally` — a handler restored in `addTearDown` runs after
  /// the framework has already checked it was put back.
  void sheetTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {}; // layout is the responsive suite's job
      try {
        await body(tester);
      } finally {
        FlutterError.onError = prev;
      }
    });
  }

  sheetTest('a mood already logged today fills the face in, and is NOT '
      'logged a second time', (tester) async {
    await logEntry(0); // Great
    await open(tester);
    await save(tester);

    expect(PeriodService.getDay(date)?.mood, 5,
        reason: 'Great in the log is the best face (5) on the period sheet');
    expect((await entries()), hasLength(1),
        reason: 'the same answer must not be stacked as a second entry');
  });

  sheetTest('a face tapped with nothing logged becomes the day\'s mood in '
      'the log, on the mood log\'s scale', (tester) async {
    await open(tester);
    await tester.tap(face(Symbols.sentiment_dissatisfied_rounded)); // 2
    await tester.pump();
    await save(tester);

    expect(PeriodService.getDay(date)?.mood, 2);
    final e = (await entries());
    expect(e, hasLength(1));
    expect(e.single.moodIndex, 3, reason: '2 of 5 is "Bad" (3) in the log');
    expect(e.single.label, 'Bad');
    final t = e.single.takenAt;
    expect(DateTime(t.year, t.month, t.day), date,
        reason: 'it belongs to the day the sheet was for');
  });

  sheetTest('changing it to something else logs the new answer', (tester) async {
    await logEntry(0); // Great
    await open(tester);
    await tester.tap(face(Symbols.sentiment_very_dissatisfied_rounded)); // 1
    await tester.pump();
    await save(tester);

    final e = (await entries())..sort(
        (a, b) => a.createdAt.compareTo(b.createdAt));
    expect(e, hasLength(2));
    expect(e.last.moodIndex, 4, reason: '1 of 5 is "Terrible" (4)');
    expect(PeriodService.getDay(date)?.mood, 1);
  });

  sheetTest('no mood chosen logs nothing', (tester) async {
    await open(tester);
    await save(tester);
    expect((await entries()), isEmpty);
  });

  sheetTest('a past day is stamped at midday on THAT day', (tester) async {
    final past = DateTime(date.year, date.month, date.day - 3);
    await open(tester, on: past);
    await tester.tap(face(Symbols.sentiment_satisfied_rounded)); // 4
    await tester.pump();
    await save(tester);

    final e = (await entries()).single;
    expect(e.moodIndex, 1);
    expect(DateTime(e.takenAt.year, e.takenAt.month, e.takenAt.day), past);
    expect(e.takenAt.hour, 12);
  });

  sheetTest('the mood-log entry of ANOTHER day does not leak in',
      (tester) async {
    await logEntry(0, at: DateTime(date.year, date.month, date.day - 1, 10));
    await open(tester);
    await save(tester);

    expect(PeriodService.getDay(date)?.mood, isNull);
    expect((await entries()), hasLength(1));
  });
}

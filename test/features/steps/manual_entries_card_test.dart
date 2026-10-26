import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/steps/models/step_manual_entry.dart';
import 'package:tablet_remainder/features/steps/screens/steps_dashboard_screen.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:tablet_remainder/features/steps/widgets/manual_step_entries_card.dart';

/// Manual steps were summed into the day and shown nowhere, so a mistyped
/// 10,000 could only be corrected by typing a negative entry. Today's entries
/// are listed now, each removable, with an Undo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late db.AppDatabase database;
  final now = DateTime(2026, 3, 12, 13);

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    StepService.clearInMemory();
    await StepService.resetForTesting();
    await StepService.init();
  });

  tearDown(() async => database.close());

  group('ManualStepEntriesCard', () {
    StepManualEntry entry(int steps, {String? note}) => StepManualEntry(
        id: 'e$steps',
        dailyDataId: '2026-03-12',
        time: DateTime(2026, 3, 12, 9, 15),
        steps: steps,
        note: note);

    Widget host(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: SingleChildScrollView(child: child)));

    testWidgets('nothing to show, nothing drawn', (tester) async {
      await tester.pumpWidget(
          host(ManualStepEntriesCard(entries: const [], onRemove: (_) {})));
      expect(find.text('Added by hand'), findsNothing);
    });

    testWidgets('lists each entry with its time and note, and a minus sign '
        'for a trim', (tester) async {
      await tester.pumpWidget(host(ManualStepEntriesCard(
        entries: [entry(1000, note: 'Morning walk'), entry(-300)],
        onRemove: (_) {},
      )));
      expect(find.text('+1,000 steps'), findsOneWidget);
      expect(find.text('9:15 AM · Morning walk'), findsOneWidget);
      expect(find.text('−300 steps'), findsOneWidget);
    });

    testWidgets('removing reports which entry', (tester) async {
      final removed = <String>[];
      await tester.pumpWidget(host(ManualStepEntriesCard(
        entries: [entry(1000), entry(500)],
        onRemove: (e) => removed.add(e.id),
      )));
      await tester.tap(find.byTooltip('Remove this entry').last);
      expect(removed, ['e500']);
    });
  });

  group('on the Steps screen', () {
    Future<void> open(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 1800);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {}; // overflow is the responsive suite's job
      try {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme, home: const StepsDashboardScreen()));
        for (var f = 0; f < 8; f++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      } finally {
        FlutterError.onError = prev;
      }
    }

    testWidgets('a mistyped entry can be removed, and put back', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await StepService.addManualSteps(10000, note: 'oops');
        await open(tester);
        expect(find.text('Added by hand'), findsOneWidget);
        expect(find.text('+10,000 steps'), findsOneWidget);

        await tester.tap(find.byTooltip('Remove this entry'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(StepService.getTodayData().manualEntries, isEmpty);
        expect(find.text('Entry removed'), findsOneWidget);
        expect(find.text('Added by hand'), findsNothing);

        await tester.tap(find.text('Undo'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final back = StepService.getTodayData().manualEntries;
        expect(back, hasLength(1));
        expect(back.single.steps, 10000);
        expect(back.single.note, 'oops');
        await tester.pump(const Duration(seconds: 8));
      });
    });

    testWidgets('no card when nothing was typed in', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await open(tester);
        expect(find.text('Added by hand'), findsNothing);
        await tester.pump(const Duration(seconds: 8));
      });
    });
  });
}

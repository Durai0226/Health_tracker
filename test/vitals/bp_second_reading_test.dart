import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/vitals_widgets.dart' show VitalsStatusHero;
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/bp_second_reading_sheet.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

/// Two-reading blood-pressure sessions.
///
/// Three things matter and each has a test that fails without it:
///  * the session average is what the hero card and averages show, while every
///    raw reading stays in History;
///  * averaging can NEVER hide a crisis — the emergency card follows the latest
///    raw reading;
///  * the second-reading offer appears after a normal new reading, once, and
///    never after a crisis, an edit, a back-dated reading or the second reading
///    itself.
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

  BloodPressureReading bp(String id, int s, int d, DateTime at) =>
      BloodPressureReading(
          id: id, systolic: s, diastolic: d, takenAt: at, createdAt: at);

  group('shouldOfferSecondReading', () {
    final now = DateTime(2026, 3, 1, 8, 0);
    bool offer(BloodPressureReading saved, List<BloodPressureReading> all) =>
        BloodPressureScreen.shouldOfferSecondReading(saved, all, now);

    test('a normal reading taken just now is offered a partner', () {
      final r = bp('a', 128, 82, now);
      expect(offer(r, [r]), isTrue);
    });

    test('a crisis is not: its own advice is a five-minute rest', () {
      final r = bp('a', 190, 125, now);
      expect(offer(r, [r]), isFalse);
    });

    test('a back-dated reading is not', () {
      final r = bp('a', 128, 82, now.subtract(const Duration(minutes: 11)));
      expect(offer(r, [r]), isFalse);
      final recent = bp('b', 128, 82, now.subtract(const Duration(minutes: 9)));
      expect(offer(recent, [recent]), isTrue);
    });

    test('the second reading of a session is not offered a third', () {
      final first = bp('a', 128, 82, now.subtract(const Duration(minutes: 2)));
      final second = bp('b', 126, 80, now);
      expect(offer(second, [first, second]), isFalse);
    });
  });

  group('BpSecondReadingBody', () {
    Widget host({required VoidCallback onLog, required VoidCallback onSkip}) =>
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: BpSecondReadingBody(
                  first: bp('a', 128, 82, DateTime(2026)),
                  onLog: onLog,
                  onSkip: onSkip),
            ),
          ),
        );

    testWidgets('the second-reading button is locked until the minute is up',
        (tester) async {
      var logged = 0;
      await tester.pumpWidget(host(onLog: () => logged++, onSkip: () {}));
      expect(find.text('Saved 128/82. A single reading can swing. Rest for a '
          'minute, stay seated and still, then measure again. The app will '
          'average the two.'), findsOneWidget);
      expect(find.text('1:00'), findsOneWidget);
      expect(find.text('Log second reading'), findsNothing);

      await tester.tap(find.textContaining('Second reading in'));
      await tester.pump();
      expect(logged, 0, reason: 'a locked button must not fire');

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('0:30'), findsOneWidget);

      await tester.pump(const Duration(seconds: 31));
      expect(find.text('Ready'), findsOneWidget);
      await tester.tap(find.text('Log second reading'));
      expect(logged, 1);
    });

    testWidgets('Skip is available the whole time', (tester) async {
      var skipped = 0;
      await tester.pumpWidget(host(onLog: () {}, onSkip: () => skipped++));
      await tester.tap(find.text('Skip'));
      expect(skipped, 1);
    });
  });

  group('the screen', () {
    /// The number on the hero card. Scoped: the same value legitimately also
    /// appears in the 7-day and morning/evening tiles.
    Finder hero(String text) => find.descendant(
        of: find.byType(VitalsStatusHero), matching: find.text(text));

    Future<void> pump(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 3000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const BloodPressureScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('the hero shows the session average and History keeps both rows',
        (tester) async {
      final now = DateTime.now();
      await VitalsStorageService.saveBp(
          bp('a', 125, 78, now.subtract(const Duration(minutes: 2))));
      await VitalsStorageService.saveBp(bp('b', 141, 79, now));
      await pump(tester);

      expect(hero('133/79'), findsOneWidget, reason: 'the average');
      expect(find.textContaining('Average of 2 readings'), findsOneWidget);
      expect(find.text('125/78 mmHg'), findsOneWidget);
      expect(find.text('141/79 mmHg'), findsOneWidget);
      expect(find.textContaining('in a 2-reading average'), findsNWidgets(2));
    });

    testWidgets('a lone reading reads exactly as before', (tester) async {
      await VitalsStorageService.saveBp(bp('a', 118, 76, DateTime.now()));
      await pump(tester);
      expect(hero('118/76'), findsOneWidget);
      expect(find.textContaining('Last reading'), findsOneWidget);
      expect(find.textContaining('Average of'), findsNothing);
      expect(find.textContaining('-reading average'), findsNothing);
    });

    testWidgets(
        'averaging cannot hide a crisis: the emergency card follows the latest raw reading',
        (tester) async {
      final now = DateTime.now();
      // 110/70 then 190/125 a minute later: the average (150/98) is not a
      // crisis, the latest reading is.
      await VitalsStorageService.saveBp(
          bp('a', 110, 70, now.subtract(const Duration(minutes: 1))));
      await VitalsStorageService.saveBp(bp('b', 190, 125, now));
      await pump(tester);

      expect(find.text('Possible hypertensive crisis'), findsOneWidget);
      expect(hero('150/98'), findsOneWidget,
          reason: 'the hero still shows the session average');
    });

    testWidgets('a re-measure after the crisis clears the card, as it always did',
        (tester) async {
      final now = DateTime.now();
      await VitalsStorageService.saveBp(
          bp('a', 190, 125, now.subtract(const Duration(minutes: 6))));
      await VitalsStorageService.saveBp(bp('b', 150, 95, now));
      await pump(tester);

      expect(find.text('Possible hypertensive crisis'), findsNothing);
    });

    Future<void> logReading(WidgetTester tester, String sys, String dia) async {
      await tester.enterText(find.byType(TextFormField).at(0), sys);
      await tester.enterText(find.byType(TextFormField).at(1), dia);
      await tester.tap(find.text('Save reading'));
      await tester.pumpAndSettle();
    }

    testWidgets('logging a normal reading offers the second one', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Log reading'));
      await tester.pumpAndSettle();
      await logReading(tester, '128', '82');

      expect(find.text('Take a second reading?'), findsOneWidget);
      expect(find.textContaining('Saved 128/82'), findsOneWidget);
    });

    testWidgets('skipping leaves just the one saved reading', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Log reading'));
      await tester.pumpAndSettle();
      await logReading(tester, '128', '82');

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Take a second reading?'), findsNothing);
      expect(hero('128/82'), findsOneWidget);
      expect(find.textContaining('Last reading'), findsOneWidget);
    });

    testWidgets('a crisis reading is not offered a second one', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Log reading'));
      await tester.pumpAndSettle();
      await logReading(tester, '190', '125');

      expect(find.text('Take a second reading?'), findsNothing);
      expect(find.text('Possible hypertensive crisis'), findsOneWidget);
    });

    testWidgets(
        'the full flow: first, wait a minute, second — one average, no third offer',
        (tester) async {
      await pump(tester);
      await tester.tap(find.text('Log reading'));
      await tester.pumpAndSettle();
      await logReading(tester, '130', '84');

      expect(find.text('Take a second reading?'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
      await tester.tap(find.text('Log second reading'));
      await tester.pumpAndSettle();

      // The form re-opens as the SECOND reading.
      expect(find.text('Second reading'), findsOneWidget);
      await logReading(tester, '126', '80');

      expect(find.text('Take a second reading?'), findsNothing,
          reason: 'two readings make a session; it must not chain into a third');
      expect(hero('128/82'), findsOneWidget, reason: 'the average');
      expect(find.textContaining('Average of 2 readings'), findsOneWidget);
      expect(find.text('130/84 mmHg'), findsOneWidget);
      expect(find.text('126/80 mmHg'), findsOneWidget);
    });
  });
}

/// "Your recent readings" on a condition page opens the readings.
///
/// The card named the latest reading and how many there were in 90 days, and did
/// nothing when tapped — the one box on the page that looked like a way in and
/// was not.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppCard;
import 'package:tablet_remainder/features/medication/data/condition_library_data.dart';
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/screens/conditions/condition_detail_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_screen.dart';
import 'package:tablet_remainder/features/medication/services/condition_library_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

import '../support/font_free_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  final now = DateTime(2026, 8, 26, 21, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    ConditionLibraryService.resetForTesting();
  });

  tearDown(() async => db.close());

  Future<void> bp(String id, int s, int d, DateTime at) => VitalsStorageService.saveBp(
      BloodPressureReading(id: id, systolic: s, diastolic: d, takenAt: at, createdAt: at));

  Future<void> sugar(String id, int mgdl, DateTime at) =>
      VitalsStorageService.saveGlucose(
          GlucoseReading(id: id, valueMgdl: mgdl, takenAt: at, createdAt: at));

  Future<void> open(WidgetTester tester, String conditionId) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1600);
    addTearDown(tester.view.reset);
    final condition = conditionLibrary.firstWhere((c) => c.id == conditionId);
    await tester.pumpWidget(MaterialApp(
      theme: fontFreeTheme(),
      home: ConditionDetailScreen(condition: condition),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder card(String latestValue) =>
      find.ancestor(of: find.text(latestValue), matching: find.byType(AppCard)).first;

  testWidgets('a blood pressure page: the card opens Blood pressure', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await tester.runAsync(() => bp('b1', 128, 82, DateTime(2026, 8, 25, 8)));
      await open(tester, 'hypertension');

      expect(find.text('Your recent readings'), findsOneWidget);
      expect(find.text('128/82'), findsOneWidget, reason: 'the premise: the card is there');

      await tester.tap(card('128/82'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(BloodPressureScreen), findsOneWidget);
      expect(find.byType(BloodSugarScreen), findsNothing);
    });
  });

  testWidgets('a diabetes page: the card opens Blood sugar', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await tester.runAsync(() => sugar('g1', 112, DateTime(2026, 8, 25, 8)));
      await open(tester, 'type-2-diabetes');

      expect(find.text('112 mg/dL'), findsOneWidget);

      await tester.tap(card('112 mg/dL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(BloodSugarScreen), findsOneWidget);
      expect(find.byType(BloodPressureScreen), findsNothing);
    });
  });

  testWidgets('and shows it can be tapped', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await tester.runAsync(() => bp('b1', 128, 82, DateTime(2026, 8, 25, 8)));
      await open(tester, 'hypertension');

      expect(tester.widget<AppCard>(card('128/82')).onTap, isNotNull);
      expect(
          find.descendant(
              of: card('128/82'),
              matching: find.byWidgetPredicate(
                  (w) => w is Icon && w.icon == Symbols.chevron_right_rounded)),
          findsOneWidget,
          reason: 'a box that opens something should look like it does');
    });
  });

  testWidgets('a reading logged there is on the card when you come back',
      (tester) async {
    await withClock(Clock.fixed(now), () async {
      await tester.runAsync(() => bp('b1', 128, 82, DateTime(2026, 8, 24, 8)));
      await open(tester, 'hypertension');
      expect(find.text('128/82'), findsOneWidget);

      await tester.tap(card('128/82'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // A newer reading arrives while the other screen is open.
      await tester.runAsync(() => bp('b2', 141, 91, DateTime(2026, 8, 26, 7)));
      await tester.tap(find.byTooltip('Back').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BloodPressureScreen), findsNothing, reason: 'the premise: back');
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('141/91'), findsOneWidget,
          reason: 'the card was left showing the reading from before');
      expect(find.text('128/82'), findsNothing);
    });
  });

  testWidgets('a page with nothing to read has no card to tap', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await open(tester, 'hypertension');
      expect(find.text('Your recent readings'), findsNothing);
    });
  });
}

/// "Setup that fills the app": the welcome screen asks what to start with (up to
/// three, none is fine), moves those cards up on Today and picks the tab to open on,
/// and — once the health app is connected — brings its steps and sleep in so Today
/// has numbers on the first day. It sets no goal figure, hides nothing and switches
/// nothing on.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/home/screens/app_shell.dart';
import 'package:tablet_remainder/features/home/services/today_order.dart';
import 'package:tablet_remainder/features/onboarding/screens/welcome_screen.dart';
import 'package:tablet_remainder/features/onboarding/services/welcome_goals.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('WelcomeGoal', () {
    test('a tap adds, a second tap takes away, in the order picked', () {
      var picks = const <WelcomeGoal>[];
      picks = WelcomeGoal.toggled(picks, WelcomeGoal.water);
      picks = WelcomeGoal.toggled(picks, WelcomeGoal.medicines);
      expect(picks, [WelcomeGoal.water, WelcomeGoal.medicines]);
      picks = WelcomeGoal.toggled(picks, WelcomeGoal.water);
      expect(picks, [WelcomeGoal.medicines]);
    });

    test('never more than three: a fourth is refused and nothing else moves', () {
      final three = [WelcomeGoal.water, WelcomeGoal.steps, WelcomeGoal.sleep];
      expect(WelcomeGoal.toggled(three, WelcomeGoal.focus), three);
      expect(WelcomeGoal.maxPicks, 3);
      // Taking one off makes room.
      final two = WelcomeGoal.toggled(three, WelcomeGoal.steps);
      expect(WelcomeGoal.toggled(two, WelcomeGoal.focus).length, 3);
    });

    test('Today\'s cards go in the order picked, each once', () {
      expect(WelcomeGoal.todayOrderFor([WelcomeGoal.water, WelcomeGoal.medicines]),
          ['water', 'medicine']);
      expect(WelcomeGoal.todayOrderFor([WelcomeGoal.steps, WelcomeGoal.sleep]),
          ['weekly'], reason: 'one card carries both');
      expect(WelcomeGoal.todayOrderFor([WelcomeGoal.focus, WelcomeGoal.reminders]),
          ['activity']);
      expect(WelcomeGoal.todayOrderFor(const []), isEmpty);
    });

    test('every goal maps to a card Today actually has', () {
      for (final g in WelcomeGoal.values) {
        expect(todayCardIds, contains(g.todayCard), reason: g.name);
      }
    });

    test('what is picked first is shown first, and the rest follow as ever', () {
      final stored = WelcomeGoal.todayOrderFor([WelcomeGoal.water]);
      expect(TodayOrder.normalise(stored),
          ['water', 'medicine', 'weekly', 'activity']);
    });

    test('the app opens on Meds unless medicines were left out of a real choice', () {
      expect(WelcomeGoal.landingTab(const []), 1, reason: 'said nothing: as before');
      expect(WelcomeGoal.landingTab([WelcomeGoal.medicines]), 1);
      expect(WelcomeGoal.landingTab([WelcomeGoal.water, WelcomeGoal.medicines]), 1);
      expect(WelcomeGoal.landingTab([WelcomeGoal.water]), 0);
      expect(WelcomeGoal.landingTab([WelcomeGoal.steps, WelcomeGoal.sleep]), 0);
    });

    test('what is stored is read back, and anything else is dropped', () {
      final picks = [WelcomeGoal.sleep, WelcomeGoal.water];
      expect(WelcomeGoal.decode(WelcomeGoal.encode(picks)), picks);
      expect(WelcomeGoal.decode(['water', 'nonsense', 'water', 7, null]),
          [WelcomeGoal.water]);
      expect(WelcomeGoal.decode('water'), isEmpty);
      expect(WelcomeGoal.decode(null), isEmpty);
      expect(
          WelcomeGoal.decode(['water', 'steps', 'sleep', 'focus']).length, 3,
          reason: 'a hand-edited store cannot exceed the limit');
    });
  });

  group('the pane', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      CleanStorageService.resetForTesting();
      await CleanStorageService.init();
    });

    tearDown(() async => db.close());

    Future<void> open(
      WidgetTester tester, {
      HealthAvailability availability = HealthAvailability.unavailable,
      Future<bool> Function()? connect,
      Future<void> Function()? importHealth,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(411, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: WelcomeScreen(
          healthAvailability: () async => availability,
          connectHealth: connect,
          importHealth: importHealth,
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> tapText(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    Future<void> toGoals(WidgetTester tester) async {
      await tapText(tester, 'Get started');
      await tapText(tester, 'Continue');
    }

    Future<void> finish(WidgetTester tester) async {
      // Past health (if any) to the reminders pane, then the shortest way out.
      // Bounded: a pane that went missing must fail this, not spin for ever.
      for (var i = 0; i < 4 && find.text('Skip for now').evaluate().isEmpty; i++) {
        await tapText(tester, 'Continue');
      }
      await tapText(tester, 'Skip for now');
      await tapText(tester, 'Continue as guest');
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      tester.takeException();
    }

    testWidgets('asks what to start with, says what that does, and is optional',
        (tester) async {
      await open(tester);
      await toGoals(tester);

      expect(find.text('What would you like to start with?'), findsOneWidget);
      for (final g in WelcomeGoal.values) {
        expect(find.text(g.label), findsOneWidget, reason: g.name);
      }
      expect(find.textContaining('Nothing is hidden or switched on'), findsOneWidget);
      expect(find.text('Optional — Continue to skip.'), findsOneWidget);
    });

    testWidgets('a fourth is refused, and the pane says why', (tester) async {
      await open(tester);
      await toGoals(tester);

      for (final label in ['Water', 'Steps', 'Sleep']) {
        await tapText(tester, label);
      }
      expect(find.text('That is 3 of 3. Tap one to swap it.'), findsOneWidget);

      await tapText(tester, 'Focus');
      expect(find.text('That is 3 of 3. Tap one to swap it.'), findsOneWidget);

      await tapText(tester, 'Steps'); // take one off: room again
      expect(find.text('Optional — Continue to skip.'), findsOneWidget);
    });

    testWidgets('skipping it writes nothing at all', (tester) async {
      await open(tester);
      await toGoals(tester);
      await finish(tester);

      expect(CleanStorageService.isFirstLaunch, isFalse,
          reason: 'the finish path never ran, so nothing below proves anything');
      final prefs = CleanStorageService.getAppPreferences();
      expect(prefs.containsKey(WelcomeGoal.todayOrderKey), isFalse,
          reason: 'Today\'s order is left exactly as it was');
      expect(prefs.containsKey(WelcomeGoal.prefKey), isFalse);
      expect(find.byType(AppShell), findsOneWidget);
      expect(tester.widget<AppShell>(find.byType(AppShell)).initialIndex, 1,
          reason: 'Meds, as before');
    });

    testWidgets('what was picked goes first on Today, and Today is where it opens',
        (tester) async {
      await open(tester);
      await toGoals(tester);
      await tapText(tester, 'Water');
      await tapText(tester, 'Sleep');
      await finish(tester);

      final prefs = CleanStorageService.getAppPreferences();
      expect(prefs[WelcomeGoal.todayOrderKey], ['water', 'weekly']);
      expect(prefs[WelcomeGoal.prefKey], ['water', 'sleep']);
      expect(tester.widget<AppShell>(find.byType(AppShell)).initialIndex, 0,
          reason: 'not medicines: Today, with theirs on top');
    });

    testWidgets('medicines picked: Meds, as ever', (tester) async {
      await open(tester);
      await toGoals(tester);
      await tapText(tester, 'Medicines');
      await tapText(tester, 'Water');
      await finish(tester);

      expect(CleanStorageService.getAppPreferences()[WelcomeGoal.todayOrderKey],
          ['medicine', 'water']);
      expect(tester.widget<AppShell>(find.byType(AppShell)).initialIndex, 1);
    });

    testWidgets('it sets no goal figure: the hydration profile is still untouched',
        (tester) async {
      await open(tester);
      await toGoals(tester);
      await tapText(tester, 'Water');
      await finish(tester);

      expect(await db.waterDao.getProfile(), isNull);
    });

    testWidgets('connecting the health app brings its data in, once', (tester) async {
      var imported = 0;
      await open(tester,
          availability: HealthAvailability.notDetermined,
          connect: () async => true,
          importHealth: () async => imported++);
      await toGoals(tester);
      await tapText(tester, 'Continue');
      expect(find.text('Bring in your health data'), findsOneWidget);
      expect(imported, 0, reason: 'nothing is read until it is connected');

      await tapText(tester, 'Connect Health Connect');
      expect(imported, 1);
    });

    testWidgets('a refusal reads nothing', (tester) async {
      var imported = 0;
      await open(tester,
          availability: HealthAvailability.notDetermined,
          connect: () async => false,
          importHealth: () async => imported++);
      await toGoals(tester);
      await tapText(tester, 'Continue');

      await tapText(tester, 'Connect Health Connect');
      expect(imported, 0);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('an import that fails does not stop the pane', (tester) async {
      await open(tester,
          availability: HealthAvailability.notDetermined,
          connect: () async => true,
          importHealth: () async => throw StateError('no sleep in it'));
      await toGoals(tester);
      await tapText(tester, 'Continue');

      // The failure belongs to the background import; the person still sees the
      // connection they made.
      await tester.tap(find.text('Connect Health Connect'));
      await tester.pumpAndSettle();
      tester.takeException();
      expect(find.text('Connected'), findsOneWidget);
    });
  });
}

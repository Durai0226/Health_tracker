/// Focus and Reminders have a way in that is not Today's card.
///
/// Today's "Focus & reminders" card can be switched off, which it could not be
/// while it was the only door to either. The Health tab is the other door: a
/// row each, opening the same screens the card does.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/home/screens/health_browse_screen.dart';
import 'package:tablet_remainder/features/reminders/screens/reminders_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late db.AppDatabase database;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => database.close());

  Future<void> pumpHub(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 2600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const HealthBrowseScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
    } finally {
      FlutterError.onError = prev;
    }
  }

  testWidgets('the Health tab lists Focus and Reminders', (tester) async {
    await pumpHub(tester);

    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('Timer, streaks & garden'), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Your to-dos & alerts'), findsOneWidget);
  });

  testWidgets('Reminders opens the reminders screen', (tester) async {
    await pumpHub(tester);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.tap(find.text('Reminders'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(RemindersScreen), findsOneWidget);
      expect(find.byType(FocusScreen), findsNothing);
    } finally {
      FlutterError.onError = prev;
    }
  });

  testWidgets('Focus opens the focus screen', (tester) async {
    await pumpHub(tester);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.tap(find.text('Focus'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(FocusScreen), findsOneWidget);
      expect(find.byType(RemindersScreen), findsNothing);
    } finally {
      FlutterError.onError = prev;
    }
  });
}

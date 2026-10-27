/// Settings has the Emergency card, beside Family & caregivers.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/home/screens/emergency_card_screen.dart';
import 'package:tablet_remainder/features/settings/screens/settings_screen.dart';

import '../../support/font_free_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  testWidgets('a tile under Family & caregivers opens it', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 2400);
    addTearDown(tester.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (_) {}; // overflow is the responsive suite's job
    try {
      await tester.pumpWidget(
          MaterialApp(theme: fontFreeTheme(), home: const SettingsScreen()));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Family & caregivers'), findsWidgets);
      expect(find.text('Emergency card'), findsOneWidget);
      expect(find.text('Allergies, medicines and who to call'), findsOneWidget);

      await tester.tap(find.text('Emergency card'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(EmergencyCardScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    } finally {
      FlutterError.onError = prev;
    }
  });
}

/// Every haptic feature gets exactly one row.
///
/// The "Feature haptics" section was a hand-written list of SEVEN rows over
/// only FOUR distinct `HapticFeature` keys: "Medicine taken" and "Medicine
/// reminder" both wrote `.medication`, "Water added" and "Water goal" both
/// wrote `.water`, "Focus start" and "Focus done" both wrote `.focus`. Three
/// pairs were one setting wearing two names — adjusting either half silently
/// moved the other, and the twin row kept showing the old value.
///
/// `.fitness` and `.notifications` meanwhile had no row at all and could not
/// be reached from the UI, although both fire haptics elsewhere in the app.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/haptic_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/settings/screens/haptic_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
  });

  tearDown(() async => db.close());

  testWidgets('one row per feature, none missing and none doubled',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 2600);
    addTearDown(tester.view.reset);

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: const HapticSettingsScreen(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    } finally {
      FlutterError.onError = prev;
    }

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();

    expect(texts, contains('Feature haptics'),
        reason: 'the section did not render, so this test checks nothing');

    // Every enum value must be nameable on screen exactly once.
    const titles = {
      HapticFeature.water: 'Water',
      HapticFeature.medication: 'Medicine',
      HapticFeature.focus: 'Focus',
      HapticFeature.fitness: 'Fitness',
      HapticFeature.navigation: 'Navigation',
      HapticFeature.notifications: 'Notifications',
    };
    expect(titles.length, HapticFeature.values.length,
        reason: 'a HapticFeature was added without a row or a name here');

    for (final entry in titles.entries) {
      final n = texts.where((t) => t == entry.value).length;
      expect(n, 1,
          reason: '${entry.key} is represented by $n rows titled '
              '"${entry.value}". Two rows writing one key is one setting '
              'wearing two names; zero rows is a setting the user cannot '
              'reach at all.');
    }

    // ...and none of the old doubled labels survive.
    for (final stale in const [
      'Medicine taken',
      'Medicine reminder',
      'Water added',
      'Water goal',
      'Focus start',
      'Focus done',
    ]) {
      expect(texts, isNot(contains(stale)),
          reason: '"$stale" shared its HapticFeature with another row');
    }
  });
}

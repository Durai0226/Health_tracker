import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/mood_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/weight_screen.dart';

/// MED-UI-18 — `_TakenAtField` (×4) and `_ScrollableFill` (×4) were lifted into
/// `lib/core/widgets/app/`.
///
/// Two halves, and the second is the one that matters. Deduplication is easy to
/// verify by grep and easy to get wrong in a way grep cannot see: the four
/// copies were identical EXCEPT for their picker-sheet titles ('Entry' on mood,
/// 'Reading' on the other three), so the obvious lift silently retitles three
/// screens. The pumped tests below are what would catch that.
///
/// ALL FOUR screens are pumped, not a sample. `noun` defaults to 'Entry', so a
/// dropped argument is silent — and a two-screen version of this group was
/// verified to stay green while blood sugar and blood pressure were both
/// retitled to 'Entry date'. The guard has to name every caller it guards.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: home));
    await tester.pumpAndSettle();
  }

  /// Opens a vitals entry sheet via its empty-state CTA, then opens the date
  /// picker from the shared field's date box (labelled 'Today' for a new entry).
  Future<void> openDatePicker(WidgetTester tester, String cta) async {
    await tester.tap(find.text(cta));
    await tester.pumpAndSettle();
    expect(find.byType(AppDateTimeField), findsOneWidget,
        reason: 'the sheet must be using the lifted field, not a private copy');
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
  }

  group('MED-UI-18 the lifted widgets', () {
    // One screen per test: pumping a second MaterialApp into the same tester
    // reuses the Navigator element, so the first screen's open sheet is still
    // on the route stack and the second flow taps through it.
    testWidgets('title mood\'s pickers "Entry"', (tester) async {
      await pump(tester, const MoodScreen());
      await openDatePicker(tester, 'Log mood');
      expect(find.text('Entry date'), findsOneWidget,
          reason: 'mood logs an entry, not a reading — the noun is the one '
              'thing that differed between the four copies');
      expect(find.text('Reading date'), findsNothing);
    });

    testWidgets('title weight\'s pickers "Reading"', (tester) async {
      await pump(tester, const WeightScreen());
      await openDatePicker(tester, 'Log reading');
      expect(find.text('Reading date'), findsOneWidget);
      expect(find.text('Entry date'), findsNothing);
    });

    testWidgets('title blood sugar\'s pickers "Reading"', (tester) async {
      await pump(tester, const BloodSugarScreen());
      await openDatePicker(tester, 'Log reading');
      expect(find.text('Reading date'), findsOneWidget);
      expect(find.text('Entry date'), findsNothing);
    });

    testWidgets('title blood pressure\'s pickers "Reading"', (tester) async {
      await pump(tester, const BloodPressureScreen());
      await openDatePicker(tester, 'Log reading');
      expect(find.text('Reading date'), findsOneWidget);
      expect(find.text('Entry date'), findsNothing);
    });

    test('are gone from every screen that used to declare them', () {
      final offenders = <String>[];
      for (final e in Directory('lib').listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        final src = e.readAsStringSync();
        for (final decl in const [
          'class _TakenAtField',
          'class _ScrollableFill',
        ]) {
          if (src.contains(decl)) offenders.add('${e.path}: $decl');
        }
      }
      expect(offenders, isEmpty,
          reason: 'AppDateTimeField and ScrollableFill live in '
              'lib/core/widgets/app/ now.\n${offenders.join('\n')}');
    });

    test('are not re-inlined in the feature that they were lifted out of', () {
      // Deleting the class and pasting its three lines back into the build
      // method would pass the declaration scan above. This is scoped to
      // medication on purpose: lib/features/reminders and lib/features/focus
      // still hand-roll the same shape, and this change did not touch them.
      final offenders = <String>[];
      for (final e
          in Directory('lib/features/medication').listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        if (e
            .readAsStringSync()
            .contains('BoxConstraints(minHeight: constraints.maxHeight)')) {
          offenders.add(e.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'use ScrollableFill.\n${offenders.join('\n')}');
    });

    test('are reachable through the app_widgets barrel', () {
      // Every other shared widget is imported through it; a file that is not
      // exported is a second import line at every call site, which is how the
      // private copies were convenient in the first place.
      final barrel =
          File('lib/core/widgets/app/app_widgets.dart').readAsStringSync();
      expect(barrel, contains("export 'app_date_time_field.dart';"));
      expect(barrel, contains("export 'scrollable_fill.dart';"));
    });
  });
}

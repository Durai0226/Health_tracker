/// A medicine's reminder sound, from the form to the database and back.
///
/// The model had a `reminderSound` the form carried forward and nothing stored; a
/// choice made on the form would have vanished on the next load. The form's card
/// opens the same sound list the Reminders editor uses.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart'
    show AppButton, AppCard, AppListTile;
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_add_medication_flow.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_detail_screen.dart';
import 'package:tablet_remainder/features/medication/services/drug_name_catalog.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/reminders/widgets/reminder_sound_sheet.dart';
import 'package:tablet_remainder/core/design/app_design.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  tz_data.initializeTimeZones();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tz.setLocalLocation(tz.UTC);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
  });

  tearDown(() async => db.close());

  EnhancedMedicine metformin({String? sound, bool reminders = true}) =>
      EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
            frequencyType: FrequencyType.onceDaily,
            times: [ScheduledTime(hour: 8, minute: 0)],
            startDate: DateTime(2026, 1, 1)),
        reminderEnabled: reminders,
        reminderSound: sound,
      );

  Future<EnhancedMedicine> stored() async =>
      (await MedicineCleanStorageService.getMedicine('m1'))!;

  Future<void> openEdit(WidgetTester tester) async {
    await tester.runAsync(DrugNameCatalog.ensureLoaded);
    final edit = await stored();
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(
              builder: (_) =>
                  NunitoAddMedicationFlow(editMedicine: edit, debugInitialStep: 4),
            )),
            child: const Text('host page'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('host page'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    final b = find.widgetWithText(AppButton, 'Save changes');
    await tester.ensureVisible(b);
    await tester.pump();
    await tester.tap(b);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tapText(WidgetTester tester, String label) async {
    final f = find.text(label).first;
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  /// The words on the card that carries [label].
  List<String> cardTexts(String label) {
    final card = find
        .ancestor(of: find.text(label).first, matching: find.byType(AppCard))
        .first;
    return [
      for (final t in find
          .descendant(of: card, matching: find.byType(Text))
          .evaluate()
          .map((e) => e.widget as Text))
        if (t.data != null) t.data!
    ];
  }

  group('storage', () {
    test('a chosen sound is stored and read back', () async {
      await MedicineCleanStorageService.saveMedicine(metformin(sound: 'marimba'));

      expect((await stored()).reminderSound, 'marimba');
    });

    test('no choice stays no choice', () async {
      await MedicineCleanStorageService.saveMedicine(metformin());

      expect((await stored()).reminderSound, isNull);
    });
  });

  group('the form', () {
    testWidgets('a medicine with no choice says Default', (tester) async {
      await MedicineCleanStorageService.saveMedicine(metformin());
      await openEdit(tester);

      expect(cardTexts('Reminder sound'), contains('Default'));
    });

    testWidgets('choosing a sound shows it and saves it', (tester) async {
      await MedicineCleanStorageService.saveMedicine(metformin());
      await openEdit(tester);

      await tapText(tester, 'Reminder sound');
      expect(find.text('Marimba'), findsOneWidget,
          reason: 'the sheet lists the bundled sounds');
      await tester.tap(find.text('Marimba'));
      await tester.pumpAndSettle();

      expect(cardTexts('Reminder sound'), contains('Marimba'));
      await save(tester);
      expect((await stored()).reminderSound, 'marimba');
    });

    testWidgets('the saved choice is what the form shows next time', (tester) async {
      await MedicineCleanStorageService.saveMedicine(metformin(sound: 'soft_bells'));
      await openEdit(tester);

      expect(cardTexts('Reminder sound'), contains('Soft Bells'));
    });

    testWidgets('choosing Default clears a saved sound', (tester) async {
      await MedicineCleanStorageService.saveMedicine(metformin(sound: 'marimba'));
      await openEdit(tester);

      await tapText(tester, 'Reminder sound');
      await tester.tap(find.text('Default').last);
      await tester.pumpAndSettle();

      expect(cardTexts('Reminder sound'), contains('Default'));
      await save(tester);
      expect((await stored()).reminderSound, isNull,
          reason: 'Default stores nothing, so it follows the standard sound');
    });

    testWidgets('dismissing the sheet changes nothing', (tester) async {
      await MedicineCleanStorageService.saveMedicine(metformin(sound: 'marimba'));
      await openEdit(tester);

      await tapText(tester, 'Reminder sound');
      await tester.tapAt(const Offset(195, 20)); // the scrim above the sheet
      await tester.pumpAndSettle();

      expect(cardTexts('Reminder sound'), contains('Marimba'));
      await save(tester);
      expect((await stored()).reminderSound, 'marimba');
    });

    testWidgets('changing only the sound counts as an unsaved change', (tester) async {
      await MedicineCleanStorageService.saveMedicine(metformin());
      await openEdit(tester);

      await tapText(tester, 'Reminder sound');
      await tester.tap(find.text('Pulse'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget,
          reason: 'the sound is part of what the form would lose');
    });

    testWidgets('a stored key the app no longer has shows as Default', (tester) async {
      await MedicineCleanStorageService.saveMedicine(metformin(sound: 'removed_in_v9'));
      await openEdit(tester);

      expect(cardTexts('Reminder sound'), contains('Default'));
    });

    testWidgets('saving drops a stored key the app no longer has', (tester) async {
      await MedicineCleanStorageService.saveMedicine(metformin(sound: 'removed_in_v9'));
      await openEdit(tester);

      await save(tester);

      expect((await stored()).reminderSound, isNull,
          reason: 'a dead key would otherwise ride along in every later save');
    });

    testWidgets('with reminders off there is no sound to pick, and none is kept',
        (tester) async {
      await MedicineCleanStorageService.saveMedicine(metformin(sound: 'marimba'));
      await openEdit(tester);

      await tapText(tester, 'Reminders');
      expect(find.text('Reminder sound'), findsNothing);

      await save(tester);
      expect((await stored()).reminderSound, isNull,
          reason: 'a silenced medicine must not keep a sound it cannot ring');
    });
  });

  group('the sheet', () {
    // Held here, not returned: an `async` function that returned this future
    // would wait for it, and it completes only when the sheet closes.
    late Future<({String? key})?> answer;

    Future<void> open(WidgetTester tester, {String? current}) async {
      // Tall enough to show every row: the sheet scrolls on a short screen, and
      // a tap on a row below the fold misses — leaving `answer` pending forever,
      // which `await` then waits on with no timeout able to stop it.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 1800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => answer = chooseReminderSound(context,
                  current: current,
                  accent: AppColorsExt.of(context).medicine),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a sound answers with its key', (tester) async {
      await open(tester);
      await tester.tap(find.text('Calm'));
      await tester.pumpAndSettle();

      expect(await answer, (key: 'calm'));
    });

    testWidgets('Default answers with a null key, not with nothing', (tester) async {
      await open(tester, current: 'calm');
      await tester.tap(find.text('Default'));
      await tester.pumpAndSettle();

      expect(await answer, (key: null),
          reason: 'null alone would read as a dismissed sheet');
    });

    testWidgets('the current sound carries the tick, and only it', (tester) async {
      await open(tester, current: 'pulse');

      Finder tick(String title) => find.descendant(
          of: find
              .ancestor(of: find.text(title), matching: find.byType(AppListTile))
              .first,
          matching: find.byIcon(Symbols.check_circle_rounded));

      expect(tick('Pulse'), findsOneWidget);
      expect(tick('Calm'), findsNothing);
      expect(tick('Default'), findsNothing);
    });

    testWidgets('a stored key the app no longer has ticks Default', (tester) async {
      await open(tester, current: 'removed_in_v9');

      expect(
          find.descendant(
              of: find
                  .ancestor(
                      of: find.text('Default'), matching: find.byType(AppListTile))
                  .first,
              matching: find.byIcon(Symbols.check_circle_rounded)),
          findsOneWidget);
    });

    testWidgets('previewing plays that sound\'s own file, and again stops it',
        (tester) async {
      final played = <String>[];
      soundPreviewForTesting = (asset) async => played.add(asset);
      addTearDown(() => soundPreviewForTesting = null);
      await open(tester);

      await tester.tap(find.byTooltip('Preview Marimba'));
      await tester.pump();

      expect(played, ['assets/sounds/marimba.wav']);
      expect(find.byTooltip('Stop preview'), findsOneWidget);
      expect(find.byTooltip('Preview Marimba'), findsNothing);

      await tester.tap(find.byTooltip('Stop preview'));
      await tester.pump();
      expect(find.byTooltip('Preview Marimba'), findsOneWidget,
          reason: 'a second tap stops it');

      // The sheet closes with its own four-second timer cancelled.
      await tester.tap(find.text('Marimba'));
      await tester.pumpAndSettle();
    });

    testWidgets('a preview that cannot play leaves the sheet usable',
        (tester) async {
      soundPreviewForTesting = (asset) async => throw 'no audio device';
      addTearDown(() => soundPreviewForTesting = null);
      await open(tester);

      await tester.tap(find.byTooltip('Preview Marimba'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byTooltip('Preview Marimba'), findsOneWidget,
          reason: 'back to a play button, not stuck on stop');
      await tester.tap(find.text('Marimba'));
      await tester.pumpAndSettle();
      expect(await answer, (key: 'marimba'));
    });
  });

  group('the detail screen', () {
    Future<void> openDetail(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 2400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: NunitoMedicationDetailScreen(medicine: await stored()),
      ));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('shows a chosen sound', (tester) async {
      await MedicineCleanStorageService.saveMedicine(metformin(sound: 'marimba'));
      await openDetail(tester);

      expect(find.text('Reminder sound'), findsOneWidget);
      expect(find.text('Marimba'), findsOneWidget);
    });

    testWidgets('says nothing when there is none', (tester) async {
      await MedicineCleanStorageService.saveMedicine(metformin());
      await openDetail(tester);

      expect(find.text('Reminder sound'), findsNothing);
    });

    testWidgets('says nothing about a sound the app no longer has', (tester) async {
      await MedicineCleanStorageService.saveMedicine(metformin(sound: 'removed_in_v9'));
      await openDetail(tester);

      expect(find.text('Reminder sound'), findsNothing);
    });

    testWidgets('says nothing when reminders are off', (tester) async {
      await MedicineCleanStorageService.saveMedicine(
          metformin(sound: 'marimba', reminders: false));
      await openDetail(tester);

      expect(find.text('Reminder sound'), findsNothing);
    });
  });
}

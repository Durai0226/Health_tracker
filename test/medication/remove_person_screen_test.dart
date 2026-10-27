/// Family & caregivers → Delete: the two answers, wired to what they do.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/medication/models/dependent_profile.dart';
import 'package:tablet_remainder/features/medication/models/mood_entry.dart';
import 'package:tablet_remainder/features/medication/screens/dependents/dependent_list_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

import '../support/font_free_theme.dart';
import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
    await ActiveProfileService().init();
    await MedicineCleanStorageService.addDependent(DependentProfile(
        id: 'dep-a', name: 'Maya', relationship: RelationshipType.child));
    await VitalsStorageService.saveMood(
        MoodEntry(
            id: 'md-a',
            moodIndex: 1,
            takenAt: DateTime(2026, 6, 1, 9),
            createdAt: DateTime(2026, 6, 1, 9),
            dependentId: 'dep-a'),
        stampActiveProfile: false);
  });

  tearDown(() async => db.close());

  Future<void> openMenuAndDelete(WidgetTester tester) async {
    // Overflow in a card drawn with the test font is the responsive suite's job.
    // Installed here, in the test body: the binding sets its own handler after
    // setUp has run.
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!'${d.exception}'.contains('overflowed')) prevOnError?.call(d);
    };
    addTearDown(() => FlutterError.onError = prevOnError);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 1400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        MaterialApp(theme: fontFreeTheme(), home: const DependentListScreen()));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 300));

    // Self comes first; Maya is the second card.
    await tester.tap(find.byIcon(Symbols.more_vert_rounded).last);
    // The menu opens over a moving barrier: let it settle before tapping in it.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.tap(find.text('Delete'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('Delete asks what to do with their records, and naming them',
      (tester) async {
    await openMenuAndDelete(tester);
    expect(find.text('Remove Maya?'), findsOneWidget);
    expect(find.text('Remove them, keep the records'), findsOneWidget);
    expect(find.text('Remove them and delete everything'), findsOneWidget);
  });

  testWidgets('Cancel removes nothing', (tester) async {
    await openMenuAndDelete(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    final people = await tester.runAsync(MedicineCleanStorageService.getAllDependents);
    expect(people!.any((d) => d.id == 'dep-a'), isTrue);
  });

  testWidgets('keep: the profile goes, their mood comes to you', (tester) async {
    await openMenuAndDelete(tester);
    await tester.tap(find.text('Remove them, keep the records'));
    await settle(tester);

    final people = await tester.runAsync(MedicineCleanStorageService.getAllDependents);
    expect(people!.any((d) => d.id == 'dep-a'), isFalse);
    final moods = await tester.runAsync(
        () => VitalsStorageService.getAllMood(scopeToActiveProfile: false));
    expect(moods!.single.id, 'md-a');
    expect(moods.single.dependentId, isNull);
    expect(find.text('Maya removed'), findsOneWidget);
  });

  testWidgets('delete: the profile and their mood both go', (tester) async {
    await openMenuAndDelete(tester);
    await tester.tap(find.text('Remove them and delete everything'));
    await settle(tester);

    final people = await tester.runAsync(MedicineCleanStorageService.getAllDependents);
    expect(people!.any((d) => d.id == 'dep-a'), isFalse);
    final moods = await tester.runAsync(
        () => VitalsStorageService.getAllMood(scopeToActiveProfile: false));
    expect(moods, isEmpty);
    expect(find.text('Maya and their records removed'), findsOneWidget);
  });
}

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppCard;
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_detail_screen.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_list_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

/// QA — the two places a medicine can be archived or deleted (the list's swipe
/// actions and the detail screen's menu) must behave the same way, and a
/// swipe-to-delete must not look like it failed.
///
/// They had drifted: two different confirmation sheets with two different
/// messages, and an archive that was undoable from the list but not from the
/// detail. The swipe itself answered `confirmDismiss` with `false` on the same
/// frame and ran the delete unawaited, so the card sprang back to rest while
/// its own confirmation sheet was still open.
///
/// DS-13 moved that confirmation from an `AlertDialog` to
/// `ConfirmationBottomSheet`, so all three of its answers are pinned here:
/// Delete, Cancel, and escaping the sheet — which resolves to `null`, not
/// `false`, and is the only one that catches a widened `confirm` branch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Archiving cancels the medicine's reminders and Undo re-schedules them;
    // without a stand-in those calls reach the unregistered plugin channel.
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async {
    ActiveProfileService().resetForTesting();
    await db.close();
  });

  EnhancedMedicine metformin() => EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        strength: '500mg',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 9, minute: 0)],
        ),
      );

  Future<EnhancedMedicine> seed() async {
    final med = metformin();
    await MedicineCleanStorageService.addMedicine(med);
    return med;
  }

  Future<void> openList(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const NunitoMedicationListScreen(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openDetail(WidgetTester tester, EnhancedMedicine med) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: NunitoMedicationDetailScreen(medicine: med),
    ));
    await tester.pumpAndSettle();
  }

  /// Where the swiped row's card is actually painted. The Dismissible's own box
  /// never moves — the translation lives on its child.
  double cardLeft(WidgetTester tester) => tester
      .getTopLeft(find.descendant(
        of: find.byKey(const Key('m1')),
        matching: find.byType(AppCard),
      ))
      .dx;

  testWidgets('a swiped-away row stays swiped while its delete is confirmed',
      (tester) async {
    await seed();
    await openList(tester);

    final atRest = cardLeft(tester);
    await tester.drag(find.text('Metformin'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Delete Metformin?'), findsOneWidget,
        reason: 'the swipe asks before deleting');
    expect(cardLeft(tester), lessThan(atRest - 100),
        reason: 'the row must not spring back to rest under its own '
            'confirmation sheet — that reads as a delete that failed');

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Metformin'), findsNothing,
        reason: 'a confirmed delete removes the row');
    expect(await MedicineCleanStorageService.getMedicine('m1'), isNull);
  });

  testWidgets('cancelling the swipe-delete puts the row back', (tester) async {
    await seed();
    await openList(tester);

    final atRest = cardLeft(tester);
    await tester.drag(find.text('Metformin'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(cardLeft(tester), moreOrLessEquals(atRest, epsilon: 0.5),
        reason: 'a cancelled delete leaves the row exactly where it was');
    expect(await MedicineCleanStorageService.getMedicine('m1'), isNotNull);
  });

  // Cancel answers `false`; escaping the sheet answers `null`. Both must read
  // as "no", but only this one pins the branch down: widen `confirm == true`
  // to `confirm != false` and the Cancel test above stays green while a
  // dismissed sheet silently deletes the medicine.
  testWidgets('dismissing the delete sheet by its barrier deletes nothing',
      (tester) async {
    await seed();
    await openList(tester);

    await tester.drag(find.text('Metformin'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete Metformin?'), findsOneWidget);

    // The dialog this replaced was barrierDismissible, and the sheet must stay
    // escapable the same way.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Delete Metformin?'), findsNothing);
    expect(await MedicineCleanStorageService.getMedicine('m1'), isNotNull,
        reason: 'nothing was confirmed, so nothing is deleted');
    expect(find.text('Metformin'), findsOneWidget,
        reason: 'the swiped row springs back');
  });

  testWidgets('both screens ask the same delete question', (tester) async {
    final med = await seed();

    await openList(tester);
    await tester.drag(find.text('Metformin'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    final fromList = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => s.contains('permanently deletes'))
        .toList();
    expect(fromList, hasLength(1),
        reason: 'the list must say what deleting actually destroys');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await openDetail(tester, med);
    await tester.tap(find.byTooltip('Show menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    final fromDetail = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => s.contains('permanently deletes'))
        .toList();

    expect(fromDetail, equals(fromList),
        reason: 'one medicine, one delete confirmation — the two surfaces '
            'must not drift apart again');
    expect(find.text('Delete Metformin?'), findsOneWidget);
  });

  testWidgets('archiving from the detail screen is undoable, as it is from the list',
      (tester) async {
    final med = await seed();
    await openDetail(tester, med);

    await tester.tap(find.byTooltip('Show menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Medicine archived'), findsOneWidget);
    expect((await MedicineCleanStorageService.getMedicine('m1'))!.isArchived,
        isTrue);

    expect(find.text('Undo'), findsOneWidget,
        reason: 'archiving cancels every reminder the medicine has — the '
            'detail screen must offer the way back the list does');

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect((await MedicineCleanStorageService.getMedicine('m1'))!.isArchived,
        isFalse, reason: 'Undo must restore the medicine, not just the toast');
  });
}

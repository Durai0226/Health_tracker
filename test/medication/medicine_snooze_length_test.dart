/// A medicine can ask how long its Snooze waits.
///
/// The model carried a `snoozeMinutes` nothing stored: it read 10 for every
/// medicine, the in-app Snooze used it, and the Notifications setting ("Snooze
/// for 5 min", the label on the notification's own button) never reached it.
/// The part worth pinning without a device is the decision with no obvious
/// answer: a slot is ONE alarm however many medicines share its minute, so it
/// snoozes once — and it takes the SHORTEST length asked for, so no medicine
/// waits longer than it said it could.
library;

import 'dart:convert';
import 'dart:ui' show CallbackHandle;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show AndroidFlutterLocalNotificationsPlugin;
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart'
    show FlutterLocalNotificationsPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart'
    show AppButton, AppCard;
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/models/medicine_snooze.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_add_medication_flow.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_detail_screen.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_take_medication_sheet.dart';
import 'package:tablet_remainder/features/medication/services/drug_name_catalog.dart';
import 'package:tablet_remainder/features/medication/services/medication_reminder_service.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/reminder_slot_grouping.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  tz_data.initializeTimeZones();

  Map<String, dynamic> entry(String id, [int? snooze]) => {
        'medicineId': id,
        'name': 'Medicine $id',
        'scheduleJson': '',
        'snooze': ?snooze,
      };

  EnhancedMedicine med(String id, {int? snooze, bool reminders = true}) =>
      EnhancedMedicine(
        id: id,
        name: 'Medicine $id',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
            frequencyType: FrequencyType.onceDaily,
            times: [ScheduledTime(hour: 8, minute: 0)],
            startDate: DateTime(2026, 1, 1)),
        reminderEnabled: reminders,
        snoozeOverrideMinutes: snooze,
      );

  group('the lengths', () {
    test('only the lengths Notifications offers are known', () {
      expect(MedicineSnooze.options, [1, 5, 10, 15, 30]);
      for (final m in MedicineSnooze.options) {
        expect(MedicineSnooze.isKnown(m), isTrue);
      }
      for (final m in [null, 0, -5, 2, 7, 45, 10000]) {
        expect(MedicineSnooze.isKnown(m), isFalse, reason: '$m');
      }
    });

    test('clean keeps a known length and drops everything else', () {
      expect(MedicineSnooze.clean(15), 15);
      expect(MedicineSnooze.clean(15.0), 15, reason: 'JSON may hand back a double');
      expect(MedicineSnooze.clean(15.5), isNull,
          reason: 'a fraction is not a length anyone chose');
      expect(MedicineSnooze.clean(double.nan), isNull);
      expect(MedicineSnooze.clean(double.infinity), isNull);
      expect(MedicineSnooze.clean(7), isNull);
      expect(MedicineSnooze.clean('15'), isNull);
      expect(MedicineSnooze.clean(null), isNull);
      expect(MedicineSnooze.clean(0), isNull,
          reason: 'a snooze of zero would re-ring at once');
    });

    test('a medicine\'s own choice wins; otherwise the phone-wide length', () {
      expect(MedicineSnooze.effective(15, 5), 15);
      expect(MedicineSnooze.effective(null, 5), 5);
      expect(MedicineSnooze.effective(7, 5), 5,
          reason: 'a value no sheet offers must not become the snooze');
    });

    test('the label says the number, or that it follows the setting', () {
      expect(MedicineSnooze.labelFor(15), '15 min');
      expect(MedicineSnooze.labelFor(null), 'Same as Notifications');
      expect(MedicineSnooze.labelFor(7), 'Same as Notifications');
    });
  });

  group('one alarm, one snooze', () {
    test('one medicine: its own length', () {
      expect(shortestSlotSnooze([entry('a', 15)]), 15);
    });

    test('nobody asked: follow the phone-wide setting', () {
      expect(shortestSlotSnooze([entry('a'), entry('b')]), isNull);
      expect(shortestSlotSnooze([]), isNull);
    });

    test('several that ask: the shortest, whichever order they come in', () {
      expect(shortestSlotSnooze([entry('a', 30), entry('b', 5)]), 5);
      expect(shortestSlotSnooze([entry('a', 5), entry('b', 30)]), 5);
      expect(shortestSlotSnooze([entry('a', 10), entry('b', 10)]), 10);
    });

    test('one asked and one did not: the one that asked', () {
      expect(shortestSlotSnooze([entry('a'), entry('b', 30)]), 30,
          reason: 'a medicine with no preference has nothing to honour');
    });

    test('a length no sheet offers is ignored, not obeyed', () {
      expect(shortestSlotSnooze([entry('a', 0), entry('b', 15)]), 15,
          reason: 'a corrupt 0 must not pull the whole alarm to zero minutes');
      expect(shortestSlotSnooze([entry('a', 7)]), isNull);
    });
  });

  group('the model', () {
    test('it survives JSON', () {
      final back = EnhancedMedicine.fromJson(
          jsonDecode(jsonEncode(med('a', snooze: 15).toJson())));

      expect(back.snoozeOverrideMinutes, 15);
    });

    test('no choice stays no choice — it is not 10', () {
      final back =
          EnhancedMedicine.fromJson(jsonDecode(jsonEncode(med('a').toJson())));

      expect(back.snoozeOverrideMinutes, isNull);
    });

    test('a backup from before this field reads as no choice', () {
      final json = med('a').toJson()..remove('snoozeOverrideMinutes');
      // Every old backup carries the legacy field as 10 — which must NOT turn
      // into a choice, or every restored medicine would snooze for 10 minutes.
      json['snoozeMinutes'] = 10;

      expect(EnhancedMedicine.fromJson(json).snoozeOverrideMinutes, isNull);
    });

    test('a hand-edited length no sheet offers reads as no choice', () {
      final json = med('a').toJson()..['snoozeOverrideMinutes'] = 9999;

      expect(EnhancedMedicine.fromJson(json).snoozeOverrideMinutes, isNull);
    });

    test('copyWith keeps it, and can change it', () {
      expect(med('a', snooze: 15).copyWith(name: 'B').snoozeOverrideMinutes, 15);
      expect(med('a', snooze: 15).copyWith(snoozeOverrideMinutes: 5)
          .snoozeOverrideMinutes, 5);
    });
  });

  group('the slot carries each medicine\'s length', () {
    final day = DateTime(2026, 6, 19);

    test('grouping keeps it per medicine', () {
      final slot =
          groupRemindersBySlot([med('a', snooze: 30), med('b')], day).single;

      expect(slot.medicines.map((m) => m.snooze), [30, null]);
    });

    test('a length no sheet offers is not armed', () {
      final slot = groupRemindersBySlot([med('a', snooze: 7)], day).single;

      expect(slot.medicines.single.snooze, isNull);
    });

    test('it survives the round trip through the persisted alarm entry', () {
      final slot = groupRemindersBySlot([med('a', snooze: 15)], day).single;
      final json = jsonDecode(jsonEncode(slot.medicines.single.toJson()))
          as Map<String, dynamic>;

      expect(json['snooze'], 15);
      expect(SlotMedicine.fromJson(json).snooze, 15);
    });

    test('an entry read back with a length no sheet offers drops it', () {
      for (final bad in [7, 0, 9999, 15.5, '15']) {
        final entry = SlotMedicine.fromJson(
            {'medicineId': 'a', 'name': 'A', 'scheduleJson': '', 'snooze': bad});

        expect(entry.snooze, isNull, reason: '$bad');
      }
    });

    test('with none chosen the entry carries no key at all', () {
      final slot = groupRemindersBySlot([med('a')], day).single;

      expect(slot.medicines.single.toJson().containsKey('snooze'), isFalse,
          reason: 'an alarm armed before this existed looks exactly like this');
    });
  });

  group('the alarm that fires', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const notificationsChannel =
        MethodChannel('dexterous.com/flutter/local_notifications');
    const alarmId = 100480; // 08:00's slot id
    late List<Map<Object?, Object?>> shown;

    setUp(() {
      shown = [];
      AndroidAlarmManager.setTestOverrides(
          getCallbackHandle: (_) => CallbackHandle.fromRawHandle(42));
      messenger.setMockMethodCallHandler(
          AndroidAlarmManager.channel, (call) async => true);
      messenger.setMockMethodCallHandler(notificationsChannel, (call) async {
        if (call.method == 'show') {
          shown.add(call.arguments as Map<Object?, Object?>);
        }
        return true;
      });
      FlutterLocalNotificationsPlatform.instance =
          AndroidFlutterLocalNotificationsPlugin();
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(AndroidAlarmManager.channel, null);
      messenger.setMockMethodCallHandler(notificationsChannel, null);
    });

    /// What the alarm posted: the `alarm:` payload the full-screen alarm opens
    /// with. [stored] is what an earlier fire may have left in the alarm entry.
    Future<Map<String, dynamic>> fire(List<Map<String, dynamic>> medicines,
        {Map<String, dynamic> stored = const {}}) async {
      SharedPreferences.setMockInitialValues({
        'alarm_$alarmId': jsonEncode({
          'title': 'Medicine Reminder 💊',
          'body': 'due',
          'channelId': 'medicine_channel',
          'hour': 8,
          'minute': 0,
          'medicines': medicines,
          ...stored,
        }),
      });
      await alarmCallback(alarmId);
      final payload = shown.single['payload'] as String;
      return jsonDecode(payload.substring('alarm:'.length))
          as Map<String, dynamic>;
    }

    Future<Map<String, dynamic>> persisted() async {
      final prefs = await SharedPreferences.getInstance();
      return jsonDecode(prefs.getString('alarm_$alarmId')!)
          as Map<String, dynamic>;
    }

    test('one medicine with a length: the payload names it', () async {
      final payload = await fire([entry('a', 15)]);

      expect(payload['snoozeDuration'], 15);
      expect(payload['medicineId'], 'a');
    });

    test('one medicine with none: no length in the payload', () async {
      final payload = await fire([entry('a')]);

      expect(payload.containsKey('snoozeDuration'), isFalse,
          reason: 'the alarm then snoozes for the Notifications length');
    });

    test('two that disagree: the shortest', () async {
      final payload = await fire([entry('a', 30), entry('b', 5)]);

      expect(payload['snoozeDuration'], 5);
      expect((payload['medicines'] as List), hasLength(2));
    });

    test('one asked and one did not: the one that asked', () async {
      final payload = await fire([entry('a'), entry('b', 15)]);

      expect(payload['snoozeDuration'], 15);
    });

    test('a corrupt length in the entry is ignored', () async {
      final payload = await fire([entry('a', 0), entry('b', 7)]);

      expect(payload.containsKey('snoozeDuration'), isFalse);
    });

    test('the entry a snooze re-fires from keeps the length', () async {
      await fire([entry('a', 15)]);

      expect((await persisted())['snoozeDuration'], 15,
          reason: 'the snooze handler reads the length from this entry');
      final stored = (await persisted())['payload'] as String;
      expect(jsonDecode(stored.substring('alarm:'.length))['snoozeDuration'], 15);
    });

    test('a length asked for yesterday does not linger when nobody asks today',
        () async {
      // Yesterday both were due and one asked for 5; today only the one that did
      // not ask is due. The entry still says 5.
      final payload = await fire([entry('b')], stored: {'snoozeDuration': 5});

      expect(payload.containsKey('snoozeDuration'), isFalse);
      expect((await persisted()).containsKey('snoozeDuration'), isFalse,
          reason: 'or the snooze would use a length nobody due now asked for');
    });
  });

  group('an iPhone', () {
    late AppDatabase database;
    late RecordingNotificationScheduler os;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tz.setLocalLocation(tz.UTC);
      database = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(database);
      CleanStorageService.resetForTesting();
      await CleanStorageService.init();
      os = RecordingNotificationScheduler();
      NotificationService().schedulerForTesting = os;
    });

    tearDown(() async => database.close());

    Future<Map<String, dynamic>> armedPayload(EnhancedMedicine m) async {
      await withClock(Clock.fixed(DateTime(2026, 10, 28, 6)),
          () => MedicationReminderService().scheduleReminders(m));
      final payload = os.scheduled.single.payload!;
      return jsonDecode(payload.substring('alarm:'.length))
          as Map<String, dynamic>;
    }

    test('a chosen length is in the payload the tap opens the alarm with',
        () async {
      expect((await armedPayload(med('a', snooze: 30)))['snoozeDuration'], 30);
    });

    test('no choice: no length in the payload', () async {
      expect((await armedPayload(med('a'))).containsKey('snoozeDuration'),
          isFalse);
    });

    test('a length no sheet offers is not armed', () async {
      expect((await armedPayload(med('a', snooze: 7))).containsKey('snoozeDuration'),
          isFalse);
    });
  });

  group('screens', () {
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tz.setLocalLocation(tz.UTC);
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      ActiveProfileService().resetForTesting();
      CleanStorageService.resetForTesting();
      await CleanStorageService.init();
      NotificationService().schedulerForTesting =
          RecordingNotificationScheduler();
    });

    tearDown(() async => db.close());

    Future<EnhancedMedicine> stored() async =>
        (await MedicineCleanStorageService.getMedicine('a'))!;

    group('storage', () {
      test('a chosen length is stored and read back', () async {
        await MedicineCleanStorageService.saveMedicine(med('a', snooze: 15));

        expect((await stored()).snoozeOverrideMinutes, 15);
      });

      test('no choice stays no choice', () async {
        await MedicineCleanStorageService.saveMedicine(med('a'));

        expect((await stored()).snoozeOverrideMinutes, isNull);
      });

      test('a length no sheet offers is not stored', () async {
        await MedicineCleanStorageService.saveMedicine(med('a', snooze: 7));

        expect((await stored()).snoozeOverrideMinutes, isNull);
      });
    });

    Future<void> openEdit(WidgetTester tester) async {
      await tester.runAsync(DrugNameCatalog.ensureLoaded);
      final edit = await stored();
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 2000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<bool>(
                builder: (_) => NunitoAddMedicationFlow(
                    editMedicine: edit, debugInitialStep: 4),
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

    group('the form', () {
      testWidgets('a medicine with no choice follows Notifications',
          (tester) async {
        await MedicineCleanStorageService.saveMedicine(med('a'));
        await openEdit(tester);

        expect(cardTexts('Snooze length'),
            contains('Follows Notifications (5 min)'));
      });

      testWidgets('the phone-wide length shown is the one set in Notifications',
          (tester) async {
        await CleanStorageService.setAppPreference('snoozeInterval', 15);
        await MedicineCleanStorageService.saveMedicine(med('a'));
        await openEdit(tester);

        expect(cardTexts('Snooze length'),
            contains('Follows Notifications (15 min)'));
      });

      testWidgets('choosing a length shows it and saves it', (tester) async {
        await MedicineCleanStorageService.saveMedicine(med('a'));
        await openEdit(tester);

        await tapText(tester, 'Snooze length');
        await tester.tap(find.text('30 min'));
        await tester.pumpAndSettle();

        expect(cardTexts('Snooze length'), contains('30 min'));
        await save(tester);
        expect((await stored()).snoozeOverrideMinutes, 30);
      });

      testWidgets('the saved choice is what the form shows next time',
          (tester) async {
        await MedicineCleanStorageService.saveMedicine(med('a', snooze: 15));
        await openEdit(tester);

        expect(cardTexts('Snooze length'), contains('15 min'));
      });

      testWidgets('following the setting again clears a saved choice',
          (tester) async {
        await MedicineCleanStorageService.saveMedicine(med('a', snooze: 15));
        await openEdit(tester);

        await tapText(tester, 'Snooze length');
        await tester.tap(find.text('Same as Notifications'));
        await tester.pumpAndSettle();

        await save(tester);
        expect((await stored()).snoozeOverrideMinutes, isNull);
      });

      testWidgets('dismissing the sheet changes nothing', (tester) async {
        await MedicineCleanStorageService.saveMedicine(med('a', snooze: 15));
        await openEdit(tester);

        await tapText(tester, 'Snooze length');
        await tester.tapAt(const Offset(195, 20)); // the scrim above the sheet
        await tester.pumpAndSettle();

        await save(tester);
        expect((await stored()).snoozeOverrideMinutes, 15);
      });

      testWidgets('changing only the length counts as an unsaved change',
          (tester) async {
        await MedicineCleanStorageService.saveMedicine(med('a'));
        await openEdit(tester);

        await tapText(tester, 'Snooze length');
        await tester.tap(find.text('1 min'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();

        expect(find.text('Discard changes?'), findsOneWidget);
      });

      testWidgets('with reminders off there is no length to pick, and none is kept',
          (tester) async {
        await MedicineCleanStorageService.saveMedicine(med('a', snooze: 15));
        await openEdit(tester);

        await tapText(tester, 'Reminders');
        expect(find.text('Snooze length'), findsNothing);

        await save(tester);
        expect((await stored()).snoozeOverrideMinutes, isNull,
            reason: 'a silenced medicine must not keep a length it cannot use');
      });
    });

    group('the medicine\'s own screen', () {
      testWidgets('shows a chosen length', (tester) async {
        await MedicineCleanStorageService.saveMedicine(med('a', snooze: 15));
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(390, 3000);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme,
            home: NunitoMedicationDetailScreen(medicine: await stored())));
        await tester.pumpAndSettle();

        expect(find.text('Snooze length'), findsOneWidget);
        expect(find.text('15 min'), findsOneWidget);
      });

      testWidgets('says nothing when there is no choice', (tester) async {
        await MedicineCleanStorageService.saveMedicine(med('a'));
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(390, 3000);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme,
            home: NunitoMedicationDetailScreen(medicine: await stored())));
        await tester.pumpAndSettle();

        expect(find.text('Snooze length'), findsNothing);
      });
    });

    group('the take sheet\'s Snooze', () {
      // Held here, not returned: it completes only when the sheet closes.
      late Future<Map<String, dynamic>?> answer;

      Future<void> open(WidgetTester tester, EnhancedMedicine m) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(390, 1800);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => answer =
                    showModalBottomSheet<Map<String, dynamic>>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => NunitoTakeMedicationSheet(
                      medicine: m, scheduledTime: DateTime(2026, 10, 28, 8)),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }

      Future<int?> snoozedFor(WidgetTester tester) async {
        await tester.tap(find.text('Snooze'));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        final result = await answer;
        return result?['minutes'] as int?;
      }

      testWidgets('uses this medicine\'s own length', (tester) async {
        await open(tester, med('a', snooze: 15));

        expect(await snoozedFor(tester), 15);
      });

      testWidgets('without one it uses the Notifications length, not a fixed 10',
          (tester) async {
        await CleanStorageService.setAppPreference('snoozeInterval', 30);
        await open(tester, med('a'));

        expect(await snoozedFor(tester), 30);
      });
    });
  });
}

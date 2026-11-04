/// An iPhone's dose reminders for a medicine that is not due every day run out, so
/// the app arms them again when it comes back to the foreground — not only when
/// it starts, which an app that stays alive in the background for weeks never does.
library;

import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' show PendingNotificationRequest;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' as db;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/services/reminder_reschedule_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  final now = DateTime(2026, 10, 28, 10, 0);
  late db.AppDatabase database;
  late int passes;
  late RecordingNotificationScheduler os;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tz.setLocalLocation(tz.UTC);
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    db.AppDatabase.setInstanceForTesting(database);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    os = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = os;
    passes = 0;
    ReminderRescheduleService.passForTesting = () async => passes++;
    ReminderRescheduleService.isIosForTesting = true;
  });

  tearDown(() async {
    ReminderRescheduleService.passForTesting = null;
    ReminderRescheduleService.isIosForTesting = null;
    await database.close();
  });

  Future<void> stampedAgo(Duration ago) => CleanStorageService.setAppPreference(
      ReminderRescheduleService.dosesArmedAtKey,
      now.subtract(ago).millisecondsSinceEpoch);

  Future<void> ask({Duration? maxAge}) => withClock(
      Clock.fixed(now),
      () => maxAge == null
          ? ReminderRescheduleService.rearmDosesIfStale()
          : ReminderRescheduleService.rearmDosesIfStale(maxAge: maxAge));

  group('coming back to the foreground', () {
    test('arms them when they never have been', () async {
      await ask();
      expect(passes, 1);
    });

    test('leaves them alone when they were armed an hour ago', () async {
      await stampedAgo(const Duration(hours: 1));
      await ask();
      expect(passes, 0,
          reason: 'resume fires on every return from a permission dialog or the '
              'app switcher; this must not be a full re-arm each time');
    });

    test('arms them when it has been a day', () async {
      await stampedAgo(const Duration(hours: 13));
      await ask();
      expect(passes, 1);
    });

    test('arms them at exactly the age limit, not a moment later', () async {
      await stampedAgo(const Duration(hours: 12));
      await ask();
      expect(passes, 1);
      passes = 0;
      await stampedAgo(const Duration(hours: 12) - const Duration(seconds: 1));
      await ask();
      expect(passes, 0);
    });

    test('a stamp from the future (the clock was set back) does not count as fresh',
        () async {
      await stampedAgo(const Duration(hours: -5));
      await ask();
      expect(passes, 1);
    });

    test('the age limit is the caller\'s to choose', () async {
      await stampedAgo(const Duration(hours: 3));
      await ask(maxAge: const Duration(hours: 2));
      expect(passes, 1);
      passes = 0;
      await ask(maxAge: const Duration(hours: 4));
      expect(passes, 0);
    });

    test('an unreadable stamp is treated as never', () async {
      await CleanStorageService.setAppPreference(
          ReminderRescheduleService.dosesArmedAtKey, 'yesterday');
      await ask();
      expect(passes, 1);
    });

    test('does nothing at all off an iPhone: Android\'s alarms never run out', () async {
      ReminderRescheduleService.isIosForTesting = false;
      await ask();
      expect(passes, 0);
    });
  });

  group('what the pass it asks for does', () {
    setUp(() => ReminderRescheduleService.passForTesting = null);

    test('re-arms the medicines and nothing else', () async {
      await withClock(Clock.fixed(now), ReminderRescheduleService.rearmDosesIfStale);
      expect(ReminderRescheduleService.lastPassFamilies, ['medicines'],
          reason: 'not every water, vitals and refill reminder cancelled and armed '
              'again just to refresh the doses');
    });

    test('a start, or any request for a full pass, is still a pass over all of them',
        () async {
      await withClock(Clock.fixed(now), ReminderRescheduleService.rescheduleAllReminders);
      expect(ReminderRescheduleService.lastPassFamilies,
          ReminderRescheduleService.familyNames);
      await withClock(Clock.fixed(now), ReminderRescheduleService.rearmReminders);
      expect(ReminderRescheduleService.lastPassFamilies,
          ReminderRescheduleService.familyNames);
    });

    test('and the pass for the doses after a full one is the doses alone again', () async {
      await withClock(Clock.fixed(now), ReminderRescheduleService.rearmReminders);
      expect(ReminderRescheduleService.lastPassFamilies,
          ReminderRescheduleService.familyNames, reason: 'premise');
      // That pass armed the doses, so they are fresh; a day later they are not.
      await stampedAgo(const Duration(hours: 13));

      await withClock(Clock.fixed(now), ReminderRescheduleService.rearmDosesIfStale);

      expect(ReminderRescheduleService.lastPassFamilies, ['medicines'],
          reason: 'the request for everything was used up by the pass that served it');
    });

    test('a full pass asked for while one for the doses runs is still a full one', () async {
      final gated = _GatedScheduler();
      os = gated;
      NotificationService().schedulerForTesting = gated;
      await MedicineCleanStorageService.saveMedicine(EnhancedMedicine(
        id: 'm1',
        name: 'Methotrexate',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
            frequencyType: FrequencyType.onceDaily,
            times: [ScheduledTime(hour: 8, minute: 0)]),
      ));
      gated.gate = Completer<void>();

      // The pass for the doses, held where the medicines ask the phone what is armed.
      final doses = withClock(Clock.fixed(now), ReminderRescheduleService.rearmDosesIfStale);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(ReminderRescheduleService.lastPassFamilies, ['medicines'], reason: 'premise');
      final full = withClock(Clock.fixed(now), ReminderRescheduleService.rearmReminders);
      gated.gate!.complete();
      await Future.wait([doses, full]);

      expect(ReminderRescheduleService.lastPassFamilies,
          ReminderRescheduleService.familyNames,
          reason: 'the request for everything was owed a pass over everything, '
              'not the doses-only one that was already under way');
    });

    test('does nothing while a pass is already running: that one is arming them', () async {
      final gate = Completer<void>();
      ReminderRescheduleService.passForTesting = () async {
        passes++;
        await gate.future;
      };
      final running = ReminderRescheduleService.rearmReminders();
      await Future<void>.delayed(Duration.zero);

      await ReminderRescheduleService.rearmDosesIfStale();
      gate.complete();
      await running;

      expect(passes, 1, reason: 'not a second, redundant pass queued behind it');
    });
  });

  group('the stamp', () {
    EnhancedMedicine weekly() => EnhancedMedicine(
          id: 'm1',
          name: 'Methotrexate',
          dosageForm: DosageForm.tablet,
          dosageAmount: 1,
          schedule: MedicineSchedule(
              frequencyType: FrequencyType.specificDays,
              times: [ScheduledTime(hour: 8, minute: 0)],
              specificDays: [DateTime.thursday]),
        );

    test('is written when the phone refused the doses too, saying so', () async {
      await MedicineCleanStorageService.saveMedicine(weekly());
      ReminderRescheduleService.passForTesting = null;
      os.midCallError = StateError('the OS said no');
      os.refuseExactMidCall.addAll([for (var i = 0; i < 24; i++) 100000 + i]);

      await withClock(Clock.fixed(now), ReminderRescheduleService.rescheduleAllReminders);

      expect(os.scheduled.where((r) => r.id >= 100000 && r.id < 100024), isEmpty,
          reason: 'premise: nothing was armed');
      expect(
          CleanStorageService.getAppPreference(
              ReminderRescheduleService.dosesArmedAtKey, null),
          now.millisecondsSinceEpoch,
          reason: 'with no stamp every return to the app would be a pass');
      expect(
          CleanStorageService.getAppPreference(
              ReminderRescheduleService.dosesRefusedKey, null),
          isTrue);
    });

    test('and it is tried again within the hour, not left for twelve', () async {
      await CleanStorageService.setAppPreference(
          ReminderRescheduleService.dosesRefusedKey, true);
      await stampedAgo(const Duration(minutes: 90));
      await ask();
      expect(passes, 1, reason: 'refused last time: worth another try');
    });

    test('but not at every return to the app', () async {
      await CleanStorageService.setAppPreference(
          ReminderRescheduleService.dosesRefusedKey, true);
      await stampedAgo(const Duration(minutes: 20));
      await ask();
      expect(passes, 0);
    });

    test('a clean pass is left alone for the full twelve hours', () async {
      await CleanStorageService.setAppPreference(
          ReminderRescheduleService.dosesRefusedKey, false);
      await stampedAgo(const Duration(hours: 5));
      await ask();
      expect(passes, 0);
    });

    test('a shorter limit asked for by the caller still wins over the retry window', () async {
      await CleanStorageService.setAppPreference(
          ReminderRescheduleService.dosesRefusedKey, true);
      await stampedAgo(const Duration(minutes: 30));
      await ask(maxAge: const Duration(minutes: 10));
      expect(passes, 1);
    });

    test('is written when they were all armed', () async {
      await MedicineCleanStorageService.saveMedicine(weekly());
      ReminderRescheduleService.passForTesting = null;

      await withClock(Clock.fixed(now), ReminderRescheduleService.rescheduleAllReminders);

      expect(os.scheduled.where((r) => r.id >= 100000 && r.id < 100024), isNotEmpty);
      expect(
          CleanStorageService.getAppPreference(
              ReminderRescheduleService.dosesArmedAtKey, null),
          now.millisecondsSinceEpoch);
      expect(
          CleanStorageService.getAppPreference(
              ReminderRescheduleService.dosesRefusedKey, null),
          isFalse);
    });


    test('is written when a pass has armed the medicines', () async {
      ReminderRescheduleService.passForTesting = null;
      await withClock(Clock.fixed(now), ReminderRescheduleService.rescheduleAllReminders);

      expect(
          CleanStorageService.getAppPreference(
              ReminderRescheduleService.dosesArmedAtKey, null),
          now.millisecondsSinceEpoch);
    });

    test('so a start, then a resume a minute later, arms once and not twice', () async {
      ReminderRescheduleService.passForTesting = null;
      await withClock(Clock.fixed(now), ReminderRescheduleService.rescheduleAllReminders);
      ReminderRescheduleService.passForTesting = () async => passes++;

      await withClock(Clock.fixed(now.add(const Duration(minutes: 1))),
          ReminderRescheduleService.rearmDosesIfStale);

      expect(passes, 0);
    });
  });

  group('the shell', () {
    test('asks on resume', () {
      final shell = File('lib/features/home/screens/app_shell.dart').readAsStringSync();
      final start = shell.indexOf('void didChangeAppLifecycleState(');
      expect(start, greaterThan(-1), reason: 'this test needs rewriting, not deleting');
      final body = shell.substring(start, shell.indexOf('\n  }', start));
      expect(body, contains('ReminderRescheduleService.rearmDosesIfStale()'));
    });
  });
}

/// A phone that takes its time to say what it has pending, so a pass can be held
/// at the moment the medicines ask.
class _GatedScheduler extends RecordingNotificationScheduler {
  Completer<void>? gate;

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    final g = gate;
    if (g != null) await g.future;
    return super.pendingNotificationRequests();
  }
}

/// A reminder is armed knowing which reminder it is — so the buttons on its
/// notification know what they are about.
///
/// Done and Later are tapped on a notification, not in the app; all the tap has
/// to go on is the payload the notification was armed with. If the reminder's id
/// is not in it at arming time, the buttons are decoration.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_escalation.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_alarm.dart';
import 'package:tablet_remainder/features/reminders/utils/reminder_payload.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingNotificationScheduler rec;

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    rec = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = rec;
  });

  final monday9 = DateTime(2030, 1, 7, 9);

  Future<void> arm({
    String? reminderId,
    RepeatType repeat = RepeatType.weekly,
    List<int>? customDays,
    ReminderEscalation escalation = ReminderEscalation.standard,
  }) async {
    final ok = await NotificationService().scheduleGenericReminder(
      id: 4321,
      title: 'Call the clinic',
      body: 'About the results',
      scheduledTime: monday9,
      repeatType: repeat,
      customDays: customDays,
      escalation: escalation,
      reminderId: reminderId,
    );
    expect(ok, isTrue);
  }

  List<String> buttons(RecordedSchedule s) =>
      [for (final a in s.details!.android!.actions ?? const <AndroidNotificationAction>[]) a.id];

  group('the id rides in every registration', () {
    test('a weekly reminder', () async {
      await arm(reminderId: 'r-1');
      expect(rec.scheduled, hasLength(1));
      expect(reminderIdFromAlarmPayload(rec.scheduled.single.payload), 'r-1');
    });

    test('a weekdays reminder: one per weekday, each knowing it', () async {
      await arm(reminderId: 'r-1', repeat: RepeatType.weekdays);
      expect(rec.scheduled, hasLength(5));
      for (final s in rec.scheduled) {
        expect(reminderIdFromAlarmPayload(s.payload), 'r-1',
            reason: 'registration ${s.id}');
      }
    });

    test('a weekends reminder', () async {
      await arm(reminderId: 'r-1', repeat: RepeatType.weekends);
      expect(rec.scheduled, hasLength(2));
      for (final s in rec.scheduled) {
        expect(reminderIdFromAlarmPayload(s.payload), 'r-1');
      }
    });

    test('a custom-days reminder', () async {
      await arm(reminderId: 'r-1', repeat: RepeatType.custom, customDays: [1, 3, 5]);
      expect(rec.scheduled, hasLength(3));
      for (final s in rec.scheduled) {
        expect(reminderIdFromAlarmPayload(s.payload), 'r-1');
      }
    });

    test('a reminder not in the list carries none', () async {
      await arm(reminderId: null);
      expect(reminderIdFromAlarmPayload(rec.scheduled.single.payload), isNull,
          reason: 'water, vitals, focus: nothing to mark done');
    });
  });

  group('and the buttons that go with it', () {
    test('a quiet reminder (the default tier): Done and Later', () async {
      await arm(reminderId: 'r-1');
      expect(buttons(rec.scheduled.single),
          [ReminderActions.doneId, ReminderActions.laterId]);
    });

    test('an insistent one: Done, Snooze, Later', () async {
      await arm(reminderId: 'r-1', escalation: ReminderEscalation.insistent);
      expect(buttons(rec.scheduled.single),
          [ReminderActions.doneId, 'snooze', ReminderActions.laterId]);
    });

    test('every weekday registration carries them', () async {
      await arm(
          reminderId: 'r-1',
          repeat: RepeatType.weekdays,
          escalation: ReminderEscalation.insistent);
      for (final s in rec.scheduled) {
        expect(buttons(s), contains(ReminderActions.doneId), reason: '${s.id}');
      }
    });

    test('a reminder not in the list has none of them', () async {
      await arm(reminderId: null, escalation: ReminderEscalation.insistent);
      expect(buttons(rec.scheduled.single), ['snooze', 'dismiss']);
    });

    test('on iPhone, the category that declares them', () async {
      await arm(reminderId: 'r-1');
      expect(rec.scheduled.single.details!.iOS!.categoryIdentifier,
          NotificationService.darwinReminderCategoryId,
          reason: 'a category id with no registered category produces no buttons, '
              'and no error — see ios_action_parity_test');
    });

    test('and not for a reminder that is not in the list', () async {
      await arm(reminderId: null);
      expect(rec.scheduled.single.details!.iOS!.categoryIdentifier, isNull);
    });
  });

  test('the alarm seam hands the reminder\'s own id down to its notification',
      () async {
    // `ReminderAlarm.arm` is the one place a reminder's notification is armed;
    // it must pass the id on, or none of the above ever happens.
    final request = ReminderArmRequest(
      id: 4321,
      title: 'Call the clinic',
      body: '',
      scheduledTime: monday9,
      repeatType: RepeatType.weekly,
      reminderId: 'r-9',
    );

    await const NotificationReminderAlarm().arm(request);

    expect(reminderIdFromAlarmPayload(rec.scheduled.single.payload), 'r-9');
  });
}

/// A medicine can ask its reminder to ring with one of the bundled sounds.
///
/// The model carried a `reminderSound` and nothing stored or used it. The part
/// worth pinning without a device is the decision that has no obvious answer: a
/// time slot is ONE alarm however many medicines share its minute, so it can loop
/// only one sound — and when the medicines disagree, picking a winner would let
/// one medicine's choice override another's.
library;

import 'dart:convert';
import 'dart:ui' show CallbackHandle;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show AndroidFlutterLocalNotificationsPlugin;
// ignore: depend_on_referenced_packages
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart'
    show FlutterLocalNotificationsPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/services/background_alarm_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/reminder_slot_grouping.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_sounds.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> entry(String id, [String? sound]) => {
        'medicineId': id,
        'name': 'Medicine $id',
        'scheduleJson': '',
        'sound': ?sound,
      };

  group('the catalogue', () {
    test('a bundled key is known, anything else is not', () {
      expect(ReminderSounds.isKnown('marimba'), isTrue);
      expect(ReminderSounds.isKnown('default'), isTrue);
      expect(ReminderSounds.isKnown(null), isFalse);
      expect(ReminderSounds.isKnown(''), isFalse);
      expect(ReminderSounds.isKnown('/storage/ring.mp3'), isFalse,
          reason: 'a device file is not a bundled sound');
      expect(ReminderSounds.isKnown('removed_in_v9'), isFalse);
    });

    test('a label is the sound\'s name, and an unknown key reads as Default', () {
      expect(ReminderSounds.labelFor('soft_bells'), 'Soft Bells');
      expect(ReminderSounds.labelFor(null), 'Default');
      expect(ReminderSounds.labelFor('removed_in_v9'), 'Default');
    });

    test('every sound has an audio file the alarm screen will look for', () {
      // The alarm screen loads assets/sounds/<key>.wav; the catalogue's own
      // asset path must agree for every key except `default`, which is chime.
      for (final e in ReminderSounds.options.entries) {
        if (e.key == 'default') continue;
        expect(e.value['asset'], 'assets/sounds/${e.key}.wav');
      }
    });
  });

  group('commonSlotSound', () {
    test('one medicine: its own sound', () {
      expect(commonSlotSound([entry('a', 'marimba')]), 'marimba');
    });

    test('one medicine with none: the standard sound', () {
      expect(commonSlotSound([entry('a')]), isNull);
    });

    test('several that agree: that sound', () {
      expect(
          commonSlotSound([entry('a', 'calm'), entry('b', 'calm')]), 'calm');
    });

    test('several that disagree: the standard sound, not either one', () {
      expect(commonSlotSound([entry('a', 'calm'), entry('b', 'marimba')]),
          isNull);
    });

    test('one asked for a sound and another asked for none: the standard sound',
        () {
      expect(commonSlotSound([entry('a', 'calm'), entry('b')]), isNull);
      expect(commonSlotSound([entry('b'), entry('a', 'calm')]), isNull,
          reason: 'whichever comes first');
    });

    test('a sound the app does not have rings the standard one', () {
      expect(commonSlotSound([entry('a', 'removed_in_v9')]), isNull);
      expect(commonSlotSound([entry('a', '/storage/ring.mp3')]), isNull);
    });

    test('nothing due: nothing to ring', () {
      expect(commonSlotSound(const []), isNull);
    });
  });

  group('the slot carries each medicine\'s sound', () {
    EnhancedMedicine med(String id, {String? sound}) => EnhancedMedicine(
          id: id,
          name: 'Medicine $id',
          dosageForm: DosageForm.tablet,
          dosageAmount: 1,
          schedule: MedicineSchedule(
              frequencyType: FrequencyType.onceDaily,
              times: [ScheduledTime(hour: 8, minute: 0)],
              startDate: DateTime(2026, 1, 1)),
          reminderSound: sound,
        );

    final day = DateTime(2026, 6, 19);

    test('grouping keeps it per medicine', () {
      final slot = groupRemindersBySlot(
          [med('a', sound: 'marimba'), med('b')], day).single;

      expect(slot.medicines.map((m) => m.sound), ['marimba', null]);
    });

    test('an unknown stored key is dropped, not armed', () {
      final slot = groupRemindersBySlot(
          [med('a', sound: 'removed_in_v9')], day).single;

      expect(slot.medicines.single.sound, isNull);
    });

    test('it survives the round trip through the persisted alarm entry', () {
      final slot =
          groupRemindersBySlot([med('a', sound: 'pulse')], day).single;
      final json = jsonDecode(jsonEncode(slot.medicines.single.toJson()))
          as Map<String, dynamic>;

      expect(json['sound'], 'pulse');
      expect(SlotMedicine.fromJson(json).sound, 'pulse');
    });

    test('and with none chosen the entry carries no sound key at all', () {
      final slot = groupRemindersBySlot([med('a')], day).single;

      expect(slot.medicines.single.toJson().containsKey('sound'), isFalse,
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

    /// What the alarm posted: the `alarm:` payload the full-screen alarm opens with.
    Future<Map<String, dynamic>> fire(List<Map<String, dynamic>> medicines) async {
      SharedPreferences.setMockInitialValues({
        'alarm_$alarmId': jsonEncode({
          'title': 'Medicine Reminder 💊',
          'body': 'due',
          'channelId': 'medicine_channel',
          'hour': 8,
          'minute': 0,
          'medicines': medicines,
        }),
      });
      await alarmCallback(alarmId);
      final payload = shown.single['payload'] as String;
      return jsonDecode(payload.substring('alarm:'.length))
          as Map<String, dynamic>;
    }

    test('one medicine with a sound: the payload names it', () async {
      final payload = await fire([entry('a', 'marimba')]);

      expect(payload['sound'], 'marimba');
      expect(payload['medicineId'], 'a');
    });

    test('one medicine with none: no sound in the payload', () async {
      final payload = await fire([entry('a')]);

      expect(payload.containsKey('sound'), isFalse,
          reason: 'the alarm screen then loops the standard sound');
    });

    test('a sound the app does not have rings the standard one', () async {
      final single = await fire([entry('a', 'removed_in_v9')]);
      expect(single.containsKey('sound'), isFalse);

      shown.clear();
      final group = await fire(
          [entry('a', 'removed_in_v9'), entry('b', 'removed_in_v9')]);
      expect(group.containsKey('sound'), isFalse,
          reason: 'two medicines agreeing on a sound that is gone');
    });

    test('two medicines that agree: the payload names the sound', () async {
      final payload = await fire([entry('a', 'calm'), entry('b', 'calm')]);

      expect(payload['sound'], 'calm');
      expect((payload['medicines'] as List), hasLength(2));
    });

    test('two medicines that disagree: the standard sound', () async {
      final payload = await fire([entry('a', 'calm'), entry('b', 'pulse')]);

      expect(payload.containsKey('sound'), isFalse);
      expect((payload['medicines'] as List), hasLength(2),
          reason: 'both are still in the alarm');
    });

    test('the payload a snooze re-fires with keeps the sound', () async {
      await fire([entry('a', 'marimba')]);

      final prefs = await SharedPreferences.getInstance();
      final stored = jsonDecode(prefs.getString('alarm_$alarmId')!)
          as Map<String, dynamic>;
      final persisted = stored['payload'] as String;
      expect(jsonDecode(persisted.substring('alarm:'.length))['sound'],
          'marimba',
          reason: 'a snooze reads this stored payload back');
    });
  });
}

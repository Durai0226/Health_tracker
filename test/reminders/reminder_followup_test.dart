import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/daos/reminders_dao.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/reminder_reschedule_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_kind.dart';

import '../support/reminder_harness.dart';

/// A follow-up is the cheapest fix for the most common failure: the notification
/// arrived while the user's hands were full and was dismissed by reflex. Apple
/// Health Medications does exactly this — a second notification if the dose has
/// not been logged within 30 minutes.
///
/// It has to work while the app is DEAD, which is why it is armed alongside the
/// reminder rather than by a resume-time sweep: a user who is in the app does
/// not need a follow-up notification.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('escalation reaches the scheduler', () {
    reminderTest('an insistent reminder carries its tier and id', (h) async {
      final r = await h.seed('r-1', at: h.now.add(const Duration(hours: 1)));
      await CleanStorageService.saveReminder(
          r.copyWith(escalation: ReminderEscalation.insistent));
      await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);

      final req = h.alarm.armed.single;
      expect(req.escalation, ReminderEscalation.insistent);
      expect(req.reminderId, 'r-1',
          reason: 'the follow-up keys its resolved flag on this');
    });

    reminderTest('a quiet reminder asks for no follow-up', (h) async {
      final r = await h.seed('r-1', at: h.now.add(const Duration(hours: 1)));
      await CleanStorageService.saveReminder(
          r.copyWith(escalation: ReminderEscalation.gentle));
      await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);
      expect(h.alarm.armed.single.escalation.hasFollowUp, isFalse);
    });

    reminderTest('the default tier is standard, which does not follow up',
        (h) async {
      await h.seed('r-1', at: h.now.add(const Duration(hours: 1)));
      await ReminderRescheduleService.rescheduleGenericReminders(
          alarm: h.alarm);
      expect(h.alarm.armed.single.escalation, ReminderEscalation.standard);
      expect(h.alarm.armed.single.escalation.hasFollowUp, isFalse,
          reason: 'opting everyone into a second notification by default is '
              'exactly the notification fatigue this is meant to avoid');
    });
  });

  group('the follow-up id stays out of everyone else\'s way', () {
    test('it lands inside the reserved block, clear of the sub-ids', () {
      // Base ids occupy 970000-970999 and the scheduler derives weekday sub-ids
      // at +1..+7 (up to 971006). A follow-up at +2000 clears both and stays
      // inside 970000-979999, below the period family at 990001.
      for (var i = 0; i < genericReminderIdCapacity; i++) {
        final base = genericReminderIdBase + i;
        final followUp = base + genericReminderFollowUpOffset;
        expect(followUp, greaterThan(base + 7),
            reason: 'must not collide with a weekday sub-id');
        expect(followUp, lessThan(980000));
      }
    });

    test('no follow-up id collides with another reminder\'s base or sub-id', () {
      final bases = <int>{
        for (var i = 0; i < genericReminderIdCapacity; i++)
          genericReminderIdBase + i,
      };
      final subIds = <int>{
        for (final b in bases)
          for (var d = 1; d <= 7; d++) b + d,
      };
      final followUps = {for (final b in bases) b + genericReminderFollowUpOffset};
      expect(followUps.intersection(bases), isEmpty);
      expect(followUps.intersection(subIds), isEmpty);
    });
  });

  group('only critical keeps asking', () {
    test('autoRepeat tracks the tier, not the follow-up flag', () {
      // Insistent nudges once and lets go; critical is the Due pattern.
      // Conflating the two would turn every insistent reminder into a repeating
      // alarm the user can only escape by deleting it.
      expect(ReminderEscalation.insistent.hasFollowUp, isTrue);
      expect(ReminderEscalation.insistent.autoSnoozeUntilActedOn, isFalse);
      expect(ReminderEscalation.critical.autoSnoozeUntilActedOn, isTrue);
      for (final e in [ReminderEscalation.gentle, ReminderEscalation.standard]) {
        expect(e.autoSnoozeUntilActedOn, isFalse, reason: e.name);
      }
    });

    test('the callback DELEGATES to nextEscalationStep, not its own copy', () async {
      // This branch used to reimplement the same round/cap rule the pure
      // function already expressed and its tests already covered — two
      // implementations of one rule, which is the drift that let the two
      // background handlers and the two snooze counters diverge before they
      // were merged.
      final code = await File('lib/core/services/background_alarm_service.dart')
          .readAsString();
      final branch = code.substring(
        code.indexOf("if (alarmData['isReminderFollowUp'] == true)"),
        code.indexOf('final rawMedicines'),
      );
      expect(branch, contains('nextEscalationStep('));
      expect(branch, contains('EscalationStep.autoSnooze'));
      expect(branch, contains('EscalationStep.finalNotice'));
      expect(branch.contains("alarmData['autoRepeat']"), isFalse,
          reason: 'a pre-computed flag in the blob puts the decision back in '
              'two places');
    });

    test('the chaining is capped and suppressed once resolved', () async {
      final code = await File('lib/core/services/background_alarm_service.dart')
          .readAsString();
      final branch = code.substring(
        code.indexOf("if (alarmData['isReminderFollowUp'] == true)"),
        code.indexOf('final rawMedicines'),
      );
      // Order matters: the resolved check must come BEFORE the re-arm, or a
      // reminder the user just completed schedules its own next nag.
      final resolvedAt = branch.indexOf('reminderResolvedKey');
      final rearmAt = branch.indexOf('_registerAlarm');
      expect(resolvedAt, greaterThan(-1));
      expect(rearmAt, greaterThan(resolvedAt),
          reason: 'checking resolution after re-arming would nag about a '
              'reminder that is already done');
      expect(branch, contains('maxSnoozes: cap'),
          reason: 'the cap must reach the decision function; uncapped this '
              'is harassment with no exit but deleting the reminder');
      expect(branch, contains('maxSnoozeCountKey'),
          reason: 'the cap is the user\'s setting, not a constant');
    });
  });

  group('resolving an occurrence tells the alarm isolate', () {
    reminderTest('a resolved outcome writes the shared flag', (h) async {
      // The alarm isolate has no Drift connection, so the occurrence row alone
      // is invisible to it. Without this flag a follow-up nags about a reminder
      // the user ticked off twenty minutes earlier.
      await h.seed('r-1', at: h.now);
      await CleanStorageService.recordReminderOutcome(
        reminderId: 'r-1',
        scheduledFor: h.now,
        outcome: ReminderOutcome.done,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(reminderResolvedKey('r-1', h.now)), isTrue);
    });

    reminderTest('a still-pending outcome writes nothing', (h) async {
      await h.seed('r-1', at: h.now);
      await CleanStorageService.recordReminderOutcome(
        reminderId: 'r-1',
        scheduledFor: h.now,
        outcome: ReminderOutcome.pending,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(reminderResolvedKey('r-1', h.now)), isNull,
          reason: 'suppressing a follow-up for an unresolved reminder is the '
              'exact failure this feature exists to prevent');
    });

    reminderTest('the key is per occurrence, not per reminder', (h) async {
      // A daily reminder resolved today must not suppress tomorrow's follow-up.
      final today = h.now;
      final tomorrow = h.now.add(const Duration(days: 1));
      await CleanStorageService.recordReminderOutcome(
        reminderId: 'r-1',
        scheduledFor: today,
        outcome: ReminderOutcome.done,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(reminderResolvedKey('r-1', today)), isTrue);
      expect(prefs.getBool(reminderResolvedKey('r-1', tomorrow)), isNull);
    });
  });
}

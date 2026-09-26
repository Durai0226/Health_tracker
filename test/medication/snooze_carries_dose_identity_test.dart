import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// In-app Snooze rescheduled a nameless reminder that could not log anything.
///
/// `snoozeReminderForDose` called `snoozeReminder(notificationId, minutes)` with
/// no title, body, medicineId, hour or minute. Slot ids are not in
/// `CleanStorageService.getReminders()`, so the lookup inside
/// `NotificationService.snoozeReminder` found nothing and fell back to
/// "Reminder" / "Time for your reminder", with `medicineId: null` in the alarm
/// payload and no dose actions on the notification.
///
/// Ten minutes later the user saw "⏰ Snoozed: Reminder — Time for your
/// reminder": no medicine name, no Take button. Tapping it opened the
/// AlarmScreen, whose `_payloadMedicineIds()` returned an empty list, so Take
/// looped over nothing — the notification closed, no dose was logged, no stock
/// was decremented, nothing was surfaced, and at the grace cutoff
/// reconciliation marked the dose missed.
///
/// The take sheet compounded it by ignoring the returned bool and toasting
/// "Snoozed for 10 min" even when nothing had been rescheduled.
void main() {
  final medService = File(
          'lib/features/medication/services/medication_reminder_service.dart')
      .readAsStringSync();
  final notif =
      File('lib/core/services/notification_service.dart').readAsStringSync();
  final sheet = File(
          'lib/features/medication/screens/nunito_take_medication_sheet.dart')
      .readAsStringSync();

  /// The body of `snoozeReminderForDose`, bounded by the next method — safer
  /// than a fixed character window, which runs off the end of the file.
  String snoozeForDoseBody() {
    final start = medService.indexOf('Future<bool> snoozeReminderForDose(');
    expect(start, greaterThan(-1));
    final end = medService.indexOf('\n  /// Find the index of the schedule', start);
    return medService.substring(start, end > start ? end : medService.length);
  }

  group('the dose identity travels with the snooze', () {
    test('positive: snoozeReminderForDose forwards name, id and slot time', () {
      final body = snoozeForDoseBody();
      expect(body, contains('medicineId: medicine.id'),
          reason: 'without it the AlarmScreen cannot resolve the dose');
      expect(body, contains('hour: scheduledTime.hour'));
      expect(body, contains('minute: scheduledTime.minute'));
      expect(body, contains('final title = medicine.name'),
          reason: 'the notification must name the medicine');
    });

    test('both platforms forward it, not just Android', () {
      final body = snoozeForDoseBody();
      // Two call sites: the Android slot id and the iOS legacy id.
      expect('medicineId: medicine.id'.allMatches(body).length, 2,
          reason: 'the iOS path had the same defect');
    });

    test('positive: a medicine snooze re-fires WITH dose actions', () {
      expect(notif, contains('doseActions: medicineId != null'),
          reason: 'a re-fire with no Take button forces the user back into '
              'the app to log a dose they are holding in their hand');
    });

    test('negative: a generic reminder snooze still carries no dose actions',
        () {
      // `medicineId != null` is the discriminator — a plain reminder has
      // nothing to take, and offering Take on one would be meaningless.
      expect(notif, isNot(contains('doseActions: true,\n        androidScheduleMode')),
          reason: 'dose actions must be conditional, not unconditional');
    });
  });

  group('the sheet reports the truth', () {
    test('positive: a failed snooze is surfaced and the sheet stays open', () {
      expect(sheet, contains('final ok = await MedicationReminderService()'),
          reason: 'the returned bool was discarded');
      expect(sheet, contains("Couldn't snooze this reminder"));
      expect(sheet, contains('if (!ok) {'));
      // Keeping the sheet open matters: closing it strands the dose with no
      // reminder and no record.
      final at = sheet.indexOf('if (!ok) {');
      expect(sheet.substring(at, at + 400), contains('return;'));
      expect(sheet.substring(at, at + 400), isNot(contains('Navigator.pop')));
    });

    test('negative: the raw exception string is no longer shown to a patient',
        () {
      expect(sheet, isNot(contains("context.toastError('Error: \$e')")),
          reason: 'an exception string is not something a patient can act on');
    });
  });
}

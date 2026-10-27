import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// On iOS, a dose notification had **no buttons at all** — silently.
///
/// iOS requires actions to be declared up front on a `DarwinNotificationCategory`
/// at `initialize()` time, unlike Android where they ride on the notification
/// itself. Only the water category was ever registered, so while Android offered
/// Take / Snooze / Dismiss, iOS offered nothing, with no error to indicate it.
/// `docs/ux-review.md` calls one-tap Take "the app's single best accelerator"
/// and this gap "a real capability difference".
///
/// A source guard because the failure mode is structural and invisible at
/// runtime: setting `categoryIdentifier` without registering the category
/// produces a notification with no buttons and no complaint.
String _codeOnly(String source) => source
    .split('\n')
    .where((l) {
      final t = l.trimLeft();
      return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
    })
    .join('\n');

void main() {
  late String code;
  late String init;

  setUpAll(() {
    code = _codeOnly(
        File('lib/core/services/notification_service.dart').readAsStringSync());
    init = code.substring(
      code.indexOf('notificationCategories: <DarwinNotificationCategory>['),
      code.indexOf('final initSettings = InitializationSettings('),
    );
  });

  group('iOS gets the same dose actions Android has', () {
    test('a dose category is registered, not only the water one', () {
      expect(init, contains('darwinDoseCategoryId'));
      expect(init, contains('darwinWaterCategoryId'),
          reason: 'the existing one must not be lost');
    });

    test('it carries take, snooze and skip', () {
      // Same ids as Android, so the one shared background handler routes both
      // platforms without branching on Platform.isIOS.
      for (final action in ["'take'", "'snooze'", "'skip'"]) {
        expect(init, contains(action));
      }
    });

    test('the medicine path actually references the category', () {
      // Registering a category nothing points at is the same as not having one.
      expect(code, contains('categoryIdentifier: doseActions ? darwinDoseCategoryId'));
      expect(code, contains('doseActions: true'));
    });

    test('the two category ids are distinct', () {
      expect(code, contains("darwinWaterCategoryId = 'water_reminder'"));
      expect(code, contains("darwinDoseCategoryId = 'dose_reminder'"));
    });

    test('previews stay hidden on the lock screen', () {
      // The body is "Time to take <medicine name>" — a prescription. Same
      // reasoning as the Android `visibility` default being private.
      expect(init, contains('hiddenPreviewShowTitle'));
    });

    test('a non-dose notification does not claim the dose category', () {
      // Otherwise every reminder would sprout a "Take" button on iOS — the
      // mirror image of the Android bug where vitals got one.
      expect(code, contains('bool doseActions = false'),
          reason: 'opt-in, not opt-out');
    });
  });

  group('iOS gets Done / Snooze / Later on a reminder, as Android does', () {
    test('a reminder category is registered', () {
      expect(init, contains('darwinReminderCategoryId'));
      expect(code, contains("darwinReminderCategoryId = 'reminder_actions'"));
    });

    test('it carries done, snooze and later — Android\'s own ids', () {
      // So the one shared handler routes both platforms without branching.
      final at = init.indexOf('darwinReminderCategoryId,');
      expect(at, greaterThan(-1));
      final category = init.substring(at);
      for (final action in ['ReminderActions.doneId', "'snooze'", 'ReminderActions.laterId']) {
        expect(category, contains(action));
      }
    });

    test('its previews are hidden: a reminder\'s words are the person\'s own', () {
      final at = init.indexOf('darwinReminderCategoryId,');
      expect(init.substring(at), contains('hiddenPreviewShowTitle'));
    });

    test('only a reminder with an identity claims it', () {
      // Otherwise water, vitals and focus nudges would sprout a "Done" nothing
      // could act on.
      expect(code,
          contains('categoryIdentifier: reminderId != null ? darwinReminderCategoryId : null'));
    });
  });
}

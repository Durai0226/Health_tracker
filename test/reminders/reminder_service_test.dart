import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// The feature model `Reminder` and the Drift row class share a name — every
// consumer in this app aliases one of them.
import 'package:tablet_remainder/core/database/app_database.dart'
    show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_service.dart';

/// Reminders had **no notifier at all**. `home_dashboard.dart` said so outright:
/// *"Returning to Home recomputes the sync parts (reminders have no notifier)."*
///
/// Every surface read the static `CleanStorageService._remindersCache` and
/// called `_load()` again after each `Navigator.push` returned. So two surfaces
/// showing reminders could disagree until one happened to be re-entered, and a
/// write from anywhere else — the reschedule pass, a cloud arrival, an
/// occurrence being recorded — stayed invisible until then.
///
/// `RemindersDao.watchReminders()` existed for exactly this and had never been
/// called.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  Reminder make(String id, {String title = 'Stretch'}) => Reminder(
        id: id,
        title: title,
        body: '',
        scheduledTime: DateTime(2026, 6, 10, 9),
      );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    // CleanStorageService caches the AppDatabase in a static, so without this it
    // keeps the previous test's closed connection.
    CleanStorageService.resetForTesting();
    await ReminderService.instance.resetForTesting();
  });

  tearDown(() async {
    await ReminderService.instance.resetForTesting();
    CleanStorageService.resetForTesting();
    await db.close();
  });

  group('the stream drives the notifier', () {
    test('a save notifies listeners without anyone asking for a reload', () async {
      await ReminderService.instance.start();
      var notifications = 0;
      void listener() => notifications++;
      ReminderService.instance.addListener(listener);
      addTearDown(() => ReminderService.instance.removeListener(listener));

      await CleanStorageService.saveReminder(make('r-1'));
      // The Drift stream emits asynchronously.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifications, greaterThan(0),
          reason: 'this is the whole point — no Navigator.push round-trip, no '
              'manual _load()');
      expect(ReminderService.instance.reminders.map((r) => r.id), contains('r-1'));
    });

    test('a delete is reflected too', () async {
      await CleanStorageService.saveReminder(make('r-1'));
      await ReminderService.instance.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(ReminderService.instance.reminders, isNotEmpty);

      await CleanStorageService.deleteReminder('r-1');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(ReminderService.instance.reminders, isEmpty);
    });

    test('isLoaded distinguishes "none yet" from "none at all"', () async {
      expect(ReminderService.instance.isLoaded, isFalse);
      await ReminderService.instance.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(ReminderService.instance.isLoaded, isTrue);
      expect(ReminderService.instance.reminders, isEmpty,
          reason: 'loaded AND empty is a real state an empty list alone cannot '
              'express');
    });
  });

  group('it does not become a second source of truth', () {
    test('the synchronous cache agrees with the notifier', () async {
      // The notification layer's snooze lookup reads the synchronous cache, so a
      // listener and a synchronous reader seeing different data would be a bug
      // with no visible symptom until a snooze silently resolved to the wrong
      // reminder.
      await ReminderService.instance.start();
      await CleanStorageService.saveReminder(make('r-1', title: 'Water plants'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        CleanStorageService.getReminders().map((r) => r.title).toList(),
        ReminderService.instance.reminders.map((r) => r.title).toList(),
      );
    });

    test('start() is idempotent', () async {
      await ReminderService.instance.start();
      await ReminderService.instance.start();
      await ReminderService.instance.start();
      await CleanStorageService.saveReminder(make('r-1'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Three subscriptions would mean three rebuilds per write.
      expect(ReminderService.instance.reminders.length, 1);
    });

    test('refresh() works without the stream having emitted', () async {
      await CleanStorageService.saveReminder(make('r-1'));
      await ReminderService.instance.refresh();
      expect(ReminderService.instance.isLoaded, isTrue);
      expect(ReminderService.instance.reminders.length, 1);
    });
  });
}

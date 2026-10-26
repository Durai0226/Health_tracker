import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/reminders/models/reminder_model.dart';
import 'package:tablet_remainder/features/reminders/services/reminder_pause_until.dart';

/// "Pause until…": a paused reminder with a day it comes back on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final now = DateTime(2026, 3, 10, 9);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  Reminder reminder(String id, {bool paused = true}) => Reminder(
        id: id,
        title: 'Water the plants',
        body: '',
        scheduledTime: DateTime(2026, 3, 1, 8),
        repeatType: RepeatType.daily,
        isPaused: paused,
      );

  group('the dates', () {
    test('set, read back and clear', () async {
      expect(ReminderPauseUntil.get('a'), isNull);
      await ReminderPauseUntil.set('a', DateTime(2026, 3, 20, 15, 30));
      expect(ReminderPauseUntil.get('a'), DateTime(2026, 3, 20),
          reason: 'a whole day, whatever time was picked');
      await ReminderPauseUntil.clear('a');
      expect(ReminderPauseUntil.get('a'), isNull);
    });

    test('several reminders are kept apart', () async {
      await ReminderPauseUntil.set('a', DateTime(2026, 3, 20));
      await ReminderPauseUntil.set('b', DateTime(2026, 4, 2));
      expect(ReminderPauseUntil.get('a'), DateTime(2026, 3, 20));
      expect(ReminderPauseUntil.get('b'), DateTime(2026, 4, 2));
    });

    test('an id that itself contains a pipe survives', () async {
      await ReminderPauseUntil.set('x|y', DateTime(2026, 3, 20));
      expect(ReminderPauseUntil.get('x|y'), DateTime(2026, 3, 20));
    });

    test('due means the day has arrived, the whole day counting', () async {
      await ReminderPauseUntil.set('a', DateTime(2026, 3, 10));
      await ReminderPauseUntil.set('b', DateTime(2026, 3, 11));
      expect(ReminderPauseUntil.due(now: DateTime(2026, 3, 10, 0, 1)), ['a']);
      expect(ReminderPauseUntil.due(now: DateTime(2026, 3, 9, 23, 59)), isEmpty);
      expect(ReminderPauseUntil.due(now: DateTime(2026, 3, 11)),
          containsAll(['a', 'b']));
    });
  });

  group('resumeDue', () {
    test('un-pauses a reminder whose day has arrived and forgets the date',
        () async {
      await CleanStorageService.saveReminder(reminder('a'));
      await ReminderPauseUntil.set('a', DateTime(2026, 3, 10));

      final n = await withClock(
          Clock.fixed(now), () => ReminderPauseUntil.resumeDue());

      expect(n, 1);
      final back = (await CleanStorageService.getAllReminders())
          .singleWhere((r) => r.id == 'a');
      expect(back.isPaused, isFalse);
      expect(ReminderPauseUntil.get('a'), isNull);
    });

    test('leaves a reminder whose day has not come', () async {
      await CleanStorageService.saveReminder(reminder('a'));
      await ReminderPauseUntil.set('a', DateTime(2026, 3, 12));

      final n = await withClock(
          Clock.fixed(now), () => ReminderPauseUntil.resumeDue());

      expect(n, 0);
      expect(
          (await CleanStorageService.getAllReminders()).single.isPaused, isTrue);
      expect(ReminderPauseUntil.get('a'), DateTime(2026, 3, 12));
    });

    test('a paused reminder with no date stays paused for good', () async {
      await CleanStorageService.saveReminder(reminder('a'));
      await withClock(Clock.fixed(now), () => ReminderPauseUntil.resumeDue());
      expect(
          (await CleanStorageService.getAllReminders()).single.isPaused, isTrue);
    });

    test('a stale date for a deleted reminder is dropped, not kept forever',
        () async {
      await ReminderPauseUntil.set('ghost', DateTime(2026, 3, 1));
      final n = await withClock(
          Clock.fixed(now), () => ReminderPauseUntil.resumeDue());
      expect(n, 0);
      expect(ReminderPauseUntil.get('ghost'), isNull);
    });

    test('one already resumed by hand is not "resumed" twice, and its date goes',
        () async {
      await CleanStorageService.saveReminder(reminder('a', paused: false));
      await ReminderPauseUntil.set('a', DateTime(2026, 3, 1));
      final n = await withClock(
          Clock.fixed(now), () => ReminderPauseUntil.resumeDue());
      expect(n, 0);
      expect(ReminderPauseUntil.get('a'), isNull);
    });
  });
}

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/backup_record.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/emergency_contact.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  group('BackupRecord', () {
    final now = DateTime(2026, 3, 20, 12);

    test('with no backup it is never recent', () {
      expect(BackupRecord.lastAt(), isNull);
      expect(BackupRecord.isRecent(now: now), isFalse);
    });

    test('a backup made today is recent, and is remembered', () async {
      await BackupRecord.markDone(now: now);
      expect(BackupRecord.lastAt(), now);
      expect(BackupRecord.isRecent(now: now), isTrue);
    });

    test('recent means within 30 days', () async {
      await BackupRecord.markDone(now: now);
      expect(BackupRecord.isRecent(now: now.add(const Duration(days: 29))), isTrue);
      expect(BackupRecord.isRecent(now: now.add(const Duration(days: 31))), isFalse);
    });

    test('a later backup replaces the earlier one', () async {
      await BackupRecord.markDone(now: now);
      await BackupRecord.markDone(now: now.add(const Duration(days: 40)));
      expect(BackupRecord.isRecent(now: now.add(const Duration(days: 45))), isTrue);
    });

    test('uses the pinned clock by default', () async {
      await withClock(Clock.fixed(now), () async {
        await BackupRecord.markDone();
        expect(BackupRecord.lastAt(), now);
      });
    });

    test('a garbled stored value reads as no backup', () async {
      await CleanStorageService.setAppPreference('last_backup_at', 'not a date');
      expect(BackupRecord.lastAt(), isNull);
      expect(BackupRecord.isRecent(now: now), isFalse);
    });
  });

  group('EmergencyContact', () {
    test('nothing saved is nothing set', () {
      expect(EmergencyContact.get(), isNull);
      expect(EmergencyContact.isSet, isFalse);
    });

    test('saves, reads back, and trims', () async {
      await EmergencyContact.save(name: '  Priya ', phone: ' +91 98765 43210 ');
      final c = EmergencyContact.get()!;
      expect(c.name, 'Priya');
      expect(c.phone, '+91 98765 43210');
      expect(EmergencyContact.isSet, isTrue);
    });

    test('a name without a number is not a contact', () async {
      await EmergencyContact.save(name: 'Priya', phone: '   ');
      expect(EmergencyContact.get(), isNull,
          reason: 'a name alone cannot be rung');
    });

    test('a number without a name still counts', () async {
      await EmergencyContact.save(name: '', phone: '999 000 111');
      expect(EmergencyContact.isSet, isTrue);
      expect(EmergencyContact.get()!.name, isEmpty);
    });

    test('clear removes it', () async {
      await EmergencyContact.save(name: 'Priya', phone: '12345');
      await EmergencyContact.clear();
      expect(EmergencyContact.isSet, isFalse);
    });

    test('isDialable accepts real numbers and refuses junk', () {
      for (final ok in ['+91 98765 43210', '(555) 123-4567', '112 000', '12345']) {
        expect(EmergencyContact.isDialable(ok), isTrue, reason: ok);
      }
      for (final bad in ['', 'call mum', '1234', 'abc12345', '12 34', '++', '1234x6']) {
        expect(EmergencyContact.isDialable(bad), isFalse, reason: bad);
      }
    });
  });
}

// Keeps two deleted paths deleted.
//
// Both were the same shape of mistake — code that looks like a feature, runs on
// every launch, and does nothing — so both are the kind of thing a future
// "this looks useful, wire it back up" would quietly restore:
//
//  * `SyncService` opened a Firestore snapshot listener on
//    `users/{uid}/reminders` for every signed-in user — a live subscription,
//    held for the life of the app, on a path whose writer
//    (`RemindersCloudService`) went in 0dd3c72: nothing has been able to put a
//    document there since. Reminders are not stranded by its removal — they
//    ride in the cloud BACKUP payload (`clean_storage_service.dart:990`, read
//    back at `:1291`), which is the supported way anything an older build left
//    behind comes home.
//  * `DatabaseService.clearAllData` ran an EMPTY Drift transaction and then
//    printed "✓ All data cleared". Nothing referenced the class at all — the
//    whole of it was a second, unused way to open the database that
//    `AppDatabase.instance` already provides.
//
// A source test because that is the only kind that can see an absence.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _libSources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) =>
        f.path.endsWith('.dart') &&
        !f.path.endsWith('.g.dart') &&
        !f.path.endsWith('.freezed.dart') &&
        !f.path.endsWith('.mocks.dart'));

void main() {
  test('the download-only reminder listener stays gone', () {
    expect(File('lib/core/services/sync_service.dart').existsSync(), isFalse);

    // `\b` before the capital S does not match inside CloudSyncService or
    // BackgroundHealthSyncService, which are live services.
    final type = RegExp(r'\bSyncService\b');
    final import = RegExp(r"['/]sync_service\.dart'");
    for (final f in _libSources()) {
      final src = f.readAsStringSync();
      expect(type.hasMatch(src), isFalse,
          reason: '${f.path} references SyncService, which was deleted. '
              'Nothing has written users/{uid}/reminders since 0dd3c72, so a '
              'listener on it is a subscription that can only ever idle. '
              'Reminders travel in the backup payload instead.');
      expect(import.hasMatch(src), isFalse, reason: '${f.path} imports it');
    }
  });

  test('DatabaseService, whose clearAllData cleared nothing, stays gone', () {
    expect(
        File('lib/core/database/database_service.dart').existsSync(), isFalse);

    final type = RegExp(r'\bDatabaseService\b');
    for (final f in _libSources()) {
      expect(type.hasMatch(f.readAsStringSync()), isFalse,
          reason: '${f.path} references DatabaseService. Use '
              'AppDatabase.instance; for a wipe use '
              'CleanStorageService.clearRestorableData, which actually '
              'deletes rows.');
    }
  });
}

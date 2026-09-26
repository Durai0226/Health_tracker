// The first-sign-in upload, for a user with more medicines than a batch holds.
//
// `uploadDataToCloud` is the "no cloud data found, uploading local data" branch
// of Google sign-in (`auth_service.dart`). It wrote one `WriteBatch` with one
// `set` per medicine — INCLUDING tombstones, so the count only ever grows — and
// committed it in one go. A `WriteBatch` is all-or-nothing and Firestore refuses
// more than 500 operations, so past that line the upload did not partially
// succeed: it failed entirely, and identically on every retry, for exactly the
// users with the most to lose. Nothing in the log said so beyond a swallowed
// `debugPrint`, and the sign-in itself reported success.
//
// These run against `FakeFirebaseFirestore`, which enforces the real cap
// (`mock_write_batch.dart` throws above 500 tasks) — so the 501-medicine case is
// the production failure rather than a simulation of it.
//
// `test/core/commit_in_chunks_test.dart` covers the helper's own boundaries;
// this file covers the call site actually reaching it.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart';
import 'package:tablet_remainder/core/services/cloud_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeFirebaseFirestore fs;
  final day = DateTime(2026, 3, 10);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    fs = FakeFirebaseFirestore();
    CloudSyncService().firestoreForTesting = fs;
  });

  tearDown(() async {
    CloudSyncService().firestoreForTesting = null;
    await db.close();
  });

  Future<void> seedMedicines(int n) async {
    await db.batch((b) => b.insertAll(db.enhancedMedicines, [
          for (var i = 0; i < n; i++)
            EnhancedMedicinesCompanion.insert(
              id: 'm$i',
              name: 'Medicine $i',
              dosageForm: 0,
              startDate: day,
              createdAt: day,
              updatedAt: day,
              scheduleJson: '{}',
            ),
        ]));
  }

  Future<int> cloudMedicineCount() async =>
      (await fs.collection('users').doc('u1').collection('medicines').get())
          .docs
          .length;

  test('501 medicines upload — one batch cannot hold them', () async {
    await seedMedicines(501);

    // The defect was not a slow or partial upload. It was this call throwing
    // `Firestore supports at most 500 tasks in a batch`, every time, leaving
    // the cloud completely empty for a user who had just been told sign-in
    // succeeded.
    await CloudSyncService().uploadDataToCloud('u1');

    expect(await cloudMedicineCount(), 501,
        reason: 'every medicine must land exactly once — chunking that drops '
            'a slice loses data just as quietly as one that throws');
  });

  test('a small upload still lands in a single pass', () async {
    // The common case, and the one a chunking bug would break silently: 3 ops
    // must behave exactly as they did before.
    await seedMedicines(3);

    await CloudSyncService().uploadDataToCloud('u1');

    expect(await cloudMedicineCount(), 3);
    final doc =
        await fs.collection('users').doc('u1').collection('medicines').doc('m1').get();
    expect(doc.data()!['name'], 'Medicine 1');
    expect(doc.data()!['updatedAtMs'], day.millisecondsSinceEpoch,
        reason: 'firestore.rules requires an int updatedAtMs on /medicines; '
            'an upload that omits it is denied silently');
  });

  test('nothing in lib/ builds a raw batch outside the chunking helper', () {
    // The guard that keeps this fixed. A `WriteBatch` assembled anywhere else
    // is unbounded by construction, and its 500-op ceiling is invisible until
    // a user crosses it.
    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('.dart') &&
            !f.path.endsWith('.g.dart') &&
            !f.path.endsWith('.freezed.dart') &&
            !f.path.endsWith('.mocks.dart'))) {
      if (f.path.endsWith('lww_collection_sync.dart')) continue; // the helper
      if (RegExp(r'\.batch\(\)').hasMatch(f.readAsStringSync())) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'build a List<void Function(WriteBatch)> and pass it to '
            'commitInChunks instead: $offenders');
  });
}

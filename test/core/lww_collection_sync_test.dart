import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/lww_collection_sync.dart';

/// Two defects in the shared last-write-wins helper, both invisible in the
/// data it produces and therefore never caught by a round-trip test.
///
///  1. **A tie re-uploaded.** The rule was `lMs >= cMs` → upload, documented as
///     "ties go to local". A tie is not a conflict: it means both sides already
///     hold the same version. So every unchanged row was rewritten on every
///     sync — a full rewrite of the collection per pass, per device, each one
///     racing the other device's identical write. The old condition is also
///     actively wrong when the two sides disagree at the same timestamp: it
///     silently discarded the cloud copy.
///  2. **The cloud read was one page.** `ref.limit(1000).get()` with no cursor.
///     Past the first page a cloud row is absent from `cloudById`, so the merge
///     reads it as "missing on this device": it is re-uploaded forever and its
///     cloud copy is never applied.
///
/// The helper takes its `FirebaseFirestore` as a parameter, so these run
/// against a fake instance with no Drift and no Firebase app.
void main() {
  late FakeFirebaseFirestore fs;
  late List<Map<String, dynamic>> applied;

  setUp(() {
    fs = FakeFirebaseFirestore();
    applied = [];
  });

  CollectionReference<Map<String, dynamic>> things() =>
      fs.collection('users').doc('u1').collection('things');

  Future<LwwSyncResult> sync(
    List<Map<String, dynamic>> locals, {
    int pageSize = kLwwPageSize,
  }) =>
      syncLwwCollection(
        fs,
        'u1',
        'things',
        local: () async => locals,
        id: (r) => (r as Map)['id'] as String,
        updatedMs: (r) => (r as Map)['updatedAtMs'] as int,
        toJson: (r) => Map<String, dynamic>.from(r as Map),
        apply: (m) async => applied.add(m),
      );

  // The `pageSize` override needs its own call site; keeping `sync` free of it
  // keeps the conflict tests readable.
  Future<LwwSyncResult> syncPaged(
    List<Map<String, dynamic>> locals,
    int pageSize,
  ) =>
      syncLwwCollection(
        fs,
        'u1',
        'things',
        local: () async => locals,
        id: (r) => (r as Map)['id'] as String,
        updatedMs: (r) => (r as Map)['updatedAtMs'] as int,
        toJson: (r) => Map<String, dynamic>.from(r as Map),
        apply: (m) async => applied.add(m),
        pageSize: pageSize,
      );

  group('conflict resolution', () {
    test('a tie moves nothing in either direction', () async {
      await things().doc('a').set(
          {'id': 'a', 'name': 'cloud', 'updatedAtMs': 100});

      final result = await sync([
        {'id': 'a', 'name': 'local', 'updatedAtMs': 100},
      ]);

      expect(result.uploaded, 0, reason: 'a tie is not a reason to write');
      expect(result.downloaded, 0);
      expect(applied, isEmpty);
      // The cloud copy is untouched — proof no upload happened, which an
      // idempotent re-upload of identical data could not have shown.
      final doc = await things().doc('a').get();
      expect(doc.data()!['name'], 'cloud');
    });

    test('a strictly newer local row is uploaded', () async {
      await things().doc('a').set(
          {'id': 'a', 'name': 'cloud', 'updatedAtMs': 100});

      final result = await sync([
        {'id': 'a', 'name': 'local', 'updatedAtMs': 101},
      ]);

      expect(result.uploaded, 1);
      expect(result.downloaded, 0);
      final doc = await things().doc('a').get();
      expect(doc.data()!['name'], 'local');
    });

    test('a strictly newer cloud row is applied locally', () async {
      await things().doc('a').set(
          {'id': 'a', 'name': 'cloud', 'updatedAtMs': 101});

      final result = await sync([
        {'id': 'a', 'name': 'local', 'updatedAtMs': 100},
      ]);

      expect(result.uploaded, 0);
      expect(result.downloaded, 1);
      expect(applied.single['name'], 'cloud');
      expect(result.appliedLocally, isTrue);
    });

    test('a local row the cloud has never seen is uploaded', () async {
      final result = await sync([
        {'id': 'a', 'name': 'local', 'updatedAtMs': 100},
      ]);

      expect(result.uploaded, 1);
      final doc = await things().doc('a').get();
      expect(doc.data()!['name'], 'local');
    });

    test('an unchanged collection costs zero writes on a repeat sync',
        () async {
      final locals = [
        for (var i = 0; i < 5; i++)
          {'id': 'r$i', 'name': 'local$i', 'updatedAtMs': 100 + i},
      ];

      final first = await sync(locals);
      expect(first.uploaded, 5, reason: 'first pass seeds the cloud');

      final second = await sync(locals);
      expect(second.uploaded, 0,
          reason: 'nothing changed, so nothing should be written again');
      expect(second.downloaded, 0);
    });
  });

  group('paging', () {
    test('reads every cloud document, not just the first page', () async {
      for (var i = 0; i < 7; i++) {
        await things()
            .doc('doc${i.toString().padLeft(2, '0')}')
            .set({'updatedAtMs': 500});
      }

      // No local rows: every cloud document must be applied.
      final result = await syncPaged(const [], 3);

      expect(result.downloaded, 7);
      // `id` is stamped from the document id by the helper, so this also pins
      // that every page's documents arrive identified.
      expect(applied.map((m) => m['id'] as String).toSet(),
          {for (var i = 0; i < 7; i++) 'doc${i.toString().padLeft(2, '0')}'});
    });

    test('a collection an exact multiple of the page size still terminates',
        () async {
      for (var i = 0; i < 6; i++) {
        await things()
            .doc('doc${i.toString().padLeft(2, '0')}')
            .set({'updatedAtMs': 500});
      }

      final result = await syncPaged(const [], 3);

      expect(result.downloaded, 6);
    });
  });
}

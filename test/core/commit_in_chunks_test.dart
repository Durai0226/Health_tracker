// `commitInChunks` — the only thing standing between a heavy user and a
// Firestore batch that fails whole.
//
// A `WriteBatch` is all-or-nothing and caps at 500 operations. An unbounded
// batch is therefore a bomb whose fuse is the user's own data: it works for
// everyone in testing, and the first person with 500 medicines or 500 stale
// cloud documents gets a delete or an upload that fails ENTIRELY, silently,
// forever — every retry rebuilds the same oversized batch.
//
// The helper had no test at all. That mattered because its two failure modes
// are both invisible in the data: chunking that never splits looks identical to
// chunking that does, right up to the document that crosses 500; and an
// off-by-one in the `sublist` bounds drops writes without an error.
//
// These run against `FakeFirebaseFirestore`, which enforces the real 500-task
// cap (`mock_write_batch.dart` throws above it) — so "no chunking" is not
// simulated here, it actually fails the same way production would.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/lww_collection_sync.dart';

void main() {
  late FakeFirebaseFirestore fs;

  setUp(() => fs = FakeFirebaseFirestore());

  CollectionReference<Map<String, dynamic>> medicines() =>
      fs.collection('users').doc('u1').collection('medicines');

  /// [n] `set` operations, each recording the batch it was handed so a test can
  /// count how many batches the helper actually opened. The op list is what
  /// every caller builds — `auth_service.dart` builds deletes the same way.
  List<void Function(WriteBatch)> setOps(int n, List<WriteBatch> seen) => [
        for (var i = 0; i < n; i++)
          (b) {
            seen.add(b);
            b.set(medicines().doc('m$i'), {'id': 'm$i', 'updatedAtMs': i});
          },
      ];

  Future<int> cloudCount() async => (await medicines().get()).docs.length;

  /// Identity, not `==`: two distinct batch objects must count as two.
  int distinct(List<WriteBatch> seen) =>
      (Set<WriteBatch>.identity()..addAll(seen)).length;

  test('one unchunked batch of 501 fails whole — the defect being prevented',
      () async {
    // The helper's behaviour with chunking switched off, expressed through its
    // own `max` rather than by editing it. This is the shape every caller has
    // when it builds a batch by hand: `fs.batch()`, N sets, one commit.
    final seen = <WriteBatch>[];
    await expectLater(
      commitInChunks(fs, setOps(501, seen), max: 501),
      throwsA(isA<Exception>()),
    );
    expect(distinct(seen), 1, reason: 'the point: it was a single batch');
    expect(await cloudCount(), 0,
        reason: 'all-or-nothing — not one of the 501 landed');
  });

  test('1000 writes land, split across chunks of at most 450', () async {
    final seen = <WriteBatch>[];
    final committed = await commitInChunks(fs, setOps(1000, seen));

    expect(committed, 1000);
    expect(await cloudCount(), 1000,
        reason: 'every op must land exactly once — a sublist off-by-one '
            'would drop or duplicate writes without throwing');
    expect(distinct(seen), 3, reason: '450 + 450 + 100');
  });

  test('the chunk boundary is exact', () async {
    final at = <WriteBatch>[];
    expect(await commitInChunks(fs, setOps(450, at)), 450);
    expect(distinct(at), 1, reason: '450 is the last size that fits one batch');

    final over = <WriteBatch>[];
    expect(await commitInChunks(fs, setOps(451, over)), 451);
    expect(distinct(over), 2, reason: 'one more must open a second');
    expect(await cloudCount(), 451, reason: 'ids overlap; 451 distinct docs');
  });

  test('an empty op list opens no batch and commits nothing', () async {
    // `_deleteCloudData` guards this itself, but a helper that committed an
    // empty batch would bill a write per empty subcollection per delete.
    final seen = <WriteBatch>[];
    expect(await commitInChunks(fs, setOps(0, seen)), 0);
    expect(seen, isEmpty);
    expect(await cloudCount(), 0);
  });
}

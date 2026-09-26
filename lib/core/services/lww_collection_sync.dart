import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Every subcollection this app writes under `users/{uid}`.
///
/// One list, because three places need to agree on it and previously did not:
/// the LWW syncers that create these documents, `firestore.rules`, and
/// `AuthService.deleteAccount` — which iterated a hand-written list containing
/// `'water'`, `'vitals'`, `'diary'`, `'cycles'`, `'steps'` and `'sleep'`.
/// None of those six is a path the app has ever written. Reads of them were
/// denied by the default-deny rules, threw permission-denied, were swallowed,
/// and `deleteAccount` returned success — while the real `water_intake`,
/// `step_days`, `sleep_sessions`, `biometric_days`, `workouts`,
/// `focus_sessions`, `health_profile`, `period_days` and `menstrual_cycles`
/// documents survived under a uid nobody can authenticate as again.
///
/// `reminder_categories` is listed even though nothing writes it today: the
/// rules have always permitted it, so an older build's documents may exist and
/// must still be reachable by a delete.
///
/// Adding a `.collection('…')` write without adding it here fails
/// `test/core/user_subcollections_test.dart`.
const List<String> kUserSubcollections = <String>[
  'backups',
  'medicines',
  'reminders',
  'reminder_categories',
  'water_intake',
  'focus_sessions',
  'step_days',
  'sleep_sessions',
  'biometric_days',
  'workouts',
  'health_profile',
  'period_days',
  'menstrual_cycles',
];

/// Firestore refuses a `WriteBatch` of more than 500 operations, and the whole
/// batch fails — so an unbounded batch is a bomb that goes off only for the
/// users with the most data. Commits [ops] in chunks of at most [max].
///
/// Returns the number of operations committed.
Future<int> commitInChunks(
  FirebaseFirestore fs,
  List<void Function(WriteBatch)> ops, {
  int max = 450,
}) async {
  var done = 0;
  for (var i = 0; i < ops.length; i += max) {
    final slice = ops.sublist(i, i + max > ops.length ? ops.length : i + max);
    final batch = fs.batch();
    for (final op in slice) {
      op(batch);
    }
    await batch.commit();
    done += slice.length;
  }
  return done;
}

/// Documents fetched per cloud read. Firestore charges per document either way,
/// so the page size only trades round trips against memory.
const int kLwwPageSize = 500;

/// What one [syncLwwCollection] pass moved.
///
/// [downloaded] is the number the caller actually needs: those rows went
/// straight into Drift, behind the back of whichever service owns them, so a
/// non-zero count means an in-memory cache is now stale. See
/// `CloudSyncService.reloadCachesAfterHealthSync`.
@immutable
class LwwSyncResult {
  const LwwSyncResult({this.uploaded = 0, this.downloaded = 0});

  final int uploaded;
  final int downloaded;

  /// This pass wrote cloud rows into the local database.
  bool get appliedLocally => downloaded > 0;
}

/// Last-write-wins sync for one Firestore subcollection under `users/{uid}`.
///
/// Extracted from `HealthCloudSyncService._sync`, which was the only
/// implementation of this and is now a one-line delegate. Focus sessions needed
/// the same semantics but explicitly NOT the same service — focus is not Health
/// Connect data, so routing it through the health syncer would drag a
/// productivity timer into the Play "Health apps" declaration and the health
/// Data-safety rows for no benefit. Two copies of a conflict-resolution rule is
/// how they drift, so the rule moved here instead.
///
/// Semantics (the first two bullets were corrected after the original; the rest
/// are as extracted):
///
///  * `updatedAtMs` is mirrored onto the cloud doc so a comparison costs no
///    extra read and no server timestamp round-trip.
///  * **A tie is a no-op.** Equal `updatedAtMs` means both sides already hold
///    the same version, so there is nothing to move in either direction. The
///    rule was `lMs >= cMs` → upload, which is not "ties go to local" but "every
///    unchanged row is re-uploaded on every pass": a full rewrite of the
///    collection per sync, per device, billed as writes and paid for in battery,
///    with each device's write racing the other's identical one. Local still
///    wins a real conflict — it just has to actually be newer.
///  * **The cloud read is paged.** It was a bare `.limit(1000)`, which is not a
///    cap but silent truncation: past the first page every cloud row looks
///    "missing on this device", so it is re-uploaded forever and its cloud copy
///    is never seen. See [kLwwPageSize].
///  * Tombstones ride along as ordinary rows: `deletedAt` is a field, so a
///    deletion propagates like any other change instead of needing a second
///    mechanism.
///  * Every failure is caught and logged. A sync that throws would take down the
///    caller's whole `Future.wait`, so one unreachable collection must not stop
///    the others.
Future<LwwSyncResult> syncLwwCollection(
  FirebaseFirestore fs,
  String userId,
  String collection, {
  required Future<List<dynamic>> Function() local,
  required String Function(dynamic) id,
  required int Function(dynamic) updatedMs,
  required Map<String, dynamic> Function(dynamic) toJson,
  required Future<void> Function(Map<String, dynamic>) apply,
  int pageSize = kLwwPageSize,
}) async {
  var uploaded = 0;
  var downloaded = 0;
  try {
    final ref = fs.collection('users').doc(userId).collection(collection);
    final locals = await local();
    final localById = {for (final r in locals) id(r): r};

    // Every document, not the first page of them. Ordering by document id is
    // what makes the cursor stable — `startAfterDocument` needs the same sort
    // the previous page was read with.
    final cloudById = <String, Map<String, dynamic>>{};
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      var page = ref.orderBy(FieldPath.documentId);
      if (cursor != null) page = page.startAfterDocument(cursor);
      final snap = await page.limit(pageSize).get();
      for (final d in snap.docs) {
        cloudById[d.id] = {...d.data(), 'id': d.id};
      }
      // A short page is the last page.
      if (snap.docs.length < pageSize) break;
      cursor = snap.docs.last;
    }

    final ids = {...localById.keys, ...cloudById.keys};
    for (final docId in ids) {
      final r = localById[docId];
      final cloud = cloudById[docId];
      final lMs = r == null ? -1 : updatedMs(r);
      final cMs = (cloud?['updatedAtMs'] as int?) ?? -1;
      // Strictly newer, or not there at all. Equal timestamps mean both sides
      // already hold this version — see the tie bullet above.
      if (r != null && (cloud == null || lMs > cMs)) {
        final data = toJson(r);
        data['updatedAtMs'] = lMs;
        data['id'] = docId;
        await ref.doc(docId).set(data);
        uploaded++;
      } else if (cloud != null && cMs > lMs) {
        await apply(cloud);
        downloaded++;
      }
    }
  } catch (e) {
    debugPrint('LWW sync [$collection] failed: $e');
  }
  return LwwSyncResult(uploaded: uploaded, downloaded: downloaded);
}

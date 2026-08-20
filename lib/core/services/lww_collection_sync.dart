import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
/// Semantics, unchanged from the original:
///
///  * `updatedAtMs` is mirrored onto the cloud doc so a comparison costs no
///    extra read and no server timestamp round-trip.
///  * **Ties go to local** (`lMs >= cMs`). A tie means both sides already agree
///    on the version, so re-uploading is idempotent, whereas downloading could
///    overwrite a local row whose clock merely rounded the same way.
///  * Tombstones ride along as ordinary rows: `deletedAt` is a field, so a
///    deletion propagates like any other change instead of needing a second
///    mechanism.
///  * Every failure is caught and logged. A sync that throws would take down the
///    caller's whole `Future.wait`, so one unreachable collection must not stop
///    the others.
Future<void> syncLwwCollection(
  FirebaseFirestore fs,
  String userId,
  String collection, {
  required Future<List<dynamic>> Function() local,
  required String Function(dynamic) id,
  required int Function(dynamic) updatedMs,
  required Map<String, dynamic> Function(dynamic) toJson,
  required Future<void> Function(Map<String, dynamic>) apply,
  int limit = 1000,
}) async {
  try {
    final ref = fs.collection('users').doc(userId).collection(collection);
    final locals = await local();
    final localById = {for (final r in locals) id(r): r};
    final snap = await ref.limit(limit).get();
    final cloudById = <String, Map<String, dynamic>>{
      for (final d in snap.docs) d.id: {...d.data(), 'id': d.id},
    };
    final ids = {...localById.keys, ...cloudById.keys};
    for (final docId in ids) {
      final r = localById[docId];
      final cloud = cloudById[docId];
      final lMs = r == null ? -1 : updatedMs(r);
      final cMs = (cloud?['updatedAtMs'] as int?) ?? -1;
      if (r != null && lMs >= cMs) {
        final data = toJson(r);
        data['updatedAtMs'] = lMs;
        data['id'] = docId;
        await ref.doc(docId).set(data);
      } else if (cloud != null && cMs > lMs) {
        await apply(cloud);
      }
    }
  } catch (e) {
    debugPrint('LWW sync [$collection] failed: $e');
  }
}

// Keeps `kUserSubcollections` honest.
//
// The list exists because three places must agree on which subcollections live
// under `users/{uid}`: the syncers that write them, `firestore.rules`, and
// `AuthService.deleteAccount`. They did not agree — deleteAccount iterated ten
// names of which six ('water', 'vitals', 'diary', 'cycles', 'steps', 'sleep')
// are paths this app has never written. Reads of them were denied by the
// default-deny rules, threw, were swallowed, and the method reported success
// while every real health document survived.
//
// A source scan rather than a runtime test: the failure mode is someone adding
// a new `.collection('x')` write and forgetting the other two places, which no
// amount of exercising the current code paths would catch.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/lww_collection_sync.dart';

/// Collection names reached via `.collection('name')` or passed to a sync
/// helper as a bare string literal, across lib/ (excluding generated code).
Set<String> _collectionNamesInLib() {
  final found = <String>{};
  // `.collection('x')` — the direct Firestore accessor.
  final direct = RegExp(r"\.collection\(\s*'([a-zA-Z_][a-zA-Z0-9_]*)'");
  // `syncLwwCollection(fs, userId, 'x'` and the `_sync(userId, 'x'` delegate.
  final viaSync = RegExp(r"userId,\s*'([a-z][a-z0-9_]*)'");

  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    if (f.path.endsWith('.g.dart') ||
        f.path.endsWith('.freezed.dart') ||
        f.path.endsWith('.mocks.dart')) {
      continue;
    }
    final src = f.readAsStringSync();
    for (final m in direct.allMatches(src)) {
      found.add(m.group(1)!);
    }
    for (final m in viaSync.allMatches(src)) {
      found.add(m.group(1)!);
    }
  }
  // `users` is the parent collection, not a per-user subcollection.
  found.remove('users');
  return found;
}

void main() {
  test('every subcollection written in lib/ is in kUserSubcollections', () {
    final written = _collectionNamesInLib();
    final missing = written.difference(kUserSubcollections.toSet());
    expect(
      missing,
      isEmpty,
      reason: 'These Firestore subcollections are written by lib/ but are not '
          'in kUserSubcollections, so deleteAccount will leave them behind '
          'and firestore.rules may not cover them: $missing',
    );
  });

  test('kUserSubcollections has no duplicates', () {
    expect(kUserSubcollections.toSet().length, kUserSubcollections.length);
  });

  test('every name in kUserSubcollections has a firestore.rules match', () {
    final rules = File('firestore.rules').readAsStringSync();
    final unmatched = kUserSubcollections
        .where((c) => !rules.contains('match /$c/'))
        .toList();
    expect(
      unmatched,
      isEmpty,
      reason: 'Default-deny rules mean a subcollection with no match block can '
          'never be read or deleted by the client: $unmatched',
    );
  });

  test('deleteAccount iterates the shared list, not a literal', () {
    final src =
        File('lib/core/services/auth_service.dart').readAsStringSync();
    expect(src.contains('for (final sub in kUserSubcollections)'), isTrue,
        reason: 'deleteAccount must iterate kUserSubcollections so it can '
            'never drift from what the syncers write.');
    // The six phantom names that made the old loop a no-op.
    for (final phantom in const [
      "'water'",
      "'vitals'",
      "'diary'",
      "'cycles'",
      "'steps'",
      "'sleep'",
      "'reminderCategories'",
    ]) {
      expect(src.contains(phantom), isFalse,
          reason: '$phantom is not a collection this app writes; its presence '
              'in auth_service.dart means the old hand-written list is back.');
    }
  });
}

// Keeps `firestore.rules` honest about the collections `lib/` actually writes.
//
// A source test rather than an emulator test: there is no Firestore emulator in
// this repo, and a rules mistake here never surfaces as a crash — every write
// goes through `syncLwwCollection`, whose body ends in
// `catch (e) { debugPrint(...) }`, so a rejected write is silent and sync for
// that collection simply stops on every device. The failure mode is invisible,
// which is exactly the kind that needs a test that can see the file.
//
// NOTE: green here means the FILE is right. Rules only bind once deployed —
// `firebase deploy --only firestore:rules`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _isSource(FileSystemEntity f) =>
    f is File &&
    f.path.endsWith('.dart') &&
    !f.path.endsWith('.g.dart') &&
    !f.path.endsWith('.freezed.dart') &&
    !f.path.endsWith('.mocks.dart');

Iterable<File> _libSources() =>
    Directory('lib').listSync(recursive: true).whereType<File>().where(_isSource);

/// Collections synced last-write-wins, read out of the call sites.
///
/// Found the way `user_subcollections_test` finds subcollection names: both
/// `syncLwwCollection(fs, userId, 'x'` and the `HealthCloudSyncService._sync(
/// userId, 'x'` delegate put the collection name in a fixed argument position.
/// Deriving it beats a hand-written list — the whole point is to catch the
/// collection someone adds without touching the rules.
///
/// Matched by CALL SHAPE, not by the argument being spelled `userId`: keying on
/// that identifier meant a new call site that named its parameter `uid` added a
/// silently unguarded collection and still left this file green — the one
/// failure this test exists to make impossible.
Set<String> _lwwCollectionsInLib() {
  const name = r"'([a-z][a-z0-9_]*)'";
  final patterns = [
    // syncLwwCollection(<fs>, <user>, 'collection'
    RegExp("syncLwwCollection\\(\\s*[^,()]+,\\s*[^,()]+,\\s*$name"),
    // HealthCloudSyncService._sync(<user>, 'collection'
    RegExp("_sync\\(\\s*[^,()]+,\\s*$name"),
  ];
  final found = <String>{};
  for (final f in _libSources()) {
    final src = f.readAsStringSync();
    for (final p in patterns) {
      for (final m in p.allMatches(src)) {
        found.add(m.group(1)!);
      }
    }
  }
  return found;
}

/// Every subcollection name `lib/` names in a `.collection('…')` call or passes
/// to a sync helper — i.e. every path the client can touch at all.
Set<String> _collectionNamesInLib() {
  final direct = RegExp(r"\.collection\(\s*'([a-zA-Z_][a-zA-Z0-9_]*)'");
  final found = <String>{};
  for (final f in _libSources()) {
    for (final m in direct.allMatches(f.readAsStringSync())) {
      found.add(m.group(1)!);
    }
  }
  return found..remove('users'); // the parent, not a subcollection
}

/// The text of one `match /<collection>/{…} { … }` block, header to closing
/// brace. Stops at the brace rather than at the next `match` on purpose: the
/// comment introducing the NEXT block would otherwise land inside this one, and
/// the backups comment alone says both "create" and "update".
String _ruleBlock(String rules, String collection) {
  final start = rules.indexOf('match /$collection/');
  expect(start, isNot(-1),
      reason: 'firestore.rules has no match block for $collection — '
          'default-deny means the client cannot even delete it.');
  // Collection matches sit inside `match /users/{userId}`, so their closing
  // brace is the first one indented six spaces.
  final end = rules.indexOf('\n      }', start);
  expect(end, isNot(-1), reason: 'unterminated match block for $collection');
  return rules.substring(start, end);
}

void main() {
  final rules = File('firestore.rules').readAsStringSync();

  group('last-write-wins collections', () {
    test('the LWW set is exactly the eight the rules document', () {
      // Pinned so that adding a ninth is a decision, not an accident: the new
      // collection needs a match block, and this file's other test then holds
      // it to the timestamp check.
      expect(
        _lwwCollectionsInLib(),
        {
          'medicines',
          'focus_sessions',
          'step_days',
          'sleep_sessions',
          'biometric_days',
          'workouts',
          'health_profile',
          'period_days',
        },
      );
    });

    test('every one of them requires an int updatedAtMs', () {
      final missing = [
        for (final c in _lwwCollectionsInLib())
          if (!_ruleBlock(rules, c).contains('hasSyncTimestamp()')) c,
      ]..sort();
      expect(
        missing,
        isEmpty,
        reason: 'syncLwwCollection casts `cloud["updatedAtMs"] as int?`. A '
            'wrongly-typed value throws inside the catch that swallows it, '
            'killing sync for the whole collection on every device. These '
            'matches let one through: $missing',
      );
    });

    test('water_intake is the one documented exception', () {
      // Not LWW: the day document is union-merged by log id, nothing casts an
      // updatedAtMs off it, and DailyWaterData.toJson does not emit one — so
      // requiring the field would reject every water upload, silently.
      expect(_lwwCollectionsInLib(), isNot(contains('water_intake')));
      expect(_ruleBlock(rules, 'water_intake'),
          isNot(contains('hasSyncTimestamp()')));
      expect(
        File('lib/features/water/models/enhanced_water_log.dart')
            .readAsStringSync()
            .contains("'updatedAtMs'"),
        isFalse,
        reason: 'Water now carries a sync timestamp. Either add '
            'hasSyncTimestamp() to the water_intake match and drop this '
            'exemption, or stop writing the field.',
      );
    });
  });

  group('paths with no writer are not writable', () {
    // `reminders` and `reminder_categories` lost their writer in 0dd3c72;
    // `menstrual_cycles` is derived from period_days and recomputed locally
    // after every log, so uploading it only ever shipped a cache.
    const noWriter = ['reminders', 'reminder_categories', 'menstrual_cycles'];

    test('nothing in lib/ writes them', () {
      final written = _collectionNamesInLib().union(_lwwCollectionsInLib());
      expect(written.intersection(noWriter.toSet()), isEmpty,
          reason: 'A writer came back. Restore create/update in '
              'firestore.rules for it, or the write is silently denied.');
    });

    test('their rules grant no create or update', () {
      for (final c in noWriter) {
        final block = _ruleBlock(rules, c);
        expect(block.contains('create'), isFalse,
            reason: '$c has no writer; an unused-but-writable path is attack '
                'surface for nothing.');
        expect(block.contains('update'), isFalse, reason: 'same for $c');
      }
    });

    test('they stay readable and deletable, or account deletion breaks', () {
      // AuthService.deleteAccount iterates kUserSubcollections and `.get()`s
      // each one. A path with no match block throws permission-denied, which
      // that loop records as a failure and then refuses to delete the Auth
      // user — so dropping these blocks entirely would make account deletion
      // impossible for everyone, not just for people with legacy documents.
      for (final c in noWriter) {
        expect(_ruleBlock(rules, c), contains('allow read, delete: if isOwner'),
            reason: '$c must stay readable and deletable for deleteAccount.');
      }
    });
  });
}

/// [EnumJson] — the guard that keeps one corrupt ordinal from costing a feature.
///
/// The helper shipped with nine call sites and no tests, which is the worst
/// combination: every one of those `fromJson`s LOOKS guarded, and nothing would
/// have noticed if the bounds check had been written `<=` or the `is int` had
/// been dropped. The truth table below is half the suite; the other half runs
/// the two shipped parsers with a poisoned ordinal, because a helper proven in
/// isolation says nothing about whether the call site actually uses it.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/utils/enum_json.dart';
import 'package:tablet_remainder/features/focus/models/ambient_sound.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';

enum _Colour { red, green, blue }

void main() {
  group('EnumJson.at', () {
    test('an in-range ordinal is the value at that index', () {
      expect(EnumJson.at(_Colour.values, 0, _Colour.blue), _Colour.red);
      expect(EnumJson.at(_Colour.values, 1, _Colour.blue), _Colour.green);
      // The last valid index, which an off-by-one `<=` bound would accept as
      // `values[length]` and a `<` bound written `>` would reject.
      expect(EnumJson.at(_Colour.values, 2, _Colour.red), _Colour.blue);
    });

    test('out of range falls back — the newer-build rollback case', () {
      // `values.length` exactly: the index a build that appended one case
      // writes, read back by a build that has not been updated.
      expect(EnumJson.at(_Colour.values, 3, _Colour.red), _Colour.red);
      expect(EnumJson.at(_Colour.values, 99, _Colour.green), _Colour.green);
    });

    test('a negative ordinal falls back', () {
      expect(EnumJson.at(_Colour.values, -1, _Colour.green), _Colour.green);
      expect(EnumJson.at(_Colour.values, -99, _Colour.red), _Colour.red);
    });

    test('an empty values list always falls back', () {
      // No index can be valid here, 0 included — the shape a bare
      // `values[raw]` gets wrong for every input rather than for some.
      expect(EnumJson.at(const <_Colour>[], 0, _Colour.blue), _Colour.blue);
      expect(EnumJson.at(const <_Colour>[], -1, _Colour.blue), _Colour.blue);
      expect(EnumJson.at(const <_Colour>[], 7, _Colour.blue), _Colour.blue);
    });

    test('a missing or non-integer value falls back', () {
      expect(EnumJson.at(_Colour.values, null, _Colour.green), _Colour.green);
      // JSON that went through a decoder which widened the number, or a key
      // written as text by an older build.
      expect(EnumJson.at(_Colour.values, '1', _Colour.green), _Colour.green);
      expect(EnumJson.at(_Colour.values, 1.0, _Colour.green), _Colour.green);
      expect(EnumJson.at(_Colour.values, true, _Colour.green), _Colour.green);
      expect(EnumJson.at(_Colour.values, const {}, _Colour.green),
          _Colour.green);
    });
  });

  group('EnumJson.atOrNull', () {
    test('an in-range ordinal is the value at that index', () {
      expect(EnumJson.atOrNull(_Colour.values, 2), _Colour.blue);
    });

    test('out of range, negative, empty and non-integer are all null', () {
      expect(EnumJson.atOrNull(_Colour.values, 3), isNull);
      expect(EnumJson.atOrNull(_Colour.values, -1), isNull);
      expect(EnumJson.atOrNull(const <_Colour>[], 0), isNull);
      expect(EnumJson.atOrNull(_Colour.values, null), isNull);
      expect(EnumJson.atOrNull(_Colour.values, '2'), isNull);
    });
  });

  group('EnumJson.key — enum map keys, which serialise as stringified ordinals',
      () {
    test('a numeric key resolves', () {
      expect(EnumJson.key(_Colour.values, '2'), _Colour.blue);
      // JSON decoders hand back either, depending on how the map was written.
      expect(EnumJson.key(_Colour.values, 1), _Colour.green);
    });

    test('an unknown ordinal is null, not a wrong enum', () {
      // Substituting a fallback here would silently re-attribute the value to
      // a different activity, which is why this returns null and `at` does not.
      expect(EnumJson.key(_Colour.values, '3'), isNull);
      expect(EnumJson.key(_Colour.values, '-1'), isNull);
      expect(EnumJson.key(const <_Colour>[], '0'), isNull);
    });

    test('a non-numeric or missing key is null rather than a parse throw', () {
      expect(EnumJson.key(_Colour.values, 'green'), isNull);
      expect(EnumJson.key(_Colour.values, ''), isNull);
      expect(EnumJson.key(_Colour.values, null), isNull);
    });
  });

  // ── The half that proves the guard is wired, not merely present ──
  //
  // A truth table for the helper passes just as well when a call site still
  // says `Enum.values[json['x']]`. These read a poisoned ordinal through the
  // two shipped parsers and assert the thing the doc comment promises: the bad
  // field degrades, its NEIGHBOURS survive.
  group('a poisoned ordinal costs one field, not the record', () {
    test('FocusSession.fromJson keeps the session around the bad enum', () {
      final session = FocusSession.fromJson(<String, dynamic>{
        'id': 'abc',
        'startedAt': '2026-01-02T09:00:00.000',
        'targetMinutes': 25,
        'actualMinutes': 25,
        'wasCompleted': true,
        // Written by a build with more activity types than this one has.
        'activityType': 99,
        'plantType': -4,
        'soundUsed': 'rain',
        'note': 'shipped',
      });

      expect(session.activityType, FocusActivityType.work);
      expect(session.plantType, PlantType.seedling);
      expect(session.soundUsed, AmbientSoundType.none);
      // The payload either side of the poisoned fields.
      expect(session.id, 'abc');
      expect(session.targetMinutes, 25);
      expect(session.actualMinutes, 25);
      expect(session.wasCompleted, isTrue);
      expect(session.note, 'shipped');
    });

    test('FocusStats.fromJson drops the unreadable bucket and keeps the rest',
        () {
      final stats = FocusStats.fromJson(<String, dynamic>{
        'totalMinutes': 140,
        'totalSessions': 6,
        'minutesByActivity': {'0': 100, '99': 40, 'work': 7},
        'plantCounts': {'0': 3, '-1': 9},
      });

      expect(stats.minutesByActivity, {FocusActivityType.work: 100});
      expect(stats.plantCounts, {PlantType.seedling: 3});
      expect(stats.totalMinutes, 140);
      expect(stats.totalSessions, 6);
    });
  });
}

/// `setState` after an `await`, with nothing between them, is a crash waiting
/// for a slow network.
///
/// Every screen here does real async work and then touches its own state:
/// sign-in leaves the app for the account picker, "App lock off" waits on
/// three preference writes, the notification screen saves on a debounce. A
/// user who backs out while one of those is in flight disposes the [State],
/// and `setState()` on a defunct State throws — so the guard has to sit
/// BEFORE the call, not beside it.
///
/// Two live examples this pins:
///
///  * `SettingsScreen._handleGoogleSignIn` had `if (!mounted) return;` one
///    line AFTER the `setState` it was meant to protect;
///  * `SecuritySettingsScreen._onToggleLock` guarded only its toast —
///    `if (mounted) context.toastInfo(...)` — while the `setState` that
///    follows the branch was reached whether or not the screen still existed.
///
/// The second is why this scan does not simply grep for the word "mounted":
/// a guard on the wrong statement reads exactly like a guard on the right one.
///
/// It is a source scan, and its limit is real: it proves the guard is there,
/// not that the state it sets is correct.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Brace depth at [end], counted from the start of [gap] (the `await`).
int _depthAt(String gap, int end) {
  var depth = 0;
  for (var p = 0; p < end; p++) {
    final c = gap.codeUnitAt(p);
    if (c == 0x7B) depth++; // {
    if (c == 0x7D) depth--; // }
  }
  return depth;
}

/// Whether a guard starting at [guardStart] is on every path that runs the
/// `await` at the start of [gap].
///
/// Depth 0 means the guard sits at the await's own level: even if the block
/// around BOTH of them closes before the setState, anything that ran the await
/// ran the guard too. Deeper means the guard is inside a block that OPENED
/// after the await — a `Timer` callback, a branch that may not run — where it
/// says nothing about the code following that block. `if (!mounted) return;`
/// is the standard first line of a timer body, so counting one there would
/// disarm this scan for the whole rest of the method.
bool _guardIsOnTheAwaitsPath(String gap, int guardStart) =>
    _depthAt(gap, guardStart) == 0;

/// Whether the block a guard sits in is still open at the end of [gap].
bool _stillOpenAtEnd(String gap, int from) {
  var depth = 0;
  for (var p = from; p < gap.length; p++) {
    final c = gap.codeUnitAt(p);
    if (c == 0x7B) depth++; // {
    if (c == 0x7D) {
      depth--; // }
      if (depth < 0) return false;
    }
  }
  return true;
}

/// Whether an `if (… mounted …)` ending at [guardEnd] wraps the setState the
/// gap ends at — either as its single statement, or in a block still open
/// there.
bool _ifGuardCovers(String gap, int guardEnd) {
  var p = guardEnd;
  while (p < gap.length && gap[p].trim().isEmpty) {
    p++;
  }
  // Nothing at all between the guard and the setState: `if (mounted) setState(`.
  if (p >= gap.length) return true;
  // A single-statement body that is NOT the setState covers something else.
  if (gap.codeUnitAt(p) != 0x7B) return false;
  return _stillOpenAtEnd(gap, p + 1);
}

/// `setState(` calls that follow an `await` in the same method with no mounted
/// check in between. Returns a human-readable location per offender.
List<String> unguardedSetStates(String rawSource, {String label = 'fixture'}) {
  // Blank out line comments, keeping every offset — the fixes here name the
  // broken shape in prose so the reason survives, and a scan that fires on its
  // own explanation is a scan people delete.
  final source = rawSource
      .split('\n')
      .map((line) {
        final at = line.indexOf('//');
        return at < 0 ? line : line.substring(0, at) + ' ' * (line.length - at);
      })
      .join('\n');

  final lineStarts = <int>[0];
  for (var i = 0; i < source.length; i++) {
    if (source.codeUnitAt(i) == 0x0A) lineStarts.add(i + 1);
  }
  int lineAt(int offset) {
    var line = 1;
    for (var i = 1; i < lineStarts.length && lineStarts[i] <= offset; i++) {
      line = i + 1;
    }
    return line;
  }

  // Any `if (… mounted …)`. The early-return form is checked separately,
  // because only it protects code that comes after the `if`.
  final ifMounted = RegExp(r'if \([^)]*mounted[^)]*\)');
  final earlyReturn = RegExp(r'!\s*mounted[^;]*return');

  final offenders = <String>[];
  for (var i = source.indexOf('setState('); i >= 0;
      i = source.indexOf('setState(', i + 1)) {
    final awaitAt = source.lastIndexOf('await ', i);
    if (awaitAt < 0) continue;
    final gap = source.substring(awaitAt, i);
    // A closing brace at class-member indentation means the await belongs to
    // some earlier method and cannot reach this setState.
    if (gap.contains('\n  }')) continue;
    if (earlyReturn
        .allMatches(gap)
        .any((m) => _guardIsOnTheAwaitsPath(gap, m.start))) {
      continue;
    }

    final guarded = ifMounted.allMatches(gap).any((m) =>
        _guardIsOnTheAwaitsPath(gap, m.start) && _ifGuardCovers(gap, m.end));
    if (!guarded) offenders.add('$label:${lineAt(i)}');
  }
  return offenders;
}

void main() {
  group('the scanner can actually fail', () {
    test('an early return before the setState is a guard', () {
      expect(
        unguardedSetStates('''
  Future<void> a() async {
    await x();
    if (!mounted) return;
    setState(() {});
  }
'''),
        isEmpty,
      );
    });

    test('a compound early return is a guard too', () {
      expect(
        unguardedSetStates('''
  Future<void> a() async {
    final ok = await x();
    if (ok != true || !mounted) return;
    setState(() {});
  }
'''),
        isEmpty,
      );
    });

    test('an if (mounted) wrapped around the setState is a guard', () {
      expect(
        unguardedSetStates('''
  Future<void> a() async {
    await x();
    if (mounted) setState(() {});
    await y();
    if (mounted) {
      setState(() {});
    }
  }
'''),
        isEmpty,
      );
    });

    test('an if (mounted) around something ELSE is NOT a guard', () {
      // The SecuritySettingsScreen shape. A grep for "mounted" passes this.
      expect(
        unguardedSetStates('''
  Future<void> a() async {
    await x();
    if (mounted) toast();
    setState(() {});
  }
''').length,
        1,
      );
    });

    test('a guard that lands after the setState is NOT a guard', () {
      // The SettingsScreen shape.
      expect(
        unguardedSetStates('''
  Future<void> a() async {
    await x();
    setState(() {});
    if (!mounted) return;
  }
''').length,
        1,
      );
    });

    test('a setState named only in a comment is not a call', () {
      expect(
        unguardedSetStates('''
  Future<void> a() async {
    await x();
    // a bare setState(() {}) here would throw once the screen is gone
    if (!mounted) return;
    setState(() {});
  }
'''),
        isEmpty,
      );
    });

    test('a guard inside a callback does not reach past the callback', () {
      // The shape that would quietly disarm the whole scan: `if (!mounted)
      // return;` is the standard opening of a Timer/then body, and it says
      // nothing about the code that follows the callback.
      expect(
        unguardedSetStates('''
  Future<void> a() async {
    await x();
    _t = Timer(d, () {
      if (!mounted) return;
      y();
    });
    setState(() {});
  }
''').length,
        1,
      );
    });

    test('a guard inside a branch that may not run is not a guard', () {
      expect(
        unguardedSetStates('''
  Future<void> a() async {
    final ok = await x();
    if (ok) {
      if (!mounted) return;
      z();
    }
    setState(() {});
  }
''').length,
        1,
      );
    });

    test('an if (mounted) block that closes early is not a guard', () {
      expect(
        unguardedSetStates('''
  Future<void> a() async {
    await x();
    if (mounted) { y(); }
    if (z) { setState(() {}); }
  }
''').length,
        1,
      );
    });

    test('an await in an EARLIER method does not reach this setState', () {
      expect(
        unguardedSetStates('''
  Future<void> a() async {
    await x();
  }

  void b() {
    setState(() {});
  }
'''),
        isEmpty,
      );
    });
  });

  test('no settings screen sets state after an await without a guard', () {
    // backup_screen.dart is deliberately absent: it has an unguarded
    // `setState(() => _backups = backups)` after `await getBackups()` (its
    // _loadBackups), and it is owned by another change in flight. Add it back
    // here in the same commit that fixes it.
    final files = Directory('lib/features/settings/screens')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        // Anchored on the separator: an unanchored `endsWith` would also let
        // any FUTURE `*_backup_screen.dart` out of the scan without anyone
        // deciding to exempt it.
        .where((f) => !f.path.endsWith('/backup_screen.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    expect(files.length, greaterThan(5),
        reason: 'the scan found almost no screens — it is reading nothing');

    final offenders = <String>[];
    for (final f in files) {
      offenders
          .addAll(unguardedSetStates(f.readAsStringSync(), label: f.path));
    }

    expect(offenders, isEmpty,
        reason: 'setState() after an await needs `if (!mounted) return;` '
            'BEFORE it (or an if (mounted) around it):\n'
            '${offenders.join('\n')}');
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// INS-13 — `_QuickLogTile` and `_QuickLogTileState` were 136 lines of a widget
/// nothing constructed.
///
/// The analyzer could not see it: the two classes name each other, and a
/// mutually-referencing dead pair satisfies `unused_element`. That is why this
/// needs a guard rather than a lint — and why the guard lands in the same
/// commit as the deletion, never before it. A guard that is red on
/// correct-for-now code gets suppressed, which is how it stops catching
/// anything.
///
/// The proof of deadness was exhaustive by construction rather than by luck:
/// both classes are private and `home_dashboard.dart` has no `part` directive,
/// so that one file IS their entire reachable scope.
void main() {
  const home = 'lib/features/home/screens/home_dashboard.dart';

  test('the dead quick-log tile stays gone', () {
    final src = File(home).readAsStringSync();
    expect(src.contains('_QuickLogTile'), isFalse,
        reason: 'reintroducing this widget means reintroducing 136 lines the '
            'analyzer cannot flag; build it fresh from AppCard instead');
  });

  test('and nothing else in the app grew a reference to it', () {
    final offenders = <String>[];
    for (final dir in ['lib', 'test', 'integration_test']) {
      final d = Directory(dir);
      if (!d.existsSync()) continue;
      for (final f in d
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        // This guard names the symbol it bans, so it must not flag itself.
        if (f.path.endsWith('no_dead_quick_log_tile_test.dart')) continue;
        if (f.readAsStringSync().contains('_QuickLogTile')) {
          offenders.add(f.path);
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the scanner is reading a real file (it can fail)', () {
    final src = File(home).readAsStringSync();
    expect(src.length, greaterThan(20000),
        reason: 'a tiny read means the path moved and both checks above are '
            'asserting nothing');
    // The banner that used to head the deck now heads what is actually there.
    expect(src.contains('quick log deck'), isFalse,
        reason: 'a section banner describing a deck that no longer exists is '
            'a comment that lies about the code beside it');
  });
}

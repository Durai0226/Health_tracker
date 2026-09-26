@Tags(['responsive'])
library;

/// Keeps the two responsive harnesses' screen registries complete.
///
/// Both are hand-maintained maps of widget builders, and a screen that is
/// simply absent from one of them is not reported as uncovered — it is not
/// reported at all. `responsive_overflow_test` printed "NO OVERFLOWS" for
/// twelve screens it had never constructed, and `touch_target_audit_test`
/// printed "none below the floor" for fifty. A harness whose coverage is a
/// literal list needs something that enumerates the real population, because
/// the list cannot notice what is missing from it.
///
/// So: every `*Screen` / `*Dashboard` class under `lib/` must be either
/// registered in each harness or named in that harness's skip list WITH a
/// reason. Adding a screen and forgetting the harness now fails here, which is
/// the only moment anyone is looking at the new screen.
///
/// Scope is deliberately the two names the app uses for a full-page surface.
/// It does not cover flows and one-off surfaces that follow neither convention
/// (`NunitoAddMedicationFlow`, `ProactiveNudge`); those are registered by hand
/// and are not what this guard is for.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `<screen class> : why it cannot be REGISTERED at all`.
///
/// Both are empty, and neither is a formality — three screens needed a fixture
/// (a seeded medicine, a populated devices controller, a library entry) rather
/// than an exemption, and a fixture is the better answer every time: an
/// exemption removes the screen from the report, a fixture puts it in.
///
/// Note what does NOT belong here. `BackupScreen` cannot RENDER in a host VM —
/// `BackupService` resolves `FirebaseFirestore.instance` in a field initialiser
/// — but it is still registered in both harnesses and named in each one's
/// `buildErrorAllowlist`. That is the difference the two mechanisms draw: an
/// allow-listed screen is a gap the report prints on every run, an unregistered
/// one is a gap nobody can see. Skip here only when the screen cannot be
/// CONSTRUCTED — no fixture can be built for its arguments.
const Map<String, String> _responsiveSkips = <String, String>{};

/// `<screen class> : why it cannot be registered` — see [_responsiveSkips].
const Map<String, String> _touchTargetSkips = <String, String>{};

final RegExp _screenClass =
    RegExp(r'^class\s+([A-Z][A-Za-z0-9_]*(?:Screen|Dashboard))\b', multiLine: true);

Iterable<File> _libSources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) =>
        f.path.endsWith('.dart') &&
        !f.path.endsWith('.g.dart') &&
        !f.path.endsWith('.freezed.dart') &&
        !f.path.endsWith('.mocks.dart'));

/// Every full-page surface class in the app, mapped to the file declaring it.
Map<String, String> _screenClasses() {
  final found = <String, String>{};
  for (final f in _libSources()) {
    for (final m in _screenClass.allMatches(f.readAsStringSync())) {
      found[m.group(1)!] = f.path;
    }
  }
  return found;
}

/// The text of one harness's `_screens` map literal, and nothing else.
///
/// Bounded at `'\n};'` — the only place a `};` starts a line, because every
/// entry in these maps is indented. The caller passes a [sentinel] that is
/// declared near the END of the map, so a window that closed early fails
/// loudly here instead of quietly reporting the screens it could not see as
/// unregistered.
String _registry(String path, String header, String sentinel) {
  final src = File(path).readAsStringSync();
  final start = src.indexOf(header);
  if (start < 0) {
    throw StateError('$path no longer declares `$header` — this guard is '
        'reading nothing. Update the header, do not delete the guard.');
  }
  final end = src.indexOf('\n};', start);
  if (end < 0) throw StateError('$path: unterminated registry map');
  final region = src.substring(start, end);
  if (!region.contains(sentinel)) {
    throw StateError('$path: the registry window stopped before `$sentinel`, '
        'so it is reading only part of the map.');
  }
  return region;
}

bool _isRegistered(String region, String className) =>
    RegExp('(?<![A-Za-z0-9_])$className\\s*\\(').hasMatch(region);

void main() {
  final screens = _screenClasses();

  test('the scan finds the app\'s screens at all', () {
    // A beacon, not a formality. Every assertion below is "no screen is
    // missing", which is trivially true of an empty scan — a renamed directory
    // or a tightened regex would turn this whole file green and silent.
    expect(screens.length, greaterThan(50),
        reason: 'only ${screens.length} screen classes found under lib/');
    for (final known in const [
      'SettingsScreen',
      'FocusScreen',
      'HomeDashboard',
      'WaterHistoryEditScreen',
    ]) {
      expect(screens.keys, contains(known),
          reason: '$known exists but the scan did not see it, so the scan is '
              'not looking where the screens are');
    }
  });

  group('responsive_overflow_test', () {
    const path = 'test/responsive/responsive_overflow_test.dart';
    late String region;
    setUpAll(() => region = _registry(
        path,
        'final Map<String, ScreenBuilder> _screens = {',
        'HealthSourceDetailScreen('));

    test('every screen is registered or skipped with a reason', () {
      final missing = <String>[];
      for (final e in screens.entries) {
        if (_isRegistered(region, e.key)) continue;
        if (_responsiveSkips.containsKey(e.key)) continue;
        missing.add('${e.key}  (${e.value})');
      }
      expect(missing, isEmpty,
          reason: 'these screens are in no responsive sweep, so the report '
              'says nothing about them at any device size. Register one in '
              '`_screens`, or add it to `_responsiveSkips` with the reason it '
              'cannot be built headlessly.\n${missing.join('\n')}');
    });

    test('no skip outlives the screen or the reason for it', () {
      for (final e in _responsiveSkips.entries) {
        expect(screens.keys, contains(e.key),
            reason: '${e.key} is skipped but no longer exists — drop the skip');
        expect(_isRegistered(region, e.key), isFalse,
            reason: '${e.key} is BOTH registered and skipped; the skip is a '
                'lie about coverage');
        expect(e.value.trim(), isNotEmpty,
            reason: '${e.key} is skipped with no reason');
      }
    });
  });

  group('touch_target_audit_test', () {
    const path = 'test/responsive/touch_target_audit_test.dart';
    late String region;
    setUpAll(() => region = _registry(
        path, 'final Map<String, Widget Function()> _screens = {', '_canaryKey:'));

    test('every screen is registered or skipped with a reason', () {
      final missing = <String>[];
      for (final e in screens.entries) {
        if (_isRegistered(region, e.key)) continue;
        if (_touchTargetSkips.containsKey(e.key)) continue;
        missing.add('${e.key}  (${e.value})');
      }
      expect(missing, isEmpty,
          reason: 'no tap target on these screens has ever been measured, and '
              'the audit reports "none below the floor" for them in the same '
              'words it uses for a clean result. Register one in `_screens`, '
              'or add it to `_touchTargetSkips` with a reason.\n'
              '${missing.join('\n')}');
    });

    test('no skip outlives the screen or the reason for it', () {
      for (final e in _touchTargetSkips.entries) {
        expect(screens.keys, contains(e.key),
            reason: '${e.key} is skipped but no longer exists — drop the skip');
        expect(_isRegistered(region, e.key), isFalse,
            reason: '${e.key} is BOTH registered and skipped; the skip is a '
                'lie about coverage');
        expect(e.value.trim(), isNotEmpty,
            reason: '${e.key} is skipped with no reason');
      }
    });
  });
}

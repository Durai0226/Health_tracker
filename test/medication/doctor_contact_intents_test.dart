/// The Email button on a doctor card has to be able to open a mail app.
///
/// Android 11+ package visibility hides every app that is not declared in the
/// manifest's `<queries>` block, so `url_launcher`'s `canLaunchUrl` answers
/// false for a scheme nothing visible handles. The manifest declared the
/// dialer — with a comment saying exactly why — and never declared mail. The
/// Email handler was a bare `if (await canLaunchUrl(uri))` with no else, so on
/// a phone with Gmail installed the button did nothing at all: no launch, no
/// error, no feedback.
///
/// Asserted against the manifest because that is where the defect lives; the
/// scheme a screen launches is only half of the contract.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String manifest;
  late String queries;

  setUpAll(() {
    manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final start = manifest.indexOf('<queries>');
    final end = manifest.indexOf('</queries>');
    expect(start, isNonNegative,
        reason: 'no <queries> block at all — every implicit intent this app '
            'launches is invisible on Android 11+');
    expect(end, greaterThan(start));
    // Comments stripped: this block explains itself at length, and a guard its
    // own prose satisfies is not a guard.
    queries = manifest
        .substring(start, end)
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  });

  /// Every scheme a screen hands to `canLaunchUrl`, and the action that
  /// resolves it.
  const required = <String, String>{
    'tel': 'android.intent.action.DIAL',
    'mailto': 'android.intent.action.SENDTO',
  };

  required.forEach((scheme, action) {
    test('<queries> declares $scheme so canLaunchUrl can see a handler', () {
      expect(queries, contains('android:scheme="$scheme"'),
          reason: 'lib/ launches "$scheme:" URIs. Without this entry '
              'canLaunchUrl returns false on Android 11+ and the button is '
              'silently dead.');
      expect(queries, contains(action),
          reason: 'the $scheme entry needs the $action it resolves through');
    });
  });

  test('every scheme launched in lib/ is declared', () {
    // Catches the next one: a screen adding sms:/geo:/whatever without the
    // matching manifest entry.
    final lib = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync())
        .join('\n');

    final launched = RegExp(r"Uri\.parse\('(\w+):")
        .allMatches(lib)
        .map((m) => m.group(1)!)
        .where((s) => s != 'http' && s != 'https' && s != 'package')
        .toSet();

    expect(launched, isNotEmpty,
        reason: 'the scan found no launched schemes at all, so this test is '
            'checking nothing');

    for (final scheme in launched) {
      expect(queries, contains('android:scheme="$scheme"'),
          reason: 'lib/ builds a "$scheme:" URI but the manifest <queries> '
              'block does not declare it, so Android 11+ hides every app that '
              'could handle it. Declared: $launched');
    }
  });
}

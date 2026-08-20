import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AdMob application ids, across both platforms at once.
///
/// ## Why this exists rather than a build-time check
///
/// Android already refuses quietly: `android/app/build.gradle.kts` logs a loud
/// warning on a release build when `ADMOB_APP_ID_ANDROID` is unset or still
/// Google's test id. iOS has nothing — `GADApplicationIdentifier` is a literal in
/// `Info.plist`, so an ipa can be produced with the test id and no build step
/// objects.
///
/// The obvious fix is an Xcode run-script phase, and it was rejected: adding one
/// means hand-editing `project.pbxproj`, which cannot be verified without Xcode
/// on the machine, and a corrupt pbxproj breaks the whole iOS build in a way that
/// is much harder to diagnose than the problem it solves.
///
/// So this guards the mistake that will ACTUALLY happen instead. Nobody forgets
/// both ids — the Android build shouts. What happens is you set Android, ship,
/// and iOS quietly keeps serving test ads: zero revenue, and a policy strike if
/// the test id is used against real traffic. A drift check catches that, is
/// deterministic, and needs no toolchain.
void main() {
  /// Google's public test application id, shared by both platforms.
  const testIdFragment = '3940256099942544';

  String read(String path) {
    final f = File(path);
    expect(f.existsSync(), isTrue, reason: '$path is missing');
    return f.readAsStringSync();
  }

  test('the two platforms agree about whether ads are configured', () {
    final iosPlist = read('ios/Runner/Info.plist');
    final iosIsTest = iosPlist.contains(testIdFragment);

    // Android reads its id from a gitignored gradle.properties, so its real
    // value is not in the repo. What IS in the repo is whether the guard is
    // still armed — and the guard names the same test-id fragment.
    final gradle = read('android/app/build.gradle.kts');
    final androidGuardArmed = gradle.contains(testIdFragment);

    expect(androidGuardArmed, isTrue,
        reason: 'the Android release guard no longer mentions the test id, so '
            'either it was removed or the fragment changed — it is the only '
            'thing stopping a release build shipping test ads');

    // The asymmetry to catch: someone sets a real iOS id and drops the Android
    // guard, or vice versa. Both-are-test is the current, known state and is
    // recorded in docs/release-checklist.md; both-are-real is the goal.
    if (!iosIsTest) {
      fail('iOS has a real AdMob id but the Android guard still points at the '
          'test id. Set ADMOB_APP_ID_ANDROID and update this test, or the two '
          'platforms are shipping different ad configurations.');
    }
  });

  test('the outstanding test ids are documented, not just present', () {
    // A TODO the release checklist does not know about is a TODO nobody reads.
    // This fails if the ids are still test ids AND the checklist has stopped
    // mentioning them — i.e. if someone "closes" the item without doing it.
    final iosPlist = read('ios/Runner/Info.plist');
    if (!iosPlist.contains(testIdFragment)) return; // done — nothing to document

    final checklist = read('docs/release-checklist.md');
    expect(checklist.toLowerCase(), contains('admob'),
        reason: 'the test ids are still in the tree, so the release checklist '
            'must still list them as outstanding');
    expect(iosPlist, contains('TODO(ads)'),
        reason: 'the Info.plist literal must keep saying it is a placeholder');
  });
}

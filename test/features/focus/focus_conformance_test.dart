import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/focus/models/app_allow_list.dart';

/// Design-system conformance for the Focus SCREENS and WIDGETS.
///
/// Source gates, on purpose. Every defect below was found by reading the files,
/// not by a failing render: a hardcoded `#4CAF50` renders perfectly, a
/// `BorderRadius.circular(28)` looks fine on its own, and a 10pt caption is
/// legible to someone with good eyes on a big phone. They are only wrong
/// *relative to the system*, and the only instrument that can see that is one
/// that reads the source.
///
/// `focus_guards_test.dart` is the sibling of this file and covers the emoji
/// rule, perpetual motion and health claims. This one covers colour, radius,
/// type scale, shared components, and three controls that lied.
void main() {
  final files = Directory('lib/features/focus')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) =>
          f.path.contains('/screens/') || f.path.contains('/widgets/'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  /// Source with `//` and `///` comment LINES removed.
  ///
  /// Every gate here reads this rather than the raw file, because the comments
  /// in these screens deliberately quote the thing they replaced — "was a
  /// hardcoded #4CAF50", "`Colors.grey.shade300` measures 1.32:1" — and a guard
  /// that fires on the explanation of its own fix is a guard nobody keeps.
  String code(File f) => f
      .readAsStringSync()
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  String rel(File f) => f.path;

  /// Every (file, line number, line) in scope, comments already stripped.
  Iterable<(String, int, String)> lines() sync* {
    for (final f in files) {
      final split = code(f).split('\n');
      for (var i = 0; i < split.length; i++) {
        yield (rel(f), i + 1, split[i]);
      }
    }
  }

  void expectNoHits(RegExp pattern, String reason,
      {bool Function(String line)? allow}) {
    final hits = <String>[];
    for (final (path, n, line) in lines()) {
      if (!pattern.hasMatch(line)) continue;
      if (allow != null && allow(line)) continue;
      hits.add('$path:$n  ${line.trim()}');
    }
    expect(hits, isEmpty, reason: '$reason\n${hits.join('\n')}');
  }

  test('the file scope actually resolved something', () {
    // A source sweep that matched no files is unmeasured, not clean — the same
    // self-check `focus_guards_test.dart` applies to its own matchers.
    expect(files.length, greaterThanOrEqualTo(9),
        reason: 'expected the Focus screens + widgets, found '
            '${files.map(rel).join(', ')}');
  });

  group('colour comes from the token source', () {
    test('no Colors.* literal (transparent excepted)', () {
      // `Colors.transparent` is the ABSENCE of a colour — the idiom for a
      // Material/Ink that must not paint its own ground — so it carries no
      // theme information and nothing in the palette replaces it.
      //
      // Everything else did carry information and got it wrong: `Colors.white`
      // on a #4CAF50 header (2.78:1), `Colors.grey.shade200` as a border that
      // does not exist in dark mode, `Colors.grey.shade300` as a drag handle
      // measuring 1.32:1 on the light surface.
      //
      // The lookbehind is load-bearing: without it this matches the `Colors.`
      // inside `FocusTag.availableColors.first`.
      expectNoHits(
        RegExp(r'(?<![A-Za-z_$])Colors\.[a-zA-Z]'),
        'colour must come from AppColorsExt.of(context) — '
        'ext.fillBg/fillFg for filled controls, ext.mark for a foreground '
        'mark, container/onContainer for a tinted badge:',
        allow: (l) => l.contains('Colors.transparent'),
      );
    });

    test('no raw hex colour', () {
      expectNoHits(
        RegExp(r'Color\(0x'),
        'a hex literal cannot theme and cannot have been contrast-checked '
        'against both surfaces — use a swatch:',
      );
    });
  });

  group('radius comes from the one scale', () {
    test('no BorderRadius.circular / Radius.circular literal', () {
      // The scale collapsed 21 distinct radii to six. These files had 83 raw
      // ones — including 28, which is not on the scale at all and sat next to
      // the theme's own 24pt sheet corners.
      expectNoHits(
        RegExp(r'(BorderRadius|Radius)\.circular\('),
        'use AppRadius.brSm/brMd/brLg/brCard/brSheet/brFull '
        '(or AppRadius.topSheet for a bottom sheet):',
      );
    });
  });

  group('type comes from the one scale', () {
    test('nothing is set below the 11pt floor', () {
      // labelSmall (11) is the smallest slot the scale has. These files carried
      // captions at 10, 9 and 8 — the 8 being hour labels inside a heatmap cell
      // roughly 11pt WIDE, which is why that one moved to an axis instead of
      // being enlarged in place.
      final sized = RegExp(r'fontSize:\s*(\d+(?:\.\d+)?)');
      final hits = <String>[];
      for (final (path, n, line) in lines()) {
        for (final m in sized.allMatches(line)) {
          if (double.parse(m.group(1)!) < 11) {
            hits.add('$path:$n  ${line.trim()}');
          }
        }
      }
      expect(hits, isEmpty,
          reason: 'below the scale floor — the smallest slot is labelSmall '
              '(11):\n${hits.join('\n')}');
    });

    test('the floor matcher can actually fire', () {
      // Self-verification: a matcher that cannot fire reads as coverage while
      // guarding nothing.
      final sized = RegExp(r'fontSize:\s*(\d+(?:\.\d+)?)');
      final m = sized.firstMatch('style: TextStyle(fontSize: 10),');
      expect(m, isNotNull);
      expect(double.parse(m!.group(1)!) < 11, isTrue);
    });
  });

  group('shared components, not hand-rolled ones', () {
    test('no raw FloatingActionButton', () {
      // AppFab owns four things a raw FAB re-declaration keeps losing:
      // `heroTag: null` (the shell keeps several FAB screens alive in an
      // IndexedStack, so a shared tag throws "multiple heroes share the same
      // tag" on a push), the brLg shape, labelLarge text, and the medium-impact
      // haptic. Both Focus FABs had lost all four AND were brand teal on a
      // violet feature.
      expectNoHits(
        RegExp(r'FloatingActionButton(\.extended)?\s*\('),
        'use AppFab(icon:, label:, accent:, onPressed:):',
      );
    });

    test('no raw showModalBottomSheet', () {
      // Four sheets here set `backgroundColor: transparent`, drew their own
      // 28pt top corners against the theme's 24, and hand-drew a grab handle in
      // `Colors.grey.shade300` — invisible on light, a bright bar on dark.
      // AppBottomSheet owns the handle colour, the radius, the keyboard inset,
      // and the Material that lets rows show their ink.
      expectNoHits(
        RegExp(r'showModalBottomSheet[<(]'),
        'use AppBottomSheet.show(context, ...):',
      );
    });

    test('no magic bottom spacer under a scrollable', () {
      // `SizedBox(height: 100)` is the tab-root constant (nav 68 + FAB
      // overhang 20 + gap 12) and every Focus screen that used it is a PUSHED
      // screen — so it was both the wrong number and missing the gesture-bar
      // inset. AppInsets computes each case from the real viewPadding.
      expectNoHits(
        RegExp(r'SizedBox\(height:\s*(100|120)\b'),
        'use AppInsets.pushed(context) or AppInsets.underNav(context):',
      );
    });
  });

  group('controls do what they appear to do', () {
    test('the distractions list offers no isAllowed switch', () {
      // M13. Nothing read the flag: `AppAllowList.allowedApps` and
      // `blockedApps` are its only consumers and neither getter has a caller in
      // lib/. So the switch persisted a boolean and changed nothing — a control
      // that reads as "is this app permitted", on a screen that states in its
      // own copy that the app permits and forbids nothing.
      //
      // The FIELD is fine and stays (it is in persisted JSON, and this asserts
      // nothing about the model); it is the offered control that was a lie.
      final screen =
          code(File('lib/features/focus/screens/app_allow_list_screen.dart'));
      expect(screen.contains('isAllowed'), isFalse,
          reason: 'app_allow_list_screen must not render a control for '
              'isAllowed — nothing in lib/ reads it');
    });

    test('isAllowed still has no reader, which is why the switch went', () {
      // The other half of the same claim, asserted rather than assumed: if a
      // real consumer ever appears, this fails and the gate above should be
      // reconsidered rather than worked around.
      final libDart = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.endsWith('.g.dart'))
          .where((f) => !f.path.endsWith('app_allow_list.dart'));
      final readers = <String>[];
      for (final f in libDart) {
        for (final l in f.readAsStringSync().split('\n')) {
          if (l.trimLeft().startsWith('//')) continue;
          if (RegExp(r'\.isAllowed\b').hasMatch(l)) {
            readers.add('${f.path}  ${l.trim()}');
          }
        }
      }
      expect(readers, isEmpty,
          reason: 'something now reads AllowedApp.isAllowed:\n'
              '${readers.join('\n')}');
    });

    test('the distractions screen offers no allow-list presets', () {
      // L23. `PresetAllowList` bulk-added Notion, Todoist, Duolingo, Khan
      // Academy and Spotify — a vestige of when this screen was a list of apps
      // you were ALLOWED to open. Filing Khan Academy under "what pulls you
      // away" contradicts the sentence in the card directly above it, and
      // seeding six apps the user never named is the opposite of the noticing
      // the screen exists for.
      final screen =
          code(File('lib/features/focus/screens/app_allow_list_screen.dart'));
      expect(screen.contains('PresetAllowList'), isFalse,
          reason: 'the presets contradict the screen: it lists what pulls you '
              'away, and these are apps to work in');
      // The model class itself is untouched and still consistent — this gate is
      // about what the screen offers, not about deleting someone else's file.
      expect(PresetAllowList.getProductivityApps(), isNotEmpty);
    });

    test('a flow session is not announced with a minute count', () {
      // M14. `startSession()` sets `_selectedMinutes` to the SAFETY CAP for a
      // flow session, because `_phaseMinutes` needs a number. The start toast
      // read that same field, so flow mode was greeted with
      // "600 minute session - stay focused!" — absurd on its face, and a target
      // the feature explicitly refuses to set (the ring stays empty and the
      // clock counts UP for exactly this reason).
      final screen =
          code(File('lib/features/focus/screens/focus_screen.dart'));
      final start = screen.indexOf('void _startSession()');
      expect(start, greaterThan(-1),
          reason: 'FocusScreen._startSession has been renamed — re-point this');
      final toast = screen.indexOf('FocusToast.sessionStarted', start);
      expect(toast, greaterThan(-1),
          reason: 'the start toast has moved — re-point this gate');
      final guard = screen.indexOf('isCountUp', start);
      expect(guard, allOf(greaterThan(-1), lessThan(toast)),
          reason: 'flow mode must branch away BEFORE the minutes toast — '
              'selectedMinutes is kMaxSessionMinutes by then');
    });

    test('no tappable in the Focus screens has a silently-null onTap', () {
      // L21. A locked plant tile and the idle ambient play button both looked
      // tappable, were tapped, and did nothing at all — no toast, no shake, no
      // haptic. `onTap: cond ? handler : null` is the shape that produces it,
      // and it is indistinguishable from an enabled control at a glance.
      //
      // Deliberately narrow: `onPressed: null` on an AppButton is a real
      // DISABLED state and renders as one (AppButton greys the fill), so only
      // the bare-gesture form is caught.
      expectNoHits(
        RegExp(r'onTap:\s*[\w.]+\s*\?[^?]*:\s*null\b'),
        'a conditionally-null onTap is a dead tap — give the disabled branch '
        'a toast that says what is needed:',
      );
    });
  });
}

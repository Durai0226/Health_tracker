@Tags(['responsive'])
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/design/app_design.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';
import '../../support/perf_rating.dart';
import '../../support/text_layout.dart';

/// Alignment, measured — the "inch by inch" pass on the Focus screen.
///
/// **Why geometry and not goldens.** `flutter_test` renders in a square-em
/// fallback font where every glyph is as wide as the font size — roughly twice the
/// shipped Inter/Plus Jakarta — and runtime font fetching is pinned OFF for
/// determinism (with it on, the same responsive sweep reported 18 overflowing
/// screens on one run and 4 on the next). A golden captured under those conditions
/// is a picture of a layout no user will ever see. Reaching the real typeface needs
/// the TTFs bundled plus a `flutter_test_config.dart` FontLoader, and CI here is
/// one developer's Mac (`tool/rate.dart` hardcodes the SDK path), so the first move
/// to Linux would turn every golden red at once with no way to tell a regression
/// from a rasteriser difference.
///
/// The repo already made this argument itself, in
/// `test/core/widgets/progress_ring_geometry_test.dart`: goldens generated from a
/// buggy painter bless the bug. So this asserts the things the layout algorithm
/// decides — boxes, centres, gutters, gaps, baselines — which are font-insensitive
/// where it matters and are exactly what "aligned" means.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    AudioService().engineForTesting = FakeAudioEngine();
    FocusService().resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
  });

  tearDown(() async {
    FocusService().resetForTesting();
    await db.close();
  });

  /// Findings, grouped per (surface, dimension) so one drift does not cost twelve
  /// P2s across the device/scale matrix.
  final findings = <String, List<String>>{};

  /// Geometry probes actually laid out, reported in the beacon so a run that
  /// measured nothing cannot certify the dimension as clean.
  var geometryChecks = 0;
  void note(String dimension, String detail) =>
      findings.putIfAbsent(dimension, () => []).add(detail);

  Future<void> pumpFocus(WidgetTester tester,
      {required double width, required double scale}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1400),
          textScaler: TextScaler.linear(scale),
        ),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AccentScope(
              feature: FeatureAccent.focus, child: FocusScreen()),
        ),
      ));
      // Never pumpAndSettle: this screen runs looping pulse animations.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 350));
      geometryChecks++;
    } finally {
      FlutterError.onError = prev;
    }
  }

  const widths = [320.0, 375.0, 428.0];
  const scales = [1.0, 1.3, 2.0];

  testWidgets('every section shares one left edge', (tester) async {
    // The screen hand-rolls its own horizontal padding in FOURTEEN places rather
    // than wrapping the column once. That is fourteen independent chances for one
    // section to sit a few points off, and nothing checked it — a drift of 4pt is
    // invisible in review and obvious on a device.
    for (final width in widths) {
      await withClock(Clock.fixed(DateTime(2026, 3, 14, 13, 0)), () async {
        await pumpFocus(tester, width: width, scale: 1.0);
      });

      // Scroll the whole list, collecting headers as they are built.
      //
      // The previous version measured `find.byType(SectionHeader)` once, without
      // scrolling, and bailed via `if (length < 2) continue` — which asserts
      // NOTHING and passes. The restructure took the resting surface from
      // fourteen hand-padded sections to three, and two of those three (`More`
      // and today's progress) sit below the fold of a lazy `ListView`, so a
      // single-shot look can legitimately find one header and quietly skip the
      // test. That is the same silent no-op this file's grid test was caught in.
      //
      // Vertical scrolling cannot change a horizontal left edge, so accumulating
      // `dx` across scroll positions is sound.
      final lefts = <double>{};
      final seenTitles = <String>{};
      final mainList = find.byType(Scrollable).first;
      for (var pass = 0; pass < 10; pass++) {
        for (final element in find.byType(SectionHeader).evaluate()) {
          final header = element.widget as SectionHeader;
          seenTitles.add(header.title);
          lefts.add(double.parse(
              tester.getTopLeft(find.byWidget(header)).dx.toStringAsFixed(1)));
        }
        await tester.drag(mainList, const Offset(0, -420));
        await tester.pump(const Duration(milliseconds: 50));
      }

      if (lefts.length > 1) {
        note('alignment-drift',
            '${width.toInt()}pt: section left edges disagree: $lefts '
            '(headers seen: ${seenTitles.join(', ')})');
      }

      // A probe that measured nothing must not read as a pass. Three headers
      // remain on the idle surface: the duration picker, `More`, and today's
      // progress. Finding fewer means the scroll never reached them and the
      // alignment check above covered less than it claims.
      expect(seenTitles.length, greaterThanOrEqualTo(3),
          reason: '${width.toInt()}pt: only reached ${seenTitles.length} section '
              'header(s) (${seenTitles.join(', ')}) — the sweep did not cover the '
              'surface, so a clean result here would be meaningless');

      await tester.pumpWidget(const SizedBox.shrink());
    }

    expect(findings['alignment-drift'], anyOf(isNull, isEmpty),
        reason: 'sections must share a left edge:\n'
            '${(findings['alignment-drift'] ?? []).join('\n')}');
  });

  testWidgets('the ring, the clock and the control share one axis',
      (tester) async {
    for (final width in widths) {
      for (final scale in scales) {
        await withClock(Clock.fixed(DateTime(2026, 3, 14, 13, 0)), () async {
          await pumpFocus(tester, width: width, scale: scale);
        });

        final ring = find.byType(ProgressRing);
        if (ring.evaluate().isEmpty) continue;

        final ringCentre = tester.getCenter(ring.first);
        final ringSize = tester.getSize(ring.first);

        // The ring is declared `size: 210`. At 320pt with the gutters and card
        // padding taken out there is room, but a future padding change could
        // squeeze it — and a squashed ring paints an ellipse.
        if ((ringSize.width - ringSize.height).abs() > 0.5) {
          note('alignment-drift',
              '${width.toInt()}pt @${scale}x: ring is ${ringSize.width}x'
              '${ringSize.height}, not square');
        }

        // The clock sits under the ring, so its centre must share the ring's axis.
        //
        // This was `find.text(FocusService().formattedTime)` and it NEVER MATCHED.
        // At rest `remainingSeconds` is 0, so `formattedTime` is "00:00", while the
        // screen renders `'$idleMinutes:00'` — "25:00". Every assertion in this
        // block was therefore skipped by the `isNotEmpty` guard, including the
        // 2.0x wrap check the comment below claims to prove. An audit caught it.
        //
        // Matched by SHAPE instead, so it cannot drift out of sync with whatever
        // the screen chooses to display.
        final clock = find.byWidgetPredicate(
            (w) => w is Text && RegExp(r'^\d+:\d\d$').hasMatch(w.data ?? ''),
            description: 'the MM:SS clock readout');
        if (clock.evaluate().isEmpty) {
          note('alignment-drift',
              '${width.toInt()}pt @${scale}x: no MM:SS clock readout was found at '
              'all, so the centring and wrap checks measured nothing');
        } else {
          final dx = (tester.getCenter(clock.first).dx - ringCentre.dx).abs();
          if (dx > 1.0) {
            note('alignment-drift',
                '${width.toInt()}pt @${scale}x: clock is ${dx.toStringAsFixed(1)}pt '
                'off the ring centre');
          }
          // FittedBox(scaleDown) is what keeps "25:00" on one line inside a
          // fixed circle. Prove it holds at 2.0x rather than trusting it.
          final lines = renderedLineCount(tester, clock.first);
          if (lines > 1) {
            note('alignment-drift',
                '${width.toInt()}pt @${scale}x: the clock wrapped onto $lines lines');
          }
        }

        // "and the control" — in the title since this test was written, never
        // actually located. The primary action is the whole point of the surface;
        // a Start button off the ring's axis is the most visible misalignment the
        // screen can have.
        final start = find.byWidgetPredicate(
            (w) => w is AppButton && w.label.startsWith('Start'),
            description: 'the Start button');
        if (start.evaluate().isEmpty) {
          note('alignment-drift',
              '${width.toInt()}pt @${scale}x: no Start control was found, so this '
              "test's own title covers something it does not check");
        } else {
          final dx = (tester.getCenter(start.first).dx - ringCentre.dx).abs();
          if (dx > 1.0) {
            note('alignment-drift',
                '${width.toInt()}pt @${scale}x: Start is ${dx.toStringAsFixed(1)}pt '
                'off the ring centre');
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }

    expect(findings['alignment-drift'], anyOf(isNull, isEmpty),
        reason: (findings['alignment-drift'] ?? []).join('\n'));
  });

  testWidgets('the More grid is six equal cards in three rows', (tester) async {
    // Rewritten for the restructure, which moved Breathing and Relaxation off the
    // resting surface and into this grid: four cards in two rows became six in
    // three, and the header lost the redundant "Features".
    //
    // The card set is named EXPLICITLY rather than discovered by walking the
    // ancestor Row of one title. The old version measured whichever Row happened
    // to enclose 'Statistics' — which silently covered two of the four cards, and
    // would have gone on reporting a clean grid however many rows were added
    // below it. Naming the six is what makes "the grid" mean the whole grid.
    const titles = [
      'Breathing',
      'Relaxation',
      'Statistics',
      'Plant Trees',
      'Tags',
      'Distractions',
    ];

    for (final width in widths) {
      await withClock(Clock.fixed(DateTime(2026, 3, 14, 13, 0)), () async {
        await pumpFocus(tester, width: width, scale: 1.0);
      });

      // Scroll the grid into view — it is near the end of a long screen, and a
      // lazily-built list will not lay out what is below the fold. That is not
      // hypothetical: an overflow in the Distractions screen stayed hidden for
      // exactly this reason until a card above it got shorter.
      // The scrollable must be named explicitly. `scrollUntilVisible` defaults to
      // `find.byType(Scrollable)` and then calls `.single` on it, and this screen
      // has several — the vertical list plus the horizontal chip strips. Which is
      // also why the previous version of this test never scrolled at all: its
      // `'More Features'` finder came back empty from the lazy list, the scroll
      // was skipped by the `isNotEmpty` guard, and the grid was measured only on
      // the runs where it happened to be built already. Depth-first order makes
      // `.first` the outer vertical list, deterministically.
      final header = find.text('More');
      final mainList = find.byType(Scrollable).first;
      if (header.evaluate().isEmpty) {
        await tester.scrollUntilVisible(header, 300,
            scrollable: mainList, maxScrolls: 30);
      }
      await tester.pump(const Duration(milliseconds: 50));

      final sizes = <String, Size>{};
      for (final title in titles) {
        final label = find.text(title);
        if (label.evaluate().isEmpty) {
          note('alignment-drift',
              '${width.toInt()}pt: the More grid is missing "$title"');
          continue;
        }
        final card =
            find.ancestor(of: label.first, matching: find.byType(AppCard));
        if (card.evaluate().isEmpty) continue;
        sizes[title] = tester.getSize(card.first);
      }

      // A probe that measured nothing must not read as a pass.
      if (sizes.length < titles.length) {
        note('alignment-drift',
            '${width.toInt()}pt: only ${sizes.length} of ${titles.length} grid '
            'cards were measurable');
      }

      if (sizes.length >= 2) {
        final widthsSet = sizes.values
            .map((s) => double.parse(s.width.toStringAsFixed(1)))
            .toSet();
        if (widthsSet.length > 1) {
          note('alignment-drift',
              '${width.toInt()}pt: grid card widths disagree: $widthsSet');
        }
        // Heights are compared WITHIN a row. Rows may legitimately differ from
        // each other — IntrinsicHeight equalises each row to its own tallest
        // card — but two cards side by side must match, which is what "a short
        // card next to a tall one reads as broken" actually means.
        for (var i = 0; i + 1 < titles.length; i += 2) {
          final a = sizes[titles[i]], b = sizes[titles[i + 1]];
          if (a == null || b == null) continue;
          if ((a.height - b.height).abs() > 0.5) {
            note('alignment-drift',
                '${width.toInt()}pt: "${titles[i]}" is ${a.height}pt tall beside '
                '"${titles[i + 1]}" at ${b.height}pt');
          }
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }

    expect(findings['alignment-drift'], anyOf(isNull, isEmpty),
        reason: (findings['alignment-drift'] ?? []).join('\n'));
  });

  // Price ONCE, after every test has contributed.
  //
  // `emitAll` used to be called at the end of all four tests over a `findings`
  // map that is declared in `main()`'s scope and never cleared. So a single
  // alignment drift recorded by the first test was re-emitted by the three later
  // calls: 4 x P2 = -20, score 80, grade B, for one defect. That is the exact
  // multiplier `docs/rating.md` names as already fixed ("one blank screen emitted
  // twelve findings and cost 12 x P1"), reintroduced one scope up — the grouping
  // worked WITHIN a test and broke ACROSS them.
  //
  // The per-test `expect`s stay where they are: they gate, and each test should be
  // individually red. Only the pricing moved.
  tearDownAll(() {
    reportMeasured(const ['alignment-drift'], samples: geometryChecks);
    emitAll(findings);
  });

  testWidgets('chip rows keep one height and reach the 44pt tap floor',
      (tester) async {
    // Rewritten after an audit found the title promised two things the body did
    // not do.
    //
    //  * **44pt was never asserted at all.** The name says "reach the 44pt tap
    //    floor" and no assertion mentioned 44. That floor is now checked, and only
    //    for chips that are actually TAPPABLE: `AppChip` applies
    //    `minHeight: onTap != null ? 44 : 0` (primitives.dart), so a display-only
    //    chip sitting at 32pt is correct, not a defect. Measuring those is what
    //    produced the phantom "32pt chips on focus" finding that sat in
    //    docs/ux-review.md for weeks.
    //  * **"one height" allowed four.** The check was `heights.length > 3`, three
    //    times looser than its own name. A chip row is one visual row; two
    //    distinct heights in it already read as broken.
    for (final scale in scales) {
      await withClock(Clock.fixed(DateTime(2026, 3, 14, 13, 0)), () async {
        await pumpFocus(tester, width: 375, scale: scale);
      });

      final chips = find.byType(AppChip);
      if (chips.evaluate().length >= 2) {
        final heights = <double>{};
        for (var i = 0; i < chips.evaluate().length; i++) {
          final chip = tester.widget<AppChip>(chips.at(i));
          final size = tester.getSize(chips.at(i));
          heights.add(double.parse(size.height.toStringAsFixed(1)));

          // The floor in the test's own title, finally applied.
          if (chip.onTap != null && size.height < 44.0) {
            note('alignment-drift',
                '@${scale}x: a TAPPABLE chip is ${size.height.toStringAsFixed(1)}pt '
                'tall, under the 44pt floor this test is named after');
          }
        }
        if (heights.length > 2) {
          note('alignment-drift',
              '@${scale}x: ${heights.length} distinct chip heights: $heights');
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }

    expect(findings['alignment-drift'], anyOf(isNull, isEmpty),
        reason: (findings['alignment-drift'] ?? []).join('\n'));
  });
}

/// Emit before asserting.
///
/// `expect` throws, and a harness that dies before reporting contributes nothing
/// to the score — that asymmetry is how three broken instruments once left the
/// rating at 100. Grouped per dimension so one drift is one finding, not one per
/// width × scale combination.
void emitAll(Map<String, List<String>> findings) {
  for (final e in findings.entries) {
    if (e.value.isEmpty) continue;
    emitFinding(Finding(
      feature: 'Focus',
      screen: 'focus',
      dimension: e.key,
      sev: Sev.p2,
      detail: '${e.value.length} case(s): ${e.value.take(3).join('; ')}',
      source: 'geometry assertion on the laid-out render tree',
    ));
  }
}

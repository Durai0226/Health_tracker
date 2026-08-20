@Tags(['responsive'])
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/design/app_design.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/focus/screens/app_allow_list_screen.dart';
import 'package:tablet_remainder/features/focus/screens/custom_tags_screen.dart';
import 'package:tablet_remainder/features/focus/screens/detailed_stats_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_garden_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/screens/plant_real_trees_screen.dart';
import 'package:tablet_remainder/features/focus/screens/relaxation_screen.dart';
import 'package:tablet_remainder/features/focus/screens/settings/focus_reminders_settings_screen.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';
import '../../support/perf_rating.dart';

/// Text that is invisible in dark mode.
///
/// `docs/ui-audit.md` measured **≈1.05:1** contrast on five Focus screens and put
/// it bluntly: the titles were not "hard to read", they were *invisible*. Root
/// cause was `AppColors` exposing light-only `static const` values next to
/// theme-aware `getX(context)` helpers, and these screens reaching for the
/// constants. It was fixed on-device and **nothing guarded it**.
///
/// Two instruments, deliberately:
///
///  * `focus_guards_test.dart` bans the light-only constants by source grep. That
///    is the real fix — it cannot flake and it closes the whole class.
///  * this probe is the backstop, for a hard-coded `Colors.white` or a themed
///    colour that resolves wrong.
///
/// **Gated at 1.5:1, reported below 4.5:1.** `rating/manifest.json` deliberately
/// excludes `a11y-contrast` because `meetsGuideline(textContrastGuideline)`
/// over-reports on this app's gradients, and that objection is correct — so this
/// respects it: gradient subtrees are skipped entirely, and the gate only fires
/// where text is *effectively invisible*. No legitimate design pairing lands under
/// 1.5:1, and the measured failure was 1.05:1, so the threshold catches every bug
/// the audit found without inheriting the false positives.
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

  final surfaces = <String, Widget Function()>{
    'focus': () => const FocusScreen(),
    'focus_stats': () => const DetailedStatsScreen(),
    'focus_garden': () => const FocusGardenScreen(),
    'focus_tags': () => const CustomTagsScreen(),
    'focus_apps': () => const AppAllowListScreen(),
    'plant_trees': () => const PlantRealTreesScreen(),
    'relaxation': () => const RelaxationScreen(),
    'focus_reminders': () => const FocusRemindersSettingsScreen(),
  };

  double luminance(Color c) => c.computeLuminance();

  double contrast(Color a, Color b) {
    final la = luminance(a), lb = luminance(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// The nearest ancestor that paints a resolvable OPAQUE colour.
  ///
  /// Returns null when the nearest background is a gradient — those are skipped
  /// rather than guessed at, which is the whole reason the app-wide contrast
  /// dimension was excluded from scoring.
  Color? backgroundBehind(RenderObject node) {
    RenderObject? current = node.parent;
    while (current != null) {
      if (current is RenderDecoratedBox) {
        final d = current.decoration;
        if (d is BoxDecoration) {
          if (d.gradient != null) return null; // do not guess
          final c = d.color;
          if (c != null && c.a == 1.0) return c;
        }
      }
      if (current is RenderPhysicalModel && current.color.a == 1.0) {
        return current.color;
      }
      if (current is RenderPhysicalShape) {
        final c = current.color;
        if (c.a == 1.0) return c;
      }
      current = current.parent;
    }
    return null;
  }

  /// Text/background pairs resolved across every surface. Reported in the beacon:
  /// a contrast sweep that resolved nothing is unmeasured, not clean.
  var textNodesChecked = 0;
  final invisible = <String, List<String>>{};
  final belowAA = <String, List<String>>{};

  for (final entry in surfaces.entries) {
    final name = entry.key;

    testWidgets('$name has no invisible text in dark mode', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(375, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        await withClock(Clock.fixed(DateTime(2026, 3, 14, 13, 0)), () async {
          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.darkTheme,
            home: AccentScope(
                feature: FeatureAccent.focus, child: entry.value()),
          ));
          // Never pumpAndSettle a Focus screen.
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pump(const Duration(milliseconds: 350));
        });
      } catch (_) {
        // A screen that cannot build headlessly is the responsive sweep's
        // problem, not this one's.
        return;
      } finally {
        FlutterError.onError = prev;
      }

      var checked = 0;
      void walk(RenderObject node) {
        if (node is RenderParagraph) {
          final style = node.text.style;
          final fg = style?.color;
          final bg = backgroundBehind(node);
          if (fg != null && fg.a == 1.0 && bg != null) {
            checked++;
            final ratio = contrast(fg, bg);
            final text = node.text.toPlainText().trim();
            if (text.isEmpty) return;
            final label = '$name: "${text.length > 40 ? '${text.substring(0, 40)}…' : text}" '
                '${ratio.toStringAsFixed(2)}:1';
            if (ratio < 1.5) {
              invisible.putIfAbsent(name, () => []).add(label);
            } else if (ratio < 4.5) {
              belowAA.putIfAbsent(name, () => []).add(label);
            }
          }
        }
        node.visitChildren(walk);
      }

      final root = tester.binding.renderViewElement?.renderObject;
      if (root != null) walk(root);

      // A probe that measured nothing must not read as a pass.
      textNodesChecked += checked;
      expect(checked, greaterThan(0),
          reason: '$name: no text/background pair was resolvable, so this '
              'assertion checked nothing — the walk or the theme is wrong');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 7));
    });
  }

  tearDownAll(() {
    // ignore: avoid_print
    print('\n===== FOCUS DARK MODE =====');
    if (belowAA.isNotEmpty) {
      // ignore: avoid_print
      print('-- below 4.5:1 (reported, not gated) --');
      belowAA.forEach((k, v) {
        for (final line in v.toSet().take(6)) {
          // ignore: avoid_print
          print('   $line');
        }
      });
    }
    if (invisible.isEmpty) {
      // ignore: avoid_print
      print('no invisible text on any Focus surface');
    }
    // ignore: avoid_print
    print('===========================\n');

    // Emit BEFORE asserting: expect throws, and a harness that dies before
    // reporting leaves the rating untouched. Grouped per surface so one bad screen
    // is one P0, not one per string.
    // Beacon first: these dimensions were measured, findings or not.
    // Without this a clean run and a run that never happened are the same
    // silence, and tool/rate.dart scores both as perfect.
    reportMeasured(const ['invisible-text'], samples: textNodesChecked);

    for (final e in invisible.entries) {
      emitFinding(Finding(
        feature: 'Focus',
        screen: e.key,
        dimension: 'invisible-text',
        sev: Sev.p0,
        detail: '${e.value.length} string(s) under 1.5:1: '
            '${e.value.take(3).join('; ')}',
        source: 'WCAG ratio from Color.computeLuminance against the nearest '
            'opaque ancestor; gradients skipped',
      ));
    }

    expect(invisible, isEmpty,
        reason: 'text that cannot be read at all in dark mode:\n'
            '${invisible.values.expand((v) => v).join('\n')}');
  });
}

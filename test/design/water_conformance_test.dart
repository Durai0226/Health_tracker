/// Regression guards for the WATER design-system pass.
///
/// `design_tokens_guard_test.dart` already counts deviations per file and only
/// lets the counts shrink. This file guards the things a count cannot see: that
/// the specific defects fixed here — a gradient card with white text on it, a
/// brightness-blind colour const, an alcohol glyph in a hydration cup picker —
/// do not come back wearing different numbers.
///
/// Contrast is asserted from the colours the widgets ACTUALLY PAINT, read back
/// off the rendered tree, rather than from the tokens the code was written
/// against. A test that re-reads `ext.fillBg(ext.reminders)` and compares it to
/// `ext.fillFg(ext.reminders)` proves the palette is self-consistent and proves
/// nothing about the card.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/screens/water_achievements_screen.dart';
import 'package:tablet_remainder/features/water/theme/aqua_theme.dart';

import '../support/emoji_chrome_scan.dart';

// ───────────────────────────── WCAG 2.1 ─────────────────────────────

double _channel(int v) {
  final c = v / 255.0;
  return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;
}

double _luminance(Color c) =>
    0.2126 * _channel((c.r * 255).round()) +
    0.7152 * _channel((c.g * 255).round()) +
    0.0722 * _channel((c.b * 255).round());

/// (L1 + 0.05) / (L2 + 0.05), lighter first.
double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

String _hex(Color c) =>
    '#${((c.a * 255).round() << 24 | (c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

// ───────────────────────────── sources ─────────────────────────────

String _read(String path) {
  final f = File(path);
  if (!f.existsSync()) {
    throw StateError('$path has moved — fix this test rather than deleting it.');
  }
  return f.readAsStringSync();
}

const _waterUi = <String>[
  'lib/features/water/screens/water_achievements_screen.dart',
  'lib/features/water/screens/water_statistics_screen.dart',
  'lib/features/water/screens/water_calendar_screen.dart',
  'lib/features/water/screens/hydration_profile_screen.dart',
];

/// Lines of [src] that are code rather than comment. Every rule below is about
/// what the file DOES; a comment recording what it used to do must not trip it,
/// and several of these files explain the defect they fixed.
Iterable<String> _codeLines(String src) => src
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // The harness cannot fetch Plus Jakarta / Inter, and a pending fetch makes
    // text measurement nondeterministic. Same pin the responsive sweep uses.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('DS-01 / DS-02 / DS-07 — no gradient cards', () {
    for (final path in _waterUi) {
      test('${path.split('/').last} paints no gradient', () {
        final offenders = _codeLines(_read(path))
            .where((l) =>
                l.contains('LinearGradient') ||
                l.contains('RadialGradient') ||
                l.contains('ShaderMask'))
            .toList();
        expect(offenders, isEmpty,
            reason: 'There are no gradients in this design system, and all '
                'three that were here carried white text at 1.53:1-1.94:1. A '
                'card that needs to be amber uses AppCard(color: '
                'ext.fillBg(ext.reminders)) with ext.fillFg on top.\n'
                '${offenders.join('\n')}');
      });
    }
  });

  group('DS-19 — AquaTheme exports nothing that ignores the brightness', () {
    late String src;
    setUp(() => src = _read('lib/features/water/theme/aqua_theme.dart'));

    test('the light-only text constants are gone', () {
      for (final decl in const [
        'Color textPrimary',
        'Color textSecondary',
        'Color textTertiary',
        'Color textOnDark',
        'Color textOnPrimary',
      ]) {
        expect(src.contains(decl), isFalse,
            reason: '`$decl` is a const, so it cannot know the brightness. '
                'This is the exact shape of the deleted AppColors consts that '
                'produced 1.05:1 white-on-white in dark mode. Read colour from '
                'AppColorsExt.of(context).');
      }
    });

    test('the second type scale is gone', () {
      expect(RegExp(r'TextStyle\s+get\s+\w+').hasMatch(src), isFalse,
          reason: 'AquaTheme used to export eleven TextStyle getters, off the '
              'app scale at four steps and each baking a LIGHT text colour '
              'into a const. Type comes from Theme.of(context).textTheme.');
    });

    test('the radius and spacing aliases resolve to the token scale', () {
      // Named aliases are fine; hardcoded values behind them are not, because
      // that is how a second scale grows back.
      expect(src.contains('static const double radiusSmall = AppRadius.sm'), isTrue);
      expect(src.contains('static const double radiusMedium = AppRadius.lg'), isTrue);
      expect(src.contains('static const double radiusLarge = AppRadius.sheet'), isTrue);
      expect(src.contains('static const double radiusFull = AppRadius.full'), isTrue);
      // Mapped BY VALUE: this scale's M is 16, which is AppSpacing.lg, not md.
      expect(src.contains('static const double spacingM = AppSpacing.lg'), isTrue);
    });
  });

  group('DS-17 — beverage glyphs and the cup picker', () {
    test('every catalog beverage resolves to a Material Symbol', () {
      for (final b in BeverageType.defaultBeverages) {
        expect(AquaTheme.iconFor(b.id), isA<IconData>(), reason: b.id);
      }
      // Spot-check that the map is keyed, not just defaulting to water.
      expect(AquaTheme.iconFor('coffee'), isNot(AquaTheme.iconFor('water')));
      expect(AquaTheme.iconFor('beer'), isNot(AquaTheme.iconFor('water')));
      expect(AquaTheme.iconFor('wine'), AquaTheme.iconFor('cocktail'));
      expect(AquaTheme.iconFor('espresso'), AquaTheme.iconFor('coffee'));
    });

    test('the cup picker offers no alcohol and no non-vessels', () {
      final src = _read('lib/features/water/screens/custom_cup_creator_screen.dart');
      final options = RegExp(r'_emojiOptions = \[(.*?)\];', dotAll: true)
          .firstMatch(src)
          ?.group(1);
      expect(options, isNotNull, reason: '_emojiOptions has been renamed.');
      for (final banned in const ['🍺', '🍷', '🥃', '🍹']) {
        expect(options!.contains(banned), isFalse,
            reason: 'A hydration tracker whose own model scores alcohol at a '
                'NEGATIVE hydration factor should not offer four ways to label '
                'your everyday cup as a drink. Alcohol stays loggable as a '
                'beverage; it does not get a slot in this picker.');
      }
      for (final banned in const ['🧴', '🏃', '🥝']) {
        expect(options!.contains(banned), isFalse,
            reason: 'A lotion bottle, a runner and a kiwi fruit are not cups.');
      }
      // The picker still has to be usable.
      expect(options!.contains('🥛'), isTrue);
      expect(options.contains('☕'), isTrue);
    });

    test('no emoji is rendered as chrome anywhere in the water feature', () {
      // Same scan the Focus guard runs (`test/support/emoji_chrome_scan.dart`),
      // with a STRICTER policy. Focus has to tolerate a large emoji because the
      // plant glyph is the garden metaphor, so it only bans badge-sized ones.
      // Water has no such content: the beverage glyphs went to
      // `AquaTheme.iconFor`, and the only emoji that legitimately survive are
      // the cup glyph the user picked in the creator and an insight's authored
      // emoji — every one of which already carries the inline annotation.
      //
      // The font-size floor Focus uses would be useless here: these are written
      // with theme text styles (`textTheme.displaySmall`), never a raw
      // `fontSize:`, so a size heuristic matches none of them and would let a
      // 36pt 🍺 straight back into the quick-add grid.
      //
      // `includeFieldReads` is the half that makes this guard able to fail at
      // all. The defect DS-17 names was never a literal: the quick-add tile
      // rendered `Text(beverage.emoji)` and the timeline `Text(log.beverageEmoji)`
      // — the glyph came from the model. A literal-only scan passes with that
      // code restored verbatim, which is exactly what it did when this test was
      // first written.
      final hits =
          unannotatedEmojiTextLines('lib/features/water', includeFieldReads: true);
      expect(hits, isEmpty,
          reason: 'an emoji in a Text() is a glyph from the system font: it '
              'will not take the accent colour, will not scale with the icon '
              'size the rest of the app uses, and renders differently on every '
              'OS version. Use `AquaTheme.iconFor`, or annotate '
              '`// $kEmojiContentOptOut <reason>` inline if it is genuinely '
              'content:\n${hits.join('\n')}');
    });
  });

  group('a foreground on a beverage fill is measured, never assumed', () {
    test('onBeverage clears 4:1 against every beverage in the catalog', () {
      final worst = <String, double>{};
      for (final b in BeverageType.defaultBeverages) {
        final fill = AquaTheme.themeFromBeverage(b).primary;
        final ratio = contrast(fill, AquaTheme.onBeverage(fill));
        worst[b.id] = ratio;
        expect(ratio, greaterThanOrEqualTo(4.0),
            reason: '${b.id} fill ${_hex(fill)} vs '
                '${_hex(AquaTheme.onBeverage(fill))} = '
                '${ratio.toStringAsFixed(2)}:1. Every one of these sites used '
                'a hardcoded Colors.white, which measures 1.04:1 on milk '
                '(#FAFAFA) and 1.14:1 on the energy-drink green.');
      }
      // Also true for the curated gradient palette, which is a different set.
      for (final t in AquaTheme.beverages.values) {
        expect(contrast(t.primary, AquaTheme.onBeverage(t.primary)),
            greaterThanOrEqualTo(4.0),
            reason: t.id);
      }
    });
  });

  group('DS-01 — the achievements stats card, as painted', () {
    /// The fill behind [text], read off the render tree: the nearest ancestor
    /// Container whose decoration actually declares a colour.
    Color fillBehind(WidgetTester tester, Finder text) {
      final containers = tester.widgetList<Container>(
          find.ancestor(of: text, matching: find.byType(Container)));
      for (final c in containers) {
        final d = c.decoration;
        if (d is BoxDecoration && d.color != null) return d.color!;
        if (c.color != null) return c.color!;
      }
      fail('No coloured ancestor container — the card lost its fill.');
    }

    // The themes are resolved INSIDE the test, not in the group body: building
    // one touches google_fonts, which reads the asset bundle, which needs a
    // binding that does not exist while the group is being declared.
    for (final brightness in const ['light', 'dark']) {
      testWidgets('values and labels clear AA in $brightness', (tester) async {
        final theme = brightness == 'light'
            ? AppTheme.lightTheme
            : AppTheme.darkTheme;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: const WaterAchievementsScreen(),
        ));
        await tester.pump(const Duration(milliseconds: 350));

        // 'Unlocked' is deliberately not in this list: it is also a tab label,
        // so the finder is ambiguous. These two are unique to the card.
        for (final label in const ['Total Points', 'Day Streak']) {
          final finder = find.text(label);
          expect(finder, findsOneWidget, reason: '$label is missing');
          final style = tester.widget<Text>(finder).style;
          expect(style?.color, isNotNull,
              reason: '$label has no explicit colour, so it inherits whatever '
                  'the ambient DefaultTextStyle is — which on a filled card is '
                  'the colour for the page background, not for the fill.');
          final fg = style!.color!;
          final bg = fillBehind(tester, finder);
          final ratio = contrast(fg, bg);
          expect(ratio, greaterThanOrEqualTo(4.5),
              reason: '"$label" ${_hex(fg)} on ${_hex(bg)} = '
                  '${ratio.toStringAsFixed(2)}:1 in $brightness. This card '
                  'shipped as white 11-18pt on an amber/orange gradient: '
                  '1.53:1 at the amber end, 1.94:1 at the orange, and the '
                  'labels carried a further 0.8 alpha on top of that.');
        }
      });
    }
  });
}

/// One back arrow, one implementation.
///
/// Before this, 41 screens hand-rolled the block and 6 used
/// `AppHeader.backButton`. An 87% duplication rate on the one thing that static
/// exists to absorb, and the drift was measurable:
///
///   * `filled` disagreed — six sites omitted it and so rendered a raised
///     `surface` circle with a shadow while the rest were flat.
///   * `accent` was omitted on seven, falling through to `AccentScope`, and the
///     two raw Material `IconButton`s ignored it entirely and rendered their
///     glyph at Material's 24 rather than the app's 22.
///   * `tooltip: 'Back'` was set on 8 of 41, so roughly 33 back buttons
///     announced to a screen reader as an unlabelled button.
///   * Three different pop semantics coexisted.
///
/// A source-grep guard, in the same idiom as
/// `test/health/no_generative_ai_guard_test.dart`, because the failure mode is
/// a new screen quietly copying the block again — which no runtime test can see.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Screens that legitimately do NOT use the static.
const _exempt = <String, String>{
  'app_header.dart': 'defines the static',
  // Material AppBar / SliverAppBar surfaces. `AppHeader.backButton` returns an
  // AppIconButton sized for AppHeader's row, and these bars position and size
  // their own leading slot. Unifying them is its own phase, and it has to
  // re-home AppBarTheme.systemOverlayStyle first — without which three water
  // screens paint white status-bar glyphs on a light scaffold.
  'early_access_screen.dart': 'Material AppBar',
  'water_achievements_screen.dart': 'SliverAppBar',
  'water_statistics_screen.dart': 'Material AppBar',
  'hydration_profile_screen.dart': 'Material AppBar',
  'water_calendar_screen.dart': 'Material AppBar',
  'aqua_water_dashboard.dart': 'SliverAppBar with a scroll-driven header',
  'app_allow_list_screen.dart': 'SliverAppBar',
  'custom_tags_screen.dart': 'SliverAppBar',
  'focus_garden_screen.dart': 'SliverAppBar',
  'plant_real_trees_screen.dart': 'SliverAppBar',
  'nunito_medication_detail_screen.dart': 'SliverAppBar',
  // Hand-rolled header rows that are not AppHeader at all — the Period
  // feature's own grammar, plus Relaxation's full-screen chrome.
  'period_dashboard.dart': 'hand-rolled header row',
  'period_calendar_screen.dart': 'hand-rolled header row',
  'cycle_history_screen.dart': 'hand-rolled header row',
  'relaxation_screen.dart': 'hand-rolled full-screen chrome',
  // Pops with a RESULT. The static pops without one, so folding this in would
  // silently drop the value the caller awaits.
  'water_history_edit_screen.dart': 'pops with a result',
  // Both are tab roots AND pushable, so the leading slot is conditional on
  // Navigator.canPop() — the static would render a button that does nothing.
  'sleep_dashboard_screen.dart': 'conditional leading',
  'steps_dashboard_screen.dart': 'conditional leading',
  'trends_dashboard_screen.dart': 'conditional leading (isRoot)',
};

void main() {
  test('no screen hand-rolls a header back button', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final name = entity.uri.pathSegments.last;
      if (_exempt.containsKey(name)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('arrow_back_rounded')) continue;
        // A back arrow is fine anywhere EXCEPT as a header's leading slot,
        // which is what the static owns. Look back a few lines for it.
        final window = lines
            .sublist((i - 4).clamp(0, i), i + 1)
            .join(' ');
        if (window.contains('leading:')) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'Use AppHeader.backButton(context). It carries the neutral '
            'chrome colour, the Back tooltip and the canPop guard, and it is '
            'the only place those can be changed once.\n'
            '${offenders.join('\n')}');
  });

  test('the static is actually adopted, not merely available', () {
    // A guard that only forbids the old shape would pass on a codebase with no
    // back buttons at all. This pins that the migration really happened.
    var uses = 0;
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      uses += RegExp('AppHeader.backButton')
          .allMatches(entity.readAsStringSync())
          .length;
    }
    expect(uses, greaterThanOrEqualTo(35),
        reason: 'only $uses call sites use the shared static; the migration '
            'covered 39');
  });
}

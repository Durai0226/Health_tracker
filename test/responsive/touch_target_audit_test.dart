@Tags(['responsive'])
library;

/// Measures the ACTUAL rendered size of every tappable widget on each screen
/// and reports those below the platform minimum.
///
/// Thresholds (see docs/ux-review.md for sources):
///   Apple HIG      : >= 44 x 44 pt
///   Material 3     : >= 48 x 48 dp
///   WCAG 2.2 (AA)  : >= 24 x 24 CSS px (2.5.8), with spacing exceptions
///
/// We report against 44pt, the stricter of the two platform rules that this
/// app actually ships on, and separately flag anything under the WCAG 24pt
/// floor as a hard failure rather than a style preference.
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/perf_rating.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/vitals_reminder_settings_screen.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/dev/qa_seed.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../support/fake_audio_engine.dart';

import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/screens/custom_tags_screen.dart';
import 'package:tablet_remainder/features/focus/screens/detailed_stats_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_garden_screen.dart';
import 'package:tablet_remainder/features/focus/screens/app_allow_list_screen.dart';
import 'package:tablet_remainder/features/focus/screens/plant_real_trees_screen.dart';
import 'package:tablet_remainder/features/focus/screens/relaxation_screen.dart';
import 'package:tablet_remainder/features/focus/screens/settings/focus_reminders_settings_screen.dart';
import 'package:tablet_remainder/features/biometrics/screens/connected_devices_screen.dart';
import 'package:tablet_remainder/features/medication/screens/conditions/condition_library_screen.dart';
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_dashboard.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/weight_screen.dart';
import 'package:tablet_remainder/features/period/screens/period_calendar_screen.dart';
import 'package:tablet_remainder/features/settings/screens/settings_screen.dart';
import 'package:tablet_remainder/features/settings/screens/vitavibe_settings_screen.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_dashboard_screen.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';
import 'package:tablet_remainder/features/water/screens/caffeine_insights_screen.dart';
import 'package:tablet_remainder/features/water/screens/water_calendar_screen.dart';

const double _appleMin = 44.0;
const double _wcagMin = 24.0;

final Map<String, Widget Function()> _screens = {
  // Registered here for the first time too. A screen that is almost entirely
  // switches is exactly what a tap-target audit is for.
  'vitals_reminders': () => const VitalsReminderSettingsScreen(),
  // Never registered before, on a screen that is almost entirely controls: a
  // switch per source, plus the row itself as a nav target.
  'connected_devices': () => const ConnectedDevicesScreen(),
  'condition_library': () => const ConditionLibraryScreen(),
  'home': () => HomeDashboard(onNavigate: (int i, {int? healthTab}) {}),
  'medicine': () => const NunitoMedicationDashboard(),
  'water_dashboard': () => const AquaWaterDashboard(),
  // All eight Focus surfaces. Only `focus` and `focus_tags` were registered
  // before, so six screens had never had a tap target measured — and an audit
  // that covers two of eight screens reports "none" for the other six in exactly
  // the same words it uses for a clean result.
  'focus': () => const FocusScreen(),
  'focus_tags': () => const CustomTagsScreen(),
  'focus_stats': () => const DetailedStatsScreen(),
  'focus_garden': () => const FocusGardenScreen(),
  'focus_apps': () => const AppAllowListScreen(),
  'plant_trees': () => const PlantRealTreesScreen(),
  'relaxation': () => const RelaxationScreen(),
  'focus_reminders': () => const FocusRemindersSettingsScreen(),
  'settings': () => const SettingsScreen(),
  'vitavibe': () => const VitaVibeSettingsScreen(),
  'sleep': () => const SleepDashboardScreen(),
  'caffeine': () => const CaffeineInsightsScreen(),
  'bp': () => const BloodPressureScreen(),
  'weight': () => const WeightScreen(),
  'period_calendar': () => const PeriodCalendarScreen(),
  'water_calendar': () => const WaterCalendarScreen(),
};

/// True when this widget can actually receive a tap.
///
/// `Switch`/`Checkbox`/`Radio` with a null `onChanged` are disabled, and a
/// disabled control is not a touch-target failure either.
bool _isInteractive(Widget w) {
  if (w is InkWell) {
    return w.onTap != null ||
        w.onDoubleTap != null ||
        w.onLongPress != null ||
        w.onTapDown != null;
  }
  if (w is GestureDetector) {
    return w.onTap != null ||
        w.onDoubleTap != null ||
        w.onLongPress != null ||
        w.onTapDown != null;
  }
  if (w is IconButton) return w.onPressed != null;
  if (w is Switch) return w.onChanged != null;
  if (w is Checkbox) return w.onChanged != null;
  if (w is Radio) return w.onChanged != null;
  return true;
}

/// The first text found inside [e], for identifying an offending target.
String? _labelUnder(Element e) {
  String? found;
  void visit(Element child) {
    if (found != null) return;
    final w = child.widget;
    if (w is Text && (w.data?.trim().isNotEmpty ?? false)) {
      found = w.data!.trim();
      return;
    }
    // Fall back to a Semantics label, then an icon codepoint. Icon-only
    // controls are exactly the ones most likely to be undersized, and
    // "GestureDetector 48x40" with no further information is a finding nobody
    // can act on.
    if (w is Semantics && (w.properties.label?.trim().isNotEmpty ?? false)) {
      found = w.properties.label!.trim();
      return;
    }
    if (w is Icon && w.icon != null) {
      found = 'icon:0x${w.icon!.codePoint.toRadixString(16)}';
      return;
    }
    child.visitChildren(visit);
  }
  e.visitChildren(visit);
  return found == null || found!.length <= 24 ? found : '${found!.substring(0, 24)}…';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  // screen -> "WidgetType WxH"
  /// Same instant the responsive sweep pins, for the same reason: the seed
  /// anchors its history to "now".
  final seedNow = DateTime(2026, 8, 12, 10, 30);

  final small = <String, List<String>>{};
  final belowWcag = <String, List<String>>{};
  /// Screens that threw while building, so their targets were never measured.
  final couldNotBuild = <String, String>{};
  var measured = 0;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    // The six Focus surfaces added to this audit reach the audio player and three
    // singletons that outlive a single test. Substituting a fake engine keeps the
    // audit off the platform, and resetting the singletons keeps a measurement
    // from depending on which screen was pumped before it.
    AudioService().engineForTesting = FakeAudioEngine();
    FocusService().resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();

    // SEEDED, and pinned. This audit ran against an empty database, so every
    // list rendered its empty state and every per-row control — the switch on a
    // connected source, the chevron on a medicine, the chip on a reminder — was
    // simply absent from the tree it measured. Seeding the sibling sweep found
    // 234 overflow combinations across eight screens that had been invisible
    // for the same reason.
    //
    // The clock is fixed for the same reason it is fixed there: the seed
    // anchors its history to "now", so an unpinned run measures a different
    // screen every day.
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await withClock(Clock.fixed(seedNow), () => seedQaData(force: true));
  });

  tearDown(() async {
    FocusService().resetForTesting();
    await db.close();
  });

  // Three text scales, not one.
  //
  // This audit ran at 1.0 only, which is the scale at which a control/label
  // mismatch is least likely to exist — a fixed-size control beside a label that
  // doubles is exactly the shape of the defect, and it is structurally invisible
  // at the default size. 2.0 is the app's clamp (`lib/main.dart:478`, citing
  // WCAG 1.4.4).
  const scales = <double>[1.0, 1.3, 2.0];

  // Expected in the 44pt (advisory) column, and not a defect:
  //
  //  * **`CupertinoSwitch` / `GestureDetector` at 59x39.** That is Cupertino's
  //    own size, and Apple ships it. `AppSwitch` pins its LAYOUT box to 60x48 so
  //    the Material swap was neutral, but a `SizedBox` does not extend a child's
  //    hit area and wrapping the switch in a second tap recogniser would put two
  //    of them in one gesture arena. The real target on these rows is the row:
  //    `SettingsTile` and `AppListTile` both toggle on row-tap and both carry
  //    `minHeight: 56`.
  //  * **`period_calendar` day cells at 41x41.** A 7-column month grid on a
  //    390pt screen cannot give each cell 44pt and still fit; 41 is what the
  //    grid allows and it clears the WCAG floor comfortably.

  for (final entry in _screens.entries) {
    for (final scale in scales) {
    testWidgets('${entry.key}: tap targets meet 44pt @${scale}x', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844); // a mainstream phone
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final prev = FlutterError.onError;
      FlutterError.onError = (_) {}; // overflow noise is covered elsewhere
      try {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              textScaler: TextScaler.linear(scale),
            ),
            child: entry.value(),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(seconds: 1));
      } catch (e) {
        FlutterError.onError = prev;
        // Recorded, not swallowed. This used to `return` silently, so a screen
        // that would not build was indistinguishable from a screen with no
        // undersized targets — and this audit's whole job is to say which screens
        // it measured. Nineteen screens build today, so nothing is currently being
        // hidden; the hole was latent, and latent is how the last three green
        // instruments in this repo started.
        //
        // Gated, not scored: `unrenderable` in `responsive_overflow` owns the
        // severity for a screen that throws, and pricing it here too would cost
        // two findings for one defect.
        couldNotBuild[entry.key] = '$e'.split('\n').first;
        return;
      }
      FlutterError.onError = prev;

      // Only leaf-most tappables: a nested InkWell inside a big row would
      // otherwise report the row's generous size and hide the real target.
      for (final type in <Type>[
        InkWell,
        GestureDetector,
        IconButton,
        // `Switch` alone stopped being enough the moment `AppSwitch` moved to
        // `CupertinoSwitch`: 47 rendered switches vanished from this audit's
        // view and it went on reporting the same green. Both are listed so the
        // list survives the next platform swap in either direction.
        Switch,
        CupertinoSwitch,
        Checkbox,
        Radio,
      ]) {
        for (final e in find.byType(type).evaluate()) {
          // Only things that actually RESPOND to a tap.
          //
          // `InkWell(onTap: null)` and `GestureDetector(onTap: null)` are inert
          // — they are in the tree for layout or decoration, and no user can
          // hit them. Counting them made the audit report display-only chips as
          // undersized touch targets: `AppChip` already applies
          // `minHeight: onTap != null ? 44 : 0` (primitives.dart), so the very
          // chips it correctly leaves at 32pt BECAUSE they are not tappable
          // were the ones being flagged.
          //
          // Four findings, two whole surfaces, all measuring the wrong thing.
          // An audit that reports non-targets as targets gets its real findings
          // ignored along with the noise.
          if (!_isInteractive(e.widget)) continue;
          final ro = e.renderObject;
          if (ro is! RenderBox || !ro.hasSize) continue;
          final s = ro.size;
          if (s.isEmpty) continue;
          measured++;
          final shortest = s.width < s.height ? s.width : s.height;
          // Label the target with the text inside it. "InkWell 101x32" is a
          // measurement nobody can act on; "InkWell 101x32 'Gentle'" is a
          // widget you can go and find. A report that cannot be acted on gets
          // read once and ignored.
          final label = _labelUnder(e);
          final desc = '$type ${s.width.toStringAsFixed(0)}'
              'x${s.height.toStringAsFixed(0)}'
              '${label == null ? '' : " '$label'"}'
              '${scale == 1.0 ? '' : ' @${scale}x'}';
          if (shortest < _wcagMin) {
            belowWcag.putIfAbsent(entry.key, () => []).add(desc);
          } else if (shortest < _appleMin) {
            small.putIfAbsent(entry.key, () => []).add(desc);
          }
        }
      }
      // Drain anything still armed before the tree goes away, or a screen with
      // a bounded platform probe fails as "a Timer is still pending after the
      // widget tree was disposed" — which says nothing about touch targets.
      // `screen_build_cost_test.dart` already does exactly this, for the same
      // reason and with the same 8s; this harness had no equivalent, so the
      // first registered screen holding a `.timeout()` would have taken it down.
      // Costs no real wall time: the clock here is fake.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 8));
    });
    }
  }

  tearDownAll(() {
    // ignore: avoid_print
    print('\n===== TOUCH TARGET AUDIT (390x844, 1.0x) =====');
    // ignore: avoid_print
    print('tappables measured: $measured');
    // ignore: avoid_print
    print('\n-- BELOW WCAG 2.2 MINIMUM (24pt) — hard failures --');
    if (belowWcag.isEmpty) {
      // ignore: avoid_print
      print('  none');
    } else {
      belowWcag.forEach((k, v) {
        final counts = <String, int>{};
        for (final x in v) {
          counts[x] = (counts[x] ?? 0) + 1;
        }
        // ignore: avoid_print
        print('  $k: ${counts.entries.map((e) => "${e.key} x${e.value}").join(", ")}');
      });
    }
    // ignore: avoid_print
    print('\n-- BELOW APPLE HIG 44pt (comfort) --');
    if (small.isEmpty) {
      // ignore: avoid_print
      print('  none');
    } else {
      final sorted = small.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
      for (final e in sorted) {
        final counts = <String, int>{};
        for (final x in e.value) {
          counts[x] = (counts[x] ?? 0) + 1;
        }
        // ignore: avoid_print
        print('  ${e.key} (${e.value.length}): '
            '${counts.entries.take(4).map((c) => "${c.key} x${c.value}").join(", ")}');
      }
    }
    // ignore: avoid_print
    print('\n-- COULD NOT BE BUILT (nothing measured) --');
    // ignore: avoid_print
    print(couldNotBuild.isEmpty
        ? '  none'
        : couldNotBuild.entries.map((e) => '  ${e.key}: ${e.value}').join('\n'));
    // ignore: avoid_print
    print('=============================================\n');

    // THE GATE. Like the overflow harness, this file had no `expect()` at all —
    // it printed a report and always passed. WCAG 2.2 SC 2.5.8 sets 24x24 CSS
    // px as a hard minimum, so anything below it is a conformance failure, not
    // a note. (The Apple 44pt list stays advisory: it is a comfort guideline,
    // and gating on it would fail the app today.)
    // Beacon first: these dimensions were measured, findings or not.
    // Without this a clean run and a run that never happened are the same
    // silence, and tool/rate.dart scores both as perfect.
    reportMeasured(const ['touch-target-wcag', 'touch-target-comfort'],
        samples: measured);

    for (final e in belowWcag.entries) {
      emitFinding(Finding(
          feature: e.key.split('/').first, screen: e.key,
          dimension: 'touch-target-wcag', sev: Sev.p0,
          detail: '${e.value.length} target(s): ${e.value.take(3).join('; ')}',
          source: 'WCAG 2.2 SC 2.5.8 — 24x24 CSS px minimum'));
    }
    for (final e in small.entries) {
      emitFinding(Finding(
          feature: e.key.split('/').first, screen: e.key,
          dimension: 'touch-target-comfort', sev: Sev.p2,
          detail: '${e.value.length} target(s): ${e.value.take(3).join('; ')}',
          source: 'Apple HIG 44pt — advisory, not conformance'));
    }

    expect(couldNotBuild, isEmpty,
        reason: 'these screens were never measured, so "none below the floor" '
            'above does not cover them:\n'
            '${couldNotBuild.entries.map((e) => '${e.key}: ${e.value}').join('\n')}');
    expect(belowWcag, isEmpty,
        reason: 'Tappable targets below the WCAG 2.2 SC 2.5.8 minimum of 24pt '
            '— see the BELOW WCAG section above.');
  });
}

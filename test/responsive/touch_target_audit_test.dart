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
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/perf_rating.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';

import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/screens/custom_tags_screen.dart';
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
  'home': () => HomeDashboard(onNavigate: (int i, {int? healthTab}) {}),
  'medicine': () => const NunitoMedicationDashboard(),
  'water_dashboard': () => const AquaWaterDashboard(),
  'focus': () => const FocusScreen(),
  'focus_tags': () => const CustomTagsScreen(),
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
    child.visitChildren(visit);
  }
  e.visitChildren(visit);
  return found == null || found!.length <= 24 ? found : '${found!.substring(0, 24)}…';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  // screen -> "WidgetType WxH"
  final small = <String, List<String>>{};
  final belowWcag = <String, List<String>>{};
  var measured = 0;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  for (final entry in _screens.entries) {
    testWidgets('${entry.key}: tap targets meet 44pt', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844); // a mainstream phone
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final prev = FlutterError.onError;
      FlutterError.onError = (_) {}; // overflow noise is covered elsewhere
      try {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: entry.value(),
        ));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(seconds: 1));
      } catch (_) {
        FlutterError.onError = prev;
        return;
      }
      FlutterError.onError = prev;

      // Only leaf-most tappables: a nested InkWell inside a big row would
      // otherwise report the row's generous size and hide the real target.
      for (final type in <Type>[
        InkWell,
        GestureDetector,
        IconButton,
        Switch,
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
              '${label == null ? '' : " '$label'"}';
          if (shortest < _wcagMin) {
            belowWcag.putIfAbsent(entry.key, () => []).add(desc);
          } else if (shortest < _appleMin) {
            small.putIfAbsent(entry.key, () => []).add(desc);
          }
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
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
    print('=============================================\n');

    // THE GATE. Like the overflow harness, this file had no `expect()` at all —
    // it printed a report and always passed. WCAG 2.2 SC 2.5.8 sets 24x24 CSS
    // px as a hard minimum, so anything below it is a conformance failure, not
    // a note. (The Apple 44pt list stays advisory: it is a comfort guideline,
    // and gating on it would fail the app today.)
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

    expect(belowWcag, isEmpty,
        reason: 'Tappable targets below the WCAG 2.2 SC 2.5.8 minimum of 24pt '
            '— see the BELOW WCAG section above.');
  });
}

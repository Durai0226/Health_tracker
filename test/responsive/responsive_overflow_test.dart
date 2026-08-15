@Tags(['responsive'])
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_header.dart';

import '../support/text_layout.dart';

import 'package:tablet_remainder/features/medication/screens/appointments/nunito_add_edit_appointment_screen.dart';
import 'package:tablet_remainder/features/medication/screens/doctors/nunito_add_edit_doctor_screen.dart';
import 'package:tablet_remainder/features/medication/screens/clinics/nunito_add_edit_clinic_screen.dart';
import 'package:tablet_remainder/features/medication/screens/dependents/add_edit_dependent_screen.dart';
import 'package:tablet_remainder/features/medication/screens/dependents/dependent_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_report_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_report_screen.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_add_medication_flow.dart';
import 'package:tablet_remainder/features/diary/screens/diary_entry_screen.dart';
import 'package:tablet_remainder/core/milestones/milestones_screen.dart';
import 'package:tablet_remainder/features/insights/screens/proactive_nudge.dart';
import 'package:tablet_remainder/features/settings/screens/notification_settings_screen.dart';
import 'package:tablet_remainder/features/water/screens/water_history_edit_screen.dart';
// --- screens under audit -----------------------------------------------------
import 'package:tablet_remainder/features/diary/screens/diary_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/screens/custom_tags_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_garden_screen.dart';
import 'package:tablet_remainder/features/focus/screens/app_allow_list_screen.dart';
import 'package:tablet_remainder/features/focus/screens/plant_real_trees_screen.dart';
import 'package:tablet_remainder/features/focus/screens/relaxation_screen.dart';
import 'package:tablet_remainder/features/focus/screens/detailed_stats_screen.dart';
import 'package:tablet_remainder/features/focus/screens/settings/focus_reminders_settings_screen.dart';
import 'package:tablet_remainder/features/home/screens/health_browse_screen.dart';
import 'package:tablet_remainder/features/insights/screens/weekly_recap_screen.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_dashboard.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/analytics/nunito_adherence_report_screen.dart';
import 'package:tablet_remainder/features/medication/screens/appointments/nunito_appointment_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/clinics/nunito_clinic_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/doctors/nunito_doctor_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/weight_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/mood_screen.dart';
import 'package:tablet_remainder/features/period/screens/period_calendar_screen.dart';
import 'package:tablet_remainder/features/period/screens/cycle_history_screen.dart';
import 'package:tablet_remainder/features/reminders/screens/reminders_screen.dart';
import 'package:tablet_remainder/features/settings/screens/settings_screen.dart';
import 'package:tablet_remainder/features/settings/screens/haptic_settings_screen.dart';
import 'package:tablet_remainder/features/settings/screens/vitavibe_settings_screen.dart';
import 'package:tablet_remainder/features/settings/screens/security_settings_screen.dart';
import 'package:tablet_remainder/features/settings/screens/early_access_screen.dart';
import 'package:tablet_remainder/features/settings/screens/reminders_hub_screen.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_dashboard_screen.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_history_screen.dart';
import 'package:tablet_remainder/features/steps/screens/steps_history_screen.dart';
import 'package:tablet_remainder/features/water/screens/caffeine_insights_screen.dart';
import 'package:tablet_remainder/features/water/screens/water_statistics_screen.dart';
import 'package:tablet_remainder/features/water/screens/water_calendar_screen.dart';
import 'package:tablet_remainder/features/water/screens/water_achievements_screen.dart';
import 'package:tablet_remainder/features/water/screens/hydration_profile_screen.dart';
import 'package:tablet_remainder/features/water/screens/custom_cup_creator_screen.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';
import 'package:tablet_remainder/features/steps/screens/steps_dashboard_screen.dart';
import 'package:tablet_remainder/features/period/screens/period_dashboard.dart';
import 'package:tablet_remainder/features/onboarding/screens/welcome_screen.dart';
import 'package:tablet_remainder/features/settings/screens/backup_screen.dart';
import 'package:tablet_remainder/features/reminders/screens/alarm_screen.dart';
import 'package:tablet_remainder/features/insights/screens/trends_dashboard_screen.dart';

/// Phone sizes this app must support, in LOGICAL pixels (portrait).
/// 320x568 is the floor (iPhone SE 1st gen / small Android); 428x926 the
/// ceiling among phones. If it holds at both ends it holds in between.
const _devices = <String, Size>{
  'sm-320x568': Size(320, 568), // iPhone SE 1 / small Android — the floor
  'sm-360x640': Size(360, 640), // most common budget Android
  'md-375x667': Size(375, 667), // iPhone SE 2/3
  'lg-428x926': Size(428, 926), // iPhone Pro Max
};

/// 1.0 = default. 1.3 = the ceiling `lib/main.dart` clamps Dynamic Type to,
/// so this is the largest text the app will ever actually render.
const _textScales = <double>[1.0, 1.3, 2.0];

typedef ScreenBuilder = Widget Function();

/// Every screen with a zero-argument constructor.
final Map<String, ScreenBuilder> _screens = {
  'diary': () => const DiaryScreen(),
  // Previously covered by NOTHING. Every add/edit form in medication, both
  // vitals report screens, the diary write path, milestones, and the nudge —
  // 17 user-reachable surfaces reported no findings simply because no harness
  // ever rendered them. The "zero-argument constructor" limit cited above is
  // not real: this map already passes arguments (see 'home' and 'alarm').
  'add_appointment': () => const NunitoAddEditAppointmentScreen(),
  'add_doctor': () => const NunitoAddEditDoctorScreen(),
  'add_clinic': () => const NunitoAddEditClinicScreen(),
  'add_dependent': () => const AddEditDependentScreen(),
  'dependent_list': () => const DependentListScreen(),
  'bp_report': () => const BloodPressureReportScreen(),
  'glucose_report': () => const BloodSugarReportScreen(),
  'diary_entry': () => const DiaryEntryScreen(),
  'milestones': () => MilestonesScreen(accentOf: (ext) => ext.sleep),
  'proactive_nudge': () => const ProactiveNudge(),
  'notif_settings': () => const NotificationSettingsScreen(),
  'water_history_edit': () => WaterHistoryEditScreen(date: DateTime.now()),
  // docs/ui-audit.md calls this screen "Worst. 5 overflow stripes" — and it
  // was absent from this registry entirely.
  'add_medicine': () => const NunitoAddMedicationFlow(debugInitialStep: 0),

  'focus': () => const FocusScreen(),
  'focus_tags': () => const CustomTagsScreen(),
  'focus_garden': () => const FocusGardenScreen(),
  'focus_apps': () => const AppAllowListScreen(),
  'plant_trees': () => const PlantRealTreesScreen(),
  'relaxation': () => const RelaxationScreen(),
  'focus_stats': () => const DetailedStatsScreen(),
  'focus_reminders': () => const FocusRemindersSettingsScreen(),
  'health_browse': () => const HealthBrowseScreen(),
  'weekly_recap': () => const WeeklyRecapScreen(),
  'medicine': () => const NunitoMedicationDashboard(),
  'med_list': () => const NunitoMedicationListScreen(),
  'adherence': () => const NunitoAdherenceReportScreen(),
  'appointments': () => const NunitoAppointmentListScreen(),
  'clinics': () => const NunitoClinicListScreen(),
  'doctors': () => const NunitoDoctorListScreen(),
  'bp': () => const BloodPressureScreen(),
  'glucose': () => const BloodSugarScreen(),
  'weight': () => const WeightScreen(),
  'mood': () => const MoodScreen(),
  'period_calendar': () => const PeriodCalendarScreen(),
  'cycle_history': () => const CycleHistoryScreen(),
  'reminders': () => const RemindersScreen(),
  'settings': () => const SettingsScreen(),
  'haptics': () => const HapticSettingsScreen(),
  'vitavibe': () => const VitaVibeSettingsScreen(),
  'security': () => const SecuritySettingsScreen(),
  'early_access': () => const EarlyAccessScreen(),
  'reminders_hub': () => const RemindersHubScreen(),
  'sleep': () => const SleepDashboardScreen(),
  'sleep_history': () => const SleepHistoryScreen(),
  'steps_history': () => const StepsHistoryScreen(),
  'caffeine': () => const CaffeineInsightsScreen(),
  'water_stats': () => const WaterStatisticsScreen(),
  'water_calendar': () => const WaterCalendarScreen(),
  'water_awards': () => const WaterAchievementsScreen(),
  'hydration_profile': () => const HydrationProfileScreen(),
  'custom_cup': () => const CustomCupCreatorScreen(),
  // Previously uncovered: main dashboards, onboarding, and the alarm screen
  // (whose label is user-typed, so its width is unbounded).
  'water_dashboard': () => const AquaWaterDashboard(),
  'home': () => HomeDashboard(onNavigate: (int i, {int? healthTab}) {}),
  'steps': () => const StepsDashboardScreen(),
  'period': () => const PeriodDashboard(),
  'welcome': () => const WelcomeScreen(),
  'backup': () => const BackupScreen(),
  'alarm': () => const AlarmScreen(payload: {'title': 'Metformin 500mg extended release', 'body': 'Time for your evening dose'}),
  'trends': () => const TrendsDashboardScreen(),
};

/// A failure we care about: RenderFlex/RenderBox overflow.
bool _isOverflow(Object e) {
  final s = e.toString();
  return s.contains('overflowed by') || s.contains('A RenderFlex overflowed');
}

/// Extract "overflowed by 24 pixels on the bottom" for a readable report.
String _overflowSummary(Object e) {
  final s = e.toString();
  final m = RegExp(r'overflowed by ([\d.]+) pixels').firstMatch(s);
  final dir = RegExp(r'pixels on the (bottom|right|left|top)').firstMatch(s);
  if (m == null) return s.split('\n').first;
  return '${dir?.group(1) ?? "?"} +${m.group(1)}px';
}

/// The widget chain that created the overflowing render object. This is what
/// turns "something overflowed by 44px" into a file you can actually open.
String _creatorChain(FlutterErrorDetails d) {
  final chain = <String>[];
  try {
    d.informationCollector?.call().forEach((node) {
    final t = node.toString();
    // DebugCreator renders as "The relevant error-causing widget was: Foo".
    for (final m
        in RegExp(r'([A-Z][A-Za-z0-9_]{2,})\b').allMatches(t).take(40)) {
      final w = m.group(1)!;
      if (w.startsWith('Render') || w == 'RenderFlex') continue;
        chain.add(w);
      }
    });
  } catch (_) {
    // Walking the element tree can throw if the error surfaced while the tree
    // was being torn down. The chain is a convenience; never let it break the
    // report.
    return '';
  }
  final seen = <String>{};
  final uniq = chain.where(seen.add).take(6).toList();
  return uniq.isEmpty ? '' : uniq.join(' > ');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  // screen -> list of "device @scale: detail"
  final overflows = <String, List<String>>{};
  final wraps = <String, List<String>>{};
  // A blank screen never overflows, so the overflow check alone would pass it.
  // Track text count per screen to catch "renders nothing" regressions.
  final blank = <String>[];
  // Non-overflow build failures. Previously these were swallowed, so a screen
  // that CRASHED reported as "rendered, no overflow" — a false pass. Some are
  // environment-only (Firebase isn't initialised under `flutter test`), so they
  // are reported separately rather than failing the run.
  final buildErrors = <String, String>{};
  final unrenderable = <String, String>{};
  var rendered = 0;

  setUpAll(() {
    // google_fonts resolves asynchronously. Left on, a borderline text
    // measurement depends on whether resolution happened to finish between
    // pumps, which made this harness nondeterministic — the same command
    // reported 18 overflowing screens on one run and 4 on the next. Pinning
    // it off forces the synchronous fallback every time, so a "clean" result
    // is trustworthy. The fallback metric is WIDER than the shipped fonts,
    // so this errs toward over-reporting rather than missing real overflows.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  for (final screenEntry in _screens.entries) {
    final name = screenEntry.key;

    testWidgets('$name fits every supported phone', (tester) async {
      for (final dev in _devices.entries) {
        for (final scale in _textScales) {
          final size = dev.value;
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = size;

          // Resolve each error to a STRING inside the callback. The creator
          // chain walks the element tree, so it must be read while the tree is
          // still live — doing it later (after the reset pump) throws
          // "Looking up a deactivated widget's ancestor is unsafe".
          final caught = <String>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (d) {
            if (!_isOverflow(d.exception)) {
              buildErrors.putIfAbsent(
                  name, () => d.exception.toString().split('\n').first);
              return;
            }
            final where = _creatorChain(d);
            caught.add('${_overflowSummary(d.exception)}'
                '${where.isEmpty ? '' : '   [$where]'}');
          };

          try {
            await tester.pumpWidget(
              MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  home: screenEntry.value(),
                ),
              ),
            );
            // Deliberately NOT pumpAndSettle: several screens run looping
            // shimmer/pulse animations that never settle.
            await tester.pump(const Duration(milliseconds: 50));
            await tester.pump(const Duration(milliseconds: 350));
            rendered++;
            final texts = tester
                .widgetList<Text>(find.byType(Text))
                .map((w) => w.data ?? '')
                .where((t) => t.trim().isNotEmpty)
                .length;
            if (texts == 0) blank.add('$name @ ${dev.key}');

            // Header chrome that WRAPPED.
            //
            // This harness was blind to the bug it existed to catch: a Text
            // that soft-wraps to three lines is, to Flutter, a perfectly legal
            // layout — nothing throws, so `_isOverflow` never saw it. Scoped to
            // AppHeader because header text is chrome, not content: a title or
            // a greeting that needs two lines is broken by definition.
            final wrapped =
                collectWrappedText(tester, find.byType(AppHeader));
            for (final w in wrapped) {
              wraps.putIfAbsent(name, () => []).add('${dev.key} @${scale}x  $w');
            }
          } catch (e) {
            unrenderable.putIfAbsent(name, () => e.toString().split('\n').first);
          } finally {
            FlutterError.onError = prevOnError;
          }

          // Drain anything the framework recorded too.
          Object? ex;
          while ((ex = tester.takeException()) != null) {
            if (_isOverflow(ex!)) caught.add(_overflowSummary(ex));
          }

          for (final line in caught) {
            overflows
                .putIfAbsent(name, () => [])
                .add('${dev.key} @${scale}x  $line');
          }

          // Some screens guard their init with `.timeout(6s)`, which leaves a
          // pending Timer that trips the teardown assertion. Advancing the
          // fake clock past it is instant (no real wall time) and lets those
          // timers fire so the harness reports overflows, not timer noise.
          await tester.pump(const Duration(seconds: 7));

          // Reset so the next combination starts clean.
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    });
  }

  tearDownAll(() {
    // ignore: avoid_print
    print('\n===== RESPONSIVE OVERFLOW REPORT =====');
    // ignore: avoid_print
    print('combinations rendered: $rendered');
    if (unrenderable.isNotEmpty) {
      // ignore: avoid_print
      print('\n-- could not construct headlessly (needs a device) --');
      unrenderable.forEach((k, v) {
        // ignore: avoid_print
        print('  $k: $v');
      });
    }
    if (buildErrors.isNotEmpty) {
      // ignore: avoid_print
      print('\n-- BUILD ERRORS (may be environment-only, e.g. Firebase) --');
      buildErrors.forEach((k, v) {
        // ignore: avoid_print
        print('  $k: $v');
      });
    }
    if (blank.isNotEmpty) {
      // ignore: avoid_print
      print('\n-- RENDERED BLANK (no text at all) --');
      for (final b in blank.toSet()) {
        // ignore: avoid_print
        print('  $b');
      }
    }
    if (overflows.isEmpty) {
      // ignore: avoid_print
      print('\nNO OVERFLOWS across all devices and text scales.');
    } else {
      // ignore: avoid_print
      print('\n-- OVERFLOWS (${overflows.length} screens) --');
      final sorted = overflows.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
      for (final e in sorted) {
        // ignore: avoid_print
        print('\n${e.key}  (${e.value.length})');
        for (final d in e.value.toSet()) {
          // ignore: avoid_print
          print('    $d');
        }
      }
    }
    if (wraps.isNotEmpty) {
      // ignore: avoid_print
      print('\n-- WRAPPED HEADER TEXT (${wraps.length} screens) --');
      final sorted = wraps.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
      for (final e in sorted) {
        // ignore: avoid_print
        print('\n${e.key}  (${e.value.length})');
        for (final d in e.value.toSet()) {
          // ignore: avoid_print
          print('    $d');
        }
      }
    }
    // ignore: avoid_print
    print('======================================\n');

    // THE GATE.
    //
    // Until now this file had no `expect()` at all — it accumulated results and
    // printed them, so it reported green on a genuine RenderFlex overflow just
    // as happily as on a clean run. It was a report generator wearing a test's
    // clothes, which is the real reason a broken header shipped past "564
    // combinations, NO OVERFLOWS". These three assertions are what make it a
    // test. Verify with a deliberate `SizedBox(width: 9999)` on any screen:
    // if that does not turn this file red, nothing here is protecting anything.
    expect(overflows, isEmpty,
        reason: 'Screens overflowed — see the OVERFLOWS section above.');
    expect(wraps, isEmpty,
        reason: 'Header text wrapped — see the WRAPPED HEADER TEXT section '
            'above. Header chrome must render on one line at every supported '
            'width and text scale.');
    expect(unrenderable, isEmpty,
        reason: 'Screens could not be constructed at all — see above.');
  });
}

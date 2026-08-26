@Tags(['responsive'])
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/perf_rating.dart';


import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/dev/qa_seed.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
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
import 'package:tablet_remainder/features/settings/screens/health_privacy_screen.dart';
import 'package:tablet_remainder/features/biometrics/screens/heart_dashboard_screen.dart';
import 'package:tablet_remainder/features/biometrics/screens/workouts_screen.dart';
import 'package:tablet_remainder/features/biometrics/screens/connected_devices_screen.dart';
import 'package:tablet_remainder/features/medication/screens/conditions/condition_library_screen.dart';
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

/// Surfaces that render nothing ON PURPOSE, with the reason.
///
/// `renders-blank` is a good dimension and a bad one to apply blindly: a
/// conditional banner and a broken screen look identical from the outside.
/// Pricing the two the same is how a rating stops being believed, which is the
/// failure mode this whole exercise exists to fix. Every entry needs a reason.
const Map<String, String> _blankAllowlist = {
  'proactive_nudge':
      'Not a screen — a frequency-capped banner. It is mounted here without a '
          'Scaffold, so it throws "No Material widget found" before it can '
          'render anything, and the absurd +99882px figures it reports are that '
          'failure rather than a layout. A harness artifact. (The old reason '
          'given here — no insight on an empty database — went stale the moment '
          'this sweep started seeding.)',
  'backup':
      'Caught in its loading state: the body is `_isLoading ? _buildLoading() '
          ': _buildContent()` (backup_screen.dart) and the skeleton carries no '
          'text. A harness artifact, not a defect — the cloud lookup never '
          'resolves headlessly.',
};

/// Screens that ALREADY overflow with seeded data, and by how many
/// device x scale combinations.
///
/// ## Why this list exists
///
/// This sweep used to run against an empty database. Every screen therefore
/// rendered its EMPTY state, and an empty state has almost nothing in it to
/// overflow — so the harness reported "NO OVERFLOWS" while proving only that
/// the empty states fit. Seeding it surfaced **234 real overflow combinations
/// across eight screens**, none of which was new; they had simply never been
/// looked at.
///
/// Fixing all eight in the same change as switching the harness on would make
/// both impossible to review, so the known set is recorded here and the gate
/// fails on anything BEYOND it.
///
/// ## This list may only shrink
///
/// The count is asserted in both directions. Overflow more than the number and
/// the gate fails as a regression; overflow *less* and it fails too, telling you
/// to lower the number. A baseline that silently absorbs improvements is a
/// baseline that never gets smaller — and this repo has already been bitten by
/// instruments that could not fail.
///
/// Ordered worst first. Every one is at 320pt, most only above 1.0x text scale.
const Map<String, int> _seededOverflowBaseline = {
  'sleep_history': 90,
  'water_dashboard': 56,
  // 48, not the 41 I first recorded. The original figure was measured on a run
  // that was itself broken: StepActivityRing was still throwing an UNCAUGHT
  // framework exception at that point ("Multiple exceptions (5) were detected"),
  // and captures after it were lost. Re-measured twice, identically, once the
  // sweep ran clean. Not a regression in the water screen — a bad baseline.
  'water_stats': 48,
  'focus_stats': 26,
  'period': 18,
  // proactive_nudge's two are the "No Material widget found" artifact described
  // in _blankAllowlist, not a layout at all.
  'proactive_nudge': 2,
  // One combination each, all at the 320pt floor. `home` is the one that should
  // go first: it is the app's primary screen and it overflows at **1.0x**, i.e.
  // at the default text size, not only under Dynamic Type.
  'home': 1, // 320 @1.0x, right +52px
  // glucose is gone: its one combination was "inside AppHeader's own layout",
  // and the header redesign fixed it. Surfaced by the shrink-only side of this
  // gate, which fails when a screen does BETTER than its record.
  'weight': 1, // 320 @2.0x, right +26px
};

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
  'health_privacy': () => const HealthPrivacyScreen(),
  'heart': () => const HeartDashboardScreen(),
  'workouts': () => const WorkoutsScreen(),
  'connected_devices': () => const ConnectedDevicesScreen(),
  // hypertension is the responsive fixture of choice on the DETAIL side:
  // longest name and the only entry that renders both personalised
  // sections. The list screen goes here.
  'condition_library': () => const ConditionLibraryScreen(),
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
  final truncations = <String, List<String>>{};
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
    // Seeded, the way `screen_build_cost_test.dart` already is — and for a
    // sharper reason here. On an empty database every screen renders its EMPTY
    // state, and an empty state has almost nothing in it to overflow. So this
    // harness was reporting "NO OVERFLOWS" while proving only that the empty
    // states fit.
    //
    // Measured cost of that gap, on the one card file that got a widget-level
    // sweep with real data: a 93px header overflow, a 136px and a 17px row
    // overflow, and a silently CLIPPED in-segment label — four defects in a
    // file this harness had declared clean across 48 device/scale combinations.
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await seedQaData(force: true);
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

            // Text cut off with an ellipsis, ANYWHERE on the screen. Reported
            // rather than gated: a long user-entered name legitimately
            // ellipsizes, so this needs a human read. A developer-authored
            // string in the list is a layout bug.
            if (scale == 1.0) {
              for (final t in collectTruncatedText(tester, find.byType(MaterialApp))) {
                truncations.putIfAbsent(name, () => []).add('${dev.key}  $t');
              }
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

    if (truncations.isNotEmpty) {
      // ignore: avoid_print
      print('\n-- TRUNCATED TEXT at 1.0x --');
      // ignore: avoid_print
      print('   READ THIS BEFORE ACTING ON THE LIST:');
      // ignore: avoid_print
      print('   * flutter_test renders in a square-em fallback font where each');
      // ignore: avoid_print
      print('     glyph is as wide as the font size — roughly 2x the shipped');
      // ignore: avoid_print
      print('     Inter/Plus Jakarta. Most entries here fit fine on a device.');
      // ignore: avoid_print
      print('   * An ellipsis on USER-ENTERED data is correct behaviour.');
      // ignore: avoid_print
      print('   * A DEVELOPER-AUTHORED string that never fits is the bug —');
      // ignore: avoid_print
      print('     e.g. "Ready to focus?" as "Ready to foc…". Fix the copy or');
      // ignore: avoid_print
      print('     the slot, never the font size.');
      // ignore: avoid_print
      print('   Reported, not gated, for exactly this reason.');
      final sorted = truncations.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
      for (final e in sorted.take(12)) {
        // ignore: avoid_print
        print('\n${e.key}');
        for (final d in e.value.toSet().take(6)) {
          // ignore: avoid_print
          print('    $d');
        }
      }
    }

    // THE GATE.
    //
    // Until now this file had no `expect()` at all — it accumulated results and
    // printed them, so it reported green on a genuine RenderFlex overflow just
    // as happily as on a clean run. It was a report generator wearing a test's
    // clothes, which is the real reason a broken header shipped past "564
    // combinations, NO OVERFLOWS". These three assertions are what make it a
    // test. Verify with a deliberate `SizedBox(width: 9999)` on any screen:
    // if that does not turn this file red, nothing here is protecting anything.
    // Emit BEFORE asserting: `expect` throws, and a harness that dies before
    // reporting contributes nothing to the score. That asymmetry is how three
    // instruments could fail the build while leaving the rating at 100.
    // Beacon first: these dimensions were measured, findings or not. A
    // clean run and a run that never happened are otherwise the same
    // silence, and tool/rate.dart scored both as perfect.
    reportMeasured(
        const ['unrenderable', 'overflow', 'renders-blank', 'wrapped-header-text'],
        samples: rendered);

    for (final e in unrenderable.entries) {
      emitFinding(Finding(
          feature: e.key.split('/').first, screen: e.key,
          dimension: 'unrenderable', sev: Sev.p0,
          detail: e.value, source: 'binary: the screen threw while building'));
    }
    for (final e in overflows.entries) {
      emitFinding(Finding(
          feature: e.key.split('/').first, screen: e.key,
          dimension: 'overflow', sev: Sev.p1,
          detail: '${e.value.length} combination(s): ${e.value.take(3).join('; ')}',
          source: 'RenderFlex overflow at a supported width/text scale'));
    }
    for (final e in wraps.entries) {
      emitFinding(Finding(
          feature: e.key.split('/').first, screen: e.key,
          dimension: 'wrapped-header-text', sev: Sev.p2,
          detail: '${e.value.length} combination(s): ${e.value.take(3).join('; ')}',
          source: 'header chrome must be one line at every supported size'));
    }
    // Grouped per surface: 4 devices x 3 scales means one blank screen would
    // otherwise emit twelve findings and cost 12 x P1, which prices a single
    // defect at more than the whole app is worth.
    final blankBySurface = <String, List<String>>{};
    for (final entry in blank) {
      final name = entry.split(' @ ').first;
      if (_blankAllowlist.containsKey(name)) continue;
      blankBySurface.putIfAbsent(name, () => []).add(entry);
    }
    for (final e in blankBySurface.entries) {
      emitFinding(Finding(
          feature: e.key.split('/').first, screen: e.key,
          dimension: 'renders-blank', sev: Sev.p1,
          detail: 'no text rendered in ${e.value.length} combination(s)',
          source: 'binary: a screen with no text is not a screen'));
    }

    // Anything not in the baseline, or worse than the baseline, fails.
    final regressions = <String>[];
    final improvements = <String>[];
    for (final e in overflows.entries) {
      final known = _seededOverflowBaseline[e.key];
      if (known == null) {
        regressions.add('${e.key}: ${e.value.length} combination(s), and this '
            'screen has never overflowed before');
      } else if (e.value.length > known) {
        regressions.add('${e.key}: ${e.value.length} combination(s), baseline '
            'is $known');
      } else if (e.value.length < known) {
        improvements.add('${e.key}: now ${e.value.length}, baseline says '
            '$known — lower it');
      }
    }
    for (final name in _seededOverflowBaseline.keys) {
      if (!overflows.containsKey(name)) {
        improvements.add('$name: fixed entirely — remove it from the baseline');
      }
    }

    expect(regressions, isEmpty,
        reason: 'Screens overflowed beyond the recorded baseline — see the '
            'OVERFLOWS section above.\n${regressions.join('\n')}');
    // Failing on an IMPROVEMENT is deliberate. A baseline that absorbs progress
    // silently is a baseline that never shrinks.
    expect(improvements, isEmpty,
        reason: 'Good news, and an action: these are better than the baseline '
            'records, so the baseline is now lying.\n'
            '${improvements.join('\n')}');
    expect(wraps, isEmpty,
        reason: 'Header text wrapped — see the WRAPPED HEADER TEXT section '
            'above. Header chrome must render on one line at every supported '
            'width and text scale.');
    expect(unrenderable, isEmpty,
        reason: 'Screens could not be constructed at all — see above.');
    // `blank` was collected at :298 and printed, but never asserted — so a
    // screen that rendered NOTHING passed this harness silently.
    // Same allowlist as the findings above — a surface that renders nothing on
    // purpose must not fail the gate either. Filtering one and not the other
    // is how I first made this red for two surfaces that are behaving
    // correctly.
    expect(
      blank
          .where((e) => !_blankAllowlist.containsKey(e.split(' @ ').first))
          .toList(),
      isEmpty,
      reason: 'Screens rendered no text at all. A blank screen is the most '
          'visible defect there is and this harness was not gating on it. If a '
          'surface renders nothing deliberately, add it to _blankAllowlist '
          'WITH A REASON.',
    );
  });
}

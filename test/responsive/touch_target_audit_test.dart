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
/// Both columns are gated, by different rules. Anything under the WCAG 24pt
/// floor fails outright — that is a conformance defect, not a style
/// preference. The 44pt Apple column is held at a shrink-only baseline
/// ([_comfortBaseline]), because the app does not clear 44 everywhere today
/// and a column that is only ever printed is a column nobody has to keep true.
///
/// A third thing is gated, and it is the one that makes the other two mean
/// anything: a screen that FAILED TO RENDER. Both "clean" and "never built"
/// used to print the same "none". See [_canaryKey].
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
import '../support/overflow_errors.dart';
import '../support/screen_fixtures.dart';
import 'package:tablet_remainder/core/milestones/milestones_screen.dart';
import 'package:tablet_remainder/features/backup/presentation/screens/backup_settings_screen.dart';
import 'package:tablet_remainder/features/biometrics/screens/health_source_detail_screen.dart';
import 'package:tablet_remainder/features/biometrics/screens/heart_dashboard_screen.dart';
import 'package:tablet_remainder/features/biometrics/screens/workouts_screen.dart';
import 'package:tablet_remainder/features/diary/screens/diary_entry_screen.dart';
import 'package:tablet_remainder/features/diary/screens/diary_screen.dart';
import 'package:tablet_remainder/features/home/screens/health_browse_screen.dart';
import 'package:tablet_remainder/features/insights/screens/trends_dashboard_screen.dart';
import 'package:tablet_remainder/features/insights/screens/weekly_recap_screen.dart';
import 'package:tablet_remainder/features/medication/data/condition_library_data.dart';
import 'package:tablet_remainder/features/medication/screens/analytics/nunito_adherence_report_screen.dart';
import 'package:tablet_remainder/features/medication/screens/appointments/nunito_add_edit_appointment_screen.dart';
import 'package:tablet_remainder/features/medication/screens/appointments/nunito_appointment_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/clinics/nunito_add_edit_clinic_screen.dart';
import 'package:tablet_remainder/features/medication/screens/clinics/nunito_clinic_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/conditions/condition_detail_screen.dart';
import 'package:tablet_remainder/features/medication/screens/dependents/add_edit_dependent_screen.dart';
import 'package:tablet_remainder/features/medication/screens/dependents/dependent_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/doctors/nunito_add_edit_doctor_screen.dart';
import 'package:tablet_remainder/features/medication/screens/doctors/nunito_doctor_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_detail_screen.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/refill_overview_screen.dart';
import 'package:tablet_remainder/features/onboarding/screens/welcome_screen.dart';
import 'package:tablet_remainder/features/period/screens/cycle_history_screen.dart';
import 'package:tablet_remainder/features/period/screens/period_dashboard.dart';
import 'package:tablet_remainder/features/period/screens/period_reminder_settings_screen.dart';
import 'package:tablet_remainder/features/reminders/screens/add_reminder_screen.dart';
import 'package:tablet_remainder/features/reminders/screens/alarm_screen.dart';
import 'package:tablet_remainder/features/reminders/screens/category_management_screen.dart';
import 'package:tablet_remainder/features/reminders/screens/reminders_screen.dart';
import 'package:tablet_remainder/features/settings/screens/backup_screen.dart';
import 'package:tablet_remainder/features/settings/screens/early_access_screen.dart';
import 'package:tablet_remainder/features/settings/screens/haptic_settings_screen.dart';
import 'package:tablet_remainder/features/settings/screens/health_privacy_screen.dart';
import 'package:tablet_remainder/features/settings/screens/notification_settings_screen.dart';
import 'package:tablet_remainder/features/settings/screens/pin_entry_screen.dart';
import 'package:tablet_remainder/features/settings/screens/reminders_hub_screen.dart';
import 'package:tablet_remainder/features/settings/screens/security_settings_screen.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_history_screen.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_schedule_settings_screen.dart';
import 'package:tablet_remainder/features/steps/screens/steps_dashboard_screen.dart';
import 'package:tablet_remainder/features/steps/screens/steps_goal_settings_screen.dart';
import 'package:tablet_remainder/features/steps/screens/steps_history_screen.dart';
import 'package:tablet_remainder/features/water/screens/custom_cup_creator_screen.dart';
import 'package:tablet_remainder/features/water/screens/hydration_profile_screen.dart';
import 'package:tablet_remainder/features/water/screens/water_achievements_screen.dart';
import 'package:tablet_remainder/features/water/screens/water_history_edit_screen.dart';
import 'package:tablet_remainder/features/water/screens/water_reminder_settings_screen.dart';
import 'package:tablet_remainder/features/water/screens/water_statistics_screen.dart';

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
import 'package:tablet_remainder/features/medication/screens/nunito_add_medication_flow.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_report_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_report_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/mood_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/weight_screen.dart';
import 'package:tablet_remainder/features/period/screens/period_calendar_screen.dart';
import 'package:tablet_remainder/features/settings/screens/settings_screen.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_dashboard_screen.dart';
import 'package:tablet_remainder/features/water/screens/aqua_water_dashboard.dart';
import 'package:tablet_remainder/features/water/screens/caffeine_insights_screen.dart';
import 'package:tablet_remainder/features/water/screens/water_calendar_screen.dart';

/// The instant both responsive harnesses pin, for the same reason: `qa_seed`
/// anchors its history to "now", so an unpinned run measures a different screen
/// every day and the shrink-only baselines below drift on their own.
///
/// Top level rather than local to `main`, because the registry is a top-level
/// `final` and three of its entries take this date as a constructor argument —
/// `withClock` redirects `clock.now()` and cannot reach a literal.
final DateTime _seedNow = DateTime(2026, 8, 12, 10, 30);

const double _appleMin = 44.0;
const double _wcagMin = 24.0;

/// The audit's own instrument check.
///
/// A widget whose `build` throws does NOT propagate out of `pumpWidget`: the
/// framework reports it through `FlutterError.onError`, leaves an `ErrorWidget`
/// in its place and carries on. This harness used to install
/// `FlutterError.onError = (_) {}`, so such a screen was measured as zero
/// tappables and scored exactly like a screen with nothing undersized on it.
/// The `catch` below never saw it, because nothing was thrown at it.
///
/// Registering a screen that is GUARANTEED to fail that way, and asserting it
/// is recorded, is what keeps the discrimination honest. A report that cannot
/// tell "measured, clean" from "never rendered" is the failure mode this whole
/// file exists to avoid, and the only way to know it still can is to hand it
/// one of each on every run.
const String _canaryKey = '__selfcheck_throws_in_build';

class _ThrowsInBuild extends StatelessWidget {
  const _ThrowsInBuild();

  @override
  Widget build(BuildContext context) =>
      throw StateError('touch-target audit self-check');
}

/// Tappables under the 44pt Apple comfort minimum, per screen — a ratchet, not
/// a target of zero.
///
/// This column was PRINTED AND NEVER ASSERTED. The header above claimed the
/// audit reported against 44pt, the report named five screens, and the run was
/// green — so the number could grow forever without anything failing. That is
/// the same hole the WCAG `isEmpty` gate below was added to close, left open in
/// the column with all the findings in it.
///
/// It is a baseline rather than `isEmpty` because the two biggest entries are
/// not defects and would have had to be waived one by one anyway:
///
///  * **59x39 `CupertinoSwitch`.** Cupertino's own size, shipped by Apple.
///    `AppSwitch` pins its LAYOUT box to 60x48, but a `SizedBox` does not
///    extend a child's hit area, and wrapping the switch in a second recogniser
///    would put two of them in one gesture arena. The row is the real target:
///    `SettingsTile` and `AppListTile` both toggle on row-tap at
///    `minHeight: 56`. One switch scores NINE — the `CupertinoSwitch` plus the
///    two `GestureDetector`s inside it, at each of the three text scales — so
///    most of these counts are a switch count in disguise: five switches on
///    `vitals_reminders`, two on `focus_reminders`, one each on
///    `connected_devices` and add-medicine steps 2, 3 and 5. Nine is not a
///    switch signature on its own — `add_medicine_4`'s nine are chips — so read
///    the per-entry comment rather than the arithmetic.
/// The `period_calendar` day cells used to be the other one, at 41x41, waived
/// on the reasoning that seven columns on a 390pt screen cannot each be 44pt
/// wide. Only the 20pt card padding and the 4pt grid spacing made that true:
/// moving the gap inside the cell and narrowing the card leaves 48.9pt of
/// pitch, and the row height carries the floor on the phones too narrow for
/// the width to. The entry is gone rather than lowered (PV-15).
///
/// What is left is real, and small enough to act on: the reminder-window
/// caption on step 3 of the add-medicine flow (346x32 at 1.0x — a 15pt icon and
/// a caption with no minimum height), the nine pill-shape chips on step 4 (42pt,
/// two short), and Home's dose-summary row (32pt, 42pt at 1.3x).
///
/// Shrink-only in both directions, like `_rowCutBaseline` and
/// `_seededOverflowBaseline` in `responsive_overflow_test.dart`: more than the
/// number fails as a regression, fewer fails too and says to lower it, so the
/// baseline can absorb neither a new undersized control nor a fix. Like those
/// two it assumes the whole file ran — under a name filter the screens that
/// were never pumped all read as "fixed entirely".
final Map<String, int> _comfortBaseline = {
  'vitals_reminders': 45, // 5 switches
  'focus_reminders': 18, // 2 switches
  // 1 switch, plus the one real finding on this STEP: the reminder-window
  // caption row, 346x32 at 1.0x. Step 4 has real ones of its own.
  'add_medicine_3': 10,
  'connected_devices': 9, // 1 switch
  'add_medicine_2': 9, // 1 switch
  // NOT a switch: nine shape chips ('Round', 'Oval', 'Capsule'...) at 42pt.
  // They clear 44 at 1.3x and above, so this is the 1.0x row only.
  'add_medicine_4': 9,
  'add_medicine_5': 9, // 1 switch
  // The dose-summary row — "N of 6 taken today · See all" — 32pt at 1.0x and
  // 42pt at 1.3x. Fine at 2.0x.
  'home': 2,

  // --- The fifty-four screens registered by TQ-05.
  //
  // These are not new defects. Every one was already on the screen; this is the
  // first run that laid the screen out. Read them with the 59x39 arithmetic
  // above: ONE `AppSwitch` scores nine (the `CupertinoSwitch` plus the two
  // `GestureDetector`s inside it, at each of the three scales), so a count
  // divisible by nine is a switch count in disguise and the row — 56pt, and
  // tappable — is the real target. Only two of the fourteen are anything else,
  // and both are named.
  //
  // 67: seven switches (63), plus the SEX CHIPS, which are a real finding —
  // "Male" 84x32 and "Female" 111x32 at 1.0x, 100x37 and 134x37 at 1.3x. They
  // clear 44 at 2.0x, so this is a chip with no minimum height rather than a
  // clipped one.
  'hydration_profile': 67,
  'add_clinic': 63, // seven switches, nothing else
  // Six switches at 1.0x and 1.3x, five at 2.0x — the sixth is outside the
  // built extent by then, which is why this is 51 and not 54.
  'notif_settings': 51,
  'early_access': 27, // three switches
  'period_reminders': 27, // three switches
  // 18, and the second real one: the "All / Unlocked / Locked" filter segments
  // at 130x43 — one point short, at every scale. Each segment is counted twice
  // (the `InkWell` and the `GestureDetector` inside it), so this is three
  // controls, not eighteen.
  'water_awards': 18,
  'sleep_schedule': 18, // two switches
  'health_source_detail': 18, // two switches
  'haptics': 9, // 1 switch
  'security': 9, // 1 switch
  'custom_cup': 9, // 1 switch
  'water_reminders': 9, // 1 switch
  'add_appointment': 6, // 1 switch, built at 1.0x and 1.3x only
  'steps_goal': 3, // 1 switch, built at 1.0x only
};

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
  'sleep': () => const SleepDashboardScreen(),
  'caffeine': () => const CaffeineInsightsScreen(),
  // The whole vitals folder, not two thirds of it. `bp` and `weight` were
  // registered and `mood`, `glucose` and both report screens were not — and a
  // rating-picker row and a unit toggle are precisely the controls this audit
  // exists to measure. Every zero-argument screen in
  // `features/medication/screens/vitals/` is now here; none had to be skipped.
  'bp': () => const BloodPressureScreen(),
  'bp_report': () => const BloodPressureReportScreen(),
  'glucose': () => const BloodSugarScreen(),
  'glucose_report': () => const BloodSugarReportScreen(),
  'mood': () => const MoodScreen(),
  'weight': () => const WeightScreen(),
  // Five entries for one screen, because `PageView` builds only the page it is
  // showing: registering the flow once measures step 1 and reports silence for
  // the dose stepper, the frequency chips and the time pickers on steps 2-5.
  // `docs/ui-audit.md` calls this the worst screen in the app and no tap-target
  // harness had ever rendered any of it.
  for (var step = 0; step < 5; step++)
    'add_medicine_${step + 1}': () =>
        NunitoAddMedicationFlow(debugInitialStep: step),
  'period_calendar': () => const PeriodCalendarScreen(),
  'water_calendar': () => const WaterCalendarScreen(),
  // ------------------------------------------------------------------
  // The fifty-four surfaces this audit had never laid a finger on (TQ-05).
  //
  // It registered 21 of the app's 75 full-page screens, and for the other 54 it
  // printed exactly what it prints for a clean one. The list below is the rest
  // of the population, keyed identically to `responsive_overflow_test` so a
  // finding can be read across both harnesses, and kept complete from here by
  // `screen_registration_guard_test.dart`.
  'diary': () => const DiaryScreen(),
  'diary_entry': () => const DiaryEntryScreen(),
  'add_appointment': () => const NunitoAddEditAppointmentScreen(),
  'add_doctor': () => const NunitoAddEditDoctorScreen(),
  'add_clinic': () => const NunitoAddEditClinicScreen(),
  'add_dependent': () => const AddEditDependentScreen(),
  'dependent_list': () => const DependentListScreen(),
  'milestones': () => MilestonesScreen(accentOf: (ext) => ext.sleep),
  'notif_settings': () => const NotificationSettingsScreen(),
  'health_browse': () => const HealthBrowseScreen(),
  'weekly_recap': () => const WeeklyRecapScreen(),
  'med_list': () => const NunitoMedicationListScreen(),
  'adherence': () => const NunitoAdherenceReportScreen(),
  'appointments': () => const NunitoAppointmentListScreen(),
  'clinics': () => const NunitoClinicListScreen(),
  'doctors': () => const NunitoDoctorListScreen(),
  'cycle_history': () => const CycleHistoryScreen(),
  'reminders': () => const RemindersScreen(),
  'reminders_hub': () => const RemindersHubScreen(),
  'haptics': () => const HapticSettingsScreen(),
  'security': () => const SecuritySettingsScreen(),
  'health_privacy': () => const HealthPrivacyScreen(),
  'early_access': () => const EarlyAccessScreen(),
  'heart': () => const HeartDashboardScreen(),
  'workouts': () => const WorkoutsScreen(),
  'sleep_history': () => const SleepHistoryScreen(),
  'steps': () => const StepsDashboardScreen(),
  'steps_history': () => const StepsHistoryScreen(),
  'period': () => const PeriodDashboard(),
  'water_stats': () => const WaterStatisticsScreen(),
  'water_awards': () => const WaterAchievementsScreen(),
  'hydration_profile': () => const HydrationProfileScreen(),
  'custom_cup': () => const CustomCupCreatorScreen(),
  'trends': () => const TrendsDashboardScreen(),
  'welcome': () => const WelcomeScreen(),
  'backup': () => const BackupScreen(),
  // `_seedNow`, not the wall clock — the day this screen edits is a constructor
  // argument, and `withClock` cannot reach a literal. See the same registration
  // in `responsive_overflow_test`, where an unpinned date measured an empty
  // list and called it clean.
  'water_history_edit': () => WaterHistoryEditScreen(date: _seedNow),
  // A user-typed medicine name, i.e. the unbounded label on this surface.
  'alarm': () => const AlarmScreen(payload: {
        'title': 'Metformin 500mg extended release',
        'body': 'Time for your evening dose',
      }),
  'add_reminder': () => const AddReminderScreen(),
  'backup_settings': () => const BackupSettingsScreen(),
  'reminder_categories': () => const CategoryManagementScreen(),
  'period_reminders': () => const PeriodReminderSettingsScreen(),
  'refill_overview': () => const RefillOverviewScreen(),
  'sleep_schedule': () => const SleepScheduleSettingsScreen(),
  'steps_goal': () => const StepsGoalSettingsScreen(),
  'water_reminders': () => const WaterReminderSettingsScreen(),
  // `autoPromptBiometrics: false`: the default raises the platform biometric
  // sheet on first build, and a tap-target audit has no business asking for a
  // fingerprint — nor can `flutter test` answer.
  'pin_entry': () => const PinEntryScreen(
        mode: PinEntryMode.setup,
        setupTitle: 'Change PIN',
        autoPromptBiometrics: false,
      ),
  'condition_detail': () => ConditionDetailScreen(
        condition: conditionLibrary.firstWhere((c) => c.id == 'hypertension'),
      ),
  'medicine_detail': () =>
      NunitoMedicationDetailScreen(medicine: seededMedicine(_seedNow)),
  'health_source_detail': () => HealthSourceDetailScreen(
        controller: seededSourceController(_seedNow),
        sourceId: kFixtureSourceId,
      ),
  // Last, and not a screen — see [_canaryKey].
  _canaryKey: () => const _ThrowsInBuild(),
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

  final small = <String, List<String>>{};
  final belowWcag = <String, List<String>>{};
  /// Screens whose constructor or first pump threw OUT of `pumpWidget`, so
  /// their targets were never measured.
  final couldNotBuild = <String, String>{};
  /// Screens that failed while BUILDING — reported through
  /// `FlutterError.onError` rather than thrown, so `pumpWidget` returned
  /// normally and [couldNotBuild] above never sees them. See [_canaryKey].
  final buildErrors = <String, String>{};
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
    await withClock(Clock.fixed(_seedNow), () => seedQaData(force: true));
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

  // Which 44pt sightings are expected and which are debt is recorded on
  // [_comfortBaseline], beside the numbers it gates.

  for (final entry in _screens.entries) {
    for (final scale in scales) {
    testWidgets('${entry.key}: tap targets meet 44pt @${scale}x', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844); // a mainstream phone
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final prev = FlutterError.onError;
      // Overflow noise is `responsive_overflow_test`'s finding, not this
      // harness's — silencing it here keeps one defect from being priced
      // twice. Everything ELSE is recorded: this used to be a blanket
      // `(_) {}`, and a widget whose `build` throws never reaches the `catch`
      // below (the framework reports it here and substitutes an ErrorWidget),
      // so such a screen was measured as zero tappables and printed the same
      // "none" a genuinely clean screen prints.
      FlutterError.onError = (d) {
        if (isOverflowError(d.exception)) return;
        buildErrors.putIfAbsent(
            entry.key, () => d.exception.toString().split('\n').first);
      };
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
        // it measured. This bucket is empty today: the one screen that cannot
        // render here (`backup`) fails through `FlutterError.onError` above, not
        // out of `pumpWidget`, so it lands in [buildErrors] instead. Deliberately
        // no screen count in this sentence — it said "nineteen" while the
        // registry held twenty-one, and then fifty-four more were registered
        // under it without anyone noticing the number had stopped being true.
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
    print('\n===== TOUCH TARGET AUDIT (390x844, 1.0/1.3/2.0x) =====');
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
    print('\n-- THREW WHILE BUILDING (ErrorWidget, nothing measured) --');
    // ignore: avoid_print
    print(buildErrors.isEmpty
        ? '  none'
        : buildErrors.entries.map((e) => '  ${e.key}: ${e.value}').join('\n'));
    // ignore: avoid_print
    print('=============================================\n');

    // THE GATE. Like the overflow harness, this file had no `expect()` at all —
    // it printed a report and always passed. WCAG 2.2 SC 2.5.8 sets 24x24 CSS
    // px as a hard minimum, so anything below it is a conformance failure, not
    // a note. The Apple 44pt column is gated too, against `_comfortBaseline`:
    // it cannot be `isEmpty` today, but it can be stopped from growing, and
    // that is the difference between a guideline and a report.
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

    // The instrument check, before anything it measured is trusted. The
    // canary's `build` throws unconditionally, so the ONLY way it is missing
    // here is that build failures are being swallowed again — which is
    // precisely the state in which every "none" printed above is worthless.
    // (Like the baselines below, this assumes the whole file ran: under a
    // `--plain-name` filter that excludes the canary it fails, and correctly
    // so, because a filtered run has not checked the instrument.)
    expect(buildErrors.containsKey(_canaryKey), isTrue,
        reason: 'the self-check screen throws in build and was NOT recorded, '
            'so this run could not tell a screen that failed to render from a '
            'screen with no undersized targets. Every "none" above is '
            'unreliable. See _canaryKey.');

    // Screens that genuinely cannot build in a host VM go here WITH A REASON,
    // the way `responsive_overflow_test`'s `buildErrorAllowlist` does it — and
    // with the same single entry, because it is the same screen and the same
    // cause: `BackupService` resolves `FirebaseFirestore.instance` in a field
    // initialiser, so `BackupScreen` throws before it lays anything out.
    // It is registered rather than left out so the two harnesses report the
    // same population; an unregistered screen is invisible, an allow-listed one
    // is a named gap.
    const buildErrorAllowlist = <String, String>{
      'backup': 'needs a real Firebase app; host VM cannot initialise one',
    };
    expect(
      buildErrors.keys
          .where((k) => k != _canaryKey && !buildErrorAllowlist.containsKey(k))
          .toList(),
      isEmpty,
      reason: 'these screens threw while BUILDING, so an ErrorWidget was '
          'measured instead of the screen — see the THREW WHILE BUILDING '
          'section above. If one genuinely cannot build in a host VM, add it '
          'to buildErrorAllowlist WITH A REASON.\n'
          '${buildErrors.entries.where((e) => e.key != _canaryKey).map((e) => '${e.key}: ${e.value}').join('\n')}',
    );

    expect(couldNotBuild, isEmpty,
        reason: 'these screens were never measured, so "none below the floor" '
            'above does not cover them:\n'
            '${couldNotBuild.entries.map((e) => '${e.key}: ${e.value}').join('\n')}');
    expect(belowWcag, isEmpty,
        reason: 'Tappable targets below the WCAG 2.2 SC 2.5.8 minimum of 24pt '
            '— see the BELOW WCAG section above.');

    final comfortRegressions = <String>[];
    final comfortImprovements = <String>[];
    for (final e in small.entries) {
      final known = _comfortBaseline[e.key];
      if (known == null) {
        comfortRegressions.add('${e.key}: ${e.value.length} target(s), and '
            'nothing on this screen has been under 44pt before');
      } else if (e.value.length > known) {
        comfortRegressions
            .add('${e.key}: ${e.value.length} target(s), baseline is $known');
      } else if (e.value.length < known) {
        comfortImprovements.add('${e.key}: now ${e.value.length}, baseline '
            'says $known — lower it');
      }
    }
    for (final name in _comfortBaseline.keys) {
      if (!small.containsKey(name)) {
        comfortImprovements
            .add('$name: none left at all — remove it from the baseline');
      }
    }
    expect(comfortRegressions, isEmpty,
        reason: 'More tappables under the 44pt Apple minimum than the baseline '
            'records — see the BELOW APPLE HIG section above. A new one is '
            'either a control that needs a floor or, if it is genuinely not a '
            'defect, an argued edit to `_comfortBaseline`.\n'
            '${comfortRegressions.join('\n')}');
    // Failing on an IMPROVEMENT is deliberate, and is why the previous "print
    // it and move on" treatment could never have driven this number down.
    expect(comfortImprovements, isEmpty,
        reason: 'Good news, and an action: these beat the baseline, so the '
            'baseline is now lying.\n${comfortImprovements.join('\n')}');
  });
}

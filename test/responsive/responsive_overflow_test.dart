@Tags(['responsive'])
library;

import 'package:drift/native.dart';
import 'package:clock/clock.dart';
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
import 'package:tablet_remainder/features/medication/screens/vitals/vitals_reminder_settings_screen.dart';
import 'package:tablet_remainder/core/widgets/app/settings_tile.dart';

import 'package:tablet_remainder/features/biometrics/screens/health_source_detail_screen.dart';
import 'package:tablet_remainder/features/backup/presentation/screens/backup_settings_screen.dart';
import 'package:tablet_remainder/features/medication/data/condition_library_data.dart';
import 'package:tablet_remainder/features/medication/screens/conditions/condition_detail_screen.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_detail_screen.dart';
import 'package:tablet_remainder/features/medication/screens/refill_overview_screen.dart';
import 'package:tablet_remainder/features/period/screens/period_reminder_settings_screen.dart';
import 'package:tablet_remainder/features/reminders/screens/add_reminder_screen.dart';
import 'package:tablet_remainder/features/reminders/screens/category_management_screen.dart';
import 'package:tablet_remainder/features/settings/screens/pin_entry_screen.dart';
import 'package:tablet_remainder/features/sleep/screens/sleep_schedule_settings_screen.dart';
import 'package:tablet_remainder/features/steps/screens/steps_goal_settings_screen.dart';
import 'package:tablet_remainder/features/water/screens/water_reminder_settings_screen.dart';
import '../support/overflow_errors.dart';
import '../support/screen_fixtures.dart';
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
/// Row text the harness FONT cuts, per screen — a ratchet, not a target of zero.
///
/// `collectWrappedText` and `collectTruncatedText` divide the work: the first
/// re-lays a paragraph out against its declared allowance and so is meaningful
/// only for an UNCLAMPED `Text`, the second answers "you clamped it and it still
/// did not fit". Clamping the row title to 2 lines and the status to 1 moved
/// every signal from the first bucket to the second, which is why both are
/// collected.
///
/// **These are not device defects.** `flutter_test`'s fallback font is roughly
/// twice the advance width of shipped Inter, and the residue proves it: at 320pt
/// it cuts `"Vibration"` — nine characters — across two lines of a 134pt column,
/// which works out to ~30pt per character at a 16pt size. Real Inter averages
/// about half that. A hard `isEmpty` gate here would demand copy sized for a
/// font the app does not ship.
///
/// So the gate is shrink-only, exactly like the overflow baseline: any increase
/// fails, and so does any decrease, which forces the number down as copy
/// improves. Before the copy pass these five screens totalled **132**; the
/// unclamped-wrap bucket totalled **251** across six screens and is now empty.
const Map<String, int> _rowCutBaseline = {
  // 72 one-line status subtitles. Every one fits on a device: "Set per medicine"
  // is 16 characters, which needs ~112pt of real Inter against a 172pt column.
  'reminders_hub': 72,
  // Newly registered, so these 13 were always there and simply unmeasured.
  // All harness-font: it cuts "Blood pressure" — 14 characters — across two
  // lines of a 134pt column, which real Inter fits on one.
  'vitals_reminders': 13,
  // Newly VISIBLE to this gate rather than newly broken: `early_access` had no
  // SettingsTiles at all until its three hand-rolled feature-flag cards were
  // migrated onto the shared row, so the scope finder matched nothing there.
  // All harness-font — it cuts "May be unstable", fifteen characters, on one
  // line of a 134pt column.
  'early_access': 55,
  'focus_reminders': 13,
  'haptics': 12,
  'notif_settings': 8,
  // Newly registered (TQ-05), so these were always there and simply unmeasured
  // — the same shape as `vitals_reminders` above. Both are harness-font: the
  // widest offender on `period_reminders` is "~2 days before your start", a
  // 25-character STATUS line clamped to one line of a 134pt column, and
  // `health_source_detail` cuts "Use for health data" — eighteen characters —
  // across two lines of the same column. Real Inter is about half that advance.
  // 51 rather than a handful because this screen is four reminder rows at four
  // widths and three scales, each contributing a title and a status.
  'period_reminders': 51,
  'health_source_detail': 27,
};

/// The instant every seeded screen is rendered at.
///
/// A Wednesday in the middle of a month, so nothing straddles a week or month
/// boundary by accident. The value itself does not matter; that it is FIXED
/// does. `qa_seed.dart` anchors its history to "now", so under the wall clock
/// every date label, weekday strip and bar width in the baseline below moves
/// when the day rolls over — `water_stats` read 48 one day and 53 the next with
/// no code change, and the gate called it a regression.
final DateTime _seedNow = DateTime(2026, 8, 12, 10, 30);

/// **One entry, and it may only shrink.**
///
/// This began at six screens and 219 device/text-scale combinations. All 219 are
/// fixed; the single entry below is not one of them — it is what pinning
/// `water_history_edit` to `_seedNow` uncovered, on a screen whose list had
/// never been rendered with data in it. The gate is shrink-only in both
/// directions, so adding an entry here is a deliberate act that has to be
/// argued for, and a screen that starts overflowing fails immediately rather
/// than being absorbed.
///
/// All 219 were two defects wearing different clothes:
///
///  1. **A non-flex child in a `Row`.** Often with a `Spacer`, which absorbs
///     slack but cannot create any — `PredictionCard`'s eyebrow and
///     `AquaTimelineList`'s "View all" row were the same three-child shape.
///     Bounding the outer widget is usually not enough: a badge made `Flexible`
///     still overflowed until the label INSIDE it could ellipsise.
///  2. **A fixed height around text that scales.** `SizedBox(height: 150)` over
///     a 120pt bar and a label; `height: 80` over a 60pt bar; a circular gauge
///     whose readout outgrew its disc. The fix is `minHeight`, except where the
///     box is genuinely a circle, where the CONTENT has to scale down instead.
///
/// Two traps worth remembering. Deriving an exact height from `fontSize x a
/// guessed multiplier` made `water_stats` worse (28 -> 36) — a paragraph's band
/// is not that. And `focus_stats` kept eight combinations alive on **0.200px**,
/// because Flutter rounds a line box UP from the scaled metrics and the
/// derivation rounded down.
const Map<String, int> _seededOverflowBaseline = <String, int>{
  // Five drink rows on the seeded day, each one the SAME defect: the time on
  // the right of `_buildLogItem`'s inner `Row`
  // (`water_history_edit_screen.dart:382-395`) is a non-flex child, so when the
  // string alone outgrows the row the `Expanded` beside it is squeezed to zero
  // and the remainder overflows. Only at 320pt @2.0x, and the amounts are the
  // giveaway: +7.4px for the three 7-character times ("8:00 AM") and +32px for
  // the two 8-character ones ("10:00 AM"), i.e. one character of difference —
  // 24.6px — in a font whose every glyph is an em wide. Shipped Inter averages
  // about half that advance, so all five fit on a device, and the layout that
  // would satisfy the harness (a `Flexible` time) would ellipsise a clock that
  // currently renders in full on real hardware. Recorded rather than papered
  // over: this is the first time anything has rendered this list at all, and
  // the count is exact, so a sixth row or a wider one fails the gate.
  'water_history_edit': 5,

  // --- The five screens registering the last twelve surfaces uncovered (TQ-05).
  //
  // Recorded, not waived. Each is the FIRST time the screen has been laid out
  // at any width, the counts are exact, and the entries exist so the numbers
  // can only go down. Read them with the report header's caveat in mind:
  // `flutter_test` renders in a square-em fallback font roughly twice the
  // advance of the shipped Inter/Plus Jakarta, so an overflow that appears only
  // at 2.0x is usually the font. An overflow at 1.0x is not — that one is a
  // layout that has no slack at the default text size, on a phone the app
  // claims to support.
  //
  // 'add_reminder' was here at 18 — FIXED, so it is gone rather than lowered.
  // It was `_buildTimeRow`'s `Text + Spacer + chip`: the label set the width and
  // the row had nowhere to put a formatted date ("Wed, Sep 30, 2026"). The
  // value chip is now Expanded and ellipsizes, which cleared all of them.
  //
  // It got WORSE before it got better: moving the screen to `clock.now()`
  // (TQ-02) took it from 18 to 20, because against the wall clock it had been
  // rendering a date the pinned seed never matched — so this harness was
  // measuring a layout users never see. That is the whole argument for TQ-02.
  // 10. `Row > Padding > Container > Column` — +13px at 320pt @1.0x, the rest
  // at 1.3x and above. Rendered against the seeded `seed-med-1`, so this is the
  // populated screen, not the empty state.
  'medicine_detail': 10,
  // 8, all of them the `CategoryChip` row: +32px at 320pt @1.0x. A chip is
  // exactly the widget whose text is developer-authored and short, which is why
  // one that does not fit at the default size is worth a look.
  'condition_detail': 8,
  // 5, none at 1.0x — starts at 1.3x on the 320pt phone and is 2.0x-only above
  // it. Most likely the fallback font; the entry keeps it from growing.
  'steps_goal': 5,
  // 4, all at 2.0x, and +2.6px of the worst one. The mildest of the five.
  'refill_overview': 4,
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
  // `_seedNow`, not `DateTime.now()`. This screen takes the day it edits as a
  // constructor argument, and the argument is the ONE input the pinned clock
  // cannot reach: `withClock` only redirects `clock.now()`, so a literal
  // `DateTime.now()` here handed the screen the real calendar day while
  // `seedQaData` wrote its 30 days of history behind `_seedNow`. Those two
  // windows stop overlapping the moment the suite runs more than 30 days after
  // `_seedNow` — the screen then loads a day with no logs and renders its empty
  // state, so this registration measured an empty list and called it clean.
  // `water_statistics_screen` already lost a 42px overflow to exactly that.
  'water_history_edit': () => WaterHistoryEditScreen(date: _seedNow),
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
  // In NO Dart harness before this, despite a zero-argument const constructor
  // and eleven SettingsTiles — and it is one of the three screens the redesign
  // was reported against. Registering it was the entire barrier.
  'vitals_reminders': () => const VitalsReminderSettingsScreen(),
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

  // The last twelve `*Screen` classes this registry had never named (TQ-05).
  // Seven of them are settings surfaces whose rows are the exact shape this
  // harness catches — a fixed-width control beside a label that grows with
  // Dynamic Type — and no harness had ever laid one of them out.
  // `screen_registration_guard_test.dart` is what keeps the list complete from
  // here: a new `*Screen` has to be registered or skip-listed with a reason.
  'add_reminder': () => const AddReminderScreen(),
  'backup_settings': () => const BackupSettingsScreen(),
  'reminder_categories': () => const CategoryManagementScreen(),
  'period_reminders': () => const PeriodReminderSettingsScreen(),
  'refill_overview': () => const RefillOverviewScreen(),
  'sleep_schedule': () => const SleepScheduleSettingsScreen(),
  'steps_goal': () => const StepsGoalSettingsScreen(),
  'water_reminders': () => const WaterReminderSettingsScreen(),
  // `autoPromptBiometrics: false`. The default raises the platform's biometric
  // sheet on first build, which under `flutter test` is a `local_auth` channel
  // that does not exist — and a layout harness has no business asking.
  'pin_entry': () => const PinEntryScreen(
        mode: PinEntryMode.setup,
        setupTitle: 'Change PIN',
        autoPromptBiometrics: false,
      ),
  // hypertension: the longest name in the library and the only entry that
  // renders both personalised sections, exactly as the comment on
  // `condition_library` above already claimed was the fixture of choice.
  'condition_detail': () => ConditionDetailScreen(
        condition:
            conditionLibrary.firstWhere((c) => c.id == 'hypertension'),
      ),
  'medicine_detail': () =>
      NunitoMedicationDetailScreen(medicine: seededMedicine(_seedNow)),
  'health_source_detail': () => HealthSourceDetailScreen(
        controller: seededSourceController(_seedNow),
        sourceId: kFixtureSourceId,
      ),
};

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
  final rowWraps = <String, List<String>>{};
  final rowCuts = <String, List<String>>{};
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
    // Pinned, because the baseline below is a set of exact counts and the seed
    // anchors its history to "now". With the wall clock, every date label and
    // bar width shifts when the day rolls over: `water_stats` measured 48 one
    // day and 53 the next with no code change in between, and the gate reported
    // it as a regression. A baseline that moves on its own cannot tell a
    // regression from a Tuesday.
    await withClock(Clock.fixed(_seedNow), () => seedQaData(force: true));
  });

  tearDown(() async => db.close());

  for (final screenEntry in _screens.entries) {
    final name = screenEntry.key;

    testWidgets('$name fits every supported phone', (tester) async {
      // The screens read the clock too — anything showing "today", a weekday
      // strip or a relative time. Pinning the pump as well as the seed is what
      // makes the two agree.
      await withClock(Clock.fixed(_seedNow), () async {
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
            if (!isOverflowError(d.exception)) {
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
            // layout — nothing throws, so `isOverflowError` never saw it.
            // Scoped to AppHeader because header text is chrome, not content:
            // a title or a greeting that needs two lines is broken by
            // definition.
            final wrapped = collectWrappedText(find.byType(AppHeader));
            for (final w in wrapped) {
              wraps.putIfAbsent(name, () => []).add('${dev.key} @${scale}x  $w');
            }

            // ROW BODY text that wrapped. Separate bucket, separate gate.
            //
            // The header scope above is the only place this harness ever
            // looked, and it is why the settings screenshots got through: an
            // unclamped subtitle running to four lines is a legal layout, so
            // `isOverflowError` cannot see it, and a row body is not inside an
            // AppHeader.
            //
            // Allowance 2, not 1. A row is not chrome — Android's settings
            // guidance says a long TITLE may continue onto a second line while
            // the subtext "should be only one line". Applying the looser of the
            // two uniformly catches the three- and four-line rows without the
            // gate having to decide which slot each RichText belongs to.
            for (final w in collectWrappedText(find.byType(SettingsTile),
                defaultAllowance: 2)) {
              rowWraps.putIfAbsent(name, () => []).add('${dev.key} @${scale}x  $w');
            }

            // Row text that was CUT, which is the other half and the one that
            // survives clamping.
            //
            // The two helpers divide the work: `collectWrappedText` re-lays the
            // paragraph out and compares against its declared allowance, so it
            // is meaningful only for an UNCLAMPED `Text` — for a clamped one the
            // painter stops at the same `maxLines` the comparison uses, and the
            // check can never fire. `didExceedMaxLines` answers the clamped
            // case: "you gave it two lines and it needed more".
            //
            // Clamping the title to 2 and the subtitle to 1 therefore moves the
            // signal from the first bucket to this one. Gating only the first
            // would have looked like a fix and measured nothing.
            for (final t in collectTruncatedText(find.byType(SettingsTile))) {
              rowCuts.putIfAbsent(name, () => []).add('${dev.key} @${scale}x  $t');
            }

            // Text cut off with an ellipsis, ANYWHERE on the screen. Reported
            // rather than gated: a long user-entered name legitimately
            // ellipsizes, so this needs a human read. A developer-authored
            // string in the list is a layout bug.
            if (scale == 1.0) {
              for (final t in collectTruncatedText(find.byType(MaterialApp))) {
                truncations.putIfAbsent(name, () => []).add('${dev.key}  $t');
              }
            }
            // Some screens guard their init with `.timeout(6s)`, which leaves
            // a pending Timer that trips the teardown assertion. Advancing the
            // fake clock past it is instant (no real wall time) and lets those
            // timers fire so the harness reports overflows, not timer noise.
            //
            // This pump belongs INSIDE the try, before onError is restored and
            // before the drain below. It used to sit after both, so anything
            // that overflowed on this frame — the state the user actually ends
            // up in, once init has resolved — was recorded by the binding and
            // picked up by the NEXT combination's drain, i.e. reported against
            // the wrong device and scale; on the last combination there was no
            // next drain at all and it surfaced as a tearDownAll failure. That
            // is how a PersonalBestCard row that overflowed by 75px at 320pt
            // @1.0x got reported as "+37px at 428pt @2.0x".
            await tester.pump(const Duration(seconds: 7));
          } catch (e) {
            unrenderable.putIfAbsent(name, () => e.toString().split('\n').first);
          } finally {
            FlutterError.onError = prevOnError;
          }

          // Drain anything the framework recorded too.
          Object? ex;
          while ((ex = tester.takeException()) != null) {
            if (isOverflowError(ex!)) caught.add(_overflowSummary(ex));
          }

          for (final line in caught) {
            overflows
                .putIfAbsent(name, () => [])
                .add('${dev.key} @${scale}x  $line');
          }

          // Reset so the next combination starts clean.
          await tester.pumpWidget(const SizedBox.shrink());
          // …and let the teardown's own timers run. Drift's
          // `StreamQueryStore.markAsClosed` arms a zero-duration timer when the
          // last listener goes away, so a screen built on a `StreamBuilder`
          // over a Drift query (`CategoryManagementScreen`) died on "A Timer is
          // still pending after the widget tree was disposed" — a teardown
          // artefact of unsubscribing, reported as if the screen were broken.
          // A duration, not a bare `pump()`: the binding only advances its
          // fake clock when it is given one, and a zero-duration FakeTimer
          // fires on elapse, not on a microtask drain.
          await tester.pump(const Duration(milliseconds: 1));
          }
        }
      });
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
    if (rowWraps.isNotEmpty) {
      final lines = <String>[];
      for (final e in rowWraps.entries) {
        lines.add('${e.key}  (${e.value.length})');
        for (final v in e.value.take(4)) {
          lines.add('    $v');
        }
      }
      // ignore: avoid_print
      print('\n===== SETTINGS ROW TEXT THAT WRAPPED =====\n'
          '${lines.join('\n')}\n==========================================');
    }
    if (rowCuts.isNotEmpty) {
      final lines = <String>[];
      for (final e in rowCuts.entries) {
        lines.add('${e.key}  (${e.value.length})');
        for (final v in e.value.take(6)) {
          lines.add('    $v');
        }
      }
      // ignore: avoid_print
      print('\n===== SETTINGS ROW TEXT THAT WAS CUT =====\n'
          '${lines.join('\n')}\n==========================================');
    }
    // A non-overflow exception during build was recorded and printed and never
    // asserted, so a screen that threw while rendering exited this harness with
    // status 0. Pinning the clock already removed one such entry —
    // `proactive_nudge`'s "No Material widget found", which turned out to be
    // date-dependent and had been sitting in the overflow baseline as if it were
    // a layout fact.
    //
    // `backup` is allow-listed because it needs a real Firebase app, which a
    // host-VM test cannot provide. Anything else is a defect.
    const buildErrorAllowlist = <String, String>{
      'backup': 'needs a real Firebase app; host VM cannot initialise one',
    };
    expect(
      buildErrors.keys.where((k) => !buildErrorAllowlist.containsKey(k)).toList(),
      isEmpty,
      reason: 'Screens threw while building — see the BUILD ERRORS section '
          'above. If a screen genuinely cannot build in a host VM, add it to '
          'buildErrorAllowlist WITH A REASON.\n'
          '${buildErrors.entries.map((e) => '${e.key}: ${e.value}').join('\n')}',
    );

    final cutRegressions = <String>[];
    final cutImprovements = <String>[];
    for (final e in rowCuts.entries) {
      final known = _rowCutBaseline[e.key];
      if (known == null) {
        cutRegressions.add('${e.key}: ${e.value.length}, and this screen has '
            'never cut row text before');
      } else if (e.value.length > known) {
        cutRegressions
            .add('${e.key}: ${e.value.length}, baseline is $known');
      } else if (e.value.length < known) {
        cutImprovements.add('${e.key}: now ${e.value.length}, baseline says '
            '$known — lower it');
      }
    }
    for (final name in _rowCutBaseline.keys) {
      if (!rowCuts.containsKey(name)) {
        cutImprovements.add('$name: no cuts at all — remove it from the '
            'baseline');
      }
    }
    expect(cutRegressions, isEmpty,
        reason: 'Settings row text is being cut in more places than the '
            'baseline records. See the SETTINGS ROW TEXT THAT WAS CUT section '
            'above.\n${cutRegressions.join('\n')}');
    expect(cutImprovements, isEmpty,
        reason: 'Better than the baseline, so the baseline is now lying.\n'
            '${cutImprovements.join('\n')}');
    expect(rowWraps, isEmpty,
        reason: 'Settings row text wrapped past two lines. A row title may run '
            'to a second line; its status line may not, and neither may run to '
            'a third. This is the gate that was missing when the three '
            'screenshots got through — the header scope above does not contain '
            'row bodies, and a soft wrap throws nothing for '
            '`isOverflowError` to catch.\n${rowWraps.keys.join(', ')}');
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

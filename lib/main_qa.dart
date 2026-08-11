// QA-only entrypoint for seeded visual verification of the Steps & Sleep
// dashboards on the iOS simulator. NOT shipped. Build with:
//   flutter build ios --debug --simulator -t lib/main_qa.dart
// then relaunch with env to switch screen/theme WITHOUT rebuilding:
//   xcrun simctl launch --terminate-running-process booted <bundle> \
//     --setenv QA_SCREEN=sleep --setenv QA_DARK=true
import 'dart:io' show File, Platform;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'core/database/app_database.dart';
import 'core/services/clean_storage_service.dart';
import 'core/services/feature_flag_service.dart';
import 'core/theme/app_theme.dart';
import 'features/medication/screens/nunito_medication_dashboard.dart';
import 'features/medication/screens/nunito_add_medication_flow.dart';
import 'features/medication/services/medicine_storage_service.dart';
import 'features/home/screens/home_dashboard.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/reminders/screens/add_reminder_screen.dart';
import 'features/insights/screens/trends_dashboard_screen.dart';
import 'features/insights/services/trends_data_service.dart' show TrendRange;
import 'features/sleep/screens/sleep_dashboard_screen.dart';
import 'features/sleep/services/sleep_service.dart';
import 'features/steps/screens/steps_dashboard_screen.dart';
import 'features/steps/services/step_service.dart';
import 'features/water/screens/aqua_water_dashboard.dart';
import 'features/water/screens/hydration_profile_screen.dart';
import 'features/water/screens/water_statistics_screen.dart';
import 'features/water/screens/custom_cup_creator_screen.dart';
import 'features/period/screens/period_dashboard.dart';
import 'features/period/screens/period_reminder_settings_screen.dart';
import 'features/period/services/period_service.dart';
import 'features/medication/screens/vitals/vitals_reminder_settings_screen.dart';
import 'features/settings/screens/reminders_hub_screen.dart';
// --- Screens added for the full UI/UX audit sweep ---
import 'features/medication/screens/vitals/blood_pressure_screen.dart';
import 'features/medication/screens/vitals/blood_sugar_screen.dart';
import 'features/medication/screens/vitals/weight_screen.dart';
import 'features/medication/screens/vitals/mood_screen.dart';
import 'features/medication/screens/nunito_medication_list_screen.dart';
import 'features/medication/screens/refill_overview_screen.dart';
import 'features/medication/screens/analytics/nunito_adherence_report_screen.dart';
import 'features/medication/screens/appointments/nunito_appointment_list_screen.dart';
import 'features/medication/screens/doctors/nunito_doctor_list_screen.dart';
import 'features/medication/screens/clinics/nunito_clinic_list_screen.dart';
import 'features/medication/screens/dependents/dependent_list_screen.dart';
import 'features/medication/screens/conditions/condition_library_screen.dart';
import 'features/diary/screens/diary_screen.dart';
import 'features/water/screens/caffeine_insights_screen.dart';
import 'features/water/screens/water_calendar_screen.dart';
import 'features/water/screens/water_achievements_screen.dart';
import 'features/water/screens/water_history_edit_screen.dart';
import 'features/water/screens/water_reminder_settings_screen.dart';
import 'features/focus/screens/focus_screen.dart';
import 'features/focus/screens/relaxation_screen.dart';
import 'features/focus/screens/focus_garden_screen.dart';
import 'features/focus/screens/detailed_stats_screen.dart';
import 'features/focus/screens/custom_tags_screen.dart';
import 'features/focus/screens/app_allow_list_screen.dart';
import 'features/focus/screens/plant_real_trees_screen.dart';
import 'features/reminders/screens/reminders_screen.dart';
import 'features/reminders/screens/category_management_screen.dart';
import 'features/insights/screens/weekly_recap_screen.dart';
import 'features/settings/screens/notification_settings_screen.dart';
import 'features/settings/screens/haptic_settings_screen.dart';
import 'features/settings/screens/vitavibe_settings_screen.dart';
import 'features/focus/screens/settings/focus_reminders_settings_screen.dart';
import 'features/settings/screens/security_settings_screen.dart';
import 'features/settings/screens/early_access_screen.dart';
import 'features/settings/screens/backup_screen.dart';
import 'features/backup/presentation/screens/backup_settings_screen.dart';
import 'features/sleep/screens/sleep_history_screen.dart';
import 'features/sleep/screens/sleep_schedule_settings_screen.dart';
import 'features/steps/screens/steps_history_screen.dart';
import 'features/steps/screens/steps_goal_settings_screen.dart';
import 'features/period/screens/period_calendar_screen.dart';
import 'features/period/screens/cycle_history_screen.dart';
import 'features/onboarding/screens/welcome_screen.dart';
import 'features/home/screens/health_browse_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppDatabase.instance; // open Drift
  await CleanStorageService.init();
  await FeatureFlagService().init();
  await StepService.init();
  await SleepService.init();
  try {
    await MedicineCleanStorageService.init();
  } catch (_) {}
  try {
    await PeriodService.init();
  } catch (_) {}
  await _seed();

  final (screen, dark) = await _readConfig();
  debugPrint('🧪 QA resolved screen="$screen" dark=$dark');
  runApp(_QaApp(screen: screen, dark: dark));
}

/// Read screen/theme from a config file in the app's Documents container
/// (rewritten via `simctl` between launches — reliable, rebuild-free). Falls
/// back to env vars, then defaults.
Future<(String, bool)> _readConfig() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/qa_config.txt');
    if (await f.exists()) {
      final lines = (await f.readAsString()).trim().split('\n');
      final screen = lines.isNotEmpty ? lines[0].trim() : 'steps';
      final dark = lines.length > 1 && lines[1].trim() == 'dark';
      return (screen, dark);
    }
  } catch (_) {}
  return (
    Platform.environment['QA_SCREEN'] ?? 'steps',
    Platform.environment['QA_DARK'] == 'true',
  );
}

/// Seed a realistic ~week of Steps + Sleep so every new card has content.
/// Guarded so relaunches don't double-count.
Future<void> _seed() async {
  if (CleanStorageService.getAppPreference('qa_seeded', false) == true) return;
  final now = DateTime.now();

  // Steps: yesterday backward. Mostly hitting the 8k default goal (one dip that
  // the forgiving streak should absorb) with a 12,430 personal best.
  const stepVals = [9200, 8600, 7000, 8100, 12430, 8300, 9000, 6500, 8800];
  for (var i = 0; i < stepVals.length; i++) {
    final d = now.subtract(Duration(days: i + 1));
    await StepService.addManualStepsForDate(d, stepVals[i], maxDaysBack: 30);
  }
  await StepService.addManualSteps(4200); // today, in progress

  // Sleep: last 8 nights, bedtimes clustered ~22:45 ± 20m (a "fairly regular"
  // rhythm), with one high-quality night to land a "well rested" best night.
  for (var i = 1; i <= 8; i++) {
    final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
    final jitter = (i * 11) % 40 - 20; // -20..+19 min
    final wake = DateTime(day.year, day.month, day.day, 7, 0);
    final bed = wake
        .subtract(const Duration(hours: 8, minutes: 15))
        .add(Duration(minutes: jitter));
    await SleepService.logManualSession(
      bedtime: bed,
      wakeTime: wake,
      quality: i == 1 ? 5 : 4,
    );
  }

  await CleanStorageService.setAppPreference('qa_seeded', true);
}

class _QaApp extends StatelessWidget {
  final String screen;
  final bool dark;
  const _QaApp({required this.screen, required this.dark});

  @override
  Widget build(BuildContext context) {
    // Full flows / self-scaffolded screens render directly as home; the
    // hub-then-push pattern is only needed for the dashboards.
    final Widget home = switch (screen) {
      'add_med' => const NunitoAddMedicationFlow(debugInitialStep: 2),
      // Step 1 (Basic info) to screenshot the name auto-suggestion chips.
      'add_med_step1' => const NunitoAddMedicationFlow(debugInitialStep: 0),
      // Health-feature screens (self-scaffolded).
      'water' => const AquaWaterDashboard(embedded: false),
      'hydration_profile' => const HydrationProfileScreen(),
      'water_stats' => const WaterStatisticsScreen(),
      'custom_cup' => const CustomCupCreatorScreen(),
      'period' => const PeriodDashboard(embedded: false),
      'reminders_hub' => const RemindersHubScreen(),
      'period_reminders' => const PeriodReminderSettingsScreen(),
      'vitals_reminders' => const VitalsReminderSettingsScreen(),
      // --- Full audit sweep: self-scaffolded screens render directly ---
      'welcome' => const WelcomeScreen(),
      'health_browse' => const HealthBrowseScreen(),
      'bp' => const BloodPressureScreen(),
      'glucose' => const BloodSugarScreen(),
      'weight' => const WeightScreen(),
      'mood' => const MoodScreen(),
      'med_list' => const NunitoMedicationListScreen(),
      'refill' => const RefillOverviewScreen(),
      'adherence' => const NunitoAdherenceReportScreen(),
      'appointments' => const NunitoAppointmentListScreen(),
      'doctors' => const NunitoDoctorListScreen(),
      'clinics' => const NunitoClinicListScreen(),
      'dependents' => const DependentListScreen(),
      'conditions' => const ConditionLibraryScreen(),
      'diary' => const DiaryScreen(),
      'caffeine' => const CaffeineInsightsScreen(),
      'water_calendar' => const WaterCalendarScreen(),
      'water_awards' => const WaterAchievementsScreen(),
      'water_history' => WaterHistoryEditScreen(date: DateTime.now()),
      'water_reminders' => const WaterReminderSettingsScreen(),
      'focus' => const FocusScreen(),
      'relaxation' => const RelaxationScreen(),
      'focus_garden' => const FocusGardenScreen(),
      'focus_stats' => const DetailedStatsScreen(),
      'focus_tags' => const CustomTagsScreen(),
      'focus_apps' => const AppAllowListScreen(),
      'plant_trees' => const PlantRealTreesScreen(),
      'reminders' => const RemindersScreen(),
      'categories' => const CategoryManagementScreen(),
      'weekly_recap' => const WeeklyRecapScreen(),
      'notif_settings' => const NotificationSettingsScreen(),
      'haptics' => const HapticSettingsScreen(),
      'vitavibe' => const VitaVibeSettingsScreen(),
      'focus_reminders' => const FocusRemindersSettingsScreen(),
      'security' => const SecuritySettingsScreen(),
      'early_access' => const EarlyAccessScreen(),
      'backup_cloud' => const BackupScreen(),
      'backup_local' => const BackupSettingsScreen(),
      'sleep_history' => const SleepHistoryScreen(),
      'sleep_schedule' => const SleepScheduleSettingsScreen(),
      'steps_history' => const StepsHistoryScreen(),
      'steps_goal' => const StepsGoalSettingsScreen(),
      'period_calendar' => const PeriodCalendarScreen(),
      'cycle_history' => const CycleHistoryScreen(),
      _ => _QaHub(screen: screen),
    };
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      // Mirror main.dart's clamp so QA screenshots reflect what ships.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(maxScaleFactor: 2.0),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: home,
    );
  }
}

/// Empty hub that pushes the target dashboard after first frame — this
/// hub-then-push pattern avoids the sim's black/history crash on pushed screens.
class _QaHub extends StatefulWidget {
  final String screen;
  const _QaHub({required this.screen});
  @override
  State<_QaHub> createState() => _QaHubState();
}

class _QaHubState extends State<_QaHub> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final Widget target = switch (widget.screen) {
        'sleep' => const SleepDashboardScreen(),
        'trends' => const TrendsDashboardScreen(initialRange: TrendRange.d30),
        'medicine' => const NunitoMedicationDashboard(),
        // Add-medicine wizard opened straight on the Schedule step (index 2) to
        // screenshot the redesigned frequency + times UI.
        'add_med' => const NunitoAddMedicationFlow(debugInitialStep: 2),
        // Phase 1-3 UX-review screens.
        'home' => HomeDashboard(onNavigate: (i, {healthTab}) {}),
        'settings' => const SettingsScreen(),
        'add_reminder' => const AddReminderScreen(),
        _ => const StepsDashboardScreen(),
      };
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => target));
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

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
import 'features/insights/screens/assistant_screen.dart';
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
import 'features/settings/screens/reminders_hub_screen.dart';

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
      // The AI chat empty state (starters + "OR JUST LOG IT" + composer/mic).
      'assistant' => const AssistantScreen(),
      // Health-feature screens (self-scaffolded).
      'water' => const AquaWaterDashboard(embedded: false),
      'hydration_profile' => const HydrationProfileScreen(),
      'water_stats' => const WaterStatisticsScreen(),
      'custom_cup' => const CustomCupCreatorScreen(),
      'period' => const PeriodDashboard(embedded: false),
      'reminders_hub' => const RemindersHubScreen(),
      'period_reminders' => const PeriodReminderSettingsScreen(),
      _ => _QaHub(screen: screen),
    };
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
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

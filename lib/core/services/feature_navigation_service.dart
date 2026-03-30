import 'package:flutter/material.dart';

import 'auth_service.dart';
import '../widgets/auth_gate_sheet.dart';

// Feature main screen imports (with bottom nav)
import '../../features/medication/screens/medicine_main_screen.dart';
import '../../features/water/screens/water_main_screen.dart';
import '../../features/focus/screens/focus_main_screen.dart';
import '../../features/fitness/screens/fitness_entry_screen.dart';
import '../../features/finance/screens/finance_main_screen.dart';
import '../../features/period_tracking/screens/luna_main_screen.dart';
import '../../features/mood/screens/mood_main_screen.dart';
import '../../features/notes/screens/notes_main_screen.dart';
import '../../features/exam_prep/screens/exam_main_screen.dart';
import '../../features/reminders/screens/reminders_main_screen.dart';
import '../../features/habit/screens/habit_main_screen.dart';

// Legacy screen imports (for fallback)
import '../../features/medication/screens/nunito_medication_dashboard.dart';
import '../../features/water/screens/aqua_water_dashboard.dart';
import '../../features/reminders/screens/reminders_screen.dart';
import '../../features/focus/screens/focus_screen.dart';
import '../../features/notes/presentation/screens/premium_notes_screen.dart';
import '../../features/exam_prep/screens/exam_prep_home_screen.dart';
import '../../features/fitness/screens/fitness_home_screen.dart';
import '../../features/finance/screens/finance_home_screen.dart';
import '../../features/period_tracking/screens/luna_dashboard_screen.dart';
import '../../features/mood/screens/bloom_mood_home_screen.dart';
import '../../features/habit/screens/habit_dashboard.dart';
import '../../features/fun/screens/fun_relax_dashboard.dart';

/// Centralized service for navigating to feature screens
/// Maps feature IDs to their corresponding screen widgets
/// Handles authentication gating for features
class FeatureNavigationService {
  static final FeatureNavigationService _instance = FeatureNavigationService._internal();
  factory FeatureNavigationService() => _instance;
  FeatureNavigationService._internal();

  final AuthService _authService = AuthService();

  /// Get the main screen widget for a given feature ID (with bottom nav)
  Widget? getFeatureMainScreen(String featureId) {
    switch (featureId) {
      case 'medicine':
        return const MedicineMainScreen();
      case 'water':
        return const WaterMainScreen();
      case 'reminders':
        return const RemindersMainScreen();
      case 'focus':
        return const FocusMainScreen();
      case 'notes':
        return const NotesMainScreen();
      case 'exam_prep':
        return const ExamMainScreen();
      case 'fitness':
        return const FitnessEntryScreen();
      case 'finance':
        return const FinanceMainScreen();
      case 'period':
        return const LunaMainScreen();
      case 'mood':
        return const MoodMainScreen();
      case 'habit':
        return const HabitMainScreen();
      case 'fun':
      case 'relax':
        return const FunRelaxDashboard();
      default:
        return null;
    }
  }

  /// Get legacy screen widget (without bottom nav) - for backward compatibility
  Widget? getFeatureScreen(String featureId) {
    switch (featureId) {
      case 'medicine':
        return const NunitoMedicationDashboard();
      case 'water':
        return const AquaWaterDashboard();
      case 'reminders':
        return const RemindersScreen();
      case 'focus':
        return const FocusScreen();
      case 'notes':
        return const PremiumNotesScreen();
      case 'exam_prep':
        return const ExamPrepHomeScreen();
      case 'fitness':
        return const FitnessHomeScreen();
      case 'finance':
        return const FinanceHomeScreen();
      case 'period':
        return const LunaDashboardScreen();
      case 'mood':
        return const BloomMoodHomeScreen();
      case 'habit':
        return const HabitDashboard();
      case 'fun':
      case 'relax':
        return const FunRelaxDashboard();
      default:
        return null;
    }
  }

  /// Navigate to a feature with authentication gate
  /// Shows auth modal for guests, then navigates to feature main screen
  Future<void> navigateToFeatureWithAuth(BuildContext context, String featureId) async {
    final isAuthenticated = _authService.isAuthenticated;

    // If not authenticated (guest or offline guest), show auth gate
    if (!isAuthenticated) {
      final shouldProceed = await AuthGateSheet.show(
        context: context,
        featureName: getFeatureDisplayName(featureId),
        featureColor: getFeatureColor(featureId),
        featureIcon: getFeatureIcon(featureId),
      );
      
      if (!shouldProceed) return;
    }

    // Navigate to the feature main screen
    if (context.mounted) {
      final screen = getFeatureMainScreen(featureId);
      if (screen != null) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => screen,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    }
  }

  /// Navigate to a feature screen (legacy - without auth gate)
  void navigateToFeature(BuildContext context, String featureId) {
    final screen = getFeatureMainScreen(featureId) ?? getFeatureScreen(featureId);
    if (screen != null) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => screen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.05, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  /// Get the primary feature screen for a category
  /// Returns the main/default screen for a category
  Widget getPrimaryScreenForCategory(String categoryId) {
    switch (categoryId) {
      case 'health':
        return const NunitoMedicationDashboard();
      case 'productivity':
        return const FocusScreen();
      case 'fitness':
        return const FitnessHomeScreen();
      case 'finance':
        return const FinanceHomeScreen();
      case 'period_tracking':
        return const LunaDashboardScreen();
      default:
        return const _FeatureNotFoundScreen();
    }
  }

  /// Get feature display name
  String getFeatureDisplayName(String featureId) {
    switch (featureId) {
      case 'medicine':
        return 'Medicine';
      case 'water':
        return 'Water';
      case 'reminders':
        return 'Reminders';
      case 'focus':
        return 'Focus';
      case 'notes':
        return 'Notes';
      case 'exam_prep':
        return 'Exam Prep';
      case 'fitness':
        return 'Fitness';
      case 'finance':
        return 'Finance';
      case 'period':
        return 'Period';
      case 'mood':
        return 'Mood';
      case 'habit':
        return 'Habits';
      case 'fun':
      case 'relax':
        return 'Fun & Relax';
      default:
        return featureId;
    }
  }

  /// Get feature icon
  IconData getFeatureIcon(String featureId) {
    switch (featureId) {
      case 'medicine':
        return Icons.medication_rounded;
      case 'water':
        return Icons.water_drop_rounded;
      case 'reminders':
        return Icons.notifications_rounded;
      case 'focus':
        return Icons.self_improvement_rounded;
      case 'notes':
        return Icons.note_alt_rounded;
      case 'exam_prep':
        return Icons.school_rounded;
      case 'fitness':
        return Icons.fitness_center_rounded;
      case 'finance':
        return Icons.account_balance_wallet_rounded;
      case 'period':
        return Icons.calendar_month_rounded;
      case 'mood':
        return Icons.mood_rounded;
      case 'habit':
        return Icons.track_changes_rounded;
      case 'fun':
      case 'relax':
        return Icons.spa_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  /// Get feature color
  Color getFeatureColor(String featureId) {
    switch (featureId) {
      case 'medicine':
        return const Color(0xFF6366F1);
      case 'water':
        return const Color(0xFF06B6D4);
      case 'reminders':
        return const Color(0xFFF59E0B);
      case 'focus':
        return const Color(0xFF8B5CF6);
      case 'notes':
        return const Color(0xFF10B981);
      case 'exam_prep':
        return const Color(0xFF3B82F6);
      case 'fitness':
        return const Color(0xFFEF4444);
      case 'finance':
        return const Color(0xFF22C55E);
      case 'period':
        return const Color(0xFFEC4899);
      case 'mood':
        return const Color(0xFFFF6B9D);
      case 'habit':
        return const Color(0xFF7C91F4);
      case 'fun':
      case 'relax':
        return const Color(0xFF9333EA);
      default:
        return const Color(0xFF64748B);
    }
  }
}

/// Fallback screen when feature not found
class _FeatureNotFoundScreen extends StatelessWidget {
  const _FeatureNotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feature Not Found')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'This feature is not available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/feature_manager.dart';
import '../../../core/services/category_manager.dart';
import '../../medication/screens/enhanced_add_medicine_screen.dart';
import '../../medication/screens/enhanced_medicine_dashboard.dart';
import '../../medication/screens/medicine_detail_screen.dart';
import '../../../core/services/storage_service.dart';
import '../../medication/models/enhanced_medicine.dart';
import '../../medication/services/medicine_storage_service.dart';
import '../../water/screens/water_dashboard_screen.dart';
import '../../fitness/screens/fitness_dashboard_screen.dart';
import '../../period_tracking/screens/period_overview_screen.dart';
import '../../period_tracking/screens/period_intro_screen.dart';
import '../../focus/screens/focus_screen.dart';
import '../../focus/services/focus_service.dart';
import '../../focus/widgets/focus_home_card.dart';
import '../../focus/models/focus_plant.dart';
import 'package:intl/intl.dart';
import '../../settings/screens/settings_screen.dart';
import '../../notes/presentation/screens/luxury_notes_screen.dart';
import '../../exam_prep/screens/exam_dashboard_screen.dart';
import '../../finance/screens/finance_dashboard_screen.dart';
import '../../fun/screens/fun_relax_dashboard.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  String _getEmotionalGreeting(String userName) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Ready to win today, $userName?";
    } else if (hour < 17) {
      return "Stay consistent, $userName.";
    } else {
      return "Great job today 👏";
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    return ListenableBuilder(
      listenable: authService,
      builder: (context, _) {
        final user = authService.currentUser;
        final isGuest = authService.isGuest;
        
        return _buildHomeContent(context, authService, user, isGuest);
      },
    );
  }

  Widget _buildHomeContent(BuildContext context, AuthService authService, user, bool isGuest) {
    final isDark = AppColors.isDark(context);
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Column(
          children: [
            // Premium Header with User Profile
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  // User Avatar
                  GestureDetector(
                    onTap: () => _showProfileMenu(context, authService),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: user?.photoUrl != null
                          ? ClipOval(
                              child: Image.network(
                                user!.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildAvatarInitials(user.name),
                              ),
                            )
                          : _buildAvatarInitials(user?.name ?? 'U'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getEmotionalGreeting(user?.name.split(' ').first ?? 'User'),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('EEEE, MMMM d').format(DateTime.now()),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  // Settings Button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.getCardBg(context),
                      borderRadius: BorderRadius.circular(12),
                      border: isDark ? Border.all(color: AppColors.darkBorder.withOpacity(0.5)) : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                      icon: Icon(Icons.settings_outlined, color: AppColors.getTextSecondary(context)),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // Today Overview Section
                    _buildTodayOverview(context),
                    const SizedBox(height: 20),
                    // Active Focus Session Banner
                    _buildFocusSessionBanner(context),
                    
                    // Quick Actions Grid
                    _buildQuickActionsGrid(context),
                    const SizedBox(height: 16),
                    
                    // Medicine Summary Card
                    _buildMedicineSummaryCard(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildGridCard(
    BuildContext context, {
    required double width,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = AppColors.isDark(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.15 : 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkElevatedCard : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(isDark ? 0.3 : 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarInitials(String name) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Center(
      child: Text(
        initials,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
      ),
    );
  }

  void _showProfileMenu(BuildContext context, AuthService authService) {
    final user = authService.currentUser;
    final isGuest = authService.isGuest;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.getModalBackground(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 42,
                  height: 42,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.getDivider(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Profile Info
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: user?.photoUrl != null
                      ? ClipOval(
                          child: Image.network(user!.photoUrl!, fit: BoxFit.cover),
                        )
                      : _buildAvatarInitials(user?.name ?? 'U'),
                ),
                const SizedBox(height: 16),
                Text(
                  user?.name ?? 'User',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.getTextPrimary(context)),
                ),
                const SizedBox(height: 4),
                Text(
                  isGuest ? 'Guest User' : (user?.email ?? ''),
                  style: TextStyle(color: AppColors.getTextSecondary(context)),
                ),
                const SizedBox(height: 32),
                // Action Button - Google Sign In for guests, Sign Out for authenticated users
                SizedBox(
                  width: double.infinity,
                  child: isGuest
                      ? ElevatedButton.icon(
                          onPressed: () async {
                            final result = await authService.signInWithGoogle();
                            if (result == null && context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Successfully signed in with Google!'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                            } else if (result != null && result != 'cancelled' && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                          label: const Text("Sign in with Google"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await authService.signOut();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Signed out successfully. Continuing as guest.'),
                                  backgroundColor: AppColors.info,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                          label: const Text("Sign Out", style: TextStyle(color: AppColors.error)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }





  Widget _buildQuickActionsGrid(BuildContext context) {
    final categoryManager = CategoryManager();
    final selectedCategory = categoryManager.selectedCategory;
    
    return LayoutBuilder(builder: (context, constraints) {
      // Build feature cards based on selected category
      final featureCards = <Widget>[];
      
      // Category-specific features
      switch (selectedCategory) {
        case AppCategory.health:
          featureCards.addAll([
            _buildQuickActionCard(
              context,
              width: 140,
              icon: Icons.medication_rounded,
              label: 'Medicine',
              color: AppColors.primary,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EnhancedMedicineDashboard())),
            ),
            _buildQuickActionCard(
              context,
              width: 140,
              icon: Icons.water_drop_rounded,
              label: 'Water',
              color: AppColors.info,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WaterDashboardScreen())),
            ),
          ]);
          break;
        case AppCategory.productivity:
          featureCards.addAll([
            _buildQuickActionCard(
              context,
              width: 140,
              icon: Icons.self_improvement_rounded,
              label: 'Focus',
              color: const Color(0xFF8B5CF6),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FocusScreen())),
            ),
            _buildQuickActionCard(
              context,
              width: 140,
              icon: Icons.note_alt_rounded,
              label: 'Notes',
              color: const Color(0xFF009688),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LuxuryNotesScreen())),
            ),
            _buildQuickActionCard(
              context,
              width: 140,
              icon: Icons.school_rounded,
              label: 'Exam Prep',
              color: const Color(0xFF3B82F6),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExamDashboardScreen())),
            ),
          ]);
          break;
        case AppCategory.fitness:
          featureCards.add(
            _buildQuickActionCard(
              context,
              width: 140,
              icon: Icons.fitness_center_rounded,
              label: 'Fitness',
              color: AppColors.warning,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FitnessDashboardScreen())),
            ),
          );
          break;
        case AppCategory.finance:
          featureCards.add(
            _buildQuickActionCard(
              context,
              width: 140,
              icon: Icons.account_balance_wallet_rounded,
              label: 'Finance',
              color: const Color(0xFF22C55E),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FinanceDashboardScreen())),
            ),
          );
          break;
        case AppCategory.periodTracking:
          featureCards.add(
            _buildQuickActionCard(
              context,
              width: 140,
              icon: Icons.calendar_month_rounded,
              label: 'Period Tracking',
              color: AppColors.periodPrimary,
              onTap: () {
                final isPeriodEnabled = StorageService.isPeriodTrackingEnabled;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => isPeriodEnabled ? const PeriodOverviewScreen() : const PeriodIntroScreen(),
                  ),
                );
              },
            ),
          );
          break;
        case null:
          // Fallback: show basic features if no category selected
          featureCards.addAll([
            _buildQuickActionCard(
              context,
              width: 140,
              icon: Icons.medication_rounded,
              label: 'Medicine',
              color: AppColors.primary,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EnhancedMedicineDashboard())),
            ),
            _buildQuickActionCard(
              context,
              width: 140,
              icon: Icons.water_drop_rounded,
              label: 'Water',
              color: AppColors.info,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WaterDashboardScreen())),
            ),
          ]);
          break;
      }
      
      // Fun & Relax is always available (default category)
      featureCards.add(
        _buildQuickActionCard(
          context,
          width: 140,
          icon: Icons.spa_rounded,
          label: 'Fun & Relax',
          color: const Color(0xFFEC4899),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FunRelaxDashboard())),
        ),
      );
      
      return SizedBox(
        height: 100,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: featureCards.length,
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemBuilder: (context, index) => featureCards[index],
        ),
      );
    });
  }


  Widget _buildQuickActionCard(
    BuildContext context, {
    required double width,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = AppColors.isDark(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 140,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.15 : 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkElevatedCard : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(isDark ? 0.2 : 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFocusSessionBanner(BuildContext context) {
    final focusService = FocusService();
    
    return ListenableBuilder(
      listenable: focusService,
      builder: (context, _) {
        if (!focusService.isRunning) return const SizedBox.shrink();
        
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FocusScreen()),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  focusService.selectedPlant.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Focus Active • ${focusService.formattedTime} left',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    focusService.isPaused ? Icons.play_arrow_rounded : Icons.visibility_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFocusHomeSection(BuildContext context) {
    final focusService = FocusService();
    
    return ListenableBuilder(
      listenable: focusService,
      builder: (context, _) {
        // Don't show if there's an active session (we have the banner instead)
        if (focusService.isRunning) return const SizedBox.shrink();
        
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FocusHomeCard(),
            SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildTodayOverview(BuildContext context) {
    final isDark = AppColors.isDark(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: isDark ? Border.all(color: AppColors.darkBorder.withOpacity(0.2)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder(
            valueListenable: MedicineStorageService.medicinesListenable,
            builder: (context, box, _) {
              final activeMedicines = box.values.where((m) => !m.isArchived && m.isActive).length;
              final dueMedicines = box.values.where((m) {
                if (m.isArchived || !m.isActive) return false;
                final now = DateTime.now();
                return m.schedule.times.any((time) {
                  final scheduleTime = DateTime(
                    now.year, now.month, now.day,
                    time.hour, time.minute
                  );
                  return scheduleTime.isAfter(now) && 
                         scheduleTime.isBefore(now.add(const Duration(hours: 2)));
                });
              }).length;
              
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniStat("Medicine", "$dueMedicines due", Icons.medication_rounded, AppColors.primary),
                  _buildMiniStat("Focus", "0 done", Icons.self_improvement_rounded, const Color(0xFF8B5CF6)),
                  _buildMiniStat("Water", "0%", Icons.water_drop_rounded, AppColors.info),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineSummaryCard(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: MedicineStorageService.medicinesListenable,
      builder: (context, box, _) {
        final medicines = box.values.where((m) => !m.isArchived && m.isActive).toList();
        if (medicines.isEmpty) {
          return const SizedBox.shrink();
        }

        // Find next dose
        EnhancedMedicine? nextMedicine;
        String? nextDoseTime;
        
        final now = DateTime.now();
        DateTime? closestTime;
        
        for (final medicine in medicines) {
          for (final time in medicine.schedule.times) {
            final scheduleTime = DateTime(
              now.year, now.month, now.day,
              time.hour, time.minute
            );
            
            if (scheduleTime.isAfter(now)) {
              if (closestTime == null || scheduleTime.isBefore(closestTime)) {
                closestTime = scheduleTime;
                nextMedicine = medicine;
                nextDoseTime = time.formattedTime;
              }
            }
          }
        }
        
        final isDark = AppColors.isDark(context);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Next Medicine",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EnhancedMedicineDashboard(),
                      ),
                    );
                  },
                  child: Text(
                    "View All →",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (nextMedicine != null) ...
            [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.getCardBg(context),
                  borderRadius: BorderRadius.circular(14),
                  border: isDark ? Border.all(color: AppColors.darkBorder.withOpacity(0.2)) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          nextMedicine!.dosageForm.icon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nextMedicine!.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: AppColors.getTextSecondary(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                nextDoseTime!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${medicines.length} active",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...
            [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.getCardBg(context),
                  borderRadius: BorderRadius.circular(18),
                  border: isDark ? Border.all(color: AppColors.darkBorder.withOpacity(0.5)) : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "All medicines taken for today",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      "${medicines.length} active",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

}


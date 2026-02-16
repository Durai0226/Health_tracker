
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../medication/screens/add_medicine_flow.dart';
import '../../medication/screens/edit_medicine_screen.dart';
import '../../medication/screens/enhanced_medicine_dashboard.dart';
import '../../../core/services/storage_service.dart';
import '../../medication/models/medicine.dart';
import '../../health_check/models/health_check.dart';
import '../../health_check/screens/add_health_check_screen.dart';
import '../../water/screens/water_dashboard_screen.dart';
import '../../fitness/screens/fitness_dashboard_screen.dart';
import '../../period_tracking/screens/period_overview_screen.dart';
import '../../period_tracking/screens/period_intro_screen.dart';
import '../../focus/screens/focus_screen.dart';
import '../../focus/services/focus_service.dart';
import '../../focus/widgets/focus_home_card.dart';
import '../../focus/models/focus_plant.dart';
import '../../exam_prep/screens/exam_prep_screen.dart';
import 'package:intl/intl.dart';
import '../../settings/screens/settings_screen.dart';
import '../../notes/presentation/screens/notes_dashboard_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Premium Header with User Profile
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Row(
                children: [
                  // User Avatar
                  GestureDetector(
                    onTap: () => _showProfileMenu(context, authService),
                    child: Container(
                      width: 48,
                      height: 48,
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${_getGreeting()}, ${user?.name.split(' ').first ?? 'User'}!",
                          style: Theme.of(context).textTheme.titleLarge,
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
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
                      icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Slogan
                    Center(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 72,
                           child: SvgPicture.asset(
  'assets/images/logo.svg',
  height: 72,
  fit: BoxFit.contain,
),

                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Make Your Life Healthy",
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Add a reminder to stay consistent\nand prioritize your well-being",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                    // Active Focus Session Banner
                    _buildFocusSessionBanner(context),
                    
                    // Quick Actions Grid
                    _buildQuickActionsGrid(context),
                    const SizedBox(height: 24),
                    
                    // Focus Home Card
                    _buildFocusHomeSection(context),
                    
                    // Health Checks Section
                    ValueListenableBuilder(
                      valueListenable: StorageService.healthCheckListenable,
                      builder: (context, healthBox, _) {
                        final healthChecks = healthBox.values.toList();
                        if (healthChecks.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Health Checks', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ...healthChecks.map((check) => _buildHealthCheckCard(context, check)),
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    ),
                    
                    // Medicines Section
                    ValueListenableBuilder(
                      valueListenable: StorageService.listenable,
                      builder: (context, box, _) {
                        final medicines = box.values.toList();
                        if (medicines.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('My Medicines', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ...medicines.map((medicine) => _buildMedicineCard(context, medicine)),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () => _showAddReminderSheet(context),
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: const Icon(Icons.add_rounded, size: 32),
          ),
        ),
      ),
    );
  }


  void _showAddReminderSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            // Handle
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 32),
            // Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                "What would you like to add?",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            // Grid Options
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
              child: _buildGridOptions(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridOptions(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final itemWidth = (constraints.maxWidth - 16) / 2;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildGridCard(
            context,
            width: itemWidth,
            title: "Medicine",
            icon: Icons.medication_rounded,
            color: AppColors.primary,
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMedicineFlow()));
            },
          ),
          _buildGridCard(
            context,
            width: itemWidth,
            title: "Health Check",
            icon: Icons.monitor_heart_rounded,
            color: AppColors.error,
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddHealthCheckScreen()));
            },
          ),
          _buildGridCard(
            context,
            width: itemWidth,
            title: "Water",
            icon: Icons.water_drop_rounded,
            color: AppColors.info,
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => WaterDashboardScreen()));
            },
          ),
          _buildGridCard(
            context,
            width: itemWidth,
            title: "Fitness",
            icon: Icons.fitness_center_rounded,
            color: AppColors.warning,
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FitnessDashboardScreen()));
            },
          ),
          _buildGridCard(
            context,
            width: itemWidth,
            title: "Period Tracking",
            icon: Icons.calendar_month_rounded,
            color: AppColors.periodPrimary,
            onTap: () async {
              Navigator.pop(context);
              final isPeriodEnabled = StorageService.isPeriodTrackingEnabled;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => isPeriodEnabled ? const PeriodOverviewScreen() : const PeriodIntroScreen(),
                ),
              );
            },
          ),
        ],
      );
    });
  }

  Widget _buildGridCard(
    BuildContext context, {
    required double width,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
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
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
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
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  isGuest ? 'Guest User' : (user?.email ?? ''),
                  style: const TextStyle(color: AppColors.textSecondary),
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




  Widget _buildMedicineCard(BuildContext context, Medicine medicine) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EditMedicineScreen(medicine: medicine),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.medication_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('h:mm a').format(medicine.time),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${medicine.dosageAmount} ${medicine.dosageType}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Edit indicator
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final itemWidth = (constraints.maxWidth - 16) / 2;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildQuickActionCard(
            context,
            width: itemWidth,
            icon: Icons.medication_rounded,
            label: 'Medicine',
            color: AppColors.primary,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EnhancedMedicineDashboard())),
          ),
          _buildQuickActionCard(
            context,
            width: itemWidth,
            icon: Icons.monitor_heart_rounded,
            label: 'Health Check',
            color: AppColors.error,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddHealthCheckScreen())),
          ),
          _buildQuickActionCard(
            context,
            width: itemWidth,
            icon: Icons.water_drop_rounded,
            label: 'Water',
            color: AppColors.info,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WaterDashboardScreen())),
          ),
          _buildQuickActionCard(
            context,
            width: itemWidth,
            icon: Icons.fitness_center_rounded,
            label: 'Fitness',
            color: AppColors.warning,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FitnessDashboardScreen())),
          ),
          _buildQuickActionCard(
            context,
            width: itemWidth,
            icon: Icons.self_improvement_rounded,
            label: 'Focus',
            color: const Color(0xFF8B5CF6),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FocusScreen())),
          ),
          _buildQuickActionCard(
            context,
            width: itemWidth,
            icon: Icons.school_rounded,
            label: 'Exam Prep',
            color: const Color(0xFF1E88E5),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExamPrepScreen())),
          ),
          _buildQuickActionCard(
            context,
            width: itemWidth,
            icon: Icons.note_alt_rounded,
            label: 'Notes',
            color: const Color(0xFF009688),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotesDashboardScreen())),
          ),
        ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
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
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FocusScreen()),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF8B5CF6),
                  Color(0xFF7C3AED),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  focusService.selectedPlant.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Focus Session Active',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${focusService.formattedTime} remaining',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        focusService.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        focusService.isPaused ? 'Resume' : 'View',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
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

  Widget _buildHealthCheckCard(BuildContext context, HealthCheck check) {
    final color = check.type == 'sugar' ? AppColors.error : AppColors.periodPrimary;
    final emoji = check.type == 'sugar' ? '🩸' : '❤️';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddHealthCheckScreen(existingCheck: check),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    check.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('h:mm a').format(check.reminderTime),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        check.frequency,
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}


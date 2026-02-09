
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../medication/screens/add_medicine_flow.dart';
import '../../medication/screens/edit_medicine_screen.dart';
import '../../../core/services/storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../medication/models/medicine.dart';
import '../../health_check/models/health_check.dart';
import '../../health_check/screens/add_health_check_screen.dart';
import '../../water/screens/water_tracking_screen.dart';
import '../../fitness/screens/add_fitness_screen.dart';
import 'package:intl/intl.dart';
import '../../settings/screens/settings_screen.dart';

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
    final user = authService.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Premium Header with User Profile
            Container(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                            offset: Offset(0, 2),
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
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${_getGreeting()}, ${user?.name.split(' ').first ?? 'User'}!",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: 2),
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
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                      icon: Icon(Icons.settings_outlined, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Actions - Row 1
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickAction(
                            context,
                            icon: Icons.medication_rounded,
                            label: 'Medicine',
                            color: AppColors.primary,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const AddMedicineFlow()),
                              );
                            },
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickAction(
                            context,
                            icon: Icons.monitor_heart_rounded,
                            label: 'Health',
                            color: AppColors.error,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const AddHealthCheckScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    // Quick Actions - Row 2
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickAction(
                            context,
                            icon: Icons.water_drop_rounded,
                            label: 'Water',
                            color: AppColors.info,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const WaterTrackingScreen()),
                              );
                            },
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickAction(
                            context,
                            icon: Icons.fitness_center_rounded,
                            label: 'Fitness',
                            color: AppColors.warning,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const AddFitnessScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    
                    // Health Checks Section
                    ValueListenableBuilder(
                      valueListenable: StorageService.healthCheckListenable,
                      builder: (context, healthBox, _) {
                        final healthChecks = healthBox.values.toList();
                        if (healthChecks.isEmpty) return SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Health Checks', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            SizedBox(height: 12),
                            ...healthChecks.map((check) => _buildHealthCheckCard(context, check)),
                            SizedBox(height: 24),
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
                          return _buildEmptyState(context);
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('My Medicines', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            SizedBox(height: 12),
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
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddMedicineFlow()),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          label: Text("Add Medicine"),
          icon: Icon(Icons.add_rounded),
        ),
      ),
    );
  }

  Widget _buildAvatarInitials(String name) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Center(
      child: Text(
        initials,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
      ),
    );
  }

  void _showProfileMenu(BuildContext context, AuthService authService) {
    final user = authService.currentUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
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
              margin: EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Profile Info
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: user?.photoUrl != null
                  ? ClipOval(
                      child: Image.network(user!.photoUrl!, fit: BoxFit.cover),
                    )
                  : _buildAvatarInitials(user?.name ?? 'U'),
            ),
            SizedBox(height: 16),
            Text(
              user?.name ?? 'User',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              user?.email ?? '',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 32),
            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await authService.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
                  }
                },
                icon: Icon(Icons.logout_rounded, color: AppColors.error),
                label: Text("Sign Out", style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.medication_outlined,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 32),
            Text(
              "No medicines yet",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 12),
            Text(
              "Add your first medicine to start\ntracking your health routine",
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddMedicineFlow()),
                );
              },
              icon: Icon(Icons.add_rounded),
              label: Text("Add Medicine"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineList(BuildContext context, List<Medicine> medicines) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 100),
      itemCount: medicines.length,
      itemBuilder: (context, index) {
        final medicine = medicines[index];
        return _buildMedicineCard(context, medicine);
      },
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
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: Offset(0, 4),
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
                child: Icon(Icons.medication_rounded, color: Colors.white, size: 28),
              ),
              SizedBox(width: 16),
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
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                        SizedBox(width: 4),
                        Text(
                          DateFormat('h:mm a').format(medicine.time),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        SizedBox(width: 12),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${medicine.dosageAmount} ${medicine.dosageType}",
                            style: TextStyle(
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
              Icon(
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

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
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
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(emoji, style: TextStyle(fontSize: 28)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    check.title,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Text(
                        DateFormat('h:mm a').format(check.reminderTime),
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      SizedBox(width: 8),
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


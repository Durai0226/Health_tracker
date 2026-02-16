import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../medication/screens/add_medicine_flow.dart';
import '../../health_check/screens/add_health_check_screen.dart';
import '../../fitness/screens/add_fitness_screen.dart';
import '../../../features/settings/screens/notification_settings_screen.dart';
import 'reminders_screen.dart';

class AllRemindersScreen extends StatefulWidget {
  const AllRemindersScreen({super.key});

  @override
  State<AllRemindersScreen> createState() => _AllRemindersScreenState();
}

class _AllRemindersScreenState extends State<AllRemindersScreen> {
  int _totalReminders = 0;
  int _activeReminders = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _loadStats() {
    final medicines = StorageService.getAllMedicines();
    final healthChecks = StorageService.getAllHealthChecks();
    final fitnessReminders = StorageService.getAllFitnessReminders();
    final waterReminder = StorageService.getWaterReminder();
    final periodReminder = StorageService.getPeriodReminder();
    final reminders = StorageService.getAllReminders();

    int total = medicines.length + healthChecks.length + fitnessReminders.length + reminders.length;
    int active = medicines.where((m) => m.enableReminder).length +
        healthChecks.where((h) => h.enableReminder).length +
        fitnessReminders.where((f) => f.isEnabled).length +
        reminders.where((r) => !r.isCompleted).length;

    if (waterReminder != null && waterReminder.isEnabled) {
      total++;
      active++;
    }
    if (periodReminder != null && periodReminder.isEnabled) {
      total++;
      active++;
    }

    setState(() {
      _totalReminders = total;
      _activeReminders = active;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('All Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: AppColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadStats();
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildStatsCard(),
            const SizedBox(height: 24),
            _buildReminderTypeCard(
              icon: Icons.notifications_rounded,
              title: 'General Reminders',
              color: AppColors.secondary,
              count: StorageService.getAllReminders().length,
              activeCount: StorageService.getAllReminders().where((r) => !r.isCompleted).length,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RemindersScreen()),
                ).then((_) => _loadStats());
              },
            ),
            const SizedBox(height: 12),
            _buildReminderTypeCard(
              icon: Icons.medication_rounded,
              title: 'Medicine Reminders',
              color: AppColors.primary,
              count: StorageService.getAllMedicines().length,
              activeCount: StorageService.getAllMedicines().where((m) => m.enableReminder).length,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddMedicineFlow()),
                ).then((_) => _loadStats());
              },
            ),
            const SizedBox(height: 12),
            _buildReminderTypeCard(
              icon: Icons.favorite_rounded,
              title: 'Health Check Reminders',
              color: AppColors.error,
              count: StorageService.getAllHealthChecks().length,
              activeCount: StorageService.getAllHealthChecks().where((h) => h.enableReminder).length,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddHealthCheckScreen()),
                ).then((_) => _loadStats());
              },
            ),
            const SizedBox(height: 12),
            _buildReminderTypeCard(
              icon: Icons.fitness_center_rounded,
              title: 'Fitness Reminders',
              color: AppColors.warning,
              count: StorageService.getAllFitnessReminders().length,
              activeCount: StorageService.getAllFitnessReminders().where((f) => f.isEnabled).length,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddFitnessScreen()),
                ).then((_) => _loadStats());
              },
            ),
            const SizedBox(height: 12),
            _buildReminderTypeCard(
              icon: Icons.water_drop_rounded,
              title: 'Water Reminders',
              color: AppColors.info,
              count: StorageService.getWaterReminder() != null ? 1 : 0,
              activeCount: StorageService.getWaterReminder()?.isEnabled == true ? 1 : 0,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Go to Water Tracking to set up reminders'),
                    backgroundColor: AppColors.info,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildReminderTypeCard(
              icon: Icons.calendar_today_rounded,
              title: 'Period Reminders',
              color: AppColors.periodPrimary,
              count: StorageService.getPeriodReminder() != null ? 1 : 0,
              activeCount: StorageService.getPeriodReminder()?.isEnabled == true ? 1 : 0,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Go to Period Tracking to set up reminders'),
                    backgroundColor: AppColors.periodPrimary,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.notifications_active_rounded,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            '$_activeReminders Active',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'out of $_totalReminders total reminders',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildQuickStat(Icons.check_circle_rounded, '$_activeReminders', 'Active'),
              const SizedBox(width: 32),
              _buildQuickStat(Icons.cancel_rounded, '${_totalReminders - _activeReminders}', 'Disabled'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildReminderTypeCard({
    required IconData icon,
    required String title,
    required Color color,
    required int count,
    required int activeCount,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$activeCount active • $count total',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

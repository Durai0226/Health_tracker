import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../medication/screens/nunito_medication_dashboard.dart';
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
  int _medicineCount = 0;
  int _reminderCount = 0;
  int _reminderActive = 0;
  bool _hasWaterReminder = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final medicines = CleanStorageService.getAllMedicines();
    final reminders = CleanStorageService.getReminders();

    final medicineCount = medicines.length;
    final reminderCount = reminders.length;
    final reminderActive = reminders.where((r) => !r.isCompleted).length;

    int total = medicineCount + reminderCount;
    int active = reminderActive;

    // Add water reminder (async)
    final waterReminder = await CleanStorageService.getWaterReminder();
    final hasWater = waterReminder != null;
    if (hasWater) {
      total++;
      active++;
    }

    if (mounted) {
      setState(() {
        _totalReminders = total;
        _activeReminders = active;
        _medicineCount = medicineCount;
        _reminderCount = reminderCount;
        _reminderActive = reminderActive;
        _hasWaterReminder = hasWater;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('All Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Symbols.settings_rounded, color: AppColors.primary),
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
              icon: Symbols.notifications_rounded,
              title: 'General Reminders',
              color: AppColors.secondary,
              count: _reminderCount,
              activeCount: _reminderActive,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RemindersScreen()),
                ).then((_) => _loadStats());
              },
            ),
            const SizedBox(height: 12),
            _buildReminderTypeCard(
              icon: Symbols.medication_rounded,
              title: 'Medicine Reminders',
              color: AppColors.primary,
              count: _medicineCount,
              activeCount: _medicineCount,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NunitoMedicationDashboard()),
                ).then((_) => _loadStats());
              },
            ),
            const SizedBox(height: 12),
            _buildReminderTypeCard(
              icon: Symbols.water_drop_rounded,
              title: 'Water Reminders',
              color: AppColors.info,
              count: _hasWaterReminder ? 1 : 0,
              activeCount: _hasWaterReminder ? 1 : 0,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Go to Water Tracking to set up reminders'),
                    backgroundColor: AppColors.info,
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
            Symbols.notifications_active_rounded,
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
              _buildQuickStat(Symbols.check_circle_rounded, '$_activeReminders', 'Active'),
              const SizedBox(width: 32),
              _buildQuickStat(Symbols.cancel_rounded, '${_totalReminders - _activeReminders}', 'Disabled'),
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
              Symbols.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

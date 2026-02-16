import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../medication/models/medicine.dart';

class ReminderAnalysisScreen extends StatefulWidget {
  const ReminderAnalysisScreen({super.key});

  @override
  State<ReminderAnalysisScreen> createState() => _ReminderAnalysisScreenState();
}

class _ReminderAnalysisScreenState extends State<ReminderAnalysisScreen> {
  int _selectedPeriod = 7; // Days

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reminder Analysis',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 24),
          _buildPeriodSelector(),
          const SizedBox(height: 24),
          _buildStatisticsCard(),
          const SizedBox(height: 24),
          _buildReminderBreakdown(),
          const SizedBox(height: 24),
          _buildUpcomingReminders(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withOpacity(0.1),
            AppColors.success.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.analytics_outlined,
              color: AppColors.success,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reminder Insights',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Track your reminder patterns and adherence',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildPeriodButton('7 Days', 7),
          _buildPeriodButton('30 Days', 30),
          _buildPeriodButton('90 Days', 90),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, int days) {
    final isSelected = _selectedPeriod == days;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = days),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final medicines = StorageService.getAllMedicines();
    final healthChecks = StorageService.getAllHealthChecks();
    final fitnessReminders = StorageService.getAllFitnessReminders();
    final waterReminder = StorageService.getWaterReminder();
    final periodReminder = StorageService.getPeriodReminder();

    final totalReminders = medicines.length + 
                          healthChecks.length + 
                          fitnessReminders.length +
                          (waterReminder != null && waterReminder.isEnabled ? 1 : 0) +
                          (periodReminder != null && periodReminder.isEnabled ? 1 : 0);

    final activeReminders = medicines.where((m) => m.enableReminder).length +
                           healthChecks.where((h) => h.enableReminder).length +
                           fitnessReminders.where((f) => f.isEnabled).length +
                           (waterReminder != null && waterReminder.isEnabled ? 1 : 0) +
                           (periodReminder != null && periodReminder.isEnabled ? 1 : 0);

    final adherenceRate = totalReminders > 0 ? (activeReminders / totalReminders * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatItem('Total', '$totalReminders', AppColors.primary, Icons.notifications_rounded),
              const SizedBox(width: 16),
              _buildStatItem('Active', '$activeReminders', AppColors.success, Icons.notifications_active_rounded),
              const SizedBox(width: 16),
              _buildStatItem('Rate', '$adherenceRate%', AppColors.warning, Icons.trending_up_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderBreakdown() {
    final medicines = StorageService.getAllMedicines().where((m) => m.enableReminder).length;
    final healthChecks = StorageService.getAllHealthChecks().where((h) => h.enableReminder).length;
    final fitness = StorageService.getAllFitnessReminders().where((f) => f.isEnabled).length;
    final water = StorageService.getWaterReminder()?.isEnabled == true ? 1 : 0;
    final period = StorageService.getPeriodReminder()?.isEnabled == true ? 1 : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reminder Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildBreakdownItem('Medicine', medicines, AppColors.primary, Icons.medication_rounded),
          _buildBreakdownItem('Health Check', healthChecks, AppColors.error, Icons.favorite_rounded),
          _buildBreakdownItem('Fitness', fitness, AppColors.success, Icons.fitness_center_rounded),
          _buildBreakdownItem('Water', water, AppColors.info, Icons.water_drop_rounded),
          _buildBreakdownItem('Period', period, AppColors.periodPrimary, Icons.calendar_today_rounded),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(String label, int count, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingReminders() {
    final medicines = StorageService.getAllMedicines()
        .where((m) => m.enableReminder)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Today\'s Schedule',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (medicines.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No reminders scheduled for today',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...medicines.take(5).map((medicine) => _buildUpcomingReminderItem(medicine)),
        ],
      ),
    );
  }

  Widget _buildUpcomingReminderItem(Medicine medicine) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              DateFormat('h:mm a').format(medicine.time),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${medicine.dosageAmount} ${medicine.dosageType}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.medication_rounded, color: AppColors.primary, size: 20),
        ],
      ),
    );
  }
}

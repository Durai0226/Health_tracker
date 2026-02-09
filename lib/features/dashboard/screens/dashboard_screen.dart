
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../medication/models/medicine.dart';
import '../../health_check/models/health_check.dart';
import '../../water/models/water_intake.dart';
import '../../fitness/models/fitness_reminder.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final medicines = StorageService.getAllMedicines();
    final healthChecks = StorageService.getAllHealthChecks();
    final waterIntake = StorageService.getTodayWaterIntake();
    final fitnessReminders = StorageService.getAllFitnessReminders();
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(today),
                SizedBox(height: 24),

                // Hero Card with Teal Theme
                _buildHeroCard(medicines, waterIntake),
                SizedBox(height: 20),

                // Stats Grid
                _buildStatsGrid(medicines, healthChecks, waterIntake, fitnessReminders),
                SizedBox(height: 28),

                // Weekly Progress
                _buildSectionHeader('Weekly Progress'),
                SizedBox(height: 14),
                _buildWeeklyProgress(),
                SizedBox(height: 28),

                // Today's Schedule
                _buildSectionHeader('Today\'s Schedule'),
                SizedBox(height: 14),
                _buildScheduleList(medicines, healthChecks, fitnessReminders),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(DateTime today) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 4),
            Text(
              DateFormat('EEEE, MMMM d').format(today),
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Container(
          padding: EdgeInsets.all(14),
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
          child: Icon(Icons.insights_rounded, color: Colors.white, size: 24),
        ),
      ],
    );
  }

  Widget _buildHeroCard(List<Medicine> medicines, WaterIntake? waterIntake) {
    final total = medicines.length;
    final taken = total > 0 ? (total * 0.67).round() : 0;
    final medProgress = total > 0 ? taken / total : 0.0;
    final waterProgress = waterIntake?.progress ?? 0.0;
    final overallProgress = (medProgress + waterProgress) / 2;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, AppColors.primaryLight.withOpacity(0.3)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Progress Ring
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: overallProgress,
                    strokeWidth: 10,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(overallProgress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'overall',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 24),
          // Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Progress',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16),
                _buildHeroStat('💊', 'Medicines', '$taken / $total', medProgress),
                SizedBox(height: 10),
                _buildHeroStat('💧', 'Water', '${(waterProgress * 100).round()}%', waterProgress),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String emoji, String label, String value, double progress) {
    return Row(
      children: [
        Text(emoji, style: TextStyle(fontSize: 16)),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(List<Medicine> medicines, List<HealthCheck> healthChecks, 
                          WaterIntake? waterIntake, List<FitnessReminder> fitnessReminders) {
    final waterMl = waterIntake?.currentIntakeMl ?? 0;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard(
              icon: Icons.medication_rounded,
              color: AppColors.primary,
              value: '${medicines.length}',
              label: 'Active Meds',
            )),
            SizedBox(width: 12),
            Expanded(child: _buildStatCard(
              icon: Icons.favorite_rounded,
              color: AppColors.error,
              value: '${healthChecks.length}',
              label: 'Health Checks',
            )),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard(
              icon: Icons.water_drop_rounded,
              color: AppColors.info,
              value: '${(waterMl / 1000).toStringAsFixed(1)}L',
              label: 'Water Today',
            )),
            SizedBox(width: 12),
            Expanded(child: _buildStatCard(
              icon: Icons.fitness_center_rounded,
              color: AppColors.warning,
              value: '${fitnessReminders.length}',
              label: 'Workouts',
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildWeeklyProgress() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final todayIndex = now.weekday - 1;
    final adherence = [0.9, 1.0, 0.8, 0.75, 0.5, 0.0, 0.0];

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, AppColors.primaryLight.withOpacity(0.3)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Progress bars for each day
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final isToday = index == todayIndex;
              final isPast = index < todayIndex;
              final value = adherence[index];
              return _buildDayBar(days[index], value, isToday, isPast);
            }),
          ),
          SizedBox(height: 20),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(AppColors.success, 'Completed'),
              SizedBox(width: 20),
              _buildLegend(AppColors.primary, 'Today'),
              SizedBox(width: 20),
              _buildLegend(AppColors.warning, 'Partial'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayBar(String day, double value, bool isToday, bool isPast) {
    final maxHeight = 70.0;
    final barHeight = isPast ? (value * maxHeight) : (isToday ? maxHeight * 0.5 : 8.0);
    
    Color barColor;
    if (isToday) {
      barColor = AppColors.primary;
    } else if (isPast && value >= 0.8) {
      barColor = AppColors.success;
    } else if (isPast) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.border;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Percentage label for past/today
        if (isPast || isToday)
          Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: barColor,
              ),
            ),
          ),
        // Bar
        AnimatedContainer(
          duration: Duration(milliseconds: 500),
          width: 28,
          height: barHeight,
          decoration: BoxDecoration(
            gradient: (isPast || isToday)
                ? LinearGradient(
                    colors: [barColor, barColor.withOpacity(0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: (!isPast && !isToday) ? barColor : null,
            borderRadius: BorderRadius.circular(8),
            boxShadow: (isPast || isToday)
                ? [
                    BoxShadow(
                      color: barColor.withOpacity(0.3),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
        ),
        SizedBox(height: 10),
        // Day label
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isToday ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            day,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
              color: isToday ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleList(List<Medicine> medicines, List<HealthCheck> healthChecks, List<FitnessReminder> fitnessReminders) {
    if (medicines.isEmpty && healthChecks.isEmpty && fitnessReminders.isEmpty) {
      return Container(
        padding: EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.calendar_today_rounded, size: 48, color: AppColors.textLight),
            SizedBox(height: 12),
            Text(
              'No schedule yet',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ...medicines.take(3).map((m) => Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: _buildScheduleCard(
            icon: Icons.medication_rounded,
            color: AppColors.primary,
            title: m.name,
            subtitle: '${m.dosageAmount} ${m.dosageType}',
            time: DateFormat('h:mm a').format(m.time),
          ),
        )),
        ...healthChecks.take(2).map((h) => Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: _buildScheduleCard(
            icon: Icons.favorite_rounded,
            color: AppColors.error,
            title: h.title,
            subtitle: h.frequency,
            time: DateFormat('h:mm a').format(h.reminderTime),
          ),
        )),
        ...fitnessReminders.take(2).map((f) => Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: _buildScheduleCard(
            icon: Icons.fitness_center_rounded,
            color: AppColors.warning,
            title: f.title,
            subtitle: '${f.durationMinutes} min • ${f.frequency}',
            time: DateFormat('h:mm a').format(f.reminderTime),
          ),
        )),
      ],
    );
  }

  Widget _buildScheduleCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              time,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

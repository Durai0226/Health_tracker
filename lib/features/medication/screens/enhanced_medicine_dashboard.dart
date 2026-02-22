import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/vitavibe_service.dart';
import '../../../core/widgets/common_tab_widgets.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../services/medicine_storage_service.dart';
import '../services/drug_interaction_service.dart';
import 'add_medicine_wizard.dart';
import 'medicine_detail_screen.dart';
import 'medicine_history_screen.dart';

/// Premium Medicine Dashboard - Medisafe/Apple Health style
class EnhancedMedicineDashboard extends StatefulWidget {
  const EnhancedMedicineDashboard({super.key});

  @override
  State<EnhancedMedicineDashboard> createState() => _EnhancedMedicineDashboardState();
}

class _EnhancedMedicineDashboardState extends State<EnhancedMedicineDashboard> with SingleTickerProviderStateMixin {
  List<EnhancedMedicine> _medicines = [];
  List<_ScheduledDose> _todaysDoses = [];
  final Map<String, bool> _takenStatus = {};
  bool _isLoading = true;
  int _streak = 0;
  double _adherenceRate = 0.0;
  List<EnhancedMedicine> _lowStockMedicines = [];
  List<EnhancedMedicine> _expiringMedicines = [];
  final HapticService _hapticService = HapticService();
  final VitaVibeService _vitaVibeService = VitaVibeService();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _medicines = MedicineStorageService.getAllMedicines();
      _lowStockMedicines = MedicineStorageService.getLowStockMedicines();
      _expiringMedicines = MedicineStorageService.getExpiringMedicines();
      _streak = MedicineStorageService.getCurrentStreak();
      
      final stats = MedicineStorageService.getAdherenceStats();
      _adherenceRate = (stats['adherenceRate'] as int) / 100.0;

      // Build today's schedule
      _buildTodaySchedule();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _buildTodaySchedule() {
    _todaysDoses = [];
    final now = DateTime.now();
    final todayLogs = MedicineStorageService.getLogsForDate(now);

    for (final medicine in _medicines) {
      if (medicine.isPRN) continue;
      
      final times = medicine.schedule.getScheduledTimesForDate(now);
      for (final time in times) {
        final isTaken = todayLogs.any((log) => 
          log.medicineId == medicine.id && 
          log.scheduledTime.hour == time.hour &&
          log.scheduledTime.minute == time.minute &&
          log.isTaken
        );
        
        _todaysDoses.add(_ScheduledDose(
          medicine: medicine,
          scheduledTime: time,
          isTaken: isTaken,
        ));
        _takenStatus['${medicine.id}_${time.hour}_${time.minute}'] = isTaken;
      }
    }

    // Sort by time
    _todaysDoses.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  int get _takenToday => _todaysDoses.where((d) => d.isTaken).length;
  int get _totalToday => _todaysDoses.length;
  double get _todayProgress => _totalToday > 0 ? _takenToday / _totalToday : 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildAppBar(),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildProgressCard(),
                        _buildQuickStats(),
                        _buildAlerts(),
                        _buildTabSection(),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddMedicineWizard()),
        ).then((_) => _loadData()),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Medicine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.history_rounded, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MedicineHistoryScreen()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onPressed: _showMoreOptions,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Medicine Tracker',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                right: 40,
                bottom: 60,
                child: Icon(
                  Icons.medication_rounded,
                  size: 60,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Circular progress
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        value: _todayProgress,
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_takenToday/$_totalToday',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'taken',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE').format(DateTime.now()),
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _todayProgress >= 1 
                          ? 'All done! 🎉' 
                          : '${_totalToday - _takenToday} remaining',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_todayProgress * 100).toInt()}% complete',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.local_fire_department_rounded,
              value: '$_streak',
              label: 'Day Streak',
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.trending_up_rounded,
              value: '${(_adherenceRate * 100).toInt()}%',
              label: 'Adherence',
              color: _adherenceRate >= 0.8 ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.medication_rounded,
              value: '${_medicines.length}',
              label: 'Medicines',
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlerts() {
    final hasAlerts = _lowStockMedicines.isNotEmpty || _expiringMedicines.isNotEmpty;
    if (!hasAlerts) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (_lowStockMedicines.isNotEmpty)
            _buildAlertCard(
              icon: Icons.inventory_2_rounded,
              title: 'Low Stock Alert',
              subtitle: '${_lowStockMedicines.length} medicine(s) running low',
              color: AppColors.warning,
              onTap: () => _showLowStockDetails(),
            ),
          if (_expiringMedicines.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildAlertCard(
              icon: Icons.event_rounded,
              title: 'Expiring Soon',
              subtitle: '${_expiringMedicines.length} medicine(s) expiring',
              color: AppColors.error,
              onTap: () => _showExpiringDetails(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: color.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical:20),
      child: Column(
        children: [
          CommonCard(
            child: CommonTabBar(
              tabs: const ['Today', 'Upcoming', 'All Meds'],
              controller: _tabController,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: BoxConstraints(
              minHeight: 200,
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildTodayTab(),
                _buildUpcomingTab(),
                _buildAllMedsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTab() {
    if (_todaysDoses.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'No medicines scheduled',
        subtitle: 'Add your first medicine to start tracking',
      );
    }

    final now = DateTime.now();
    final upcoming = _todaysDoses.where((d) => !d.isTaken && d.scheduledTime.isAfter(now)).toList();
    final past = _todaysDoses.where((d) => !d.isTaken && d.scheduledTime.isBefore(now)).toList();
    final taken = _todaysDoses.where((d) => d.isTaken).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (upcoming.isNotEmpty) ...[
          _buildSectionHeader('Upcoming', upcoming.length),
          ...upcoming.map((dose) => _buildDoseCard(dose)),
        ],
        if (past.isNotEmpty) ...[
          _buildSectionHeader('Overdue', past.length, color: AppColors.error),
          ...past.map((dose) => _buildDoseCard(dose, isOverdue: true)),
        ],
        if (taken.isNotEmpty) ...[
          _buildSectionHeader('Completed', taken.length, color: AppColors.success),
          ...taken.map((dose) => _buildDoseCard(dose)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (color ?? AppColors.primary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color ?? AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoseCard(_ScheduledDose dose, {bool isOverdue = false}) {
    final statusColor = dose.isTaken 
        ? AppColors.success 
        : (isOverdue ? AppColors.error : AppColors.primary);
    
    final now = DateTime.now();
    final scheduledDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      dose.scheduledTime.hour,
      dose.scheduledTime.minute,
    );
    final canTakeNow = now.isAfter(scheduledDateTime) || now.isAtSameMomentAs(scheduledDateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: dose.isTaken 
            ? Border.all(color: AppColors.success.withOpacity(0.3))
            : (isOverdue ? Border.all(color: AppColors.error.withOpacity(0.3)) : null),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              dose.medicine.dosageForm.icon,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.medicine.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    decoration: dose.isTaken ? TextDecoration.lineThrough : null,
                    color: dose.isTaken ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('h:mm a').format(dose.scheduledTime),
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      dose.medicine.displayDosage,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!dose.isTaken && canTakeNow)
            GestureDetector(
              onTap: () => _takeDose(dose),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Take',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else if (!dose.isTaken && !canTakeNow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, size: 14, color: AppColors.info),
                  const SizedBox(width: 4),
                  Text(
                    'Scheduled',
                    style: TextStyle(
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: AppColors.success, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildUpcomingTab() {
    // Show next 7 days
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: 7,
      itemBuilder: (context, index) {
        final date = DateTime.now().add(Duration(days: index + 1));
        final doses = _getMedicinesForDate(date);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('d').format(date),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      DateFormat('E').format(date),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE').format(date),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${doses.length} dose(s) scheduled',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAllMedsTab() {
    if (_medicines.isEmpty) {
      return _buildEmptyState(
        icon: Icons.medication_outlined,
        title: 'No medicines added',
        subtitle: 'Tap the button below to add your first medicine',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _medicines.length,
      itemBuilder: (context, index) {
        final medicine = _medicines[index];
        return _buildMedicineListItem(medicine);
      },
    );
  }

  Widget _buildMedicineListItem(EnhancedMedicine medicine) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MedicineDetailScreen(medicineId: medicine.id),
        ),
      ).then((_) => _loadData()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: medicine.color != null
                    ? Color(medicine.color!.colorValue).withOpacity(0.2)
                    : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(medicine.dosageForm.icon, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        medicine.displayDosage,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        medicine.schedule.frequencyDescription,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  if (medicine.isLowStock) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${medicine.currentStock} left',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<EnhancedMedicine> _getMedicinesForDate(DateTime date) {
    return _medicines.where((m) => m.schedule.isActiveOnDate(date)).toList();
  }

  Future<void> _takeDose(_ScheduledDose dose) async {
    _hapticService.medicineTaken();
    _vitaVibeService.medicineTaken();
    
    await MedicineStorageService.markMedicineTaken(
      medicineId: dose.medicine.id,
      scheduledTime: dose.scheduledTime,
      dosageTaken: dose.medicine.dosageAmount,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Text('${dose.medicine.name} marked as taken'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadData();
    }
  }

  void _showLowStockDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2_rounded, color: AppColors.warning),
                SizedBox(width: 8),
                Text('Low Stock', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ..._lowStockMedicines.map((m) => ListTile(
              leading: Text(m.dosageForm.icon, style: const TextStyle(fontSize: 24)),
              title: Text(m.name),
              subtitle: Text('${m.currentStock} ${m.dosageForm.unit} remaining'),
              trailing: Text(
                '~${m.estimatedDaysRemaining} days',
                style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showExpiringDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.event_rounded, color: AppColors.error),
                SizedBox(width: 8),
                Text('Expiring Soon', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ..._expiringMedicines.map((m) => ListTile(
              leading: Text(m.dosageForm.icon, style: const TextStyle(fontSize: 24)),
              title: Text(m.name),
              subtitle: Text(
                m.expiryDate != null 
                    ? 'Expires ${DateFormat('MMM d, yyyy').format(m.expiryDate!)}'
                    : 'No expiry date',
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people_rounded),
              title: const Text('Family Members'),
              subtitle: const Text('Manage dependents'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.local_hospital_rounded),
              title: const Text('Doctors & Pharmacies'),
              subtitle: const Text('Manage healthcare providers'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('Export Report'),
              subtitle: const Text('Generate PDF for doctor'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded),
              title: const Text('Drug Interactions'),
              subtitle: const Text('Check your current medications'),
              onTap: () {
                Navigator.pop(context);
                _checkAllInteractions();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _checkAllInteractions() {
    final drugNames = _medicines.map((m) => m.name).toList();
    final interactions = DrugInteractionService().checkAllInteractions(drugNames);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Drug Interactions'),
        content: interactions.isEmpty
            ? const Text('No known interactions between your current medications.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: interactions.length,
                  itemBuilder: (context, index) {
                    final interaction = interactions[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(interaction.severity).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getSeverityColor(interaction.severity),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  interaction.severity.displayName,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${interaction.drug1Name} + ${interaction.drug2Name}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            interaction.description,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(InteractionSeverity severity) {
    switch (severity) {
      case InteractionSeverity.mild:
        return AppColors.info;
      case InteractionSeverity.moderate:
        return AppColors.warning;
      case InteractionSeverity.severe:
        return AppColors.error;
      case InteractionSeverity.contraindicated:
        return Colors.purple;
    }
  }
}

class _ScheduledDose {
  final EnhancedMedicine medicine;
  final DateTime scheduledTime;
  final bool isTaken;

  _ScheduledDose({
    required this.medicine,
    required this.scheduledTime,
    required this.isTaken,
  });
}

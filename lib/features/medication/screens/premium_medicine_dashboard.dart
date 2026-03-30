import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/haptic_service.dart';
import '../models/enhanced_medicine.dart';
import '../services/medicine_storage_service.dart'; // Updated from local_storage
import '../services/pdf_report_service.dart';
import 'premium_add_medicine_screen.dart';
import 'medicine_detail_screen.dart';
import 'medicine_history_screen.dart';
import 'doctors/doctor_list_screen.dart';
import 'pharmacies/pharmacy_list_screen.dart';
import 'dependents/dependent_list_screen.dart';

/// Premium Medicine Dashboard - Asklepios/Medisafe inspired design
/// Features: Glassmorphism, Timeline view, Adherence tracking, Modern animations
class PremiumMedicineDashboard extends StatefulWidget {
  const PremiumMedicineDashboard({super.key});

  @override
  State<PremiumMedicineDashboard> createState() => _PremiumMedicineDashboardState();
}

class _PremiumMedicineDashboardState extends State<PremiumMedicineDashboard>
    with TickerProviderStateMixin {
  List<EnhancedMedicine> _medicines = [];
  List<_ScheduledDose> _todaysDoses = [];
  final Map<String, bool> _takenStatus = {};
  bool _isLoading = true;
  int _streak = 0;
  double _adherenceRate = 0.0;
  int _selectedDayIndex = 0; // 0 = today

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  final HapticService _hapticService = HapticService();
  final ScrollController _scrollController = ScrollController();

  // Medication theme colors
  static const Color _medicationPrimary = Color(0xFF00BFA5);
  static const Color _medicationSecondary = Color(0xFF00897B);
  // Medication accent for future use

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadData();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await MedicineCleanStorageService.init();
      _medicines = await MedicineCleanStorageService.getAllMedicines();
      _streak = await MedicineCleanStorageService.getCurrentStreak();
      final stats = await MedicineCleanStorageService.getAdherenceStats();
      _adherenceRate = (stats['adherenceRate'] as int) / 100.0;

      await _buildTodaySchedule(); // Updated to await
      _fadeController.forward();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _buildTodaySchedule() async { // Changed to Future
    _todaysDoses = [];
    final targetDate = DateTime.now().add(Duration(days: _selectedDayIndex));
    final logs = await MedicineCleanStorageService.getLogsForDate(targetDate); // Async

    for (final medicine in _medicines) {
      if (medicine.isPRN || !medicine.isActive) continue;

      final times = medicine.schedule.getScheduledTimesForDate(targetDate);
      for (final time in times) {
        final isTaken = logs.any((log) =>
            log.medicineId == medicine.id &&
            log.scheduledTime.hour == time.hour &&
            log.scheduledTime.minute == time.minute &&
            log.isTaken);

        _todaysDoses.add(_ScheduledDose(
          medicine: medicine,
          scheduledTime: time,
          isTaken: isTaken,
        ));
        _takenStatus['${medicine.id}_${time.hour}_${time.minute}'] = isTaken;
      }
    }

    _todaysDoses.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  int get _takenToday => _todaysDoses.where((d) => d.isTaken).length;
  int get _totalToday => _todaysDoses.length;
  double get _todayProgress => _totalToday > 0 ? _takenToday / _totalToday : 0;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF0F4F8),
      body: _isLoading
          ? _buildLoadingState()
          : Stack(
              children: [
                // Background gradient
                _buildBackgroundGradient(isDark),
                
                // Main content
                SafeArea(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        _buildAppBar(isDark),
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              _buildProgressHero(isDark),
                              _buildQuickStats(isDark),
                              _buildDaySelector(isDark),
                              _buildTimelineSection(isDark),
                              _buildMedicineList(isDark),
                              const SizedBox(height: 120),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _medicationPrimary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(_medicationPrimary),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading your medicines...',
            style: TextStyle(
              color: AppColors.getTextSecondary(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGradient(bool isDark) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0A1628),
                    const Color(0xFF0F2027),
                    const Color(0xFF0A1628),
                  ]
                : [
                    const Color(0xFFF0F4F8),
                    const Color(0xFFE8F5E9),
                    const Color(0xFFF0F4F8),
                  ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 60,
      floating: true,
      pinned: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.history_rounded,
              size: 20,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MedicineHistoryScreen()),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.more_horiz_rounded,
              size: 20,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          onPressed: _showMoreOptions,
        ),
        const SizedBox(width: 16),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Medications',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 60, bottom: 16),
      ),
    );
  }

  Widget _buildProgressHero(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _medicationPrimary,
                  _medicationSecondary,
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: _medicationPrimary.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Circular progress
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.15),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 85,
                              height: 85,
                              child: CircularProgressIndicator(
                                value: _todayProgress,
                                strokeWidth: 8,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                valueColor: const AlwaysStoppedAnimation(Colors.white),
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${(_todayProgress * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Complete',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, MMM d').format(DateTime.now()),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _todayProgress >= 1
                                ? 'All done! Great job! 🎉'
                                : _totalToday == 0
                                    ? 'No medications today'
                                    : '${_totalToday - _takenToday} dose${_totalToday - _takenToday == 1 ? '' : 's'} remaining',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildMiniStat('$_takenToday/$_totalToday', 'Taken'),
                              const SizedBox(width: 16),
                              _buildMiniStat('$_streak', 'Day streak'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(bool isDark) {
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
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.trending_up_rounded,
              value: '${(_adherenceRate * 100).toInt()}%',
              label: 'Adherence',
              color: _adherenceRate >= 0.8 ? AppColors.success : AppColors.warning,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.medication_rounded,
              value: '${_medicines.length}',
              label: 'Active Meds',
              color: _medicationPrimary,
              isDark: isDark,
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
    required bool isDark,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaySelector(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 75,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              itemBuilder: (context, index) {
                final date = DateTime.now().add(Duration(days: index));
                final isSelected = _selectedDayIndex == index;
                final isToday = index == 0;

                return GestureDetector(
                  onTap: () {
                    _hapticService.light();
                    setState(() {
                      _selectedDayIndex = index;
                    });
                    _buildTodaySchedule().then((_) => setState(() {}));
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    width: 55,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [_medicationPrimary, _medicationSecondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected
                          ? null
                          : isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: isToday && !isSelected
                          ? Border.all(color: _medicationPrimary, width: 2)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _medicationPrimary.withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(date).substring(0, 3),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.white.withOpacity(0.8)
                                : isDark
                                    ? Colors.white60
                                    : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('d').format(date),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : isDark
                                    ? Colors.white
                                    : AppColors.textPrimary,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(height: 4),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? Colors.white : _medicationPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(bool isDark) {
    if (_todaysDoses.isEmpty) {
      return _buildEmptyDosesState(isDark);
    }

    final now = DateTime.now();
    final upcoming = _todaysDoses.where((d) => !d.isTaken && d.scheduledTime.isAfter(now)).toList();
    final overdue = _todaysDoses.where((d) => !d.isTaken && d.scheduledTime.isBefore(now)).toList();
    final completed = _todaysDoses.where((d) => d.isTaken).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overdue.isNotEmpty) ...[
            _buildSectionHeader('Overdue', overdue.length, AppColors.error, isDark),
            ...overdue.map((dose) => _buildDoseCard(dose, isOverdue: true, isDark: isDark)),
            const SizedBox(height: 16),
          ],
          if (upcoming.isNotEmpty) ...[
            _buildSectionHeader('Upcoming', upcoming.length, _medicationPrimary, isDark),
            ...upcoming.map((dose) => _buildDoseCard(dose, isDark: isDark)),
            const SizedBox(height: 16),
          ],
          if (completed.isNotEmpty) ...[
            _buildSectionHeader('Completed', completed.length, AppColors.success, isDark),
            ...completed.map((dose) => _buildDoseCard(dose, isDark: isDark)),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyDosesState(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _medicationPrimary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.medication_outlined,
              size: 48,
              color: _medicationPrimary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _selectedDayIndex == 0 ? 'No medications scheduled today' : 'No medications for this day',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a medication to start tracking',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoseCard(_ScheduledDose dose, {bool isOverdue = false, required bool isDark}) {
    final statusColor = dose.isTaken
        ? AppColors.success
        : (isOverdue ? AppColors.error : _medicationPrimary);

    final now = DateTime.now();
    final scheduledDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      dose.scheduledTime.hour,
      dose.scheduledTime.minute,
    );
    final canTakeNow = _selectedDayIndex == 0 && 
        (now.isAfter(scheduledDateTime) || now.isAtSameMomentAs(scheduledDateTime));

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MedicineDetailScreen(medicineId: dose.medicine.id),
          ),
        ).then((_) => _loadData());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: dose.isTaken
                      ? AppColors.success.withOpacity(0.3)
                      : isOverdue
                          ? AppColors.error.withOpacity(0.3)
                          : isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Medicine icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor.withOpacity(0.2),
                          statusColor.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        dose.medicine.dosageForm.icon,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Medicine info
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
                            color: dose.isTaken
                                ? (isDark ? Colors.white38 : AppColors.textSecondary)
                                : (isDark ? Colors.white : AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('h:mm a').format(dose.scheduledTime),
                              style: TextStyle(
                                fontSize: 13,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                dose.medicine.displayDosage,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Action button
                  if (!dose.isTaken && canTakeNow)
                    _buildTakeButton(dose)
                  else if (!dose.isTaken && !canTakeNow)
                    _buildScheduledBadge(isDark)
                  else
                    _buildCompletedBadge(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTakeButton(_ScheduledDose dose) {
    return GestureDetector(
      onTap: () => _takeDose(dose),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_medicationPrimary, _medicationSecondary],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _medicationPrimary.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Text(
          'Take',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildScheduledBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
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
    );
  }

  Widget _buildCompletedBadge() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_rounded,
        color: AppColors.success,
        size: 22,
      ),
    );
  }

  Widget _buildMedicineList(bool isDark) {
    if (_medicines.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'All Medications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'See All',
                  style: TextStyle(
                    color: _medicationPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._medicines.take(3).map((medicine) => _buildMedicineItem(medicine, isDark)),
        ],
      ),
    );
  }

  Widget _buildMedicineItem(EnhancedMedicine medicine, bool isDark) {
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
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.transparent,
          ),
          boxShadow: isDark ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: medicine.color != null
                    ? Color(medicine.color!.colorValue).withOpacity(0.2)
                    : _medicationPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(medicine.dosageForm.icon, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${medicine.displayDosage} • ${medicine.schedule.frequencyDescription}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PremiumAddMedicineScreen()),
      ).then((_) => _loadData()),
      backgroundColor: _medicationPrimary,
      elevation: 8,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: const Text(
        'Add Medicine',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _takeDose(_ScheduledDose dose) async {
    _hapticService.medicineTaken();

    try {
      await MedicineCleanStorageService.markMedicineTaken(
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
                Expanded(
                  child: Text(
                    '${dose.medicine.name} marked as taken',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        _loadData();
      }
    } catch (e) {
      debugPrint('Error taking dose: $e');
    }
  }

  void _showMoreOptions() {
    final isDark = AppColors.isDark(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionTile(
              icon: Icons.people_outline_rounded,
              title: 'Family Profiles',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DependentListScreen()),
                );
              },
              isDark: isDark,
            ),
            _buildOptionTile(
              icon: Icons.medical_services_outlined,
              title: 'Doctors',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DoctorListScreen()),
                );
              },
              isDark: isDark,
            ),
            _buildOptionTile(
              icon: Icons.local_pharmacy_outlined,
              title: 'Pharmacies',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PharmacyListScreen()),
                );
              },
              isDark: isDark,
            ),
            Divider(color: isDark ? Colors.white12 : AppColors.divider),
            _buildOptionTile(
              icon: Icons.picture_as_pdf_rounded,
              title: 'Export PDF Report',
              onTap: () {
                Navigator.pop(context);
                _exportPdfReport();
              },
              isDark: isDark,
            ),
            _buildOptionTile(
              icon: Icons.download_rounded,
              title: 'Export Data (JSON)',
              onTap: () {
                Navigator.pop(context);
                _exportData();
              },
              isDark: isDark,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdfReport() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating report...')),
      );
      await PdfReportService.generateAndShareReport();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating report: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _medicationPrimary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _medicationPrimary, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDark ? Colors.white38 : AppColors.textLight,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _exportData() async {
    final data = await MedicineCleanStorageService.exportAllMedicineData();
    debugPrint('Export data: $data');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Data exported to console (JSON)'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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

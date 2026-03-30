import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
// AppColors imported but using local theme
import '../../../core/services/haptic_service.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../services/medicine_storage_service.dart';
import 'add_medicine_wizard.dart';
import 'medicine_detail_screen.dart';
import 'medicine_history_screen.dart';

/// PILLMATE-Inspired Medication Dashboard
/// Features: Modern teal theme, circular progress, medicine cards, schedule view
class PillmateDashboard extends StatefulWidget {
  const PillmateDashboard({super.key});

  @override
  State<PillmateDashboard> createState() => _PillmateDashboardState();
}

class _PillmateDashboardState extends State<PillmateDashboard>
    with TickerProviderStateMixin {
  // Data
  List<EnhancedMedicine> _medicines = [];
  List<_ScheduledDose> _todaysDoses = [];
  bool _isLoading = true;
  int _streak = 0;
  double _adherenceRate = 0.0;
  DateTime _selectedDate = DateTime.now();

  // Animation controllers
  late AnimationController _progressController;
  late AnimationController _cardController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;

  final HapticService _hapticService = HapticService();
  final ScrollController _scrollController = ScrollController();

  // PILLMATE Theme Colors
  static const Color _primaryTeal = Color(0xFF00BFA5);
  static const Color _darkTeal = Color(0xFF00897B);
  static const Color _lightTeal = Color(0xFFE0F7F4);
  static const Color _accentOrange = Color(0xFFFF7043);
  static const Color _backgroundLight = Color(0xFFF5F9FC);
  static const Color _cardWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadData();
  }

  void _initAnimations() {
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _cardController.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await MedicineCleanStorageService.init();
      final allMedicines = await MedicineCleanStorageService.getAllMedicines();
      _medicines = allMedicines
          .where((m) => m.isActive && !m.isArchived)
          .toList();
      _streak = await MedicineCleanStorageService.getCurrentStreak();
      final stats = await MedicineCleanStorageService.getAdherenceStats();
      _adherenceRate = (stats['adherenceRate'] as int) / 100.0;

      await _buildSchedule();
      _progressController.forward();
      _cardController.forward();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _buildSchedule() async {
    _todaysDoses = [];
    final logs = await MedicineCleanStorageService.getLogsForDate(_selectedDate);

    for (final medicine in _medicines) {
      if (medicine.isPRN) continue;

      final times = medicine.schedule.getScheduledTimesForDate(_selectedDate);
      for (final time in times) {
        bool isTaken = false;
        bool isSkipped = false;
        
        try {
          final log = logs.firstWhere(
            (l) =>
                l.medicineId == medicine.id &&
                l.scheduledTime.hour == time.hour &&
                l.scheduledTime.minute == time.minute,
          );
          isTaken = log.isTaken;
          isSkipped = log.isSkipped;
        } catch (_) {
          // No log found
        }

        _todaysDoses.add(_ScheduledDose(
          medicine: medicine,
          scheduledTime: time,
          isTaken: isTaken,
          isSkipped: isSkipped,
        ));
      }
    }

    _todaysDoses.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  int get _takenCount => _todaysDoses.where((d) => d.isTaken).length;
  int get _totalCount => _todaysDoses.length;
  double get _progress => _totalCount > 0 ? _takenCount / _totalCount : 0;

  List<_ScheduledDose> get _upcomingDoses {
    final now = DateTime.now();
    return _todaysDoses.where((d) => !d.isTaken && !d.isSkipped && d.scheduledTime.isAfter(now)).toList();
  }

  List<_ScheduledDose> get _completedDoses {
    return _todaysDoses.where((d) => d.isTaken).toList();
  }

  List<_ScheduledDose> get _missedDoses {
    final now = DateTime.now();
    return _todaysDoses.where((d) => !d.isTaken && !d.isSkipped && d.scheduledTime.isBefore(now)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundLight,
      body: _isLoading ? _buildLoadingState() : _buildContent(),
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
              color: _lightTeal,
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: _primaryTeal,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading your medications...',
            style: TextStyle(
              color: _darkTeal,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildHeader(),
        SliverToBoxAdapter(child: _buildProgressSection()),
        SliverToBoxAdapter(child: _buildQuickStats()),
        SliverToBoxAdapter(child: _buildWeekCalendar()),
        SliverToBoxAdapter(child: _buildSectionTitle('Upcoming', Icons.schedule_rounded)),
        _buildUpcomingList(),
        if (_missedDoses.isNotEmpty) ...[
          SliverToBoxAdapter(child: _buildSectionTitle('Missed', Icons.warning_rounded, isWarning: true)),
          _buildMissedList(),
        ],
        if (_completedDoses.isNotEmpty) ...[
          SliverToBoxAdapter(child: _buildSectionTitle('Completed', Icons.check_circle_rounded)),
          _buildCompletedList(),
        ],
        SliverToBoxAdapter(child: _buildMedicinesList()),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: _primaryTeal,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primaryTeal, _darkTeal],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Your Health',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildHeaderIconButton(
                            Icons.history_rounded,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MedicineHistoryScreen()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildHeaderIconButton(
                            Icons.notifications_outlined,
                            () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        _hapticService.light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildProgressSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryTeal.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Progress
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _CircularProgressPainter(
                    progress: _progress * _progressAnimation.value,
                    strokeWidth: 12,
                    backgroundColor: _lightTeal,
                    progressColor: _primaryTeal,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${(_progress * 100 * _progressAnimation.value).toInt()}%',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _darkTeal,
                          ),
                        ),
                        const Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 24),
          // Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressStat(
                  'Taken',
                  '$_takenCount/$_totalCount',
                  _primaryTeal,
                  Icons.check_circle_rounded,
                ),
                const SizedBox(height: 12),
                _buildProgressStat(
                  'Streak',
                  '$_streak days',
                  _accentOrange,
                  Icons.local_fire_department_rounded,
                ),
                const SizedBox(height: 12),
                _buildProgressStat(
                  'Adherence',
                  '${(_adherenceRate * 100).toInt()}%',
                  Colors.purple,
                  Icons.trending_up_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat(String label, String value, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    final lowStock = _medicines.where((m) => m.isLowStock).length;
    final expiring = _medicines.where((m) => m.isExpiringSoon).length;

    if (lowStock == 0 && expiring == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (lowStock > 0)
            Expanded(
              child: _buildAlertCard(
                'Low Stock',
                '$lowStock medicines',
                Icons.inventory_2_outlined,
                _accentOrange,
              ),
            ),
          if (lowStock > 0 && expiring > 0) const SizedBox(width: 12),
          if (expiring > 0)
            Expanded(
              child: _buildAlertCard(
                'Expiring Soon',
                '$expiring medicines',
                Icons.event_busy_rounded,
                Colors.red,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(String title, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCalendar() {
    final today = DateTime.now();
    final weekDays = List.generate(7, (i) => today.subtract(Duration(days: 3 - i)));

    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_selectedDate),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _darkTeal,
                ),
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    _buildSchedule();
                  }
                },
                child: const Text('View All', style: TextStyle(color: _primaryTeal)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: weekDays.length,
              itemBuilder: (context, index) {
                final date = weekDays[index];
                final isSelected = DateUtils.isSameDay(date, _selectedDate);
                final isToday = DateUtils.isSameDay(date, today);

                return GestureDetector(
                  onTap: () {
                    _hapticService.light();
                    setState(() => _selectedDate = date);
                    _buildSchedule();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? _primaryTeal : _cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: isToday && !isSelected
                          ? Border.all(color: _primaryTeal, width: 2)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _primaryTeal.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(date).substring(0, 2),
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            color: isSelected ? Colors.white : _darkTeal,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isToday)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : _primaryTeal,
                              shape: BoxShape.circle,
                            ),
                          ),
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

  Widget _buildSectionTitle(String title, IconData icon, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: isWarning ? _accentOrange : _primaryTeal,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isWarning ? _accentOrange : _darkTeal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingList() {
    if (_upcomingDoses.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptyState(
          'No upcoming doses',
          'All your doses for today are completed!',
          Icons.celebration_rounded,
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final dose = _upcomingDoses[index];
          return _buildDoseCard(dose, isUpcoming: true);
        },
        childCount: _upcomingDoses.length,
      ),
    );
  }

  Widget _buildMissedList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final dose = _missedDoses[index];
          return _buildDoseCard(dose, isMissed: true);
        },
        childCount: _missedDoses.length,
      ),
    );
  }

  Widget _buildCompletedList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final dose = _completedDoses[index];
          return _buildDoseCard(dose, isCompleted: true);
        },
        childCount: math.min(_completedDoses.length, 3),
      ),
    );
  }

  Widget _buildDoseCard(_ScheduledDose dose, {
    bool isUpcoming = false,
    bool isMissed = false,
    bool isCompleted = false,
  }) {
    final medicine = dose.medicine;
    final timeStr = DateFormat('h:mm a').format(dose.scheduledTime);
    
    Color cardColor = _cardWhite;
    Color accentColor = _primaryTeal;
    
    if (isMissed) {
      cardColor = _accentOrange.withValues(alpha: 0.05);
      accentColor = _accentOrange;
    } else if (isCompleted) {
      cardColor = _primaryTeal.withValues(alpha: 0.05);
      accentColor = _primaryTeal;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MedicineDetailScreen(medicineId: medicine.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Medicine Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getColorFromMedicineColor(medicine.color),
                        _getColorFromMedicineColor(medicine.color).withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getMedicineIcon(medicine.dosageForm),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Medicine Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${medicine.displayDosage} • ${medicine.dosageForm.displayName}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 14, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            timeStr,
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Action Button
                if (isUpcoming || isMissed)
                  GestureDetector(
                    onTap: () => _showTakeDialog(dose),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accentColor, accentColor.withValues(alpha: 0.8)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Take',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else if (isCompleted)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _primaryTeal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: _primaryTeal,
                      size: 24,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedicinesList() {
    if (_medicines.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.medication_rounded, color: _primaryTeal, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'My Medicines',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _darkTeal,
                    ),
                  ),
                ],
              ),
              Text(
                '${_medicines.length} active',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _medicines.length,
            itemBuilder: (context, index) {
              final medicine = _medicines[index];
              return _buildMedicineCard(medicine);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMedicineCard(EnhancedMedicine medicine) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MedicineDetailScreen(medicineId: medicine.id),
        ),
      ),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getColorFromMedicineColor(medicine.color).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getMedicineIcon(medicine.dosageForm),
                color: _getColorFromMedicineColor(medicine.color),
                size: 24,
              ),
            ),
            const Spacer(),
            Text(
              medicine.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              medicine.displayDosage,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            if (medicine.isLowStock)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded, size: 14, color: _accentOrange),
                    const SizedBox(width: 4),
                    Text(
                      'Low stock',
                      style: TextStyle(
                        color: _accentOrange,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _lightTeal,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primaryTeal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _primaryTeal, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _darkTeal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController.value * 0.05);
        return Transform.scale(
          scale: scale,
          child: FloatingActionButton.extended(
            onPressed: () async {
              _hapticService.medium();
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddMedicineWizard()),
              );
              if (result == true) _loadData();
            },
            backgroundColor: _primaryTeal,
            elevation: 8,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text(
              'Add Medicine',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTakeDialog(_ScheduledDose dose) {
    _hapticService.light();
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getColorFromMedicineColor(dose.medicine.color),
                    _getColorFromMedicineColor(dose.medicine.color).withValues(alpha: 0.7),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getMedicineIcon(dose.medicine.dosageForm),
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              dose.medicine.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${dose.medicine.displayDosage} • ${DateFormat('h:mm a').format(dose.scheduledTime)}',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await MedicineCleanStorageService.markMedicineSkipped(
                        medicineId: dose.medicine.id,
                        scheduledTime: dose.scheduledTime,
                        reason: SkipReason.other,
                      );
                      _loadData();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      _hapticService.medicineTaken();
                      await MedicineCleanStorageService.markMedicineTaken(
                        medicineId: dose.medicine.id,
                        scheduledTime: dose.scheduledTime,
                      );
                      _loadData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white),
                                const SizedBox(width: 12),
                                Text('${dose.medicine.name} marked as taken'),
                              ],
                            ),
                            backgroundColor: _primaryTeal,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryTeal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Take Now',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Color _getColorFromMedicineColor(MedicineColor? color) {
    if (color == null) return _primaryTeal;
    switch (color) {
      case MedicineColor.white:
        return const Color(0xFFE0E0E0);
      case MedicineColor.pink:
        return const Color(0xFFEC407A);
      case MedicineColor.red:
        return const Color(0xFFEF5350);
      case MedicineColor.orange:
        return const Color(0xFFFF7043);
      case MedicineColor.yellow:
        return const Color(0xFFFFCA28);
      case MedicineColor.green:
        return const Color(0xFF66BB6A);
      case MedicineColor.blue:
        return const Color(0xFF42A5F5);
      case MedicineColor.purple:
        return const Color(0xFFAB47BC);
      case MedicineColor.brown:
        return const Color(0xFF8D6E63);
      case MedicineColor.gray:
        return const Color(0xFF9E9E9E);
      case MedicineColor.black:
        return const Color(0xFF424242);
      case MedicineColor.multicolor:
        return const Color(0xFF5C6BC0);
    }
  }

  IconData _getMedicineIcon(DosageForm form) {
    switch (form) {
      case DosageForm.tablet:
        return Icons.medication_rounded;
      case DosageForm.capsule:
        return Icons.medication_liquid_rounded;
      case DosageForm.syrup:
      case DosageForm.solution:
        return Icons.water_drop_rounded;
      case DosageForm.injection:
        return Icons.vaccines_rounded;
      case DosageForm.inhaler:
        return Icons.air_rounded;
      case DosageForm.cream:
        return Icons.spa_rounded;
      case DosageForm.drops:
        return Icons.opacity_rounded;
      case DosageForm.patch:
        return Icons.healing_rounded;
      default:
        return Icons.medication_rounded;
    }
  }
}

// Circular Progress Painter
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  _CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [
          progressColor.withValues(alpha: 0.5),
          progressColor,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Scheduled Dose Model
class _ScheduledDose {
  final EnhancedMedicine medicine;
  final DateTime scheduledTime;
  final bool isTaken;
  final bool isSkipped;

  _ScheduledDose({
    required this.medicine,
    required this.scheduledTime,
    this.isTaken = false,
    this.isSkipped = false,
  });
}

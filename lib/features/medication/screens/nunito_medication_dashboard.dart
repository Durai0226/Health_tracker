import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/haptic_service.dart';
import '../theme/nunito_theme.dart';
import '../widgets/nunito_glass_card.dart';
import '../widgets/nunito_pill_visual.dart';
import '../models/enhanced_medicine.dart';
import '../services/medicine_storage_service.dart';
import 'nunito_medication_list_screen.dart';
import 'nunito_add_medication_flow.dart';
import 'nunito_take_medication_sheet.dart';
import 'doctors/nunito_doctor_list_screen.dart';
import 'clinics/nunito_clinic_list_screen.dart';
import 'analytics/nunito_adherence_report_screen.dart';

class NunitoMedicationDashboard extends StatefulWidget {
  /// When embedded in the Health hub, the dashboard drops its own header
  /// (the hub owns the single header) and uses a transparent background.
  final bool embedded;
  const NunitoMedicationDashboard({super.key, this.embedded = false});

  @override
  State<NunitoMedicationDashboard> createState() => _NunitoMedicationDashboardState();
}

class _NunitoMedicationDashboardState extends State<NunitoMedicationDashboard>
    with TickerProviderStateMixin {
  List<EnhancedMedicine> _medicines = [];
  List<_ScheduledDose> _todaysDoses = [];
  final Map<String, bool> _takenStatus = {};
  bool _isLoading = true;
  int _streak = 0;
  double _adherenceRate = 0.0;
  DateTime _selectedDate = DateTime.now();

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;

  final HapticService _hapticService = HapticService();
  final ScrollController _scrollController = ScrollController();

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
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _floatController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _floatController.dispose();
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

      await _buildTodaySchedule();
      _fadeController.forward();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _buildTodaySchedule() async {
    _todaysDoses.clear();
    _takenStatus.clear();

    final activeMedicines = _medicines.where((m) => m.isActive && !m.isArchived);
    final logs = await MedicineCleanStorageService.getLogsForDate(_selectedDate);

    for (final medicine in activeMedicines) {
      final times = medicine.schedule.getScheduledTimesForDate(_selectedDate);
      for (int i = 0; i < times.length; i++) {
        final doseKey = '${medicine.id}_$i';
        final log = logs.where((l) => 
          l.medicineId == medicine.id && 
          l.scheduledTime.hour == times[i].hour &&
          l.scheduledTime.minute == times[i].minute
        ).firstOrNull;

        _todaysDoses.add(_ScheduledDose(
          medicine: medicine,
          scheduledTime: times[i],
          timeIndex: i,
          log: log,
        ));
        _takenStatus[doseKey] = log?.isTaken ?? false;
      }
    }

    _todaysDoses.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
  }

  void _onDateChanged(DateTime date) {
    setState(() => _selectedDate = date);
    _buildTodaySchedule().then((_) => setState(() {}));
  }

  Future<void> _onTakeMedication(_ScheduledDose dose) async {
    _hapticService.medium();
    
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NunitoTakeMedicationSheet(
        medicine: dose.medicine,
        scheduledTime: dose.scheduledTime,
      ),
    );

    if (result != null) {
      await _loadData();
    }
  }

  void _navigateToAddMedication() async {
    _hapticService.light();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NunitoAddMedicationFlow()),
    );
    if (result == true) {
      _loadData();
    }
  }

  void _navigateToMedicationList() {
    _hapticService.light();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NunitoMedicationListScreen()),
    ).then((_) => _loadData());
  }

  void _navigateToDoctors() {
    _hapticService.light();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NunitoDoctorListScreen()),
    );
  }

  void _navigateToClinics() {
    _hapticService.light();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NunitoClinicListScreen()),
    );
  }

  void _navigateToAnalytics() {
    _hapticService.light();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NunitoAdherenceReportScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = _isLoading
        ? _buildLoadingState()
        : FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                if (!widget.embedded) _buildHeader(isDark),
                if (widget.embedded)
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(child: _buildStatsRow(isDark)),
                SliverToBoxAdapter(child: _buildDateSelector(isDark)),
                SliverToBoxAdapter(child: _buildSectionTitle('Today\'s Schedule', Icons.schedule_rounded)),
                _todaysDoses.isEmpty
                    ? SliverToBoxAdapter(child: _buildEmptySchedule(isDark))
                    : _buildTimelineList(isDark),
                SliverToBoxAdapter(child: _buildQuickActions(isDark)),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );

    // Embedded in the Health hub: no nested Scaffold — return the body with a
    // floating add button so the hub owns the single Scaffold.
    if (widget.embedded) {
      return Stack(
        children: [
          Positioned.fill(child: content),
          Positioned(right: 16, bottom: 16, child: _buildFAB()),
        ],
      );
    }

    return Scaffold(
      backgroundColor: isDark ? NunitoTheme.backgroundDark : NunitoTheme.backgroundLight,
      body: content,
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _floatAnimation.value),
              child: Icon(
                Icons.medication_rounded,
                size: 64,
                color: NunitoTheme.primary.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your medications...',
            style: NunitoTheme.bodyMedium.copyWith(
              color: NunitoTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: NunitoTheme.primaryGradient,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(NunitoTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: NunitoTheme.bodyMedium.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Medication Tracker',
                            style: NunitoTheme.heading1.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      _buildHeaderActions(),
                    ],
                  ),
                  const Spacer(),
                  _buildAdherenceBadge(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Row(
      children: [
        _buildGlassIconButton(
          icon: Icons.bar_chart_rounded,
          onTap: _navigateToAnalytics,
        ),
        const SizedBox(width: 8),
        _buildGlassIconButton(
          icon: Icons.list_rounded,
          onTap: _navigateToMedicationList,
        ),
      ],
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildAdherenceBadge() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) => Transform.scale(
        scale: _pulseAnimation.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: Colors.orange.shade300,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '$_streak day streak',
                style: NunitoTheme.labelLarge.copyWith(color: Colors.white),
              ),
              const SizedBox(width: 16),
              Container(
                width: 1,
                height: 20,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(width: 16),
              Text(
                '${(_adherenceRate * 100).toInt()}% adherence',
                style: NunitoTheme.labelLarge.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    final takenToday = _todaysDoses.where((d) => _takenStatus['${d.medicine.id}_${d.timeIndex}'] == true).length;
    final totalToday = _todaysDoses.length;
    final upcoming = _todaysDoses.where((d) => 
      d.scheduledTime.isAfter(DateTime.now()) && 
      _takenStatus['${d.medicine.id}_${d.timeIndex}'] != true
    ).length;

    return Padding(
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('Taken', '$takenToday/$totalToday', Icons.check_circle_rounded, NunitoTheme.success, isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('Upcoming', '$upcoming', Icons.access_time_rounded, NunitoTheme.accentBlue, isDark)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('Medicines', '${_medicines.where((m) => m.isActive).length}', Icons.medication_rounded, NunitoTheme.primary, isDark)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return NunitoCard(
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: NunitoTheme.heading2.copyWith(
              color: isDark ? Colors.white : NunitoTheme.textPrimary,
            ),
          ),
          Text(
            label,
            style: NunitoTheme.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(bool isDark) {
    final now = DateTime.now();
    final dates = List.generate(7, (i) => now.add(Duration(days: i - 3)));

    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: NunitoTheme.spacingS),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: NunitoTheme.spacingM),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = _isSameDay(date, _selectedDate);
          final isToday = _isSameDay(date, now);

          return GestureDetector(
            onTap: () => _onDateChanged(date),
            child: AnimatedContainer(
              duration: NunitoTheme.animationFast,
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? NunitoTheme.primary
                    : (isDark ? NunitoTheme.cardDark : NunitoTheme.cardLight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected ? NunitoTheme.cardShadow : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date).toUpperCase(),
                    style: NunitoTheme.caption.copyWith(
                      color: isSelected ? Colors.white70 : NunitoTheme.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d').format(date),
                    style: NunitoTheme.heading2.copyWith(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : NunitoTheme.textPrimary),
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : NunitoTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NunitoTheme.spacingM,
        NunitoTheme.spacingM,
        NunitoTheme.spacingM,
        NunitoTheme.spacingS,
      ),
      child: Row(
        children: [
          Icon(icon, color: NunitoTheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(title, style: NunitoTheme.heading3),
        ],
      ),
    );
  }

  Widget _buildEmptySchedule(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(NunitoTheme.spacingXL),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _floatAnimation.value),
              child: Icon(
                Icons.event_available_rounded,
                size: 64,
                color: NunitoTheme.primary.withOpacity(0.3),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No medications scheduled',
            style: NunitoTheme.heading3.copyWith(
              color: isDark ? Colors.white70 : NunitoTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first medication',
            style: NunitoTheme.bodyMedium.copyWith(
              color: NunitoTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineList(bool isDark) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final dose = _todaysDoses[index];
          final isTaken = _takenStatus['${dose.medicine.id}_${dose.timeIndex}'] ?? false;
          final isPast = dose.scheduledTime.isBefore(DateTime.now());
          final isNext = !isTaken && index == _todaysDoses.indexWhere((d) => 
            !(_takenStatus['${d.medicine.id}_${d.timeIndex}'] ?? false) &&
            d.scheduledTime.isAfter(DateTime.now())
          );

          return _buildTimelineItem(dose, isTaken, isPast, isNext, isDark, index == 0, index == _todaysDoses.length - 1);
        },
        childCount: _todaysDoses.length,
      ),
    );
  }

  Widget _buildTimelineItem(_ScheduledDose dose, bool isTaken, bool isPast, bool isNext, bool isDark, bool isFirst, bool isLast) {
    final timeStr = DateFormat('h:mm a').format(dose.scheduledTime);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NunitoTheme.spacingM),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Timeline column
            SizedBox(
              width: 60,
              child: Column(
                children: [
                  if (!isFirst)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isTaken ? NunitoTheme.success.withOpacity(0.3) : NunitoTheme.textTertiary.withOpacity(0.2),
                      ),
                    ),
                  Container(
                    width: isNext ? 16 : 12,
                    height: isNext ? 16 : 12,
                    decoration: BoxDecoration(
                      color: isTaken 
                          ? NunitoTheme.success 
                          : (isNext ? NunitoTheme.primary : NunitoTheme.textTertiary.withOpacity(0.3)),
                      shape: BoxShape.circle,
                      border: isNext ? Border.all(color: NunitoTheme.primary.withOpacity(0.3), width: 3) : null,
                    ),
                    child: isTaken
                        ? const Icon(Icons.check, color: Colors.white, size: 8)
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: NunitoTheme.textTertiary.withOpacity(0.2),
                      ),
                    ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: NunitoTheme.spacingM),
                child: NunitoAnimatedCard(
                  onTap: isTaken ? null : () => _onTakeMedication(dose),
                  backgroundColor: isTaken
                      ? NunitoTheme.success.withOpacity(0.1)
                      : (isNext 
                          ? (isDark ? NunitoTheme.cardDark : Colors.white)
                          : (isDark ? NunitoTheme.cardDark.withOpacity(0.5) : Colors.white.withOpacity(0.7))),
                  boxShadow: isNext ? NunitoTheme.elevatedShadow : NunitoTheme.subtleShadow,
                  child: Row(
                    children: [
                      NunitoPillIndicator(
                        color: dose.medicine.color,
                        shape: dose.medicine.shape,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dose.medicine.name,
                              style: NunitoTheme.labelLarge.copyWith(
                                color: isDark ? Colors.white : NunitoTheme.textPrimary,
                                decoration: isTaken ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${dose.medicine.displayDosage} • $timeStr',
                              style: NunitoTheme.bodySmall.copyWith(
                                color: isTaken ? NunitoTheme.success : NunitoTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isTaken)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isNext ? NunitoTheme.primary : NunitoTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isNext ? 'Take Now' : 'Take',
                            style: NunitoTheme.labelMedium.copyWith(
                              color: isNext ? Colors.white : NunitoTheme.primary,
                            ),
                          ),
                        )
                      else
                        Icon(Icons.check_circle_rounded, color: NunitoTheme.success, size: 28),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Quick Access', Icons.apps_rounded),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildQuickActionCard('Doctors', Icons.person_rounded, NunitoTheme.accentBlue, _navigateToDoctors, isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildQuickActionCard('Clinics', Icons.local_hospital_rounded, NunitoTheme.accent, _navigateToClinics, isDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(String label, IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return NunitoAnimatedCard(
      onTap: onTap,
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: NunitoTheme.labelLarge.copyWith(
              color: isDark ? Colors.white : NunitoTheme.textPrimary,
            ),
          ),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, color: NunitoTheme.textTertiary),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _navigateToAddMedication,
      backgroundColor: NunitoTheme.primary,
      elevation: 8,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: Text(
        'Add Medication',
        style: NunitoTheme.labelLarge.copyWith(color: Colors.white),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _ScheduledDose {
  final EnhancedMedicine medicine;
  final DateTime scheduledTime;
  final int timeIndex;
  final dynamic log;

  _ScheduledDose({
    required this.medicine,
    required this.scheduledTime,
    required this.timeIndex,
    this.log,
  });
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../widgets/nunito_pill_visual.dart';
import '../models/enhanced_medicine.dart';
import '../models/drug_interaction.dart';
import '../models/medicine_enums.dart';
import '../services/medicine_storage_service.dart';
import '../services/drug_interaction_service.dart';
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

  final DrugInteractionService _interactionService = DrugInteractionService();
  List<DrugInteraction> _interactions = [];
  bool _interactionsExpanded = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final HapticService _hapticService = HapticService();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: AppMotion.slow,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: AppMotion.standard,
    );
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await MedicineCleanStorageService.init();
      // Backfill `missed` logs for past-due slots so adherence reflects reality.
      await MedicineCleanStorageService.reconcileMissedDoses();
      _medicines = await MedicineCleanStorageService.getAllMedicines();
      _computeInteractions();
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

  /// Scan the user's active medicines for drug-drug interactions using the
  /// built-in interaction database. One representative name per medicine
  /// (generic when known) avoids pairing a brand against its own generic.
  void _computeInteractions() {
    final names = _medicines
        .where((m) => m.isActive && !m.isArchived)
        .map((m) => (m.genericName != null && m.genericName!.trim().isNotEmpty)
            ? m.genericName!
            : m.name)
        .toList();
    _interactions = _interactionService.checkAllInteractions(names);
  }

  AccentSwatch _severitySwatch(InteractionSeverity severity) {
    final ext = AppColorsExt.of(context);
    switch (severity) {
      case InteractionSeverity.mild:
      case InteractionSeverity.moderate:
        return ext.warning;
      case InteractionSeverity.severe:
      case InteractionSeverity.contraindicated:
        return ext.error;
    }
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
    final content = _isLoading
        ? _buildLoadingState()
        : FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                if (!widget.embedded)
                  SliverToBoxAdapter(child: _buildHeader())
                else
                  const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
                if (_interactions.isNotEmpty)
                  SliverToBoxAdapter(child: _buildInteractionBanner()),
                SliverToBoxAdapter(child: _buildSummaryCard()),
                SliverToBoxAdapter(child: _buildStatsRow()),
                SliverToBoxAdapter(child: _buildDateSelector()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 0),
                    child: const SectionHeader(
                      title: "Today's Schedule",
                      icon: Icons.schedule_rounded,
                    ),
                  ),
                ),
                _todaysDoses.isEmpty
                    ? SliverToBoxAdapter(child: _buildEmptySchedule())
                    : _buildTimelineList(),
                SliverToBoxAdapter(child: _buildQuickActions()),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );

    // Embedded in the Health hub: no nested Scaffold — return the body with a
    // floating add button so the hub owns the single Scaffold.
    if (widget.embedded) {
      return AccentScope(
        feature: FeatureAccent.medicine,
        child: Stack(
          children: [
            Positioned.fill(child: content),
            Positioned(right: 16, bottom: 16, child: _buildFAB()),
          ],
        ),
      );
    }

    return AccentScope(
      feature: FeatureAccent.medicine,
      child: AppScaffold(
        body: content,
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  Widget _buildLoadingState() {
    final ext = AppColorsExt.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_rounded,
            size: 64,
            color: ext.mark(ext.medicine),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Loading your medications...',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: ext.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final ext = AppColorsExt.of(context);
    return AppHeader(
      title: 'Medication Tracker',
      greeting: _getGreeting(),
      icon: Icons.medication_rounded,
      accent: ext.medicine,
      actions: [
        AppIconButton(
          icon: Icons.bar_chart_rounded,
          accent: ext.medicine,
          tooltip: 'Adherence report',
          onPressed: _navigateToAnalytics,
        ),
        AppIconButton(
          icon: Icons.list_rounded,
          accent: ext.medicine,
          tooltip: 'All medications',
          onPressed: _navigateToMedicationList,
        ),
      ],
    );
  }

  Widget _buildInteractionBanner() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    // Interactions are pre-sorted most-severe first, so the first drives accent.
    final topSeverity = _interactions.first.severity;
    final swatch = _severitySwatch(topSeverity);
    final count = _interactions.length;

    return AppCard(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 0),
      color: swatch.container,
      onTap: () => setState(() => _interactionsExpanded = !_interactionsExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: swatch.onContainer, size: 24),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count potential interaction${count == 1 ? '' : 's'}',
                      style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: swatch.onContainer),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _interactionsExpanded
                          ? 'Tap to collapse'
                          : 'Between your active medicines — tap to review',
                      style: tt.bodySmall
                          ?.copyWith(color: swatch.onContainer.withOpacity(0.85)),
                    ),
                  ],
                ),
              ),
              Icon(
                _interactionsExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                color: swatch.onContainer,
              ),
            ],
          ),
          if (_interactionsExpanded) ...[
            const SizedBox(height: AppSpacing.md),
            ..._interactions.map(_buildInteractionRow),
          ],
        ],
      ),
    );
  }

  Widget _buildInteractionRow(DrugInteraction interaction) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final swatch = _severitySwatch(interaction.severity);

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ext.surface,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: ext.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${interaction.drug1Name} + ${interaction.drug2Name}',
                  style: tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700, color: ext.textPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: swatch.container,
                  borderRadius: AppRadius.brSm,
                ),
                child: Text(
                  interaction.severity.displayName,
                  style: tt.labelSmall?.copyWith(
                      color: swatch.onContainer, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            interaction.description,
            style: tt.bodySmall?.copyWith(color: ext.textSecondary),
          ),
          if (interaction.recommendation != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline_rounded,
                    size: 15, color: ext.mark(ext.info)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    interaction.recommendation!,
                    style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ext.warning.container,
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(Icons.local_fire_department_rounded,
                color: ext.warning.onContainer, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_streak day streak',
                  style: tt.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text('Keep it going',
                  style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${(_adherenceRate * 100).toInt()}%',
                  style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: ext.mark(ext.medicine))),
              Text('adherence',
                  style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final ext = AppColorsExt.of(context);
    final takenToday = _todaysDoses.where((d) => _takenStatus['${d.medicine.id}_${d.timeIndex}'] == true).length;
    final totalToday = _todaysDoses.length;
    final upcoming = _todaysDoses.where((d) =>
      d.scheduledTime.isAfter(DateTime.now()) &&
      _takenStatus['${d.medicine.id}_${d.timeIndex}'] != true
    ).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, 0),
      child: StatTileRow(
        tiles: [
          StatTile(
            label: 'Taken',
            value: '$takenToday/$totalToday',
            icon: Icons.check_circle_rounded,
            accent: ext.success,
          ),
          StatTile(
            label: 'Upcoming',
            value: '$upcoming',
            icon: Icons.access_time_rounded,
            accent: ext.info,
          ),
          StatTile(
            label: 'Medicines',
            value: '${_medicines.where((m) => m.isActive).length}',
            icon: Icons.medication_rounded,
            accent: ext.medicine,
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final dates = List.generate(7, (i) => now.add(Duration(days: i - 3)));

    return Container(
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = _isSameDay(date, _selectedDate);
          final isToday = _isSameDay(date, now);

          return GestureDetector(
            onTap: () => _onDateChanged(date),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? ext.fillBg(ext.medicine) : ext.surface,
                borderRadius: AppRadius.brLg,
                border: isSelected
                    ? null
                    : Border.all(color: ext.outline),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date).toUpperCase(),
                    style: tt.labelSmall?.copyWith(
                      color: isSelected
                          ? ext.fillFg(ext.medicine).withOpacity(0.8)
                          : ext.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d').format(date),
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? ext.fillFg(ext.medicine)
                          : ext.textPrimary,
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ext.fillFg(ext.medicine)
                            : ext.mark(ext.medicine),
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

  Widget _buildEmptySchedule() {
    final ext = AppColorsExt.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: EmptyState(
        icon: Icons.event_available_rounded,
        title: 'No medications scheduled',
        message: 'Tap + to add your first medication',
        accent: ext.medicine,
      ),
    );
  }

  Widget _buildTimelineList() {
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

          return _buildTimelineItem(dose, isTaken, isPast, isNext, index == 0, index == _todaysDoses.length - 1);
        },
        childCount: _todaysDoses.length,
      ),
    );
  }

  Widget _buildTimelineItem(_ScheduledDose dose, bool isTaken, bool isPast, bool isNext, bool isFirst, bool isLast) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final timeStr = DateFormat('h:mm a').format(dose.scheduledTime);

    final dotColor = isTaken
        ? ext.success.base
        : (isNext ? ext.mark(ext.medicine) : ext.textTertiary.withOpacity(0.5));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Timeline column
            SizedBox(
              width: 56,
              child: Column(
                children: [
                  if (!isFirst)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isTaken
                            ? ext.success.base.withOpacity(0.3)
                            : ext.outline,
                      ),
                    ),
                  Container(
                    width: isNext ? 16 : 12,
                    height: isNext ? 16 : 12,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: isNext
                          ? Border.all(
                              color: ext.mark(ext.medicine).withOpacity(0.3),
                              width: 3)
                          : null,
                    ),
                    child: isTaken
                        ? Icon(Icons.check, color: ext.success.on, size: 8)
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: ext.outline),
                    ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: MergeSemantics(
                  child: Semantics(
                  button: !isTaken,
                  child: AppCard(
                  color: isTaken ? ext.success.container : ext.surface,
                  onTap: isTaken ? null : () => _onTakeMedication(dose),
                  child: Row(
                    children: [
                      NunitoPillIndicator(
                        color: dose.medicine.color,
                        shape: dose.medicine.shape,
                        size: 44,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dose.medicine.name,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isTaken
                                    ? ext.success.onContainer
                                    : ext.textPrimary,
                                decoration: isTaken
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${dose.medicine.displayDosage} • $timeStr',
                              style: tt.bodySmall?.copyWith(
                                color: isTaken
                                    ? ext.success.onContainer
                                    : ext.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isTaken)
                        AppButton(
                          label: isNext ? 'Take Now' : 'Take',
                          size: AppButtonSize.sm,
                          variant: isNext
                              ? AppButtonVariant.primary
                              : AppButtonVariant.tonal,
                          accent: ext.medicine,
                          onPressed: () => _onTakeMedication(dose),
                        )
                      else
                        Icon(Icons.check_circle_rounded,
                            color: ext.success.base, size: 28),
                    ],
                  ),
                ),
                ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final ext = AppColorsExt.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Quick Access', icon: Icons.apps_rounded),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                    'Doctors', Icons.person_rounded, ext.info, _navigateToDoctors),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildQuickActionCard('Clinics',
                    Icons.local_hospital_rounded, ext.medicine, _navigateToClinics),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
      String label, IconData icon, AccentSwatch accent, VoidCallback onTap) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.container,
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(icon, color: accent.onContainer, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700, color: ext.textPrimary),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: ext.textTertiary),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    final ext = AppColorsExt.of(context);
    return AppFab(
      icon: Icons.add_rounded,
      label: 'Add Medication',
      accent: ext.medicine,
      onPressed: _navigateToAddMedication,
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

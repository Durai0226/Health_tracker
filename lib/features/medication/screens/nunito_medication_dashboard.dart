import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../widgets/nunito_pill_visual.dart';
import '../models/enhanced_medicine.dart';
import '../models/drug_interaction.dart';
import '../models/medicine_enums.dart';
import '../services/medicine_storage_service.dart';
import '../services/today_schedule_service.dart';
import '../services/drug_interaction_service.dart';
import '../../../core/services/rating_prompt_service.dart';
import 'nunito_medication_list_screen.dart';
import 'refill_overview_screen.dart';
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
  bool _ratingChecked = false; // one-shot rating prompt per screen lifetime
  int _streak = 0;
  double _adherenceRate = 0.0;
  // Log ids applied this load from queued notification actions (for Undo).
  List<String> _drainedLogIds = const [];
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
    // Live refresh: any dose taken/edited/deleted — here, from a notification,
    // the medicine detail screen, or another tab — bumps this revision. Kept
    // alive in the Health hub's IndexedStack, this screen would otherwise go
    // stale until a tab remount, so subscribe and refresh in place.
    MedicineCleanStorageService.revision.addListener(_onMedicineRevision);
  }

  void _onMedicineRevision() {
    if (mounted) _loadData(showLoader: false);
  }

  @override
  void dispose() {
    MedicineCleanStorageService.revision.removeListener(_onMedicineRevision);
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoader = true}) async {
    if (showLoader) setState(() => _isLoading = true);
    try {
      await MedicineCleanStorageService.init();
      // Apply any Take/Skip the user tapped on a notification while the app was
      // closed (queued by the background isolate); reflected below in the stats.
      _drainedLogIds = await MedicineCleanStorageService.drainPendingDoseActions();
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

    // Confirm + offer Undo for doses logged from a notification while away.
    if (_drainedLogIds.isNotEmpty && mounted) {
      final ids = _drainedLogIds;
      _drainedLogIds = const [];
      final n = ids.length;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Logged $n dose${n == 1 ? '' : 's'} from your reminder'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              for (final id in ids) {
                // Reverse the stock decrement for taken doses before deleting,
                // otherwise Undo silently loses inventory.
                final log = await MedicineCleanStorageService.getLog(id);
                if (log != null && log.isTaken) {
                  await MedicineCleanStorageService.restoreStock(
                      log.medicineId, log.dosageTaken);
                }
                await MedicineCleanStorageService.deleteLog(id);
              }
              await _loadData();
            },
          ),
        ));
    }

    // One-shot: after a real adherence "win", ask for a store rating (never nags).
    if (!_ratingChecked && mounted) {
      _ratingChecked = true;
      RatingPromptService.maybePrompt(context, streak: _streak);
    }
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
    // Single source of truth (shared with the Today hub's next-dose hero).
    final requestDate = _selectedDate;
    final doses = await TodayScheduleService.getTodaysDoses(requestDate);
    // Discard stale results if the user changed the date during the await —
    // otherwise two rapid taps could interleave and merge both days' doses.
    if (requestDate != _selectedDate) return;
    _todaysDoses.clear();
    _takenStatus.clear();
    for (final d in doses) {
      _todaysDoses.add(_ScheduledDose(
        medicine: d.medicine,
        scheduledTime: d.scheduledTime,
        timeIndex: d.timeIndex,
        log: d.log,
      ));
      _takenStatus[d.key] = d.isTaken;
    }
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
                SliverToBoxAdapter(child: _buildRefillBanner()),
                SliverToBoxAdapter(child: _buildSummaryCard()),
                // Date selector before the stats so the numbers sit next to the
                // picker that scopes them (the stats follow the selected date).
                SliverToBoxAdapter(child: _buildDateSelector()),
                SliverToBoxAdapter(child: _buildStatsRow()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 0),
                    child: const SectionHeader(
                      title: "Today's Schedule",
                      icon: Symbols.schedule_rounded,
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
            Positioned(right: 16, bottom: 24, child: _buildFAB()),
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
            Symbols.medication_rounded,
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
      // Short title so it never truncates beside the greeting + two actions.
      title: 'Medicine',
      greeting: _getGreeting(),
      icon: Symbols.medication_rounded,
      accent: ext.medicine,
      actions: [
        AppIconButton(
          icon: Symbols.bar_chart_rounded,
          accent: ext.medicine,
          tooltip: 'Adherence report',
          onPressed: _navigateToAnalytics,
        ),
        AppIconButton(
          icon: Symbols.list_rounded,
          accent: ext.medicine,
          tooltip: 'All medications',
          onPressed: _navigateToMedicationList,
        ),
      ],
    );
  }

  /// Calm banner aggregating meds that are running low or expiring. Collapses to
  /// nothing when all is well. Data is already computed on each medicine model.
  Widget _buildRefillBanner() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final flagged = _medicines
        .where((m) =>
            m.isActive &&
            !m.isArchived &&
            (m.isLowStock || m.isExpiringSoon || m.isExpired))
        .toList();
    if (flagged.isEmpty) return const SizedBox.shrink();

    final anyExpired = flagged.any((m) => m.isExpired);
    final swatch = anyExpired ? ext.error : ext.warning;
    final n = flagged.length;
    // Bucket each flagged med once (expiry takes priority) so the subtitle
    // parts sum to the count — a med both low AND expiring was double-counted.
    final expCount = flagged.where((m) => m.isExpiringSoon || m.isExpired).length;
    final lowCount = flagged
        .where((m) => m.isLowStock && !(m.isExpiringSoon || m.isExpired))
        .length;
    final parts = <String>[
      if (lowCount > 0) '$lowCount running low',
      if (expCount > 0) '$expCount expiring',
    ];

    return AppCard(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 0),
      color: swatch.container,
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const RefillOverviewScreen()))
          .then((_) => _loadData(showLoader: false)),
      child: Row(
        children: [
          Icon(Symbols.inventory_2_rounded, color: swatch.onContainer, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$n medicine${n == 1 ? '' : 's'} need attention',
                  style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700, color: swatch.onContainer),
                ),
                const SizedBox(height: 2),
                Text(
                  parts.join(' · '),
                  style: tt.bodySmall
                      ?.copyWith(color: swatch.onContainer.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          Icon(Symbols.chevron_right_rounded, color: swatch.onContainer),
        ],
      ),
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
              Icon(Symbols.warning_amber_rounded,
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
                    ? Symbols.expand_less_rounded
                    : Symbols.expand_more_rounded,
                color: swatch.onContainer,
              ),
            ],
          ),
          if (_interactionsExpanded) ...[
            const SizedBox(height: AppSpacing.md),
            ..._interactions.map(_buildInteractionRow),
            const SizedBox(height: AppSpacing.sm),
            // Cited, abstaining framing + pharmacist escalation — never present
            // this as an authoritative or complete clinical verdict.
            Text(
              'General reference from a built-in list — not a complete or '
              'clinical interaction check. Always confirm with your pharmacist '
              'or doctor before changing anything.',
              style: tt.bodySmall
                  ?.copyWith(color: swatch.onContainer.withOpacity(0.85)),
            ),
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
                Icon(Symbols.lightbulb_rounded,
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
            child: Icon(Symbols.local_fire_department_rounded,
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
              Text('${(_adherenceRate * 100).round()}%',
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
    // "Upcoming" is scoped to the SELECTED date, not always "now": a past day
    // has nothing upcoming; today counts doses still after now; a future day
    // counts every not-yet-taken dose.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final isToday = selDay == today;
    final isPastDay = selDay.isBefore(today);
    final upcoming = _todaysDoses.where((d) {
      final taken = _takenStatus['${d.medicine.id}_${d.timeIndex}'] == true;
      if (taken || isPastDay) return false;
      if (isToday) return d.scheduledTime.isAfter(now);
      return true; // future day → all untaken doses are upcoming
    }).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.md, AppSpacing.gutter, 0),
      child: StatTileRow(
        tiles: [
          StatTile(
            label: 'Taken',
            value: '$takenToday/$totalToday',
            icon: Symbols.check_circle_rounded,
            accent: ext.success,
          ),
          StatTile(
            label: 'Upcoming',
            value: '$upcoming',
            icon: Symbols.access_time_rounded,
            accent: ext.info,
          ),
          StatTile(
            label: 'Medicines',
            value: '${_medicines.where((m) => m.isActive).length}',
            icon: Symbols.medication_rounded,
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
    // Distinguish true onboarding (no meds yet) from an off-day (meds exist but
    // none are scheduled on the selected date). The old copy told an existing
    // user to "add your first medication".
    final hasMeds = _medicines.any((m) => m.isActive && !m.isArchived);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: EmptyState(
        icon: Symbols.event_available_rounded,
        title: hasMeds ? 'Nothing scheduled for this day' : 'No medications scheduled',
        message: hasMeds
            ? 'None of your medicines are due on this date.'
            : 'Tap + to add your first medication',
        accent: ext.medicine,
      ),
    );
  }

  Widget _buildTimelineList() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool isFutureDay(DateTime t) =>
        DateTime(t.year, t.month, t.day).isAfter(today);
    bool isHandled(_ScheduledDose d) =>
        (_takenStatus['${d.medicine.id}_${d.timeIndex}'] ?? false) ||
        d.log?.isSkipped == true ||
        d.log?.isMissed == true;
    // "Next" = the earliest still-open dose that is due today (overdue OR
    // upcoming) — never a future-day dose, never one already taken/skipped/
    // missed. This keeps the emphasis on the overdue dose, not a later one.
    final nextIndex = _todaysDoses
        .indexWhere((d) => !isHandled(d) && !isFutureDay(d.scheduledTime));

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final dose = _todaysDoses[index];
          final isTaken =
              _takenStatus['${dose.medicine.id}_${dose.timeIndex}'] ?? false;
          final isPast = dose.scheduledTime.isBefore(now);
          final isNext = index == nextIndex;

          return _buildTimelineItem(dose, isTaken, isPast, isNext, index == 0,
              index == _todaysDoses.length - 1);
        },
        childCount: _todaysDoses.length,
      ),
    );
  }

  Widget _buildTimelineItem(_ScheduledDose dose, bool isTaken, bool isPast, bool isNext, bool isFirst, bool isLast) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final timeStr = DateFormat('h:mm a').format(dose.scheduledTime);

    // A dose can be taken / skipped / missed (terminal) — or, on a future day,
    // view-only. Previously only "taken" was tracked, so a skipped or missed
    // dose rendered as a fresh pending one and could be re-taken (duplicate log
    // + double stock decrement); a future dose could be "taken" early.
    final isSkipped = dose.log?.isSkipped == true;
    final isMissed = dose.log?.isMissed == true;
    final isTerminal = isTaken || isSkipped || isMissed;
    final now = DateTime.now();
    final isFuture = DateTime(dose.scheduledTime.year, dose.scheduledTime.month,
            dose.scheduledTime.day)
        .isAfter(DateTime(now.year, now.month, now.day));
    final actionable = !isTerminal && !isFuture;
    final closed = isTerminal; // taken/skipped/missed all read as "done"

    final dotColor = isTaken
        ? ext.success.base
        : (isNext ? ext.mark(ext.medicine) : ext.textTertiary.withOpacity(0.5));
    final cardColor = isTaken
        ? ext.success.container
        : (isSkipped || isMissed ? ext.surfaceVariant : ext.surface);
    final nameColor = isTaken
        ? ext.success.onContainer
        : (isSkipped || isMissed ? ext.textTertiary : ext.textPrimary);

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
                        ? Icon(Symbols.check_rounded, color: ext.success.on, size: 8)
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
                  button: actionable,
                  child: AppCard(
                  color: cardColor,
                  onTap: actionable ? () => _onTakeMedication(dose) : null,
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
                                color: nameColor,
                                decoration: closed
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
                                    : (isSkipped || isMissed
                                        ? ext.textTertiary
                                        : ext.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildDoseTrailing(
                          isTaken, isSkipped, isMissed, isNext, actionable, dose),
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

  /// Trailing control for a timeline dose: a completed check, a Skipped/Missed
  /// badge (non-actionable), a Take button (only for a due, unhandled dose), or
  /// a view-only clock for a future-day dose.
  Widget _buildDoseTrailing(bool isTaken, bool isSkipped, bool isMissed,
      bool isNext, bool actionable, _ScheduledDose dose) {
    final ext = AppColorsExt.of(context);
    if (isTaken) {
      return Icon(Symbols.check_circle_rounded,
          color: ext.success.base, size: 28);
    }
    if (isSkipped) return _doseBadge('Skipped', ext.textTertiary);
    if (isMissed) return _doseBadge('Missed', ext.warning.base);
    if (actionable) {
      return AppButton(
        label: isNext ? 'Take Now' : 'Take',
        size: AppButtonSize.sm,
        variant: isNext ? AppButtonVariant.primary : AppButtonVariant.tonal,
        accent: ext.medicine,
        onPressed: () => _onTakeMedication(dose),
      );
    }
    // Future-day dose — view only, not takeable yet.
    return Icon(Symbols.schedule_rounded, color: ext.textTertiary, size: 22);
  }

  Widget _doseBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: AppRadius.brFull,
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildQuickActions() {
    final ext = AppColorsExt.of(context);
    // Health trackers (Steps/Sleep/BP/Glucose) now live in the Health tab, so
    // this grid is just the medicine-adjacent care directory.
    final tiles = <_QuickTile>[
      _QuickTile('Doctors', Symbols.person_rounded, ext.info, _navigateToDoctors),
      _QuickTile('Clinics', Symbols.local_hospital_rounded, ext.medicine,
          _navigateToClinics),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Care team', icon: Symbols.groups_rounded),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.92,
            children: [for (final t in tiles) _buildQuickTile(t)],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTile(_QuickTile t) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: t.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: t.accent.container,
              borderRadius: AppRadius.brMd,
            ),
            child: Icon(t.icon, color: t.accent.onContainer, size: 22),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              t.label,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: tt.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700, color: ext.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    final ext = AppColorsExt.of(context);
    // Circular + (matches Reminders, doesn't overlap the empty-state text).
    return AppFab(
      icon: Symbols.add_rounded,
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

/// A single Quick-Access tile (label + icon + accent + destination).
class _QuickTile {
  final String label;
  final IconData icon;
  final AccentSwatch accent;
  final VoidCallback onTap;
  const _QuickTile(this.label, this.icon, this.accent, this.onTap);
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

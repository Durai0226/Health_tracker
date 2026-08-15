import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/services/active_profile_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../widgets/nunito_pill_visual.dart';
import '../models/enhanced_medicine.dart';
import '../models/drug_interaction.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_log.dart';
import '../services/medicine_storage_service.dart';
import '../services/today_schedule_service.dart';
import '../services/drug_interaction_service.dart';
import '../../../core/services/rating_prompt_service.dart';
import '../../../core/services/clean_storage_service.dart';
import '../../../core/health/streak_milestones.dart';
import 'nunito_medication_list_screen.dart';
import 'refill_overview_screen.dart';
import 'nunito_add_medication_flow.dart';
import 'nunito_take_medication_sheet.dart';
import 'appointments/nunito_appointment_list_screen.dart';
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
  bool _milestoneChecked = false; // one-shot celebration per screen lifetime
  int _streak = 0;
  double _adherenceRate = 0.0;
  /// Doses scheduled in the adherence window. When this is 0 the service
  /// returns adherenceRate = 100 for a degenerate "nothing scheduled" case,
  /// which rendered a fabricated "100% adherence" next to "0 Medicines".
  /// A health app must not invent a clinical figure — gate the display on this.
  int _adherenceScheduled = 0;
  // Log ids applied this load from queued notification actions (for Undo).
  List<String> _drainedLogIds = const [];
  DateTime _selectedDate = DateTime.now();
  // Guards against overlapping / re-entrant loads (see _loadData).
  bool _loadInFlight = false;
  bool _reloadQueued = false;
  // Timeline vs. pillbox-tray layout for today's schedule; persisted so the
  // choice survives an app restart (see _loadViewModePreference).
  _MedicationViewMode _viewMode = _MedicationViewMode.timeline;

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
    _viewMode = _loadViewModePreference();
    _loadData();
    // Live refresh: any dose taken/edited/deleted — here, from a notification,
    // the medicine detail screen, or another tab — bumps this revision. Kept
    // alive in the Health hub's IndexedStack, this screen would otherwise go
    // stale until a tab remount, so subscribe and refresh in place.
    MedicineCleanStorageService.revision.addListener(_onMedicineRevision);
    // Same reasoning for switching profiles: getAllMedicines() etc. are
    // scoped to whichever profile is active, but that scope changing isn't a
    // medicine mutation, so it never bumps `revision` on its own — without
    // this listener, switching from "Me" to "Kid A" here would keep showing
    // Mom's medicines until an unrelated write happened to fire.
    ActiveProfileService().addListener(_onMedicineRevision);
  }

  void _onMedicineRevision() {
    if (mounted) _loadData(showLoader: false);
  }

  @override
  void dispose() {
    MedicineCleanStorageService.revision.removeListener(_onMedicineRevision);
    ActiveProfileService().removeListener(_onMedicineRevision);
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoader = true}) async {
    // Writes bump `revision`, which re-enters this method while an earlier load
    // is still awaiting — and `reconcileMissedDoses`/`drainPendingDoseActions`
    // write too, so a load can re-enter itself. Serialise: coalesce anything
    // arriving mid-flight into a single follow-up pass.
    if (_loadInFlight) {
      _reloadQueued = true;
      return;
    }
    _loadInFlight = true;
    try {
      await _loadDataOnce(showLoader: showLoader);
    } finally {
      _loadInFlight = false;
    }
    if (_reloadQueued && mounted) {
      _reloadQueued = false;
      await _loadData(showLoader: false);
    }
  }

  Future<void> _loadDataOnce({bool showLoader = true}) async {
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
      final stats = await MedicineCleanStorageService.getAdherenceStats(
          medicines: _medicines);
      _adherenceRate = (stats['adherenceRate'] as int) / 100.0;
      _adherenceScheduled = (stats['scheduled'] as int?) ?? 0;

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
      context.toastSuccess(
        'Logged $n dose${n == 1 ? '' : 's'} from your reminder',
        action: AppToastAction(
          label: 'Undo',
          onPressed: () async {
            for (final id in ids) {
              // Reverse the stock decrement for taken doses before deleting,
              // otherwise Undo silently loses inventory.
              final log = await MedicineCleanStorageService.getLog(id);
              if (log != null && log.countsAsTaken) {
                await MedicineCleanStorageService.restoreStock(
                    log.medicineId, log.dosageTaken);
              }
              await MedicineCleanStorageService.deleteLog(id);
            }
            await _loadData();
          },
        ),
      );
    }

    // One-shot: after a real adherence "win", ask for a store rating (never nags).
    if (!_ratingChecked && mounted) {
      _ratingChecked = true;
      RatingPromptService.maybePrompt(context, streak: _streak);
    }
    if (!_milestoneChecked && mounted) {
      _milestoneChecked = true;
      await _maybeCelebrateMilestone();
    }
  }

  static const String _lastCelebratedMilestoneKey =
      'medicineStreakLastCelebratedMilestone';

  /// Shows a one-time celebration the first time the streak crosses a new
  /// threshold (7/14/30/60/100/180/365 days) — persisted so it's shown once
  /// per milestone ever reached, not once per app open.
  Future<void> _maybeCelebrateMilestone() async {
    final last = CleanStorageService.getAppPreference(
        _lastCelebratedMilestoneKey) as int?;
    if (!isNewMilestone(_streak, last)) return;
    final reached = highestMilestoneReached(_streak);
    if (reached == null) return;
    await CleanStorageService.setAppPreference(
        _lastCelebratedMilestoneKey, reached);
    if (!mounted) return;
    _hapticService.medium();
    final ext = AppColorsExt.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ext.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
        title: Row(
          children: [
            Icon(Symbols.emoji_events_rounded, color: ext.warning.base),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('${milestoneLabel(reached)} streak!',
                  style: Theme.of(dialogContext)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: ext.textPrimary)),
            ),
          ],
        ),
        content: Text(
          "You've taken your medicine on schedule for $reached days straight. Keep it up!",
          style: Theme.of(dialogContext)
              .textTheme
              .bodyMedium
              ?.copyWith(color: ext.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Nice!', style: TextStyle(color: ext.mark(ext.medicine))),
          ),
        ],
      ),
    );
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
    // Compute from the medicines this screen already loaded rather than having
    // getTodaysDoses re-read the table. Measured, this screen read
    // `enhanced_medicines` SIX times for one open — and getAllMedicines()
    // re-maps every row and re-decodes every schedule JSON on each call.
    final doses = TodayScheduleService.dosesFrom(
      requestDate,
      medicines: _medicines,
      logs: await MedicineCleanStorageService.getLogsForDate(requestDate),
    );
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
      _takenStatus[d.key] = d.isTaken || d.isPreLogged;
    }
  }

  void _onDateChanged(DateTime date) {
    setState(() => _selectedDate = date);
    _buildTodaySchedule().then((_) => setState(() {}));
  }

  static const String _viewModeKey = 'medicationViewMode';

  /// Restores the last-chosen schedule layout (timeline vs. pillbox), falling
  /// back to timeline for a first run or a stored value that's out of range
  /// (e.g. an older/newer enum ordering).
  _MedicationViewMode _loadViewModePreference() {
    final stored = CleanStorageService.getAppPreference(
        _viewModeKey, _MedicationViewMode.timeline.index);
    final idx = (stored is int &&
            stored >= 0 &&
            stored < _MedicationViewMode.values.length)
        ? stored
        : _MedicationViewMode.timeline.index;
    return _MedicationViewMode.values[idx];
  }

  void _toggleViewMode() {
    _hapticService.light();
    final next = _viewMode == _MedicationViewMode.timeline
        ? _MedicationViewMode.pillbox
        : _MedicationViewMode.timeline;
    setState(() => _viewMode = next);
    CleanStorageService.setAppPreference(_viewModeKey, next.index);
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

    if (result == null) return;

    // Reflect the outcome on the row BEFORE the reload. The sheet already wrote
    // the log, so re-querying is only for the derived stats — waiting on it (and
    // on the full-screen loader it used to raise) made a Take/Skip look like it
    // hadn't registered until the screen came back.
    final log = result['log'];
    if (log is MedicineLog) _applyLogLocally(dose, log);

    // No loader: the schedule is already correct on screen, so this quietly
    // refreshes streak / adherence / refill state underneath.
    await _loadData(showLoader: false);

    if (!mounted) return;
    if (result['skipped'] == true && log is MedicineLog) {
      _confirmDoseOutcome('${dose.medicine.name} skipped', log);
    } else if (result['taken'] == true && log is MedicineLog) {
      _confirmDoseOutcome('${dose.medicine.name} taken', log);
    }
  }

  /// Optimistically swap the dose's log in place so the timeline flips to
  /// Taken/Skipped on the same frame the sheet closes.
  void _applyLogLocally(_ScheduledDose dose, MedicineLog log) {
    final i = _todaysDoses.indexWhere((d) =>
        d.medicine.id == dose.medicine.id && d.timeIndex == dose.timeIndex);
    if (i < 0) return;
    setState(() {
      _todaysDoses[i] = _ScheduledDose(
        medicine: _todaysDoses[i].medicine,
        scheduledTime: _todaysDoses[i].scheduledTime,
        timeIndex: _todaysDoses[i].timeIndex,
        log: log,
      );
      _takenStatus['${dose.medicine.id}_${dose.timeIndex}'] = log.countsAsTaken;
    });
  }

  /// One-line confirmation with Undo — a mis-tapped Skip used to be permanent
  /// (the row simply became non-actionable with no way back).
  void _confirmDoseOutcome(String message, MedicineLog log) {
    context.toastSuccess(
      message,
      action: AppToastAction(
        label: 'Undo',
        onPressed: () async {
          // Reverse the stock decrement first, or Undo silently loses inventory.
          if (log.countsAsTaken) {
            await MedicineCleanStorageService.restoreStock(
                log.medicineId, log.dosageTaken);
          }
          await MedicineCleanStorageService.deleteLog(log.id);
          await _loadData(showLoader: false);
        },
      ),
    );
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

  void _navigateToAppointments() {
    _hapticService.light();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NunitoAppointmentListScreen()),
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
                    : (_viewMode == _MedicationViewMode.pillbox
                        ? SliverToBoxAdapter(child: _buildPillboxGrid())
                        : _buildTimelineList()),
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
          icon: _viewMode == _MedicationViewMode.timeline
              ? Symbols.grid_view_rounded
              : Symbols.view_list_rounded,
          accent: ext.medicine,
          tooltip: _viewMode == _MedicationViewMode.timeline
              ? 'Pillbox view'
              : 'Timeline view',
          onPressed: _toggleViewMode,
        ),
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
    final milestone = highestMilestoneReached(_streak);
    final hasAdherence = _adherenceScheduled > 0;

    final streakBlock = Row(
      mainAxisSize: MainAxisSize.min,
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
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text('$_streak day streak',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  if (milestone != null) ...[
                    const SizedBox(width: 6),
                    Icon(Symbols.emoji_events_rounded,
                        size: 16, color: ext.warning.base),
                  ],
                ],
              ),
              Text(
                milestone != null
                    ? '${milestoneLabel(milestone)} milestone'
                    : 'Keep it going',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: ext.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );

    final adherenceBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(hasAdherence ? '${(_adherenceRate * 100).round()}%' : '--',
            maxLines: 1,
            softWrap: false,
            style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: hasAdherence
                    ? ext.mark(ext.medicine)
                    : ext.textTertiary)),
        // Name what the number measures and over what window. A bare
        // percentage is uninterpretable — users read it as "today". No
        // maxLines: on its own run at 200% this caption needs three lines,
        // and a clinical caption must wrap rather than ellipsize.
        Text(hasAdherence ? 'doses taken · 30 days' : 'no doses scheduled yet',
            textAlign: TextAlign.end,
            style: tt.bodySmall?.copyWith(color: ext.textSecondary)),
      ],
    );

    return AppCard(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 0),
      // Wrap, not Row: both blocks are text-sized, and as a Row they demanded
      // ~334pt side by side — more than a 320/360/375pt phone has even at the
      // DEFAULT text size, which is why the caption ("no doses scheduled yet")
      // used to be sliced off the card and the streak squeezed to zero width.
      // Wrap keeps them on one line, streak left / adherence flush right,
      // exactly as before whenever they fit, and drops the adherence stat onto
      // its own line — full size, nothing truncated — when they don't.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: [streakBlock, adherenceBlock],
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

    // The strip used to be a fixed `height: 80` Container around a horizontal
    // ListView. That height was the viewport, so every one of the seven chips
    // was laid out with a TIGHT 80px height — at large Dynamic Type each chip's
    // column needed more and every one of them printed its own "BOTTOM
    // OVERFLOWED" stripe with the date number sliced off. A min-height box
    // around an intrinsically-sized Row keeps the 80px look by default and
    // simply grows when the text does. IntrinsicHeight + stretch preserves the
    // uniform chip height the fixed viewport used to give for free.
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: dates.map((date) {
              final isSelected = _isSameDay(date, _selectedDate);
              final isToday = _isSameDay(date, now);

              return GestureDetector(
                onTap: () => _onDateChanged(date),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.standard,
                  width: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isSelected ? ext.fillBg(ext.medicine) : ext.surface,
                    borderRadius: AppRadius.brLg,
                    border: isSelected ? null : Border.all(color: ext.outline),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // The chip is a FIXED 56px wide — without scaleDown the
                      // selected day wrapped to "MO / N".
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          DateFormats.weekdayShort.format(date).toUpperCase(),
                          maxLines: 1,
                          softWrap: false,
                          style: tt.labelSmall?.copyWith(
                            color: isSelected
                                ? ext.fillFg(ext.medicine).withOpacity(0.8)
                                : ext.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          DateFormats.dayOfMonth.format(date),
                          maxLines: 1,
                          softWrap: false,
                          style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? ext.fillFg(ext.medicine)
                                : ext.textPrimary,
                          ),
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
            }).toList(),
          ),
        ),
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
        d.log?.isMissed == true ||
        d.log?.isPreLogged == true;
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
    final timeStr = DateFormats.time.format(dose.scheduledTime);

    // A dose can be taken / skipped / missed (terminal) — or, on a future day,
    // view-only. Previously only "taken" was tracked, so a skipped or missed
    // dose rendered as a fresh pending one and could be re-taken (duplicate log
    // + double stock decrement); a future dose could be "taken" early.
    final isSkipped = dose.log?.isSkipped == true;
    final isMissed = dose.log?.isMissed == true;
    final isPreLogged = dose.log?.isPreLogged == true;
    final isTerminal = isTaken || isSkipped || isMissed;
    final now = DateTime.now();
    final isFuture = DateTime(dose.scheduledTime.year, dose.scheduledTime.month,
            dose.scheduledTime.day)
        .isAfter(DateTime(now.year, now.month, now.day));
    final actionable = !isTerminal && !isFuture;
    final closed = isTerminal; // taken/skipped/missed/pre-logged all read as "done"

    // Pre-logged gets its own distinct treatment (ext.info) — it read as
    // "taken" via isTaken above (countsAsTaken already folded it into
    // _takenStatus), but a row that's actually a pre-log must stay visually
    // distinguishable from one confirmed at the real scheduled time,
    // including on a future day this dose hasn't reached yet.
    final dotColor = isPreLogged
        ? ext.info.base
        : (isTaken
            ? ext.success.base
            : (isNext ? ext.mark(ext.medicine) : ext.textTertiary.withOpacity(0.5)));
    final cardColor = isPreLogged
        ? ext.info.container
        : (isTaken
            ? ext.success.container
            : (isSkipped || isMissed ? ext.surfaceVariant : ext.surface));
    final nameColor = isPreLogged
        ? ext.info.onContainer
        : (isTaken
            ? ext.success.onContainer
            : (isSkipped || isMissed ? ext.textTertiary : ext.textPrimary));

    // Pill + name + action share one line only while the action still leaves a
    // readable name column. A "Take Now" button is 40pt of fixed padding plus
    // a label that grows with Dynamic Type, so on a 320pt phone the three
    // stopped fitting at 130% and overflowed by 121pt at 200% — the medicine
    // name was squeezed to nothing on the way there. Below the threshold the
    // action moves to its own line under the dose instead.
    //
    // Measured off MediaQuery, NOT a LayoutBuilder: this subtree sits inside
    // the timeline's [IntrinsicHeight], and a LayoutBuilder there throws
    // "does not support returning intrinsic dimensions". The card's content
    // width is a fixed inset from the screen: the row gutter on both sides,
    // the 56pt timeline rail, and the card's own AppSpacing.gutter padding.
    final cardWidth = MediaQuery.sizeOf(context).width -
        AppSpacing.gutter * 4 -
        _timelineRailWidth;
    final free = cardWidth -
        _doseTileSize -
        AppSpacing.md -
        _doseTrailingWidth(
            isTaken, isSkipped, isMissed, isPreLogged, isNext, actionable);
    // Floor scales with the text: at 200% a 64pt column shows nothing either.
    final stackAction = free < MediaQuery.textScalerOf(context).scale(64);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Timeline column
            SizedBox(
              width: _timelineRailWidth,
              child: Column(
                children: [
                  if (!isFirst)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isTaken
                            ? (isPreLogged ? ext.info.base : ext.success.base)
                                .withOpacity(0.3)
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
                        ? Icon(
                            isPreLogged
                                ? Symbols.schedule_rounded
                                : Symbols.check_rounded,
                            color: isPreLogged ? ext.info.on : ext.success.on,
                            size: 8)
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          NunitoPillIndicator(
                            color: dose.medicine.color,
                            shape: dose.medicine.shape,
                            size: _doseTileSize,
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
                                    color: isPreLogged
                                        ? ext.info.onContainer
                                        : (isTaken
                                            ? ext.success.onContainer
                                            : (isSkipped || isMissed
                                                ? ext.textTertiary
                                                : ext.textSecondary)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!stackAction)
                            _buildDoseTrailing(isTaken, isSkipped, isMissed,
                                isPreLogged, isNext, actionable, dose),
                        ],
                      ),
                      if (stackAction) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _buildDoseTrailing(isTaken, isSkipped,
                              isMissed, isPreLogged, isNext, actionable, dose),
                        ),
                      ],
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

  /// Trailing control for a timeline dose: a completed check, a Pre-logged
  /// badge (checked BEFORE the future-day fallback below — a pre-log is
  /// already resolved even on a day this dose hasn't reached yet), a
  /// Skipped/Missed badge (non-actionable), a Take button (only for a due,
  /// unhandled dose), or a view-only clock for a future-day dose.
  Widget _buildDoseTrailing(bool isTaken, bool isSkipped, bool isMissed,
      bool isPreLogged, bool isNext, bool actionable, _ScheduledDose dose) {
    final ext = AppColorsExt.of(context);
    if (isPreLogged) return _doseBadge('Pre-logged', ext.info.base);
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

  /// Fixed geometry of a timeline row, shared by the layout and by the
  /// one-line-vs-stacked measurement in [_buildTimelineItem].
  static const double _timelineRailWidth = 56;
  static const double _doseTileSize = 44;

  /// What [_buildDoseTrailing] will actually measure at the current text size:
  /// an [AppButton] is its label plus 40pt of fixed horizontal padding, a
  /// badge its label plus 20pt, and the check / clock fallbacks are fixed
  /// glyphs. Measured rather than assumed so the row's one-line-vs-stacked
  /// decision tracks Dynamic Type and the real font metrics.
  double _doseTrailingWidth(bool isTaken, bool isSkipped, bool isMissed,
      bool isPreLogged, bool isNext, bool actionable) {
    final tt = Theme.of(context).textTheme;
    if (isPreLogged) return _measureLabel('Pre-logged', tt.labelMedium) + 20;
    if (isTaken) return 28;
    if (isSkipped) return _measureLabel('Skipped', tt.labelMedium) + 20;
    if (isMissed) return _measureLabel('Missed', tt.labelMedium) + 20;
    if (actionable) {
      return _measureLabel(isNext ? 'Take Now' : 'Take', tt.labelLarge) + 40;
    }
    return 22;
  }

  /// One-line painted width of [text] in [style], with the ambient
  /// [DefaultTextStyle] merged in (font family / height) and the live text
  /// scaler applied — the same measuring approach the water dashboard uses to
  /// size its feature tiles.
  double _measureLabel(String text, TextStyle? style) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final painter = TextPainter(
      text: TextSpan(text: text, style: effective),
      textDirection: Directionality.of(context),
      maxLines: 1,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
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

  /// Alternate layout for today's schedule: a physical-pillbox-style tray,
  /// one compartment row per time-of-day slot, one pill icon per medicine due
  /// in that slot. Reuses the exact same `_todaysDoses`/`_takenStatus`/
  /// `_onTakeMedication` the timeline view is built from — nothing here is
  /// re-derived from storage.
  Widget _buildPillboxGrid() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    final Map<String, List<_ScheduledDose>> groups = {};
    for (final dose in _todaysDoses) {
      groups.putIfAbsent(_pillboxSlotLabel(dose), () => []).add(dose);
    }
    // _todaysDoses is already chronological (see _buildTodaySchedule), so the
    // first dose appended to each group is that slot's earliest — order the
    // rows by it, top-to-bottom like a real tray (morning first).
    final slotLabels = groups.keys.toList()
      ..sort((a, b) =>
          groups[a]!.first.scheduledTime.compareTo(groups[b]!.first.scheduledTime));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, AppSpacing.sm, AppSpacing.gutter, 0),
      child: Column(
        children: [
          for (final slot in slotLabels)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_pillboxSlotIcon(slot),
                            size: 18, color: ext.mark(ext.medicine)),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          slot,
                          style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: ext.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final dose in groups[slot]!) _buildPillboxCell(dose),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The time-of-day bucket for one dose: the matching `ScheduledTime`'s own
  /// `label` when the schedule set one (honoring a weekend override), else an
  /// hour-range fallback — needed for schedules that never set a label (e.g.
  /// "every X hours", whose slots are synthesized with no `ScheduledTime`).
  String _pillboxSlotLabel(_ScheduledDose dose) {
    final schedule = dose.medicine.schedule;
    final isWeekend = dose.scheduledTime.weekday == DateTime.saturday ||
        dose.scheduledTime.weekday == DateTime.sunday;
    final times = (isWeekend && schedule.hasWeekendOverride)
        ? schedule.weekendTimes!
        : schedule.times;
    for (final t in times) {
      if (t.hour == dose.scheduledTime.hour &&
          t.minute == dose.scheduledTime.minute) {
        final label = t.label?.trim();
        if (label != null && label.isNotEmpty) return label;
        break;
      }
    }
    final hour = dose.scheduledTime.hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    if (hour < 21) return 'Evening';
    return 'Bedtime';
  }

  IconData _pillboxSlotIcon(String slotLabel) {
    switch (slotLabel.toLowerCase()) {
      case 'morning':
        return Symbols.wb_twilight_rounded;
      case 'afternoon':
        return Symbols.wb_sunny_rounded;
      case 'evening':
        return Symbols.wb_cloudy_rounded;
      case 'bedtime':
      case 'night':
        return Symbols.bedtime_rounded;
      default:
        return Symbols.schedule_rounded;
    }
  }

  /// One pillbox compartment: the medicine's pill icon plus a status overlay,
  /// mirroring the SAME taken/skipped/missed/pre-logged/future rules
  /// `_buildTimelineItem` uses. Tapping an actionable (not yet resolved, not a
  /// future day) dose opens the same take-medication sheet as the timeline.
  Widget _buildPillboxCell(_ScheduledDose dose) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final isTaken =
        _takenStatus['${dose.medicine.id}_${dose.timeIndex}'] ?? false;
    final isSkipped = dose.log?.isSkipped == true;
    final isMissed = dose.log?.isMissed == true;
    final isPreLogged = dose.log?.isPreLogged == true;
    final isTerminal = isTaken || isSkipped || isMissed;
    final now = DateTime.now();
    final isFuture = DateTime(dose.scheduledTime.year, dose.scheduledTime.month,
            dose.scheduledTime.day)
        .isAfter(DateTime(now.year, now.month, now.day));
    final actionable = !isTerminal && !isFuture;

    final cellColor = isPreLogged
        ? ext.info.container
        : (isTaken
            ? ext.success.container
            : (isSkipped || isMissed ? ext.surfaceVariant : ext.surface));

    Widget? badge;
    if (isPreLogged) {
      badge = _pillboxBadge(Symbols.schedule_rounded, ext.info.base, ext.info.on);
    } else if (isTaken) {
      badge = _pillboxBadge(
          Symbols.check_rounded, ext.success.base, ext.success.on);
    } else if (isSkipped) {
      badge = _pillboxBadge(
          Symbols.close_rounded, ext.textTertiary, ext.surface);
    } else if (isMissed) {
      badge = _pillboxBadge(
          Symbols.priority_high_rounded, ext.warning.base, ext.warning.on);
    }

    final statusSuffix = isPreLogged
        ? ', pre-logged'
        : (isTaken
            ? ', taken'
            : (isSkipped ? ', skipped' : (isMissed ? ', missed' : '')));

    return MergeSemantics(
      child: Semantics(
        button: actionable,
        label: '${dose.medicine.name}, '
            '${DateFormats.time.format(dose.scheduledTime)}$statusSuffix',
        child: SizedBox(
          width: 88,
          child: AppCard(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm, horizontal: 6),
            color: cellColor,
            onTap: actionable ? () => _onTakeMedication(dose) : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Opacity(
                      opacity: (isSkipped || isMissed) ? 0.5 : 1,
                      child: NunitoPillIndicator(
                        color: dose.medicine.color,
                        shape: dose.medicine.shape,
                        size: 36,
                      ),
                    ),
                    if (badge != null)
                      Positioned(right: -4, top: -4, child: badge),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  dose.medicine.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: (isSkipped || isMissed)
                        ? ext.textTertiary
                        : ext.textPrimary,
                    decoration: isTerminal ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  DateFormats.time.format(dose.scheduledTime),
                  style: tt.labelSmall
                      ?.copyWith(color: ext.textTertiary, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillboxBadge(IconData icon, Color bg, Color fg) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: AppColorsExt.of(context).surface, width: 2),
      ),
      child: Icon(icon, size: 11, color: fg),
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
      _QuickTile('Appointments', Symbols.event_rounded, ext.warning,
          _navigateToAppointments),
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

/// Layout for today's schedule: the default vertical timeline, or the
/// pillbox-tray grid (one row per time-of-day slot).
enum _MedicationViewMode { timeline, pillbox }

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

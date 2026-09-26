import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../core/utils/date_formats.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../../../core/widgets/confirmation_bottom_sheet.dart';
import '../widgets/nunito_pill_visual.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_log.dart';
import '../models/drug_interaction.dart';
import '../models/medicine_enums.dart';
import '../services/medicine_storage_service.dart';
import '../services/dose_undo.dart';
import '../services/medication_reminder_service.dart';
import '../services/drug_interaction_service.dart';
import '../services/drug_name_catalog.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/health/coach_text.dart';
import '../../../core/health/drug_info_catalog.dart';
import '../../../core/health/refill_predictor.dart';
import '../../../core/health/med_safety_checker.dart';
import '../../../core/health/insight.dart';
import '../../../core/health/insight_engine.dart';
import '../../../core/health/adherence_analyzer.dart';
import '../../../core/health/streak_engine.dart';
import '../../../core/health/adaptive_timing.dart';
import 'nunito_add_medication_flow.dart';
import 'nunito_take_medication_sheet.dart';

class NunitoMedicationDetailScreen extends StatefulWidget {
  final EnhancedMedicine medicine;

  const NunitoMedicationDetailScreen({
    super.key,
    required this.medicine,
  });

  /// The one delete confirmation for a medicine, shared with the list screen.
  ///
  /// The two surfaces had drifted into different sheets AND different copy —
  /// the list only said "This action cannot be undone", which doesn't tell the
  /// user that the dose history goes with it. Deleting a medicine is the most
  /// destructive thing either screen can do, so both now ask the same
  /// question, in the destructive sheet's own error accent.
  static Future<bool?> confirmDelete(
          BuildContext context, EnhancedMedicine medicine) =>
      ConfirmationBottomSheet.showDelete(
        context: context,
        itemName: medicine.name,
        customMessage: 'This permanently deletes ${medicine.name} and its '
            'whole dose history. This cannot be undone.',
      );

  @override
  State<NunitoMedicationDetailScreen> createState() => _NunitoMedicationDetailScreenState();
}

class _NunitoMedicationDetailScreenState extends State<NunitoMedicationDetailScreen>
    with SingleTickerProviderStateMixin {
  late EnhancedMedicine _medicine;
  List<MedicineLog> _recentLogs = [];
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  final DrugInteractionService _interactionService = DrugInteractionService();
  List<DrugInteraction> _interactions = [];
  List<String> _foodWarnings = [];

  // AI (pure-Dart, offline): refill forecast from real consumption + allergy /
  // duplicate-therapy safety warnings.
  RefillPrediction? _refill;
  List<MedSafetyWarning> _safetyWarnings = [];
  List<Insight> _medInsights = [];

  // AI plain-language rephrasing of the rules-based interactions. The rules
  // remain the source of truth; this only restates them for the patient.
  String? _interactionExplanation;
  bool _explainingInteractions = false;
  bool _interactionExplainFailed = false;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  final HapticService _hapticService = HapticService();
  final MedicationReminderService _reminderService = MedicationReminderService();

  @override
  void initState() {
    super.initState();
    _medicine = widget.medicine;
    _controller = AnimationController(
      duration: AppMotion.slow,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: AppMotion.standard);
    _loadData();
    // Doses can be logged from anywhere (a notification, the dashboard timeline,
    // the quick-log sheet). Without this the history/adherence on this screen
    // stayed stale until it was popped and reopened.
    MedicineCleanStorageService.revision.addListener(_onMedicineRevision);
  }

  void _onMedicineRevision() {
    if (mounted) _loadData(showLoader: false);
  }

  @override
  void dispose() {
    MedicineCleanStorageService.revision.removeListener(_onMedicineRevision);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoader = true}) async {
    if (showLoader) setState(() => _isLoading = true);
    try {
      // Ensure the brand→generic catalog is ready for the "What it's for" bridge.
      await DrugNameCatalog.ensureLoaded();
      // Reload medicine data
      final medicines = await MedicineCleanStorageService.getAllMedicines();
      final updated = medicines.where((m) => m.id == _medicine.id).firstOrNull;
      if (updated != null) {
        _medicine = updated;
      }

      _computeInteractions(medicines);

      // This medicine's dose history, read ONCE for every consumer below.
      //
      // Three of them want the same rows — the history list, the refill/insight
      // engines, and the adherence stats — and each used to fetch its own copy,
      // so opening the screen cost three full selects of `medicine_logs`.
      // Deduped per slot so one dose can't appear twice in the history list,
      // and sorted newest-first because that is the order the history list
      // renders in (and the order the DAO already returned).
      final allLogs = MedicineCleanStorageService.dedupeByDose(
          await MedicineCleanStorageService.getLogsForMedicine(_medicine.id))
        ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
      _recentLogs =
          allLogs.length > 10 ? allLogs.sublist(0, 10) : List.of(allLogs);

      // Adherence = taken / SCHEDULED doses, never taken / number-of-log-rows:
      // log rows are outcomes, not the doses that were due, so the old ratio
      // read 0% for a brand-new medicine with no logs and was meaningless in
      // general. getAdherenceStatsForMedicine owns the scheduled-slot rule
      // (due-only, from the medicine's creation, PRN/archived excluded) and is
      // the same source the dashboard's headline adherence uses. `allLogs` is
      // what it would otherwise re-read; it applies its own window filter, so
      // handing it the whole history changes nothing but the read count.
      //
      // `medicine:` is the same row this method read moments ago — without it
      // the service falls back to `getMedicine(id)` and selects
      // `enhanced_medicines` a second time for a row already in hand. If the
      // medicine was deleted from under an open screen, this now reports the
      // schedule the screen is still SHOWING rather than silently dropping to
      // "0 doses scheduled", which is the more honest of the two.
      _stats = await MedicineCleanStorageService.getAdherenceStatsForMedicine(
        _medicine.id,
        days: _lifetimeWindowDays,
        medicine: _medicine,
        allLogs: allLogs,
      );

      _computeRefill(allLogs);
      await _computeSafety(medicines);
      _computeMedInsights(allLogs);

      _controller.forward();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// Trailing-window length that covers this medicine's whole life, so the
  /// stats row stays all-time (matching the Taken tile's existing meaning)
  /// rather than silently becoming a 30-day figure. Slots before `createdAt`
  /// are skipped by the service anyway, so over-reaching is harmless — hence
  /// the +2 slack, which also absorbs the DST hour that can make a whole-day
  /// `difference().inDays` come back one short.
  int get _lifetimeWindowDays {
    final now = DateTime.now();
    final created = _medicine.createdAt;
    final days = DateTime(now.year, now.month, now.day)
            .difference(DateTime(created.year, created.month, created.day))
            .inDays +
        2;
    return days < 1 ? 1 : days;
  }

  /// This medicine's representative name for interaction lookups
  /// (generic when known, otherwise the display name).
  String get _lookupName =>
      (_medicine.genericName != null && _medicine.genericName!.trim().isNotEmpty)
          ? _medicine.genericName!
          : _medicine.name;

  /// Check this medicine against every other active medicine and collect any
  /// food interactions from the built-in drug database.
  void _computeInteractions(List<EnhancedMedicine> allMedicines) {
    final results = <DrugInteraction>[];
    for (final other in allMedicines) {
      if (other.id == _medicine.id) continue;
      if (!other.isActive || other.isArchived) continue;
      final otherName = (other.genericName != null &&
              other.genericName!.trim().isNotEmpty)
          ? other.genericName!
          : other.name;
      results.addAll(_interactionService.checkInteraction(_lookupName, otherName));
    }
    // De-duplicate by interaction id, then sort most-severe first.
    final seen = <String>{};
    _interactions = results.where((i) => seen.add(i.id)).toList()
      ..sort((a, b) => b.severity.index.compareTo(a.severity.index));

    _foodWarnings = _interactionService.checkFoodInteractions(_lookupName);
  }

  /// Project run-out from the user's OWN taken-dose history (last 21 days) —
  /// more accurate than dividing stock by the scheduled rate.
  void _computeRefill(List<MedicineLog> allLogs) {
    if (_medicine.currentStock == null) {
      _refill = null;
      return;
    }
    final taken = allLogs.where((l) => l.countsAsTaken).toList();
    _refill = RefillPredictor.predict(
      currentStock: _medicine.currentStock!,
      doseTimes: taken.map((l) => l.actionTime ?? l.scheduledTime).toList(),
      doseAmounts: taken.map((l) => l.dosageTaken).toList(),
      lowStockThreshold: _medicine.lowStockThreshold,
      windowDays: 21,
    );
  }

  /// Duplicate-therapy (across active meds) + drug–allergy (against the taker's
  /// stored allergies) checks — pure Dart, offline.
  Future<void> _computeSafety(List<EnhancedMedicine> allMedicines) async {
    final active = allMedicines
        .where((m) => m.isActive && !m.isArchived)
        .map((m) => MedRef(id: m.id, name: m.name, genericName: m.genericName))
        .toList();

    List<String> allergies = const [];
    if (_medicine.dependentId != null) {
      try {
        final deps = await MedicineCleanStorageService.getAllDependents();
        final profile =
            deps.where((d) => d.id == _medicine.dependentId).firstOrNull;
        allergies = profile?.allergies ?? const [];
      } catch (_) {/* best-effort */}
    }

    final warnings = <MedSafetyWarning>[
      ...MedSafetyChecker.checkAllergies(
        name: _medicine.name,
        genericName: _medicine.genericName,
        allergies: allergies,
      ),
      // Only duplicates that actually involve THIS medicine.
      ...MedSafetyChecker.checkDuplicates(active)
          .where((w) => w.message.contains(_medicine.name)),
    ];
    _safetyWarnings = warnings;
  }

  /// Deterministic medicine insights — surfaces the AdherenceAnalyzer,
  /// StreakEngine and AdaptiveTiming engines (adherence %, dose streak, supply,
  /// and a "you usually take this later" reminder-time suggestion).
  void _computeMedInsights(List<MedicineLog> allLogs) {
    final out = <Insight>[];

    // Adherence % + dose streak from the log history.
    final history = allLogs
        .where((l) => l.countsAsTaken || l.isMissed || l.isSkipped)
        .map((l) => DoseEvent(
              l.scheduledTime,
              l.countsAsTaken
                  ? DoseOutcome.taken
                  : (l.isMissed ? DoseOutcome.missed : DoseOutcome.skipped),
            ))
        .toList();
    final adherence = history.isEmpty ? null : AdherenceAnalyzer.adherence(history);
    final takenDays = allLogs
        .where((l) => l.countsAsTaken)
        .map((l) => DateTime(l.scheduledTime.year, l.scheduledTime.month, l.scheduledTime.day))
        .toSet();
    final streak = StreakEngine.compute(completedDays: takenDays, today: DateTime.now());

    final primary = InsightEngine.medicine(
      adherence: adherence,
      streakDays: streak.current,
      daysOfSupply: _refill?.daysRemaining,
    );
    if (primary != null) out.add(primary);

    // AdaptiveTiming: compare real take-times to the first scheduled slot.
    final times = _medicine.schedule.times;
    if (times.isNotEmpty) {
      final scheduledMin = times.first.hour * 60 + times.first.minute;
      // Deliberately l.isTaken, NOT countsAsTaken: a pre-log's actionTime is
      // an artificial early timestamp, not a real "when do I actually take
      // this dose" data point — folding it in would corrupt the suggestion.
      final actualMins = allLogs
          .where((l) => l.isTaken && l.actionTime != null)
          .map((l) => l.actionTime!.hour * 60 + l.actionTime!.minute)
          .toList();
      final s = AdaptiveTiming.suggest(
          scheduledMinutes: scheduledMin, actualMinutes: actualMins);
      if (s.confident) {
        final h = (s.suggestedMinutes ~/ 60).toString().padLeft(2, '0');
        final m = (s.suggestedMinutes % 60).toString().padLeft(2, '0');
        final laterEarlier = s.deltaMinutes > 0 ? 'later' : 'earlier';
        out.add(Insight(
          id: 'med_adaptive',
          feature: InsightFeature.medicine,
          severity: InsightSeverity.info,
          title: 'You usually take this $laterEarlier',
          detail:
              'On average you take this about ${s.deltaMinutes.abs()} min $laterEarlier than scheduled. Shifting the reminder to $h:$m could fit your routine better.',
          metric: '$h:$m',
          why:
              'Median of your ${s.sampleCount} recorded take-times vs the scheduled time.',
          rank: 48,
        ));
      }
    }

    _medInsights = InsightEngine.rankAll(out);
  }

  /// Rephrase the rules-based interaction findings in plain language for the
  /// patient. The rules data stays the source of truth; AI only restates it.
  Future<void> _explainInteractions() async {
    if (_interactions.isEmpty) return;
    _hapticService.light();
    setState(() {
      _explainingInteractions = true;
      _interactionExplainFailed = false;
      _interactionExplanation = null;
    });

    final descriptions = _interactions.map((i) {
      final other = i.drug1Name.toLowerCase() == _lookupName.toLowerCase()
          ? i.drug2Name
          : i.drug1Name;
      final rec = i.recommendation != null ? ' Recommendation: ${i.recommendation}' : '';
      return '${_medicine.name} + $other (${i.severity.displayName}): ${i.description}.$rec';
    }).toList();

    final result = const CoachText().explainInteractions(descriptions);

    if (!mounted) return;
    setState(() {
      _interactionExplanation = result;
      _interactionExplainFailed = false; // deterministic: cannot fail
      _explainingInteractions = false;
    });
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

  /// Show the curated offline monograph for this medicine as a plain reference
  /// section — what it's for, common side effects, whether to take it with food,
  /// and precautions. No question to phrase, no generation: it's a bundled
  /// lookup by active ingredient. Absent from the catalogue → say so plainly.
  Future<void> _showAbout() async {
    _hapticService.light();
    await DrugInfoCatalog.ensureLoaded();
    if (!mounted) return;

    // Try the stored generic, then the display name, then resolve a BRAND name
    // to its generic. Without the last hop a medicine entered as "Glucophage"
    // found no monograph even though the app can map it to metformin.
    final info = DrugInfoCatalog.find(
          generic: _medicine.genericName,
          displayName: _medicine.name,
        ) ??
        DrugInfoCatalog.find(
          generic: DrugNameCatalog.genericFor(_medicine.name),
        );
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    Widget para(String heading, String body) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppEyebrow(heading),
              const SizedBox(height: 4),
              Text(body,
                  style: tt.bodyMedium
                      ?.copyWith(color: ext.textPrimary, height: 1.45)),
            ],
          ),
        );

    await AppBottomSheet.show(
      context,
      title: 'About ${_medicine.name}',
      icon: Symbols.info_rounded,
      accent: ext.medicine,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: info == null
            ? [
                Text(
                  'We don\'t have reference information for this medicine. '
                  'Your pharmacist or the leaflet in the box is the best source.',
                  style: tt.bodyMedium
                      ?.copyWith(color: ext.textSecondary, height: 1.45),
                ),
              ]
            : [
                if (info.klass.isNotEmpty) para('Type', info.klass),
                para('What it\'s for', info.uses),
                para('Common side effects', info.sideEffects),
                para('With food?', info.food),
                para('Good to know', info.precautions),
                const SafetyDisclaimerBar(),
              ],
      ),
    );
  }

  void _editMedicine() {
    _hapticService.light();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NunitoAddMedicationFlow(editMedicine: _medicine),
      ),
    ).then((result) {
      if (result == true) _loadData();
    });
  }

  Future<void> _toggleArchive() async {
    _hapticService.warning();
    final previous = _medicine;
    final updated = _medicine.copyWith(isArchived: !_medicine.isArchived);
    await MedicineCleanStorageService.saveMedicine(updated);
    await _syncReminders(updated);

    if (!mounted) return; // awaits above may outlive the screen
    setState(() => _medicine = updated);

    context.toastSuccess(
      _medicine.isArchived ? 'Medicine archived' : 'Medicine restored',
      // The same Undo the list screen's swipe-to-archive offers. Archiving
      // silently cancels every reminder the medicine has, so the two places
      // that can do it must both be one tap from reversing it.
      action: AppToastAction(
        label: 'Undo',
        onPressed: () async {
          await MedicineCleanStorageService.saveMedicine(previous);
          await _syncReminders(previous);
          if (mounted) setState(() => _medicine = previous);
        },
      ),
    );
  }

  /// Cancel or (re)schedule this medicine's reminders to match its archived
  /// state — the list screen's `_syncReminders`, same rule.
  Future<void> _syncReminders(EnhancedMedicine medicine) async {
    if (medicine.isArchived) {
      await _reminderService.cancelReminders(medicine);
    } else {
      await _reminderService.scheduleReminders(medicine);
    }
  }

  Future<void> _deleteMedicine() async {
    final confirm =
        await NunitoMedicationDetailScreen.confirmDelete(context, _medicine);

    if (confirm == true) {
      _hapticService.error();
      await _reminderService.cancelReminders(_medicine);
      await MedicineCleanStorageService.deleteMedicine(_medicine.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccentScope(
      feature: FeatureAccent.medicine,
      child: AppScaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : FadeTransition(
                opacity: _fadeAnimation,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildHeader(),
                    SliverToBoxAdapter(child: _buildStatsSection()),
                    SliverToBoxAdapter(child: _buildInsightsSection()),
                    SliverToBoxAdapter(child: _buildScheduleSection()),
                    SliverToBoxAdapter(child: _buildDetailsSection()),
                    SliverToBoxAdapter(child: _buildWhatItsForSection()),
                    SliverToBoxAdapter(child: _buildStockSection()),
                    SliverToBoxAdapter(child: _buildInteractionsSection()),
                    SliverToBoxAdapter(child: _buildSafetySection()),
                    SliverToBoxAdapter(child: _buildHistorySection()),
                    SliverToBoxAdapter(child: _buildActionsSection()),
                    SliverToBoxAdapter(
                        child: SizedBox(height: AppInsets.pushed(context))),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final headerBg = ext.fillBg(ext.medicine);
    final onHeader = ext.fillFg(ext.medicine);

    // `FlexibleSpaceBar` lays its background out at exactly `expandedHeight`,
    // so a flat 200 clips the title block at large text. This is the last of
    // the four collapsing headers still doing that; the other three derive it
    // (`focus_garden_screen.dart:64` records the 18px clip at 200% that made
    // them, `aqua_water_dashboard.dart:708`, `water_achievements_screen.dart:82`).
    //
    // The arithmetic, so the constant is checkable rather than tuned: 116 is
    // fixed — 40 of `EdgeInsets.all(gutter)` and a 76pt toolbar band. The rest
    // is the content row, which is `max(pill, text)`: the pill visual is 56 in
    // a 12pt-padded box and does NOT scale, while the text is two lines of
    // headlineMedium (22/28), a 4pt gap and one line of bodyLarge (16/24) —
    // 2*28 + 4 + 24 = 84 at 1.0x, which is what keeps this at 200 there.
    final textScaler = MediaQuery.textScalerOf(context);
    final textBlock = textScaler.scale(28) * 2 + 4 + textScaler.scale(24);
    // The archived pill is conditional and was never budgeted for at all:
    // 8 of margin, 8 of vertical padding and a labelSmall line box.
    final archivedBand =
        _medicine.isArchived ? 16 + textScaler.scale(16) : 0.0;

    return SliverAppBar(
      expandedHeight: 116 + math.max(80.0, textBlock) + archivedBand,
      pinned: true,
      backgroundColor: headerBg,
      foregroundColor: onHeader,
      leading: IconButton(
        icon: Icon(Symbols.arrow_back_rounded, color: onHeader),
        tooltip: 'Back',
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(Symbols.info_rounded, color: onHeader),
          tooltip: 'About this medicine',
          onPressed: _showAbout,
        ),
        IconButton(
          icon: Icon(Symbols.edit_rounded, color: onHeader),
          tooltip: 'Edit medicine',
          onPressed: _editMedicine,
        ),
        PopupMenuButton<String>(
          icon: Icon(Symbols.more_vert_rounded, color: onHeader),
          color: ext.surfaceElevated,
          onSelected: (value) {
            if (value == 'archive') _toggleArchive();
            if (value == 'delete') _deleteMedicine();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'archive',
              child: Row(
                children: [
                  Icon(
                    _medicine.isArchived ? Symbols.unarchive_rounded : Symbols.archive_rounded,
                    color: ext.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(_medicine.isArchived ? 'Restore' : 'Archive',
                      style: TextStyle(color: ext.textPrimary)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Symbols.delete_rounded, color: ext.mark(ext.error)),
                  const SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: ext.mark(ext.error))),
                ],
              ),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: headerBg,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: onHeader.withOpacity(0.15),
                          borderRadius: AppRadius.brLg,
                        ),
                        child: NunitoPillVisual(
                          color: _medicine.color,
                          shape: _medicine.shape,
                          size: 56,
                          showShadow: false,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _medicine.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tt.headlineMedium?.copyWith(
                                  color: onHeader, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _medicine.displayDosage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodyLarge
                                  ?.copyWith(color: onHeader.withOpacity(0.8)),
                            ),
                            if (_medicine.isArchived)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: onHeader.withOpacity(0.15),
                                  borderRadius: AppRadius.brMd,
                                ),
                                child: Text(
                                  'Archived',
                                  style: tt.labelSmall?.copyWith(color: onHeader),
                                ),
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
      ),
    );
  }

  Widget _buildStatsSection() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final scheduled = (_stats['scheduled'] as int?) ?? 0;
    // Nothing was ever due (brand-new medicine, PRN, or archived) → adherence
    // is undefined. Show the same honest no-data state the dashboard shows
    // ("--" plus "no doses scheduled yet") instead of fabricating a percentage.
    final hasAdherence = scheduled > 0;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatTileRow(
            tiles: [
              StatTile(
                label: 'Adherence',
                value: hasAdherence ? '${_stats['adherenceRate'] ?? 0}%' : '--',
                icon: Symbols.trending_up_rounded,
                accent: ext.success,
              ),
              StatTile(
                label: 'Taken',
                value: '${_stats['taken'] ?? 0}',
                icon: Symbols.check_circle_rounded,
                accent: ext.info,
              ),
              // Scheduled, not "total log rows": it is the denominator of the
              // adherence tile beside it, so the row now reads consistently.
              StatTile(
                label: 'Scheduled',
                value: '$scheduled',
                icon: Symbols.event_repeat_rounded,
                accent: ext.medicine,
              ),
            ],
          ),
          if (!hasAdherence) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _medicine.schedule.isPRN
                  ? 'taken as needed — no fixed schedule'
                  : 'no doses scheduled yet',
              style: tt.bodySmall?.copyWith(color: ext.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    if (_medInsights.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.gutter),
      child: Column(
        children: [
          for (final i in _medInsights)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: InsightCard(insight: i),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final schedule = _medicine.schedule;
    // Archived meds have their reminders cancelled, so don't imply an upcoming
    // dose or an active reminder state on the Schedule card.
    final nextTime =
        _medicine.isArchived ? null : _reminderService.getNextReminderTime(_medicine);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, 0, AppSpacing.gutter, 0),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.schedule_rounded,
                    color: ext.mark(ext.medicine), size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Schedule', style: tt.titleLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildDetailRow('Frequency', schedule.frequencyType.displayName),
            if (schedule.times.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildDetailRow(
                'Times',
                schedule.times.map((t) => t.formattedTime).join(', '),
              ),
            ],
            if (nextTime != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildDetailRow(
                'Next Dose',
                DateFormats.weekdayDayMonthTime.format(nextTime),
                highlight: true,
              ),
            ],
            if (_medicine.reminderEnabled && !_medicine.isArchived) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: ext.success.container,
                  borderRadius: AppRadius.brSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Symbols.notifications_active_rounded,
                        color: ext.success.onContainer, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Reminders enabled',
                      style: tt.labelMedium
                          ?.copyWith(color: ext.success.onContainer),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.info_rounded,
                    color: ext.mark(ext.medicine), size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Details', style: tt.titleLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildDetailRow('Form', _medicine.dosageForm.displayName),
            if (_medicine.route != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildDetailRow('Route', _medicine.route!.displayName),
            ],
            if (_medicine.strength != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildDetailRow('Strength', _medicine.strength!),
            ],
            if (_medicine.instructions != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildDetailRow('Instructions', _medicine.instructions!),
            ],
            if (_medicine.purpose != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildDetailRow('Purpose', _medicine.purpose!),
            ],
          ],
        ),
      ),
    );
  }

  /// Plain-language "what it's for" from the curated on-device monograph.
  /// Collapses when there's no monograph AND the user already wrote a Purpose
  /// (the Details card shows that), so we never duplicate or fabricate.
  Widget _buildWhatItsForSection() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final summary = _interactionService.purposeSummary(
        name: _medicine.name, genericName: _medicine.genericName);
    final hasUserPurpose =
        _medicine.purpose != null && _medicine.purpose!.trim().isNotEmpty;
    if (summary == null && hasUserPurpose) return const SizedBox.shrink();

    final onC = ext.medicine.onContainer;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: AppCard(
        color: ext.medicine.container,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.help_rounded, color: onC, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('What it\'s for',
                    style: tt.titleLarge?.copyWith(color: onC)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              summary ??
                  'Not sure what this is for? Add a note under Edit, or ask '
                      'your pharmacist.',
              style: tt.bodyMedium?.copyWith(color: onC, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Symbols.info_rounded,
                    size: 13, color: onC.withValues(alpha: 0.75)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'General reference — confirm with your doctor or pharmacist.',
                    style: tt.bodySmall
                        ?.copyWith(color: onC.withValues(alpha: 0.75)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool highlight = false}) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(color: ext.textTertiary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: tt.bodyMedium?.copyWith(
              color: highlight ? ext.mark(ext.warning) : ext.textPrimary,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStockSection() {
    // Untracked medicines (never given a stock count) don't show a stock card.
    if (_medicine.currentStock == null) return const SizedBox.shrink();
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final stock = _medicine.currentStock!;
    final low = _medicine.isLowStock;
    // -1 when supply can't be derived (no fixed schedule / PRN).
    final days = _medicine.estimatedDaysRemaining;
    final swatch = low ? ext.warning : ext.medicine;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.gutter),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.inventory_2_rounded,
                    color: ext.mark(swatch), size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Stock', style: tt.titleLarge),
                const Spacer(),
                if (days >= 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: swatch.container,
                      borderRadius: AppRadius.brMd,
                    ),
                    child: Text(
                      '$days ${days == 1 ? 'day' : 'days'} left',
                      style: tt.labelMedium?.copyWith(
                          color: swatch.onContainer,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$stock',
                  style: tt.displaySmall?.copyWith(
                      color: ext.textPrimary, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${_medicine.dosageForm.unit} remaining',
                    style:
                        tt.bodyMedium?.copyWith(color: ext.textSecondary),
                  ),
                ),
              ],
            ),
            // AI refill forecast from real consumption (when there's history).
            if (_refill != null && _refill!.daysRemaining != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(Symbols.insights_rounded,
                      size: 15, color: ext.mark(ext.medicine)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _refill!.summary,
                      style: tt.bodySmall?.copyWith(color: ext.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
            if (low) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: ext.warning.container,
                  borderRadius: AppRadius.brMd,
                ),
                child: Row(
                  children: [
                    Icon(Symbols.warning_amber_rounded,
                        color: ext.warning.onContainer, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Running low — only $stock left. Time to refill.',
                        style: tt.bodySmall?.copyWith(
                            color: ext.warning.onContainer,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Refill',
              leadingIcon: Symbols.add_rounded,
              variant:
                  low ? AppButtonVariant.primary : AppButtonVariant.secondary,
              accent: ext.medicine,
              fullWidth: true,
              onPressed: _refillStock,
            ),
            if (!_medicine.refillReminderEnabled) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Refill reminders are off — enable them in Edit.',
                style: tt.bodySmall?.copyWith(color: ext.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _refillStock() async {
    _hapticService.light();
    final amount = await AppBottomSheet.show<int>(
      context,
      title: 'Refill ${_medicine.name}',
      icon: Symbols.inventory_2_rounded,
      accent: AppColorsExt.of(context).medicine,
      builder: (_) => _RefillSheet(medicine: _medicine),
    );
    if (amount != null && amount > 0) {
      await MedicineCleanStorageService.refillStock(_medicine.id, amount);
      _hapticService.success();
      await _loadData();
      if (mounted) {
        context.toastSuccess('Added $amount to ${_medicine.name}');
      }
    }
  }

  Widget _buildInteractionsSection() {
    if (_interactions.isEmpty && _foodWarnings.isEmpty) {
      return const SizedBox.shrink();
    }
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    // Headline accent escalates to error when a serious interaction exists.
    final hasSerious = _interactions.any((i) =>
        i.severity == InteractionSeverity.severe ||
        i.severity == InteractionSeverity.contraindicated);
    final headerSwatch = hasSerious ? ext.error : ext.warning;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.gutter),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.warning_amber_rounded,
                    color: ext.mark(headerSwatch), size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Interactions & Cautions', style: tt.titleLarge),
              ],
            ),
            if (_interactions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'With your other active medicines',
                style: tt.bodySmall?.copyWith(color: ext.textTertiary),
              ),
              const SizedBox(height: AppSpacing.sm),
              ..._interactions.map(_buildInteractionTile),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Explain in plain language',
                leadingIcon: Symbols.auto_awesome_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                accent: ext.medicine,
                loading: _explainingInteractions,
                onPressed: _explainingInteractions ? null : _explainInteractions,
              ),
              if (_interactionExplanation != null ||
                  _interactionExplainFailed) ...[
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  color: ext.medicine.container,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Symbols.auto_awesome_rounded,
                              color: ext.medicine.onContainer, size: 16),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'In plain language',
                            style: tt.labelLarge?.copyWith(
                                color: ext.medicine.onContainer,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _interactionExplainFailed
                            ? 'Couldn\'t generate an explanation right now. Please try again.'
                            : _interactionExplanation!,
                        style: tt.bodyMedium?.copyWith(
                            color: ext.medicine.onContainer, height: 1.4),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'General information — not medical advice. '
                        'Consult your doctor or pharmacist.',
                        style: tt.bodySmall?.copyWith(
                            color: ext.medicine.onContainer.withOpacity(0.75)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            if (_foodWarnings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Food & lifestyle',
                style: tt.bodySmall?.copyWith(color: ext.textTertiary),
              ),
              const SizedBox(height: AppSpacing.sm),
              ..._foodWarnings.map(
                (w) => _buildBulletRow(
                    w, Symbols.restaurant_rounded, ext.warning),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionTile(DrugInteraction interaction) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final swatch = _severitySwatch(interaction.severity);
    final other = interaction.drug1Name.toLowerCase() ==
            _lookupName.toLowerCase()
        ? interaction.drug2Name
        : interaction.drug1Name;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: swatch.container,
        borderRadius: AppRadius.brMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'With $other',
                  style: tt.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700, color: swatch.onContainer),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ext.surface,
                  borderRadius: AppRadius.brSm,
                ),
                child: Text(
                  interaction.severity.displayName,
                  style: tt.labelSmall?.copyWith(
                      color: ext.mark(swatch), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            interaction.description,
            style: tt.bodySmall?.copyWith(
                color: swatch.onContainer.withOpacity(0.9)),
          ),
          if (interaction.recommendation != null) ...[
            const SizedBox(height: 6),
            Text(
              interaction.recommendation!,
              style: tt.bodySmall?.copyWith(
                  color: swatch.onContainer,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSafetySection() {
    final warnings = _medicine.warnings ?? const [];
    final sideEffects = _medicine.sideEffects ?? const [];
    if (warnings.isEmpty && sideEffects.isEmpty && _safetyWarnings.isEmpty) {
      return const SizedBox.shrink();
    }
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.gutter),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Symbols.health_and_safety_rounded,
                    color: ext.mark(ext.warning), size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Warnings & Side Effects', style: tt.titleLarge),
              ],
            ),
            // AI safety checks (allergy conflict / duplicate therapy) first —
            // highest-signal, from the user's own data.
            if (_safetyWarnings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              ..._safetyWarnings.map((w) => _buildBulletRow(
                    w.message,
                    w.kind == 'allergy'
                        ? Symbols.dangerous_rounded
                        : Symbols.copy_all_rounded,
                    w.severity == 'high' ? ext.error : ext.warning,
                  )),
            ],
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Warnings',
                  style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
              const SizedBox(height: AppSpacing.sm),
              ...warnings.map((w) =>
                  _buildBulletRow(w, Symbols.error_rounded, ext.error)),
            ],
            if (sideEffects.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Possible side effects',
                  style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
              const SizedBox(height: AppSpacing.sm),
              ...sideEffects.map((s) =>
                  _buildBulletRow(s, Symbols.circle_rounded, ext.warning, small: true)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBulletRow(String text, IconData icon, AccentSwatch accent,
      {bool small = false}) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: small ? 6 : 2),
            child: Icon(icon,
                size: small ? 8 : 16, color: ext.mark(accent)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: tt.bodyMedium?.copyWith(color: ext.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_recentLogs.isEmpty) return const SizedBox.shrink();
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, 0, AppSpacing.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.history_rounded,
                  color: ext.mark(ext.medicine), size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('Recent history', style: tt.titleLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...(_recentLogs.take(5).map((log) => _buildLogItem(log))),
        ],
      ),
    );
  }

  Widget _buildLogItem(MedicineLog log) {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final status = log.isTaken
        ? 'Taken'
        : (log.isPreLogged
            ? 'Pre-logged'
            : (log.isSkipped ? 'Skipped' : 'Missed'));
    // Status colours must match the medication dashboard exactly: Skipped reads
    // as neutral grey, Missed as amber. They used to be swapped between the two
    // surfaces (amber = "Missed" on the dashboard, amber = "Skipped" here),
    // which is the sharpest comprehension failure for adherence data. A null
    // swatch means "no accent" — the neutral grey used for Skipped.
    final swatch = log.isTaken
        ? ext.success
        : (log.isPreLogged ? ext.info : (log.isSkipped ? null : ext.warning));
    final statusDot = swatch?.base ?? ext.textTertiary;
    final statusBg = swatch?.container ?? ext.textTertiary.withOpacity(0.12);
    final statusFg = swatch?.onContainer ?? ext.textTertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusDot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormats.weekdayDayMonthShort.format(log.scheduledTime),
                    style: tt.labelLarge?.copyWith(color: ext.textPrimary),
                  ),
                  Text(
                    DateFormats.time.format(log.scheduledTime),
                    style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: AppRadius.brMd,
              ),
              child: Text(
                status,
                style: tt.labelMedium?.copyWith(
                    color: statusFg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Log a dose now. The primary path for PRN/as-needed medicines, which have
  /// no scheduled reminder to tap "taken" on — without this they could be added
  /// but never recorded as taken.
  Future<void> _logDose() async {
    _hapticService.medium();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NunitoTakeMedicationSheet(
        medicine: _medicine,
        scheduledTime: DateTime.now(),
      ),
    );
    // The write already bumped `revision`, which refreshed this screen — no
    // second full-loader reload. Undo's writes bump it again, so the confirm
    // needs no `afterUndo` callback either.
    if (!mounted) return;
    DoseUndo.confirmSheetResult(context, result, _medicine.name);
  }

  Widget _buildActionsSection() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        children: [
          if (_medicine.schedule.isPRN ||
              _medicine.schedule.frequencyType == FrequencyType.asNeeded) ...[
            AppButton(
              label: 'Log a dose',
              accent: ext.medicine,
              size: AppButtonSize.lg,
              fullWidth: true,
              leadingIcon: Symbols.check_circle_rounded,
              onPressed: _logDose,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppCard(
            onTap: _toggleArchive,
            child: Row(
              children: [
                Icon(
                  _medicine.isArchived ? Symbols.unarchive_rounded : Symbols.archive_rounded,
                  color: ext.mark(ext.warning),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _medicine.isArchived ? 'Restore medicine' : 'Archive medicine',
                    style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600, color: ext.textPrimary),
                  ),
                ),
                Icon(Symbols.chevron_right_rounded, color: ext.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            onTap: _deleteMedicine,
            child: Row(
              children: [
                Icon(Symbols.delete_rounded, color: ext.mark(ext.error)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Delete medicine',
                    style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600, color: ext.mark(ext.error)),
                  ),
                ),
                Icon(Symbols.chevron_right_rounded, color: ext.textTertiary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom-sheet body for choosing a refill amount. Returns the chosen top-up
/// count via [Navigator.pop] so the caller can apply it through
/// [MedicineCleanStorageService.refillStock].
class _RefillSheet extends StatefulWidget {
  final EnhancedMedicine medicine;

  const _RefillSheet({required this.medicine});

  @override
  State<_RefillSheet> createState() => _RefillSheetState();
}

class _RefillSheetState extends State<_RefillSheet> {
  int _amount = 30;
  static const List<int> _presets = [10, 30, 60, 90];

  @override
  Widget build(BuildContext context) {
    final ext = AppColorsExt.of(context);
    final med = ext.medicine;
    final tt = Theme.of(context).textTheme;
    final newTotal = (widget.medicine.currentStock ?? 0) + _amount;

    // Not AppStepper: that control is a full-width row of two 44pt circles
    // around an Expanded value, and this is a centred row of two 48pt bordered
    // squares around a fixed-width one — swapping it would redraw the sheet.
    // So it takes the same Semantics wrapper the add-flow's stepper carries:
    // an icon-only GestureDetector announces as nothing without one.
    Widget stepButton(
        IconData icon, bool enabled, VoidCallback onTap, String semanticLabel) {
      return Semantics(
        button: true,
        enabled: enabled,
        label: semanticLabel,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: enabled ? med.container : ext.surfaceVariant,
              borderRadius: AppRadius.brSm,
              border: Border.all(color: enabled ? med.base : ext.outline),
            ),
            child: Icon(icon,
                color: enabled ? med.onContainer : ext.textTertiary),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How many units are you adding?',
          style: tt.bodyMedium?.copyWith(color: ext.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            stepButton(
                Symbols.remove_rounded,
                _amount > 1,
                () => setState(() => _amount = (_amount - 1).clamp(1, 9999)),
                'Decrease refill amount'),
            Container(
              constraints: const BoxConstraints(minWidth: 96),
              alignment: Alignment.center,
              child: Text(
                '$_amount',
                style: tt.displaySmall?.copyWith(
                    color: ext.textPrimary, fontWeight: FontWeight.w800),
              ),
            ),
            stepButton(
                Symbols.add_rounded,
                true,
                () => setState(() => _amount = (_amount + 1).clamp(1, 9999)),
                'Increase refill amount'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: _presets
              .map((p) => AppChip(
                    label: '+$p',
                    selected: _amount == p,
                    accent: med,
                    onTap: () => setState(() => _amount = p),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'New total: $newTotal',
          textAlign: TextAlign.center,
          style: tt.bodySmall?.copyWith(color: ext.textTertiary),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Add to stock',
          variant: AppButtonVariant.primary,
          accent: med,
          fullWidth: true,
          onPressed: () => Navigator.pop(context, _amount),
        ),
      ],
    );
  }
}

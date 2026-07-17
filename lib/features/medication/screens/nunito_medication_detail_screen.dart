import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../widgets/nunito_pill_visual.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_log.dart';
import '../models/drug_interaction.dart';
import '../models/medicine_enums.dart';
import '../services/medicine_storage_service.dart';
import '../services/medication_reminder_service.dart';
import '../services/drug_interaction_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/ai/ai_assistant.dart';
import 'nunito_add_medication_flow.dart';
import 'nunito_take_medication_sheet.dart';

class NunitoMedicationDetailScreen extends StatefulWidget {
  final EnhancedMedicine medicine;

  const NunitoMedicationDetailScreen({
    super.key,
    required this.medicine,
  });

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Reload medicine data
      final medicines = await MedicineCleanStorageService.getAllMedicines();
      final updated = medicines.where((m) => m.id == _medicine.id).firstOrNull;
      if (updated != null) {
        _medicine = updated;
      }

      _computeInteractions(medicines);

      // Load recent logs
      _recentLogs = await MedicineCleanStorageService.getLogsForMedicine(_medicine.id);
      _recentLogs.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
      if (_recentLogs.length > 10) {
        _recentLogs = _recentLogs.sublist(0, 10);
      }

      // Calculate stats
      final allLogs = await MedicineCleanStorageService.getLogsForMedicine(_medicine.id);
      final taken = allLogs.where((l) => l.isTaken).length;
      final total = allLogs.length;
      _stats = {
        'taken': taken,
        'total': total,
        'adherence': total > 0 ? (taken / total * 100).toInt() : 0,
      };

      _controller.forward();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
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

    final result = await AiAssistant().explainInteractions(descriptions);

    if (!mounted) return;
    setState(() {
      _interactionExplanation = result;
      _interactionExplainFailed = result == null;
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

  /// Open the shared Ask-AI sheet scoped to this medicine. Always available
  /// (free on-device engine); the sheet also self-guards.
  void _askAi() {
    _hapticService.light();
    final name = _medicine.name;
    final dose = _medicine.displayDosage;
    AiAskSheet.show(
      context,
      title: 'Ask about $name',
      accent: AppColorsExt.of(context).medicine,
      hint: 'e.g. Should I take this with food?',
      disclaimer:
          'AI info — not medical advice. Consult your doctor/pharmacist.',
      onAsk: (q) => AiAssistant().medicineAnswer(
        name: name,
        dose: dose,
        question: q,
        instructions: _medicine.instructions,
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
    final updated = _medicine.copyWith(isArchived: !_medicine.isArchived);
    await MedicineCleanStorageService.saveMedicine(updated);

    if (_medicine.isArchived) {
      await _reminderService.scheduleReminders(updated);
    } else {
      await _reminderService.cancelReminders(_medicine);
    }

    setState(() => _medicine = updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_medicine.isArchived ? 'Medicine archived' : 'Medicine restored'),
        ),
      );
    }
  }

  Future<void> _deleteMedicine() async {
    final confirm = await AppBottomSheet.confirm(
      context,
      title: 'Delete ${_medicine.name}?',
      message: 'This will permanently delete this medication and all its history.',
      confirmLabel: 'Delete',
      danger: true,
      icon: Icons.delete_rounded,
    );

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
                    SliverToBoxAdapter(child: _buildScheduleSection()),
                    SliverToBoxAdapter(child: _buildDetailsSection()),
                    SliverToBoxAdapter(child: _buildStockSection()),
                    SliverToBoxAdapter(child: _buildInteractionsSection()),
                    SliverToBoxAdapter(child: _buildSafetySection()),
                    SliverToBoxAdapter(child: _buildHistorySection()),
                    SliverToBoxAdapter(child: _buildActionsSection()),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
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

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: headerBg,
      foregroundColor: onHeader,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded, color: onHeader),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.auto_awesome_rounded, color: onHeader),
          tooltip: 'Ask AI about this medicine',
          onPressed: _askAi,
        ),
        IconButton(
          icon: Icon(Icons.edit_rounded, color: onHeader),
          onPressed: _editMedicine,
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: onHeader),
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
                    _medicine.isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
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
                  Icon(Icons.delete_rounded, color: ext.mark(ext.error)),
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
                              style: tt.headlineMedium?.copyWith(
                                  color: onHeader, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _medicine.displayDosage,
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: StatTileRow(
        tiles: [
          StatTile(
            label: 'Adherence',
            value: '${_stats['adherence'] ?? 0}%',
            icon: Icons.trending_up_rounded,
            accent: ext.success,
          ),
          StatTile(
            label: 'Taken',
            value: '${_stats['taken'] ?? 0}',
            icon: Icons.check_circle_rounded,
            accent: ext.info,
          ),
          StatTile(
            label: 'Total',
            value: '${_stats['total'] ?? 0}',
            icon: Icons.history_rounded,
            accent: ext.medicine,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    final schedule = _medicine.schedule;
    final nextTime = _reminderService.getNextReminderTime(_medicine);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter, 0, AppSpacing.gutter, 0),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule_rounded,
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
                DateFormat('EEE, MMM d at h:mm a').format(nextTime),
                highlight: true,
              ),
            ],
            if (_medicine.reminderEnabled) ...[
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
                    Icon(Icons.notifications_active_rounded,
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
                Icon(Icons.info_outline_rounded,
                    color: ext.mark(ext.medicine), size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Details', style: tt.titleLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildDetailRow('Form', _medicine.dosageForm.displayName),
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
                Icon(Icons.inventory_2_rounded,
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
                    Icon(Icons.warning_amber_rounded,
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
              leadingIcon: Icons.add_rounded,
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
      icon: Icons.inventory_2_rounded,
      accent: AppColorsExt.of(context).medicine,
      builder: (_) => _RefillSheet(medicine: _medicine),
    );
    if (amount != null && amount > 0) {
      await MedicineCleanStorageService.refillStock(_medicine.id, amount);
      _hapticService.success();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $amount to ${_medicine.name}')),
        );
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
                Icon(Icons.warning_amber_rounded,
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
                leadingIcon: Icons.auto_awesome_rounded,
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
                          Icon(Icons.auto_awesome_rounded,
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
                        'AI info — not medical advice. Consult your doctor/pharmacist.',
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
                    w, Icons.restaurant_rounded, ext.warning),
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
    if (warnings.isEmpty && sideEffects.isEmpty) {
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
                Icon(Icons.health_and_safety_rounded,
                    color: ext.mark(ext.warning), size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text('Warnings & Side Effects', style: tt.titleLarge),
              ],
            ),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Warnings',
                  style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
              const SizedBox(height: AppSpacing.sm),
              ...warnings.map((w) =>
                  _buildBulletRow(w, Icons.error_outline_rounded, ext.error)),
            ],
            if (sideEffects.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Possible side effects',
                  style: tt.bodySmall?.copyWith(color: ext.textTertiary)),
              const SizedBox(height: AppSpacing.sm),
              ...sideEffects.map((s) =>
                  _buildBulletRow(s, Icons.circle, ext.warning, small: true)),
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
              Icon(Icons.history_rounded,
                  color: ext.mark(ext.medicine), size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('Recent History', style: tt.titleLarge),
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
    final status = log.isTaken ? 'Taken' : (log.isSkipped ? 'Skipped' : 'Missed');
    final swatch = log.isTaken
        ? ext.success
        : (log.isSkipped ? ext.warning : ext.error);

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
                color: swatch.base,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEE, MMM d').format(log.scheduledTime),
                    style: tt.labelLarge?.copyWith(color: ext.textPrimary),
                  ),
                  Text(
                    DateFormat('h:mm a').format(log.scheduledTime),
                    style: tt.bodySmall?.copyWith(color: ext.textTertiary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: swatch.container,
                borderRadius: AppRadius.brMd,
              ),
              child: Text(
                status,
                style: tt.labelMedium?.copyWith(
                    color: swatch.onContainer, fontWeight: FontWeight.w600),
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
    if (result != null) await _loadData();
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
              leadingIcon: Icons.check_circle_rounded,
              onPressed: _logDose,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppCard(
            onTap: _toggleArchive,
            child: Row(
              children: [
                Icon(
                  _medicine.isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
                  color: ext.mark(ext.warning),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _medicine.isArchived ? 'Restore Medication' : 'Archive Medication',
                    style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600, color: ext.textPrimary),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: ext.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            onTap: _deleteMedicine,
            child: Row(
              children: [
                Icon(Icons.delete_rounded, color: ext.mark(ext.error)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Delete Medication',
                    style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600, color: ext.mark(ext.error)),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: ext.textTertiary),
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

    Widget stepButton(IconData icon, bool enabled, VoidCallback onTap) {
      return GestureDetector(
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
            stepButton(Icons.remove_rounded, _amount > 1,
                () => setState(() => _amount = (_amount - 1).clamp(1, 9999))),
            Container(
              constraints: const BoxConstraints(minWidth: 96),
              alignment: Alignment.center,
              child: Text(
                '$_amount',
                style: tt.displaySmall?.copyWith(
                    color: ext.textPrimary, fontWeight: FontWeight.w800),
              ),
            ),
            stepButton(Icons.add_rounded, true,
                () => setState(() => _amount = (_amount + 1).clamp(1, 9999))),
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

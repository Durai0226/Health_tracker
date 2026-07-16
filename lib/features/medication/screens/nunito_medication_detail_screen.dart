import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app/app_widgets.dart';
import '../widgets/nunito_pill_visual.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_log.dart';
import '../services/medicine_storage_service.dart';
import '../services/medication_reminder_service.dart';
import '../../../core/services/haptic_service.dart';
import 'nunito_add_medication_flow.dart';

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
            if (_medicine.currentStock != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildDetailRow(
                'Stock',
                '${_medicine.currentStock} remaining',
                highlight: (_medicine.currentStock ?? 0) <= (_medicine.lowStockThreshold ?? 5),
              ),
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

  Widget _buildActionsSection() {
    final ext = AppColorsExt.of(context);
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        children: [
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

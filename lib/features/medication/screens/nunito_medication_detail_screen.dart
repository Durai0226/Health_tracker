import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/nunito_theme.dart';
import '../widgets/nunito_glass_card.dart';
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
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
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
    setState(() => _isLoading = false);
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NunitoTheme.radiusMedium),
        ),
        title: Text('Delete ${_medicine.name}?', style: NunitoTheme.heading3),
        content: Text(
          'This will permanently delete this medication and all its history.',
          style: NunitoTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: NunitoTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? NunitoTheme.backgroundDark : NunitoTheme.backgroundLight,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildHeader(isDark),
                  SliverToBoxAdapter(child: _buildStatsSection(isDark)),
                  SliverToBoxAdapter(child: _buildScheduleSection(isDark)),
                  SliverToBoxAdapter(child: _buildDetailsSection(isDark)),
                  SliverToBoxAdapter(child: _buildHistorySection(isDark)),
                  SliverToBoxAdapter(child: _buildActionsSection(isDark)),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: NunitoTheme.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_rounded, color: Colors.white),
          onPressed: _editMedicine,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onSelected: (value) {
            if (value == 'archive') _toggleArchive();
            if (value == 'delete') _deleteMedicine();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'archive',
              child: Row(
                children: [
                  Icon(_medicine.isArchived ? Icons.unarchive_rounded : Icons.archive_rounded),
                  const SizedBox(width: 8),
                  Text(_medicine.isArchived ? 'Restore' : 'Archive'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_rounded, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: NunitoTheme.primaryGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(NunitoTheme.spacingL),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: NunitoPillVisual(
                          color: _medicine.color,
                          shape: _medicine.shape,
                          size: 56,
                          showShadow: false,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _medicine.name,
                              style: NunitoTheme.heading1.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _medicine.displayDosage,
                              style: NunitoTheme.bodyLarge.copyWith(color: Colors.white70),
                            ),
                            if (_medicine.isArchived)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Archived',
                                  style: NunitoTheme.caption.copyWith(color: Colors.white),
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

  Widget _buildStatsSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Adherence',
              '${_stats['adherence'] ?? 0}%',
              Icons.trending_up_rounded,
              NunitoTheme.success,
              isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Taken',
              '${_stats['taken'] ?? 0}',
              Icons.check_circle_rounded,
              NunitoTheme.accentBlue,
              isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Total',
              '${_stats['total'] ?? 0}',
              Icons.history_rounded,
              NunitoTheme.secondary,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return NunitoCard(
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: NunitoTheme.heading2.copyWith(
              color: isDark ? Colors.white : NunitoTheme.textPrimary,
            ),
          ),
          Text(label, style: NunitoTheme.caption),
        ],
      ),
    );
  }

  Widget _buildScheduleSection(bool isDark) {
    final schedule = _medicine.schedule;
    final nextTime = _reminderService.getNextReminderTime(_medicine);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NunitoTheme.spacingM),
      child: NunitoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule_rounded, color: NunitoTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('Schedule', style: NunitoTheme.heading3.copyWith(
                  color: isDark ? Colors.white : NunitoTheme.textPrimary,
                )),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Frequency', schedule.frequencyType.displayName, isDark),
            if (schedule.times.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                'Times',
                schedule.times.map((t) => t.formattedTime).join(', '),
                isDark,
              ),
            ],
            if (nextTime != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                'Next Dose',
                DateFormat('EEE, MMM d at h:mm a').format(nextTime),
                isDark,
                highlight: true,
              ),
            ],
            if (_medicine.reminderEnabled) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: NunitoTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_active_rounded, 
                         color: NunitoTheme.success, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Reminders enabled',
                      style: NunitoTheme.caption.copyWith(color: NunitoTheme.success),
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

  Widget _buildDetailsSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      child: NunitoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded, color: NunitoTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text('Details', style: NunitoTheme.heading3.copyWith(
                  color: isDark ? Colors.white : NunitoTheme.textPrimary,
                )),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Form', _medicine.dosageForm.displayName, isDark),
            if (_medicine.strength != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow('Strength', _medicine.strength!, isDark),
            ],
            if (_medicine.instructions != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow('Instructions', _medicine.instructions!, isDark),
            ],
            if (_medicine.purpose != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow('Purpose', _medicine.purpose!, isDark),
            ],
            if (_medicine.currentStock != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                'Stock',
                '${_medicine.currentStock} remaining',
                isDark,
                highlight: (_medicine.currentStock ?? 0) <= (_medicine.lowStockThreshold ?? 5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: NunitoTheme.bodySmall.copyWith(color: NunitoTheme.textTertiary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: NunitoTheme.bodyMedium.copyWith(
              color: highlight
                  ? NunitoTheme.warning
                  : (isDark ? Colors.white : NunitoTheme.textPrimary),
              fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection(bool isDark) {
    if (_recentLogs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NunitoTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, color: NunitoTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('Recent History', style: NunitoTheme.heading3.copyWith(
                color: isDark ? Colors.white : NunitoTheme.textPrimary,
              )),
            ],
          ),
          const SizedBox(height: 12),
          ...(_recentLogs.take(5).map((log) => _buildLogItem(log, isDark))),
        ],
      ),
    );
  }

  Widget _buildLogItem(MedicineLog log, bool isDark) {
    final status = log.isTaken ? 'Taken' : (log.isSkipped ? 'Skipped' : 'Missed');
    final color = log.isTaken ? NunitoTheme.success : (log.isSkipped ? NunitoTheme.warning : NunitoTheme.error);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NunitoCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEE, MMM d').format(log.scheduledTime),
                    style: NunitoTheme.labelMedium.copyWith(
                      color: isDark ? Colors.white : NunitoTheme.textPrimary,
                    ),
                  ),
                  Text(
                    DateFormat('h:mm a').format(log.scheduledTime),
                    style: NunitoTheme.caption,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: NunitoTheme.caption.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(NunitoTheme.spacingM),
      child: Column(
        children: [
          NunitoAnimatedCard(
            onTap: _toggleArchive,
            child: Row(
              children: [
                Icon(
                  _medicine.isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
                  color: NunitoTheme.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _medicine.isArchived ? 'Restore Medication' : 'Archive Medication',
                    style: NunitoTheme.labelLarge.copyWith(
                      color: isDark ? Colors.white : NunitoTheme.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: NunitoTheme.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: 8),
          NunitoAnimatedCard(
            onTap: _deleteMedicine,
            child: Row(
              children: [
                const Icon(Icons.delete_rounded, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Delete Medication',
                    style: NunitoTheme.labelLarge.copyWith(color: Colors.red),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: NunitoTheme.textTertiary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

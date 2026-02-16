import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../models/medicine_log.dart';
import '../models/medicine_enums.dart';
import '../models/enhanced_medicine.dart';
import '../services/medicine_storage_service.dart';

/// Premium Feature: Medicine History with Calendar View
/// Similar to Medisafe's history and Apple Health's medication logs
class MedicineHistoryScreen extends StatefulWidget {
  final String? medicineId; // Optional - filter by specific medicine
  
  const MedicineHistoryScreen({super.key, this.medicineId});

  @override
  State<MedicineHistoryScreen> createState() => _MedicineHistoryScreenState();
}

class _MedicineHistoryScreenState extends State<MedicineHistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  List<MedicineLog> _logs = [];
  Map<DateTime, List<MedicineLog>> _logsByDate = {};
  bool _isLoading = true;
  EnhancedMedicine? _selectedMedicine;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      if (widget.medicineId != null) {
        _selectedMedicine = MedicineStorageService.getMedicine(widget.medicineId!);
        _logs = MedicineStorageService.getLogsForMedicine(widget.medicineId!);
      } else {
        _logs = MedicineStorageService.getAllLogs();
      }

      // Group logs by date
      _logsByDate = {};
      for (final log in _logs) {
        final dateKey = DateTime(
          log.scheduledTime.year,
          log.scheduledTime.month,
          log.scheduledTime.day,
        );
        _logsByDate[dateKey] ??= [];
        _logsByDate[dateKey]!.add(log);
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  List<MedicineLog> get _logsForSelectedDate {
    final dateKey = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return _logsByDate[dateKey] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _selectedMedicine != null ? '${_selectedMedicine!.name} History' : 'Medicine History',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: AppColors.primary),
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCalendarHeader(),
                _buildCalendarGrid(),
                const SizedBox(height: 16),
                _buildDateStats(),
                const SizedBox(height: 16),
                Expanded(child: _buildLogsList()),
              ],
            ),
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () {
              setState(() {
                _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
              });
            },
          ),
          Text(
            DateFormat('MMMM yyyy').format(_focusedMonth),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () {
              setState(() {
                _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startWeekday = firstDay.weekday;
    
    final days = <Widget>[];
    
    // Day labels
    for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      days.add(
        Center(
          child: Text(
            day,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // Empty cells before first day
    for (int i = 1; i < startWeekday; i++) {
      days.add(const SizedBox());
    }

    // Day cells
    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final dateKey = DateTime(date.year, date.month, date.day);
      final hasLogs = _logsByDate.containsKey(dateKey);
      final isSelected = _selectedDate.year == date.year &&
          _selectedDate.month == date.month &&
          _selectedDate.day == date.day;
      final isToday = DateTime.now().year == date.year &&
          DateTime.now().month == date.month &&
          DateTime.now().day == date.day;

      Color? dotColor;
      if (hasLogs) {
        final logs = _logsByDate[dateKey]!;
        final allTaken = logs.every((l) => l.isTaken);
        final anyMissed = logs.any((l) => l.isMissed);
        if (allTaken) {
          dotColor = AppColors.success;
        } else if (anyMissed) {
          dotColor = AppColors.error;
        } else {
          dotColor = AppColors.warning;
        }
      }

      days.add(
        GestureDetector(
          onTap: () => setState(() => _selectedDate = date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : (isToday ? AppColors.primary.withOpacity(0.1) : null),
              borderRadius: BorderRadius.circular(8),
              border: isToday && !isSelected 
                  ? Border.all(color: AppColors.primary, width: 1.5) 
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                if (dotColor != null)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.2,
        children: days,
      ),
    );
  }

  Widget _buildDateStats() {
    final logs = _logsForSelectedDate;
    final taken = logs.where((l) => l.isTaken).length;
    final skipped = logs.where((l) => l.isSkipped).length;
    final missed = logs.where((l) => l.isMissed).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMMM d').format(_selectedDate),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatChip('Taken', taken, AppColors.success),
              const SizedBox(width: 8),
              _buildStatChip('Skipped', skipped, AppColors.warning),
              const SizedBox(width: 8),
              _buildStatChip('Missed', missed, AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsList() {
    final logs = _logsForSelectedDate;

    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note_rounded,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No medicine logs for this day',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return _buildLogCard(log);
      },
    );
  }

  Widget _buildLogCard(MedicineLog log) {
    final medicine = MedicineStorageService.getMedicine(log.medicineId);
    final statusColor = _getStatusColor(log.status);
    final statusIcon = _getStatusIcon(log.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(statusIcon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine?.name ?? 'Unknown Medicine',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Scheduled: ${DateFormat('h:mm a').format(log.scheduledTime)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  log.status.displayName,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (log.actionTime != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  log.wasTakenOnTime ? Icons.check_circle_rounded : Icons.info_rounded,
                  size: 14,
                  color: log.wasTakenOnTime ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  log.isTaken
                      ? 'Taken at ${DateFormat('h:mm a').format(log.actionTime!)}'
                      : 'Logged at ${DateFormat('h:mm a').format(log.actionTime!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (log.timeDifference != null && log.isTaken) ...[
                  const SizedBox(width: 8),
                  Text(
                    _formatTimeDifference(log.timeDifference!),
                    style: TextStyle(
                      fontSize: 12,
                      color: log.wasTakenOnTime ? AppColors.success : AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (log.skipReason != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Text(
                    'Reason: ${log.skipReason!.displayName}',
                    style: const TextStyle(fontSize: 12, color: AppColors.warning),
                  ),
                ],
              ),
            ),
          ],
          if (log.sideEffects != null && log.sideEffects!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Side effects: ${log.sideEffects}',
                      style: const TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (log.notes != null && log.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              log.notes!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (log.moodRating != null || log.effectivenessRating != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (log.moodRating != null) ...[
                  _buildRatingChip('Mood', log.moodRating!, Icons.mood),
                  const SizedBox(width: 8),
                ],
                if (log.effectivenessRating != null)
                  _buildRatingChip('Effectiveness', log.effectivenessRating!, Icons.medical_services),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingChip(String label, int rating, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          ...List.generate(5, (i) => Icon(
            i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 12,
            color: i < rating ? Colors.amber : AppColors.textSecondary,
          )),
        ],
      ),
    );
  }

  Color _getStatusColor(MedicineStatus status) {
    switch (status) {
      case MedicineStatus.taken:
        return AppColors.success;
      case MedicineStatus.skipped:
        return AppColors.warning;
      case MedicineStatus.missed:
        return AppColors.error;
      case MedicineStatus.snoozed:
        return AppColors.info;
      case MedicineStatus.pending:
        return AppColors.textSecondary;
    }
  }

  IconData _getStatusIcon(MedicineStatus status) {
    switch (status) {
      case MedicineStatus.taken:
        return Icons.check_circle_rounded;
      case MedicineStatus.skipped:
        return Icons.skip_next_rounded;
      case MedicineStatus.missed:
        return Icons.cancel_rounded;
      case MedicineStatus.snoozed:
        return Icons.snooze_rounded;
      case MedicineStatus.pending:
        return Icons.schedule_rounded;
    }
  }

  String _formatTimeDifference(Duration diff) {
    final minutes = diff.inMinutes.abs();
    if (minutes == 0) return '(on time)';
    final direction = diff.isNegative ? 'early' : 'late';
    if (minutes < 60) return '($minutes min $direction)';
    return '(${minutes ~/ 60}h ${minutes % 60}m $direction)';
  }

  void _showFilterOptions() {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildFilterOption('All Logs', Icons.list_alt, () {
              Navigator.pop(context);
            }),
            _buildFilterOption('Taken Only', Icons.check_circle, () {
              Navigator.pop(context);
            }),
            _buildFilterOption('Missed Only', Icons.cancel, () {
              Navigator.pop(context);
            }),
            _buildFilterOption('With Side Effects', Icons.warning_amber, () {
              Navigator.pop(context);
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

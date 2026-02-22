import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/enhanced_medicine.dart';
import '../models/medicine_enums.dart';
import '../models/medicine_log.dart';
import '../services/medicine_storage_service.dart';
import '../services/drug_interaction_service.dart';
import '../services/intake_tracking_service.dart';
import 'add_medicine_wizard.dart';
import 'medicine_history_screen.dart';

/// Medicine Detail Screen with comprehensive info like Medisafe
class MedicineDetailScreen extends StatefulWidget {
  final String medicineId;

  const MedicineDetailScreen({super.key, required this.medicineId});

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  EnhancedMedicine? _medicine;
  List<MedicineLog> _recentLogs = [];
  bool _isLoading = true;
  Map<String, dynamic>? _streakStats;
  bool _hasTakenToday = false;
  bool _hasSkippedToday = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _medicine = MedicineStorageService.getMedicine(widget.medicineId);
      if (_medicine != null) {
        _recentLogs = MedicineStorageService.getLogsForMedicine(widget.medicineId).take(10).toList();
        _streakStats = IntakeTrackingService.getStreakStats(widget.medicineId);
        _checkTodayStatus();
      }
    } catch (e) {
      debugPrint('Error loading medicine: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _checkTodayStatus() {
    final today = DateTime.now();
    final todayLogs = MedicineStorageService.getLogsForDate(today)
        .where((log) => log.medicineId == widget.medicineId);
    
    _hasTakenToday = todayLogs.any((log) => log.isTaken);
    _hasSkippedToday = todayLogs.any((log) => log.isSkipped);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_medicine == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Medicine Not Found')),
        body: const Center(child: Text('This medicine could not be found.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildQuickActions(),
                if (_streakStats != null) _buildStreakCard(),
                if (_medicine!.healthCategories != null && _medicine!.healthCategories!.isNotEmpty)
                  _buildHealthCategoriesCard(),
                _buildInfoCard(),
                _buildScheduleCard(),
                _buildStockCard(),
                if (_medicine!.drugInfo != null || _medicine!.warnings != null)
                  _buildDrugInfoCard(),
                _buildRecentLogsCard(),
                _buildDangerZone(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_rounded, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddMedicineWizard(editMedicine: _medicine),
            ),
          ).then((_) => _loadData()),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onPressed: _showMoreOptions,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _medicine!.dosageForm.icon,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _medicine!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_medicine!.strength != null)
                              Text(
                                _medicine!.strength!,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 16,
                                ),
                              ),
                            Text(
                              _medicine!.dosageForm.displayName,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
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

  Widget _buildQuickActions() {
    final canTake = !_hasTakenToday && !_hasSkippedToday;
    final canSkip = !_hasTakenToday && !_hasSkippedToday;

    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (_hasTakenToday)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Already taken today',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_hasSkippedToday)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.skip_next_rounded, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Already skipped today',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.check_circle_rounded,
                  label: 'Take Now',
                  color: AppColors.success,
                  onTap: canTake ? () => _showTakeMedicineDialog() : null,
                  isEnabled: canTake,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.skip_next_rounded,
                  label: 'Skip',
                  color: AppColors.warning,
                  onTap: canSkip ? () => _showSkipDialog() : null,
                  isEnabled: canSkip,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.history_rounded,
                  label: 'History',
                  color: AppColors.info,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MedicineHistoryScreen(medicineId: _medicine!.id),
                    ),
                  ),
                  isEnabled: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    required bool isEnabled,
  }) {
    final effectiveColor = isEnabled ? color : AppColors.textSecondary;
    
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: effectiveColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: effectiveColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: effectiveColor, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: effectiveColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakCard() {
    if (_streakStats == null) return const SizedBox.shrink();

    final currentStreak = _streakStats!['currentStreak'] ?? 0;
    final longestStreak = _streakStats!['longestStreak'] ?? 0;
    final adherenceRate = _streakStats!['adherenceRate'] ?? 100.0;
    final canSkip = _streakStats!['canSkip'] ?? true;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.success.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Intake Streak',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (!canSkip)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStreakStat(
                  'Current Streak',
                  '$currentStreak',
                  'days',
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStreakStat(
                  'Longest Streak',
                  '$longestStreak',
                  'days',
                  AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStreakStat(
                  'Adherence',
                  '${adherenceRate.toStringAsFixed(0)}',
                  '%',
                  AppColors.info,
                ),
              ),
            ],
          ),
          if (_medicine!.requiresContinuousIntake) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_rounded, color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Continuous intake required${_medicine!.minimumConsecutiveDays != null ? ' for ${_medicine!.minimumConsecutiveDays} days' : ''}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStreakStat(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCategoriesCard() {
    if (_medicine!.healthCategories == null || _medicine!.healthCategories!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          const Row(
            children: [
              Icon(Icons.medical_services_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Health Categories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _medicine!.healthCategories!.map((category) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category.icon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      category.displayName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (_medicine!.customHealthCategory != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📋', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    _medicine!.customHealthCategory!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          const Text(
            'Medicine Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Dosage', _medicine!.displayDosage),
          _buildInfoRow('Frequency', _medicine!.schedule.frequencyDescription),
          _buildInfoRow('Meal Timing', _medicine!.schedule.mealTiming.displayName),
          if (_medicine!.purpose != null)
            _buildInfoRow('Purpose', _medicine!.purpose!),
          if (_medicine!.instructions != null)
            _buildInfoRow('Instructions', _medicine!.instructions!),
          if (_medicine!.notes != null)
            _buildInfoRow('Notes', _medicine!.notes!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    final schedule = _medicine!.schedule;
    final times = schedule.times;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          const Row(
            children: [
              Icon(Icons.schedule_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Schedule',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_medicine!.isPRN)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_rounded, color: AppColors.info),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Take as needed (PRN)'),
                  ),
                ],
              ),
            )
          else
            ...times.map((time) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          time.formattedTime,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (time.label != null)
                          Text(
                            time.label!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${time.dosageAmount} ${_medicine!.dosageForm.unit}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Start Date', style: TextStyle(color: AppColors.textSecondary)),
              Text(
                schedule.startDate != null
                    ? DateFormat('MMM d, yyyy').format(schedule.startDate!)
                    : 'Not set',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Duration', style: TextStyle(color: AppColors.textSecondary)),
              Text(
                schedule.isOngoing ? 'Ongoing' : '${schedule.durationDays} days',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard() {
    if (_medicine!.currentStock == null) return const SizedBox.shrink();

    final daysRemaining = _medicine!.estimatedDaysRemaining;
    final isLow = _medicine!.isLowStock;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isLow ? AppColors.warning.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isLow ? Border.all(color: AppColors.warning.withOpacity(0.3)) : null,
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
          Row(
            children: [
              Icon(
                Icons.inventory_2_rounded,
                color: isLow ? AppColors.warning : AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Stock',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (isLow)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Low Stock',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_medicine!.currentStock}',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_medicine!.dosageForm.unit} remaining',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (daysRemaining >= 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '~$daysRemaining',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isLow ? AppColors.warning : AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'days left',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: CommonButton(
              text: 'Add Refill',
              variant: ButtonVariant.primary,
              onPressed: _showRefillDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrugInfoCard() {
    final drugInfo = DrugInteractionService().getDrugInfo(_medicine!.name);

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          const Row(
            children: [
              Icon(Icons.medical_information_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Drug Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (drugInfo != null) ...[
            _buildInfoRow('Drug Class', drugInfo.drugClass),
            if (drugInfo.description != null)
              _buildInfoRow('Description', drugInfo.description!),
            if (drugInfo.uses != null && drugInfo.uses!.isNotEmpty)
              _buildInfoRow('Uses', drugInfo.uses!.join(', ')),
            if (drugInfo.storage != null)
              _buildInfoRow('Storage', drugInfo.storage!),
          ],
          if (_medicine!.warnings != null && _medicine!.warnings!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                      SizedBox(width: 8),
                      Text('Warnings', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._medicine!.warnings!.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $w', style: const TextStyle(fontSize: 13)),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentLogsCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Row(
            children: [
              const Icon(Icons.history_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Recent Activity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              CommonButton(
                text: 'View All',
                variant: ButtonVariant.secondary,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MedicineHistoryScreen(medicineId: _medicine!.id),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recentLogs.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No activity yet',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ..._recentLogs.take(5).map((log) => _buildLogItem(log)),
        ],
      ),
    );
  }

  Widget _buildLogItem(MedicineLog log) {
    final statusColor = _getStatusColor(log.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            log.isTaken ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.status.displayName,
                  style: TextStyle(fontWeight: FontWeight.w500, color: statusColor),
                ),
                Text(
                  DateFormat('MMM d, h:mm a').format(log.scheduledTime),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text(
                'Danger Zone',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CommonButton(
                  text: 'Archive',
                  variant: ButtonVariant.secondary,
                  onPressed: _archiveMedicine,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CommonButton(
                  text: 'Delete',
                  variant: ButtonVariant.danger,
                  onPressed: _deleteMedicine,
                ),
              ),
            ],
          ),
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
      default:
        return AppColors.textSecondary;
    }
  }

  void _showTakeMedicineDialog() {
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Take ${_medicine!.name}?',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${_medicine!.displayDosage} - ${_medicine!.dosageForm.displayName}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: CommonButton(
                text: 'Confirm',
                variant: ButtonVariant.primary,
                onPressed: () async {
                  final result = await IntakeTrackingService.recordMedicineTaken(
                    medicineId: _medicine!.id,
                    takenDate: DateTime.now(),
                    dosageTaken: _medicine!.dosageAmount,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['message'] ?? 'Medicine marked as taken!'),
                        backgroundColor: AppColors.success,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            CommonButton(
              text: 'Cancel',
              variant: ButtonVariant.secondary,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showSkipDialog() async {
    final canSkip = await IntakeTrackingService.canSkipMedicine(_medicine!.id);
    
    if (!canSkip) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Skip'),
          content: Text(
            _medicine!.requiresContinuousIntake
                ? 'This medicine requires continuous intake. You have taken it ${_streakStats?['consecutiveTakes'] ?? 0} times consecutively. You must continue taking it as prescribed.'
                : 'You cannot skip this dose at this time.',
          ),
          actions: [
            CommonButton(
              text: 'OK',
              variant: ButtonVariant.primary,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    SkipReason? selectedReason;
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                'Skip this dose?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please select a reason',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              if (_streakStats != null && _streakStats!['currentStreak'] > 0)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Skipping will reset your ${_streakStats!['currentStreak']}-day streak',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              ...SkipReason.values.map((reason) => RadioListTile<SkipReason>(
                value: reason,
                groupValue: selectedReason,
                onChanged: (v) => setModalState(() => selectedReason = v),
                title: Text(reason.displayName),
                contentPadding: EdgeInsets.zero,
              )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: CommonButton(
                  text: 'Skip Dose',
                  variant: ButtonVariant.primary,
                  backgroundColor: AppColors.warning,
                  onPressed: selectedReason == null
                      ? null
                      : () async {
                          final result = await IntakeTrackingService.recordMedicineSkipped(
                            medicineId: _medicine!.id,
                            skipDate: DateTime.now(),
                            reason: selectedReason!,
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            _loadData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result['message'] ?? 'Dose skipped'),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRefillDialog() {
    int amount = 30;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Refill',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 32),
                    onPressed: () {
                      if (amount > 1) setModalState(() => amount -= 10);
                    },
                  ),
                  const SizedBox(width: 24),
                  Text(
                    '$amount',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 32),
                    onPressed: () => setModalState(() => amount += 10),
                  ),
                ],
              ),
              Text(
                _medicine!.dosageForm.unit,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: CommonButton(
                  text: 'Add Refill',
                  variant: ButtonVariant.primary,
                  onPressed: () async {
                    await MedicineStorageService.refillStock(_medicine!.id, amount);
                    if (mounted) {
                      Navigator.pop(context);
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added $amount to stock')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreOptions() {
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
            ListTile(
              leading: const Icon(Icons.share_rounded),
              title: const Text('Share'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('Export Report'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_rounded),
              title: const Text('Notification Settings'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _archiveMedicine() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Medicine?'),
        content: const Text('This medicine will be hidden but you can restore it later.'),
        actions: [
          CommonButton(
            text: 'Cancel',
            variant: ButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
          CommonButton(
            text: 'Archive',
            variant: ButtonVariant.secondary,
            onPressed: () async {
              await MedicineStorageService.archiveMedicine(_medicine!.id);
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Medicine archived')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _deleteMedicine() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medicine?'),
        content: const Text('This action cannot be undone. All history will be lost.'),
        actions: [
          CommonButton(
            text: 'Cancel',
            variant: ButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
          CommonButton(
            text: 'Delete',
            variant: ButtonVariant.danger,
            onPressed: () async {
              await MedicineStorageService.deleteMedicine(_medicine!.id);
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Medicine deleted')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

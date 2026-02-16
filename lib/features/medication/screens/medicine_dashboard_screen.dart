import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/analytics_service.dart';
import '../models/medicine.dart';
import 'add_medicine_flow.dart';
import 'medicine_list_screen.dart';

import '../../../core/services/vitavibe_service.dart';

/// Medicine Dashboard - Medisafe-style medication tracking
/// Features: Today's schedule, adherence tracking, refill reminders, history
class MedicineDashboardScreen extends StatefulWidget {
  const MedicineDashboardScreen({super.key});

  @override
  State<MedicineDashboardScreen> createState() => _MedicineDashboardScreenState();
}

class _MedicineDashboardScreenState extends State<MedicineDashboardScreen> {
  final VitaVibeService _vitaVibeService = VitaVibeService();
  List<Medicine> _medicines = [];
  bool _isLoading = true;
  int _takenToday = 0;
  int _totalToday = 0;
  int _streak = 0;
  double _adherenceRate = 0.0;
  Map<String, bool> _todayStatus = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      
      final medicines = StorageService.getAllMedicines();
      final analytics = AnalyticsService().getMedicineAnalytics(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
      );
      
      // Load today's taken status from preferences
      final prefs = StorageService.getAppPreferences();
      final todayKey = _getTodayKey();
      final todayData = prefs['medicineTakenToday_$todayKey'];
      Map<String, bool> todayStatus = {};
      if (todayData != null && todayData is Map) {
        todayStatus = Map<String, bool>.from(todayData);
      }
      
      if (mounted) {
        setState(() {
          _medicines = medicines;
          _totalToday = medicines.length;
          _takenToday = todayStatus.values.where((v) => v).length;
          _streak = analytics.streak;
          _adherenceRate = analytics.adherenceRate;
          _todayStatus = todayStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading medicine data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _markAsTaken(Medicine medicine) async {
    try {
      final todayKey = _getTodayKey();
      _todayStatus[medicine.id] = true;
      
      await StorageService.setAppPreference('medicineTakenToday_$todayKey', _todayStatus);
      await AnalyticsService().logMedicineTaken(
        medicineId: medicine.id,
        medicineName: medicine.name,
      );
      
      // Trigger haptic feedback
      _vitaVibeService.medicineTaken();
      
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('${medicine.name} marked as taken'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking medicine as taken: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalToday > 0 ? _takenToday / _totalToday : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildAppBar(),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildTodayProgress(progress),
                        const SizedBox(height: 20),
                        _buildStreakCard(),
                        const SizedBox(height: 20),
                        _buildTodaySchedule(),
                        const SizedBox(height: 20),
                        _buildAdherenceCard(),
                        const SizedBox(height: 20),
                        _buildRefillReminders(),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMedicine,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Medicine',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.error,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.list_alt, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MedicineListScreen()),
          ).then((_) => _loadData()),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Medicine Tracker',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.error, AppColors.error.withOpacity(0.7)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                right: 30,
                bottom: 50,
                child: Icon(
                  Icons.medication_rounded,
                  size: 50,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayProgress(double progress) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.error, AppColors.error.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Circular progress
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_takenToday/$_totalToday',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'taken',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s Medicines',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      progress >= 1 ? 'All done! 🎉' : '${_totalToday - _takenToday} remaining',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(progress * 100).toInt()}% complete',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange, Colors.orange.shade700],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_fire_department, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Streak',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '$_streak days',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (_streak >= 7)
            const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
        ],
      ),
    );
  }

  Widget _buildTodaySchedule() {
    if (_medicines.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(Icons.medication_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'No medicines added',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to add your first medicine',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // Sort by time
    final sortedMedicines = List<Medicine>.from(_medicines);
    sortedMedicines.sort((a, b) => a.time.compareTo(b.time));

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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Schedule',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...sortedMedicines.map((medicine) {
            final isTaken = _todayStatus[medicine.id] ?? false;
            final time = TimeOfDay.fromDateTime(medicine.time);
            
            return _buildMedicineItem(medicine, time, isTaken);
          }),
        ],
      ),
    );
  }

  Widget _buildMedicineItem(Medicine medicine, TimeOfDay time, bool isTaken) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isTaken ? AppColors.success.withOpacity(0.1) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTaken ? AppColors.success.withOpacity(0.3) : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isTaken 
                  ? AppColors.success.withOpacity(0.2) 
                  : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getDosageIcon(medicine.dosageType),
              color: isTaken ? AppColors.success : AppColors.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    decoration: isTaken ? TextDecoration.lineThrough : null,
                    color: isTaken ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      time.format(context),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${medicine.dosageAmount} ${medicine.dosageType}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isTaken)
            GestureDetector(
              onTap: () => _markAsTaken(medicine),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Take',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: AppColors.success, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildAdherenceCard() {
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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '30-Day Adherence',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${(_adherenceRate * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _adherenceRate >= 0.8 
                      ? AppColors.success 
                      : (_adherenceRate >= 0.5 ? AppColors.warning : AppColors.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _adherenceRate,
              minHeight: 12,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                _adherenceRate >= 0.8 
                    ? AppColors.success 
                    : (_adherenceRate >= 0.5 ? AppColors.warning : AppColors.error),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _getAdherenceMessage(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefillReminders() {
    final lowStockMedicines = _medicines.where((m) {
      if (m.stockRemaining == null || m.lowStockThreshold == null) return false;
      return m.stockRemaining! <= m.lowStockThreshold!;
    }).toList();

    if (lowStockMedicines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              SizedBox(width: 8),
              Text(
                'Refill Reminders',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...lowStockMedicines.map((medicine) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(_getDosageIcon(medicine.dosageType), 
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    medicine.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '${medicine.stockRemaining} left',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  IconData _getDosageIcon(String dosageType) {
    switch (dosageType.toLowerCase()) {
      case 'tablet':
        return Icons.medication_rounded;
      case 'capsule':
        return Icons.medication_liquid;
      case 'syrup':
        return Icons.local_drink_rounded;
      case 'injection':
        return Icons.vaccines;
      default:
        return Icons.medication;
    }
  }

  String _getAdherenceMessage() {
    if (_adherenceRate >= 0.9) return 'Excellent! Keep up the great work! 🌟';
    if (_adherenceRate >= 0.8) return 'Good job! You\'re doing well.';
    if (_adherenceRate >= 0.6) return 'Room for improvement. Try setting more reminders.';
    return 'Consider reviewing your medication schedule.';
  }

  void _addMedicine() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicineFlow()),
    ).then((_) => _loadData());
  }
}

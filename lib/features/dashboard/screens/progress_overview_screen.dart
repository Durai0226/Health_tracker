import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/focus_mode_service.dart';
import '../../water/screens/water_dashboard_screen.dart';
import '../../fitness/screens/fitness_dashboard_screen.dart';
import '../../reminders/screens/focus_dashboard_screen.dart';
import '../../medication/screens/medicine_dashboard_screen.dart';
import '../../water/services/water_service.dart';
import '../../water/models/beverage_type.dart';

/// Unified Progress Overview - All modules in one view
/// Inspired by Apple Health, Google Fit dashboard designs
class ProgressOverviewScreen extends StatefulWidget {
  const ProgressOverviewScreen({super.key});

  @override
  State<ProgressOverviewScreen> createState() => _ProgressOverviewScreenState();
}

class _ProgressOverviewScreenState extends State<ProgressOverviewScreen> {
  bool _isLoading = true;
  
  // Water stats
  double _waterProgress = 0.0;
  int _waterMl = 0;
  int _waterGoal = 2500;
  
  // Fitness stats
  int _fitnessWorkouts = 0;
  int _fitnessMinutes = 0;
  int _fitnessCalories = 0;
  
  // Focus stats
  int _focusMinutes = 0;
  int _focusSessions = 0;
  
  // Medicine stats
  int _medicineTaken = 0;
  int _medicineTotal = 0;
  double _medicineAdherence = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Load water data
      await WaterService.init();
      final waterIntake = WaterService.getTodayData();
      final waterGoal = WaterService.getDailyGoal();
      
      // Load fitness data
      final fitnessAnalytics = AnalyticsService().getFitnessAnalytics(
        startDate: AnalyticsService.getWeekStart(),
        endDate: DateTime.now(),
      );
      
      // Load focus data
      final focusService = FocusModeService();
      await focusService.init();
      final prefs = StorageService.getAppPreferences();
      final todayKey = _getTodayKey();
      
      // Load medicine data
      final medicines = StorageService.getAllMedicines();
      final medicineAnalytics = AnalyticsService().getMedicineAnalytics(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
      );
      
      // Load today's medicine status
      final medicineTodayData = prefs['medicineTakenToday_$todayKey'];
      int takenToday = 0;
      if (medicineTodayData != null && medicineTodayData is Map) {
        takenToday = Map<String, bool>.from(medicineTodayData)
            .values.where((v) => v).length;
      }
      
      if (mounted) {
        setState(() {
          // Water
          _waterMl = waterIntake.effectiveHydrationMl;
          _waterGoal = waterGoal;
          _waterProgress = _waterGoal > 0 ? (_waterMl / _waterGoal).clamp(0.0, 1.0) : 0.0;
          
          // Fitness
          _fitnessWorkouts = fitnessAnalytics.weeklyProgress;
          _fitnessMinutes = fitnessAnalytics.totalMinutes;
          _fitnessCalories = fitnessAnalytics.totalCalories;
          
          // Focus
          _focusMinutes = prefs['focusTodayMinutes_$todayKey'] ?? 0;
          _focusSessions = prefs['focusTotalSessions'] ?? 0;
          
          // Medicine
          _medicineTaken = takenToday;
          _medicineTotal = medicines.length;
          _medicineAdherence = medicineAnalytics.adherenceRate;
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading progress data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOverallProgress(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Today\'s Progress'),
                        const SizedBox(height: 12),
                        _buildModuleCards(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Quick Actions'),
                        const SizedBox(height: 12),
                        _buildQuickActions(),
                        const SizedBox(height: 24),
                        _buildWeeklySummary(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Progress Overview',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                right: 40,
                bottom: 50,
                child: Icon(
                  Icons.insights_rounded,
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

  Widget _buildOverallProgress() {
    // Calculate overall score
    final waterScore = _waterProgress;
    final fitnessScore = (_fitnessWorkouts / 5).clamp(0.0, 1.0);
    final focusScore = (_focusMinutes / 60).clamp(0.0, 1.0);
    final medicineScore = _medicineTotal > 0 
        ? (_medicineTaken / _medicineTotal).clamp(0.0, 1.0) 
        : 1.0;
    
    final overallScore = (waterScore + fitnessScore + focusScore + medicineScore) / 4;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getScoreColor(overallScore),
            _getScoreColor(overallScore).withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _getScoreColor(overallScore).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
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
                    value: overallScore,
                    strokeWidth: 8,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${(overallScore * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'score',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
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
                  'Today\'s Health Score',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  _getScoreMessage(overallScore),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getScoreDescription(overallScore),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildModuleCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildWaterCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildFitnessCard()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildFocusCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildMedicineCard()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaterCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WaterDashboardScreen()),
      ).then((_) => _loadAllData()),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.info.withOpacity(0.15),
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.water_drop, color: AppColors.info, size: 24),
                ),
                const Spacer(),
                Text(
                  '${(_waterProgress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _waterProgress >= 1 ? AppColors.success : AppColors.info,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Water',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              '$_waterMl / $_waterGoal ml',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _waterProgress,
                minHeight: 6,
                backgroundColor: AppColors.info.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(
                  _waterProgress >= 1 ? AppColors.success : AppColors.info,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFitnessCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FitnessDashboardScreen()),
      ).then((_) => _loadAllData()),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fitness_center, color: AppColors.primary, size: 24),
                ),
                const Spacer(),
                Text(
                  '$_fitnessWorkouts/5',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _fitnessWorkouts >= 5 ? AppColors.success : AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Fitness',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              '$_fitnessMinutes min • $_fitnessCalories kcal',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_fitnessWorkouts / 5).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(
                  _fitnessWorkouts >= 5 ? AppColors.success : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FocusDashboardScreen()),
      ).then((_) => _loadAllData()),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withOpacity(0.15),
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.self_improvement, color: AppColors.success, size: 24),
                ),
                const Spacer(),
                Text(
                  _formatMinutes(_focusMinutes),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _focusMinutes >= 60 ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Focus',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              '$_focusSessions total sessions',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_focusMinutes / 60).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.success.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(
                  _focusMinutes >= 60 ? AppColors.success : AppColors.success.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineCard() {
    final progress = _medicineTotal > 0 ? _medicineTaken / _medicineTotal : 0.0;
    
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MedicineDashboardScreen()),
      ).then((_) => _loadAllData()),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withOpacity(0.15),
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.medication, color: AppColors.error, size: 24),
                ),
                const Spacer(),
                Text(
                  '$_medicineTaken/$_medicineTotal',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: progress >= 1 ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Medicine',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              '${(_medicineAdherence * 100).toInt()}% adherence',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.error.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(
                  progress >= 1 ? AppColors.success : AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildQuickActionButton(
            icon: Icons.water_drop,
            label: 'Log Water',
            color: AppColors.info,
            onTap: () async {
              final waterBeverage = WaterService.getBeverage('water') ?? BeverageType.defaultBeverages.first;
              await WaterService.addWaterLog(amountMl: 250, beverage: waterBeverage);
              _loadAllData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('+250ml water added'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          _buildQuickActionButton(
            icon: Icons.fitness_center,
            label: 'Log Workout',
            color: AppColors.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FitnessDashboardScreen()),
            ).then((_) => _loadAllData()),
          ),
          _buildQuickActionButton(
            icon: Icons.timer,
            label: 'Start Focus',
            color: AppColors.success,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FocusDashboardScreen()),
            ).then((_) => _loadAllData()),
          ),
          _buildQuickActionButton(
            icon: Icons.medication,
            label: 'Take Medicine',
            color: AppColors.error,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MedicineDashboardScreen()),
            ).then((_) => _loadAllData()),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 85,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySummary() {
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
            'This Week',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildWeeklyRow(Icons.water_drop, 'Water Goals Met', '5/7 days', AppColors.info),
          const Divider(height: 24),
          _buildWeeklyRow(Icons.fitness_center, 'Workouts Completed', '$_fitnessWorkouts workouts', AppColors.primary),
          const Divider(height: 24),
          _buildWeeklyRow(Icons.timer, 'Focus Time', _formatMinutes(_focusMinutes * 7), AppColors.success),
          const Divider(height: 24),
          _buildWeeklyRow(Icons.medication, 'Medicine Adherence', '${(_medicineAdherence * 100).toInt()}%', AppColors.error),
        ],
      ),
    );
  }

  Widget _buildWeeklyRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 0.8) return AppColors.success;
    if (score >= 0.5) return AppColors.warning;
    return AppColors.primary;
  }

  String _getScoreMessage(double score) {
    if (score >= 0.9) return 'Excellent! 🌟';
    if (score >= 0.75) return 'Great job! 💪';
    if (score >= 0.5) return 'Keep going! 👍';
    return 'Let\'s get started! 🚀';
  }

  String _getScoreDescription(double score) {
    if (score >= 0.9) return 'You\'re crushing your health goals today!';
    if (score >= 0.75) return 'You\'re on track with your daily goals.';
    if (score >= 0.5) return 'Good progress, keep the momentum!';
    return 'Every step counts toward better health.';
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
}

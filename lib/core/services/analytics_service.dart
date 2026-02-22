import 'package:flutter/foundation.dart';
import 'storage_service.dart';
import '../../features/water/services/water_service.dart';
import '../../features/water/models/enhanced_water_log.dart';

/// Unified Analytics Service for tracking trends and insights
/// Inspired by Google Fit, Fitbit, WaterMinder analytics
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  // ============ Date Range Helpers ============
  
  static DateTime get todayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime getWeekStart() {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  static DateTime get monthStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  static List<DateTime> getLast7Days() {
    return List.generate(7, (i) => todayStart.subtract(Duration(days: 6 - i)));
  }

  static List<DateTime> getLast30Days() {
    return List.generate(30, (i) => todayStart.subtract(Duration(days: 29 - i)));
  }

  // ============ Water Analytics ============

  /// Get water intake for a specific date
  DailyWaterData? getWaterIntakeForDate(DateTime date) {
    return WaterService.getDataForDate(date);
  }

  /// Get water analytics for date range
  WaterAnalytics getWaterAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final intakesInRange = WaterService.getDataForRange(startDate, endDate);

    if (intakesInRange.isEmpty) {
      return WaterAnalytics.empty();
    }

    final totalMl = intakesInRange.fold<int>(0, (sum, w) => sum + w.effectiveHydrationMl);
    final avgMl = totalMl ~/ intakesInRange.length;
    final daysMetGoal = intakesInRange.where((w) => w.progress >= 1.0).length;
    final totalDays = intakesInRange.length;

    // Calculate trend
    final trend = _calculateTrend(
      intakesInRange.map((w) => w.effectiveHydrationMl.toDouble()).toList()
    );

    // Daily breakdown
    final dailyData = <DateTime, int>{};
    for (final intake in intakesInRange) {
      final dayKey = intake.date;
      dailyData[dayKey] = intake.effectiveHydrationMl;
    }

    return WaterAnalytics(
      totalMl: totalMl,
      averageMl: avgMl,
      daysMetGoal: daysMetGoal,
      totalDays: totalDays,
      goalCompletionRate: totalDays > 0 ? daysMetGoal / totalDays : 0.0,
      trend: trend,
      dailyData: dailyData,
    );
  }

  /// Get today's water progress
  double getTodayWaterProgress() {
    return WaterService.getTodayData().progress;
  }

  // ============ Fitness Analytics ============

  /// Get fitness analytics for date range
  FitnessAnalytics getFitnessAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final prefs = StorageService.getAppPreferences();
    
    // Get logged workouts from preferences
    final workoutsData = prefs['fitnessCompletedWorkouts'];
    List<Map<String, dynamic>> completedWorkouts = [];
    
    if (workoutsData != null && workoutsData is List) {
      completedWorkouts = List<Map<String, dynamic>>.from(
        workoutsData.map((w) => Map<String, dynamic>.from(w))
      );
    }

    // Filter by date range
    final workoutsInRange = completedWorkouts.where((w) {
      final date = DateTime.tryParse(w['date'] ?? '');
      if (date == null) return false;
      return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
             date.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();

    final totalWorkouts = workoutsInRange.length;
    final totalMinutes = workoutsInRange.fold<int>(
      0, (sum, w) => sum + ((w['durationMinutes'] ?? 0) as int)
    );
    final totalCalories = workoutsInRange.fold<int>(
      0, (sum, w) => sum + ((w['calories'] ?? 0) as int)
    );

    // Calculate by type
    final byType = <String, int>{};
    for (final workout in workoutsInRange) {
      final type = workout['type'] as String? ?? 'other';
      byType[type] = (byType[type] ?? 0) + 1;
    }

    // Weekly goal tracking
    final weeklyGoal = prefs['fitnessWeeklyGoal'] ?? 5;
    final weekStart = AnalyticsService.getWeekStart();
    final thisWeekWorkouts = workoutsInRange.where((w) {
      final date = DateTime.tryParse(w['date'] ?? '');
      return date != null && date.isAfter(weekStart);
    }).length;

    return FitnessAnalytics(
      totalWorkouts: totalWorkouts,
      totalMinutes: totalMinutes,
      totalCalories: totalCalories,
      averageMinutesPerWorkout: totalWorkouts > 0 ? totalMinutes ~/ totalWorkouts : 0,
      workoutsByType: byType,
      weeklyGoal: weeklyGoal,
      weeklyProgress: thisWeekWorkouts,
      streak: _calculateStreak(workoutsInRange),
    );
  }

  /// Log a completed workout
  Future<void> logWorkout({
    required String type,
    required int durationMinutes,
    int? calories,
    String? notes,
  }) async {
    final prefs = StorageService.getAppPreferences();
    List<Map<String, dynamic>> workouts = [];
    
    final workoutsData = prefs['fitnessCompletedWorkouts'];
    if (workoutsData != null && workoutsData is List) {
      workouts = List<Map<String, dynamic>>.from(
        workoutsData.map((w) => Map<String, dynamic>.from(w))
      );
    }

    workouts.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': type,
      'durationMinutes': durationMinutes,
      'calories': calories ?? _estimateCalories(type, durationMinutes),
      'notes': notes,
      'date': DateTime.now().toIso8601String(),
    });

    // Keep last 100 workouts
    if (workouts.length > 100) {
      workouts = workouts.take(100).toList();
    }

    await StorageService.setAppPreference('fitnessCompletedWorkouts', workouts);
    debugPrint('✓ Logged workout: $type for $durationMinutes min');
  }

  int _estimateCalories(String type, int minutes) {
    final metValues = {
      'walk': 3.5, 'run': 9.8, 'cycling': 7.5, 'swimming': 8.0,
      'gym': 6.0, 'yoga': 3.0, 'hiit': 10.0, 'stretching': 2.5,
    };
    final met = metValues[type] ?? 5.0;
    return ((met * 70 * (minutes / 60))).round();
  }

  int _calculateStreak(List<Map<String, dynamic>> workouts) {
    if (workouts.isEmpty) return 0;
    
    int streak = 0;
    var currentDate = todayStart;
    
    for (int i = 0; i < 365; i++) {
      final hasWorkout = workouts.any((w) {
        final date = DateTime.tryParse(w['date'] ?? '');
        return date != null && _isSameDay(date, currentDate);
      });
      
      if (hasWorkout) {
        streak++;
        currentDate = currentDate.subtract(const Duration(days: 1));
      } else if (i > 0) {
        break;
      } else {
        currentDate = currentDate.subtract(const Duration(days: 1));
      }
    }
    
    return streak;
  }

  // ============ Focus/Productivity Analytics ============

  /// Get focus analytics for date range
  FocusAnalytics getFocusAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final prefs = StorageService.getAppPreferences();
    
    // Get recent sessions
    final sessionsData = prefs['focusRecentSessions'];
    List<Map<String, dynamic>> sessions = [];
    
    if (sessionsData != null && sessionsData is List) {
      sessions = List<Map<String, dynamic>>.from(
        sessionsData.map((s) => Map<String, dynamic>.from(s))
      );
    }

    // Filter by date range
    final sessionsInRange = sessions.where((s) {
      final date = DateTime.tryParse(s['date'] ?? '');
      if (date == null) return false;
      return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
             date.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();

    final totalSessions = sessionsInRange.length;
    final totalMinutes = sessionsInRange.fold<int>(
      0, (sum, s) => sum + ((s['minutes'] ?? 0) as int)
    );

    // By activity
    final byActivity = <String, int>{};
    for (final session in sessionsInRange) {
      final activity = session['activity'] as String? ?? 'other';
      byActivity[activity] = (byActivity[activity] ?? 0) + 
          ((session['minutes'] ?? 0) as int);
    }

    // Today's focus time
    final todayMinutesKey = 'focusTodayMinutes_${_formatDateKey(todayStart)}';
    final todayMinutes = prefs[todayMinutesKey] ?? 0;

    // Weekly goal
    final weeklyGoal = prefs['focusWeeklyGoalMinutes'] ?? 300; // 5 hours default
    
    return FocusAnalytics(
      totalSessions: totalSessions,
      totalMinutes: totalMinutes,
      averageSessionMinutes: totalSessions > 0 ? totalMinutes ~/ totalSessions : 0,
      minutesByActivity: byActivity,
      todayMinutes: todayMinutes,
      weeklyGoal: weeklyGoal,
      weeklyProgress: _getWeekFocusMinutes(prefs),
    );
  }

  int _getWeekFocusMinutes(Map<String, dynamic> prefs) {
    int total = 0;
    for (final date in getLast7Days()) {
      final key = 'focusTodayMinutes_${_formatDateKey(date)}';
      total += (prefs[key] ?? 0) as int;
    }
    return total;
  }

  // ============ Medicine Analytics ============

  /// Get medicine adherence analytics
  MedicineAnalytics getMedicineAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final medicines = StorageService.getAllMedicines();
    final prefs = StorageService.getAppPreferences();
    
    // Get taken records
    final takenData = prefs['medicineTakenRecords'];
    List<Map<String, dynamic>> takenRecords = [];
    
    if (takenData != null && takenData is List) {
      takenRecords = List<Map<String, dynamic>>.from(
        takenData.map((r) => Map<String, dynamic>.from(r))
      );
    }

    // Filter by date range
    final recordsInRange = takenRecords.where((r) {
      final date = DateTime.tryParse(r['date'] ?? '');
      if (date == null) return false;
      return date.isAfter(startDate.subtract(const Duration(days: 1))) &&
             date.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();

    // Calculate adherence
    final totalMedicines = medicines.length;
    final dayCount = endDate.difference(startDate).inDays + 1;
    final expectedDoses = totalMedicines * dayCount;
    final takenDoses = recordsInRange.length;
    
    final adherenceRate = expectedDoses > 0 ? takenDoses / expectedDoses : 0.0;

    // By medicine
    final byMedicine = <String, double>{};
    for (final medicine in medicines) {
      final medicineRecords = recordsInRange.where(
        (r) => r['medicineId'] == medicine.id
      ).length;
      byMedicine[medicine.name] = dayCount > 0 ? medicineRecords / dayCount : 0.0;
    }

    // Today's status
    final todayTaken = recordsInRange.where((r) {
      final date = DateTime.tryParse(r['date'] ?? '');
      return date != null && _isSameDay(date, todayStart);
    }).length;

    return MedicineAnalytics(
      totalMedicines: totalMedicines,
      takenToday: todayTaken,
      expectedToday: totalMedicines,
      adherenceRate: adherenceRate,
      adherenceByMedicine: byMedicine,
      missedDoses: expectedDoses - takenDoses,
      streak: _calculateMedicineStreak(recordsInRange, totalMedicines),
    );
  }

  /// Log medicine taken
  Future<void> logMedicineTaken({
    required String medicineId,
    required String medicineName,
    DateTime? takenAt,
  }) async {
    final prefs = StorageService.getAppPreferences();
    List<Map<String, dynamic>> records = [];
    
    final recordsData = prefs['medicineTakenRecords'];
    if (recordsData != null && recordsData is List) {
      records = List<Map<String, dynamic>>.from(
        recordsData.map((r) => Map<String, dynamic>.from(r))
      );
    }

    records.insert(0, {
      'medicineId': medicineId,
      'medicineName': medicineName,
      'date': (takenAt ?? DateTime.now()).toIso8601String(),
    });

    // Keep last 500 records
    if (records.length > 500) {
      records = records.take(500).toList();
    }

    await StorageService.setAppPreference('medicineTakenRecords', records);
    debugPrint('✓ Logged medicine taken: $medicineName');
  }

  int _calculateMedicineStreak(List<Map<String, dynamic>> records, int totalMedicines) {
    if (records.isEmpty || totalMedicines == 0) return 0;
    
    int streak = 0;
    var currentDate = todayStart;
    
    for (int i = 0; i < 365; i++) {
      final dayRecords = records.where((r) {
        final date = DateTime.tryParse(r['date'] ?? '');
        return date != null && _isSameDay(date, currentDate);
      }).length;
      
      if (dayRecords >= totalMedicines) {
        streak++;
        currentDate = currentDate.subtract(const Duration(days: 1));
      } else if (i > 0) {
        break;
      } else {
        currentDate = currentDate.subtract(const Duration(days: 1));
      }
    }
    
    return streak;
  }

  // ============ Unified Dashboard Data ============

  /// Get overview data for all modules
  DashboardOverview getDashboardOverview() {
    return DashboardOverview(
      waterProgress: getTodayWaterProgress(),
      fitnessToday: getFitnessAnalytics(
        startDate: todayStart,
        endDate: DateTime.now(),
      ),
      focusToday: getFocusAnalytics(
        startDate: todayStart,
        endDate: DateTime.now(),
      ),
      medicineToday: getMedicineAnalytics(
        startDate: todayStart,
        endDate: DateTime.now(),
      ),
    );
  }

  // ============ Helpers ============

  double _calculateTrend(List<double> values) {
    if (values.length < 2) return 0.0;
    
    final firstHalf = values.take(values.length ~/ 2);
    final secondHalf = values.skip(values.length ~/ 2);
    
    final firstAvg = firstHalf.fold(0.0, (a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.fold(0.0, (a, b) => a + b) / secondHalf.length;
    
    if (firstAvg == 0) return 0.0;
    return ((secondAvg - firstAvg) / firstAvg * 100);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime get currentWeekStart => AnalyticsService.getWeekStart();
}

// ============ Analytics Models ============

class WaterAnalytics {
  final int totalMl;
  final int averageMl;
  final int daysMetGoal;
  final int totalDays;
  final double goalCompletionRate;
  final double trend;
  final Map<DateTime, int> dailyData;

  WaterAnalytics({
    required this.totalMl,
    required this.averageMl,
    required this.daysMetGoal,
    required this.totalDays,
    required this.goalCompletionRate,
    required this.trend,
    required this.dailyData,
  });

  factory WaterAnalytics.empty() => WaterAnalytics(
    totalMl: 0,
    averageMl: 0,
    daysMetGoal: 0,
    totalDays: 0,
    goalCompletionRate: 0,
    trend: 0,
    dailyData: {},
  );
}

class FitnessAnalytics {
  final int totalWorkouts;
  final int totalMinutes;
  final int totalCalories;
  final int averageMinutesPerWorkout;
  final Map<String, int> workoutsByType;
  final int weeklyGoal;
  final int weeklyProgress;
  final int streak;

  FitnessAnalytics({
    required this.totalWorkouts,
    required this.totalMinutes,
    required this.totalCalories,
    required this.averageMinutesPerWorkout,
    required this.workoutsByType,
    required this.weeklyGoal,
    required this.weeklyProgress,
    required this.streak,
  });
}

class FocusAnalytics {
  final int totalSessions;
  final int totalMinutes;
  final int averageSessionMinutes;
  final Map<String, int> minutesByActivity;
  final int todayMinutes;
  final int weeklyGoal;
  final int weeklyProgress;

  FocusAnalytics({
    required this.totalSessions,
    required this.totalMinutes,
    required this.averageSessionMinutes,
    required this.minutesByActivity,
    required this.todayMinutes,
    required this.weeklyGoal,
    required this.weeklyProgress,
  });
}

class MedicineAnalytics {
  final int totalMedicines;
  final int takenToday;
  final int expectedToday;
  final double adherenceRate;
  final Map<String, double> adherenceByMedicine;
  final int missedDoses;
  final int streak;

  MedicineAnalytics({
    required this.totalMedicines,
    required this.takenToday,
    required this.expectedToday,
    required this.adherenceRate,
    required this.adherenceByMedicine,
    required this.missedDoses,
    required this.streak,
  });
}

class DashboardOverview {
  final double waterProgress;
  final FitnessAnalytics fitnessToday;
  final FocusAnalytics focusToday;
  final MedicineAnalytics medicineToday;

  DashboardOverview({
    required this.waterProgress,
    required this.fitnessToday,
    required this.focusToday,
    required this.medicineToday,
  });
}

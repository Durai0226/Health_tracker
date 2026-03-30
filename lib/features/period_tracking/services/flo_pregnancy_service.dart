import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/pregnancy_data.dart';

/// Service for pregnancy tracking calculations and storage
class FloPregnancyService {
  static const String _pregnancyKey = 'flo_pregnancy_data';
  static PregnancyData? _cachedData;

  /// Get current pregnancy data
  static Future<PregnancyData?> getPregnancyData() async {
    if (_cachedData != null) return _cachedData;

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_pregnancyKey);
      if (json == null) return null;

      _cachedData = PregnancyData.fromJson(jsonDecode(json));
      return _cachedData;
    } catch (e) {
      debugPrint('Error loading pregnancy data: $e');
      return null;
    }
  }

  /// Save pregnancy data
  static Future<void> savePregnancyData(PregnancyData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pregnancyKey, jsonEncode(data.toJson()));
      _cachedData = data;
    } catch (e) {
      debugPrint('Error saving pregnancy data: $e');
    }
  }

  /// Start pregnancy tracking from last period date
  static Future<PregnancyData> startPregnancy(DateTime lastPeriodDate) async {
    final data = PregnancyData.fromLastPeriod(lastPeriodDate);
    await savePregnancyData(data);
    return data;
  }

  /// End pregnancy tracking
  static Future<void> endPregnancy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pregnancyKey);
      _cachedData = null;
    } catch (e) {
      debugPrint('Error ending pregnancy: $e');
    }
  }

  /// Add a pregnancy log entry
  static Future<void> addLog(PregnancyLog log) async {
    final data = await getPregnancyData();
    if (data == null) return;

    final updatedLogs = [...data.logs, log];
    final updatedData = data.copyWith(logs: updatedLogs);
    await savePregnancyData(updatedData);
  }

  /// Get log for specific date
  static Future<PregnancyLog?> getLogForDate(DateTime date) async {
    final data = await getPregnancyData();
    if (data == null) return null;

    try {
      return data.logs.firstWhere(
        (log) =>
            log.date.year == date.year &&
            log.date.month == date.month &&
            log.date.day == date.day,
      );
    } catch (e) {
      return null;
    }
  }

  /// Calculate due date from conception date
  static DateTime calculateDueDate(DateTime conceptionDate) {
    return conceptionDate.add(const Duration(days: 266)); // 38 weeks from conception
  }

  /// Calculate due date from last period date
  static DateTime calculateDueDateFromLastPeriod(DateTime lastPeriodDate) {
    return lastPeriodDate.add(const Duration(days: 280)); // 40 weeks from LMP
  }

  /// Get current week of pregnancy
  static int getCurrentWeek(DateTime conceptionDate) {
    final daysSinceConception = DateTime.now().difference(conceptionDate).inDays;
    return (daysSinceConception / 7).floor() + 1;
  }

  /// Get current trimester (1, 2, or 3)
  static int getTrimester(int week) {
    if (week <= 12) return 1;
    if (week <= 27) return 2;
    return 3;
  }

  /// Get trimester name
  static String getTrimesterName(int trimester) {
    switch (trimester) {
      case 1:
        return 'First Trimester';
      case 2:
        return 'Second Trimester';
      case 3:
        return 'Third Trimester';
      default:
        return 'Unknown';
    }
  }

  /// Get fetus info for current week
  static FetusInfo getFetusInfo(int week) {
    return FetusInfo.forWeek(week);
  }

  /// Calculate weight gain recommendation based on BMI and week
  static Map<String, double> getWeightGainRecommendation(double preBMI, int week) {
    // Weight gain recommendations based on pre-pregnancy BMI
    double weeklyGain;
    double totalMin;
    double totalMax;

    if (preBMI < 18.5) {
      // Underweight
      weeklyGain = 0.51;
      totalMin = 12.7;
      totalMax = 18.1;
    } else if (preBMI < 25) {
      // Normal weight
      weeklyGain = 0.42;
      totalMin = 11.3;
      totalMax = 15.9;
    } else if (preBMI < 30) {
      // Overweight
      weeklyGain = 0.28;
      totalMin = 6.8;
      totalMax = 11.3;
    } else {
      // Obese
      weeklyGain = 0.22;
      totalMin = 5.0;
      totalMax = 9.1;
    }

    // First trimester: minimal gain (~0.5-2kg total)
    double expectedGain;
    if (week <= 12) {
      expectedGain = week * 0.15;
    } else {
      // Second and third trimester
      expectedGain = 2 + (week - 12) * weeklyGain;
    }

    return {
      'expectedGain': expectedGain,
      'weeklyGain': weeklyGain,
      'totalMin': totalMin,
      'totalMax': totalMax,
    };
  }

  /// Get kick count goal based on week
  static int getKickCountGoal(int week) {
    if (week < 28) return 0; // Kick counting starts at 28 weeks
    return 10; // 10 kicks in 2 hours is normal
  }

  /// Get recommended appointments for current week
  static List<String> getRecommendedAppointments(int week) {
    final appointments = <String>[];

    if (week == 8) appointments.add('First prenatal visit');
    if (week == 12) appointments.add('First trimester screening');
    if (week == 16) appointments.add('Second trimester checkup');
    if (week == 18) appointments.add('Anatomy scan (18-22 weeks)');
    if (week == 24) appointments.add('Glucose screening');
    if (week == 28) appointments.add('Third trimester begins - weekly appointments');
    if (week == 32) appointments.add('Growth scan');
    if (week == 36) appointments.add('Group B strep test');
    if (week >= 37 && week <= 40) appointments.add('Weekly checkup');

    return appointments;
  }

  /// Clear cache
  static void clearCache() {
    _cachedData = null;
  }
}

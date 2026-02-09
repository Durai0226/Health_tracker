
import 'package:hive/hive.dart';

part 'period_data.g.dart';

@HiveType(typeId: 1)
class PeriodData extends HiveObject {
  @HiveField(0)
  final DateTime lastPeriodDate;

  @HiveField(1)
  final int cycleLength; // Default: 28 days

  @HiveField(2)
  final int periodDuration; // Default: 5 days

  @HiveField(3)
  final bool isEnabled;

  PeriodData({
    required this.lastPeriodDate,
    this.cycleLength = 28,
    this.periodDuration = 5,
    this.isEnabled = true,
  });

  DateTime get nextPeriodDate => lastPeriodDate.add(Duration(days: cycleLength));

  bool isOnPeriod(DateTime date) {
    final start = lastPeriodDate;
    final end = lastPeriodDate.add(Duration(days: periodDuration));
    return date.isAfter(start.subtract(Duration(days: 1))) && date.isBefore(end.add(Duration(days: 1)));
  }

  int daysUntilNextPeriod(DateTime today) {
    return nextPeriodDate.difference(today).inDays;
  }
}

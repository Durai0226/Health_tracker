class PeriodData {
  final DateTime lastPeriodDate;
  final int cycleLength; // Default: 28 days
  final int periodDuration; // Default: 5 days
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
    return date.isAfter(start.subtract(const Duration(days: 1))) && date.isBefore(end.add(const Duration(days: 1)));
  }

  int daysUntilNextPeriod(DateTime today) {
    return nextPeriodDate.difference(today).inDays;
  }

  Map<String, dynamic> toJson() => {
    'lastPeriodDate': lastPeriodDate.toIso8601String(),
    'cycleLength': cycleLength,
    'periodDuration': periodDuration,
    'isEnabled': isEnabled,
  };

  factory PeriodData.fromJson(Map<String, dynamic> json) => PeriodData(
    lastPeriodDate: DateTime.parse(json['lastPeriodDate']),
    cycleLength: json['cycleLength'] ?? 28,
    periodDuration: json['periodDuration'] ?? 5,
    isEnabled: json['isEnabled'] ?? true,
  );
}

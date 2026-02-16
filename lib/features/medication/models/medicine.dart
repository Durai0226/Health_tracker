
import 'package:hive/hive.dart';

part 'medicine.g.dart';

@HiveType(typeId: 0)
class Medicine extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int dosageAmount;

  @HiveField(3)
  final String dosageType; // Tablet, Capsule, Syrup, Injection

  @HiveField(4)
  final DateTime time; // We will store the full DateTime but mostly use the time part

  @HiveField(5)
  final String frequency; // "Once a day", "Twice a day", "Every X hours"

  @HiveField(6)
  final int? durationDays; // null means "forever"

  @HiveField(7)
  final bool enableReminder;

  @HiveField(8)
  final bool enableBuyReminder;

  @HiveField(9)
  final int? stockRemaining;
  
  @HiveField(10)
  final int? lowStockThreshold;

  Medicine({
    required this.id,
    required this.name,
    required this.dosageAmount,
    required this.dosageType,
    required this.time,
    required this.frequency,
    this.durationDays,
    this.enableReminder = true,
    this.enableBuyReminder = false,
    this.stockRemaining,
    this.lowStockThreshold,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dosageAmount': dosageAmount,
    'dosageType': dosageType,
    'time': time.toIso8601String(),
    'frequency': frequency,
    'durationDays': durationDays,
    'enableReminder': enableReminder,
    'enableBuyReminder': enableBuyReminder,
    'stockRemaining': stockRemaining,
    'lowStockThreshold': lowStockThreshold,
  };

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    dosageAmount: json['dosageAmount'] ?? 1,
    dosageType: json['dosageType'] ?? 'Tablet',
    time: DateTime.parse(json['time']),
    frequency: json['frequency'] ?? 'Once a day',
    durationDays: json['durationDays'],
    enableReminder: json['enableReminder'] ?? true,
    enableBuyReminder: json['enableBuyReminder'] ?? false,
    stockRemaining: json['stockRemaining'],
    lowStockThreshold: json['lowStockThreshold'],
  );
}

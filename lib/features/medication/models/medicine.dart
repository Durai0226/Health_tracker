
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
}

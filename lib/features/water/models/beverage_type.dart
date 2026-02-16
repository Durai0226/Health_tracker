import 'package:hive/hive.dart';

part 'beverage_type.g.dart';

/// Beverage types with hydration percentages
/// Some drinks like coffee and alcohol can have negative hydration effects
@HiveType(typeId: 20)
class BeverageType extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String emoji;

  @HiveField(3)
  final int hydrationPercent; // 100 = pure water, 80 = coffee, -50 = alcohol

  @HiveField(4)
  final String colorHex;

  @HiveField(5)
  final bool isDefault;

  @HiveField(6)
  final bool hasCaffeine;

  @HiveField(7)
  final int caffeinePerMl; // mg per 100ml

  @HiveField(8)
  final bool isAlcoholic;

  @HiveField(9)
  final int defaultAmountMl;

  BeverageType({
    required this.id,
    required this.name,
    required this.emoji,
    this.hydrationPercent = 100,
    this.colorHex = '#2196F3',
    this.isDefault = false,
    this.hasCaffeine = false,
    this.caffeinePerMl = 0,
    this.isAlcoholic = false,
    this.defaultAmountMl = 250,
  });

  /// Calculate effective hydration from a given amount
  int getEffectiveHydration(int amountMl) {
    return (amountMl * hydrationPercent / 100).round();
  }

  BeverageType copyWith({
    String? name,
    String? emoji,
    int? hydrationPercent,
    String? colorHex,
    bool? isDefault,
    bool? hasCaffeine,
    int? caffeinePerMl,
    bool? isAlcoholic,
    int? defaultAmountMl,
  }) {
    return BeverageType(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      hydrationPercent: hydrationPercent ?? this.hydrationPercent,
      colorHex: colorHex ?? this.colorHex,
      isDefault: isDefault ?? this.isDefault,
      hasCaffeine: hasCaffeine ?? this.hasCaffeine,
      caffeinePerMl: caffeinePerMl ?? this.caffeinePerMl,
      isAlcoholic: isAlcoholic ?? this.isAlcoholic,
      defaultAmountMl: defaultAmountMl ?? this.defaultAmountMl,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'hydrationPercent': hydrationPercent,
    'colorHex': colorHex,
    'isDefault': isDefault,
    'hasCaffeine': hasCaffeine,
    'caffeinePerMl': caffeinePerMl,
    'isAlcoholic': isAlcoholic,
    'defaultAmountMl': defaultAmountMl,
  };

  factory BeverageType.fromJson(Map<String, dynamic> json) => BeverageType(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    emoji: json['emoji'] ?? '💧',
    hydrationPercent: json['hydrationPercent'] ?? 100,
    colorHex: json['colorHex'] ?? '#2196F3',
    isDefault: json['isDefault'] ?? false,
    hasCaffeine: json['hasCaffeine'] ?? false,
    caffeinePerMl: json['caffeinePerMl'] ?? 0,
    isAlcoholic: json['isAlcoholic'] ?? false,
    defaultAmountMl: json['defaultAmountMl'] ?? 250,
  );

  /// Default beverage types - these are always available
  static List<BeverageType> get defaultBeverages => [
    BeverageType(
      id: 'water',
      name: 'Water',
      emoji: '💧',
      hydrationPercent: 100,
      colorHex: '#2196F3',
      isDefault: true,
      defaultAmountMl: 250,
    ),
    BeverageType(
      id: 'sparkling_water',
      name: 'Sparkling Water',
      emoji: '🫧',
      hydrationPercent: 100,
      colorHex: '#03A9F4',
      isDefault: true,
      defaultAmountMl: 250,
    ),
    BeverageType(
      id: 'coffee',
      name: 'Coffee',
      emoji: '☕',
      hydrationPercent: 80,
      colorHex: '#795548',
      isDefault: true,
      hasCaffeine: true,
      caffeinePerMl: 40, // ~40mg per 100ml
      defaultAmountMl: 150,
    ),
    BeverageType(
      id: 'espresso',
      name: 'Espresso',
      emoji: '☕',
      hydrationPercent: 75,
      colorHex: '#3E2723',
      isDefault: true,
      hasCaffeine: true,
      caffeinePerMl: 212, // ~212mg per 100ml
      defaultAmountMl: 30,
    ),
    BeverageType(
      id: 'tea',
      name: 'Tea',
      emoji: '🍵',
      hydrationPercent: 95,
      colorHex: '#8BC34A',
      isDefault: true,
      hasCaffeine: true,
      caffeinePerMl: 20, // ~20mg per 100ml
      defaultAmountMl: 200,
    ),
    BeverageType(
      id: 'green_tea',
      name: 'Green Tea',
      emoji: '🍃',
      hydrationPercent: 98,
      colorHex: '#4CAF50',
      isDefault: true,
      hasCaffeine: true,
      caffeinePerMl: 12,
      defaultAmountMl: 200,
    ),
    BeverageType(
      id: 'herbal_tea',
      name: 'Herbal Tea',
      emoji: '🌿',
      hydrationPercent: 100,
      colorHex: '#9C27B0',
      isDefault: true,
      hasCaffeine: false,
      defaultAmountMl: 200,
    ),
    BeverageType(
      id: 'milk',
      name: 'Milk',
      emoji: '🥛',
      hydrationPercent: 90,
      colorHex: '#FAFAFA',
      isDefault: true,
      defaultAmountMl: 200,
    ),
    BeverageType(
      id: 'juice',
      name: 'Fruit Juice',
      emoji: '🧃',
      hydrationPercent: 85,
      colorHex: '#FF9800',
      isDefault: true,
      defaultAmountMl: 200,
    ),
    BeverageType(
      id: 'orange_juice',
      name: 'Orange Juice',
      emoji: '🍊',
      hydrationPercent: 85,
      colorHex: '#FF5722',
      isDefault: true,
      defaultAmountMl: 200,
    ),
    BeverageType(
      id: 'smoothie',
      name: 'Smoothie',
      emoji: '🥤',
      hydrationPercent: 80,
      colorHex: '#E91E63',
      isDefault: true,
      defaultAmountMl: 300,
    ),
    BeverageType(
      id: 'coconut_water',
      name: 'Coconut Water',
      emoji: '🥥',
      hydrationPercent: 100,
      colorHex: '#FFEB3B',
      isDefault: true,
      defaultAmountMl: 250,
    ),
    BeverageType(
      id: 'sports_drink',
      name: 'Sports Drink',
      emoji: '⚡',
      hydrationPercent: 95,
      colorHex: '#00BCD4',
      isDefault: true,
      defaultAmountMl: 500,
    ),
    BeverageType(
      id: 'soda',
      name: 'Soda',
      emoji: '🥤',
      hydrationPercent: 70,
      colorHex: '#F44336',
      isDefault: true,
      hasCaffeine: true,
      caffeinePerMl: 10,
      defaultAmountMl: 330,
    ),
    BeverageType(
      id: 'diet_soda',
      name: 'Diet Soda',
      emoji: '🥤',
      hydrationPercent: 75,
      colorHex: '#9E9E9E',
      isDefault: true,
      hasCaffeine: true,
      caffeinePerMl: 10,
      defaultAmountMl: 330,
    ),
    BeverageType(
      id: 'energy_drink',
      name: 'Energy Drink',
      emoji: '🔋',
      hydrationPercent: 60,
      colorHex: '#FFEB3B',
      isDefault: true,
      hasCaffeine: true,
      caffeinePerMl: 32,
      defaultAmountMl: 250,
    ),
    BeverageType(
      id: 'lemonade',
      name: 'Lemonade',
      emoji: '🍋',
      hydrationPercent: 85,
      colorHex: '#FFEB3B',
      isDefault: true,
      defaultAmountMl: 250,
    ),
    BeverageType(
      id: 'iced_tea',
      name: 'Iced Tea',
      emoji: '🧊',
      hydrationPercent: 90,
      colorHex: '#795548',
      isDefault: true,
      hasCaffeine: true,
      caffeinePerMl: 15,
      defaultAmountMl: 350,
    ),
    // Alcoholic beverages (negative/low hydration due to diuretic effect)
    BeverageType(
      id: 'beer',
      name: 'Beer',
      emoji: '🍺',
      hydrationPercent: -20,
      colorHex: '#FFC107',
      isDefault: true,
      isAlcoholic: true,
      defaultAmountMl: 330,
    ),
    BeverageType(
      id: 'wine',
      name: 'Wine',
      emoji: '🍷',
      hydrationPercent: -30,
      colorHex: '#880E4F',
      isDefault: true,
      isAlcoholic: true,
      defaultAmountMl: 150,
    ),
    BeverageType(
      id: 'spirits',
      name: 'Spirits',
      emoji: '🥃',
      hydrationPercent: -50,
      colorHex: '#BF360C',
      isDefault: true,
      isAlcoholic: true,
      defaultAmountMl: 50,
    ),
    BeverageType(
      id: 'cocktail',
      name: 'Cocktail',
      emoji: '🍹',
      hydrationPercent: -25,
      colorHex: '#E91E63',
      isDefault: true,
      isAlcoholic: true,
      defaultAmountMl: 200,
    ),
  ];
}

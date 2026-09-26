/// Beverage types with hydration percentages.
///
/// Non-alcoholic drinks all count at 100%. That is not laziness — it is what
/// the evidence says. Killer 2014 (PLoS ONE, n=50, deuterium dilution, the
/// gold standard) found coffee and water indistinguishable: total body water
/// 51.5 vs 51.4 kg, 24-hour urine 2409 vs 2428 mL. Maughan's Beverage
/// Hydration Index puts coffee at 0.91, tea 1.03, cola 1.23, sports drink
/// 1.01 — none significantly different from water. This app used to score
/// coffee at 80% and cola at 70%, which invented a fluid deficit that did not
/// exist and then showed it to the user as fact on the dashboard.
///
/// Nothing is scored ABOVE 100 even though BHI ranks milk at 1.50: the index
/// measures 2-hour retention after a 1 L bolus, not contribution to a daily
/// target, and crediting more fluid than was drunk would be its own lie.
///
/// Alcohol is the one real deduction, and it is dose-derived — see
/// [hydrationPercentForAbv].
class BeverageType {
  final String id;
  final String name;
  final String emoji;
  final int hydrationPercent; // 100 = pure water, 80 = coffee, -50 = alcohol
  final String colorHex;
  final bool isDefault;
  final bool hasCaffeine;
  final int caffeinePerMl; // mg per 100ml
  final bool isAlcoholic;
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

  /// Calculate caffeine amount from a given drink volume
  int getCaffeineAmount(int amountMl) {
    if (!hasCaffeine) return 0;
    return (amountMl * caffeinePerMl / 100).round();
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

  /// Net hydration percentage for a drink of strength [abvPercent].
  ///
  /// Alcohol's cost is a *dose* effect, not a category effect, so it is derived
  /// rather than assigned. Two published numbers do all the work:
  ///
  ///   * Ethanol mass = `ml x abv/100 x 0.789` (ethanol's density, g/mL).
  ///   * **Hobson & Maughan 2010**: 1 L of 4% ABV beer against alcohol-free
  ///     beer produced 1279 +/- 256 mL of urine vs 1121 +/- 148 mL over 4 h
  ///     (p < 0.001) — **+158 mL** for the ~31.6 g of ethanol in that litre,
  ///     i.e. about **5 mL of extra urine per gram of ethanol**.
  ///
  /// (The commonly quoted "4 mL per gram" comes from reading that same study's
  /// 1 L of 4% beer as 40 g of ethanol. It is not: 1000 x 0.04 x 0.789 = 31.6 g.
  /// Mixing %ABV with %w/v understates every alcohol penalty by about a fifth.)
  ///
  /// So `netMl = ml - 5.0 x (ml x abv/100 x 0.789)`, giving
  /// `percent = 100 x (1 - 0.03945 x abv)`.
  ///
  /// The consequence is worth stating plainly, because it reverses what this
  /// app used to claim: **beer and wine are net hydrating.** A 330 mL beer is
  /// mostly water, and 5% ethanol does not cost more fluid than the drink
  /// supplies — Maughan's Beverage Hydration Index puts lager at 0.99, i.e.
  /// indistinguishable from water. Only spirits, where ethanol is a large
  /// fraction of a small volume, go net negative. The old flat values (beer
  /// -20%, wine -30%) told users a beer had *dehydrated* them by 66 mL, which
  /// is not true and is not what any of the evidence says.
  ///
  /// Note this models FLUID BALANCE only. Nothing here is a claim that alcohol
  /// is good for you.
  static int hydrationPercentForAbv(double abvPercent) =>
      (100 * (1 - 0.03945 * abvPercent)).round();

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
      hydrationPercent: 100,
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
      hydrationPercent: 100,
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
      hydrationPercent: 100,
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
      hydrationPercent: 100,
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
      hydrationPercent: 100,
      colorHex: '#FAFAFA',
      isDefault: true,
      defaultAmountMl: 200,
    ),
    BeverageType(
      id: 'juice',
      name: 'Fruit Juice',
      emoji: '🧃',
      hydrationPercent: 100,
      colorHex: '#FF9800',
      isDefault: true,
      defaultAmountMl: 200,
    ),
    BeverageType(
      id: 'orange_juice',
      name: 'Orange Juice',
      emoji: '🍊',
      hydrationPercent: 100,
      colorHex: '#FF5722',
      isDefault: true,
      defaultAmountMl: 200,
    ),
    BeverageType(
      id: 'smoothie',
      name: 'Smoothie',
      emoji: '🥤',
      hydrationPercent: 100,
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
      hydrationPercent: 100,
      colorHex: '#00BCD4',
      isDefault: true,
      defaultAmountMl: 500,
    ),
    BeverageType(
      id: 'soda',
      name: 'Soda',
      emoji: '🥤',
      hydrationPercent: 100,
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
      hydrationPercent: 100,
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
      hydrationPercent: 100,
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
      hydrationPercent: 100,
      colorHex: '#FFEB3B',
      isDefault: true,
      defaultAmountMl: 250,
    ),
    BeverageType(
      id: 'iced_tea',
      name: 'Iced Tea',
      emoji: '🧊',
      hydrationPercent: 100,
      colorHex: '#795548',
      isDefault: true,
      hasCaffeine: true,
      caffeinePerMl: 15,
      defaultAmountMl: 350,
    ),
    // Alcoholic beverages. Derived from strength via
    // [hydrationPercentForAbv], not assigned per category — see its doc for
    // why beer and wine come out NET HYDRATING and only spirits go negative.
    BeverageType(
      id: 'beer',
      name: 'Beer',
      emoji: '🍺',
      hydrationPercent: hydrationPercentForAbv(5.0), // a typical 5% ABV lager
      colorHex: '#FFC107',
      isDefault: true,
      isAlcoholic: true,
      defaultAmountMl: 330,
    ),
    BeverageType(
      id: 'wine',
      name: 'Wine',
      emoji: '🍷',
      hydrationPercent: hydrationPercentForAbv(12.0), // a typical 12% ABV table wine
      colorHex: '#880E4F',
      isDefault: true,
      isAlcoholic: true,
      defaultAmountMl: 150,
    ),
    BeverageType(
      id: 'spirits',
      name: 'Spirits',
      emoji: '🥃',
      hydrationPercent: hydrationPercentForAbv(40.0), // a typical 40% ABV spirit
      colorHex: '#BF360C',
      isDefault: true,
      isAlcoholic: true,
      defaultAmountMl: 50,
    ),
    BeverageType(
      id: 'cocktail',
      name: 'Cocktail',
      emoji: '🍹',
      hydrationPercent: hydrationPercentForAbv(15.0), // a mixed drink at roughly 15% ABV
      colorHex: '#E91E63',
      isDefault: true,
      isAlcoholic: true,
      defaultAmountMl: 200,
    ),
  ];
}

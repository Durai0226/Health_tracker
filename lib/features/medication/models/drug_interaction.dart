import 'medicine_enums.dart';

/// Drug interaction information
class DrugInteraction {
  final String id;
  final String drug1Name;
  final String drug2Name;
  final InteractionSeverity severity;
  final String description;
  final String? recommendation;
  final String? mechanism;
  final List<String>? references;

  DrugInteraction({
    required this.id,
    required this.drug1Name,
    required this.drug2Name,
    required this.severity,
    required this.description,
    this.recommendation,
    this.mechanism,
    this.references,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'drug1Name': drug1Name,
    'drug2Name': drug2Name,
    'severity': severity.index,
    'description': description,
    'recommendation': recommendation,
    'mechanism': mechanism,
    'references': references,
  };

  factory DrugInteraction.fromJson(Map<String, dynamic> json) => DrugInteraction(
    id: json['id'] ?? '',
    drug1Name: json['drug1Name'] ?? '',
    drug2Name: json['drug2Name'] ?? '',
    severity: InteractionSeverity.values[json['severity'] ?? 0],
    description: json['description'] ?? '',
    recommendation: json['recommendation'],
    mechanism: json['mechanism'],
    references: (json['references'] as List?)?.cast<String>(),
  );
}

/// Side effect information
class SideEffect {
  final String name;
  final String frequency; // "common", "uncommon", "rare"
  final String? description;
  final bool isSerious;

  SideEffect({
    required this.name,
    required this.frequency,
    this.description,
    this.isSerious = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'frequency': frequency,
    'description': description,
    'isSerious': isSerious,
  };

  factory SideEffect.fromJson(Map<String, dynamic> json) => SideEffect(
    name: json['name'] ?? '',
    frequency: json['frequency'] ?? 'uncommon',
    description: json['description'],
    isSerious: json['isSerious'] ?? false,
  );
}

/// Drug information from database
class DrugInfo {
  final String genericName;
  final List<String> brandNames;
  final String drugClass;
  final String? description;
  final List<String>? uses;
  final List<String>? warnings;
  final List<SideEffect>? sideEffects;
  final List<String>? contraindications;
  final String? pregnancyCategory;
  final bool? requiresPrescription;
  final String? storage;
  final String? halfLife;
  final List<String>? foodInteractions;

  DrugInfo({
    required this.genericName,
    required this.brandNames,
    required this.drugClass,
    this.description,
    this.uses,
    this.warnings,
    this.sideEffects,
    this.contraindications,
    this.pregnancyCategory,
    this.requiresPrescription,
    this.storage,
    this.halfLife,
    this.foodInteractions,
  });

  Map<String, dynamic> toJson() => {
    'genericName': genericName,
    'brandNames': brandNames,
    'drugClass': drugClass,
    'description': description,
    'uses': uses,
    'warnings': warnings,
    'sideEffects': sideEffects?.map((e) => e.toJson()).toList(),
    'contraindications': contraindications,
    'pregnancyCategory': pregnancyCategory,
    'requiresPrescription': requiresPrescription,
    'storage': storage,
    'halfLife': halfLife,
    'foodInteractions': foodInteractions,
  };

  factory DrugInfo.fromJson(Map<String, dynamic> json) => DrugInfo(
    genericName: json['genericName'] ?? '',
    brandNames: (json['brandNames'] as List?)?.cast<String>() ?? [],
    drugClass: json['drugClass'] ?? '',
    description: json['description'],
    uses: (json['uses'] as List?)?.cast<String>(),
    warnings: (json['warnings'] as List?)?.cast<String>(),
    sideEffects: (json['sideEffects'] as List?)?.map((e) => SideEffect.fromJson(e)).toList(),
    contraindications: (json['contraindications'] as List?)?.cast<String>(),
    pregnancyCategory: json['pregnancyCategory'],
    requiresPrescription: json['requiresPrescription'],
    storage: json['storage'],
    halfLife: json['halfLife'],
    foodInteractions: (json['foodInteractions'] as List?)?.cast<String>(),
  );
}

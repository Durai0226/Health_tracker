import 'package:hive/hive.dart';
import 'medicine_enums.dart';

part 'drug_interaction.g.dart';

/// Drug interaction information
@HiveType(typeId: 65)
class DrugInteraction extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String drug1Name;

  @HiveField(2)
  final String drug2Name;

  @HiveField(3)
  final InteractionSeverity severity;

  @HiveField(4)
  final String description;

  @HiveField(5)
  final String? recommendation;

  @HiveField(6)
  final String? mechanism;

  @HiveField(7)
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
@HiveType(typeId: 66)
class SideEffect extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String frequency; // "common", "uncommon", "rare"

  @HiveField(2)
  final String? description;

  @HiveField(3)
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
@HiveType(typeId: 67)
class DrugInfo extends HiveObject {
  @HiveField(0)
  final String genericName;

  @HiveField(1)
  final List<String> brandNames;

  @HiveField(2)
  final String drugClass;

  @HiveField(3)
  final String? description;

  @HiveField(4)
  final List<String>? uses;

  @HiveField(5)
  final List<String>? warnings;

  @HiveField(6)
  final List<SideEffect>? sideEffects;

  @HiveField(7)
  final List<String>? contraindications;

  @HiveField(8)
  final String? pregnancyCategory;

  @HiveField(9)
  final bool? requiresPrescription;

  @HiveField(10)
  final String? storage;

  @HiveField(11)
  final String? halfLife;

  @HiveField(12)
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

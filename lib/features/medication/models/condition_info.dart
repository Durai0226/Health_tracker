import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/widgets.dart' show IconData;

/// Broad grouping for the condition-resource library's browse list.
enum ConditionCategory {
  cardiovascular,
  endocrine,
  respiratory,
  mentalHealth,
  gastrointestinal,
  musculoskeletal,
  neurological,
  renal,
}

extension ConditionCategoryX on ConditionCategory {
  String get label {
    switch (this) {
      case ConditionCategory.cardiovascular:
        return 'Heart & circulation';
      case ConditionCategory.endocrine:
        return 'Endocrine & metabolic';
      case ConditionCategory.respiratory:
        return 'Respiratory';
      case ConditionCategory.mentalHealth:
        return 'Mental health';
      case ConditionCategory.gastrointestinal:
        return 'Digestive';
      case ConditionCategory.musculoskeletal:
        return 'Bones & joints';
      case ConditionCategory.neurological:
        return 'Neurological';
      case ConditionCategory.renal:
        return 'Kidney';
    }
  }

  IconData get icon {
    switch (this) {
      case ConditionCategory.cardiovascular:
        return Symbols.favorite_rounded;
      case ConditionCategory.endocrine:
        return Symbols.bloodtype_rounded;
      case ConditionCategory.respiratory:
        return Symbols.pulmonology_rounded;
      case ConditionCategory.mentalHealth:
        return Symbols.psychology_rounded;
      case ConditionCategory.gastrointestinal:
        return Symbols.gastroenterology_rounded;
      case ConditionCategory.musculoskeletal:
        return Symbols.orthopedics_rounded;
      case ConditionCategory.neurological:
        return Symbols.neurology_rounded;
      case ConditionCategory.renal:
        return Symbols.nephrology_rounded;
    }
  }
}

/// A curated, general-education reference entry for a common condition — NOT
/// diagnostic or treatment advice. See [ConditionInfo.disclaimer] and the
/// same framing already used by `DrugInteractionService`'s doc comments:
/// always positioned as a starting point for a conversation with a clinician,
/// never as a substitute for one.
class ConditionInfo {
  final String id;
  final String name;
  final ConditionCategory category;

  /// Alternate names/spellings the search box should also match against.
  final List<String> aliases;

  /// One or two plain-language sentences on what the condition is.
  final String overview;
  final List<String> commonSymptoms;
  final List<String> selfCareTips;

  /// Red-flag symptoms that warrant urgent/emergency care, not just a routine
  /// follow-up — kept short and concrete on purpose.
  final List<String> whenToSeekHelp;

  const ConditionInfo({
    required this.id,
    required this.name,
    required this.category,
    this.aliases = const [],
    required this.overview,
    required this.commonSymptoms,
    required this.selfCareTips,
    required this.whenToSeekHelp,
  });

  /// Whether [query] (already lowercased by the caller) matches this
  /// condition's name or any alias.
  bool matches(String query) {
    if (query.isEmpty) return true;
    if (name.toLowerCase().contains(query)) return true;
    return aliases.any((a) => a.toLowerCase().contains(query));
  }
}

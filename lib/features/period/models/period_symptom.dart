import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Broad grouping for the symptom picker.
enum SymptomCategory { physical, emotional, digestive, skin, other }

extension SymptomCategoryX on SymptomCategory {
  String get label {
    switch (this) {
      case SymptomCategory.physical:
        return 'Physical';
      case SymptomCategory.emotional:
        return 'Mood';
      case SymptomCategory.digestive:
        return 'Digestive';
      case SymptomCategory.skin:
        return 'Skin';
      case SymptomCategory.other:
        return 'Other';
    }
  }
}

/// One entry in the symptom catalogue. Persisted by [id] (a JSON string[] on the
/// day row), so ids are stable and must never change. The [icon] is a Material
/// Symbol rendered through the shared AppChip glyph slot (no emoji fallback).
class PeriodSymptom {
  final String id;
  final String label;
  final IconData icon;
  final SymptomCategory category;

  const PeriodSymptom({
    required this.id,
    required this.label,
    required this.icon,
    required this.category,
  });
}

/// The built-in symptom catalogue. Order groups by category for the picker.
const List<PeriodSymptom> defaultSymptoms = [
  // Physical — body/object glyphs
  PeriodSymptom(id: 'cramps', label: 'Cramps', icon: Symbols.compress_rounded, category: SymptomCategory.physical),
  PeriodSymptom(id: 'headache', label: 'Headache', icon: Symbols.neurology_rounded, category: SymptomCategory.physical),
  PeriodSymptom(id: 'backache', label: 'Back pain', icon: Symbols.orthopedics_rounded, category: SymptomCategory.physical),
  PeriodSymptom(id: 'tender_breasts', label: 'Tender breasts', icon: Symbols.self_care_rounded, category: SymptomCategory.physical),
  PeriodSymptom(id: 'fatigue', label: 'Fatigue', icon: Symbols.battery_low_rounded, category: SymptomCategory.physical),
  PeriodSymptom(id: 'cravings', label: 'Cravings', icon: Symbols.cookie_rounded, category: SymptomCategory.physical),
  PeriodSymptom(id: 'insomnia', label: 'Insomnia', icon: Symbols.bedtime_off_rounded, category: SymptomCategory.physical),

  // Emotional — sentiment_* family, cohering with the Mood face scale
  PeriodSymptom(id: 'mood_swings', label: 'Mood swings', icon: Symbols.theater_comedy_rounded, category: SymptomCategory.emotional),
  PeriodSymptom(id: 'anxious', label: 'Anxious', icon: Symbols.sentiment_stressed_rounded, category: SymptomCategory.emotional),
  PeriodSymptom(id: 'irritable', label: 'Irritable', icon: Symbols.sentiment_extremely_dissatisfied_rounded, category: SymptomCategory.emotional),
  PeriodSymptom(id: 'low_mood', label: 'Low mood', icon: Symbols.sentiment_sad_rounded, category: SymptomCategory.emotional),

  // Digestive
  PeriodSymptom(id: 'bloating', label: 'Bloating', icon: Symbols.expand_rounded, category: SymptomCategory.digestive),
  PeriodSymptom(id: 'nausea', label: 'Nausea', icon: Symbols.sick_rounded, category: SymptomCategory.digestive),

  // Skin
  PeriodSymptom(id: 'acne', label: 'Acne', icon: Symbols.dermatology_rounded, category: SymptomCategory.skin),

  // Other
  PeriodSymptom(id: 'discharge', label: 'Discharge', icon: Symbols.humidity_low_rounded, category: SymptomCategory.other),
  PeriodSymptom(id: 'high_energy', label: 'High energy', icon: Symbols.electric_bolt_rounded, category: SymptomCategory.other),
];

/// Lookup a catalogue entry by id (null when unknown / removed).
PeriodSymptom? symptomById(String id) {
  for (final s in defaultSymptoms) {
    if (s.id == id) return s;
  }
  return null;
}

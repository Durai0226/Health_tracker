import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// One curated, patient-friendly monograph for a generic drug. Deliberately
/// general and conservative (no doses/numbers) — it supplements, never
/// replaces, a doctor or pharmacist, and every answer is disclaimed upstream.
@immutable
class DrugInfo {
  final String generic;
  final String klass;
  final String uses;
  final String sideEffects;
  final String food;
  final String precautions;

  const DrugInfo({
    required this.generic,
    required this.klass,
    required this.uses,
    required this.sideEffects,
    required this.food,
    required this.precautions,
  });
}

/// A small, bundled, offline drug-information knowledge base keyed by generic
/// (active ingredient). Purely on-device (an asset) — no network — matching the
/// app's privacy-first stance and the RAG grounding model. It exists so common
/// "what is this for / side effects / with food?" questions get a real,
/// well-established, disclaimed answer instead of a generic "ask your
/// pharmacist" deflection. It is NOT exhaustive and NOT medical advice.
class DrugInfoCatalog {
  DrugInfoCatalog._();

  static Map<String, DrugInfo>? _byGeneric;

  static Future<void> ensureLoaded() async {
    if (_byGeneric != null) return;
    try {
      final raw = await rootBundle.loadString('assets/ai/drug_info.json');
      final list = jsonDecode(raw) as List;
      final map = <String, DrugInfo>{};
      for (final e in list) {
        if (e is Map && e['generic'] != null && e['uses'] != null) {
          final info = DrugInfo(
            generic: e['generic'].toString(),
            klass: (e['class'] ?? '').toString(),
            uses: (e['uses'] ?? '').toString(),
            sideEffects: (e['sideEffects'] ?? '').toString(),
            food: (e['food'] ?? '').toString(),
            precautions: (e['precautions'] ?? '').toString(),
          );
          map[info.generic.toLowerCase()] = info;
        }
      }
      _byGeneric = map;
    } catch (e) {
      debugPrint('⚠️ DrugInfoCatalog load failed: $e');
      _byGeneric = const {};
    }
  }

  static DrugInfo? _lookup(String? key) {
    if (_byGeneric == null || key == null) return null;
    final k = key.trim().toLowerCase();
    if (k.isEmpty) return null;
    return _byGeneric![k];
  }

  /// Answers [question] about a medicine from the curated monograph, or null
  /// when we have nothing (or shouldn't answer) — so the caller can fall back.
  /// [generic] is the active ingredient; [displayName] the name to show.
  /// Handles uses / side-effects / food / precautions / general questions; for
  /// a "missed dose" it returns null so the general (drug-agnostic) advice wins.
  static String? answer({
    required String question,
    String? generic,
    String? displayName,
  }) {
    final info = _lookup(generic) ?? _lookup(displayName);
    if (info == null) return null;

    final q = question.toLowerCase();
    final name = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : info.generic;
    final klass = info.klass.isNotEmpty ? ' — ${info.klass}' : '';

    // Missed-dose guidance is drug-agnostic and handled well elsewhere.
    if (RegExp(r'\b(miss|missed|forgot|skip)\b').hasMatch(q)) return null;

    if (RegExp(r'side.?effect|reaction|adverse').hasMatch(q)) {
      return '**$name — common side effects**\n\n${info.sideEffects}';
    }
    if (RegExp(r'\b(food|eat|meal|empty stomach|before|after)\b').hasMatch(q)) {
      return '**$name — with food?**\n\n${info.food}';
    }
    if (RegExp(r'precaution|warning|careful|avoid|interact|alcohol|pregnan|safe')
        .hasMatch(q)) {
      return '**$name — good to know**\n\n${info.precautions}';
    }
    if (RegExp(r'\b(what|why|for|purpose|used|use|treat|does|do|how)\b')
        .hasMatch(q)) {
      return '**$name**$klass\n\n${info.uses}';
    }

    // General question → a compact monograph.
    return '**$name**$klass\n\n${info.uses}\n\n'
        '**Good to know:** ${info.precautions}';
  }
}

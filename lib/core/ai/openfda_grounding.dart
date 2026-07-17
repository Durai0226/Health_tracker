import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Tier 3 (cloud opt-in): ground medicine Q&A in the FDA's official drug label
/// via the free, no-key openFDA API. The research is clear that a generative
/// model must NEVER be the authority on dosing/interactions — so when the user
/// has consented to network use, we answer from the authoritative label text
/// with a citation, falling back to the on-device engines otherwise.
///
/// Only the drug NAME leaves the device (not user PII), and only with consent.
/// URL-building + section selection are pure and unit-tested; the fetch degrades
/// to null on any failure so the app still answers offline.
class GroundedAnswer {
  /// Authoritative excerpt from the label.
  final String text;

  /// Human label for the section used (e.g. "Interactions").
  final String section;

  /// Source citation for display.
  final String source;

  const GroundedAnswer({
    required this.text,
    required this.section,
    required this.source,
  });
}

class OpenFdaGrounding {
  const OpenFdaGrounding._();

  static const String _base = 'https://api.fda.gov/drug/label.json';
  static const int _maxChars = 700;

  /// Build the openFDA query for a drug (searches brand OR generic name).
  static Uri buildQueryUrl(String drugName) {
    final q = drugName.trim().toLowerCase();
    final search =
        'openfda.brand_name:"$q" openfda.generic_name:"$q"'; // space = OR
    return Uri.parse(
        '$_base?search=${Uri.encodeQueryComponent(search)}&limit=1');
  }

  /// Choose the label section most relevant to the question.
  static String _sectionKeyFor(String question) {
    final q = question.toLowerCase();
    if (RegExp(r'\b(interact|together|combine|mix|with other)\b').hasMatch(q)) {
      return 'drug_interactions';
    }
    if (RegExp(r'\b(dose|dosage|how much|how many|take|administer)\b').hasMatch(q)) {
      return 'dosage_and_administration';
    }
    if (RegExp(r'\b(side effect|side-effect|reaction|adverse)\b').hasMatch(q)) {
      return 'adverse_reactions';
    }
    if (RegExp(r'\b(warning|caution|avoid|danger|risk|safe)\b').hasMatch(q)) {
      return 'warnings';
    }
    if (RegExp(r'\b(store|storage|keep|expire)\b').hasMatch(q)) {
      return 'storage_and_handling';
    }
    // Default: what it's for.
    return 'indications_and_usage';
  }

  static const Map<String, String> _sectionLabels = {
    'drug_interactions': 'Interactions',
    'dosage_and_administration': 'Dosage & administration',
    'adverse_reactions': 'Side effects',
    'warnings': 'Warnings',
    'storage_and_handling': 'Storage',
    'indications_and_usage': 'Uses',
  };

  /// Pure: pick and format the relevant section from an openFDA response.
  static GroundedAnswer? selectSection(
      Map<String, dynamic> responseJson, String question) {
    final results = responseJson['results'];
    if (results is! List || results.isEmpty) return null;
    final label = results.first;
    if (label is! Map) return null;

    final key = _sectionKeyFor(question);
    var text = _firstText(label[key]);
    var usedKey = key;
    // Fall back to indications/purpose if the chosen section is empty.
    if (text == null) {
      for (final fallback in const [
        'indications_and_usage',
        'purpose',
        'warnings'
      ]) {
        text = _firstText(label[fallback]);
        if (text != null) {
          usedKey = fallback;
          break;
        }
      }
    }
    if (text == null || text.trim().isEmpty) return null;

    return GroundedAnswer(
      text: _clip(text.trim(), _maxChars),
      section: _sectionLabels[usedKey] ?? 'Label',
      source: 'FDA label via openFDA',
    );
  }

  /// Fetch + ground. Returns null on any failure (offline, not found, error).
  static Future<GroundedAnswer?> fetch(
    String drugName,
    String question, {
    http.Client? client,
  }) async {
    if (drugName.trim().isEmpty) return null;
    final ownClient = client == null;
    final c = client ?? http.Client();
    try {
      final resp = await c
          .get(buildQueryUrl(drugName))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(resp.bodyBytes));
      if (json is! Map<String, dynamic>) return null;
      return selectSection(json, question);
    } catch (e) {
      debugPrint('OpenFdaGrounding: $e');
      return null;
    } finally {
      if (ownClient) c.close();
    }
  }

  static String? _firstText(dynamic section) {
    if (section is List && section.isNotEmpty) {
      final s = section.first?.toString();
      return (s != null && s.trim().isNotEmpty) ? s : null;
    }
    if (section is String && section.trim().isNotEmpty) return section;
    return null;
  }

  static String _clip(String s, int max) {
    if (s.length <= max) return s;
    final cut = s.substring(0, max);
    final lastStop = cut.lastIndexOf('. ');
    return (lastStop > max ~/ 2 ? cut.substring(0, lastStop + 1) : cut) + ' …';
  }
}

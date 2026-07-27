import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/medicine_enums.dart';

/// One suggestible drug: a display [name] (brand or generic), its [generic]
/// (active ingredient), and the typical dosage [form]. Selecting a suggestion
/// can pre-fill the generic (which powers the disclaimed interaction reference
/// checks) and auto-select the [form] (tablet / drops / cream / …) so the user
/// doesn't have to pick it manually.
@immutable
class DrugNameEntry {
  final String name;
  final String generic;

  /// Typical dosage form for this medicine, when known. Null for older entries
  /// that predate the form column (kept backward-compatible).
  final DosageForm? form;

  const DrugNameEntry({required this.name, required this.generic, this.form});
}

/// A small, bundled, offline drug-name catalog for typeahead on the add-medicine
/// name field. Purely on-device (an asset) — no network, matching the app's
/// privacy-first stance. Deliberately a curated common-meds seed, not an
/// exhaustive database; it exists to reduce setup friction, not to be complete.
class DrugNameCatalog {
  DrugNameCatalog._();

  static List<DrugNameEntry>? _entries;

  static Future<void> ensureLoaded() async {
    if (_entries != null) return;
    try {
      final raw = await rootBundle.loadString('assets/data/drug_names.json');
      final list = jsonDecode(raw) as List;
      _entries = [
        for (final e in list)
          if (e is Map && e['name'] != null && e['generic'] != null)
            DrugNameEntry(
                name: e['name'].toString(),
                generic: e['generic'].toString(),
                form: _formFromName(e['form']))
      ];
    } catch (e) {
      debugPrint('⚠️ DrugNameCatalog load failed: $e');
      _entries = const [];
    }
  }

  /// Maps a JSON `form` string (an enum name like "drops"/"cream") to a
  /// [DosageForm]. Returns null for unknown/absent values so old entries and
  /// unrecognised forms degrade gracefully rather than breaking the load.
  static DosageForm? _formFromName(dynamic raw) {
    if (raw is! String) return null;
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return null;
    for (final f in DosageForm.values) {
      if (f.name == v) return f;
    }
    return null;
  }

  /// Resolve a display/brand name to its generic (active ingredient) via an
  /// exact, case-insensitive match, e.g. "Dolo 650" → "Paracetamol". Returns
  /// null when unknown. Used to bridge a brand to a drug monograph.
  static String? genericFor(String name) {
    if (_entries == null) return null;
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return null;
    for (final e in _entries!) {
      if (e.name.toLowerCase() == n) return e.generic;
    }
    return null;
  }

  /// Up to [limit] suggestions matching [query] against the display name OR the
  /// generic. Prefix matches rank above contains-matches; empty query → none.
  static List<DrugNameEntry> suggest(String query, {int limit = 5}) {
    final q = query.trim().toLowerCase();
    if (q.length < 2 || _entries == null) return const [];
    final prefix = <DrugNameEntry>[];
    final contains = <DrugNameEntry>[];
    for (final e in _entries!) {
      final n = e.name.toLowerCase();
      final g = e.generic.toLowerCase();
      if (n == q) continue; // already typed exactly — nothing to suggest
      if (n.startsWith(q) || g.startsWith(q)) {
        prefix.add(e);
      } else if (n.contains(q) || g.contains(q)) {
        contains.add(e);
      }
    }
    // De-dupe by name while preserving prefix-first order.
    final seen = <String>{};
    final out = <DrugNameEntry>[];
    for (final e in [...prefix, ...contains]) {
      if (seen.add(e.name.toLowerCase())) out.add(e);
      if (out.length >= limit) break;
    }
    return out;
  }
}

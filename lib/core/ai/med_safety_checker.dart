/// Pure-Dart medication safety checks over data the app already holds — no
/// network, no model. Two high-signal, low-cost checks the research flagged as
/// higher value than a full drug-drug matrix (which needs a licensed DB):
///  1. Drug–allergy conflict: a med matches a stored allergy.
///  2. Duplicate therapy: two active meds share the same active ingredient
///     (same generic), an easy way to double-dose by accident.
///
/// Deliberately conservative on matching to avoid false alarms, and always
/// framed as "check with your pharmacist", never as a complete safety check.
class MedSafetyWarning {
  /// 'allergy' | 'duplicate'
  final String kind;

  /// 'high' | 'medium'
  final String severity;
  final String message;

  const MedSafetyWarning({
    required this.kind,
    required this.severity,
    required this.message,
  });
}

/// Minimal med reference so this stays decoupled from the feature model.
class MedRef {
  final String id;
  final String name;
  final String? genericName;
  const MedRef({required this.id, required this.name, this.genericName});
}

class MedSafetyChecker {
  const MedSafetyChecker._();

  /// Flags when [name]/[genericName] plausibly matches any of the user's stored
  /// [allergies]. Matching is token-based with a length floor so short/common
  /// fragments don't cause false alarms.
  static List<MedSafetyWarning> checkAllergies({
    required String name,
    String? genericName,
    required List<String> allergies,
  }) {
    final out = <MedSafetyWarning>[];
    final medTokens = {
      ..._tokens(name),
      if (genericName != null) ..._tokens(genericName),
    };
    if (medTokens.isEmpty) return out;
    final seen = <String>{};
    for (final raw in allergies) {
      final allergyTokens = _tokens(raw);
      for (final a in allergyTokens) {
        if (a.length < 4) continue;
        final hit = medTokens.any((m) =>
            m == a ||
            (a.length >= 5 && m.contains(a)) ||
            (m.length >= 5 && a.contains(m)));
        if (hit && seen.add(raw.trim().toLowerCase())) {
          out.add(MedSafetyWarning(
            kind: 'allergy',
            severity: 'high',
            message:
                '$name may conflict with your recorded allergy "${raw.trim()}". '
                'Confirm with your pharmacist or doctor before taking it.',
          ));
          break;
        }
      }
    }
    return out;
  }

  /// Flags pairs of active meds that share the same active ingredient (generic),
  /// or the same normalized name — a common accidental double-dose.
  static List<MedSafetyWarning> checkDuplicates(List<MedRef> meds) {
    final out = <MedSafetyWarning>[];
    final byKey = <String, List<MedRef>>{};
    for (final m in meds) {
      // Prefer the generic (active ingredient); fall back to the display name.
      final g = _norm(m.genericName ?? '');
      final key = g.isNotEmpty ? g : _norm(m.name);
      if (key.isEmpty) continue;
      byKey.putIfAbsent(key, () => []).add(m);
    }
    for (final entry in byKey.entries) {
      // Distinct medicines (by id) that resolve to the same ingredient.
      final distinct = <String, MedRef>{};
      for (final m in entry.value) {
        distinct[m.id] = m;
      }
      if (distinct.length < 2) continue;
      final names = distinct.values.map((m) => m.name).toSet().toList();
      out.add(MedSafetyWarning(
        kind: 'duplicate',
        severity: 'medium',
        message:
            '${names.join(' and ')} appear to share the same active ingredient. '
            'Taking both could double your dose — check with your pharmacist.',
      ));
    }
    return out;
  }

  /// Combined convenience: allergy + duplicate warnings for a target med within
  /// the user's full active list.
  static List<MedSafetyWarning> checkAll({
    required MedRef target,
    required List<MedRef> activeMeds,
    List<String> allergies = const [],
  }) {
    return [
      ...checkAllergies(
        name: target.name,
        genericName: target.genericName,
        allergies: allergies,
      ),
      ...checkDuplicates(activeMeds),
    ];
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').trim();

  static Set<String> _tokens(String s) => _norm(s)
      .split(RegExp(r'\s+'))
      .where((t) => t.length >= 3)
      .toSet();
}

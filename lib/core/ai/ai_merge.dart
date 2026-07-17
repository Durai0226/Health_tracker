import 'ai_types.dart';

/// Merge + validate an LLM's structured output against our own schema, using the
/// deterministic rule-engine result as the SAFE baseline. This is what makes the
/// generative tiers (on-device LLM / cloud) both useful and safe: the LLM can
/// handle messy free text, but it can never inject an out-of-schema value or
/// wipe a field the rules already parsed correctly. Pure functions → fully
/// unit-testable without any engine or network.
class AiMerge {
  const AiMerge._();

  static const _repeats = {
    'none', 'daily', 'weekly', 'weekdays', 'weekends', 'custom'
  };
  static const _priorities = {'low', 'medium', 'high'};
  static const _frequencies = {
    'once daily',
    'twice daily',
    'thrice daily',
    'four times daily',
    'asNeeded',
    'everyXHours',
  };

  /// Overlay validated LLM fields onto the rule-engine [base].
  static ParsedReminder mergeReminder({
    required ParsedReminder base,
    required Map<String, dynamic> llm,
  }) {
    final title = _str(llm['title']);
    final repeat = _oneOf(_str(llm['repeat'])?.toLowerCase(), _repeats) ?? base.repeat;
    final priority =
        _oneOf(_str(llm['priority'])?.toLowerCase(), _priorities) ?? base.priority;
    // Keep the rule engine's date when the LLM's is missing/unparseable — the
    // rules have solid relative/absolute date logic.
    final time = DateTime.tryParse(_str(llm['datetimeIso']) ?? '') ?? base.time;
    final cat = _str(llm['category']);

    return ParsedReminder(
      title: (title != null && title.isNotEmpty) ? title : base.title,
      time: time,
      repeat: repeat,
      priority: priority,
      categoryHint: (cat != null && cat.isNotEmpty) ? cat : base.categoryHint,
      customDays: base.customDays, // rules own multi-day detection
      durationMinutes: base.durationMinutes,
    );
  }

  /// Overlay validated LLM fields onto the rule-engine medicine [base] map.
  static Map<String, dynamic> mergeMedicine({
    required Map<String, dynamic> base,
    required Map<String, dynamic> llm,
  }) {
    final out = Map<String, dynamic>.from(base);

    final name = _str(llm['name']);
    if (name != null && name.isNotEmpty) out['name'] = name;

    final amt = _num(llm['dosageAmount']);
    if (amt != null && amt > 0) out['dosageAmount'] = amt;

    final unit = _str(llm['dosageUnit']);
    if (unit != null && unit.isNotEmpty) out['dosageUnit'] = unit;

    final form = _str(llm['form']);
    if (form != null && form.isNotEmpty) out['form'] = form;

    final freq = _canonFrequency(_str(llm['frequency']));
    if (freq != null) out['frequency'] = freq;

    final iv = _int(llm['intervalHours']);
    if (iv != null && iv > 0) out['intervalHours'] = iv;

    final times = _times(llm['times']);
    if (times.isNotEmpty) out['times'] = times;

    return out;
  }

  // ---- validators ----------------------------------------------------------

  static String? _oneOf(String? v, Set<String> allowed) =>
      (v != null && allowed.contains(v)) ? v : null;

  /// Map a free-form frequency to our canonical value (case/spacing-insensitive).
  static String? _canonFrequency(String? raw) {
    if (raw == null) return null;
    final v = raw.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    for (final f in _frequencies) {
      if (f.toLowerCase().replaceAll(' ', '') == v) return f;
    }
    // Common paraphrases.
    if (v == 'daily' || v == 'oncedaily' || v == 'qd') return 'once daily';
    if (v == 'bid') return 'twice daily';
    if (v == 'tid') return 'thrice daily';
    if (v == 'qid') return 'four times daily';
    if (v == 'prn' || v == 'asneeded') return 'asNeeded';
    if (v.contains('hour')) return 'everyXHours';
    return null;
  }

  /// Validate a list of "HH:mm" strings; drop anything malformed.
  static List<String> _times(dynamic raw) {
    if (raw is! List) return const [];
    final out = <String>[];
    final re = RegExp(r'^(\d{1,2}):(\d{2})$');
    for (final e in raw) {
      final s = e?.toString().trim() ?? '';
      final m = re.firstMatch(s);
      if (m == null) continue;
      final h = int.parse(m.group(1)!);
      final min = int.parse(m.group(2)!);
      if (h <= 23 && min <= 59) {
        out.add('${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}');
      }
    }
    return out.toSet().toList()..sort();
  }

  static String? _str(dynamic v) => v?.toString();
  static num? _num(dynamic v) =>
      v is num ? v : (v is String ? num.tryParse(v.trim()) : null);
  static int? _int(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse(v?.toString() ?? ''));
}

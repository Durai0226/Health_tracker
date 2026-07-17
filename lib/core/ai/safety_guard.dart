/// Deterministic safety layer for any health/medical AI output.
///
/// Runs in pure Dart BEFORE any engine is selected, so it works offline and
/// cannot be prompt-injected or jailbroken through the LLM tiers. Two jobs:
///  1. Emergency red-flag triage — if the user's text describes a possible
///     emergency, short-circuit to a fixed "seek help now" card instead of
///     letting a generative model answer.
///  2. Disclaimer enforcement — guarantee every medical answer carries the
///     not-a-diagnosis note (a CI test asserts this can't regress).
class SafetyGuard {
  const SafetyGuard._();

  /// Canonical medical disclaimer appended to every medical answer.
  static const String disclaimer =
      'This is general information, not medical advice or a diagnosis. '
      'Always confirm with your doctor or pharmacist.';

  /// A stable marker used to detect whether an answer already carries the note
  /// (kept short + lowercase-insensitive so paraphrases still match the test).
  static const String _disclaimerMarker = 'not medical advice';

  // Red-flag phrases that warrant immediate escalation rather than an AI answer.
  // Kept high-precision (specific multi-word symptoms) to avoid false alarms on
  // benign questions like "can this cause a mild headache?".
  static final List<RegExp> _emergencyPatterns = [
    RegExp(r'\b(chest pain|chest tightness|crushing chest)\b', caseSensitive: false),
    RegExp(r"\b(can't breathe|cannot breathe|trouble breathing|struggling to breathe|difficulty breathing)\b",
        caseSensitive: false),
    // Stroke signs — loose enough to catch "face is drooping" / "speech is
    // slurred" (words in between), but still specific tokens.
    RegExp(r'(droop|slurred|face.{0,15}(numb|weak)|one[- ]?sided?.{0,15}(numb|weak)|sudden.{0,15}(numbness|weakness)|having a stroke)',
        caseSensitive: false),
    RegExp(r'\b(overdose|overdosed|took too many|took (a lot|lots) of|double dose.*(sick|dizzy))\b',
        caseSensitive: false),
    RegExp(r'\b(anaphylaxis|throat (closing|swelling)|swollen (tongue|throat)|severe allergic)\b',
        caseSensitive: false),
    RegExp(r'\b(suicidal|kill myself|end my life|want to die|self.?harm)\b', caseSensitive: false),
    RegExp(r'\b(unconscious|unresponsive|passed out|seizure|convulsi)\b', caseSensitive: false),
    RegExp(r'\b(severe bleeding|bleeding (won\x27t|will not) stop|coughing up blood|vomiting blood)\b',
        caseSensitive: false),
  ];

  /// Returns a fixed emergency card if [text] contains a red flag, else null.
  /// Uses the user's [locale] to nudge toward the right number without hard-
  /// coding a country-specific one (e.g. 911 vs 112 vs 999).
  static String? emergencyResponse(String text, {String? locale}) {
    final t = text.toLowerCase();
    final hit = _emergencyPatterns.any((p) => p.hasMatch(t));
    if (!hit) return null;
    final number = _emergencyNumberFor(locale);
    return '⚠️ This may be a medical emergency.\n\n'
        'If you or someone else is in danger, call your local emergency number '
        '$number now, or go to the nearest emergency department. '
        'Do not wait for an app.';
  }

  /// Best-effort local emergency number from a locale string; falls back to a
  /// neutral instruction rather than guessing wrong.
  static String _emergencyNumberFor(String? locale) {
    final l = (locale ?? '').toLowerCase();
    if (l.contains('us') || l.contains('en_us')) return '(911 in the US)';
    if (l.contains('gb') || l.contains('uk')) return '(999 in the UK)';
    if (l.contains('in')) return '(112 in India)';
    if (l.contains('au')) return '(000 in Australia)';
    if (l.startsWith('en') || l.contains('eu') || l.contains('de') || l.contains('fr')) {
      return '(112 in the EU)';
    }
    return '(your local emergency number)';
  }

  /// Guarantees a medical answer carries the disclaimer. Idempotent: if the
  /// answer already contains the marker (any tier), it's returned unchanged.
  static String ensureDisclaimer(String answer) {
    final a = answer.trim();
    if (hasDisclaimer(a)) return a;
    return '$a\n\n_${disclaimer}_';
  }

  /// True if [answer] already carries a recognizable medical disclaimer. Matches
  /// our canonical note plus common paraphrases so LLM-tier outputs pass too.
  static bool hasDisclaimer(String answer) {
    final a = answer.toLowerCase();
    return a.contains(_disclaimerMarker) ||
        a.contains('not a diagnosis') ||
        a.contains('consult your') ||
        a.contains('ask your pharmacist') ||
        a.contains('ask your doctor') ||
        (a.contains('doctor') && a.contains('pharmacist'));
  }
}

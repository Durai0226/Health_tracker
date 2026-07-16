/// Neutral result types for the AI facade — deliberately free of feature-layer
/// model imports so `lib/core/ai/` stays decoupled. Feature screens map these
/// simple string/enum-string fields onto their own enums.

class ParsedReminder {
  final String title;
  final DateTime? time;

  /// One of: none | daily | weekly | weekdays | weekends
  final String repeat;

  /// One of: low | medium | high
  final String priority;

  /// A best-effort category name hint (e.g. 'Health', 'Work') or null.
  final String? categoryHint;

  const ParsedReminder({
    required this.title,
    this.time,
    this.repeat = 'none',
    this.priority = 'medium',
    this.categoryHint,
  });
}

/// Which tier answered — surfaced for diagnostics/UX ("on-device" vs "cloud").
enum AiEngineKind { ruleBased, onDevice, cloud }

/// User preference for which engine to prefer.
enum AiEnginePreference { auto, localOnly, onDevice, cloud }

AiEnginePreference aiEnginePreferenceFromString(String? s) {
  switch (s) {
    case 'localOnly':
      return AiEnginePreference.localOnly;
    case 'onDevice':
      return AiEnginePreference.onDevice;
    case 'cloud':
      return AiEnginePreference.cloud;
    default:
      return AiEnginePreference.auto;
  }
}

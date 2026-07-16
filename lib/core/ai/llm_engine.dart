/// Contract for a generative LLM engine (cloud proxy or on-device model).
///
/// The rule-based engine does NOT implement this — it is deterministic Dart with
/// intent-specific methods. Only real generative backends implement [LlmEngine]
/// so [AiAssistant] can treat cloud and on-device models interchangeably and
/// always fall back to the rule engine.
abstract class LlmEngine {
  /// Stable id for diagnostics / preferences ('cloud', 'on_device').
  String get id;

  /// Whether this engine can serve requests right now (configured + allowed).
  bool get isAvailable;

  /// Free-form text completion. Returns null on any failure.
  Future<String?> completeText({
    required String system,
    required String user,
    double temperature = 0.3,
    int maxTokens = 512,
  });

  /// Structured completion → parsed JSON object. Returns null on any failure.
  Future<Map<String, dynamic>?> completeJson({
    required String system,
    required String user,
    int maxTokens = 512,
  });
}

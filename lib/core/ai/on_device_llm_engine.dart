import 'llm_engine.dart';

/// On-device LLM tier (Phase B) — the free, offline, private generative engine.
///
/// This is the build-safe SLOT: it implements [LlmEngine] and is wired into
/// [AiAssistant.onDeviceEngine], but reports `isAvailable == false` until a real
/// runtime is attached, so the app keeps running on the rule engine with zero
/// behavior change and no heavy dependency in the build.
///
/// To ACTIVATE (see lib/core/ai/ON_DEVICE_LLM.md for the full guide):
///  1. Add `flutter_gemma` (or Apple Foundation Models) to pubspec.
///  2. In [init], download/attach a small int4 model (e.g. gemma3-1B-it) and set
///     [_ready] = true when the session is created.
///  3. Implement [completeText]/[completeJson] via the model session, running
///     OFF the main isolate. Keep JSON parsing tolerant (strip fences, extract
///     the outer object) — [AiMerge] then validates the result against our
///     schema, so a messy generation can never produce out-of-schema data.
///
/// Availability is intentionally conservative: only capable mobile hardware with
/// a downloaded model should flip [isAvailable] true; web/simulator/low-RAM stay
/// on the rule engine.
class OnDeviceLlmEngine implements LlmEngine {
  OnDeviceLlmEngine();

  bool _ready = false;

  @override
  String get id => 'on_device';

  @override
  bool get isAvailable => _ready;

  /// Attach a model runtime. No-op until the native backend is added; returns
  /// false so callers can decide whether to offer the download.
  Future<bool> init() async {
    // TODO(phase-b): create the flutter_gemma model + session here, then
    // `_ready = true;`. Kept inert so the shipping build stays green + free.
    _ready = false;
    return _ready;
  }

  Future<void> dispose() async {
    _ready = false;
  }

  @override
  Future<String?> completeText({
    required String system,
    required String user,
    double temperature = 0.3,
    int maxTokens = 512,
  }) async {
    if (!_ready) return null; // → AiAssistant falls back to the rule engine
    // TODO(phase-b): run the model session and return its text.
    return null;
  }

  @override
  Future<Map<String, dynamic>?> completeJson({
    required String system,
    required String user,
    int maxTokens = 512,
  }) async {
    if (!_ready) return null;
    // TODO(phase-b): prompt for JSON, tolerantly extract the object, return it.
    // AiMerge validates it against our schema before use.
    return null;
  }
}

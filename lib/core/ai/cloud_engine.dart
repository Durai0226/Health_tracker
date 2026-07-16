import 'package:flutter/foundation.dart';
import '../services/llm_service.dart';
import 'llm_engine.dart';

/// Cloud LLM engine — proxy-ready and production-safe.
///
/// Production must NOT ship a provider key in the client. This engine is only
/// [isAvailable] when either:
///   * a managed backend proxy is configured (Phase C — key held server-side), OR
///   * the build is a DEBUG build with a pasted key (developer testing only).
///
/// In a release build with no proxy, the cloud tier stays OFF and the app runs
/// fully on-device. It delegates the actual HTTP to the existing [LlmService]
/// (OpenAI-compatible), so pointing at a proxy later is a config change only.
class CloudEngine implements LlmEngine {
  @override
  String get id => 'cloud';

  @override
  bool get isAvailable {
    // Production-safe: available whenever a managed proxy is deployed (key is
    // server-side). Otherwise (dev), only in DEBUG builds with a pasted key —
    // never ship a client key in release.
    if (LlmService().usesProxy) return true;
    return LlmService().isConfigured && kDebugMode;
  }

  @override
  Future<String?> completeText({
    required String system,
    required String user,
    double temperature = 0.3,
    int maxTokens = 512,
  }) {
    return LlmService().completeText(
      system: system,
      user: user,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  @override
  Future<Map<String, dynamic>?> completeJson({
    required String system,
    required String user,
    int maxTokens = 512,
  }) {
    return LlmService().completeJson(
      system: system,
      user: user,
      maxTokens: maxTokens,
    );
  }
}

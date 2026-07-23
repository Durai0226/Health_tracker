import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/core/model.dart' show ModelType;
import 'package:flutter_gemma/flutter_gemma.dart';

import 'llm_engine.dart';

/// On-device LLM tier — the free, offline, private generative engine, backed by
/// `flutter_gemma` (MediaPipe LLM Inference). It phrases answers from the
/// retrieved KB context supplied by [AiAssistant.groundedAnswer]; it is NEVER
/// asked to free-associate on health data.
///
/// Opt-in + conservatively gated:
///  • Mobile only (never web/desktop).
///  • Inert until a model is downloaded AND [init] succeeds — so the shipping
///    build stays free, small, and on the rule engine by default. Web / low-end
///    / no-model devices keep using the deterministic engine with zero change.
///  • Every native call is guarded; any failure returns null so [AiAssistant]
///    falls back to the rule engine. A generation can never crash the app.
///
/// Activation flow (from Settings → "On-device AI"):
///  1. [downloadModel] pulls a small int4 `.task` model (progress stream).
///  2. [init] creates the model session and flips [isAvailable] true.
///  3. [completeText] runs a one-shot grounded generation per request.
class OnDeviceLlmEngine implements LlmEngine {
  OnDeviceLlmEngine();

  InferenceModel? _model;
  bool _ready = false;

  /// Context window for the small model. Kept modest to bound memory/latency.
  static const int _maxTokens = 1024;

  @override
  String get id => 'on_device';

  @override
  bool get isAvailable => _ready;

  /// Android-only: the on-device model tier is excluded from the iOS build (see
  /// third_party/flutter_gemma — iOS stripped so the app keeps its iOS 13
  /// minimum). iOS uses the rule + cloud tiers.
  static bool get isSupportedPlatform => !kIsWeb && Platform.isAndroid;

  /// Whether a model file is already installed on this device.
  Future<bool> isModelInstalled() async {
    if (!isSupportedPlatform) return false;
    try {
      return await FlutterGemmaPlugin.instance.modelManager.isModelInstalled;
    } catch (_) {
      return false;
    }
  }

  /// Downloads the model with progress (0–100). The [url] must point at a
  /// MediaPipe-compatible `.task` model (e.g. a Gemma int4 build). Caller is
  /// responsible for consent + network/metered warnings.
  Stream<int> downloadModel(String url) {
    if (!isSupportedPlatform) return const Stream.empty();
    return FlutterGemmaPlugin.instance.modelManager
        .downloadModelFromNetworkWithProgress(url);
  }

  /// Removes the downloaded model and releases the session.
  Future<void> deleteModel() async {
    await dispose();
    try {
      // Reset the path so the plugin reports "not installed".
      await FlutterGemmaPlugin.instance.modelManager.setModelPath('');
    } catch (_) {}
  }

  /// Attaches the model runtime if a model is installed. Returns whether the
  /// engine is now available. Safe + idempotent; never throws.
  Future<bool> init() async {
    if (_ready) return true;
    if (!isSupportedPlatform) return false;
    try {
      if (!await isModelInstalled()) {
        _ready = false;
        return false;
      }
      _model = await FlutterGemmaPlugin.instance.createModel(
        modelType: ModelType.gemmaIt,
        maxTokens: _maxTokens,
      );
      _ready = _model != null;
      if (_ready) debugPrint('✓ On-device LLM ready');
      return _ready;
    } catch (e) {
      debugPrint('⚠️ On-device LLM init failed: $e');
      _ready = false;
      return false;
    }
  }

  Future<void> dispose() async {
    _ready = false;
    try {
      await _model?.close();
    } catch (_) {}
    _model = null;
  }

  @override
  Future<String?> completeText({
    required String system,
    required String user,
    double temperature = 0.3,
    int maxTokens = 512,
  }) async {
    if (!_ready || _model == null) return null; // → rule-engine fallback
    InferenceModelSession? session;
    try {
      session = await _model!.createSession(temperature: temperature, topK: 40);
      // groundedAnswer already builds a CONTEXT-only, refuse-if-absent prompt in
      // [system]; combine it with the question as a single instruction turn.
      await session.addQueryChunk(Message(text: '$system\n\n$user', isUser: true));
      final out = await session.getResponse();
      return out.trim().isEmpty ? null : out.trim();
    } catch (e) {
      debugPrint('⚠️ On-device generation failed: $e');
      return null;
    } finally {
      try {
        await session?.close();
      } catch (_) {}
    }
  }

  @override
  Future<Map<String, dynamic>?> completeJson({
    required String system,
    required String user,
    int maxTokens = 512,
  }) async {
    // The small on-device model is used only for grounded free-text answers;
    // structured extraction stays on the cloud/rule tiers (AiMerge validates
    // those). Returning null keeps the on-device tail text-only + safe.
    return null;
  }
}

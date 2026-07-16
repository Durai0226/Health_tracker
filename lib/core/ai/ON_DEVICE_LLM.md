# Phase B — On-device LLM (flutter_gemma) activation guide

The AI architecture is **ready** for an on-device generative model: `AiAssistant`
already has an `onDeviceEngine` slot and prefers it (private, free) over cloud.
Turning it on is the steps below. It is intentionally NOT enabled in the default
build because it requires **iOS 16+**, native **MediaPipe** pods (bleeding-edge
Xcode compatibility risk), a **~0.5 GB model download**, and can only be
validated on a **physical device** (the iOS Simulator can't run MediaPipe LLM
inference). Rule-based + cloud tiers already cover all features for free.

## 1. Dependencies
```yaml
dependencies:
  flutter_gemma: ^1.3.0
  flutter_gemma_mediapipe: ^latest   # native runtime for .task models (Android/iOS)
```

## 2. iOS config
- `ios/Podfile`: bump `platform :ios, '16.0'` (currently 13.0). Keep
  `use_frameworks! :linkage => :static` (already set).
- `ios/Runner/Info.plist`: add `UIFileSharingEnabled = true`,
  `NSLocalNetworkUsageDescription = "…"`.
- `ios/Runner/Runner.entitlements`: add
  `com.apple.developer.kernel.increased-memory-limit = true` and
  `com.apple.developer.kernel.extended-virtual-addressing = true`.
- Android: `minSdk 26+`, arm64 device for `.litertlm` (`.task` works broadly).

## 3. Engine implementation — create `lib/core/ai/on_device_llm_engine.dart`
```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'llm_engine.dart';

/// On-device generative engine (free, offline, private). Available only after a
/// model is installed on a supported mobile device.
class OnDeviceLlmEngine implements LlmEngine {
  @override String get id => 'on_device';

  static const String modelName = 'gemma3-1B-it-int4';
  static const String modelUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task';

  bool _ready = false;
  InferenceModel? _model;

  @override
  bool get isAvailable =>
      _ready && (defaultTargetPlatform == TargetPlatform.android ||
                 defaultTargetPlatform == TargetPlatform.iOS) &&
      !kIsWeb;

  /// Call once at startup after checking the model is installed.
  Future<void> init() async {
    try {
      final mgr = FlutterGemmaPlugin.instance.modelManager;
      final spec = InferenceModelSpec(name: modelName, modelUrl: modelUrl);
      if (await mgr.isModelInstalled(spec)) {
        _model = await FlutterGemmaPlugin.instance
            .createModel(modelType: ModelType.gemmaIt, maxTokens: 1024);
        _ready = _model != null;
      }
    } catch (e) {
      debugPrint('OnDeviceLlmEngine.init: $e');
    }
  }

  /// Download + install the model (call from the Settings "Download" button).
  Stream<int> download() {
    final mgr = FlutterGemmaPlugin.instance.modelManager;
    final spec = InferenceModelSpec(name: modelName, modelUrl: modelUrl);
    return mgr.downloadModelFromNetworkWithProgress(spec); // % progress
  }

  Future<String?> _run(String system, String user) async {
    if (!isAvailable) return null;
    try {
      final chat = await _model!.createChat(modelType: ModelType.gemmaIt);
      await chat.addQueryChunk(Message(text: '$system\n\n$user', isUser: true));
      final res = await chat.generateChatResponse();
      return res is TextResponse ? res.token : res.toString();
    } catch (e) {
      debugPrint('OnDeviceLlmEngine._run: $e');
      return null;
    }
  }

  @override
  Future<String?> completeText(
          {required String system, required String user,
           double temperature = 0.3, int maxTokens = 512}) =>
      _run(system, user);

  @override
  Future<Map<String, dynamic>?> completeJson(
      {required String system, required String user, int maxTokens = 512}) async {
    final raw = await _run(
        '$system\nRespond with ONLY one minified JSON object.', user);
    if (raw == null) return null;
    try {
      final s = raw.substring(raw.indexOf('{'), raw.lastIndexOf('}') + 1);
      final d = jsonDecode(s);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) { return null; }
  }
}
```
*(Verify method names against the installed flutter_gemma version — the download
helper is on `FlutterGemmaPlugin.instance.modelManager`; `TextResponse.token`
holds the text.)*

## 4. Wire it in
- `main.dart`: `FlutterGemma.initialize(inferenceEngines: const [MediaPipeEngine()]);`
  then `final od = OnDeviceLlmEngine(); await od.init(); AiAssistant().onDeviceEngine = od;`
- Settings → AI Assistant: add a "Download offline AI (~0.5 GB)" button that
  listens to `OnDeviceLlmEngine.download()` for progress, then `await od.init()`.
- No other changes — `AiAssistant` already routes to `onDeviceEngine` when
  available and preferred, and falls back to rule-based otherwise.

## 5. Test on a real device
`flutter run -d <device>` → Settings → download model → try Reminders Smart-Add /
Medicine Ask-AI offline. The Simulator will keep using rule-based/cloud.

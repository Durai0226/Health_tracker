import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/secure_storage_helper.dart';

/// Provider-agnostic LLM client over an OpenAI-compatible Chat Completions API.
///
/// Defaults to NVIDIA's free hosted endpoint (build.nvidia.com / NIM). Because
/// the API is OpenAI-compatible, switching to another provider (e.g. Google
/// Gemini's OpenAI-compatible endpoint) for production is a config change via
/// [configureProvider] — no call-site changes.
///
/// Every method degrades gracefully: if there's no API key, no network, or a
/// bad response, it returns null and the caller falls back to the manual flow.
/// The app is fully usable without an AI key.
class LlmService {
  LlmService._();
  static final LlmService _instance = LlmService._();
  factory LlmService() => _instance;

  // Default provider = NVIDIA free (dev/beta). Swap via configureProvider().
  static const String defaultBaseUrl = 'https://integrate.api.nvidia.com/v1';
  static const String defaultModel = 'meta/llama-3.1-8b-instruct';

  String _baseUrl = defaultBaseUrl;
  String _model = defaultModel;
  // A --dart-define=LLM_API_KEY=... acts as a CLI fallback for the on-device key.
  String _apiKey = const String.fromEnvironment('LLM_API_KEY', defaultValue: '');

  bool get isConfigured => _apiKey.trim().isNotEmpty;
  String get model => _model;
  String get baseUrl => _baseUrl;

  /// Load the on-device saved key (call once at startup).
  Future<void> init() async {
    try {
      final saved = await SecureStorageHelper.getLlmApiKey();
      if (saved != null && saved.trim().isNotEmpty) _apiKey = saved.trim();
    } catch (e) {
      debugPrint('LlmService.init: $e');
    }
  }

  /// Persist + apply a new API key (from the Settings screen).
  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    try {
      await SecureStorageHelper.setLlmApiKey(_apiKey);
    } catch (e) {
      debugPrint('LlmService.setApiKey: $e');
    }
  }

  Future<void> clearApiKey() async {
    _apiKey = '';
    try {
      await SecureStorageHelper.clearLlmApiKey();
    } catch (_) {}
  }

  /// Point at a different OpenAI-compatible provider (e.g. for production).
  void configureProvider({String? baseUrl, String? model}) {
    if (baseUrl != null && baseUrl.isNotEmpty) _baseUrl = baseUrl;
    if (model != null && model.isNotEmpty) _model = model;
  }

  /// Free-form completion → plain text (or null on failure).
  Future<String?> completeText({
    required String system,
    required String user,
    double temperature = 0.3,
    int maxTokens = 512,
  }) {
    return _chat(
      system: system,
      user: user,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }

  /// Structured completion → a parsed JSON object (or null on failure).
  ///
  /// Portable across models: we do NOT rely on the provider's response_format
  /// (many NIM models reject it). Instead the [system] prompt must instruct the
  /// model to reply with ONLY JSON; we then robustly extract the JSON object.
  Future<Map<String, dynamic>?> completeJson({
    required String system,
    required String user,
    int maxTokens = 512,
  }) async {
    final raw = await _chat(
      system:
          '$system\n\nRespond with ONLY a single minified JSON object — no prose, no code fences.',
      user: user,
      temperature: 0.1,
      maxTokens: maxTokens,
    );
    if (raw == null) return null;
    try {
      var s = raw.trim();
      // Strip ``` / ```json fences if present.
      if (s.startsWith('```')) {
        s = s.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
        s = s.replaceFirst(RegExp(r'\s*```$'), '');
        s = s.trim();
      }
      // Extract the outermost { ... }.
      final start = s.indexOf('{');
      final end = s.lastIndexOf('}');
      if (start >= 0 && end > start) s = s.substring(start, end + 1);
      final decoded = jsonDecode(s);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      debugPrint('LlmService.completeJson parse failed: $e');
      return null;
    }
  }

  Future<String?> _chat({
    required String system,
    required String user,
    required double temperature,
    required int maxTokens,
  }) async {
    if (!isConfigured) return null;
    try {
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'system', 'content': system},
                {'role': 'user', 'content': user},
              ],
              'temperature': temperature,
              'max_tokens': maxTokens,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        debugPrint('LlmService HTTP ${resp.statusCode}: ${resp.body}');
        return null;
      }
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final choices = data['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final content = (choices.first as Map)['message']?['content'];
      return content is String && content.trim().isNotEmpty ? content.trim() : null;
    } catch (e) {
      debugPrint('LlmService request failed: $e');
      return null;
    }
  }
}

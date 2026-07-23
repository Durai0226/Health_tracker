import '../../../core/ai/ai_types.dart';
import '../../../core/services/clean_storage_service.dart';
import 'assistant_service.dart';

/// One message in the Ask AI thread — serializable so the conversation survives
/// closing the screen (a top-tier expectation the assistant used to miss). Kept
/// local (app preferences); never synced or backed up.
class ChatMessage {
  final String text;
  final bool isUser;
  final bool isEmergency;
  final List<Citation> sources;
  final AiEngineKind engine;

  /// The topic this answer was about, for resolving the next follow-up.
  final String? topic;

  /// User feedback on an answer: 1 = helpful, -1 = not helpful, 0 = none.
  int feedback;

  ChatMessage({
    required this.text,
    this.isUser = false,
    this.isEmergency = false,
    this.sources = const [],
    this.engine = AiEngineKind.ruleBased,
    this.topic,
    this.feedback = 0,
  });

  Map<String, dynamic> toJson() => {
        't': text,
        'u': isUser,
        'e': isEmergency,
        'g': engine.index,
        'f': feedback,
        if (topic != null) 'tp': topic,
        's': sources.map((c) => c.toJson()).toList(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final gi = (j['g'] as num?)?.toInt() ?? 0;
    return ChatMessage(
      text: j['t']?.toString() ?? '',
      isUser: j['u'] == true,
      isEmergency: j['e'] == true,
      engine: gi >= 0 && gi < AiEngineKind.values.length
          ? AiEngineKind.values[gi]
          : AiEngineKind.ruleBased,
      topic: j['tp']?.toString(),
      feedback: (j['f'] as num?)?.toInt() ?? 0,
      sources: ((j['s'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Citation.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

/// Persists the Ask AI thread locally (last [_maxMessages]).
class ChatStore {
  const ChatStore._();
  static const String _key = 'aiChatThread';
  static const int _maxMessages = 60;

  static Future<void> save(List<ChatMessage> messages) async {
    final tail = messages.length > _maxMessages
        ? messages.sublist(messages.length - _maxMessages)
        : messages;
    await CleanStorageService.setAppPreference(
        _key, tail.map((m) => m.toJson()).toList());
  }

  static List<ChatMessage> load() {
    final raw = CleanStorageService.getAppPreference(_key);
    if (raw is! List) return [];
    try {
      return raw
          .whereType<Map>()
          .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clear() =>
      CleanStorageService.setAppPreference(_key, <dynamic>[]);
}

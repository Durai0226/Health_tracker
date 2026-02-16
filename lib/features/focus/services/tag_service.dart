import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/services/storage_service.dart';
import '../models/custom_tag.dart';
import '../models/focus_session.dart';

class TagService extends ChangeNotifier {
  static final TagService _instance = TagService._internal();
  factory TagService() => _instance;
  TagService._internal();

  List<FocusTag> _tags = [];
  Map<String, List<String>> _sessionTags = {};

  List<FocusTag> get tags => List.unmodifiable(_tags);
  List<FocusTag> get defaultTags => _tags.where((t) => t.isDefault).toList();
  List<FocusTag> get customTags => _tags.where((t) => !t.isDefault).toList();

  Future<void> init() async {
    await _loadData();
    if (_tags.isEmpty) {
      _tags = DefaultTags.getDefaultTags();
      await _saveData();
    }
    debugPrint('✓ TagService initialized with ${_tags.length} tags');
  }

  Future<void> _loadData() async {
    try {
      final prefs = StorageService.getAppPreferences();
      
      final tagsJson = prefs['focusTags'];
      if (tagsJson != null && tagsJson is List) {
        _tags = tagsJson
            .map((t) => FocusTag.fromJson(Map<String, dynamic>.from(t)))
            .toList();
      }

      final sessionTagsJson = prefs['focusSessionTags'];
      if (sessionTagsJson != null && sessionTagsJson is Map) {
        _sessionTags = {};
        sessionTagsJson.forEach((key, value) {
          _sessionTags[key] = List<String>.from(value);
        });
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading tags data: $e');
    }
  }

  Future<void> _saveData() async {
    try {
      await StorageService.setAppPreference(
        'focusTags',
        _tags.map((t) => t.toJson()).toList(),
      );
      await StorageService.setAppPreference('focusSessionTags', _sessionTags);
    } catch (e) {
      debugPrint('Error saving tags data: $e');
    }
  }

  Future<FocusTag> createTag({
    required String name,
    required int colorValue,
    String? emoji,
  }) async {
    final tag = FocusTag(
      id: _generateId(),
      name: name,
      color: FocusTag.availableColors.firstWhere(
        (c) => c.value == colorValue,
        orElse: () => FocusTag.availableColors.first,
      ),
      emoji: emoji,
      createdAt: DateTime.now(),
      isDefault: false,
    );

    _tags.add(tag);
    await _saveData();
    notifyListeners();
    
    debugPrint('✓ Created tag: ${tag.name}');
    return tag;
  }

  Future<void> updateTag(FocusTag updatedTag) async {
    final index = _tags.indexWhere((t) => t.id == updatedTag.id);
    if (index != -1) {
      _tags[index] = updatedTag;
      await _saveData();
      notifyListeners();
    }
  }

  Future<void> deleteTag(String tagId) async {
    _tags.removeWhere((t) => t.id == tagId && !t.isDefault);
    
    _sessionTags.forEach((sessionId, tagIds) {
      tagIds.remove(tagId);
    });

    await _saveData();
    notifyListeners();
  }

  Future<void> tagSession(String sessionId, List<String> tagIds) async {
    _sessionTags[sessionId] = tagIds;

    for (final tagId in tagIds) {
      final index = _tags.indexWhere((t) => t.id == tagId);
      if (index != -1) {
        _tags[index] = _tags[index].copyWith(
          usageCount: _tags[index].usageCount + 1,
        );
      }
    }

    await _saveData();
    notifyListeners();
  }

  List<String> getTagsForSession(String sessionId) {
    return _sessionTags[sessionId] ?? [];
  }

  List<FocusTag> getTagObjectsForSession(String sessionId) {
    final tagIds = _sessionTags[sessionId] ?? [];
    return _tags.where((t) => tagIds.contains(t.id)).toList();
  }

  FocusTag? getTagById(String tagId) {
    try {
      return _tags.firstWhere((t) => t.id == tagId);
    } catch (_) {
      return null;
    }
  }

  List<TagStatistics> calculateTagStatistics(List<FocusSession> sessions) {
    final Map<String, int> minutesByTag = {};
    final Map<String, int> sessionsByTag = {};
    final Map<String, DateTime> lastUsedByTag = {};

    for (final session in sessions.where((s) => s.wasCompleted)) {
      final tagIds = _sessionTags[session.id] ?? [];
      for (final tagId in tagIds) {
        minutesByTag[tagId] = (minutesByTag[tagId] ?? 0) + session.actualMinutes;
        sessionsByTag[tagId] = (sessionsByTag[tagId] ?? 0) + 1;
        
        final lastUsed = lastUsedByTag[tagId];
        if (lastUsed == null || session.startedAt.isAfter(lastUsed)) {
          lastUsedByTag[tagId] = session.startedAt;
        }
      }
    }

    return _tags.map((tag) {
      return TagStatistics(
        tagId: tag.id,
        tagName: tag.name,
        tagColor: tag.color,
        totalMinutes: minutesByTag[tag.id] ?? 0,
        sessionCount: sessionsByTag[tag.id] ?? 0,
        lastUsed: lastUsedByTag[tag.id],
      );
    }).where((s) => s.sessionCount > 0).toList()
      ..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
  }

  List<FocusTag> get mostUsedTags {
    final sorted = List<FocusTag>.from(_tags)
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));
    return sorted.take(5).toList();
  }

  String _generateId() {
    return 'tag_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }
}

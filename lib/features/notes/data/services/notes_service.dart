import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/notification_service.dart';
import '../../../reminders/models/reminder_model.dart';
import '../models/note_model.dart';
import '../models/task_model.dart';
import '../models/tag_model.dart';
import '../models/folder_model.dart';
import 'notes_cloud_service.dart';
import 'note_security_service.dart';
import 'speech_to_text_service.dart';

class NotesService {
  static final NotesService _instance = NotesService._internal();
  factory NotesService() => _instance;
  NotesService._internal();

  final NotesCloudService _cloudService = NotesCloudService();
  final NoteSecurityService _securityService = NoteSecurityService();
  final SpeechToTextService _speechService = SpeechToTextService();

  static const String _notesKey = 'dlyminder_notes_v2';
  static const String _tasksKey = 'dlyminder_tasks_v2';
  static const String _tagsKey = 'dlyminder_tags_v2';
  static const String _foldersKey = 'dlyminder_folders_v2';

  final _uuid = const Uuid();
  
  List<NoteModel> _notes = [];
  List<TaskModel> _tasks = [];
  List<TagModel> _tags = [];
  List<FolderModel> _folders = [];
  
  bool _isInitialized = false;

  final ValueNotifier<List<NoteModel>> notesNotifier = ValueNotifier([]);
  final ValueNotifier<List<TaskModel>> tasksNotifier = ValueNotifier([]);
  final ValueNotifier<List<TagModel>> tagsNotifier = ValueNotifier([]);
  final ValueNotifier<List<FolderModel>> foldersNotifier = ValueNotifier([]);

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Load notes
    final notesJson = prefs.getString(_notesKey);
    if (notesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(notesJson);
        _notes = decoded.map((e) => NoteModel.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Error loading notes: $e');
        _notes = [];
      }
    }
    
    // Load tasks
    final tasksJson = prefs.getString(_tasksKey);
    if (tasksJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(tasksJson);
        _tasks = decoded.map((e) => TaskModel.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Error loading tasks: $e');
        _tasks = [];
      }
    }
    
    // Load tags
    final tagsJson = prefs.getString(_tagsKey);
    if (tagsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(tagsJson);
        _tags = decoded.map((e) => TagModel.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Error loading tags: $e');
        _tags = [];
      }
    }
    
    // Load folders
    final foldersJson = prefs.getString(_foldersKey);
    if (foldersJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(foldersJson);
        _folders = decoded.map((e) => FolderModel.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Error loading folders: $e');
        _folders = [];
      }
    }
    
    _isInitialized = true;
    _notifyAll();
  }

  void _notifyAll() {
    notesNotifier.value = List.from(_notes);
    tasksNotifier.value = List.from(_tasks);
    tagsNotifier.value = List.from(_tags);
    foldersNotifier.value = List.from(_folders);
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notesKey, jsonEncode(_notes.map((e) => e.toJson()).toList()));
    notesNotifier.value = List.from(_notes);
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tasksKey, jsonEncode(_tasks.map((e) => e.toJson()).toList()));
    tasksNotifier.value = List.from(_tasks);
  }

  Future<void> _saveTags() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tagsKey, jsonEncode(_tags.map((e) => e.toJson()).toList()));
    tagsNotifier.value = List.from(_tags);
  }

  Future<void> _saveFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_foldersKey, jsonEncode(_folders.map((e) => e.toJson()).toList()));
    foldersNotifier.value = List.from(_folders);
  }

  // ============ NOTES ============

  List<NoteModel> getAllNotes() => List.from(_notes.where((n) => !n.isDeleted));
  
  List<NoteModel> getActiveNotes() => _notes.where((n) => !n.isDeleted && !n.isArchived).toList();
  
  List<NoteModel> getPinnedNotes() => _notes.where((n) => n.isPinned && !n.isDeleted && !n.isArchived).toList();
  
  List<NoteModel> getArchivedNotes() => _notes.where((n) => n.isArchived && !n.isDeleted).toList();
  
  List<NoteModel> getTrashNotes() => _notes.where((n) => n.isDeleted).toList();

  List<NoteModel> getFavoriteNotes() => _notes.where((n) => n.isFavorite && !n.isDeleted && !n.isArchived).toList();

  List<NoteModel> getVoiceNotes() => _notes.where((n) => n.isVoiceNote && !n.isDeleted && !n.isArchived).toList();

  List<NoteModel> getRecentNotes({int limit = 5}) {
    final notes = getActiveNotes();
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes.take(limit).toList();
  }

  List<NoteModel> getNotesByFolder(String folderId) =>
      _notes.where((n) => n.folderId == folderId && !n.isDeleted && !n.isArchived).toList();

  List<NoteModel> getNotesByType(NoteType type) =>
      _notes.where((n) => n.noteType == type && !n.isDeleted && !n.isArchived).toList();

  List<NoteModel> getNotesWithReminders() =>
      _notes.where((n) => n.hasReminder && !n.isDeleted && !n.isArchived).toList();

  List<NoteModel> getNotesWithTasks() {
    final noteIdsWithTasks = _tasks.where((t) => !t.isCompleted).map((t) => t.noteId).toSet();
    return _notes.where((n) => noteIdsWithTasks.contains(n.id) && !n.isDeleted && !n.isArchived).toList();
  }

  NoteModel? getNote(String id) {
    try {
      return _notes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<String> createNote({
    required String title,
    String content = '',
    List<String> tagIds = const [],
    String? color,
    String? folderId,
  }) async {
    final now = DateTime.now();
    final note = NoteModel(
      id: _uuid.v4(),
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
      tagIds: tagIds,
      color: color,
    );
    _notes.insert(0, note);
    await _saveNotes();
    await _cloudService.syncNote(note);
    return note.id;
  }

  Future<void> updateNote(NoteModel note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      final oldNote = _notes[index];
      String? reminderId = note.reminderId;
      
      // Check if reminder needs update (date changed OR content/title changed while reminder exists)
      bool dateChanged = note.reminderDate != oldNote.reminderDate;
      bool contentChanged = note.title != oldNote.title || note.content != oldNote.content;
      bool hasActiveReminder = note.reminderDate != null && note.reminderDate!.isAfter(DateTime.now());

      if (dateChanged || (contentChanged && hasActiveReminder)) {
         // Cancel old reminder if exists
         if (oldNote.reminderId != null) {
            await NotificationService().cancelNotification(int.parse(oldNote.reminderId!));
            reminderId = null;
         }
         
         // Schedule new reminder if active
         if (hasActiveReminder) {
            final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;
            reminderId = notificationId.toString();
            await NotificationService().scheduleGenericReminder(
              id: notificationId,
              title: note.title.isEmpty ? 'Note Reminder' : note.title,
              body: generateLocalSummary(note.content).isEmpty 
                  ? 'Time to check your note' 
                  : generateLocalSummary(note.content),
              scheduledTime: note.reminderDate!,
              repeatType: RepeatType.none,
              priority: ReminderPriority.high,
              payload: 'note:${note.id}',
            );
         } else {
            // If date changed to null or past, ensure reminderId is null
            reminderId = null;
         }
      }

      _notes[index] = note.copyWith(
        updatedAt: DateTime.now(),
        reminderId: reminderId,
      );
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  Future<void> deleteNote(String id, {bool permanent = false}) async {
    if (permanent) {
      _notes.removeWhere((n) => n.id == id);
      _tasks.removeWhere((t) => t.noteId == id);
      await _saveTasks();
      await _cloudService.deleteNote(id);
    } else {
      final index = _notes.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notes[index] = _notes[index].copyWith(isDeleted: true);
        await _cloudService.syncNote(_notes[index]);
      }
    }
    await _saveNotes();
  }

  Future<void> restoreNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(isDeleted: false);
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  Future<void> togglePin(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(isPinned: !_notes[index].isPinned);
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  Future<void> archiveNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(isArchived: true);
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  Future<void> unarchiveNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(isArchived: false);
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  Future<void> setNoteColor(String noteId, String? color) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(color: color);
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  Future<void> addTagToNote(String noteId, String tagId) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final tagIds = List<String>.from(_notes[index].tagIds);
      if (!tagIds.contains(tagId)) {
        tagIds.add(tagId);
        _notes[index] = _notes[index].copyWith(tagIds: tagIds);
        await _saveNotes();
        await _cloudService.syncNote(_notes[index]);
      }
    }
  }

  Future<void> removeTagFromNote(String noteId, String tagId) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final tagIds = List<String>.from(_notes[index].tagIds);
      tagIds.remove(tagId);
      _notes[index] = _notes[index].copyWith(tagIds: tagIds);
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  // ============ TASKS ============

  List<TaskModel> getAllTasks() => List.from(_tasks);
  
  List<TaskModel> getTasksForNote(String noteId) => 
      _tasks.where((t) => t.noteId == noteId).toList()..sort((a, b) => a.order.compareTo(b.order));
  
  List<TaskModel> getIncompleteTasks() => _tasks.where((t) => !t.isCompleted).toList();
  
  List<TaskModel> getCompletedTasks() => _tasks.where((t) => t.isCompleted).toList();

  Future<String> createTask({
    required String noteId,
    required String title,
    int? order,
    DateTime? dueDate,
    String? priority,
  }) async {
    final task = TaskModel.create(
      noteId: noteId,
      title: title,
      order: order ?? _tasks.where((t) => t.noteId == noteId).length,
      dueDate: dueDate,
      priority: priority,
    );
    _tasks.add(task);
    await _saveTasks();
    return task.id;
  }

  Future<void> updateTask(TaskModel task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;
      await _saveTasks();
    }
  }

  Future<void> toggleTask(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(isCompleted: !_tasks[index].isCompleted);
      await _saveTasks();
    }
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    await _saveTasks();
  }

  Future<void> reorderTasks(String noteId, int oldIndex, int newIndex) async {
    final noteTasks = getTasksForNote(noteId);
    if (oldIndex < newIndex) newIndex--;
    final task = noteTasks.removeAt(oldIndex);
    noteTasks.insert(newIndex, task);
    
    for (int i = 0; i < noteTasks.length; i++) {
      final taskIndex = _tasks.indexWhere((t) => t.id == noteTasks[i].id);
      if (taskIndex != -1) {
        _tasks[taskIndex] = _tasks[taskIndex].copyWith(order: i);
      }
    }
    await _saveTasks();
  }

  // ============ TAGS ============

  List<TagModel> getAllTags() => List.from(_tags);

  TagModel? getTag(String id) {
    try {
      return _tags.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  TagModel? getTagById(String id) => getTag(id);

  Future<String> createTag(String name, {String? color}) async {
    final tag = TagModel(
      id: _uuid.v4(),
      name: name,
      color: color,
    );
    _tags.add(tag);
    await _saveTags();
    await _cloudService.syncTag(tag);
    return tag.id;
  }

  Future<void> updateTag(TagModel tag) async {
    final index = _tags.indexWhere((t) => t.id == tag.id);
    if (index != -1) {
      _tags[index] = tag;
      await _saveTags();
      await _cloudService.syncTag(tag);
    }
  }

  Future<void> deleteTag(String id) async {
    _tags.removeWhere((t) => t.id == id);
    // Remove tag from all notes
    for (int i = 0; i < _notes.length; i++) {
      if (_notes[i].tagIds.contains(id)) {
        final tagIds = List<String>.from(_notes[i].tagIds);
        tagIds.remove(id);
        _notes[i] = _notes[i].copyWith(tagIds: tagIds);
        await _cloudService.syncNote(_notes[i]);
      }
    }
    await _saveTags();
    await _saveNotes();
    await _cloudService.deleteTag(id);
  }

  // ============ FOLDERS ============

  List<FolderModel> getAllFolders() => List.from(_folders);

  Future<String> createFolder(String name, {String? color, String? icon}) async {
    final folder = FolderModel(
      id: _uuid.v4(),
      name: name,
      createdAt: DateTime.now(),
      color: color,
      icon: icon,
    );
    _folders.add(folder);
    await _saveFolders();
    await _cloudService.syncFolder(folder);
    return folder.id;
  }

  Future<void> deleteFolder(String id) async {
    _folders.removeWhere((f) => f.id == id);
    await _saveFolders();
    await _cloudService.deleteFolder(id);
  }

  Future<void> updateFolder(FolderModel folder) async {
    final index = _folders.indexWhere((f) => f.id == folder.id);
    if (index != -1) {
      _folders[index] = folder;
      await _saveFolders();
      await _cloudService.syncFolder(folder);
    }
  }

  List<NoteModel> getNotesInFolder(String folderId) {
    return _notes.where((n) => 
      !n.isDeleted && n.folderId == folderId
    ).toList();
  }

  // ============ SEARCH ============

  List<NoteModel> searchNotes(String query) {
    if (query.isEmpty) return getActiveNotes();
    
    final q = query.toLowerCase();
    return _notes.where((n) {
      if (n.isDeleted || n.isArchived) return false;
      return n.title.toLowerCase().contains(q) || 
             n.content.toLowerCase().contains(q);
    }).toList();
  }

  // ============ FAVORITES ============

  Future<void> toggleFavorite(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(isFavorite: !_notes[index].isFavorite);
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  // ============ AI FEATURES ============

  Future<void> setAiSummary(String noteId, String summary) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(aiSummary: summary);
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  String generateLocalSummary(String content) {
    if (content.isEmpty) return '';
    
    String plainText = content;
    try {
      if (content.startsWith('[')) {
        final decoded = jsonDecode(content) as List;
        plainText = decoded
            .where((op) => op['insert'] is String)
            .map((op) => op['insert'])
            .join()
            .trim();
      }
    } catch (_) {}
    
    final sentences = plainText.split(RegExp(r'[.!?]+'));
    final validSentences = sentences.where((s) => s.trim().length > 10).take(2);
    return validSentences.join('. ').trim();
  }

  /// Generates Quill Delta JSON for meeting note template
  String generateMeetingTemplate() {
    final template = [
      {"insert": "📋 Meeting Details\n", "attributes": {"bold": true, "size": "large"}},
      {"insert": "\n"},
      {"insert": "Date: ", "attributes": {"bold": true}},
      {"insert": "${DateTime.now().toString().split(' ')[0]}\n"},
      {"insert": "Time: ", "attributes": {"bold": true}},
      {"insert": "\n"},
      {"insert": "Duration: ", "attributes": {"bold": true}},
      {"insert": "\n"},
      {"insert": "Location: ", "attributes": {"bold": true}},
      {"insert": "\n\n"},
      {"insert": "👥 Attendees\n", "attributes": {"bold": true, "size": "large"}},
      {"insert": "\n• \n• \n• \n\n"},
      {"insert": "📝 Agenda\n", "attributes": {"bold": true, "size": "large"}},
      {"insert": "\n1. \n2. \n3. \n\n"},
      {"insert": "📌 Discussion Notes\n", "attributes": {"bold": true, "size": "large"}},
      {"insert": "\n\n\n"},
      {"insert": "✅ Action Items\n", "attributes": {"bold": true, "size": "large"}},
      {"insert": "\n"},
      {"insert": "[ ] \n", "attributes": {"list": "unchecked"}},
      {"insert": "[ ] \n", "attributes": {"list": "unchecked"}},
      {"insert": "[ ] \n", "attributes": {"list": "unchecked"}},
      {"insert": "\n"},
      {"insert": "📅 Follow-up\n", "attributes": {"bold": true, "size": "large"}},
      {"insert": "\nNext meeting: \nDeadlines: \n"},
    ];
    return jsonEncode(template);
  }

  // ============ VOICE NOTES ============

  Future<String?> getVoiceNotesDirectory() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final voiceDir = Directory('${dir.path}/voice_notes');
      if (!await voiceDir.exists()) {
        await voiceDir.create(recursive: true);
      }
      return voiceDir.path;
    } catch (e) {
      debugPrint('Error getting voice notes directory: $e');
      return null;
    }
  }

  Future<void> setVoiceData(String noteId, {
    String? path,
    int? duration,
    String? transcript,
  }) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(
        voiceRecordingPath: path,
        voiceDurationSeconds: duration,
        voiceTranscript: transcript,
        noteType: NoteType.voice,
      );
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  // ============ ATTACHMENTS ============

  Future<void> addAttachment(String noteId, String path) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final attachments = List<String>.from(_notes[index].attachments);
      attachments.add(path);
      _notes[index] = _notes[index].copyWith(attachments: attachments);
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  Future<void> removeAttachment(String noteId, String path) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final attachments = List<String>.from(_notes[index].attachments);
      attachments.remove(path);
      _notes[index] = _notes[index].copyWith(attachments: attachments);
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  // ============ REMINDERS ============

  Future<void> setReminder(String noteId, DateTime? date) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      final note = _notes[index];
      
      // Cancel existing reminder if present
      if (note.reminderId != null) {
        await NotificationService().cancelNotification(int.parse(note.reminderId!));
      }

      String? newReminderId;
      
      if (date != null) {
        // Schedule new reminder
        final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;
        newReminderId = notificationId.toString();
        
        await NotificationService().scheduleGenericReminder(
          id: notificationId,
          title: note.title.isEmpty ? 'Note Reminder' : note.title,
          body: generateLocalSummary(note.content).isEmpty 
              ? 'Time to check your note' 
              : generateLocalSummary(note.content),
          scheduledTime: date,
          repeatType: RepeatType.none,
          priority: ReminderPriority.high,
          payload: 'note:${note.id}',
        );
      }

      _notes[index] = _notes[index].copyWith(
        reminderDate: date,
        reminderId: newReminderId,
      );
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  // ============ PRIORITY ============

  Future<void> setPriority(String noteId, NotePriority priority) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(priority: priority);
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  // ============ FOLDER ASSIGNMENT ============

  Future<void> moveToFolder(String noteId, String? folderId) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(folderId: folderId);
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  // ============ DUPLICATE ============

  Future<String> duplicateNote(String noteId) async {
    final note = getNote(noteId);
    if (note == null) throw Exception('Note not found');
    
    final now = DateTime.now();
    final newNote = NoteModel(
      id: _uuid.v4(),
      title: '${note.title} (Copy)',
      content: note.content,
      createdAt: now,
      updatedAt: now,
      tagIds: note.tagIds,
      color: note.color,
      folderId: note.folderId,
      noteType: note.noteType,
      priority: note.priority,
    );
    
    _notes.insert(0, newNote);
    await _saveNotes();
    await _cloudService.syncNote(newNote);
    return newNote.id;
  }

  // ============ NOTE LOCKING ============

  NoteSecurityService get securityService => _securityService;
  SpeechToTextService get speechService => _speechService;

  Future<void> lockNote(String noteId, String password) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      await _securityService.setNotePassword(noteId, password);
      _notes[index] = _notes[index].copyWith(
        isLocked: true,
        password: 'protected',
      );
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  Future<void> unlockNote(String noteId) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      await _securityService.removeNotePassword(noteId);
      _notes[index] = _notes[index].copyWith(
        isLocked: false,
        password: null,
      );
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  Future<bool> verifyNotePassword(String noteId, String password) async {
    return await _securityService.verifyNotePassword(noteId, password);
  }

  Future<bool> authenticateWithBiometric() async {
    return await _securityService.authenticateWithBiometric();
  }

  Future<bool> isBiometricAvailable() async {
    return await _securityService.isBiometricAvailable();
  }

  // ============ AI SUMMARY ============

  Future<String> generateAiSummary(String noteId) async {
    final note = getNote(noteId);
    if (note == null) return '';
    
    String plainText = note.content;
    try {
      if (note.content.startsWith('[')) {
        final decoded = jsonDecode(note.content) as List;
        plainText = decoded
            .where((op) => op['insert'] is String)
            .map((op) => op['insert'])
            .join()
            .trim();
      }
    } catch (_) {}
    
    if (plainText.length < 50) {
      return plainText;
    }
    
    final sentences = plainText.split(RegExp(r'[.!?]+'));
    final validSentences = sentences.where((s) => s.trim().length > 10).take(3);
    final summary = validSentences.join('. ').trim();
    
    if (summary.isNotEmpty) {
      await setAiSummary(noteId, summary);
    }
    
    return summary.isEmpty ? 'No summary available' : summary;
  }

  // ============ VOICE TRANSCRIPTION ============

  Future<String?> transcribeVoiceNote(String audioPath) async {
    return await _speechService.transcribeAudioFile(audioPath);
  }

  Future<void> setVoiceTranscript(String noteId, String transcript) async {
    final index = _notes.indexWhere((n) => n.id == noteId);
    if (index != -1) {
      _notes[index] = _notes[index].copyWith(voiceTranscript: transcript);
      await _saveNotes();
      await _cloudService.syncNote(_notes[index]);
    }
  }

  // ============ STATS ============

  Map<String, int> getNotesStats() {
    return {
      'total': getActiveNotes().length,
      'pinned': getPinnedNotes().length,
      'withTasks': getNotesWithTasks().length,
      'archived': getArchivedNotes().length,
      'trash': getTrashNotes().length,
      'incompleteTasks': getIncompleteTasks().length,
      'favorites': getFavoriteNotes().length,
      'voiceNotes': getVoiceNotes().length,
      'withReminders': getNotesWithReminders().length,
    };
  }

  Map<String, dynamic> getDetailedStats() {
    final notes = getActiveNotes();
    int totalWords = 0;
    int totalChars = 0;
    
    for (final note in notes) {
      String text = note.content;
      try {
        if (note.content.startsWith('[')) {
          final decoded = jsonDecode(note.content) as List;
          text = decoded
              .where((op) => op['insert'] is String)
              .map((op) => op['insert'])
              .join();
        }
      } catch (_) {}
      
      totalChars += text.length;
      totalWords += text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    }
    
    return {
      'totalNotes': notes.length,
      'totalWords': totalWords,
      'totalCharacters': totalChars,
      'avgWordsPerNote': notes.isEmpty ? 0 : (totalWords / notes.length).round(),
      'pinnedNotes': getPinnedNotes().length,
      'favoriteNotes': getFavoriteNotes().length,
      'voiceNotes': getVoiceNotes().length,
      'notesWithTasks': getNotesWithTasks().length,
      'archivedNotes': getArchivedNotes().length,
      'trashedNotes': getTrashNotes().length,
    };
  }
}

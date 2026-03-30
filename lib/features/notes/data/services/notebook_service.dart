import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/notebook_model.dart';
import '../models/page_model.dart';
import '../models/stroke_model.dart';
import '../models/audio_clip_model.dart';

/// Service for managing notebooks, pages, and strokes
/// Handles local storage and cloud sync for Livescribe feature
class NotebookService {
  static final NotebookService _instance = NotebookService._internal();
  factory NotebookService() => _instance;
  NotebookService._internal();

  static const String _notebooksKey = 'livescribe_notebooks_v1';
  static const String _pagesKey = 'livescribe_pages_v1';

  final _uuid = const Uuid();
  
  List<NotebookModel> _notebooks = [];
  Map<String, List<PageModel>> _pagesByNotebook = {};
  
  bool _isInitialized = false;

  final ValueNotifier<List<NotebookModel>> notebooksNotifier = ValueNotifier([]);

  // ============ INITIALIZATION ============

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    // Load notebooks
    final notebooksJson = prefs.getString(_notebooksKey);
    if (notebooksJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(notebooksJson);
        _notebooks = decoded.map((e) => NotebookModel.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Error loading notebooks: $e');
        _notebooks = [];
      }
    }
    
    // Load pages
    final pagesJson = prefs.getString(_pagesKey);
    if (pagesJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(pagesJson);
        _pagesByNotebook = decoded.map((key, value) {
          final pages = (value as List<dynamic>)
              .map((e) => PageModel.fromJson(e))
              .toList();
          return MapEntry(key, pages);
        });
      } catch (e) {
        debugPrint('Error loading pages: $e');
        _pagesByNotebook = {};
      }
    }
    
    _isInitialized = true;
    _notifyNotebooks();
  }

  void _notifyNotebooks() {
    notebooksNotifier.value = List.from(_notebooks);
  }

  Future<void> _saveNotebooks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _notebooksKey,
      jsonEncode(_notebooks.map((n) => n.toJson()).toList()),
    );
    _notifyNotebooks();
  }

  Future<void> _savePages() async {
    final prefs = await SharedPreferences.getInstance();
    final pagesMap = _pagesByNotebook.map((key, pages) {
      return MapEntry(key, pages.map((p) => p.toJson()).toList());
    });
    await prefs.setString(_pagesKey, jsonEncode(pagesMap));
  }

  // ============ NOTEBOOKS ============

  List<NotebookModel> getAllNotebooks() {
    return _notebooks.where((n) => !n.isDeleted).toList();
  }

  List<NotebookModel> getActiveNotebooks() {
    return _notebooks.where((n) => !n.isDeleted && !n.isArchived).toList();
  }

  List<NotebookModel> getPinnedNotebooks() {
    return _notebooks.where((n) => n.isPinned && !n.isDeleted && !n.isArchived).toList();
  }

  List<NotebookModel> getArchivedNotebooks() {
    return _notebooks.where((n) => n.isArchived && !n.isDeleted).toList();
  }

  List<NotebookModel> getTrashNotebooks() {
    return _notebooks.where((n) => n.isDeleted).toList();
  }

  List<NotebookModel> getRecentNotebooks({int limit = 10}) {
    final notebooks = getActiveNotebooks();
    notebooks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notebooks.take(limit).toList();
  }

  List<NotebookModel> getNotebooksByFolder(String folderId) {
    return _notebooks.where((n) => 
      n.folderId == folderId && !n.isDeleted && !n.isArchived
    ).toList();
  }

  NotebookModel? getNotebook(String id) {
    try {
      return _notebooks.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<String> createNotebook({
    required String title,
    String? description,
    String coverColor = '#0066FF',
    String? folderId,
    NotebookTemplate defaultTemplate = NotebookTemplate.blank,
  }) async {
    final now = DateTime.now();
    final notebook = NotebookModel(
      id: _uuid.v4(),
      title: title,
      description: description,
      coverColor: coverColor,
      createdAt: now,
      updatedAt: now,
      folderId: folderId,
      defaultTemplate: defaultTemplate,
    );
    
    _notebooks.insert(0, notebook);
    _pagesByNotebook[notebook.id] = [];
    
    // Create first page
    await addPage(
      notebookId: notebook.id,
      template: defaultTemplate,
    );
    
    await _saveNotebooks();
    await _savePages();
    
    return notebook.id;
  }

  Future<void> updateNotebook(NotebookModel notebook) async {
    final index = _notebooks.indexWhere((n) => n.id == notebook.id);
    if (index != -1) {
      _notebooks[index] = notebook.copyWith(updatedAt: DateTime.now());
      await _saveNotebooks();
    }
  }

  Future<void> deleteNotebook(String id, {bool permanent = false}) async {
    if (permanent) {
      _notebooks.removeWhere((n) => n.id == id);
      _pagesByNotebook.remove(id);
      await _savePages();
    } else {
      final index = _notebooks.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notebooks[index] = _notebooks[index].copyWith(isDeleted: true);
      }
    }
    await _saveNotebooks();
  }

  Future<void> restoreNotebook(String id) async {
    final index = _notebooks.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notebooks[index] = _notebooks[index].copyWith(isDeleted: false);
      await _saveNotebooks();
    }
  }

  Future<void> toggleNotebookPin(String id) async {
    final index = _notebooks.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notebooks[index] = _notebooks[index].copyWith(
        isPinned: !_notebooks[index].isPinned,
      );
      await _saveNotebooks();
    }
  }

  Future<void> archiveNotebook(String id) async {
    final index = _notebooks.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notebooks[index] = _notebooks[index].copyWith(isArchived: true);
      await _saveNotebooks();
    }
  }

  Future<void> unarchiveNotebook(String id) async {
    final index = _notebooks.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notebooks[index] = _notebooks[index].copyWith(isArchived: false);
      await _saveNotebooks();
    }
  }

  Future<void> setNotebookCover(String notebookId, String coverColor) async {
    final index = _notebooks.indexWhere((n) => n.id == notebookId);
    if (index != -1) {
      _notebooks[index] = _notebooks[index].copyWith(coverColor: coverColor);
      await _saveNotebooks();
    }
  }

  // ============ PAGES ============

  List<PageModel> getPages(String notebookId) {
    return _pagesByNotebook[notebookId] ?? [];
  }

  PageModel? getPage(String notebookId, int pageIndex) {
    final pages = _pagesByNotebook[notebookId];
    if (pages == null || pageIndex >= pages.length) return null;
    return pages[pageIndex];
  }

  PageModel? getPageById(String pageId) {
    for (final pages in _pagesByNotebook.values) {
      for (final page in pages) {
        if (page.id == pageId) return page;
      }
    }
    return null;
  }

  Future<String> addPage({
    required String notebookId,
    NotebookTemplate template = NotebookTemplate.blank,
    String? backgroundColor,
  }) async {
    final pages = _pagesByNotebook[notebookId] ?? [];
    
    final page = PageModel.create(
      id: _uuid.v4(),
      notebookId: notebookId,
      pageNumber: pages.length + 1,
      template: template,
      backgroundColor: backgroundColor,
    );
    
    pages.add(page);
    _pagesByNotebook[notebookId] = pages;
    
    // Update notebook page count
    final notebookIndex = _notebooks.indexWhere((n) => n.id == notebookId);
    if (notebookIndex != -1) {
      _notebooks[notebookIndex] = _notebooks[notebookIndex].copyWith(
        pageCount: pages.length,
        updatedAt: DateTime.now(),
      );
      await _saveNotebooks();
    }
    
    await _savePages();
    return page.id;
  }

  Future<void> updatePage(PageModel page) async {
    final pages = _pagesByNotebook[page.notebookId];
    if (pages == null) return;
    
    final index = pages.indexWhere((p) => p.id == page.id);
    if (index != -1) {
      pages[index] = page.copyWith(updatedAt: DateTime.now());
      _pagesByNotebook[page.notebookId] = pages;
      
      // Update notebook timestamp
      final notebookIndex = _notebooks.indexWhere((n) => n.id == page.notebookId);
      if (notebookIndex != -1) {
        _notebooks[notebookIndex] = _notebooks[notebookIndex].copyWith(
          updatedAt: DateTime.now(),
        );
        await _saveNotebooks();
      }
      
      await _savePages();
    }
  }

  Future<void> deletePage(String notebookId, int pageIndex) async {
    final pages = _pagesByNotebook[notebookId];
    if (pages == null || pageIndex >= pages.length) return;
    
    pages.removeAt(pageIndex);
    
    // Update page numbers
    for (int i = 0; i < pages.length; i++) {
      pages[i] = pages[i].copyWith(pageNumber: i + 1);
    }
    
    _pagesByNotebook[notebookId] = pages;
    
    // Update notebook page count
    final notebookIndex = _notebooks.indexWhere((n) => n.id == notebookId);
    if (notebookIndex != -1) {
      _notebooks[notebookIndex] = _notebooks[notebookIndex].copyWith(
        pageCount: pages.length,
        updatedAt: DateTime.now(),
      );
      await _saveNotebooks();
    }
    
    await _savePages();
  }

  Future<void> reorderPage(String notebookId, int oldIndex, int newIndex) async {
    final pages = _pagesByNotebook[notebookId];
    if (pages == null) return;
    
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final page = pages.removeAt(oldIndex);
    pages.insert(newIndex, page);
    
    // Update page numbers
    for (int i = 0; i < pages.length; i++) {
      pages[i] = pages[i].copyWith(pageNumber: i + 1);
    }
    
    _pagesByNotebook[notebookId] = pages;
    await _savePages();
  }

  // ============ STROKES ============

  Future<void> addStrokeToPage(String pageId, StrokeModel stroke) async {
    final page = getPageById(pageId);
    if (page == null) return;
    
    final updatedPage = page.copyWith(
      strokes: [...page.strokes, stroke],
      updatedAt: DateTime.now(),
    );
    
    await updatePage(updatedPage);
  }

  Future<void> updatePageStrokes(String pageId, List<StrokeModel> strokes) async {
    final page = getPageById(pageId);
    if (page == null) return;
    
    final updatedPage = page.copyWith(
      strokes: strokes,
      updatedAt: DateTime.now(),
    );
    
    await updatePage(updatedPage);
  }

  Future<void> clearPageStrokes(String pageId) async {
    final page = getPageById(pageId);
    if (page == null) return;
    
    final updatedPage = page.copyWith(
      strokes: [],
      updatedAt: DateTime.now(),
    );
    
    await updatePage(updatedPage);
  }

  // ============ AUDIO CLIPS ============

  Future<void> addAudioClipToPage(String pageId, AudioClipModel audioClip) async {
    final page = getPageById(pageId);
    if (page == null) return;
    
    final updatedPage = page.copyWith(
      audioClips: [...page.audioClips, audioClip],
      updatedAt: DateTime.now(),
    );
    
    await updatePage(updatedPage);
  }

  Future<void> deleteAudioClip(String pageId, String audioClipId) async {
    final page = getPageById(pageId);
    if (page == null) return;
    
    final updatedPage = page.copyWith(
      audioClips: page.audioClips.where((a) => a.id != audioClipId).toList(),
      updatedAt: DateTime.now(),
    );
    
    await updatePage(updatedPage);
  }

  // ============ SEARCH ============

  List<NotebookModel> searchNotebooks(String query) {
    if (query.isEmpty) return getActiveNotebooks();
    
    final lowerQuery = query.toLowerCase();
    return getActiveNotebooks().where((notebook) {
      return notebook.title.toLowerCase().contains(lowerQuery) ||
          (notebook.description?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // ============ STATISTICS ============

  Map<String, dynamic> getStatistics() {
    final activeNotebooks = getActiveNotebooks();
    int totalPages = 0;
    int totalStrokes = 0;
    int totalAudioClips = 0;
    
    for (final notebook in activeNotebooks) {
      final pages = getPages(notebook.id);
      totalPages += pages.length;
      
      for (final page in pages) {
        totalStrokes += page.strokes.length;
        totalAudioClips += page.audioClips.length;
      }
    }
    
    return {
      'notebookCount': activeNotebooks.length,
      'pageCount': totalPages,
      'strokeCount': totalStrokes,
      'audioClipCount': totalAudioClips,
      'pinnedCount': getPinnedNotebooks().length,
      'archivedCount': getArchivedNotebooks().length,
    };
  }

  // ============ EXPORT ============

  Future<Map<String, dynamic>> exportNotebook(String notebookId) async {
    final notebook = getNotebook(notebookId);
    if (notebook == null) return {};
    
    final pages = getPages(notebookId);
    
    return {
      'notebook': notebook.toJson(),
      'pages': pages.map((p) => p.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
      'version': 1,
    };
  }

  Future<String?> importNotebook(Map<String, dynamic> data) async {
    try {
      final notebookData = data['notebook'] as Map<String, dynamic>;
      final pagesData = data['pages'] as List<dynamic>;
      
      // Create new IDs to avoid conflicts
      final newNotebookId = _uuid.v4();
      final notebook = NotebookModel.fromJson(notebookData).copyWith(
        id: newNotebookId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isSynced: false,
      );
      
      final pages = pagesData.map((p) {
        return PageModel.fromJson(p).copyWith(
          id: _uuid.v4(),
          notebookId: newNotebookId,
          isSynced: false,
        );
      }).toList();
      
      _notebooks.insert(0, notebook);
      _pagesByNotebook[newNotebookId] = pages;
      
      await _saveNotebooks();
      await _savePages();
      
      return newNotebookId;
    } catch (e) {
      debugPrint('Error importing notebook: $e');
      return null;
    }
  }
}

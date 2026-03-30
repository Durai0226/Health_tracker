import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/toast/toast.dart';
import '../../data/models/note_model.dart';
import '../../data/models/tag_model.dart';
import '../../data/models/folder_model.dart';
import '../../data/services/notes_service.dart';
import 'premium_note_editor_screen.dart';

class PremiumNotesScreen extends StatefulWidget {
  const PremiumNotesScreen({super.key});

  @override
  State<PremiumNotesScreen> createState() => _PremiumNotesScreenState();
}

class _PremiumNotesScreenState extends State<PremiumNotesScreen>
    with TickerProviderStateMixin {
  final NotesService _service = NotesService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _fadeController;
  late AnimationController _fabController;
  late Animation<double> _fadeAnimation;

  int _selectedTabIndex = 0;
  String _searchQuery = '';
  String? _selectedTagId;
  String? _selectedFolderId;
  bool _isLoading = true;
  bool _showFabMenu = false;
  bool _isGridView = true;

  final List<_TabItem> _tabs = [
    _TabItem('All', Icons.grid_view_rounded, null),
    _TabItem('Notes', Icons.article_rounded, 'notes'),
    _TabItem('Lists', Icons.checklist_rounded, 'lists'),
    _TabItem('Voice', Icons.mic_rounded, 'voice'),
    _TabItem('Favorites', Icons.favorite_rounded, 'favorites'),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _initialize();
  }

  Future<void> _initialize() async {
    await _service.initialize();
    if (mounted) {
      setState(() => _isLoading = false);
      _fadeController.forward();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _fabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<NoteModel> _getFilteredNotes() {
    List<NoteModel> notes;
    
    switch (_tabs[_selectedTabIndex].filter) {
      case 'notes':
        notes = _service.getNotesByType(NoteType.text);
        break;
      case 'lists':
        notes = _service.getNotesWithTasks();
        break;
      case 'voice':
        notes = _service.getVoiceNotes();
        break;
      case 'favorites':
        notes = _service.getFavoriteNotes();
        break;
      default:
        notes = _service.getActiveNotes();
    }

    if (_selectedTagId != null) {
      notes = notes.where((n) => n.tagIds.contains(_selectedTagId)).toList();
    }

    if (_selectedFolderId != null) {
      notes = notes.where((n) => n.folderId == _selectedFolderId).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      notes = notes.where((n) =>
          n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q)).toList();
    }

    notes.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return notes;
  }

  void _openNote(NoteModel? note, {NoteType type = NoteType.text}) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PremiumNoteEditorScreen(
          note: note,
          initialType: type,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }



  void _showFoldersSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (_) => ValueListenableBuilder<List<FolderModel>>(
        valueListenable: _service.foldersNotifier,
        builder: (context, folders, _) {
          return Container(
            padding: const EdgeInsets.all(20),
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Folders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _createFolder(isDark),
                      icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                      label: const Text('New'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (folders.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No folders yet',
                        style: TextStyle(color: isDark ? Colors.white54 : Colors.black38),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: folders.length + 1, // +1 for "All Notes" option
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          final isSelected = _selectedFolderId == null;
                          return ListTile(
                            leading: Icon(Icons.folder_open_outlined, color: isDark ? Colors.white54 : Colors.black54),
                            title: Text('All Notes', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                            trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                            onTap: () {
                              setState(() => _selectedFolderId = null);
                              Navigator.pop(context);
                            },
                          );
                        }
                        
                        final folder = folders[i - 1];
                        final isSelected = _selectedFolderId == folder.id;
                        final folderColor = _parseColor(folder.color) ?? Colors.amber;
                        final noteCount = _service.getNotesByFolder(folder.id).length;
                        
                        return ListTile(
                          leading: Icon(Icons.folder_rounded, color: folderColor),
                          title: Text(folder.name, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                          subtitle: Text('$noteCount notes', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) const Icon(Icons.check, color: Colors.blue),
                              if (!isSelected) 
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade300),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Folder?'),
                                        content: Text('Notes in this folder will not be deleted.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _service.deleteFolder(folder.id);
                                      if (_selectedFolderId == folder.id) {
                                        setState(() => _selectedFolderId = null);
                                      }
                                    }
                                  },
                                ),
                            ],
                          ),
                          onTap: () {
                            setState(() => _selectedFolderId = folder.id);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _createFolder(bool isDark) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (c.text.trim().isNotEmpty) {
                await _service.createFolder(c.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          )
        ],
      ),
    );
  }



  Color? _parseColor(String? c) {
    if (c == null || c.isEmpty) return null;
    try {
      return Color(int.parse(c.replaceFirst('#', '0xFF')));
    } catch (_) {
      return null;
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8F9FC),
      body: _isLoading ? _buildLoading(isDark) : _buildBody(isDark),
    );
  }

  Widget _buildLoading(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withAlpha(150)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(60),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your notes...',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white54 : Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          _buildBackground(isDark),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(isDark),
                _buildSearchSection(isDark),
                _buildQuickStats(isDark),
                _buildTabs(isDark),
                _buildTagsRow(isDark),
                Expanded(child: _buildNotesGrid(isDark)),
              ],
            ),
          ),
          _buildFloatingActions(isDark),
          if (_showFabMenu) _buildFabOverlay(isDark),
        ],
      ),
    );
  }

  Widget _buildBackground(bool isDark) {
    if (isDark) {
      return Container(color: const Color(0xFF0B0F19)); // Dark background
    }
    return Container(color: const Color(0xFFF9FAFB)); // Super clean white/gray background
  }

  Widget _buildHeader(bool isDark) {
    String title = 'My Notes';
    if (_selectedFolderId != null) {
      final folders = _service.getAllFolders();
      final folderIndex = folders.indexWhere((f) => f.id == _selectedFolderId);
      if (folderIndex != -1) {
        title = folders[folderIndex].name;
      }
    }
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _buildActionButton(
            icon: Icons.arrow_back_ios_new_rounded,
            isDark: isDark,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _showFoldersSheet(isDark),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(15) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_service.getActiveNotes().length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildActionButton(
            icon: _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            isDark: isDark,
            onTap: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white70 : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 30 : 20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSearchSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(8) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white30 : const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                ),
              )
            else
              GestureDetector(
                onTap: () => _showSettingsSheet(isDark),
                child: Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(bool isDark) {
    final stats = _service.getNotesStats();
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _buildStatChip(
            icon: Icons.push_pin_rounded,
            count: '${stats['pinned'] ?? 0}',
            color: const Color(0xFFD97706),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            icon: Icons.checklist_rounded,
            count: '${stats['incompleteTasks'] ?? 0}',
            color: const Color(0xFF047857),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            icon: Icons.mic_rounded,
            count: '${stats['voiceNotes'] ?? 0}',
            color: const Color(0xFF6D28D9),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            icon: Icons.favorite_rounded,
            count: '${stats['favorites'] ?? 0}',
            color: const Color(0xFFEF4444),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String count,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 20 : 12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 32,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _tabs.length,
          itemBuilder: (context, index) {
            final tab = _tabs[index];
            final isSelected = _selectedTabIndex == index;

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTabIndex = index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? (isDark ? Colors.white.withAlpha(15) : const Color(0xFF111827))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected ? null : Border.all(
                      color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        tab.icon,
                        size: 14,
                        color: isSelected 
                            ? (isDark ? Colors.white : Colors.white)
                            : (isDark ? Colors.white54 : const Color(0xFF6B7280)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected 
                              ? (isDark ? Colors.white : Colors.white)
                              : (isDark ? Colors.white54 : const Color(0xFF6B7280)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTagsRow(bool isDark) {
    return ValueListenableBuilder<List<TagModel>>(
      valueListenable: _service.tagsNotifier,
      builder: (context, tags, _) {
        if (tags.isEmpty) return const SizedBox(height: 8);

        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SizedBox(
            height: 28,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: tags.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildTagChip(
                    label: 'All',
                    color: AppColors.primary,
                    isSelected: _selectedTagId == null,
                    onTap: () => setState(() => _selectedTagId = null),
                    isDark: isDark,
                  );
                }

                final tag = tags[index - 1];
                final color = tag.color != null
                    ? Color(int.parse(tag.color!.replaceFirst('#', '0xFF')))
                    : AppColors.primary;

                return _buildTagChip(
                  label: tag.name,
                  color: color,
                  isSelected: _selectedTagId == tag.id,
                  onTap: () => setState(() =>
                      _selectedTagId = _selectedTagId == tag.id ? null : tag.id),
                  isDark: isDark,
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTagChip({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withAlpha(isDark ? 15 : 10),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotesGrid(bool isDark) {
    return ValueListenableBuilder<List<NoteModel>>(
      valueListenable: _service.notesNotifier,
      builder: (context, _, __) {
        final notes = _getFilteredNotes();

        if (notes.isEmpty) {
          return _buildEmptyState(isDark);
        }

        return _isGridView
            ? GridView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.88,
                ),
                itemCount: notes.length,
                itemBuilder: (context, index) => _buildNoteCard(notes[index], isDark),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: notes.length,
                itemBuilder: (context, index) => _buildNoteListTile(notes[index], isDark),
              );
      },
    );
  }

  Widget _buildNoteCard(NoteModel note, bool isDark) {
    Color? cardColor;
    if (note.color != null) {
      try {
        cardColor = Color(int.parse(note.color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }

    final hasColor = cardColor != null;
    final tasks = _service.getTasksForNote(note.id);
    final completedTasks = tasks.where((t) => t.isCompleted).length;

    String preview = '';
    try {
      if (note.content.isNotEmpty && note.content.startsWith('[')) {
        final decoded = jsonDecode(note.content) as List;
        preview = decoded
            .where((op) => op['insert'] is String)
            .map((op) => op['insert'])
            .join()
            .replaceAll('\n', ' ')
            .trim();
      } else {
        preview = note.content;
      }
    } catch (_) {
      preview = note.content;
    }

    return GestureDetector(
      onTap: () => _openNote(note),
      onLongPress: () => _showNoteOptions(note),
      child: Container(
        decoration: BoxDecoration(
          color: hasColor ? cardColor : isDark ? const Color(0xFF1A1A1F) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.isPinned)
                    Icon(
                      Icons.push_pin_rounded,
                      size: 12,
                      color: hasColor ? Colors.white70 : const Color(0xFFF59E0B),
                    ),
                  if (note.isFavorite) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.favorite_rounded,
                      size: 14,
                      color: hasColor ? Colors.white70 : const Color(0xFFEF4444),
                    ),
                  ],
                  if (note.isLocked) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.lock_rounded,
                      size: 12,
                      color: hasColor ? Colors.white70 : const Color(0xFFF59E0B),
                    ),
                  ],
                  if (note.isVoiceNote) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.mic_rounded,
                      size: 14,
                      color: hasColor ? Colors.white70 : const Color(0xFF8B5CF6),
                    ),
                  ],
                  const Spacer(),
                  if (tasks.isNotEmpty)
                    Text(
                      '$completedTasks/${tasks.length}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: hasColor ? Colors.white60 : const Color(0xFF10B981),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                note.title.isEmpty ? 'Untitled' : note.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: hasColor ? Colors.white : isDark ? Colors.white : const Color(0xFF1A1A2E),
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    preview,
                    style: TextStyle(
                      fontSize: 12,
                      color: hasColor
                          ? Colors.white60
                          : isDark
                              ? Colors.white54
                              : Colors.black45,
                      height: 1.35,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                _formatDate(note.updatedAt),
                style: TextStyle(
                  fontSize: 10,
                  color: hasColor
                      ? Colors.white54
                      : isDark
                          ? Colors.white38
                          : Colors.black38,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteListTile(NoteModel note, bool isDark) {
    Color? cardColor;
    if (note.color != null) {
      try {
        cardColor = Color(int.parse(note.color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }

    final hasColor = cardColor != null;

    return GestureDetector(
      onTap: () => _openNote(note),
      onLongPress: () => _showNoteOptions(note),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasColor ? cardColor : isDark ? const Color(0xFF1A1A1F) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: hasColor
                    ? Colors.white.withAlpha(20)
                    : AppColors.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                note.isVoiceNote
                    ? Icons.mic_rounded
                    : note.noteType == NoteType.checklist
                        ? Icons.checklist_rounded
                        : Icons.article_rounded,
                color: hasColor ? Colors.white : AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title.isEmpty ? 'Untitled' : note.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasColor
                          ? Colors.white
                          : isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(note.updatedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: hasColor
                          ? Colors.white60
                          : isDark
                              ? Colors.white54
                              : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            if (note.isPinned)
              Icon(
                Icons.push_pin_rounded,
                size: 14,
                color: hasColor ? Colors.white70 : const Color(0xFFF59E0B),
              ),
            if (note.isFavorite)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.favorite_rounded,
                  size: 14,
                  color: hasColor ? Colors.white70 : const Color(0xFFEF4444),
                ),
              ),
            if (note.isLocked)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.lock_rounded,
                  size: 14,
                  color: hasColor ? Colors.white70 : const Color(0xFFF59E0B),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(8) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.note_add_rounded,
                size: 32,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No notes yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first note and bring\nyour thoughts to life',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActions(bool isDark) {
    return Positioned(
      right: 16,
      bottom: 20,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _openNote(null, type: NoteType.text);
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          setState(() => _showFabMenu = !_showFabMenu);
          if (_showFabMenu) {
            _fabController.forward();
          } else {
            _fabController.reverse();
          }
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildFabOverlay(bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() => _showFabMenu = false);
        _fabController.reverse();
      },
      child: Container(
        color: Colors.black.withAlpha(80),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildFabOption(
                        icon: Icons.article_rounded,
                        label: 'Text',
                        color: const Color(0xFF6366F1),
                        onTap: () {
                          _closeFabMenu();
                          _openNote(null, type: NoteType.text);
                        },
                        delay: 0,
                      ),
                      const SizedBox(height: 8),
                      _buildFabOption(
                        icon: Icons.checklist_rounded,
                        label: 'List',
                        color: const Color(0xFF10B981),
                        onTap: () {
                          _closeFabMenu();
                          _openNote(null, type: NoteType.checklist);
                        },
                        delay: 40,
                      ),
                      const SizedBox(height: 8),
                      _buildFabOption(
                        icon: Icons.mic_rounded,
                        label: 'Voice',
                        color: const Color(0xFF8B5CF6),
                        onTap: () {
                          _closeFabMenu();
                          _openNote(null, type: NoteType.voice);
                        },
                        delay: 80,
                      ),
                      const SizedBox(height: 8),
                      _buildFabOption(
                        icon: Icons.image_rounded,
                        label: 'Image',
                        color: const Color(0xFFF59E0B),
                        onTap: () {
                          _closeFabMenu();
                          _openNote(null, type: NoteType.image);
                        },
                        delay: 120,
                      ),
                      const SizedBox(height: 8),
                      _buildFabOption(
                        icon: Icons.groups_rounded,
                        label: 'Meeting',
                        color: const Color(0xFF0EA5E9),
                        onTap: () {
                          _closeFabMenu();
                          _openNote(null, type: NoteType.meeting);
                        },
                        delay: 160,
                      ),
                      const SizedBox(height: 68),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFabOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 150 + delay),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(30 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  void _closeFabMenu() {
    setState(() => _showFabMenu = false);
    _fabController.reverse();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}';
  }

  void _showNoteOptions(NoteModel note) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _NoteOptionsSheet(
        note: note,
        service: _service,
        isDark: isDark,
        onUpdate: () => setState(() {}),
      ),
    );
  }

  void _showSettingsSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16161C) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Notes Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildSettingsOption(
                icon: Icons.archive_rounded,
                label: 'Archived Notes',
                subtitle: '${_service.getArchivedNotes().length} notes',
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              _buildSettingsOption(
                icon: Icons.delete_rounded,
                label: 'Trash',
                subtitle: '${_service.getTrashNotes().length} notes',
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              _buildSettingsOption(
                icon: Icons.analytics_rounded,
                label: 'Statistics',
                subtitle: 'View your notes activity',
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                  _showStatsSheet(isDark);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }

  void _showStatsSheet(bool isDark) {
    final stats = _service.getDetailedStats();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16161C) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Notes Statistics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.4,
                    children: [
                      _buildStatItem('Total Notes', '${stats['totalNotes']}', Icons.article_rounded, const Color(0xFF6366F1), isDark),
                      _buildStatItem('Total Words', '${stats['totalWords']}', Icons.text_fields_rounded, const Color(0xFF10B981), isDark),
                      _buildStatItem('Pinned', '${stats['pinnedNotes']}', Icons.push_pin_rounded, const Color(0xFFF59E0B), isDark),
                      _buildStatItem('Favorites', '${stats['favoriteNotes']}', Icons.favorite_rounded, const Color(0xFFEF4444), isDark),
                      _buildStatItem('Voice Notes', '${stats['voiceNotes']}', Icons.mic_rounded, const Color(0xFF8B5CF6), isDark),
                      _buildStatItem('With Tasks', '${stats['notesWithTasks']}', Icons.checklist_rounded, const Color(0xFF06B6D4), isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 30 : 15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final String? filter;

  const _TabItem(this.label, this.icon, this.filter);
}

class _NoteOptionsSheet extends StatelessWidget {
  final NoteModel note;
  final NotesService service;
  final bool isDark;
  final VoidCallback onUpdate;

  const _NoteOptionsSheet({
    required this.note,
    required this.service,
    required this.isDark,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                note.title.isEmpty ? 'Untitled' : note.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 20),
            _buildOption(
              context,
              icon: note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              label: note.isPinned ? 'Unpin' : 'Pin to top',
              color: const Color(0xFFF59E0B),
              onTap: () async {
                await service.togglePin(note.id);
                Navigator.pop(context);
                onUpdate();
              },
            ),
            _buildOption(
              context,
              icon: note.isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
              label: note.isFavorite ? 'Remove from favorites' : 'Add to favorites',
              color: const Color(0xFFEF4444),
              onTap: () async {
                await service.toggleFavorite(note.id);
                Navigator.pop(context);
                onUpdate();
              },
            ),
            _buildOption(
              context,
              icon: Icons.copy_rounded,
              label: 'Duplicate',
              color: const Color(0xFF6366F1),
              onTap: () async {
                await service.duplicateNote(note.id);
                Navigator.pop(context);
                onUpdate();
              },
            ),
            _buildOption(
              context,
              icon: note.isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
              label: note.isLocked ? 'Unlock Note' : 'Lock Note',
              color: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.pop(context);
                _showLockDialog(context, note, service, onUpdate);
              },
            ),
            _buildOption(
              context,
              icon: note.isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
              label: note.isArchived ? 'Unarchive' : 'Archive',
              color: const Color(0xFF8B5CF6),
              onTap: () async {
                if (note.isArchived) {
                  await service.unarchiveNote(note.id);
                } else {
                  await service.archiveNote(note.id);
                }
                Navigator.pop(context);
                onUpdate();
              },
            ),
            _buildOption(
              context,
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: AppColors.error,
              onTap: () async {
                await service.deleteNote(note.id);
                Navigator.pop(context);
                onUpdate();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showLockDialog(BuildContext context, NoteModel note, NotesService service, VoidCallback onUpdate) {
    if (note.isLocked) {
      _showUnlockDialog(context, note, service, onUpdate);
    } else {
      _showSetLockDialog(context, note, service, onUpdate);
    }
  }

  void _showSetLockDialog(BuildContext context, NoteModel note, NotesService service, VoidCallback onUpdate) {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Lock Note'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Enter password',
                prefixIcon: const Icon(Icons.password),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Confirm password',
                prefixIcon: const Icon(Icons.password),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a password'), behavior: SnackBarBehavior.floating),
                );
                return;
              }
              if (passwordController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match'), behavior: SnackBarBehavior.floating),
                );
                return;
              }
              if (passwordController.text.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 4 characters'), behavior: SnackBarBehavior.floating),
                );
                return;
              }

              await service.lockNote(note.id, passwordController.text);
              Navigator.pop(context);
              onUpdate();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Note protected with password'),
                  backgroundColor: Colors.green.shade600,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Lock'),
          ),
        ],
      ),
    );
  }

  void _showUnlockDialog(BuildContext context, NoteModel note, NotesService service, VoidCallback onUpdate) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock_open, color: Colors.green, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Remove Lock'),
          ],
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter current password',
            prefixIcon: const Icon(Icons.password),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final verified = await service.verifyNotePassword(note.id, controller.text);
              if (verified) {
                await service.unlockNote(note.id);
                Navigator.pop(context);
                onUpdate();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Password protection removed'),
                    backgroundColor: Colors.green.shade600,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Incorrect password'),
                    backgroundColor: Colors.red.shade600,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove Lock'),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color == AppColors.error
                    ? color
                    : isDark
                        ? Colors.white
                        : const Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

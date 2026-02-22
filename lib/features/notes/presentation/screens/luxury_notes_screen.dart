import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/note_model.dart';
import '../../data/models/tag_model.dart';
import '../../data/repositories/notes_repository.dart';
import 'note_editor_screen.dart';
import '../../../backup/presentation/screens/backup_settings_screen.dart';
import '../../../reminders/screens/add_reminder_screen.dart';
import '../../../../core/constants/app_colors.dart';

class LuxuryNotesScreen extends StatefulWidget {
  const LuxuryNotesScreen({super.key});

  @override
  State<LuxuryNotesScreen> createState() => _LuxuryNotesScreenState();
}

class _LuxuryNotesScreenState extends State<LuxuryNotesScreen>
    with TickerProviderStateMixin {
  final NotesRepository _repository = NotesRepository();
  late AnimationController _fabAnimationController;
  late AnimationController _tabAnimationController;
  int _selectedTabIndex = 0;
  
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedTagId;
  String _sortBy = 'updated';
  bool _isGridView = true;

  // Note colors for luxury feel
  static const List<Color> noteColors = [
    Color(0xFF1A1F3A), // Default dark
    Color(0xFF2D1B69), // Deep Purple
    Color(0xFF1B4332), // Forest Green
    Color(0xFF7C2D12), // Burnt Orange
    Color(0xFF1E3A5F), // Ocean Blue
    Color(0xFF4A1942), // Wine
    Color(0xFF2F4858), // Steel Blue
    Color(0xFF3D2914), // Coffee
  ];

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _tabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _initializeNotes();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _tabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeNotes() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() => _isLoading = false);
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
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: _isLoading ? _buildLoadingState() : _buildMainContent(),
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: AppColors.primary,
        elevation: 2,
        onPressed: _createNewNote,
        child: const Icon(Icons.add_rounded, size: 20),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your notes...',
            style: TextStyle(
              color: AppColors.getTextSecondary(context),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        _buildLuxuryAppBar(),
        _buildSearchBar(),
        _buildCategoryTabs(),
      ],
      body: _buildNotesContent(),
    );
  }

  Widget _buildLuxuryAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      expandedHeight: 72,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'My Notes',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 22,
                            color: AppColors.getTextPrimary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildIconButton(
                    icon: _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                    onTap: () => setState(() => _isGridView = !_isGridView),
                  ),
                  const SizedBox(width: 8),
                  _buildIconButton(
                    icon: Icons.cloud_sync_rounded,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BackupSettingsScreen()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildIconButton(
                    icon: Icons.more_vert_rounded,
                    onTap: _showOptionsMenu,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.getCardBg(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.getBorder(context).withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.getShadow(context).withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Icon(
              icon, 
              color: AppColors.getTextPrimary(context), 
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Container(
          decoration: AppColors.getLuxuryCardDecoration(context, borderRadius: 16),
          child: TextField(
            style: TextStyle(
              color: AppColors.getTextPrimary(context),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Search notes, tags, folders...',
              hintStyle: TextStyle(
                color: AppColors.getTextLight(context),
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 12),
                child: Icon(Icons.search_rounded, 
                  color: AppColors.primary.withOpacity(0.7), 
                  size: 24
                ),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        icon: Icon(Icons.clear_rounded, 
                          color: AppColors.getTextSecondary(context),
                          size: 20,
                        ),
                        onPressed: () => setState(() => _searchQuery = ''),
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
      ),
    );
  }

  // Tab data
  static const List<_TabItem> _tabItems = [
    _TabItem(icon: Icons.notes_rounded, label: 'All'),
    _TabItem(icon: Icons.push_pin_rounded, label: 'Pinned'),
    _TabItem(icon: Icons.checklist_rounded, label: 'Tasks'),
    _TabItem(icon: Icons.archive_rounded, label: 'Archive'),
  ];

  Widget _buildCategoryTabs() {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          _buildTagsRow(),
          const SizedBox(height: 20),
          Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.getCardBg(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.getBorder(context).withOpacity(0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.getShadow(context).withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tabWidth = constraints.maxWidth / 4;
                  return Stack(
                    children: [
                      // Sliding indicator
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        left: _selectedTabIndex * tabWidth,
                        top: 0,
                        bottom: 0,
                        width: tabWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      // Tab row
                      Row(
                        children: List.generate(4, (index) {
                          final isActive = _selectedTabIndex == index;
                          final item = _tabItems[index];
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTabIndex = index),
                              behavior: HitTestBehavior.opaque,
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : AppColors.getTextSecondary(context),
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 13,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      transitionBuilder: (child, animation) {
                                        return ScaleTransition(
                                          scale: animation,
                                          child: child,
                                        );
                                      },
                                      child: Icon(
                                        item.icon,
                                        key: ValueKey('${index}_$isActive'),
                                        size: 16,
                                        color: isActive
                                            ? Colors.white
                                            : AppColors.getTextSecondary(context),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(item.label),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTagsRow() {
    return ValueListenableBuilder<Box<TagModel>>(
      valueListenable: Hive.box<TagModel>('tags').listenable(),
      builder: (context, box, _) {
        final tags = box.values.toList();
        
        return SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: tags.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildTagChip(
                  label: 'All',
                  color: AppColors.primary,
                  isSelected: _selectedTagId == null,
                  onTap: () => setState(() => _selectedTagId = null),
                );
              }
              if (index == tags.length + 1) {
                return _buildAddTagChip();
              }
              final tag = tags[index - 1];
              return _buildTagChip(
                label: tag.name,
                color: tag.color != null ? Color(int.parse(tag.color!.replaceFirst('#', '0xFF'))) : Colors.blue,
                isSelected: _selectedTagId == tag.id,
                onTap: () => setState(() => _selectedTagId = tag.id),
              );
            },
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: color,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddTagChip() {
    return GestureDetector(
      onTap: _showCreateTagDialog,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.getBorder(context),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 18, color: AppColors.getTextSecondary(context)),
            const SizedBox(width: 6),
            Text(
              'Add Tag',
              style: TextStyle(
                color: AppColors.getTextSecondary(context),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesContent() {
    return ValueListenableBuilder<Box<NoteModel>>(
      valueListenable: _repository.notesListenable,
      builder: (context, box, _) {
        List<NoteModel> notes = _getFilteredNotes();
        
        if (notes.isEmpty) {
          return _buildEmptyState();
        }

        if (_isGridView) {
          return MasonryGridView.count(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemCount: notes.length,
            itemBuilder: (context, index) => _buildLuxuryNoteCard(notes[index]),
          );
        } else {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            itemCount: notes.length,
            itemBuilder: (context, index) => _buildLuxuryNoteListTile(notes[index]),
          );
        }
      },
    );
  }

  List<NoteModel> _getFilteredNotes() {
    var notes = _repository.getActiveNotes();

    // Filter by tab
    switch (_selectedTabIndex) {
      case 1: // Pinned
        notes = notes.where((n) => n.isPinned).toList();
        break;
      case 2: // Tasks (checklists)
        notes = notes.where((n) => n.hasUncheckedItems).toList();
        break;
      case 3: // Archive
        notes = _repository.getArchivedNotes();
        break;
    }

    // Filter by tag
    if (_selectedTagId != null) {
      notes = notes.where((n) => n.tagIds.contains(_selectedTagId)).toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      notes = notes.where((n) =>
          n.title.toLowerCase().contains(query) ||
          n.content.toLowerCase().contains(query)).toList();
    }

    // Sort
    notes.sort((a, b) {
      // Pinned first
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      // Then by date
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return notes;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add_rounded,
            size: 64,
            color: AppColors.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Start capturing ideas',
            style: TextStyle(
              color: AppColors.getTextPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _createNewNote,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Create Note',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLuxuryNoteCard(NoteModel note) {
    final noteColor = note.color != null
        ? Color(int.parse(note.color!.replaceFirst('#', '0xFF')))
        : noteColors[0];

    return GestureDetector(
      onTap: () => _openNote(note),
      onLongPress: () => _showNoteOptions(note),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              noteColor.withOpacity(0.9),
              noteColor.withOpacity(0.65),
            ],
            stops: const [0.1, 0.9],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: noteColor.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // Glass overly effect
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (note.isPinned)
                           Container(
                             padding: const EdgeInsets.all(6),
                             decoration: BoxDecoration(
                               color: Colors.black.withOpacity(0.2),
                               shape: BoxShape.circle,
                             ),
                             child: const Icon(Icons.push_pin_rounded, size: 14, color: Colors.amberAccent)
                           ),
                        if (note.isPinned) const Spacer(),
                        if (note.reminderId != null)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications_active_rounded, size: 14, color: Colors.white)
                          ),
                      ],
                    ),
                    SizedBox(height: note.isPinned || note.reminderId != null ? 12 : 0),
                    // Title
                    Text(
                      note.title.isEmpty ? 'Untitled' : note.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    // Content preview
                    Text(
                      _getContentPreview(note.content),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    // Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(note.updatedAt),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (note.tagIds.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Text(
                              '${note.tagIds.length} tags',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLuxuryNoteListTile(NoteModel note) {
    final noteColor = note.color != null
        ? Color(int.parse(note.color!.replaceFirst('#', '0xFF')))
        : noteColors[0];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            noteColor.withOpacity(0.9),
            noteColor.withOpacity(0.65),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: noteColor.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        onTap: () => _openNote(note),
        onLongPress: () => _showNoteOptions(note),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Icon(
            note.hasUncheckedItems ? Icons.checklist_rounded : Icons.description_rounded,
            color: Colors.white.withOpacity(0.9),
            size: 24,
          ),
        ),
        title: Row(
          children: [
            if (note.isPinned)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.push_pin_rounded, size: 14, color: Colors.amberAccent),
              ),
            Expanded(
              child: Text(
                note.title.isEmpty ? 'Untitled' : note.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              _getContentPreview(note.content),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              _formatDate(note.updatedAt),
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: note.reminderId != null
            ? Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_rounded, size: 16, color: Colors.white)
              )
            : null,
      ),
    );
  }

  Widget _buildLuxuryFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF00695C)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _createNewNote,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 26),
                SizedBox(width: 10),
                Text(
                  'New Note',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper methods
  String _getContentPreview(String content) {
    // Simple text extraction - remove JSON formatting if present
    if (content.trim().startsWith('[')) {
      try {
        // It's likely Quill delta JSON, extract plain text
        return content
            .replaceAll(RegExp(r'[\[\]{}"]'), '')
            .replaceAll(RegExp(r'insert:|attributes:|\n'), ' ')
            .trim();
      } catch (_) {
        return content;
      }
    }
    return content;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${date.day}/${date.month}/${date.year}';
  }

  void _openNote(NoteModel note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorScreen(noteId: note.id)),
    ).then((_) => setState(() {}));
  }

  void _createNewNote() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
    ).then((_) => setState(() {}));
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.getModalBackground(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: AppColors.getTextLight(context).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildOptionTile(
                icon: Icons.label_rounded,
                title: 'Manage Tags',
                onTap: () {
                  Navigator.pop(context);
                  _showTagsManagement();
                },
              ),
              _buildOptionTile(
                icon: Icons.delete_outline_rounded,
                title: 'Trash',
                onTap: () {
                  Navigator.pop(context);
                  _showTrashSheet();
                },
              ),
              _buildOptionTile(
                icon: Icons.cloud_sync_rounded,
                title: 'Sync & Backup',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupSettingsScreen()));
                },
              ),
              _buildOptionTile(
                icon: Icons.sort_rounded,
                title: 'Sort Notes',
                onTap: () {
                  Navigator.pop(context);
                  _showSortOptions();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: TextStyle(color: AppColors.getTextPrimary(context))),
      onTap: onTap,
    );
  }

  void _showNoteOptions(NoteModel note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.getModalBackground(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: AppColors.getTextLight(context).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildOptionTile(
                icon: note.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                title: note.isPinned ? 'Unpin' : 'Pin to top',
                onTap: () {
                  Navigator.pop(context);
                  _repository.togglePin(note.id);
                  setState(() {});
                },
              ),
              _buildOptionTile(
                icon: Icons.palette_rounded,
                title: 'Change Color',
                onTap: () {
                  Navigator.pop(context);
                  _showColorPicker(note);
                },
              ),
              _buildOptionTile(
                icon: Icons.label_rounded,
                title: 'Add Tags',
                onTap: () {
                  Navigator.pop(context);
                  _showAddTagsDialog(note);
                },
              ),
              _buildOptionTile(
                icon: Icons.notifications_rounded,
                title: 'Set Reminder',
                onTap: () {
                  Navigator.pop(context);
                  _showSetReminderDialog(note);
                },
              ),
              _buildOptionTile(
                icon: Icons.archive_rounded,
                title: note.isArchived ? 'Unarchive' : 'Archive',
                onTap: () {
                  Navigator.pop(context);
                  if (note.isArchived) {
                    _repository.unarchiveNote(note.id);
                  } else {
                    _repository.archiveNote(note.id);
                  }
                  setState(() {});
                },
              ),
              _buildOptionTile(
                icon: Icons.delete_rounded,
                title: 'Delete',
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(note);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPicker(NoteModel note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getModalBackground(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Choose Color', style: TextStyle(color: AppColors.getTextPrimary(context))),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: noteColors.map((color) {
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _repository.updateNote(note.copyWith(
                  color: '#${color.value.toRadixString(16).substring(2)}',
                ));
                setState(() {});
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.getBorder(context), width: 2),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _confirmDelete(NoteModel note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getModalBackground(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Note?', style: TextStyle(color: AppColors.getTextPrimary(context))),
        content: Text(
          'This note will be moved to trash.',
          style: TextStyle(color: AppColors.getTextSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _repository.deleteNote(note.id);
              setState(() {});
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showCreateTagDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getModalBackground(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('New Tag', style: TextStyle(color: AppColors.getTextPrimary(context))),
        content: TextField(
          controller: controller,
          style: TextStyle(color: AppColors.getTextPrimary(context)),
          decoration: InputDecoration(
            hintText: 'Tag name',
            hintStyle: TextStyle(color: AppColors.getTextLight(context)),
            filled: true,
            fillColor: AppColors.isDark(context) ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _repository.createTag(controller.text);
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showTagsManagement() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.getModalBackground(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.getTextLight(context).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Manage Tags',
                      style: TextStyle(
                        color: AppColors.getTextPrimary(context),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ValueListenableBuilder<Box<TagModel>>(
                  valueListenable: Hive.box<TagModel>('tags').listenable(),
                  builder: (context, box, _) {
                    final tags = box.values.toList();
                    if (tags.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.label_outline, size: 64, color: AppColors.getTextLight(context)),
                            const SizedBox(height: 16),
                            Text(
                              'No tags yet',
                              style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: tags.length,
                      itemBuilder: (context, index) {
                        final tag = tags[index];
                        final tagColor = tag.color != null
                            ? Color(int.parse(tag.color!.replaceFirst('#', '0xFF')))
                            : const Color(0xFFD4AF37);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.getCardBg(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: tagColor.withOpacity(0.3)),
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: tagColor.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.label, color: tagColor, size: 20),
                            ),
                            title: Text(
                              tag.name,
                              style: TextStyle(color: AppColors.getTextPrimary(context), fontWeight: FontWeight.w600),
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, color: AppColors.error),
                              onPressed: () async {
                                await _repository.deleteTag(tag.id);
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showCreateTagDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Create New Tag',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrashSheet() {
    // Navigate to trash view by setting tab
    _selectedTabIndex = 3;
    setState(() {});
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.getModalBackground(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Sort By', style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              _buildSortOption('Last Updated', 'updated'),
              _buildSortOption('Created Date', 'created'),
              _buildSortOption('Title', 'title'),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOption(String title, String value) {
    return ListTile(
      leading: Radio<String>(
        value: value,
        groupValue: _sortBy,
        activeColor: AppColors.primary,
        onChanged: (v) {
          setState(() => _sortBy = v!);
          Navigator.pop(context);
        },
      ),
      title: Text(title, style: TextStyle(color: AppColors.getTextPrimary(context))),
      onTap: () {
        setState(() => _sortBy = value);
        Navigator.pop(context);
      },
    );
  }

  void _showAddTagsDialog(NoteModel note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.getModalBackground(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.getTextLight(context).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Add Tags',
                  style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<Box<TagModel>>(
                valueListenable: Hive.box<TagModel>('tags').listenable(),
                builder: (context, box, _) {
                  final tags = box.values.toList();
                  if (tags.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No tags available. Create tags first.',
                        style: TextStyle(color: AppColors.getTextSecondary(context)),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      final tag = tags[index];
                      final isSelected = note.tagIds.contains(tag.id);
                      final tagColor = tag.color != null
                          ? Color(int.parse(tag.color!.replaceFirst('#', '0xFF')))
                          : AppColors.primary;
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) async {
                          if (value == true) {
                            await _repository.addTagToNote(note.id, tag.id);
                          } else {
                            await _repository.removeTagFromNote(note.id, tag.id);
                          }
                          setState(() {});
                        },
                        title: Text(tag.name, style: TextStyle(color: AppColors.getTextPrimary(context))),
                        activeColor: tagColor,
                        checkColor: Colors.black,
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showSetReminderDialog(NoteModel note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddReminderScreen(noteId: note.id),
      ),
    );
    setState(() {});
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem({required this.icon, required this.label});
}

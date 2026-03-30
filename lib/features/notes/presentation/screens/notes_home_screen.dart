import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/note_model.dart';
import '../../data/services/notes_service.dart';
import '../../theme/evernote_theme.dart';
import '../widgets/notes_bottom_nav.dart';
import '../widgets/note_card.dart';
import '../widgets/notes_header.dart';
import '../widgets/category_chips.dart';
import '../widgets/notes_search_bar.dart';
import '../widgets/notes_drawer.dart';
import 'notes_search_screen.dart';
import 'notes_tasks_screen.dart';
import 'notes_tags_screen.dart';
import 'notes_notebooks_screen.dart';
import 'notes_settings_screen.dart';
import 'evernote_note_editor.dart';

/// Main Notes home screen with Evernote-style dark UI
/// Features: header, search, category tabs, note cards grid
class NotesHomeScreen extends StatefulWidget {
  const NotesHomeScreen({super.key});

  @override
  State<NotesHomeScreen> createState() => _NotesHomeScreenState();
}

class _NotesHomeScreenState extends State<NotesHomeScreen>
    with TickerProviderStateMixin {
  final NotesService _notesService = NotesService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  int _currentNavIndex = 0;
  String _selectedCategory = 'All';
  bool _isGridView = true;
  bool _isLoading = true;
  List<NoteModel> _notes = [];

  final List<String> _categories = [
    'All',
    'Work',
    'Personal',
    'Ideas',
    'Archive',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: EvernoteTheme.durationSlow,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: EvernoteTheme.curveDefault,
    );
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    await _notesService.initialize();
    
    if (mounted) {
      setState(() {
        _notes = _notesService.getActiveNotes();
        _isLoading = false;
      });
      _fadeController.forward();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  List<NoteModel> get _filteredNotes {
    if (_selectedCategory == 'All') {
      return _notes;
    } else if (_selectedCategory == 'Archive') {
      return _notesService.getArchivedNotes();
    }
    // Filter by tag/category name
    return _notes.where((note) {
      // Match by folder or tag
      return note.tagIds.any((tagId) {
        final tag = _notesService.getTag(tagId);
        return tag?.name.toLowerCase() == _selectedCategory.toLowerCase();
      });
    }).toList();
  }

  void _onNavTap(int index) {
    if (index == _currentNavIndex) return;
    
    setState(() => _currentNavIndex = index);
    
    // Navigate to different screens based on index
    switch (index) {
      case 1: // Tasks
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotesTasksScreen()),
        );
        setState(() => _currentNavIndex = 0);
        break;
      case 2: // Tags
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotesTagsScreen()),
        );
        setState(() => _currentNavIndex = 0);
        break;
      case 3: // Settings
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotesSettingsScreen()),
        );
        setState(() => _currentNavIndex = 0);
        break;
    }
  }

  void _onNewNoteTap() {
    HapticFeedback.mediumImpact();
    _createNewNote();
  }

  void _createNewNote() async {
    // Create new note and navigate to editor
    final noteId = await _notesService.createNote(
      title: '',
      content: '',
    );
    if (mounted && noteId.isNotEmpty) {
      final note = _notesService.getNote(noteId);
      if (note != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EvernoteNoteEditor(note: note),
          ),
        );
        _loadNotes(); // Refresh list on return
      }
    }
  }

  void _onCategoryChanged(String category) {
    HapticFeedback.selectionClick();
    setState(() => _selectedCategory = category);
  }

  void _toggleViewMode() {
    HapticFeedback.selectionClick();
    setState(() => _isGridView = !_isGridView);
  }

  void _openNote(NoteModel note) async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EvernoteNoteEditor(note: note),
      ),
    );
    if (mounted) {
      _loadNotes(); // Refresh list on return
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: EvernoteTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    return NotesScaffold(
      scaffoldKey: _scaffoldKey,
      currentNavIndex: _currentNavIndex,
      onNavTap: _onNavTap,
      onNewNoteTap: _onNewNoteTap,
      drawer: NotesDrawer(
        onAllNotesTap: () => setState(() => _selectedCategory = 'All'),
        onTasksTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotesTasksScreen()),
        ),
        onNotebooksTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotesNotebooksScreen()),
        ),
        onTagsTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotesTagsScreen()),
        ),
        onSettingsTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotesSettingsScreen()),
        ),
      ),
      body: _isLoading ? _buildLoading() : _buildBody(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        color: EvernoteTheme.primary,
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildBody() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _loadNotes,
        color: EvernoteTheme.primary,
        backgroundColor: EvernoteTheme.surface,
        child: CustomScrollView(
          slivers: [
            // Header with menu, avatar and greeting
            SliverToBoxAdapter(
              child: NotesHeader(
                onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                onProfileTap: () {},
                onNotificationTap: () {},
              ),
            ),
            
            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: NotesSearchBar(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotesSearchScreen()),
                    );
                  },
                ),
              ),
            ),
            
            // Category chips
            SliverToBoxAdapter(
              child: CategoryChips(
                categories: _categories,
                selectedCategory: _selectedCategory,
                onCategoryChanged: _onCategoryChanged,
              ),
            ),
            
            // Section header with view toggle
            SliverToBoxAdapter(
              child: _buildSectionHeader(),
            ),
            
            // Notes grid/list
            _filteredNotes.isEmpty
                ? SliverFillRemaining(child: _buildEmptyState())
                : _isGridView
                    ? _buildNotesGrid()
                    : _buildNotesList(),
            
            // Bottom padding for nav
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _selectedCategory == 'All' ? 'All Notes' : _selectedCategory,
            style: EvernoteTheme.headlineSmall,
          ),
          Row(
            children: [
              Text(
                '${_filteredNotes.length} notes',
                style: EvernoteTheme.bodySmall.copyWith(
                  color: EvernoteTheme.textTertiary,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _toggleViewMode,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EvernoteTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isGridView 
                        ? Icons.view_list_rounded 
                        : Icons.grid_view_rounded,
                    size: 20,
                    color: EvernoteTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => NoteCard(
            note: _filteredNotes[index],
            onTap: () => _openNote(_filteredNotes[index]),
            onLongPress: () => _showNoteOptions(_filteredNotes[index]),
          ),
          childCount: _filteredNotes.length,
        ),
      ),
    );
  }

  Widget _buildNotesList() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final note = _filteredNotes[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NoteCard(
                note: note,
                isListView: true,
                onTap: () => _openNote(note),
                onLongPress: () => _showNoteOptions(note),
                onDelete: () => _deleteNote(note),
                onArchive: () => _archiveNote(note),
              ),
            );
          },
          childCount: _filteredNotes.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon container with glow
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  EvernoteTheme.primary.withOpacity(0.15),
                  EvernoteTheme.primaryDark.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: EvernoteTheme.primary.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.note_add_outlined,
              size: 48,
              color: EvernoteTheme.primary,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _selectedCategory == 'All' 
                ? 'No notes yet' 
                : 'No notes in $_selectedCategory',
            style: EvernoteTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Tap the + button to create your first note',
            style: EvernoteTheme.bodyMedium.copyWith(
              color: EvernoteTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 32),
          // Quick create button
          GestureDetector(
            onTap: _onNewNoteTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: EvernoteTheme.primaryGradient,
                borderRadius: BorderRadius.circular(EvernoteTheme.radiusFull),
                boxShadow: [
                  BoxShadow(
                    color: EvernoteTheme.primary.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: EvernoteTheme.textOnPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Create Note',
                    style: EvernoteTheme.labelLarge.copyWith(
                      color: EvernoteTheme.textOnPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNoteOptions(NoteModel note) {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: EvernoteTheme.modalDecoration,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EvernoteTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Note title
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  note.title.isEmpty ? 'Untitled' : note.title,
                  style: EvernoteTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              _OptionTile(
                icon: note.isPinned 
                    ? Icons.push_pin_rounded 
                    : Icons.push_pin_outlined,
                label: note.isPinned ? 'Unpin' : 'Pin to top',
                onTap: () {
                  Navigator.pop(ctx);
                  _togglePin(note);
                },
              ),
              _OptionTile(
                icon: note.isFavorite 
                    ? Icons.star_rounded 
                    : Icons.star_outline_rounded,
                label: note.isFavorite ? 'Remove favorite' : 'Add to favorites',
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleFavorite(note);
                },
              ),
              _OptionTile(
                icon: Icons.archive_outlined,
                label: 'Archive',
                onTap: () {
                  Navigator.pop(ctx);
                  _archiveNote(note);
                },
              ),
              _OptionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteNote(note);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _togglePin(NoteModel note) async {
    await _notesService.updateNote(note.copyWith(isPinned: !note.isPinned));
    _loadNotes();
  }

  void _toggleFavorite(NoteModel note) async {
    await _notesService.updateNote(note.copyWith(isFavorite: !note.isFavorite));
    _loadNotes();
  }

  void _archiveNote(NoteModel note) async {
    await _notesService.archiveNote(note.id);
    _loadNotes();
  }

  void _deleteNote(NoteModel note) async {
    await _notesService.deleteNote(note.id);
    _loadNotes();
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive 
        ? EvernoteTheme.error 
        : EvernoteTheme.textPrimary;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 16),
            Text(
              label,
              style: EvernoteTheme.bodyLarge.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

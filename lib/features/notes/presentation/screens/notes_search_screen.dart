import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/note_model.dart';
import '../../data/services/notes_service.dart';
import '../../theme/evernote_theme.dart';
import '../widgets/notes_search_bar.dart';
import '../widgets/note_card.dart';

/// Search screen for notes with filters and recent searches
class NotesSearchScreen extends StatefulWidget {
  const NotesSearchScreen({super.key});

  @override
  State<NotesSearchScreen> createState() => _NotesSearchScreenState();
}

class _NotesSearchScreenState extends State<NotesSearchScreen> {
  final NotesService _notesService = NotesService();
  final TextEditingController _searchController = TextEditingController();
  
  List<NoteModel> _searchResults = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Notes', 'Checklists', 'Voice', 'With Images'];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  void _loadRecentSearches() {
    // TODO: Load from SharedPreferences
    _recentSearches = ['Meeting notes', 'Project ideas', 'Shopping list'];
  }

  void _saveRecentSearch(String query) {
    if (query.isEmpty || _recentSearches.contains(query)) return;
    setState(() {
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 10) {
        _recentSearches.removeLast();
      }
    });
    // TODO: Save to SharedPreferences
  }

  void _search(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final results = _notesService.searchNotes(query);
    
    // Apply filter
    List<NoteModel> filtered;
    switch (_selectedFilter) {
      case 'Notes':
        filtered = results.where((n) => n.noteType == NoteType.text).toList();
        break;
      case 'Checklists':
        filtered = results.where((n) => n.noteType == NoteType.checklist).toList();
        break;
      case 'Voice':
        filtered = results.where((n) => n.voiceRecordingPath != null).toList();
        break;
      case 'With Images':
        filtered = results.where((n) => n.coverImagePath != null || n.attachments.isNotEmpty).toList();
        break;
      default:
        filtered = results;
    }

    setState(() {
      _searchResults = filtered;
      _isSearching = false;
    });
  }

  void _onFilterChanged(String filter) {
    HapticFeedback.selectionClick();
    setState(() => _selectedFilter = filter);
    _search(_searchController.text);
  }

  void _clearRecentSearch(String search) {
    HapticFeedback.lightImpact();
    setState(() {
      _recentSearches.remove(search);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EvernoteTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with search bar
            _buildHeader(),
            
            // Filter chips
            _buildFilters(),
            
            // Content
            Expanded(
              child: _searchController.text.isEmpty
                  ? _buildRecentSearches()
                  : _buildSearchResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: EvernoteTheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: EvernoteTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Search bar
          Expanded(
            child: NotesSearchBar(
              controller: _searchController,
              autofocus: true,
              showFilter: false,
              onChanged: (query) {
                _search(query);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = filter == _selectedFilter;
          
          return Padding(
            padding: EdgeInsets.only(right: index < _filters.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => _onFilterChanged(filter),
              child: AnimatedContainer(
                duration: EvernoteTheme.durationFast,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected ? EvernoteTheme.primary : EvernoteTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? EvernoteTheme.primary : EvernoteTheme.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected 
                          ? EvernoteTheme.textOnPrimary 
                          : EvernoteTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Searches',
              style: EvernoteTheme.titleMedium.copyWith(
                color: EvernoteTheme.textSecondary,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _recentSearches.clear());
              },
              child: Text(
                'Clear all',
                style: EvernoteTheme.bodySmall.copyWith(
                  color: EvernoteTheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        ..._recentSearches.map((search) => _RecentSearchTile(
          search: search,
          onTap: () {
            _searchController.text = search;
            _search(search);
          },
          onDelete: () => _clearRecentSearch(search),
        )),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          color: EvernoteTheme.primary,
          strokeWidth: 2,
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: EvernoteTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: EvernoteTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: EvernoteTheme.bodyMedium.copyWith(
                color: EvernoteTheme.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: NotePreviewTile(
            note: _searchResults[index],
            highlightText: _searchController.text,
            onTap: () {
              _saveRecentSearch(_searchController.text);
              // TODO: Navigate to note
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: EvernoteTheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.search_rounded,
              size: 40,
              color: EvernoteTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Search your notes',
            style: EvernoteTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Find notes by title or content',
            style: EvernoteTheme.bodyMedium.copyWith(
              color: EvernoteTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSearchTile extends StatelessWidget {
  final String search;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecentSearchTile({
    required this.search,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.history_rounded,
              size: 20,
              color: EvernoteTheme.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                search,
                style: EvernoteTheme.bodyMedium,
              ),
            ),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: EvernoteTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

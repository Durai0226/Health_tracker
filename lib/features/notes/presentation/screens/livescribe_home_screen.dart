import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/notebook_model.dart';
import '../../data/models/page_model.dart';
import '../../theme/livescribe_theme.dart';
import '../widgets/livescribe_notebook_card.dart';
import '../widgets/livescribe_search_bar.dart';
import 'livescribe_canvas_screen.dart';

/// Main home screen for Livescribe Notes feature
/// Clean minimalist design inspired by Livescribe app
class LivescribeHomeScreen extends StatefulWidget {
  const LivescribeHomeScreen({super.key});

  @override
  State<LivescribeHomeScreen> createState() => _LivescribeHomeScreenState();
}

class _LivescribeHomeScreenState extends State<LivescribeHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  
  // Mock data - will be replaced with NotebookService
  List<NotebookModel> _notebooks = [];

  final List<_TabItem> _tabs = [
    _TabItem('All', Icons.grid_view_rounded),
    _TabItem('Recent', Icons.access_time_rounded),
    _TabItem('Favorites', Icons.star_rounded),
    _TabItem('Shared', Icons.people_outline_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: LivescribeTheme.durationSlow,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: LivescribeTheme.curveDefault,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    // TODO: Replace with actual NotebookService
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Create mock data
    final now = DateTime.now();
    _notebooks = [
      NotebookModel.create(
        id: '1',
        title: 'Meeting Notes',
        coverColor: '#0066FF',
        defaultTemplate: NotebookTemplate.lined,
      ).copyWith(pageCount: 5, updatedAt: now.subtract(const Duration(hours: 2))),
      NotebookModel.create(
        id: '2',
        title: 'Project Ideas',
        coverColor: '#10B981',
        defaultTemplate: NotebookTemplate.blank,
      ).copyWith(pageCount: 12, updatedAt: now.subtract(const Duration(days: 1))),
      NotebookModel.create(
        id: '3',
        title: 'Daily Journal',
        coverColor: '#8B5CF6',
        defaultTemplate: NotebookTemplate.lined,
      ).copyWith(pageCount: 30, isPinned: true, updatedAt: now.subtract(const Duration(hours: 5))),
      NotebookModel.create(
        id: '4',
        title: 'Sketches',
        coverColor: '#F59E0B',
        defaultTemplate: NotebookTemplate.grid,
      ).copyWith(pageCount: 8, updatedAt: now.subtract(const Duration(days: 3))),
    ];
    
    if (mounted) {
      setState(() => _isLoading = false);
      _fadeController.forward();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<NotebookModel> get _filteredNotebooks {
    var notebooks = List<NotebookModel>.from(_notebooks);
    
    // Filter by tab
    switch (_selectedTabIndex) {
      case 1: // Recent
        notebooks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        notebooks = notebooks.take(10).toList();
        break;
      case 2: // Favorites
        notebooks = notebooks.where((n) => n.isPinned).toList();
        break;
      case 3: // Shared
        // TODO: Implement shared notebooks
        notebooks = [];
        break;
    }
    
    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      notebooks = notebooks.where((n) => 
        n.title.toLowerCase().contains(query) ||
        (n.description?.toLowerCase().contains(query) ?? false)
      ).toList();
    }
    
    // Sort: pinned first, then by date
    notebooks.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    
    return notebooks;
  }

  void _createNewNotebook() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LivescribeCanvasScreen(isNewNotebook: true),
      ),
    ).then((_) => _loadData());
  }

  void _openNotebook(NotebookModel notebook) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LivescribeCanvasScreen(notebook: notebook),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: isDark ? LivescribeTheme.darkSurface : LivescribeTheme.surfaceLight,
      body: _isLoading ? _buildLoading(isDark) : _buildBody(isDark),
      floatingActionButton: _buildFab(isDark),
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
              color: LivescribeTheme.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: LivescribeTheme.shadowPrimary,
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
            'Loading notebooks...',
            style: LivescribeTheme.bodyMedium.copyWith(
              color: isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(child: _buildHeader(isDark)),
            
            // Search bar
            SliverToBoxAdapter(child: _buildSearchBar(isDark)),
            
            // Quick stats
            SliverToBoxAdapter(child: _buildQuickStats(isDark)),
            
            // Tabs
            SliverToBoxAdapter(child: _buildTabs(isDark)),
            
            // Notebooks grid
            _buildNotebooksGrid(isDark),
            
            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Notebooks',
                  style: LivescribeTheme.headlineMedium.copyWith(
                    color: isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_notebooks.length} notebooks',
                  style: LivescribeTheme.bodySmall.copyWith(
                    color: isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // Settings button
          GestureDetector(
            onTap: () => _showSettingsSheet(isDark),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.more_horiz_rounded,
                size: 20,
                color: isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: LivescribeSearchBar(
        controller: _searchController,
        hintText: 'Search notebooks...',
        onChanged: (value) => setState(() => _searchQuery = value),
        onClear: () {
          _searchController.clear();
          setState(() => _searchQuery = '');
        },
      ),
    );
  }

  Widget _buildQuickStats(bool isDark) {
    final totalPages = _notebooks.fold<int>(0, (sum, n) => sum + n.pageCount);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.book_outlined,
            label: 'Notebooks',
            value: '${_notebooks.length}',
            color: LivescribeTheme.primary,
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.article_outlined,
            label: 'Pages',
            value: '$totalPages',
            color: LivescribeTheme.success,
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.star_outline_rounded,
            label: 'Favorites',
            value: '${_notebooks.where((n) => n.isPinned).length}',
            color: LivescribeTheme.warning,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _tabs.length,
          itemBuilder: (context, index) {
            final tab = _tabs[index];
            final isSelected = _selectedTabIndex == index;
            
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTabIndex = index);
                },
                child: AnimatedContainer(
                  duration: LivescribeTheme.durationFast,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? LivescribeTheme.primary 
                        : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        tab.icon,
                        size: 16,
                        color: isSelected 
                            ? Colors.white 
                            : (isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected 
                              ? Colors.white 
                              : (isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary),
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

  Widget _buildNotebooksGrid(bool isDark) {
    final notebooks = _filteredNotebooks;
    
    if (notebooks.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(isDark),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => LivescribeNotebookCard(
            notebook: notebooks[index],
            onTap: () => _openNotebook(notebooks[index]),
            onLongPress: () => _showNotebookOptions(notebooks[index]),
          ),
          childCount: notebooks.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    String message;
    IconData icon;
    
    switch (_selectedTabIndex) {
      case 1:
        message = 'No recent notebooks';
        icon = Icons.access_time_rounded;
        break;
      case 2:
        message = 'No favorite notebooks';
        icon = Icons.star_outline_rounded;
        break;
      case 3:
        message = 'No shared notebooks';
        icon = Icons.people_outline_rounded;
        break;
      default:
        message = _searchQuery.isNotEmpty 
            ? 'No notebooks found' 
            : 'Create your first notebook';
        icon = Icons.book_outlined;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.08) : LivescribeTheme.surfaceGray,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 36,
                color: isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: LivescribeTheme.titleLarge.copyWith(
                color: isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary,
              ),
            ),
            if (_selectedTabIndex == 0 && _searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Tap + to get started',
                style: LivescribeTheme.bodyMedium.copyWith(
                  color: isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFab(bool isDark) {
    return GestureDetector(
      onTap: _createNewNotebook,
      child: Container(
        width: 56,
        height: 56,
        decoration: LivescribeTheme.floatingActionDecoration,
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  void _showSettingsSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? LivescribeTheme.darkSurface : LivescribeTheme.surfaceWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _SettingsOption(
                icon: Icons.folder_outlined,
                label: 'Manage Folders',
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: Navigate to folders screen
                },
              ),
              _SettingsOption(
                icon: Icons.archive_outlined,
                label: 'Archived Notebooks',
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: Navigate to archived
                },
              ),
              _SettingsOption(
                icon: Icons.delete_outline_rounded,
                label: 'Trash',
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: Navigate to trash
                },
              ),
              _SettingsOption(
                icon: Icons.settings_outlined,
                label: 'Settings',
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: Navigate to settings
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotebookOptions(NotebookModel notebook) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? LivescribeTheme.darkSurface : LivescribeTheme.surfaceWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  notebook.title,
                  style: LivescribeTheme.titleLarge.copyWith(
                    color: isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary,
                  ),
                ),
              ),
              _SettingsOption(
                icon: notebook.isPinned ? Icons.star_rounded : Icons.star_outline_rounded,
                label: notebook.isPinned ? 'Remove from Favorites' : 'Add to Favorites',
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: Toggle favorite
                },
              ),
              _SettingsOption(
                icon: Icons.edit_outlined,
                label: 'Rename',
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: Rename notebook
                },
              ),
              _SettingsOption(
                icon: Icons.palette_outlined,
                label: 'Change Cover',
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: Change cover
                },
              ),
              _SettingsOption(
                icon: Icons.archive_outlined,
                label: 'Archive',
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: Archive
                },
              ),
              _SettingsOption(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                isDark: isDark,
                isDestructive: true,
                onTap: () {
                  Navigator.pop(ctx);
                  // TODO: Delete
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  
  _TabItem(this.label, this.icon);
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: LivescribeTheme.headlineSmall.copyWith(
                color: isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary,
              ),
            ),
            Text(
              label,
              style: LivescribeTheme.caption.copyWith(
                color: isDark ? LivescribeTheme.darkTextSecondary : LivescribeTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final bool isDestructive;

  const _SettingsOption({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive 
        ? LivescribeTheme.error 
        : (isDark ? LivescribeTheme.darkTextPrimary : LivescribeTheme.textPrimary);

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
              style: LivescribeTheme.bodyLarge.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

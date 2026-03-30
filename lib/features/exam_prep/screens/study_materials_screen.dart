/// Study Materials Screen
/// Browse notes, formulas, shortcuts and learning resources by subject

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/exam_prep_theme.dart';
import '../models/study_material_model.dart';
import '../data/study_materials/study_materials.dart';

class StudyMaterialsScreen extends StatefulWidget {
  const StudyMaterialsScreen({super.key});

  @override
  State<StudyMaterialsScreen> createState() => _StudyMaterialsScreenState();
}

class _StudyMaterialsScreenState extends State<StudyMaterialsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Exam categories for filtering - 'prefix' matches material ID prefix
  final List<Map<String, dynamic>> _examCategories = [
    {'id': 'banking', 'prefix': 'bank_', 'name': 'Banking', 'icon': Icons.account_balance, 'color': const Color(0xFF2196F3)},
    {'id': 'ssc', 'prefix': 'ssc_', 'name': 'SSC', 'icon': Icons.assignment, 'color': const Color(0xFF4CAF50)},
    {'id': 'jee', 'prefix': 'jee_', 'name': 'JEE', 'icon': Icons.science, 'color': const Color(0xFFFF5722)},
    {'id': 'neet', 'prefix': 'neet_', 'name': 'NEET', 'icon': Icons.biotech, 'color': const Color(0xFF9C27B0)},
    {'id': 'cat', 'prefix': 'cat_', 'name': 'CAT', 'icon': Icons.business, 'color': const Color(0xFF00BCD4)},
    {'id': 'gate', 'prefix': 'gate_', 'name': 'GATE', 'icon': Icons.computer, 'color': const Color(0xFF607D8B)},
    {'id': 'upsc', 'prefix': 'upsc_', 'name': 'UPSC', 'icon': Icons.gavel, 'color': const Color(0xFFE91E63)},
    {'id': 'clat', 'prefix': 'clat_', 'name': 'CLAT', 'icon': Icons.balance, 'color': const Color(0xFF795548)},
  ];

  String? _selectedExam;

  List<StudyMaterial> _materials = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _loadMaterials();
  }

  void _loadMaterials() {
    setState(() {
      _materials = allStudyMaterials;
    });
  }

  List<StudyMaterial> get _filteredMaterials {
    var materials = _materials;
    
    // Filter by exam category using prefix
    if (_selectedExam != null) {
      final examData = _examCategories.firstWhere(
        (e) => e['id'] == _selectedExam,
        orElse: () => {'prefix': _selectedExam},
      );
      final prefix = examData['prefix'] as String? ?? _selectedExam!;
      materials = materials.where((m) => m.id.startsWith(prefix)).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      materials = materials.where((m) =>
          m.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.description.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    final tabIndex = _tabController.index;
    switch (tabIndex) {
      case 0: // All
        return materials;
      case 1: // Notes
        return materials.where((m) => m.type == StudyMaterialType.notes).toList();
      case 2: // Formulas
        return materials.where((m) => m.type == StudyMaterialType.formula).toList();
      case 3: // Shortcuts
        return materials.where((m) => m.type == StudyMaterialType.shortcut).toList();
      default:
        return materials;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: ExamPrepTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: ExamPrepTheme.english,
        elevation: 0,
        title: const Text('Study Materials', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline, color: Colors.white),
            onPressed: () => _showBookmarks(context),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white),
            onPressed: () => _showDownloads(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Notes'),
            Tab(text: 'Formulas'),
            Tab(text: 'Shortcuts'),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildSearchBar(context, isDark),
            _buildSubjectFilter(context, isDark),
            Expanded(
              child: _filteredMaterials.isEmpty
                  ? _buildEmptyState(context, isDark)
                  : _buildMaterialsList(context, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search materials...',
            hintStyle: TextStyle(color: ExamPrepTheme.getTextSecondary(context)),
            prefixIcon: Icon(Icons.search, color: ExamPrepTheme.getTextSecondary(context)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectFilter(BuildContext context, bool isDark) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _examCategories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedExam == null;
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedExam = null);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(colors: [ExamPrepTheme.primary, ExamPrepTheme.primaryLight])
                      : null,
                  color: isSelected ? null : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? ExamPrepTheme.primary : (isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                ),
                child: Center(
                  child: Text(
                    'All',
                    style: TextStyle(
                      color: isSelected ? Colors.white : ExamPrepTheme.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }

          final exam = _examCategories[index - 1];
          final isSelected = _selectedExam == exam['id'];
          final color = exam['color'] as Color;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedExam = exam['id']);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(colors: [color, color.withOpacity(0.8)])
                    : null,
                color: isSelected ? null : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? color : (isDark ? Colors.white12 : Colors.grey.shade300),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    exam['icon'] as IconData,
                    size: 16,
                    color: isSelected ? Colors.white : color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    exam['name'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : ExamPrepTheme.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMaterialsList(BuildContext context, bool isDark) {
    final materials = _filteredMaterials;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: materials.length,
      itemBuilder: (context, index) {
        final material = materials[index];
        return _buildMaterialCard(context, material, isDark);
      },
    );
  }

  Widget _buildMaterialCard(BuildContext context, StudyMaterial material, bool isDark) {
    // Get color based on exam type from material ID prefix
    final examPrefix = material.id.split('_').first;
    final examColor = _examCategories
        .firstWhere((e) => e['id'] == examPrefix, orElse: () => {'color': ExamPrepTheme.primary})['color'] as Color;

    IconData typeIcon;
    String typeLabel;
    switch (material.type) {
      case StudyMaterialType.notes:
        typeIcon = Icons.article;
        typeLabel = 'Notes';
        break;
      case StudyMaterialType.formula:
        typeIcon = Icons.functions;
        typeLabel = 'Formula';
        break;
      case StudyMaterialType.shortcut:
        typeIcon = Icons.flash_on;
        typeLabel = 'Shortcut';
        break;
      case StudyMaterialType.video:
        typeIcon = Icons.play_circle;
        typeLabel = 'Video';
        break;
      case StudyMaterialType.pdf:
        typeIcon = Icons.picture_as_pdf;
        typeLabel = 'PDF';
        break;
      case StudyMaterialType.concept:
        typeIcon = Icons.lightbulb;
        typeLabel = 'Concept';
        break;
      case StudyMaterialType.summary:
        typeIcon = Icons.summarize;
        typeLabel = 'Summary';
        break;
      case StudyMaterialType.tips:
        typeIcon = Icons.tips_and_updates;
        typeLabel = 'Tips';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openMaterial(context, material),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [examColor, examColor.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: examColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                color: examColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (material.isPremium)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, size: 10, color: Colors.amber),
                                  SizedBox(width: 2),
                                  Text(
                                    'Premium',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        material.title,
                        style: TextStyle(
                          color: ExamPrepTheme.getTextPrimary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        material.description,
                        style: TextStyle(
                          color: ExamPrepTheme.getTextSecondary(context),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.timer, size: 12, color: ExamPrepTheme.getTextSecondary(context)),
                          const SizedBox(width: 4),
                          Text(
                            '${material.estimatedReadTime} min read',
                            style: TextStyle(
                              color: ExamPrepTheme.getTextSecondary(context),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.visibility, size: 12, color: ExamPrepTheme.getTextSecondary(context)),
                          const SizedBox(width: 4),
                          Text(
                            '${material.viewCount} views',
                            style: TextStyle(
                              color: ExamPrepTheme.getTextSecondary(context),
                              fontSize: 11,
                            ),
                          ),
                          if (material.rating > 0) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.star, size: 12, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              material.rating.toStringAsFixed(1),
                              style: TextStyle(
                                color: ExamPrepTheme.getTextSecondary(context),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: ExamPrepTheme.getTextSecondary(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 80,
            color: ExamPrepTheme.getTextSecondary(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No materials found',
            style: TextStyle(
              color: ExamPrepTheme.getTextPrimary(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters',
            style: TextStyle(
              color: ExamPrepTheme.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  void _openMaterial(BuildContext context, StudyMaterial material) {
    HapticFeedback.lightImpact();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildMaterialViewer(context, material),
    );
  }

  Widget _buildMaterialViewer(BuildContext context, StudyMaterial material) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final examPrefix = material.id.split('_').first;
    final examColor = _examCategories
        .firstWhere((e) => e['id'] == examPrefix, orElse: () => {'color': ExamPrepTheme.primary})['color'] as Color;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [examColor, examColor.withOpacity(0.7)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.article, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                material.title,
                                style: TextStyle(
                                  color: ExamPrepTheme.getTextPrimary(context),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${material.estimatedReadTime} min read',
                                style: TextStyle(
                                  color: ExamPrepTheme.getTextSecondary(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.bookmark_outline),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: Markdown(
                  controller: scrollController,
                  data: material.content,
                  padding: const EdgeInsets.all(16),
                  selectable: true,
                  onTapLink: (text, href, title) async {
                    if (href != null) {
                      final uri = Uri.parse(href);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    }
                  },
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      color: ExamPrepTheme.getTextPrimary(context),
                      fontSize: 15,
                      height: 1.6,
                    ),
                    h1: TextStyle(
                      color: ExamPrepTheme.getTextPrimary(context),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    h2: TextStyle(
                      color: ExamPrepTheme.getTextPrimary(context),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    h3: TextStyle(
                      color: ExamPrepTheme.getTextPrimary(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    code: TextStyle(
                      backgroundColor: ExamPrepTheme.getCardBg(context),
                      color: ExamPrepTheme.primary,
                      fontSize: 14,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: ExamPrepTheme.getCardBg(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    blockquote: TextStyle(
                      color: ExamPrepTheme.getTextSecondary(context),
                      fontStyle: FontStyle.italic,
                    ),
                    listBullet: TextStyle(
                      color: ExamPrepTheme.getTextPrimary(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBookmarks(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bookmarks feature coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDownloads(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Downloads feature coming soon!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/exam_prep_theme.dart';
import '../models/current_affairs_model.dart';

/// Current Affairs Screen with weekly updates
class CurrentAffairsScreen extends StatefulWidget {
  const CurrentAffairsScreen({super.key});

  @override
  State<CurrentAffairsScreen> createState() => _CurrentAffairsScreenState();
}

class _CurrentAffairsScreenState extends State<CurrentAffairsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CurrentAffairsCategory? _selectedCategory;
  int _selectedWeek = 0;
  
  List<CurrentAffairsItem> _items = [];
  List<WeeklyDigest> _weeklyDigests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  void _loadData() {
    // In production, this would fetch from Firestore
    setState(() {
      _items = SampleCurrentAffairs.getSampleItems();
      _weeklyDigests = _generateSampleDigests();
      _isLoading = false;
    });
  }

  List<WeeklyDigest> _generateSampleDigests() {
    final now = DateTime.now();
    return List.generate(4, (index) {
      final weekStart = now.subtract(Duration(days: 7 * index + now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      return WeeklyDigest(
        id: 'week_${WeekHelper.getWeekNumber(weekStart)}_${now.year}',
        weekNumber: WeekHelper.getWeekNumber(weekStart),
        year: now.year,
        weekStartDate: weekStart,
        weekEndDate: weekEnd,
        title: 'Week ${WeekHelper.getWeekNumber(weekStart)} Current Affairs',
        summary: 'Important events and updates from the week',
        totalItems: 15 + index * 3,
        categoryCount: {
          CurrentAffairsCategory.national: 5,
          CurrentAffairsCategory.international: 3,
          CurrentAffairsCategory.banking: 4,
          CurrentAffairsCategory.sports: 2,
        },
        highlights: [
          'RBI Monetary Policy Update',
          'G20 Summit Highlights',
          'New Government Schemes',
        ],
        isDownloaded: index == 0,
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: ExamPrepTheme.getBackground(context),
      appBar: AppBar(
        backgroundColor: ExamPrepTheme.generalAwareness,
        elevation: 0,
        title: const Text('Current Affairs', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () => _showMonthPicker(context),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white),
            onPressed: () => _showDownloadOptions(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Weekly'),
            Tab(text: 'By Category'),
            Tab(text: 'Quiz'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWeeklyView(context, isDark),
                _buildCategoryView(context, isDark),
                _buildQuizView(context, isDark),
              ],
            ),
    );
  }

  Widget _buildWeeklyView(BuildContext context, bool isDark) {
    return Column(
      children: [
        _buildWeekSelector(context, isDark),
        Expanded(
          child: _weeklyDigests.isEmpty
              ? _buildEmptyState('No weekly digests available')
              : _buildWeeklyContent(context, isDark),
        ),
      ],
    );
  }

  Widget _buildWeekSelector(BuildContext context, bool isDark) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _weeklyDigests.length,
        itemBuilder: (context, index) {
          final digest = _weeklyDigests[index];
          final isSelected = _selectedWeek == index;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedWeek = index;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 100,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          ExamPrepTheme.generalAwareness,
                          ExamPrepTheme.generalAwareness.withOpacity(0.8),
                        ],
                      )
                    : null,
                color: isSelected
                    ? null
                    : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : ExamPrepTheme.generalAwareness.withOpacity(0.3),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: ExamPrepTheme.generalAwareness.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Week ${digest.weekNumber}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${digest.totalItems} items',
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? Colors.white70
                          : (isDark ? Colors.white54 : Colors.black45),
                    ),
                  ),
                  if (digest.isDownloaded)
                    Icon(
                      Icons.download_done,
                      size: 14,
                      color: isSelected ? Colors.white : ExamPrepTheme.success,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklyContent(BuildContext context, bool isDark) {
    if (_weeklyDigests.isEmpty || _selectedWeek >= _weeklyDigests.length) {
      return _buildEmptyState('Select a week');
    }

    final digest = _weeklyDigests[_selectedWeek];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Week header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ExamPrepTheme.generalAwareness.withOpacity(0.15),
                  ExamPrepTheme.generalAwareness.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      color: ExamPrepTheme.generalAwareness,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      digest.formattedDateRange,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ExamPrepTheme.generalAwareness,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  digest.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${digest.totalItems} updates across ${digest.categoryCount.length} categories',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Highlights
          Text(
            'Highlights',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...digest.highlights.map((highlight) => _buildHighlightItem(highlight, isDark)),
          const SizedBox(height: 20),
          // Category breakdown
          Text(
            'By Category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: digest.categoryCount.entries.map((entry) {
              return _buildCategoryChip(entry.key, entry.value);
            }).toList(),
          ),
          const SizedBox(height: 24),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Start quiz for this week
                  },
                  icon: const Icon(Icons.quiz),
                  label: const Text('Take Quiz'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ExamPrepTheme.generalAwareness,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Read all items
                  },
                  icon: const Icon(Icons.read_more),
                  label: const Text('Read All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ExamPrepTheme.generalAwareness,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightItem(String highlight, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: ExamPrepTheme.generalAwareness,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              highlight,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.grey.shade400,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(CurrentAffairsCategory category, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ExamPrepTheme.generalAwareness.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(category.icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            '${category.displayName}: $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: ExamPrepTheme.generalAwareness,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryView(BuildContext context, bool isDark) {
    final categories = CurrentAffairsCategory.values;

    return Column(
      children: [
        // Category filter
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildCategoryFilter(null, 'All', isDark),
                ...categories.map((cat) => _buildCategoryFilter(cat, cat.displayName, isDark)),
              ],
            ),
          ),
        ),
        // Items list
        Expanded(
          child: _items.isEmpty
              ? _buildEmptyState('No items found')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    return _buildCurrentAffairsCard(_items[index], isDark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter(CurrentAffairsCategory? category, String label, bool isDark) {
    final isSelected = _selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedCategory = category;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? ExamPrepTheme.generalAwareness
                : ExamPrepTheme.generalAwareness.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : ExamPrepTheme.generalAwareness,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentAffairsCard(CurrentAffairsItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(item.category.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ExamPrepTheme.generalAwareness.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.category.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: ExamPrepTheme.generalAwareness,
                  ),
                ),
              ),
              if (item.isImportant) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ExamPrepTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 10, color: ExamPrepTheme.error),
                      const SizedBox(width: 2),
                      Text(
                        'Important',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: ExamPrepTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.summary,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                _formatDate(item.publishDate),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              if (item.relatedQuestions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ExamPrepTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.quiz, size: 12, color: ExamPrepTheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${item.relatedQuestions.length} Q',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: ExamPrepTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuizView(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: ExamPrepTheme.generalAwareness.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.quiz,
              size: 64,
              color: ExamPrepTheme.generalAwareness,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Current Affairs Quiz',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Test your knowledge on recent events',
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 32),
          _buildQuizOption(
            'This Week',
            'Latest current affairs quiz',
            Icons.calendar_today,
            ExamPrepTheme.generalAwareness,
          ),
          _buildQuizOption(
            'This Month',
            'Monthly compilation quiz',
            Icons.date_range,
            ExamPrepTheme.primary,
          ),
          _buildQuizOption(
            'Custom Quiz',
            'Select categories and period',
            Icons.tune,
            ExamPrepTheme.reasoning,
          ),
        ],
      ),
    );
  }

  Widget _buildQuizOption(String title, String subtitle, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
      child: ListTile(
        onTap: () {
          HapticFeedback.lightImpact();
          // Start quiz
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: Colors.grey),
        tileColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.newspaper,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showMonthPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Month'),
        content: SizedBox(
          width: 300,
          height: 200,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            children: List.generate(12, (index) {
              final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                  // Load month data
                },
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: ExamPrepTheme.generalAwareness.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      months[index],
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: ExamPrepTheme.generalAwareness,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDownloadOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download This Week'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Downloading...')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_for_offline),
              title: const Text('Download This Month'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

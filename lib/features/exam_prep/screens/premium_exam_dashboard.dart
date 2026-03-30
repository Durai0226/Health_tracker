import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/exam_prep_theme.dart';
import '../widgets/widgets.dart';
import '../data/question_bank_data.dart';
import 'premium_practice_screen.dart';
import 'mock_test_list_screen.dart';
import 'question_bank_screen.dart';
import 'current_affairs_screen.dart';

/// Premium Exam Prep Dashboard with 2x2 feature grid
class PremiumExamDashboard extends StatefulWidget {
  const PremiumExamDashboard({super.key});

  @override
  State<PremiumExamDashboard> createState() => _PremiumExamDashboardState();
}

class _PremiumExamDashboardState extends State<PremiumExamDashboard>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;

  int _streak = 7;
  int _totalQuestions = 0;
  int _attemptedToday = 0;
  double _overallAccuracy = 0.0;
  String _selectedExamCategory = 'all';

  final List<Map<String, dynamic>> _examCategories = [
    {'id': 'all', 'name': 'All Exams', 'icon': Icons.apps, 'color': ExamPrepTheme.primary},
    {'id': 'banking', 'name': 'Banking', 'icon': Icons.account_balance, 'color': const Color(0xFF1E88E5)},
    {'id': 'ssc', 'name': 'SSC/Railways', 'icon': Icons.train, 'color': const Color(0xFF43A047)},
    {'id': 'upsc', 'name': 'UPSC', 'icon': Icons.assured_workload, 'color': const Color(0xFFFF9800)},
    {'id': 'entrance', 'name': 'JEE/NEET', 'icon': Icons.school, 'color': const Color(0xFF9C27B0)},
    {'id': 'management', 'name': 'CAT/MBA', 'icon': Icons.business, 'color': const Color(0xFFE91E63)},
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _fadeController.forward();
    _loadStats();
  }

  void _loadStats() {
    setState(() {
      _totalQuestions = QuestionBank.totalQuestions;
      _attemptedToday = 25; // Would load from service
      _overallAccuracy = 0.72; // Would load from service
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: ExamPrepTheme.getBackground(context),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context, isDark),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildExamCategorySelector(context, isDark),
                    const SizedBox(height: 16),
                    _buildDailyProgressCard(context, isDark),
                    const SizedBox(height: 20),
                    _buildQuickStats(context, isDark),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Quick Access', Icons.flash_on),
                    const SizedBox(height: 12),
                    _buildFeatureGrid(context),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Your Progress', Icons.trending_up),
                    const SizedBox(height: 12),
                    _buildSubjectProgress(context, isDark),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Recent Activity', Icons.history),
                    const SizedBox(height: 12),
                    _buildRecentActivity(context, isDark),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ExamPrepTheme.primary,
                ExamPrepTheme.primaryDark,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Exam Prep',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ace your competitive exams',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      StreakBadge(streak: _streak),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.bookmark_outline, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            // Navigate to bookmarks
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: () {
            HapticFeedback.lightImpact();
            // Navigate to settings
          },
        ),
      ],
    );
  }

  Widget _buildExamCategorySelector(BuildContext context, bool isDark) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _examCategories.length,
        itemBuilder: (context, index) {
          final category = _examCategories[index];
          final isSelected = _selectedExamCategory == category['id'];
          final color = category['color'] as Color;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedExamCategory = category['id'] as String);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: 10, left: index == 0 ? 0 : 0),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(colors: [color, color.withOpacity(0.8)])
                    : null,
                color: isSelected ? null : (isDark ? const Color(0xFF2A2A3E) : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
                ] : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    category['icon'] as IconData,
                    size: 18,
                    color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category['name'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
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

  Widget _buildDailyProgressCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  ExamPrepTheme.primary.withOpacity(0.3),
                  ExamPrepTheme.primaryDark.withOpacity(0.2),
                ]
              : [
                  ExamPrepTheme.primary.withOpacity(0.1),
                  ExamPrepTheme.primaryLight.withOpacity(0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ExamPrepTheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Goal',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$_attemptedToday',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: ExamPrepTheme.primary,
                            ),
                          ),
                          TextSpan(
                            text: ' / 50 Questions',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white60 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.05),
                    child: child,
                  );
                },
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: ExamPrepTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: ExamPrepTheme.primary.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${((_attemptedToday / 50) * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _attemptedToday / 50,
              minHeight: 8,
              backgroundColor: ExamPrepTheme.primary.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(ExamPrepTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: StatsCard(
            title: 'Questions',
            value: '$_totalQuestions',
            subtitle: 'Available',
            icon: Icons.quiz_outlined,
            color: ExamPrepTheme.quantitative,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatsCard(
            title: 'Accuracy',
            value: '${(_overallAccuracy * 100).toInt()}%',
            subtitle: 'Overall',
            icon: Icons.analytics_outlined,
            color: ExamPrepTheme.success,
            trend: '+5%',
            isPositiveTrend: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: ExamPrepTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: ExamPrepTheme.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        ExamFeatureCard(
          icon: Icons.play_circle_outline,
          title: 'Practice',
          subtitle: 'Subject-wise',
          color: ExamPrepTheme.quantitative,
          onTap: () => _navigateTo(context, 'practice'),
        ),
        ExamFeatureCard(
          icon: Icons.assignment_outlined,
          title: 'Mock Tests',
          subtitle: 'Full-length',
          color: ExamPrepTheme.reasoning,
          badge: 'NEW',
          onTap: () => _navigateTo(context, 'mock_tests'),
        ),
        ExamFeatureCard(
          icon: Icons.library_books_outlined,
          title: 'Question Bank',
          subtitle: '$_totalQuestions Q\'s',
          color: ExamPrepTheme.english,
          onTap: () => _navigateTo(context, 'question_bank'),
        ),
        ExamFeatureCard(
          icon: Icons.newspaper_outlined,
          title: 'Current Affairs',
          subtitle: 'Weekly updated',
          color: ExamPrepTheme.generalAwareness,
          badge: 'LIVE',
          onTap: () => _navigateTo(context, 'current_affairs'),
        ),
      ],
    );
  }

  Widget _buildSubjectProgress(BuildContext context, bool isDark) {
    final subjects = [
      {
        'name': 'Quantitative Aptitude',
        'icon': Icons.calculate_outlined,
        'color': ExamPrepTheme.quantitative,
        'total': 350,
        'attempted': 120,
        'correct': 96,
      },
      {
        'name': 'Reasoning',
        'icon': Icons.psychology_outlined,
        'color': ExamPrepTheme.reasoning,
        'total': 300,
        'attempted': 85,
        'correct': 68,
      },
      {
        'name': 'English',
        'icon': Icons.menu_book_outlined,
        'color': ExamPrepTheme.english,
        'total': 250,
        'attempted': 60,
        'correct': 51,
      },
      {
        'name': 'General Awareness',
        'icon': Icons.public_outlined,
        'color': ExamPrepTheme.generalAwareness,
        'total': 400,
        'attempted': 150,
        'correct': 120,
      },
    ];

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: subjects.length,
        itemBuilder: (context, index) {
          final subject = subjects[index];
          return Container(
            width: 160,
            margin: EdgeInsets.only(
              right: index < subjects.length - 1 ? 12 : 0,
            ),
            child: SubjectProgressCard(
              subjectName: subject['name'] as String,
              icon: subject['icon'] as IconData,
              color: subject['color'] as Color,
              totalQuestions: subject['total'] as int,
              attempted: subject['attempted'] as int,
              correct: subject['correct'] as int,
              onTap: () {
                HapticFeedback.lightImpact();
                // Navigate to subject practice
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, bool isDark) {
    final activities = [
      {
        'title': 'Completed Mock Test',
        'subtitle': 'Banking Prelims #5 • 78%',
        'icon': Icons.assignment_turned_in,
        'color': ExamPrepTheme.success,
        'time': '2h ago',
      },
      {
        'title': 'Practice Session',
        'subtitle': 'Quantitative • 25 questions',
        'icon': Icons.play_circle_filled,
        'color': ExamPrepTheme.quantitative,
        'time': '5h ago',
      },
      {
        'title': 'Current Affairs',
        'subtitle': 'Week 48 completed',
        'icon': Icons.newspaper,
        'color': ExamPrepTheme.generalAwareness,
        'time': 'Yesterday',
      },
    ];

    return Column(
      children: activities.map((activity) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (activity['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  activity['icon'] as IconData,
                  color: activity['color'] as Color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity['title'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activity['subtitle'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                activity['time'] as String,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _navigateTo(BuildContext context, String route) {
    HapticFeedback.lightImpact();
    
    Widget? screen;
    switch (route) {
      case 'practice':
        screen = const PremiumPracticeScreen();
        break;
      case 'mock_tests':
        screen = const MockTestListScreen();
        break;
      case 'question_bank':
        screen = const QuestionBankScreen();
        break;
      case 'current_affairs':
        screen = const CurrentAffairsScreen();
        break;
    }
    
    if (screen != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screen!),
      );
    }
  }
}

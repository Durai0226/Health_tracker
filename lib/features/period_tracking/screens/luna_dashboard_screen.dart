import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/luna_theme.dart';
import '../widgets/luna_widgets.dart';
import '../services/period_prediction_service.dart';
import '../services/period_storage_service.dart';
import '../luna_providers.dart';
import 'luna_settings_screen.dart';
import 'luna_calendar_screen.dart';
import 'luna_community_screen.dart';
import 'luna_safety_screen.dart';
import 'luna_mood_log_sheet.dart';
import 'luna_symptoms_log_sheet.dart';
import 'luna_intimacy_log_sheet.dart';

/// Main dashboard for Luna Cycle app - Entry point with providers
class LunaDashboardScreen extends StatelessWidget {
  const LunaDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LunaProviders(
      child: const _LunaDashboardContent(),
    );
  }
}

class _LunaDashboardContent extends StatefulWidget {
  const _LunaDashboardContent();

  @override
  State<_LunaDashboardContent> createState() => _LunaDashboardContentState();
}

class _LunaDashboardContentState extends State<_LunaDashboardContent>
    with SingleTickerProviderStateMixin {
  int _currentNavIndex = 0;
  LunaCyclePhase _currentPhase = LunaCyclePhase.follicular;
  int _daysUntilPeriod = 14;
  int _cycleDay = 10;
  DateTime? _lastPeriodDate;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _loadCycleData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _loadCycleData() {
    final settings = PeriodCleanStorageService.getSettings();
    final cycles = PeriodCleanStorageService.getAllCycles();
    
    if (cycles.isNotEmpty) {
      final lastCycle = cycles.first;
      _lastPeriodDate = lastCycle.startDate;
      
      final prediction = PeriodPredictionService.predictNextPeriod(
        _lastPeriodDate!,
        settings.defaultCycleLength,
      );
      
      _daysUntilPeriod = prediction.difference(DateTime.now()).inDays;
      _cycleDay = DateTime.now().difference(_lastPeriodDate!).inDays + 1;
      
      final phase = PeriodPredictionService.getCurrentPhase(
        _lastPeriodDate!,
        settings.defaultCycleLength,
        settings.defaultPeriodDuration,
        DateTime.now(),
      );
      _currentPhase = LunaCyclePhaseExtension.fromLegacy(phase);
    }
    
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LunaTheme.getBackground(context),
      body: IndexedStack(
        index: _currentNavIndex,
        children: [
          _buildHomeTab(),
          const LunaCalendarScreen(),
          const LunaCommunityScreen(),
          const LunaSafetyScreen(),
        ],
      ),
      floatingActionButton: _currentNavIndex == 0
          ? FloatingActionButton(
              onPressed: _showQuickLogSheet,
              backgroundColor: LunaTheme.primaryPink,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: LunaTheme.getSurface(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.calendar_month_rounded, 'Calendar'),
              _buildNavItem(2, Icons.people_rounded, 'Community'),
              _buildNavItem(3, Icons.shield_rounded, 'Safety'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentNavIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentNavIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? LunaTheme.primaryPink.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? LunaTheme.primaryPink : LunaTheme.getTextTertiary(context),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? LunaTheme.primaryPink : LunaTheme.getTextTertiary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Greeting header
        SliverToBoxAdapter(
          child: LunaGreetingHeader(
            userName: 'Luna',
            currentPhase: _currentPhase,
            onProfileTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LunaSettingsScreen(),
                ),
              );
            },
          ),
        ),

        // Main cycle card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: LunaTheme.spacingLg),
            child: _buildCycleCard(),
          ),
        ),

        // Quick actions
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(LunaTheme.spacingLg),
            child: _buildQuickActions(),
          ),
        ),

        // Daily tip
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: LunaTheme.spacingLg),
            child: _buildDailyTip(),
          ),
        ),

        // Today's insights
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: LunaTheme.spacingLg),
            child: LunaSectionHeader(
              title: 'Today\'s Insights',
              icon: Icons.lightbulb_outline,
              actionLabel: 'See All',
              onActionTap: () {},
            ),
          ),
        ),

        // Insights cards
        SliverToBoxAdapter(
          child: SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: LunaTheme.spacingLg),
              children: [
                _buildInsightCard(
                  'Fertility',
                  _currentPhase == LunaCyclePhase.ovulation ? 'High' : 'Low',
                  Icons.favorite_outline,
                  _currentPhase == LunaCyclePhase.ovulation
                      ? LunaTheme.safetyRed
                      : LunaTheme.success,
                ),
                const SizedBox(width: LunaTheme.spacingMd),
                _buildInsightCard(
                  'Energy Level',
                  _getEnergyLevel(),
                  Icons.bolt_outlined,
                  LunaTheme.follicularYellow,
                ),
                const SizedBox(width: LunaTheme.spacingMd),
                _buildInsightCard(
                  'Mood',
                  _getMoodPrediction(),
                  Icons.mood_outlined,
                  LunaTheme.accentPurple,
                ),
              ],
            ),
          ),
        ),

        // Community preview
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: LunaTheme.spacing2xl),
            child: LunaSectionHeader(
              title: 'Community',
              icon: Icons.people_outline,
              actionLabel: 'View All',
              onActionTap: () => setState(() => _currentNavIndex = 2),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: LunaTheme.spacingLg),
            child: _buildCommunityPreview(),
          ),
        ),

        // Bottom spacing
        const SliverToBoxAdapter(
          child: SizedBox(height: LunaTheme.spacing4xl),
        ),
      ],
    );
  }

  Widget _buildCycleCard() {
    return LunaPhaseCard(
      phase: _currentPhase,
      padding: const EdgeInsets.all(LunaTheme.spacingXl),
      child: Column(
        children: [
          Row(
            children: [
              // Moon character
              LunaMoonCharacter(
                size: 100,
                phase: _currentPhase,
                mood: LunaMoonMoodExtension.fromPhase(_currentPhase),
              ),
              const SizedBox(width: LunaTheme.spacingLg),
              // Cycle info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LunaTheme.getPhaseName(_currentPhase),
                      style: LunaTheme.headlineMedium.copyWith(
                        color: LunaTheme.getPhaseColor(_currentPhase),
                      ),
                    ),
                    const SizedBox(height: LunaTheme.spacingXs),
                    Text(
                      LunaTheme.getPhaseDescription(_currentPhase),
                      style: LunaTheme.bodyMedium.copyWith(
                        color: LunaTheme.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: LunaTheme.spacingMd),
                    Row(
                      children: [
                        _buildCycleStat('Day', '$_cycleDay'),
                        const SizedBox(width: LunaTheme.spacingLg),
                        _buildCycleStat(
                          _daysUntilPeriod > 0 ? 'Period in' : 'Period',
                          _daysUntilPeriod > 0
                              ? '$_daysUntilPeriod days'
                              : 'Today',
                        ),
                      ],
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

  Widget _buildCycleStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: LunaTheme.labelSmall.copyWith(
            color: LunaTheme.getTextTertiary(context),
          ),
        ),
        Text(
          value,
          style: LunaTheme.titleMedium.copyWith(
            color: LunaTheme.getTextPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Wrap(
      spacing: LunaTheme.spacingSm,
      runSpacing: LunaTheme.spacingSm,
      children: [
        LunaQuickActionButton(
          icon: Icons.water_drop_outlined,
          label: 'Log Period',
          color: LunaTheme.primaryPink,
          onTap: _showQuickLogSheet,
        ),
        LunaQuickActionButton(
          icon: Icons.mood_outlined,
          label: 'Log Mood',
          color: LunaTheme.accentPurple,
          onTap: _showMoodLogSheet,
        ),
        LunaQuickActionButton(
          icon: Icons.healing_outlined,
          label: 'Symptoms',
          color: LunaTheme.secondaryCoral,
          onTap: _showSymptomsLogSheet,
        ),
        LunaQuickActionButton(
          icon: Icons.favorite_outline,
          label: 'Intimacy',
          color: LunaTheme.safetyRed,
          onTap: _showIntimacyLogSheet,
        ),
      ],
    );
  }

  void _showMoodLogSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LunaMoodLogSheet(
        date: DateTime.now(),
        onSaved: _loadCycleData,
      ),
    );
  }

  void _showSymptomsLogSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LunaSymptomsLogSheet(
        date: DateTime.now(),
        onSaved: _loadCycleData,
      ),
    );
  }

  void _showIntimacyLogSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LunaIntimacyLogSheet(
        date: DateTime.now(),
        onSaved: _loadCycleData,
      ),
    );
  }

  Widget _buildDailyTip() {
    final tip = LunaTheme.getPhaseAdvice(_currentPhase);
    
    return LunaPinkCard(
      padding: const EdgeInsets.all(LunaTheme.spacingLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(LunaTheme.spacingSm),
            decoration: BoxDecoration(
              color: LunaTheme.primaryPink.withOpacity(0.2),
              borderRadius: BorderRadius.circular(LunaTheme.radiusSm),
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              color: LunaTheme.primaryPink,
              size: 20,
            ),
          ),
          const SizedBox(width: LunaTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Tip',
                  style: LunaTheme.titleMedium.copyWith(
                    color: LunaTheme.primaryPink,
                  ),
                ),
                const SizedBox(height: LunaTheme.spacingXs),
                Text(
                  tip,
                  style: LunaTheme.bodyMedium.copyWith(
                    color: LunaTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(LunaTheme.spacingMd),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(LunaTheme.radiusLg),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          const Spacer(),
          Text(
            value,
            style: LunaTheme.titleLarge.copyWith(color: color),
          ),
          Text(
            title,
            style: LunaTheme.labelSmall.copyWith(
              color: LunaTheme.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityPreview() {
    return LunaGlassCard(
      onTap: () => setState(() => _currentNavIndex = 2),
      padding: const EdgeInsets.all(LunaTheme.spacingLg),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LunaTheme.communityGradient,
              borderRadius: BorderRadius.circular(LunaTheme.radiusMd),
            ),
            child: const Icon(
              Icons.people_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: LunaTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join the conversation',
                  style: LunaTheme.titleMedium.copyWith(
                    color: LunaTheme.getTextPrimary(context),
                  ),
                ),
                Text(
                  'Connect with women going through similar experiences',
                  style: LunaTheme.bodySmall.copyWith(
                    color: LunaTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            color: LunaTheme.getTextTertiary(context),
            size: 16,
          ),
        ],
      ),
    );
  }

  String _getEnergyLevel() {
    switch (_currentPhase) {
      case LunaCyclePhase.menstrual:
        return 'Low';
      case LunaCyclePhase.follicular:
        return 'Rising';
      case LunaCyclePhase.ovulation:
        return 'Peak';
      case LunaCyclePhase.luteal:
        return 'Moderate';
      case LunaCyclePhase.pms:
        return 'Low';
    }
  }

  String _getMoodPrediction() {
    switch (_currentPhase) {
      case LunaCyclePhase.menstrual:
        return 'Reflective';
      case LunaCyclePhase.follicular:
        return 'Optimistic';
      case LunaCyclePhase.ovulation:
        return 'Confident';
      case LunaCyclePhase.luteal:
        return 'Calm';
      case LunaCyclePhase.pms:
        return 'Sensitive';
    }
  }

  void _showQuickLogSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _QuickLogSheet(
        onPeriodStart: () {
          Navigator.pop(context);
          _loadCycleData();
        },
        onPeriodEnd: () {
          Navigator.pop(context);
          _loadCycleData();
        },
      ),
    );
  }
}

class _QuickLogSheet extends StatefulWidget {
  final VoidCallback onPeriodStart;
  final VoidCallback onPeriodEnd;

  const _QuickLogSheet({
    required this.onPeriodStart,
    required this.onPeriodEnd,
  });

  @override
  State<_QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<_QuickLogSheet> {
  bool _isLoading = false;

  Future<void> _startPeriod() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    
    try {
      await PeriodCleanStorageService.startNewCycle(DateTime.now());
      if (mounted) {
        Navigator.pop(context);
        widget.onPeriodStart();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Period started! Take care of yourself 💕'),
            backgroundColor: LunaTheme.primaryPink,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: LunaTheme.error),
        );
      }
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _endPeriod() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    
    try {
      await PeriodCleanStorageService.endCurrentPeriod(DateTime.now());
      if (mounted) {
        Navigator.pop(context);
        widget.onPeriodEnd();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Period ended! Great job tracking ✨'),
            backgroundColor: LunaTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: LunaTheme.error),
        );
      }
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LunaTheme.getSurface(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(LunaTheme.radius2xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: LunaTheme.spacingMd),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: LunaTheme.getDivider(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(LunaTheme.spacingXl),
              child: CircularProgressIndicator(color: LunaTheme.primaryPink),
            )
          else
            Padding(
              padding: const EdgeInsets.all(LunaTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Log',
                    style: LunaTheme.headlineMedium.copyWith(
                      color: LunaTheme.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: LunaTheme.spacingLg),
                  
                  // Period options
                  _LogOption(
                    icon: Icons.water_drop,
                    iconColor: LunaTheme.primaryPink,
                    title: 'Period Started',
                    subtitle: 'Log the start of your period',
                    onTap: _startPeriod,
                  ),
                  const SizedBox(height: LunaTheme.spacingMd),
                  _LogOption(
                    icon: Icons.check_circle_outline,
                    iconColor: LunaTheme.success,
                    title: 'Period Ended',
                    subtitle: 'Log the end of your period',
                    onTap: _endPeriod,
                  ),
                ],
              ),
            ),
          
          SafeArea(
            top: false,
            child: Container(height: LunaTheme.spacingLg),
          ),
        ],
      ),
    );
  }
}

class _LogOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LogOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(LunaTheme.spacingLg),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(LunaTheme.radiusLg),
          border: Border.all(
            color: iconColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: LunaTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: LunaTheme.titleMedium.copyWith(
                      color: LunaTheme.getTextPrimary(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: LunaTheme.bodySmall.copyWith(
                      color: LunaTheme.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: LunaTheme.getTextTertiary(context),
            ),
          ],
        ),
      ),
    );
  }
}

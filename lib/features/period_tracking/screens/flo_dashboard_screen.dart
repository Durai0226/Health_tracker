import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/flo_theme.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';
import '../services/period_prediction_service.dart';
import '../services/period_storage_service.dart';
import 'flo_calendar_screen.dart';
import 'flo_symptoms_screen.dart';
import 'flo_partner_screen.dart';
import 'flo_tracker_screen.dart';
import 'flo_fitness_screen.dart';
import 'flo_settings_screen.dart';

/// Main dashboard screen for period tracking
/// Flo-inspired design with cycle ring, week selector, and bottom navigation
class FloDashboardScreen extends StatefulWidget {
  const FloDashboardScreen({super.key});

  @override
  State<FloDashboardScreen> createState() => _FloDashboardScreenState();
}

class _FloDashboardScreenState extends State<FloDashboardScreen>
    with TickerProviderStateMixin {
  int _currentNavIndex = 0;
  PeriodData? _periodData;
  CyclePhaseType _currentPhase = CyclePhaseType.follicular;
  int _cycleDay = 1;
  DateTime _selectedDate = DateTime.now();
  Map<String, DateTime>? _fertileWindow;
  bool _isInFertileWindow = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: FloTheme.animNormal,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadData();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _loadData() {
    // Load period data from storage
    // TODO: Replace with actual storage call when Drift migration is complete
    final settings = PeriodCleanStorageService.getSettings();
    
    // For demo purposes, create sample data
    final lastPeriod = DateTime.now().subtract(const Duration(days: 10));
    _periodData = PeriodData(
      lastPeriodDate: lastPeriod,
      cycleLength: settings.defaultCycleLength,
      periodDuration: settings.defaultPeriodDuration,
    );

    if (_periodData != null) {
      final today = DateTime.now();
      _cycleDay = PeriodPredictionService.getCurrentCycleDay(
        _periodData!.lastPeriodDate,
        today,
      );
      
      final legacyPhase = PeriodPredictionService.getCurrentPhase(
        _periodData!.lastPeriodDate,
        _periodData!.cycleLength,
        _periodData!.periodDuration,
        today,
      );
      _currentPhase = CyclePhaseTypeExtension.fromLegacy(legacyPhase);
      
      _fertileWindow = PeriodPredictionService.predictFertileWindow(
        _periodData!.lastPeriodDate,
        _periodData!.cycleLength,
      );
      
      _isInFertileWindow = PeriodPredictionService.isInFertileWindow(
        today,
        _periodData!.lastPeriodDate,
        _periodData!.cycleLength,
      );
    }

    setState(() {});
  }

  void _onNavTap(int index) {
    HapticFeedback.selectionClick();
    if (index == _currentNavIndex) return;
    
    setState(() => _currentNavIndex = index);
    
    // Navigate based on index
    switch (index) {
      case 0:
        // Already on home
        break;
      case 1:
        _navigateToCalendar();
        break;
      case 2:
        _navigateToSymptoms();
        break;
      case 3:
        _navigateToPartner();
        break;
    }
  }

  void _navigateToCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FloCalendarScreen()),
    ).then((_) => setState(() => _currentNavIndex = 0));
  }

  void _navigateToSymptoms() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FloSymptomsScreen(date: _selectedDate),
      ),
    ).then((_) => setState(() => _currentNavIndex = 0));
  }

  void _navigateToPartner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FloPartnerScreen()),
    ).then((_) => setState(() => _currentNavIndex = 0));
  }

  void _showQuickLogSheet() {
    FloQuickLogSheet.show(
      context,
      initialDate: DateTime.now(),
      onLogPeriod: (date, flow) async {
        await PeriodCleanStorageService.startNewCycle(date);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Period logged for ${DateFormat('MMM d').format(date)}'),
              backgroundColor: FloTheme.periodPink,
            ),
          );
        }
      },
      onLogSymptoms: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FloSymptomsScreen(date: DateTime.now()),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final phaseColor = FloTheme.getPhaseColor(_currentPhase);
    final isDark = FloTheme.isDark(context);

    return Scaffold(
      backgroundColor: FloTheme.getPhaseBackgroundColor(_currentPhase, isDark: isDark),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: FloTheme.spacingLg),
                      
                      // Greeting header
                      FloGreetingHeader(
                        userName: 'User', // TODO: Get from user profile
                        onProfileTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FloSettingsScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: FloTheme.spacingXl),

                      // Week selector
                      FloWeekSelector(
                        selectedDate: _selectedDate,
                        periodStartDate: _periodData?.lastPeriodDate,
                        cycleLength: _periodData?.cycleLength ?? 28,
                        periodDuration: _periodData?.periodDuration ?? 5,
                        fertileWindow: _fertileWindow,
                        onDateSelected: (date) {
                          setState(() => _selectedDate = date);
                        },
                      ),

                      const SizedBox(height: FloTheme.spacing3xl),

                      // Cycle ring
                      FloCycleRing(
                        cycleDay: _cycleDay,
                        cycleLength: _periodData?.cycleLength ?? 28,
                        phase: _currentPhase,
                        isOnPeriod: _periodData?.isOnPeriod(DateTime.now()) ?? false,
                        periodDuration: _periodData?.periodDuration ?? 5,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FloTrackerScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: FloTheme.spacingLg),

                      // Phase legend
                      _buildPhaseLegend(),

                      const SizedBox(height: FloTheme.spacingXl),

                      // Log Period button
                      FloQuickLogFab(onTap: _showQuickLogSheet),

                      const SizedBox(height: FloTheme.spacing2xl),

                      // Pregnancy chance card
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: FloTheme.spacingLg,
                        ),
                        child: FloPregnancyChanceCard(
                          isHigh: _isInFertileWindow,
                          onTap: () {
                            // Show fertility info
                          },
                        ),
                      ),

                      const SizedBox(height: FloTheme.spacingLg),

                      // Previous period info
                      if (_periodData != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: FloTheme.spacingLg,
                          ),
                          child: _buildPeriodInfoCard(),
                        ),

                      const SizedBox(height: FloTheme.spacingLg),

                      // Quick actions
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: FloTheme.spacingLg,
                        ),
                        child: _buildQuickActions(),
                      ),

                      const SizedBox(height: FloTheme.spacing4xl),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: FloBottomNav(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
        onAddPressed: _showQuickLogSheet,
      ),
    );
  }

  Widget _buildPhaseLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FloTheme.spacingLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegendDot(
            color: FloTheme.periodPink,
            label: 'Period phase',
          ),
          const SizedBox(width: FloTheme.spacingXl),
          _LegendDot(
            color: FloTheme.ovulationBlue,
            label: 'Fertile window',
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodInfoCard() {
    final nextPeriod = _periodData!.nextPeriodDate;
    final daysUntil = _periodData!.daysUntilNextPeriod(DateTime.now());

    return FloGlassCard(
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Row(
        children: [
          Icon(
            Icons.event_rounded,
            color: FloTheme.periodPink,
            size: 24,
          ),
          const SizedBox(width: FloTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next expected Period starts on',
                  style: FloTheme.bodySmall.copyWith(
                    color: FloTheme.getTextSecondary(context),
                  ),
                ),
                Text(
                  DateFormat('MMMM d').format(nextPeriod),
                  style: FloTheme.titleLarge.copyWith(
                    color: FloTheme.getTextPrimary(context),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: FloTheme.spacingMd,
              vertical: FloTheme.spacingSm,
            ),
            decoration: BoxDecoration(
              color: FloTheme.periodPinkLight,
              borderRadius: BorderRadius.circular(FloTheme.radiusFull),
            ),
            child: Text(
              'in $daysUntil days',
              style: FloTheme.labelSmall.copyWith(
                color: FloTheme.periodPink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: FloStatCard(
            title: 'Fitness',
            value: 'Workouts',
            icon: Icons.fitness_center_rounded,
            color: FloTheme.accentOrange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FloFitnessScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: FloTheme.spacingMd),
        Expanded(
          child: FloStatCard(
            title: 'Statistics',
            value: 'Cycles',
            icon: Icons.analytics_rounded,
            color: FloTheme.ovulationBlue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FloTrackerScreen()),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: FloTheme.bodySmall.copyWith(
            color: FloTheme.getTextSecondary(context),
          ),
        ),
      ],
    );
  }
}

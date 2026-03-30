import 'package:flutter/material.dart';
import '../theme/flo_theme.dart';
import '../widgets/widgets.dart';
import '../services/period_storage_service.dart';

/// Cycle history and statistics screen (Flo Tracker)
class FloTrackerScreen extends StatefulWidget {
  const FloTrackerScreen({super.key});

  @override
  State<FloTrackerScreen> createState() => _FloTrackerScreenState();
}

class _FloTrackerScreenState extends State<FloTrackerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadStats() {
    _stats = PeriodCleanStorageService.getCycleStatistics();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FloTheme.getBackground(context),
      appBar: FloAppBar(
        titleWidget: Text(
          'Flo Tracker',
          style: FloTheme.headlineMedium.copyWith(
            color: FloTheme.periodPink,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: FloTheme.spacingLg),
            decoration: BoxDecoration(
              color: FloTheme.getDivider(context),
              borderRadius: BorderRadius.circular(FloTheme.radiusFull),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: FloTheme.periodPink,
                borderRadius: BorderRadius.circular(FloTheme.radiusFull),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: FloTheme.getTextSecondary(context),
              labelStyle: FloTheme.titleMedium,
              tabs: const [
                Tab(text: 'My Cycles'),
                Tab(text: 'Cycles History'),
              ],
            ),
          ),

          const SizedBox(height: FloTheme.spacingLg),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMyCyclesTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyCyclesTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Previous cycle\nlength',
                  '${_stats['averageCycleLength'] ?? 28}',
                  'days',
                  FloTheme.periodPink,
                  isRegular: true,
                ),
              ),
              const SizedBox(width: FloTheme.spacingMd),
              Expanded(
                child: _buildStatCard(
                  'Previous period\nlength',
                  '${_stats['averagePeriodDuration'] ?? 5}',
                  'days',
                  FloTheme.accentOrange,
                  isNormal: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: FloTheme.spacingLg),

          // Cycle length variation
          _buildVariationCard(
            'Cycle length\nvariation',
            '${_stats['shortestCycle'] ?? 26}-${_stats['longestCycle'] ?? 30}',
            'days',
            isNormal: (_stats['cycleVariation'] ?? 0) <= 7,
          ),

          const SizedBox(height: FloTheme.spacingLg),

          // Period length variation
          _buildVariationCard(
            'Period length\nvariation',
            '${(_stats['averagePeriodDuration'] ?? 5) - 2}-${(_stats['averagePeriodDuration'] ?? 5) + 2}',
            'days',
            isNormal: true,
          ),

          const SizedBox(height: FloTheme.spacing2xl),

          // Insights
          Text(
            'Insights',
            style: FloTheme.headlineSmall.copyWith(
              color: FloTheme.getTextPrimary(context),
            ),
          ),

          const SizedBox(height: FloTheme.spacingMd),

          _buildInsightCard(
            Icons.check_circle_rounded,
            Colors.green,
            'Your cycles appear regular',
            'Your cycle length variation is within normal range.',
          ),

          const SizedBox(height: FloTheme.spacingMd),

          _buildInsightCard(
            Icons.info_rounded,
            FloTheme.ovulationBlue,
            'Track more cycles',
            'Log at least 3 cycles for more accurate predictions.',
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final cycles = PeriodCleanStorageService.getAllCycles();

    if (cycles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 64,
              color: FloTheme.getTextSecondary(context),
            ),
            const SizedBox(height: FloTheme.spacingLg),
            Text(
              'No cycle history yet',
              style: FloTheme.headlineSmall.copyWith(
                color: FloTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: FloTheme.spacingSm),
            Text(
              'Start logging your periods to see your history',
              style: FloTheme.bodyMedium.copyWith(
                color: FloTheme.getTextSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      itemCount: cycles.length,
      itemBuilder: (context, index) {
        final cycle = cycles[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: FloTheme.spacingMd),
          child: FloGlassCard(
            padding: const EdgeInsets.all(FloTheme.spacingLg),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: FloTheme.periodPinkLight,
                    borderRadius: BorderRadius.circular(FloTheme.radiusMd),
                  ),
                  child: Center(
                    child: Text(
                      '${cycle.actualCycleLength}',
                      style: FloTheme.headlineMedium.copyWith(
                        color: FloTheme.periodPink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: FloTheme.spacingLg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cycle ${cycles.length - index}',
                        style: FloTheme.titleMedium.copyWith(
                          color: FloTheme.getTextPrimary(context),
                        ),
                      ),
                      Text(
                        '${cycle.periodDuration} day period',
                        style: FloTheme.bodySmall.copyWith(
                          color: FloTheme.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  cycle.isComplete ? 'Completed' : 'Current',
                  style: FloTheme.labelSmall.copyWith(
                    color: cycle.isComplete
                        ? FloTheme.getTextSecondary(context)
                        : FloTheme.periodPink,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String unit,
    Color color, {
    bool isRegular = false,
    bool isNormal = false,
  }) {
    return FloGlassCard(
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: FloTheme.bodySmall.copyWith(
              color: FloTheme.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: FloTheme.spacingSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: FloTheme.displaySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: FloTheme.bodySmall.copyWith(
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (isRegular || isNormal) ...[
            const SizedBox(height: FloTheme.spacingSm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: FloTheme.spacingSm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: isRegular ? FloTheme.periodPink : FloTheme.accentOrange,
                borderRadius: BorderRadius.circular(FloTheme.radiusSm),
              ),
              child: Text(
                isRegular ? '● REGULAR' : '● NORMAL',
                style: FloTheme.labelSmall.copyWith(
                  color: Colors.white,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVariationCard(
    String label,
    String value,
    String unit, {
    bool isNormal = false,
  }) {
    return FloGlassCard(
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: FloTheme.bodySmall.copyWith(
                    color: FloTheme.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: FloTheme.spacingXs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: FloTheme.displaySmall.copyWith(
                        color: FloTheme.lutealGreenAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        unit,
                        style: FloTheme.bodySmall.copyWith(
                          color: FloTheme.lutealGreenAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isNormal)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: FloTheme.spacingMd,
                vertical: FloTheme.spacingXs,
              ),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(FloTheme.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'NORMAL',
                    style: FloTheme.labelSmall.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
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
    IconData icon,
    Color color,
    String title,
    String description,
  ) {
    return FloGlassCard(
      padding: const EdgeInsets.all(FloTheme.spacingLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(FloTheme.spacingSm),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(FloTheme.radiusSm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: FloTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FloTheme.titleMedium.copyWith(
                    color: FloTheme.getTextPrimary(context),
                  ),
                ),
                Text(
                  description,
                  style: FloTheme.bodySmall.copyWith(
                    color: FloTheme.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../models/training_models.dart';

class PersonalRecordsScreen extends StatefulWidget {
  const PersonalRecordsScreen({super.key});

  @override
  State<PersonalRecordsScreen> createState() => _PersonalRecordsScreenState();
}

class _PersonalRecordsScreenState extends State<PersonalRecordsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildSummaryCard()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(text: 'Running'),
                  Tab(text: 'Cycling'),
                  Tab(text: 'Other'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPRList('run', Icons.directions_run, Colors.orange),
            _buildPRList('cycling', Icons.pedal_bike, Colors.blue),
            _buildPRList('other', Icons.emoji_events, Colors.purple),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMockRecord,
        backgroundColor: Colors.amber.shade600,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: Colors.amber.shade600,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Personal Records',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.amber.shade600,
                Colors.orange.shade600,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                right: 20,
                bottom: 60,
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: 60,
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return ValueListenableBuilder(
      valueListenable: StorageService.personalRecordsListenable,
      builder: (context, box, _) {
          final totalPRs = box.length;
          // Simple mock stats for now
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                ),
                ],
            ),
            child: Column(
                children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                    _buildSummaryItem('$totalPRs', 'Total PRs', Icons.emoji_events, Colors.amber),
                    _buildSummaryItem('5', 'This Month', Icons.calendar_today, Colors.green),
                    _buildSummaryItem('3', 'This Week', Icons.bolt, Colors.orange),
                    ],
                ),
                const SizedBox(height: 20),
                if (totalPRs > 0)
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: [Colors.amber.shade100, Colors.orange.shade100],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                        children: [
                            const Icon(Icons.celebration, color: Colors.orange),
                            const SizedBox(width: 12),
                             Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                const Text(
                                    'Latest PR!',
                                    style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    ),
                                ),
                                Text(
                                    '${box.values.last.name} - ${box.values.last.value}',
                                    style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    ),
                                ),
                                ],
                            ),
                            ),
                            Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                                'Just now',
                                style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                ),
                            ),
                            ),
                        ],
                        ),
                    ),
                ],
            ),
            );
      }
    );
  }

  Widget _buildSummaryItem(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPRList(String activityType, IconData icon, Color color) {
      return ValueListenableBuilder(
      valueListenable: StorageService.personalRecordsListenable,
      builder: (context, box, _) {
          final prs = box.values.where((pr) {
              if (activityType == 'other') {
                  return pr.activityType != 'run' && pr.activityType != 'cycling';
              }
              return pr.activityType == activityType;
          }).toList();

          if (prs.isEmpty) {
              return Center(child: Text('No $activityType records yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: prs.length,
            itemBuilder: (context, index) {
                final pr = prs[index];
                return _buildPRCard(pr, icon, color);
            },
            );
      }
      );
  }

  Widget _buildPRCard(PersonalRecord pr, IconData icon, Color color) {
    final improvement = pr.improvementPercentage;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        title: Text(
          pr.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              pr.value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              _formatDate(pr.date),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        trailing: improvement != null && improvement > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_upward, color: Colors.green, size: 14),
                    Text(
                      '$improvement%',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            : const Icon(Icons.emoji_events, color: Colors.amber),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
      return '${date.day}/${date.month}/${date.year}';
  }

  void _addMockRecord() {
      final newRecord = PersonalRecord(
          id: DateTime.now().toIso8601String(),
          activityType: 'run',
          name: '5K Run',
          value: '22:30',
          date: DateTime.now(),
          improvementPercentage: 5,
          previousValue: '23:45',
      );
      StorageService.savePersonalRecord(newRecord);
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/storage_service.dart';
import '../models/social_models.dart';
// For random/mock data generation if needed

class SocialChallengesScreen extends StatefulWidget {
  const SocialChallengesScreen({super.key});

  @override
  State<SocialChallengesScreen> createState() => _SocialChallengesScreenState();
}

class _SocialChallengesScreenState extends State<SocialChallengesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                isScrollable: true,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(text: 'Challenges'),
                  Tab(text: 'Leaderboards'),
                  Tab(text: 'Feed'),
                  Tab(text: 'Friends'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildChallengesTab(),
            _buildLeaderboardTab(),
            _buildFeedTab(),
            _buildFriendsTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createChallenge,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_task, color: Colors.white),
        label: const Text('New Challenge', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
        IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white), onPressed: () {}),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: const Text('Social & Challenges', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.orange.shade700, AppColors.primary],
                ),
              ),
            ),
            CustomPaint(painter: _SocialPatternPainter()),
            Positioned(
              left: 16,
              bottom: 60,
              child: ValueListenableBuilder(
                valueListenable: StorageService.challengesListenable,
                builder: (context, box, _) {
                    final challenges = box.values.toList();
                    final activeChallenges = challenges.where((c) => c.isActive && c.isJoined).length;
                    return Row(
                        children: [
                        _buildQuickStat('$activeChallenges', 'Active Challenges'),
                        const SizedBox(width: 20),
                        _buildQuickStat('${challenges.length}', 'Total Available'),
                        ],
                    );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildChallengesTab() {
    return ValueListenableBuilder(
      valueListenable: StorageService.challengesListenable,
      builder: (context, box, _) {
        final challenges = box.values.toList();
        
        if (challenges.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Icon(Icons.emoji_events_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
                 const SizedBox(height: 16),
                 const Text('No challenges available', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                 TextButton(onPressed: _createChallenge, child: const Text('Create a Challenge')),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Your Active Challenges', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...challenges.where((c) => c.isJoined && c.isActive).map((c) => _buildChallengeCard(c)),
            
            const SizedBox(height: 24),
            const Text('Discover', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...challenges.where((c) => !c.isJoined && c.isActive).map((c) => _buildChallengeCard(c)),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _buildChallengeCard(FitnessChallenge challenge) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              image: challenge.imageUrl != null 
                ? DecorationImage(image: NetworkImage(challenge.imageUrl!), fit: BoxFit.cover)
                : null,
            ),
            child: Stack(
              children: [
                if (challenge.imageUrl == null)
                    Center(child: Icon(Icons.emoji_events, size: 50, color: Colors.orange.withOpacity(0.3))),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Text('${challenge.daysRemaining} days left', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.orange)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(challenge.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    if (challenge.isJoined)
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  ],
                ),
                const SizedBox(height: 8),
                Text(challenge.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 16),
                if (challenge.isJoined) ...[
                  LinearProgressIndicator(
                    value: challenge.progressPercentage / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${challenge.currentProgress.toStringAsFixed(1)} / ${challenge.targetValue} ${challenge.targetUnit}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('${challenge.progressPercentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ] else
                   ElevatedButton(
                      onPressed: () {
                          // Join logic
                          StorageService.joinChallenge(challenge.id, 'currentUser', 'Me');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 36),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Join Challenge', style: TextStyle(color: Colors.white)),
                   ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.people, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${challenge.participants.length} participants', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    return ValueListenableBuilder(
      valueListenable: StorageService.leaderboardListenable,
      builder: (context, box, _) {
          final entries = box.values.toList()..sort((a, b) => a.rank.compareTo(b.rank));
          
          if (entries.isEmpty) {
             return const Center(child: Text('No leaderboard data yet.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
                Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: Row(
                    children: [
                    const Icon(Icons.leaderboard, color: Colors.orange),
                    const SizedBox(width: 12),
                    const Text('Overall Ranking', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    DropdownButton<String>(
                        value: 'This Week',
                        items: ['This Week', 'This Month', 'All Time'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (v) {},
                        underline: const SizedBox(),
                        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                    ),
                    ],
                ),
                ),
                const SizedBox(height: 16),
                ...entries.map((entry) => _buildLeaderboardItem(entry)),
            ],
          );
      }
    );
  }

  Widget _buildLeaderboardItem(LeaderboardEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: entry.isCurrentUser ? AppColors.primary.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: entry.isCurrentUser ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              entry.rank <= 3 ? entry.rankEmoji : '#${entry.rank}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: entry.rank <= 3 ? 18 : 14),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: entry.userAvatarUrl != null ? NetworkImage(entry.userAvatarUrl!) : null,
            child: entry.userAvatarUrl == null ? const Icon(Icons.person, color: Colors.grey, size: 20) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.userName,
              style: TextStyle(fontWeight: FontWeight.bold, color: entry.isCurrentUser ? AppColors.primary : Colors.black),
            ),
          ),
          Text(entry.formattedTime, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFeedTab() {
     return ValueListenableBuilder(
      valueListenable: StorageService.socialFeedListenable,
      builder: (context, box, _) {
          final items = box.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          
          if (items.isEmpty) {
              return const Center(child: Text('Activity feed is empty.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(
                                    children: [
                                        CircleAvatar(child: Text(item.userName[0])),
                                        const SizedBox(width: 12),
                                        Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                Text(item.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                Text(item.timeAgo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
                                        ),
                                        const Spacer(),
                                        Text(item.activityEmoji, style: const TextStyle(fontSize: 20)),
                                    ],
                                ),
                                const SizedBox(height: 12),
                                Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                if (item.description != null) ...[
                                    const SizedBox(height: 4),
                                    Text(item.description!, style: const TextStyle(color: Colors.grey)),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                    children: [
                                        const Icon(Icons.thumb_up_alt_outlined, size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text('${item.kudosCount}'),
                                        const SizedBox(width: 16),
                                        const Icon(Icons.comment_outlined, size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        const Text('Comment'),
                                    ],
                                ),
                            ],
                        ),
                    ),
                );
            },
          );
      }
    );
  }

  Widget _buildFriendsTab() {
    // Placeholder for friends list
    return const Center(child: Text('Friends list coming soon!'));
  }

  void _createChallenge() {
      // Mock create challenge
      final newChallenge = FitnessChallenge(
          id: DateTime.now().toIso8601String(),
          name: 'New Challenge ${DateTime.now().minute}',
          description: 'A user created challenge',
          challengeType: 'distance',
          activityType: 'run',
          targetValue: 50,
          targetUnit: 'km',
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          participants: [],
          imageUrl: null,
          isJoined: true,
          currentProgress: 0,
          privacy: 'public',
          creatorId: 'currentUser',
      );
      StorageService.addChallenge(newChallenge);
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: AppColors.background, child: tabBar);
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

class _SocialPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    var path = Path();
    for (var i = 0; i < size.width; i += 40) {
      path.moveTo(i.toDouble(), 0);
      path.lineTo(i.toDouble() + 50, size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

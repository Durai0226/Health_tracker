import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/common_tab_widgets.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/focus_leaderboard.dart';
import '../services/leaderboard_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  final LeaderboardService _leaderboardService = LeaderboardService();
  late TabController _tabController;
  
  LeaderboardType _selectedPeriod = LeaderboardType.weekly;
  LeaderboardCategory _selectedCategory = LeaderboardCategory.focusTime;
  Leaderboard? _globalLeaderboard;
  Leaderboard? _friendsLeaderboard;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initService();
  }

  Future<void> _initService() async {
    await _leaderboardService.init();
    await _fetchLeaderboards();
  }

  Future<void> _fetchLeaderboards() async {
    setState(() => _isLoading = true);
    
    _globalLeaderboard = await _leaderboardService.getLeaderboard(
      _selectedPeriod,
      _selectedCategory,
    );
    _friendsLeaderboard = await _leaderboardService.getFriendsLeaderboard(
      _selectedCategory,
    );
    
    setState(() => _isLoading = false);
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
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _leaderboardService,
          builder: (context, _) {
            return Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                _buildFilters(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildFriendsLeaderboard(),
                            _buildGlobalLeaderboard(),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Leaderboards',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _showFriendCodeDialog,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: CommonTabBar(
        tabs: const ['Friends', 'Global'],
        controller: _tabController,
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: LeaderboardType.values.map((type) {
                final isSelected = _selectedPeriod == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedPeriod = type);
                      _fetchLeaderboards();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        type.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: LeaderboardCategory.values.map((category) {
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = category);
                      _fetchLeaderboards();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? category.color.withOpacity(0.15) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? category.color : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(category.emoji),
                          const SizedBox(width: 6),
                          Text(
                            category.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? category.color : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalLeaderboard() {
    if (_globalLeaderboard == null || _globalLeaderboard!.entries.isEmpty) {
      return _buildEmptyState('No leaderboard data available');
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        _buildTopThree(_globalLeaderboard!.topThree),
        const SizedBox(height: 24),
        ..._globalLeaderboard!.restOfList.map(_buildLeaderboardEntry),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildFriendsLeaderboard() {
    if (_leaderboardService.friends.isEmpty) {
      return _buildEmptyFriendsState();
    }

    if (_friendsLeaderboard == null || _friendsLeaderboard!.entries.isEmpty) {
      return _buildEmptyState('No friends data available');
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        if (_friendsLeaderboard!.entries.length >= 3)
          _buildTopThree(_friendsLeaderboard!.topThree),
        const SizedBox(height: 24),
        ..._friendsLeaderboard!.entries.skip(3).map(_buildLeaderboardEntry),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildTopThree(List<LeaderboardEntry> topThree) {
    if (topThree.isEmpty) return const SizedBox();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (topThree.length > 1)
          Expanded(child: _buildPodiumItem(topThree[1], 2, 100)),
        Expanded(child: _buildPodiumItem(topThree[0], 1, 130)),
        if (topThree.length > 2)
          Expanded(child: _buildPodiumItem(topThree[2], 3, 80)),
      ],
    );
  }

  Widget _buildPodiumItem(LeaderboardEntry entry, int rank, double height) {
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFFC0C0C0),
      const Color(0xFFCD7F32),
    ];
    final color = colors[rank - 1];

    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: entry.isCurrentUser ? AppColors.primary : Colors.grey.shade200,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
          child: Center(
            child: Text(
              entry.displayName[0].toUpperCase(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: entry.isCurrentUser ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          entry.displayName,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: entry.isCurrentUser ? AppColors.primary : AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          _formatValue(entry.value),
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withOpacity(0.7)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Center(
            child: Text(
              rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardEntry(LeaderboardEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: entry.isCurrentUser ? AppColors.primary.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: entry.isCurrentUser
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: entry.isCurrentUser ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: entry.isCurrentUser ? AppColors.primary : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                entry.displayName[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: entry.isCurrentUser ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isCurrentUser ? 'You' : entry.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: entry.isCurrentUser ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                if (entry.rankChange != null)
                  Row(
                    children: [
                      Icon(
                        entry.rankImproved
                            ? Icons.arrow_upward_rounded
                            : entry.rankDeclined
                                ? Icons.arrow_downward_rounded
                                : Icons.remove_rounded,
                        size: 12,
                        color: entry.rankImproved
                            ? Colors.green
                            : entry.rankDeclined
                                ? Colors.red
                                : Colors.grey,
                      ),
                      Text(
                        '${entry.rankChange!.abs()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: entry.rankImproved
                              ? Colors.green
                              : entry.rankDeclined
                                  ? Colors.red
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Text(
            _formatValue(entry.value),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _selectedCategory.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📊', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFriendsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👥', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Add friends to compare!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share your friend code or add friends to see how you compare',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showFriendCodeDialog,
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              label: const Text('Add Friend', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFriendCodeDialog() {
    final codeController = TextEditingController();
    final myCode = _leaderboardService.userProfile?.friendCode ?? 'Loading...';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Friend Code',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    'Your Code',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        myCode,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: myCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied!')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Enter Friend\'s Code',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (codeController.text.isEmpty) return;
                  final success = await _leaderboardService.addFriendByCode(
                    codeController.text.toUpperCase(),
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Friend added!' : 'Invalid code'),
                      ),
                    );
                    if (success) _fetchLeaderboards();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Add Friend', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatValue(int value) {
    switch (_selectedCategory) {
      case LeaderboardCategory.focusTime:
        final hours = value ~/ 60;
        final mins = value % 60;
        return hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
      case LeaderboardCategory.streakDays:
        return '$value days';
      default:
        return '$value';
    }
  }
}

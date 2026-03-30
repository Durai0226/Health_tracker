import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/habit_social_service.dart';
import '../theme/habit_theme.dart';

/// Friends Screen - Manage friends and view challenges
/// Only available for registered (non-anonymous) users
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final HabitSocialService _socialService = HabitSocialService();
  final _searchController = TextEditingController();
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HabitTheme.background,
      appBar: AppBar(
        backgroundColor: HabitTheme.white,
        elevation: 0,
        title: Text('Friends', style: HabitTheme.h1),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: HabitTheme.primary,
          unselectedLabelColor: HabitTheme.gray,
          indicatorColor: HabitTheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'FRIEND LISTS'),
            Tab(text: 'CHALLENGES'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: _socialService,
        builder: (context, _) {
          // Check if social features are available
          if (!_socialService.areSocialFeaturesAvailable) {
            return _buildLoginRequired();
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildFriendsList(),
              _buildChallengesList(),
            ],
          );
        },
      ),
      floatingActionButton: _socialService.areSocialFeaturesAvailable
          ? FloatingActionButton(
              onPressed: () => _showAddFriendDialog(),
              backgroundColor: HabitTheme.primary,
              child: const Icon(Icons.person_add, color: HabitTheme.white),
            )
          : null,
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: HabitTheme.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 48,
                color: HabitTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Sign in to connect',
              style: HabitTheme.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Create an account or sign in to connect with friends and join challenges.',
              style: HabitTheme.b2.copyWith(color: HabitTheme.gray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Navigate to login/signup
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: HabitTheme.primary,
                foregroundColor: HabitTheme.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
                ),
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search friends...',
              hintStyle: HabitTheme.b2.copyWith(color: HabitTheme.gray),
              prefixIcon: const Icon(Icons.search, color: HabitTheme.gray),
              filled: true,
              fillColor: HabitTheme.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
          ),
        ),
        // Friends list
        Expanded(
          child: _socialService.acceptedFriends.isEmpty
              ? _buildEmptyFriends()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _socialService.acceptedFriends.length,
                  itemBuilder: (context, index) {
                    final friend = _socialService.acceptedFriends[index];
                    return _buildFriendCard(friend);
                  },
                ),
        ),
        // Pending requests section
        if (_socialService.pendingFriends.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Pending Requests',
                  style: HabitTheme.label,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: HabitTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_socialService.pendingFriends.length}',
                    style: HabitTheme.caption.copyWith(
                      color: HabitTheme.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _socialService.pendingFriends.length,
              itemBuilder: (context, index) {
                final friend = _socialService.pendingFriends[index];
                return _buildPendingCard(friend);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyFriends() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: HabitTheme.grayLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No friends yet',
            style: HabitTheme.b1.copyWith(color: HabitTheme.gray),
          ),
          const SizedBox(height: 8),
          Text(
            'Add friends to challenge each other!',
            style: HabitTheme.description,
          ),
        ],
      ),
    );
  }

  Widget _buildFriendCard(HabitFriend friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(HabitTheme.radiusL),
        boxShadow: HabitTheme.subtleShadow,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: HabitTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                friend.displayName.substring(0, 1).toUpperCase(),
                style: HabitTheme.h2.copyWith(color: HabitTheme.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.displayName,
                  style: HabitTheme.b1.copyWith(fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getTierColor(friend.tier).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        friend.tierLabel,
                        style: HabitTheme.caption.copyWith(
                          color: _getTierColor(friend.tier),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Lvl ${friend.cityLevel}',
                      style: HabitTheme.description,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Actions menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: HabitTheme.gray),
            onSelected: (action) => _handleFriendAction(action, friend),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'chat',
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Chat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'challenge',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Create challenge'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.person_remove_outlined, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Remove', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(HabitFriend friend) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(HabitTheme.radiusL),
        boxShadow: HabitTheme.subtleShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: HabitTheme.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                friend.displayName.substring(0, 1).toUpperCase(),
                style: HabitTheme.b1.copyWith(color: HabitTheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            friend.displayName,
            style: HabitTheme.b3,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _socialService.acceptFriendRequest(friend.oderId),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: HabitTheme.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: HabitTheme.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _socialService.declineFriendRequest(friend.oderId),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: HabitTheme.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: HabitTheme.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChallengesList() {
    final activeChallenges = _socialService.activeChallenges;
    final pendingChallenges = _socialService.pendingChallenges;

    if (activeChallenges.isEmpty && pendingChallenges.isEmpty) {
      return _buildEmptyChallenges();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pendingChallenges.isNotEmpty) ...[
          Text('Pending Invites', style: HabitTheme.label),
          const SizedBox(height: 12),
          ...pendingChallenges.map((c) => _buildChallengeCard(c, isPending: true)),
          const SizedBox(height: 24),
        ],
        if (activeChallenges.isNotEmpty) ...[
          Text('Active Challenges', style: HabitTheme.label),
          const SizedBox(height: 12),
          ...activeChallenges.map((c) => _buildChallengeCard(c)),
        ],
      ],
    );
  }

  Widget _buildEmptyChallenges() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flag_outlined,
            size: 64,
            color: HabitTheme.grayLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No challenges yet',
            style: HabitTheme.b1.copyWith(color: HabitTheme.gray),
          ),
          const SizedBox(height: 8),
          Text(
            'Challenge your friends to build habits together!',
            style: HabitTheme.description,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/habit/create-challenge'),
            style: ElevatedButton.styleFrom(
              backgroundColor: HabitTheme.primary,
              foregroundColor: HabitTheme.white,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Create Challenge'),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(HabitChallenge challenge, {bool isPending = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HabitTheme.white,
        borderRadius: BorderRadius.circular(HabitTheme.radiusXL),
        boxShadow: HabitTheme.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: HabitTheme.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.flag,
                  color: HabitTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: HabitTheme.b1.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${challenge.daysRemaining} days remaining',
                      style: HabitTheme.description,
                    ),
                  ],
                ),
              ),
              if (isPending)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: HabitTheme.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(HabitTheme.radiusFull),
                  ),
                  child: Text(
                    'Pending',
                    style: HabitTheme.caption.copyWith(
                      color: HabitTheme.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          LinearProgressIndicator(
            value: challenge.progress,
            backgroundColor: HabitTheme.grayLight,
            valueColor: const AlwaysStoppedAnimation(HabitTheme.primary),
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          // Habits included
          Wrap(
            spacing: 8,
            children: challenge.habitNames.take(3).map((name) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: HabitTheme.grayLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  name,
                  style: HabitTheme.caption,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Participants avatars
          Row(
            children: [
              ...challenge.participants.take(4).map((p) {
                return Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: HabitTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: HabitTheme.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      p.displayName.substring(0, 1).toUpperCase(),
                      style: HabitTheme.caption.copyWith(
                        color: HabitTheme.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                );
              }),
              if (challenge.participants.length > 4)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: HabitTheme.grayLight,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '+${challenge.participants.length - 4}',
                      style: HabitTheme.caption.copyWith(fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Decline challenge
                    },
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _socialService.acceptChallenge(challenge.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HabitTheme.primary,
                      foregroundColor: HabitTheme.white,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getTierColor(UserTier tier) {
    return switch (tier) {
      UserTier.bronze => const Color(0xFFCD7F32),
      UserTier.silver => const Color(0xFFC0C0C0),
      UserTier.gold => const Color(0xFFFFD700),
      UserTier.platinum => const Color(0xFFE5E4E2),
      UserTier.diamond => const Color(0xFFB9F2FF),
    };
  }

  void _handleFriendAction(String action, HabitFriend friend) {
    switch (action) {
      case 'chat':
        // Open chat
        break;
      case 'challenge':
        Navigator.pushNamed(
          context,
          '/habit/create-challenge',
          arguments: [friend.oderId],
        );
        break;
      case 'profile':
        // View profile
        break;
      case 'remove':
        _showRemoveFriendDialog(friend);
        break;
    }
  }

  void _showAddFriendDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HabitTheme.radiusXL),
        ),
        title: const Text('Add Friend'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            hintText: 'Enter email address',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Send friend request
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Friend request sent!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HabitTheme.primary,
            ),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  void _showRemoveFriendDialog(HabitFriend friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Remove ${friend.displayName} from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _socialService.removeFriend(friend.oderId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HabitTheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

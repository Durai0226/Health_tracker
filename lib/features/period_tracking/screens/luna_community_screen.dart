import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/luna_theme.dart';
import '../widgets/luna_widgets.dart';
import '../models/luna_community.dart';
import '../services/luna_community_service.dart';

/// Community screen for Luna Cycle - Dynamic with persistence
class LunaCommunityScreen extends StatefulWidget {
  const LunaCommunityScreen({super.key});

  @override
  State<LunaCommunityScreen> createState() => _LunaCommunityScreenState();
}

class _LunaCommunityScreenState extends State<LunaCommunityScreen> {
  int _selectedTab = 0;
  LunaPostCategory? _selectedCategory;
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Consumer<LunaCommunityService>(
      builder: (context, communityService, _) {
        return Scaffold(
          backgroundColor: LunaTheme.getBackground(context),
          body: communityService.isLoading
              ? const Center(child: CircularProgressIndicator(color: LunaTheme.primaryPink))
              : CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // App bar
                    SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(LunaTheme.spacingLg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Community',
                            style: LunaTheme.headlineLarge.copyWith(
                              color: LunaTheme.getTextPrimary(context),
                            ),
                          ),
                          Text(
                            'Connect, share, and support',
                            style: LunaTheme.bodyMedium.copyWith(
                              color: LunaTheme.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tab bar
          SliverToBoxAdapter(
            child: LunaTabBar(
              tabs: const ['Feed', 'Groups', 'Saved'],
              selectedIndex: _selectedTab,
              onTap: (index) => setState(() => _selectedTab = index),
            ),
          ),

          // Category filter
          if (_selectedTab == 0)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: LunaTheme.spacingLg,
                    vertical: LunaTheme.spacingSm,
                  ),
                  children: [
                    LunaCategoryChip(
                      category: LunaPostCategory.general,
                      isSelected: _selectedCategory == null,
                      onTap: () => setState(() => _selectedCategory = null),
                    ),
                    const SizedBox(width: LunaTheme.spacingSm),
                    ...LunaPostCategory.values.take(6).map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(right: LunaTheme.spacingSm),
                        child: LunaCategoryChip(
                          category: category,
                          isSelected: _selectedCategory == category,
                          onTap: () => setState(() => _selectedCategory = category),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: LunaTheme.spacingMd),
          ),

                    // Content based on tab
                    if (_selectedTab == 0) _buildFeed(communityService),
                    if (_selectedTab == 1) _buildGroups(communityService),
                    if (_selectedTab == 2) _buildSaved(communityService),

                    // Bottom spacing
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                ),
          floatingActionButton: _selectedTab == 0
              ? LunaCreatePostFAB(onTap: () => _showCreatePostSheet(communityService))
              : null,
        );
      },
    );
  }

  Widget _buildFeed(LunaCommunityService service) {
    final allPosts = service.posts;
    final posts = _selectedCategory == null
        ? allPosts
        : allPosts.where((p) => p.category == _selectedCategory).toList();

    if (posts.isEmpty) {
      return SliverToBoxAdapter(
        child: LunaEmptyState(
          icon: Icons.chat_bubble_outline,
          title: 'No posts yet',
          subtitle: 'Be the first to share in this category',
          actionLabel: 'Create Post',
          onAction: () => _showCreatePostSheet(service),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final post = posts[index];
          return LunaCommunityPostCard(
            post: post,
            onTap: () => _showPostDetail(post),
            onLike: () => _toggleLike(service, post.id),
            onComment: () => _showPostDetail(post),
            onSave: () => _toggleSave(service, post.id),
            onShare: () => _sharePost(post),
          );
        },
        childCount: posts.length,
      ),
    );
  }

  Widget _buildGroups(LunaCommunityService service) {
    final groups = service.groups;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final group = groups[index];
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LunaTheme.spacingLg,
              vertical: LunaTheme.spacingSm,
            ),
            child: LunaSupportGroupCard(
              group: group,
              onTap: () {},
              onJoin: () {},
            ),
          );
        },
        childCount: groups.length,
      ),
    );
  }

  Widget _buildSaved(LunaCommunityService service) {
    final savedPosts = service.posts.where((p) => p.isSavedByUser).toList();
    
    if (savedPosts.isEmpty) {
      return SliverToBoxAdapter(
        child: LunaEmptyState(
          icon: Icons.bookmark_outline,
          title: 'No saved posts',
          subtitle: 'Save posts to read later',
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final post = savedPosts[index];
          return LunaCommunityPostCard(
            post: post,
            onTap: () => _showPostDetail(post),
            onLike: () => _toggleLike(service, post.id),
            onComment: () => _showPostDetail(post),
            onSave: () => _toggleSave(service, post.id),
            onShare: () => _sharePost(post),
          );
        },
        childCount: savedPosts.length,
      ),
    );
  }

  void _showCreatePostSheet(LunaCommunityService service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreatePostSheet(
        onPost: (content, category, isAnonymous, mood) async {
          Navigator.pop(context);
          
          // Create the post using the service
          final post = await service.createPost(
            content: content,
            category: category,
            isAnonymous: isAnonymous,
            mood: mood,
          );
          
          if (post != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Post created successfully!'),
                backgroundColor: LunaTheme.success,
              ),
            );
          }
        },
      ),
    );
  }

  void _showPostDetail(LunaCommunityPost post) {
    // Navigate to post detail - show in a dialog for now
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (post.mood != null) Text(post.mood!.emoji),
            const SizedBox(width: 8),
            Text(post.isAnonymous ? 'Anonymous' : 'User'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(post.content),
              const SizedBox(height: 12),
              Text(
                '${post.likesCount} likes • ${post.commentsCount} comments',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _toggleLike(LunaCommunityService service, String postId) async {
    HapticFeedback.lightImpact();
    await service.toggleLike(postId);
  }

  void _toggleSave(LunaCommunityService service, String postId) async {
    HapticFeedback.lightImpact();
    await service.toggleSave(postId);
  }

  void _sharePost(LunaCommunityPost post) {
    HapticFeedback.mediumImpact();
    Share.share(
      '${post.content}\n\n- Shared from Luna Cycle Community',
      subject: 'Luna Cycle Community Post',
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  final Function(String content, LunaPostCategory category, bool isAnonymous, LunaPostMood? mood) onPost;

  const _CreatePostSheet({required this.onPost});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _contentController = TextEditingController();
  LunaPostCategory _selectedCategory = LunaPostCategory.general;
  bool _isAnonymous = true;
  LunaPostMood? _selectedMood;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: LunaTheme.getSurface(context),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(LunaTheme.radius2xl),
        ),
      ),
      child: Column(
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

          // Header
          Padding(
            padding: const EdgeInsets.all(LunaTheme.spacingLg),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: LunaTheme.titleMedium.copyWith(
                      color: LunaTheme.getTextSecondary(context),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Create Post',
                  style: LunaTheme.headlineSmall.copyWith(
                    color: LunaTheme.getTextPrimary(context),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    if (_contentController.text.trim().isNotEmpty) {
                      widget.onPost(
                        _contentController.text.trim(),
                        _selectedCategory,
                        _isAnonymous,
                        _selectedMood,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: LunaTheme.spacingMd,
                      vertical: LunaTheme.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      color: LunaTheme.primaryPink,
                      borderRadius: BorderRadius.circular(LunaTheme.radiusFull),
                    ),
                    child: Text(
                      'Post',
                      style: LunaTheme.titleMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(LunaTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Anonymous toggle
                  Row(
                    children: [
                      Icon(
                        _isAnonymous ? Icons.visibility_off : Icons.person,
                        color: LunaTheme.primaryPink,
                        size: 20,
                      ),
                      const SizedBox(width: LunaTheme.spacingSm),
                      Text(
                        _isAnonymous ? 'Posting anonymously' : 'Posting as yourself',
                        style: LunaTheme.bodyMedium.copyWith(
                          color: LunaTheme.getTextSecondary(context),
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _isAnonymous,
                        onChanged: (value) => setState(() => _isAnonymous = value),
                        activeColor: LunaTheme.primaryPink,
                      ),
                    ],
                  ),

                  const SizedBox(height: LunaTheme.spacingLg),

                  // Content input
                  TextField(
                    controller: _contentController,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: 'What\'s on your mind?',
                      hintStyle: LunaTheme.bodyLarge.copyWith(
                        color: LunaTheme.getTextTertiary(context),
                      ),
                      border: InputBorder.none,
                    ),
                    style: LunaTheme.bodyLarge.copyWith(
                      color: LunaTheme.getTextPrimary(context),
                    ),
                  ),

                  const SizedBox(height: LunaTheme.spacingLg),

                  // Category selection
                  Text(
                    'Category',
                    style: LunaTheme.titleMedium.copyWith(
                      color: LunaTheme.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: LunaTheme.spacingSm),
                  Wrap(
                    spacing: LunaTheme.spacingSm,
                    runSpacing: LunaTheme.spacingSm,
                    children: LunaPostCategory.values.take(8).map((category) {
                      return LunaCategoryChip(
                        category: category,
                        isSelected: _selectedCategory == category,
                        onTap: () => setState(() => _selectedCategory = category),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: LunaTheme.spacingXl),

                  // Mood selection
                  Text(
                    'How are you feeling?',
                    style: LunaTheme.titleMedium.copyWith(
                      color: LunaTheme.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: LunaTheme.spacingSm),
                  Wrap(
                    spacing: LunaTheme.spacingSm,
                    children: LunaPostMood.values.map((mood) {
                      final isSelected = _selectedMood == mood;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedMood = isSelected ? null : mood;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(LunaTheme.spacingMd),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? LunaTheme.primaryPink.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(LunaTheme.radiusMd),
                            border: Border.all(
                              color: isSelected
                                  ? LunaTheme.primaryPink
                                  : LunaTheme.getDivider(context),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(mood.emoji, style: const TextStyle(fontSize: 24)),
                              const SizedBox(height: 2),
                              Text(
                                mood.label,
                                style: LunaTheme.labelSmall.copyWith(
                                  color: isSelected
                                      ? LunaTheme.primaryPink
                                      : LunaTheme.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

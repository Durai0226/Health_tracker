import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/luna_community.dart';

/// Service for Luna Cycle community features
/// Handles posts, comments, groups, and anonymous interactions
class LunaCommunityService extends ChangeNotifier {
  static const String _savedPostsKey = 'luna_saved_posts';
  static const String _likedPostsKey = 'luna_liked_posts';
  static const String _joinedGroupsKey = 'luna_joined_groups';
  
  List<LunaCommunityPost> _posts = [];
  List<LunaSupportGroup> _groups = [];
  Set<String> _savedPostIds = {};
  Set<String> _likedPostIds = {};
  Set<String> _joinedGroupIds = {};
  bool _isLoading = false;

  List<LunaCommunityPost> get posts => _posts;
  List<LunaSupportGroup> get groups => _groups;
  bool get isLoading => _isLoading;

  String? get _currentUserId {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  bool get isAuthenticated {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    return user != null && !user.isAnonymous;
  }

  /// Initialize the service
  Future<void> initialize() async {
    await _loadLocalData();
    await fetchPosts();
    _groups = LunaPredefinedGroups.all;
    notifyListeners();
  }

  /// Load local saved/liked data
  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final savedJson = prefs.getStringList(_savedPostsKey);
      if (savedJson != null) {
        _savedPostIds = savedJson.toSet();
      }
      
      final likedJson = prefs.getStringList(_likedPostsKey);
      if (likedJson != null) {
        _likedPostIds = likedJson.toSet();
      }
      
      final joinedJson = prefs.getStringList(_joinedGroupsKey);
      if (joinedJson != null) {
        _joinedGroupIds = joinedJson.toSet();
      }
    } catch (e) {
      debugPrint('Error loading local community data: $e');
    }
  }

  /// Save local data
  Future<void> _saveLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_savedPostsKey, _savedPostIds.toList());
      await prefs.setStringList(_likedPostsKey, _likedPostIds.toList());
      await prefs.setStringList(_joinedGroupsKey, _joinedGroupIds.toList());
    } catch (e) {
      debugPrint('Error saving local community data: $e');
    }
  }

  /// Fetch posts from Firestore
  Future<void> fetchPosts({LunaPostCategory? category, int limit = 50}) async {
    if (!isAuthenticated) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      Query query = FirebaseFirestore.instance
          .collection('luna_community_posts')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (category != null) {
        query = query.where('category', isEqualTo: category.index);
      }

      final snapshot = await query.get();
      
      _posts = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        final post = LunaCommunityPost.fromJson(data);
        return post.copyWith(
          isLikedByUser: _likedPostIds.contains(post.id),
          isSavedByUser: _savedPostIds.contains(post.id),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      // Return sample posts for demo
      _posts = _getSamplePosts();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Create a new post
  Future<LunaCommunityPost?> createPost({
    required String content,
    required LunaPostCategory category,
    List<String> tags = const [],
    bool isAnonymous = true,
    LunaPostMood? mood,
    List<String>? imageUrls,
  }) async {
    if (!isAuthenticated) return null;

    try {
      final userId = _currentUserId!;
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      
      final postData = {
        'authorId': userId,
        'authorName': isAnonymous ? null : user?.displayName,
        'isAnonymous': isAnonymous,
        'content': content,
        'category': category.index,
        'tags': tags,
        'likesCount': 0,
        'commentsCount': 0,
        'sharesCount': 0,
        'isPinned': false,
        'isVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
        'mood': mood?.index,
        'imageUrls': imageUrls,
      };

      final docRef = await FirebaseFirestore.instance
          .collection('luna_community_posts')
          .add(postData);

      final post = LunaCommunityPost(
        id: docRef.id,
        authorId: userId,
        authorName: isAnonymous ? null : user?.displayName,
        isAnonymous: isAnonymous,
        content: content,
        category: category,
        tags: tags,
        mood: mood,
        imageUrls: imageUrls,
        createdAt: DateTime.now(),
      );

      _posts.insert(0, post);
      notifyListeners();
      return post;
    } catch (e) {
      debugPrint('Error creating post: $e');
      return null;
    }
  }

  /// Like/unlike a post
  Future<void> toggleLike(String postId) async {
    final isLiked = _likedPostIds.contains(postId);
    
    if (isLiked) {
      _likedPostIds.remove(postId);
    } else {
      _likedPostIds.add(postId);
    }

    // Update local state
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _posts[index];
      _posts[index] = post.copyWith(
        isLikedByUser: !isLiked,
        likesCount: post.likesCount + (isLiked ? -1 : 1),
      );
    }

    await _saveLocalData();
    notifyListeners();

    // Update Firestore
    if (isAuthenticated) {
      try {
        await FirebaseFirestore.instance
            .collection('luna_community_posts')
            .doc(postId)
            .update({
          'likesCount': FieldValue.increment(isLiked ? -1 : 1),
        });
      } catch (e) {
        debugPrint('Error updating like: $e');
      }
    }
  }

  /// Save/unsave a post
  Future<void> toggleSave(String postId) async {
    final isSaved = _savedPostIds.contains(postId);
    
    if (isSaved) {
      _savedPostIds.remove(postId);
    } else {
      _savedPostIds.add(postId);
    }

    // Update local state
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      _posts[index] = _posts[index].copyWith(isSavedByUser: !isSaved);
    }

    await _saveLocalData();
    notifyListeners();
  }

  /// Get saved posts
  List<LunaCommunityPost> get savedPosts {
    return _posts.where((p) => _savedPostIds.contains(p.id)).toList();
  }

  /// Join/leave a group
  Future<void> toggleGroupMembership(String groupId) async {
    final isJoined = _joinedGroupIds.contains(groupId);
    
    if (isJoined) {
      _joinedGroupIds.remove(groupId);
    } else {
      _joinedGroupIds.add(groupId);
    }

    await _saveLocalData();
    notifyListeners();
  }

  /// Check if user joined a group
  bool isGroupJoined(String groupId) => _joinedGroupIds.contains(groupId);

  /// Get joined groups
  List<LunaSupportGroup> get joinedGroups {
    return _groups.where((g) => _joinedGroupIds.contains(g.id)).toList();
  }

  /// Add a comment to a post
  Future<LunaCommunityComment?> addComment({
    required String postId,
    required String content,
    bool isAnonymous = true,
    String? parentCommentId,
  }) async {
    if (!isAuthenticated) return null;

    try {
      final userId = _currentUserId!;
      final user = firebase_auth.FirebaseAuth.instance.currentUser;

      final commentData = {
        'postId': postId,
        'authorId': userId,
        'authorName': isAnonymous ? null : user?.displayName,
        'isAnonymous': isAnonymous,
        'content': content,
        'likesCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'parentCommentId': parentCommentId,
      };

      final docRef = await FirebaseFirestore.instance
          .collection('luna_community_comments')
          .add(commentData);

      // Update post comment count
      await FirebaseFirestore.instance
          .collection('luna_community_posts')
          .doc(postId)
          .update({
        'commentsCount': FieldValue.increment(1),
      });

      // Update local post
      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _posts[index] = _posts[index].copyWith(
          commentsCount: _posts[index].commentsCount + 1,
        );
        notifyListeners();
      }

      return LunaCommunityComment(
        id: docRef.id,
        postId: postId,
        authorId: userId,
        authorName: isAnonymous ? null : user?.displayName,
        isAnonymous: isAnonymous,
        content: content,
        createdAt: DateTime.now(),
        parentCommentId: parentCommentId,
      );
    } catch (e) {
      debugPrint('Error adding comment: $e');
      return null;
    }
  }

  /// Get comments for a post
  Future<List<LunaCommunityComment>> getComments(String postId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('luna_community_comments')
          .where('postId', isEqualTo: postId)
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return LunaCommunityComment.fromJson(data);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      return [];
    }
  }

  /// Report a post
  Future<void> reportPost(String postId, String reason) async {
    if (!isAuthenticated) return;

    try {
      await FirebaseFirestore.instance.collection('luna_reports').add({
        'postId': postId,
        'reporterId': _currentUserId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('Error reporting post: $e');
    }
  }

  /// Delete own post
  Future<bool> deletePost(String postId) async {
    if (!isAuthenticated) return false;

    try {
      final post = _posts.firstWhere((p) => p.id == postId);
      if (post.authorId != _currentUserId) return false;

      await FirebaseFirestore.instance
          .collection('luna_community_posts')
          .doc(postId)
          .delete();

      _posts.removeWhere((p) => p.id == postId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting post: $e');
      return false;
    }
  }

  /// Get posts by category
  List<LunaCommunityPost> getPostsByCategory(LunaPostCategory category) {
    return _posts.where((p) => p.category == category).toList();
  }

  /// Search posts
  List<LunaCommunityPost> searchPosts(String query) {
    final lowerQuery = query.toLowerCase();
    return _posts.where((p) {
      return p.content.toLowerCase().contains(lowerQuery) ||
          p.tags.any((t) => t.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Sample posts for demo/offline mode
  List<LunaCommunityPost> _getSamplePosts() {
    return [
      LunaCommunityPost(
        id: 'sample-1',
        authorId: 'system',
        isAnonymous: true,
        content: 'Just discovered that tracking my symptoms helps me prepare for each phase of my cycle. Game changer! 🌙',
        category: LunaPostCategory.periodTalk,
        tags: ['tips', 'tracking'],
        likesCount: 42,
        commentsCount: 8,
        mood: LunaPostMood.happy,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      LunaCommunityPost(
        id: 'sample-2',
        authorId: 'system',
        isAnonymous: true,
        content: 'Anyone else feel extra creative during the follicular phase? I finally finished that project I\'ve been putting off!',
        category: LunaPostCategory.general,
        tags: ['follicular', 'productivity'],
        likesCount: 28,
        commentsCount: 12,
        mood: LunaPostMood.grateful,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      LunaCommunityPost(
        id: 'sample-3',
        authorId: 'system',
        isAnonymous: true,
        content: 'Self-care reminder: It\'s okay to rest during your period. Your body is doing amazing work. ❤️',
        category: LunaPostCategory.selfCare,
        tags: ['selfcare', 'period'],
        likesCount: 156,
        commentsCount: 23,
        mood: LunaPostMood.hopeful,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  /// Clear all data
  Future<void> clearAllData() async {
    _posts = [];
    _groups = [];
    _savedPostIds = {};
    _likedPostIds = {};
    _joinedGroupIds = {};
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedPostsKey);
    await prefs.remove(_likedPostsKey);
    await prefs.remove(_joinedGroupsKey);
    
    notifyListeners();
  }
}

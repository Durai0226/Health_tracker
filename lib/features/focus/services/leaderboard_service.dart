import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/services/storage_service.dart';
import '../models/focus_leaderboard.dart';

class LeaderboardService extends ChangeNotifier {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  UserProfile? _userProfile;
  List<FocusFriend> _friends = [];
  List<FriendRequest> _pendingRequests = [];
  final Map<String, Leaderboard> _cachedLeaderboards = {};

  UserProfile? get userProfile => _userProfile;
  List<FocusFriend> get friends => List.unmodifiable(_friends);
  List<FriendRequest> get pendingRequests => List.unmodifiable(_pendingRequests);
  int get friendCount => _friends.length;

  Future<void> init() async {
    await _loadData();
    if (_userProfile == null) {
      await _createDefaultProfile();
    }
    debugPrint('✓ LeaderboardService initialized');
  }

  Future<void> _loadData() async {
    try {
      final prefs = StorageService.getAppPreferences();
      
      final profileJson = prefs['focusUserProfile'];
      if (profileJson != null && profileJson is Map) {
        _userProfile = UserProfile.fromJson(Map<String, dynamic>.from(profileJson));
      }

      final friendsJson = prefs['focusFriends'];
      if (friendsJson != null && friendsJson is List) {
        _friends = friendsJson
            .map((f) => FocusFriend.fromJson(Map<String, dynamic>.from(f)))
            .toList();
      }

      final requestsJson = prefs['focusFriendRequests'];
      if (requestsJson != null && requestsJson is List) {
        _pendingRequests = requestsJson
            .map((r) => FriendRequest.fromJson(Map<String, dynamic>.from(r)))
            .toList();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading leaderboard data: $e');
    }
  }

  Future<void> _saveData() async {
    try {
      if (_userProfile != null) {
        await StorageService.setAppPreference('focusUserProfile', _userProfile!.toJson());
      }
      await StorageService.setAppPreference(
        'focusFriends',
        _friends.map((f) => f.toJson()).toList(),
      );
      await StorageService.setAppPreference(
        'focusFriendRequests',
        _pendingRequests.map((r) => r.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('Error saving leaderboard data: $e');
    }
  }

  Future<void> _createDefaultProfile() async {
    _userProfile = UserProfile(
      oderId: _generateId(),
      displayName: 'Focus User',
      friendCode: _generateFriendCode(),
      joinedAt: DateTime.now(),
    );
    await _saveData();
  }

  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
    bool? isPublicProfile,
  }) async {
    if (_userProfile == null) return;

    _userProfile = _userProfile!.copyWith(
      displayName: displayName,
      avatarUrl: avatarUrl,
      isPublicProfile: isPublicProfile,
    );

    await _saveData();
    notifyListeners();
  }

  Future<void> updateStats({
    int? totalFocusMinutes,
    int? currentStreak,
    int? longestStreak,
    int? treesPlanted,
    int? realTreesPlanted,
  }) async {
    if (_userProfile == null) return;

    _userProfile = _userProfile!.copyWith(
      totalFocusMinutes: totalFocusMinutes,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      treesPlanted: treesPlanted,
      realTreesPlanted: realTreesPlanted,
    );

    await _saveData();
    notifyListeners();
  }

  Future<Leaderboard> getLeaderboard(
    LeaderboardType type,
    LeaderboardCategory category,
  ) async {
    final cacheKey = '${type.name}_${category.name}';
    
    if (_cachedLeaderboards.containsKey(cacheKey)) {
      final cached = _cachedLeaderboards[cacheKey]!;
      if (DateTime.now().difference(cached.lastFetched).inMinutes < 5) {
        return cached;
      }
    }

    final entries = _generateMockLeaderboard(type, category);
    
    final leaderboard = Leaderboard(
      type: type,
      category: category,
      entries: entries,
      lastFetched: DateTime.now(),
      currentUserEntry: entries.firstWhere(
        (e) => e.isCurrentUser,
        orElse: () => entries.first,
      ),
    );

    _cachedLeaderboards[cacheKey] = leaderboard;
    return leaderboard;
  }

  List<LeaderboardEntry> _generateMockLeaderboard(
    LeaderboardType type,
    LeaderboardCategory category,
  ) {
    final random = Random();
    final names = [
      'FocusMaster', 'TreeHugger', 'ZenStudent', 'ProductivityPro',
      'MindfulCoder', 'DeepWorker', 'FlowState', 'ConcentrationKing',
      'StudyBuddy', 'ForestGuardian', 'TimeWizard', 'FocusNinja',
    ];

    final entries = <LeaderboardEntry>[];
    
    for (int i = 0; i < 50; i++) {
      int value;
      switch (category) {
        case LeaderboardCategory.focusTime:
          value = (1000 - i * 15 + random.nextInt(10)) * (type == LeaderboardType.daily ? 1 : 
                   type == LeaderboardType.weekly ? 7 : 
                   type == LeaderboardType.monthly ? 30 : 365);
          break;
        case LeaderboardCategory.treesPlanted:
          value = 500 - i * 8 + random.nextInt(5);
          break;
        case LeaderboardCategory.streakDays:
          value = 365 - i * 5 + random.nextInt(3);
          break;
        case LeaderboardCategory.sessionsCompleted:
          value = 1000 - i * 15 + random.nextInt(10);
          break;
        case LeaderboardCategory.realTreesPlanted:
          value = 100 - i * 2 + random.nextInt(2);
          break;
      }

      entries.add(LeaderboardEntry(
        oderId: 'user_$i',
        displayName: i == 15 ? (_userProfile?.displayName ?? 'You') : names[random.nextInt(names.length)],
        rank: i + 1,
        value: value.clamp(0, 999999),
        isCurrentUser: i == 15,
        lastUpdated: DateTime.now(),
        previousRank: i + 1 + random.nextInt(5) - 2,
      ));
    }

    return entries;
  }

  Future<Leaderboard> getFriendsLeaderboard(LeaderboardCategory category) async {
    if (_friends.isEmpty) {
      return Leaderboard(
        type: LeaderboardType.allTime,
        category: category,
        entries: [],
        lastFetched: DateTime.now(),
      );
    }

    final entries = _friends.asMap().entries.map((entry) {
      int value;
      switch (category) {
        case LeaderboardCategory.focusTime:
          value = entry.value.totalFocusMinutes;
          break;
        case LeaderboardCategory.treesPlanted:
          value = entry.value.treesPlanted;
          break;
        case LeaderboardCategory.streakDays:
          value = entry.value.currentStreak;
          break;
        default:
          value = entry.value.totalFocusMinutes;
      }

      return LeaderboardEntry(
        oderId: entry.value.oderId,
        displayName: entry.value.displayName,
        avatarUrl: entry.value.avatarUrl,
        rank: entry.key + 1,
        value: value,
        lastUpdated: DateTime.now(),
      );
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (int i = 0; i < entries.length; i++) {
      entries[i] = LeaderboardEntry(
        oderId: entries[i].oderId,
        displayName: entries[i].displayName,
        avatarUrl: entries[i].avatarUrl,
        rank: i + 1,
        value: entries[i].value,
        lastUpdated: entries[i].lastUpdated,
      );
    }

    return Leaderboard(
      type: LeaderboardType.allTime,
      category: category,
      entries: entries,
      lastFetched: DateTime.now(),
    );
  }

  Future<bool> addFriendByCode(String friendCode) async {
    if (friendCode == _userProfile?.friendCode) {
      return false;
    }

    final existingFriend = _friends.any((f) => f.friendCode == friendCode);
    if (existingFriend) {
      return false;
    }

    final newFriend = FocusFriend(
      oderId: _generateId(),
      displayName: 'Friend ${_friends.length + 1}',
      friendCode: friendCode,
      addedAt: DateTime.now(),
      totalFocusMinutes: Random().nextInt(5000),
      currentStreak: Random().nextInt(30),
      treesPlanted: Random().nextInt(100),
    );

    _friends.add(newFriend);
    await _saveData();
    notifyListeners();
    
    debugPrint('✓ Added friend with code: $friendCode');
    return true;
  }

  Future<void> removeFriend(String oderId) async {
    _friends.removeWhere((f) => f.oderId == oderId);
    await _saveData();
    notifyListeners();
  }

  Future<void> acceptFriendRequest(String requestId) async {
    final request = _pendingRequests.firstWhere(
      (r) => r.id == requestId,
      orElse: () => throw Exception('Request not found'),
    );

    final newFriend = FocusFriend(
      oderId: request.fromUserId,
      displayName: request.fromDisplayName,
      avatarUrl: request.fromAvatarUrl,
      addedAt: DateTime.now(),
    );

    _friends.add(newFriend);
    _pendingRequests.removeWhere((r) => r.id == requestId);
    
    await _saveData();
    notifyListeners();
  }

  Future<void> declineFriendRequest(String requestId) async {
    _pendingRequests.removeWhere((r) => r.id == requestId);
    await _saveData();
    notifyListeners();
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  String _generateFriendCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }
}

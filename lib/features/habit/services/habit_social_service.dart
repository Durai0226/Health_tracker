import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

/// Service for social features - friends and challenges
/// Only works for registered users (not anonymous)
class HabitSocialService extends ChangeNotifier {
  static final HabitSocialService _instance = HabitSocialService._internal();
  factory HabitSocialService() => _instance;
  HabitSocialService._internal();

  static const String _profileKey = 'habit_social_profile';
  static const String _friendsKey = 'habit_social_friends';
  static const String _challengesKey = 'habit_social_challenges';

  final _uuid = const Uuid();
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  bool _isAuthenticated = false;
  String? _currentUserId;

  HabitProfile? _profile;
  List<HabitFriend> _friends = [];
  List<HabitChallenge> _challenges = [];

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _isAuthenticated;
  String? get currentUserId => _currentUserId;
  HabitProfile? get profile => _profile;
  List<HabitFriend> get friends => List.unmodifiable(_friends);
  List<HabitChallenge> get challenges => List.unmodifiable(_challenges);

  // Filtered lists
  List<HabitFriend> get acceptedFriends => 
      _friends.where((f) => f.isAccepted).toList();
  List<HabitFriend> get pendingFriends => 
      _friends.where((f) => f.isPending).toList();
  List<HabitChallenge> get activeChallenges => 
      _challenges.where((c) => c.isActive).toList();
  List<HabitChallenge> get pendingChallenges => 
      _challenges.where((c) => c.status == ChallengeStatus.pending).toList();

  /// Initialize the service for a user
  Future<void> init({
    required String oderId,
    required String displayName,
    String? email,
    bool isAnonymous = false,
  }) async {
    if (_isInitialized && _currentUserId == oderId) return;

    _prefs = await SharedPreferences.getInstance();
    _currentUserId = oderId;
    _isAuthenticated = !isAnonymous;

    if (_isAuthenticated) {
      await _loadProfile();
      await _loadFriends();
      await _loadChallenges();

      // Create profile if doesn't exist
      if (_profile == null) {
        _profile = HabitProfile(
          oderId: oderId,
          displayName: displayName,
          email: email,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _saveProfile();
      }
    }

    _isInitialized = true;
    debugPrint('✓ HabitSocialService initialized (authenticated: $_isAuthenticated)');
    notifyListeners();
  }

  /// Check if social features are available
  bool get areSocialFeaturesAvailable => _isAuthenticated;

  // ==========================================
  // PROFILE
  // ==========================================

  Future<void> _loadProfile() async {
    final json = _prefs?.getString('${_profileKey}_$_currentUserId');
    if (json != null) {
      _profile = HabitProfile.fromJson(jsonDecode(json));
    }
  }

  Future<void> _saveProfile() async {
    if (_profile != null && _currentUserId != null) {
      final json = jsonEncode(_profile!.toJson());
      await _prefs?.setString('${_profileKey}_$_currentUserId', json);
    }
  }

  /// Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? cityName,
  }) async {
    if (_profile == null || !_isAuthenticated) return;

    _profile = _profile!.copyWith(
      displayName: displayName ?? _profile!.displayName,
      avatarUrl: avatarUrl ?? _profile!.avatarUrl,
      cityName: cityName ?? _profile!.cityName,
      updatedAt: DateTime.now(),
    );

    await _saveProfile();
    notifyListeners();
  }

  /// Update profile stats from habit service
  Future<void> syncProfileStats({
    required int totalPoints,
    required int coins,
    required int cityLevel,
    required int currentStreak,
    required int bestStreak,
    required int habitsCount,
  }) async {
    if (_profile == null || !_isAuthenticated) return;

    _profile = _profile!.copyWith(
      totalPoints: totalPoints,
      coins: coins,
      cityLevel: cityLevel,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      habitsCount: habitsCount,
      updatedAt: DateTime.now(),
    );

    await _saveProfile();
    notifyListeners();
  }

  // ==========================================
  // FRIENDS
  // ==========================================

  Future<void> _loadFriends() async {
    final json = _prefs?.getString('${_friendsKey}_$_currentUserId');
    if (json != null) {
      final List<dynamic> list = jsonDecode(json);
      _friends = list.map((e) => HabitFriend.fromJson(e)).toList();
    }
  }

  Future<void> _saveFriends() async {
    if (_currentUserId != null) {
      final json = jsonEncode(_friends.map((f) => f.toJson()).toList());
      await _prefs?.setString('${_friendsKey}_$_currentUserId', json);
    }
  }

  /// Send friend request (by email or user ID)
  Future<bool> sendFriendRequest({
    required String friendUserId,
    required String friendDisplayName,
    String? friendEmail,
  }) async {
    if (!_isAuthenticated) return false;

    // Check if already friends
    if (_friends.any((f) => f.oderId == friendUserId)) {
      return false;
    }

    final friend = HabitFriend(
      oderId: friendUserId,
      displayName: friendDisplayName,
      email: friendEmail,
      status: FriendStatus.pending,
      requestedAt: DateTime.now(),
    );

    _friends.add(friend);
    await _saveFriends();
    notifyListeners();
    
    // TODO: In real implementation, send notification to friend via Firebase
    return true;
  }

  /// Accept friend request
  Future<void> acceptFriendRequest(String friendUserId) async {
    if (!_isAuthenticated) return;

    final index = _friends.indexWhere((f) => f.oderId == friendUserId);
    if (index != -1) {
      _friends[index] = _friends[index].copyWith(
        status: FriendStatus.accepted,
        acceptedAt: DateTime.now(),
      );
      await _saveFriends();
      notifyListeners();
    }
  }

  /// Decline friend request
  Future<void> declineFriendRequest(String friendUserId) async {
    if (!_isAuthenticated) return;

    final index = _friends.indexWhere((f) => f.oderId == friendUserId);
    if (index != -1) {
      _friends[index] = _friends[index].copyWith(
        status: FriendStatus.declined,
      );
      await _saveFriends();
      notifyListeners();
    }
  }

  /// Remove friend
  Future<void> removeFriend(String friendUserId) async {
    if (!_isAuthenticated) return;

    _friends.removeWhere((f) => f.oderId == friendUserId);
    await _saveFriends();
    notifyListeners();
  }

  /// Search for users (mock - in real app would query Firestore)
  Future<List<HabitFriend>> searchUsers(String query) async {
    if (!_isAuthenticated || query.isEmpty) return [];
    
    // In real implementation, this would search Firestore
    // For now, return empty list as placeholder
    return [];
  }

  // ==========================================
  // CHALLENGES
  // ==========================================

  Future<void> _loadChallenges() async {
    final json = _prefs?.getString('${_challengesKey}_$_currentUserId');
    if (json != null) {
      final List<dynamic> list = jsonDecode(json);
      _challenges = list.map((e) => HabitChallenge.fromJson(e)).toList();
    }
  }

  Future<void> _saveChallenges() async {
    if (_currentUserId != null) {
      final json = jsonEncode(_challenges.map((c) => c.toJson()).toList());
      await _prefs?.setString('${_challengesKey}_$_currentUserId', json);
    }
  }

  /// Create a new challenge
  Future<HabitChallenge?> createChallenge({
    required String title,
    String? description,
    required List<String> habitIds,
    required List<String> habitNames,
    required List<String> invitedFriendIds,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!_isAuthenticated || _profile == null) return null;

    // Create participants list with creator
    final participants = <ChallengeParticipant>[
      ChallengeParticipant(
        oderId: _currentUserId!,
        displayName: _profile!.displayName,
        avatarUrl: _profile!.avatarUrl,
        hasAccepted: true,
        joinedAt: DateTime.now(),
      ),
    ];

    // Add invited friends
    for (final friendId in invitedFriendIds) {
      final friend = _friends.firstWhere(
        (f) => f.oderId == friendId,
        orElse: () => throw Exception('Friend not found'),
      );
      participants.add(ChallengeParticipant(
        oderId: friend.oderId,
        displayName: friend.displayName,
        avatarUrl: friend.avatarUrl,
        hasAccepted: false,
      ));
    }

    final now = DateTime.now();
    final challenge = HabitChallenge(
      id: _uuid.v4(),
      creatorId: _currentUserId!,
      creatorName: _profile!.displayName,
      title: title,
      description: description,
      habitIds: habitIds,
      habitNames: habitNames,
      participants: participants,
      startDate: startDate,
      endDate: endDate,
      status: ChallengeStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    _challenges.add(challenge);
    await _saveChallenges();
    notifyListeners();

    // TODO: Send notifications to invited friends via Firebase
    return challenge;
  }

  /// Accept challenge invitation
  Future<void> acceptChallenge(String challengeId) async {
    if (!_isAuthenticated || _currentUserId == null) return;

    final index = _challenges.indexWhere((c) => c.id == challengeId);
    if (index == -1) return;

    final challenge = _challenges[index];
    final participantIndex = challenge.participants.indexWhere(
      (p) => p.oderId == _currentUserId,
    );

    if (participantIndex == -1) return;

    final updatedParticipants = List<ChallengeParticipant>.from(challenge.participants);
    updatedParticipants[participantIndex] = updatedParticipants[participantIndex].copyWith(
      hasAccepted: true,
      joinedAt: DateTime.now(),
    );

    // Check if all participants accepted - activate challenge
    final allAccepted = updatedParticipants.every((p) => p.hasAccepted);
    
    _challenges[index] = challenge.copyWith(
      participants: updatedParticipants,
      status: allAccepted ? ChallengeStatus.active : challenge.status,
      updatedAt: DateTime.now(),
    );

    await _saveChallenges();
    notifyListeners();
  }

  /// Record progress for a challenge
  Future<void> recordChallengeProgress({
    required String challengeId,
    required int completedDays,
    required int totalDays,
  }) async {
    if (!_isAuthenticated || _currentUserId == null) return;

    final index = _challenges.indexWhere((c) => c.id == challengeId);
    if (index == -1) return;

    final challenge = _challenges[index];
    final participantIndex = challenge.participants.indexWhere(
      (p) => p.oderId == _currentUserId,
    );

    if (participantIndex == -1) return;

    final updatedParticipants = List<ChallengeParticipant>.from(challenge.participants);
    updatedParticipants[participantIndex] = updatedParticipants[participantIndex].copyWith(
      completedDays: completedDays,
      totalDays: totalDays,
    );

    _challenges[index] = challenge.copyWith(
      participants: updatedParticipants,
      updatedAt: DateTime.now(),
    );

    await _saveChallenges();
    notifyListeners();
  }

  /// Complete a challenge (when end date reached)
  Future<void> completeChallenge(String challengeId) async {
    final index = _challenges.indexWhere((c) => c.id == challengeId);
    if (index == -1) return;

    _challenges[index] = _challenges[index].copyWith(
      status: ChallengeStatus.completed,
      updatedAt: DateTime.now(),
    );

    await _saveChallenges();
    notifyListeners();
  }

  /// Get challenge by ID
  HabitChallenge? getChallenge(String challengeId) {
    try {
      return _challenges.firstWhere((c) => c.id == challengeId);
    } catch (_) {
      return null;
    }
  }

  /// Get challenges for a specific habit
  List<HabitChallenge> getChallengesForHabit(String habitId) {
    return _challenges.where((c) => c.habitIds.contains(habitId)).toList();
  }
}

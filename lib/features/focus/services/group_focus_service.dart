import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/services/storage_service.dart';
import '../models/group_focus.dart';
import '../models/focus_plant.dart';

class GroupFocusService extends ChangeNotifier {
  static final GroupFocusService _instance = GroupFocusService._internal();
  factory GroupFocusService() => _instance;
  GroupFocusService._internal();

  GroupFocusSession? _currentSession;
  List<GroupSessionHistory> _sessionHistory = [];
  Timer? _sessionTimer;
  String? _currentUserId;
  String? _currentUserName;

  GroupFocusSession? get currentSession => _currentSession;
  List<GroupSessionHistory> get sessionHistory => List.unmodifiable(_sessionHistory);
  bool get isInSession => _currentSession != null;
  bool get isSessionActive => 
      _currentSession?.status == GroupSessionStatus.inProgress;

  Future<void> init() async {
    await _loadData();
    final prefs = StorageService.getAppPreferences();
    _currentUserId = prefs['focusUserId'] ?? _generateId();
    _currentUserName = prefs['focusUserName'] ?? 'User';
    await StorageService.setAppPreference('focusUserId', _currentUserId);
    debugPrint('✓ GroupFocusService initialized');
  }

  Future<void> _loadData() async {
    try {
      final prefs = StorageService.getAppPreferences();
      
      final historyJson = prefs['focusGroupHistory'];
      if (historyJson != null && historyJson is List) {
        _sessionHistory = historyJson
            .map((h) => GroupSessionHistory.fromJson(Map<String, dynamic>.from(h)))
            .toList();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading group focus data: $e');
    }
  }

  Future<void> _saveData() async {
    try {
      await StorageService.setAppPreference(
        'focusGroupHistory',
        _sessionHistory.take(50).map((h) => h.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('Error saving group focus data: $e');
    }
  }

  Future<GroupFocusSession> createSession({
    required int targetMinutes,
    required PlantType plantType,
    bool isPublic = false,
    int maxParticipants = 10,
  }) async {
    final session = GroupFocusSession(
      id: _generateId(),
      hostUserId: _currentUserId!,
      hostDisplayName: _currentUserName!,
      roomCode: _generateRoomCode(),
      targetMinutes: targetMinutes,
      plantType: plantType,
      participants: [
        GroupParticipant(
          oderId: _currentUserId!,
          displayName: _currentUserName!,
          isHost: true,
          isReady: true,
          joinedAt: DateTime.now(),
          status: ParticipantStatus.ready,
        ),
      ],
      createdAt: DateTime.now(),
      isPublic: isPublic,
      maxParticipants: maxParticipants,
    );

    _currentSession = session;
    notifyListeners();
    
    debugPrint('✓ Created group session: ${session.roomCode}');
    return session;
  }

  Future<GroupFocusSession?> joinSession(String roomCode) async {
    final mockSession = GroupFocusSession(
      id: _generateId(),
      hostUserId: 'host_user',
      hostDisplayName: 'Session Host',
      roomCode: roomCode.toUpperCase(),
      targetMinutes: 25,
      plantType: PlantType.tree,
      participants: [
        GroupParticipant(
          oderId: 'host_user',
          displayName: 'Session Host',
          isHost: true,
          isReady: true,
          joinedAt: DateTime.now().subtract(const Duration(minutes: 2)),
          status: ParticipantStatus.ready,
        ),
        GroupParticipant(
          oderId: _currentUserId!,
          displayName: _currentUserName!,
          isHost: false,
          isReady: false,
          joinedAt: DateTime.now(),
          status: ParticipantStatus.waiting,
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      status: GroupSessionStatus.waiting,
    );

    _currentSession = mockSession;
    notifyListeners();
    
    debugPrint('✓ Joined session: $roomCode');
    return mockSession;
  }

  Future<void> setReady(bool isReady) async {
    if (_currentSession == null) return;

    final updatedParticipants = _currentSession!.participants.map((p) {
      if (p.oderId == _currentUserId) {
        return p.copyWith(
          isReady: isReady,
          status: isReady ? ParticipantStatus.ready : ParticipantStatus.waiting,
        );
      }
      return p;
    }).toList();

    _currentSession = _currentSession!.copyWith(participants: updatedParticipants);
    notifyListeners();
  }

  Future<void> startSession() async {
    if (_currentSession == null) return;
    if (_currentSession!.hostUserId != _currentUserId) return;
    if (!_currentSession!.canStart) return;

    final updatedParticipants = _currentSession!.participants.map((p) {
      return p.copyWith(status: ParticipantStatus.focusing, currentProgress: 0);
    }).toList();

    _currentSession = _currentSession!.copyWith(
      status: GroupSessionStatus.inProgress,
      startedAt: DateTime.now(),
      participants: updatedParticipants,
    );

    _startSessionTimer();
    notifyListeners();
    
    debugPrint('✓ Group session started');
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSession == null || 
          _currentSession!.status != GroupSessionStatus.inProgress) {
        timer.cancel();
        return;
      }

      final remaining = _currentSession!.remainingTime;
      if (remaining == null || remaining.inSeconds <= 0) {
        _completeSession();
        timer.cancel();
        return;
      }

      final updatedParticipants = _currentSession!.participants.map((p) {
        if (p.status == ParticipantStatus.focusing) {
          return p.copyWith(currentProgress: _currentSession!.progress);
        }
        return p;
      }).toList();

      _currentSession = _currentSession!.copyWith(participants: updatedParticipants);
      notifyListeners();
    });
  }

  Future<void> _completeSession() async {
    if (_currentSession == null) return;

    final updatedParticipants = _currentSession!.participants.map((p) {
      if (p.status == ParticipantStatus.focusing) {
        return p.copyWith(
          status: ParticipantStatus.completed,
          currentProgress: 1.0,
        );
      }
      return p;
    }).toList();

    _currentSession = _currentSession!.copyWith(
      status: GroupSessionStatus.completed,
      endedAt: DateTime.now(),
      participants: updatedParticipants,
    );

    final history = GroupSessionHistory(
      sessionId: _currentSession!.id,
      hostDisplayName: _currentSession!.hostDisplayName,
      targetMinutes: _currentSession!.targetMinutes,
      participantCount: _currentSession!.participantCount,
      wasSuccessful: true,
      completedAt: DateTime.now(),
      plantType: _currentSession!.plantType,
    );

    _sessionHistory.insert(0, history);
    await _saveData();
    notifyListeners();
    
    debugPrint('✓ Group session completed successfully');
  }

  Future<void> abandonSession() async {
    if (_currentSession == null) return;

    final wasInProgress = _currentSession!.status == GroupSessionStatus.inProgress;

    if (wasInProgress) {
      _currentSession = _currentSession!.copyWith(
        status: GroupSessionStatus.failed,
        endedAt: DateTime.now(),
        failedByUserId: _currentUserId,
      );

      final history = GroupSessionHistory(
        sessionId: _currentSession!.id,
        hostDisplayName: _currentSession!.hostDisplayName,
        targetMinutes: _currentSession!.targetMinutes,
        participantCount: _currentSession!.participantCount,
        wasSuccessful: false,
        completedAt: DateTime.now(),
        plantType: _currentSession!.plantType,
      );

      _sessionHistory.insert(0, history);
      await _saveData();
      
      debugPrint('✓ Group session failed - someone left early');
    }

    _sessionTimer?.cancel();
    _currentSession = null;
    notifyListeners();
  }

  Future<void> leaveSession() async {
    if (_currentSession == null) return;

    if (_currentSession!.status == GroupSessionStatus.inProgress) {
      await abandonSession();
      return;
    }

    if (_currentSession!.hostUserId == _currentUserId) {
      _currentSession = _currentSession!.copyWith(
        status: GroupSessionStatus.cancelled,
      );
    }

    _currentSession = null;
    notifyListeners();
  }

  GroupSessionInvite? getInviteLink() {
    if (_currentSession == null) return null;

    return GroupSessionInvite(
      id: _generateId(),
      sessionId: _currentSession!.id,
      roomCode: _currentSession!.roomCode,
      hostDisplayName: _currentSession!.hostDisplayName,
      targetMinutes: _currentSession!.targetMinutes,
      currentParticipants: _currentSession!.participantCount,
      maxParticipants: _currentSession!.maxParticipants,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  void simulateParticipantJoin() {
    if (_currentSession == null) return;

    final names = ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve'];
    final random = Random();

    final newParticipant = GroupParticipant(
      oderId: _generateId(),
      displayName: names[random.nextInt(names.length)],
      isHost: false,
      isReady: false,
      joinedAt: DateTime.now(),
      status: ParticipantStatus.waiting,
    );

    final updatedParticipants = [..._currentSession!.participants, newParticipant];
    _currentSession = _currentSession!.copyWith(participants: updatedParticipants);
    notifyListeners();
  }

  void simulateParticipantReady(String oderId) {
    if (_currentSession == null) return;

    final updatedParticipants = _currentSession!.participants.map((p) {
      if (p.oderId == oderId) {
        return p.copyWith(isReady: true, status: ParticipantStatus.ready);
      }
      return p;
    }).toList();

    _currentSession = _currentSession!.copyWith(participants: updatedParticipants);
    notifyListeners();
  }

  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }
}

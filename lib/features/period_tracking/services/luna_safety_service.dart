import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'dart:convert';
import '../models/luna_safety.dart';

/// Service for Luna Cycle safety features
/// Emergency contacts, SOS alerts, location sharing
class LunaSafetyService extends ChangeNotifier {
  static const String _contactsKey = 'luna_emergency_contacts';
  static const String _settingsKey = 'luna_safety_settings';
  static const String _alertHistoryKey = 'luna_alert_history';

  List<LunaEmergencyContact> _contacts = [];
  LunaSafetySettings _settings = const LunaSafetySettings();
  List<LunaSafetyAlert> _alertHistory = [];
  LunaLocationShare? _activeLocationShare;
  bool _isLoading = false;

  List<LunaEmergencyContact> get contacts => _contacts;
  LunaSafetySettings get settings => _settings;
  List<LunaSafetyAlert> get alertHistory => _alertHistory;
  LunaLocationShare? get activeLocationShare => _activeLocationShare;
  bool get isLoading => _isLoading;

  String? get _currentUserId {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  LunaEmergencyContact? get primaryContact {
    try {
      return _contacts.firstWhere((c) => c.isPrimary);
    } catch (e) {
      return _contacts.isNotEmpty ? _contacts.first : null;
    }
  }

  /// Initialize the service
  Future<void> initialize() async {
    await _loadLocalData();
    notifyListeners();
  }

  /// Load local data
  Future<void> _loadLocalData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load contacts
      final contactsJson = prefs.getString(_contactsKey);
      if (contactsJson != null) {
        final List<dynamic> contactsList = jsonDecode(contactsJson);
        _contacts = contactsList
            .map((c) => LunaEmergencyContact.fromJson(c as Map<String, dynamic>))
            .toList();
      }

      // Load settings
      final settingsJson = prefs.getString(_settingsKey);
      if (settingsJson != null) {
        _settings = LunaSafetySettings.fromJson(jsonDecode(settingsJson));
      }

      // Load alert history
      final historyJson = prefs.getString(_alertHistoryKey);
      if (historyJson != null) {
        final List<dynamic> historyList = jsonDecode(historyJson);
        _alertHistory = historyList
            .map((a) => LunaSafetyAlert.fromJson(a as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading safety data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Save contacts to local storage
  Future<void> _saveContacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _contactsKey,
        jsonEncode(_contacts.map((c) => c.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Error saving contacts: $e');
    }
  }

  /// Save settings to local storage
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, jsonEncode(_settings.toJson()));
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  /// Save alert history to local storage
  Future<void> _saveAlertHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep only last 50 alerts
      final historyToSave = _alertHistory.take(50).toList();
      await prefs.setString(
        _alertHistoryKey,
        jsonEncode(historyToSave.map((a) => a.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Error saving alert history: $e');
    }
  }

  /// Add emergency contact
  Future<void> addContact(LunaEmergencyContact contact) async {
    // If this is the first contact, make it primary
    final isPrimary = _contacts.isEmpty;
    final newContact = contact.copyWith(isPrimary: isPrimary);
    
    _contacts.add(newContact);
    await _saveContacts();
    notifyListeners();
  }

  /// Update emergency contact
  Future<void> updateContact(LunaEmergencyContact contact) async {
    final index = _contacts.indexWhere((c) => c.id == contact.id);
    if (index != -1) {
      _contacts[index] = contact;
      await _saveContacts();
      notifyListeners();
    }
  }

  /// Delete emergency contact
  Future<void> deleteContact(String contactId) async {
    final wasDeleted = _contacts.any((c) => c.id == contactId && c.isPrimary);
    _contacts.removeWhere((c) => c.id == contactId);
    
    // If deleted primary, make first contact primary
    if (wasDeleted && _contacts.isNotEmpty) {
      _contacts[0] = _contacts[0].copyWith(isPrimary: true);
    }
    
    await _saveContacts();
    notifyListeners();
  }

  /// Set primary contact
  Future<void> setPrimaryContact(String contactId) async {
    _contacts = _contacts.map((c) {
      return c.copyWith(isPrimary: c.id == contactId);
    }).toList();
    
    await _saveContacts();
    notifyListeners();
  }

  /// Update safety settings
  Future<void> updateSettings(LunaSafetySettings settings) async {
    _settings = settings;
    await _saveSettings();
    notifyListeners();
  }

  /// Trigger SOS alert
  Future<LunaSafetyAlert?> triggerSOS({
    double? latitude,
    double? longitude,
    String? address,
    String? customMessage,
    bool isTest = false,
  }) async {
    if (!_settings.sosEnabled && !isTest) return null;
    if (_contacts.isEmpty) return null;

    // Haptic feedback
    HapticFeedback.heavyImpact();

    final userId = _currentUserId ?? 'anonymous';
    final alert = LunaSafetyAlert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      type: LunaAlertType.sos,
      status: isTest ? LunaAlertStatus.test : LunaAlertStatus.active,
      latitude: latitude,
      longitude: longitude,
      address: address,
      customMessage: customMessage ?? _settings.customSOSMessage,
      triggeredAt: DateTime.now(),
      notifiedContactIds: _contacts.where((c) => c.canReceiveAlerts).map((c) => c.id).toList(),
      isTest: isTest,
    );

    _alertHistory.insert(0, alert);
    await _saveAlertHistory();

    // Send notifications to contacts
    if (!isTest) {
      await _sendAlertToContacts(alert);
    }

    // Save to Firestore for tracking
    if (_currentUserId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .collection('luna_safety_alerts')
            .add(alert.toJson());
      } catch (e) {
        debugPrint('Error saving alert to Firestore: $e');
      }
    }

    notifyListeners();
    return alert;
  }

  /// Send alert to contacts (SMS/Call simulation)
  Future<void> _sendAlertToContacts(LunaSafetyAlert alert) async {
    final contactsToNotify = _contacts.where((c) => c.canReceiveAlerts).toList();
    
    for (final contact in contactsToNotify) {
      if (_settings.sendSMS) {
        // In real implementation, use url_launcher or SMS plugin
        debugPrint('Sending SMS to ${contact.phone}: ${alert.type.defaultMessage}');
      }
      
      if (_settings.makeCall && contact.isPrimary) {
        // In real implementation, use url_launcher to make call
        debugPrint('Calling ${contact.phone}');
      }
    }
  }

  /// Cancel active alert
  Future<void> cancelAlert(String alertId, {String? pin}) async {
    // If fake cancel code is enabled, verify PIN
    if (_settings.fakeCancelCode && _settings.cancelPin != null) {
      if (pin != _settings.cancelPin) {
        throw Exception('Invalid PIN');
      }
    }

    final index = _alertHistory.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      _alertHistory[index] = _alertHistory[index].copyWith(
        status: LunaAlertStatus.cancelled,
        cancelledAt: DateTime.now(),
      );
      await _saveAlertHistory();
      notifyListeners();
    }
  }

  /// Start sharing location with a contact
  Future<LunaLocationShare?> startLocationSharing({
    LunaEmergencyContact? contact,
    String? sharedWithId,
    String? sharedWithName,
    required LunaShareDuration duration,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final targetId = contact?.id ?? sharedWithId ?? '';
    final targetName = contact?.name ?? sharedWithName ?? '';
    if (targetId.isEmpty || targetName.isEmpty) return null;
    final userId = _currentUserId ?? 'anonymous';
    
    final share = LunaLocationShare(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      sharedWithId: targetId,
      sharedWithName: targetName,
      currentLatitude: latitude,
      currentLongitude: longitude,
      currentAddress: address,
      startedAt: DateTime.now(),
      expiresAt: duration.duration != null 
          ? DateTime.now().add(duration.duration!) 
          : null,
      duration: duration,
      lastUpdatedAt: DateTime.now(),
    );

    _activeLocationShare = share;
    notifyListeners();

    // Save to Firestore for partner to access
    if (_currentUserId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('luna_location_shares')
            .doc(share.id)
            .set(share.toJson());
      } catch (e) {
        debugPrint('Error saving location share: $e');
      }
    }

    return share;
  }

  /// Update location in active share
  Future<void> updateSharedLocation({
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    if (_activeLocationShare == null) return;

    // Update in Firestore
    if (_currentUserId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('luna_location_shares')
            .doc(_activeLocationShare!.id)
            .update({
          'currentLatitude': latitude,
          'currentLongitude': longitude,
          'currentAddress': address,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error updating location: $e');
      }
    }
  }

  /// Stop sharing location
  Future<void> stopLocationSharing() async {
    if (_activeLocationShare == null) return;

    // Remove from Firestore
    if (_currentUserId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('luna_location_shares')
            .doc(_activeLocationShare!.id)
            .delete();
      } catch (e) {
        debugPrint('Error removing location share: $e');
      }
    }

    _activeLocationShare = null;
    notifyListeners();
  }

  /// Get helplines for country
  List<LunaHelpline> getHelplines(String countryCode) {
    return LunaEmergencyHelplines.byCountry[countryCode] ?? [];
  }

  /// Test SOS (sends test alert)
  Future<LunaSafetyAlert?> testSOS() async {
    return triggerSOS(isTest: true);
  }

  /// Clear all data
  Future<void> clearAllData() async {
    _contacts = [];
    _settings = const LunaSafetySettings();
    _alertHistory = [];
    _activeLocationShare = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_contactsKey);
    await prefs.remove(_settingsKey);
    await prefs.remove(_alertHistoryKey);

    notifyListeners();
  }

  /// Get unresolved alerts count
  int get unresolvedAlertsCount {
    return _alertHistory.where((a) => 
      a.status == LunaAlertStatus.active && !a.isTest
    ).length;
  }

  /// Check if SOS is ready (has contacts and enabled)
  bool get isSOSReady => _settings.sosEnabled && _contacts.isNotEmpty;

  /// Get formatted message for alert
  String getFormattedAlertMessage(LunaSafetyAlert alert) {
    String message = alert.customMessage ?? alert.type.defaultMessage;
    
    if (alert.hasLocation) {
      message += '\n\nLocation: ${alert.googleMapsUrl}';
    }
    
    if (alert.address != null) {
      message += '\nAddress: ${alert.address}';
    }
    
    return message;
  }
}

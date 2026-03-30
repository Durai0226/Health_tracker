import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'dart:convert';
import '../models/partner_profile.dart';

/// Service for partner sharing functionality
class FloPartnerService {
  static const String _partnerKey = 'flo_partner_profile';
  static const String _inviteCodesCollection = 'partnerInviteCodes';
  static const String _partnerLinksCollection = 'partnerLinks';
  static PartnerProfile? _cachedPartner;

  static String? get _currentUserId {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      return user.uid;
    }
    return null;
  }

  /// Get partner profile
  static Future<PartnerProfile?> getPartner() async {
    if (_cachedPartner != null) return _cachedPartner;

    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_partnerKey);
      if (json == null) return null;

      _cachedPartner = PartnerProfile.fromJson(jsonDecode(json));
      return _cachedPartner;
    } catch (e) {
      debugPrint('Error loading partner: $e');
      return null;
    }
  }

  /// Save partner profile locally
  static Future<void> _savePartnerLocally(PartnerProfile partner) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_partnerKey, jsonEncode(partner.toJson()));
      _cachedPartner = partner;
    } catch (e) {
      debugPrint('Error saving partner: $e');
    }
  }

  /// Generate and store invite code
  static Future<String?> generateInviteCode() async {
    final userId = _currentUserId;
    if (userId == null) return null;

    try {
      final code = PartnerProfile.generateInviteCode();
      final expiresAt = DateTime.now().add(const Duration(hours: 24));

      await FirebaseFirestore.instance
          .collection(_inviteCodesCollection)
          .doc(code)
          .set({
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'used': false,
      });

      return code;
    } catch (e) {
      debugPrint('Error generating invite code: $e');
      return null;
    }
  }

  /// Validate and use invite code
  static Future<Map<String, dynamic>?> validateInviteCode(String code) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_inviteCodesCollection)
          .doc(code)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final used = data['used'] as bool;

      if (used) {
        return {'error': 'Code already used'};
      }

      if (DateTime.now().isAfter(expiresAt)) {
        return {'error': 'Code expired'};
      }

      return {
        'valid': true,
        'userId': data['userId'],
      };
    } catch (e) {
      debugPrint('Error validating invite code: $e');
      return {'error': 'Failed to validate code'};
    }
  }

  /// Link with partner using invite code
  static Future<bool> linkPartner(String code, String partnerName) async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      final validation = await validateInviteCode(code);
      if (validation == null || validation['error'] != null) {
        return false;
      }

      final partnerUserId = validation['userId'] as String;

      // Mark code as used
      await FirebaseFirestore.instance
          .collection(_inviteCodesCollection)
          .doc(code)
          .update({'used': true});

      // Create partner link
      await FirebaseFirestore.instance
          .collection(_partnerLinksCollection)
          .doc(userId)
          .set({
        'partnerId': partnerUserId,
        'linkedAt': FieldValue.serverTimestamp(),
        'status': 'linked',
      });

      // Create reverse link
      await FirebaseFirestore.instance
          .collection(_partnerLinksCollection)
          .doc(partnerUserId)
          .set({
        'partnerId': userId,
        'linkedAt': FieldValue.serverTimestamp(),
        'status': 'linked',
      });

      // Save partner locally
      final partner = PartnerProfile(
        id: partnerUserId,
        name: partnerName,
        status: PartnerStatus.linked,
        linkedAt: DateTime.now(),
      );
      await _savePartnerLocally(partner);

      return true;
    } catch (e) {
      debugPrint('Error linking partner: $e');
      return false;
    }
  }

  /// Update partner permissions
  static Future<void> updatePermissions(PartnerPermissions permissions) async {
    final partner = await getPartner();
    if (partner == null) return;

    final updated = partner.copyWith(permissions: permissions);
    await _savePartnerLocally(updated);

    // Sync to cloud
    final userId = _currentUserId;
    if (userId != null) {
      try {
        await FirebaseFirestore.instance
            .collection(_partnerLinksCollection)
            .doc(userId)
            .update({'permissions': permissions.toJson()});
      } catch (e) {
        debugPrint('Error syncing permissions: $e');
      }
    }
  }

  /// Get shared data for partner
  static Future<PartnerSharedData?> getSharedDataForPartner(String partnerId) async {
    try {
      // Get partner's shared data based on permissions
      final linkDoc = await FirebaseFirestore.instance
          .collection(_partnerLinksCollection)
          .doc(partnerId)
          .get();

      if (!linkDoc.exists) return null;

      final sharedDataDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(partnerId)
          .collection('sharedData')
          .doc('current')
          .get();

      if (!sharedDataDoc.exists) return null;

      return PartnerSharedData.fromJson(sharedDataDoc.data()!);
    } catch (e) {
      debugPrint('Error getting shared data: $e');
      return null;
    }
  }

  /// Update shared data for partner to see
  static Future<void> updateSharedData(PartnerSharedData data) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('sharedData')
          .doc('current')
          .set(data.toJson());
    } catch (e) {
      debugPrint('Error updating shared data: $e');
    }
  }

  /// Remove partner link
  static Future<void> removePartner() async {
    final userId = _currentUserId;
    final partner = await getPartner();

    try {
      // Remove local data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_partnerKey);
      _cachedPartner = null;

      // Remove cloud links
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection(_partnerLinksCollection)
            .doc(userId)
            .delete();

        if (partner != null) {
          await FirebaseFirestore.instance
              .collection(_partnerLinksCollection)
              .doc(partner.id)
              .delete();
        }
      }
    } catch (e) {
      debugPrint('Error removing partner: $e');
    }
  }

  /// Clear cache
  static void clearCache() {
    _cachedPartner = null;
  }
}

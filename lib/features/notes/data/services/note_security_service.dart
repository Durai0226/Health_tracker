import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class NoteSecurityService {
  static final NoteSecurityService _instance = NoteSecurityService._internal();
  factory NoteSecurityService() => _instance;
  NoteSecurityService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  static const String _masterKeyPrefix = 'note_lock_';
  static const String _biometricEnabledKey = 'notes_biometric_enabled';

  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  Future<bool> authenticateWithBiometric({String reason = 'Authenticate to unlock note'}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }

  String _hashPassword(String password) {
    final key = encrypt.Key.fromUtf8(password.padRight(32, '0').substring(0, 32));
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.encrypt(password, iv: iv).base64;
  }

  Future<void> setNotePassword(String noteId, String password) async {
    final hashedPassword = _hashPassword(password);
    await _secureStorage.write(key: '$_masterKeyPrefix$noteId', value: hashedPassword);
  }

  Future<bool> verifyNotePassword(String noteId, String password) async {
    final storedHash = await _secureStorage.read(key: '$_masterKeyPrefix$noteId');
    if (storedHash == null) return false;
    
    final inputHash = _hashPassword(password);
    return storedHash == inputHash;
  }

  Future<void> removeNotePassword(String noteId) async {
    await _secureStorage.delete(key: '$_masterKeyPrefix$noteId');
  }

  Future<bool> hasPassword(String noteId) async {
    final stored = await _secureStorage.read(key: '$_masterKeyPrefix$noteId');
    return stored != null;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  Future<bool> isBiometricEnabled() async {
    final value = await _secureStorage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  Future<bool> unlockNote(String noteId, {String? password, bool useBiometric = false}) async {
    if (useBiometric) {
      final biometricEnabled = await isBiometricEnabled();
      if (biometricEnabled && await isBiometricAvailable()) {
        return await authenticateWithBiometric(reason: 'Unlock your protected note');
      }
    }
    
    if (password != null) {
      return await verifyNotePassword(noteId, password);
    }
    
    return false;
  }
}

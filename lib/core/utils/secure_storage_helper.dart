
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/env_config.dart';

class SecureStorageHelper {
  static const _storage = FlutterSecureStorage();

  static Future<Uint8List> getEncryptionKey() async {
    // Try to read existing key
    final keyString = await _storage.read(key: EnvConfig.secureKeyStorageKey);
    
    if (keyString == null) {
      // Generate new key
      final key = Hive.generateSecureKey();
      // Store as base64 string
      await _storage.write(
        key: EnvConfig.secureKeyStorageKey, 
        value: base64UrlEncode(key)
      );
      return Uint8List.fromList(key);
    } else {
      // Decode existing key
      return base64Url.decode(keyString);
    }
  }

  // Helper to clear keys (for debug/reset)
  static Future<void> clearKeys() async {
    await _storage.delete(key: EnvConfig.secureKeyStorageKey);
  }

  /// Returns a 32-byte key for content encryption.
  /// Reuses the Hive key logic for simplicity, ensuring consistency.
  static Future<Uint8List> getContentEncryptionKey() async {
    return getEncryptionKey();
  }
}

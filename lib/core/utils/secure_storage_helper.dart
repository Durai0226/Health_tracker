
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math';
import '../config/env_config.dart';

class SecureStorageHelper {
  static const _storage = FlutterSecureStorage();

  static Future<Uint8List> getEncryptionKey() async {
    // Try to read existing key
    final keyString = await _storage.read(key: EnvConfig.secureKeyStorageKey);
    
    if (keyString == null) {
      // Generate new secure key (32 bytes for AES-256)
      final random = Random.secure();
      final key = Uint8List.fromList(List.generate(32, (i) => random.nextInt(256)));
      // Store as base64 string
      await _storage.write(
        key: EnvConfig.secureKeyStorageKey, 
        value: base64UrlEncode(key)
      );
      return key;
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

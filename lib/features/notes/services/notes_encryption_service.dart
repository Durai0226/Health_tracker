import 'package:encrypt/encrypt.dart' as encrypt;
import '../../../core/utils/secure_storage_helper.dart';

class NotesEncryptionService {
  static final NotesEncryptionService _instance = NotesEncryptionService._internal();

  factory NotesEncryptionService() {
    return _instance;
  }

  NotesEncryptionService._internal();

  encrypt.Encrypter? _encrypter;

  Future<void> _init() async {
    if (_encrypter != null) return;
    
    final keyBytes = await SecureStorageHelper.getContentEncryptionKey();
    final key = encrypt.Key(keyBytes);
    _encrypter = encrypt.Encrypter(encrypt.AES(key));
  }

  Future<String> encryptContent(String plainText) async {
    await _init();
    
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(plainText, iv: iv);
    
    // Format: iv_base64:ciphertext_base64
    return '${iv.base64}:${encrypted.base64}';
  }

  Future<String> decryptContent(String encryptedContent) async {
    await _init();

    try {
      final parts = encryptedContent.split(':');
      if (parts.length != 2) {
        // Fallback: Assume it's old content or not encrypted? 
        // Or maybe just try to decrypt with fixed IV (legacy support optimization)?
        // For now, if format matches, decrypt. If not, throw or return as is.
        
        // Actually, if we soft-migrate, we might encounter plain text. 
        // But the Repository should handle "isLocked" check. 
        // If isLocked is true, content MUST be encrypted.
        throw Exception('Invalid encrypted format');
      }

      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
      
      return _encrypter!.decrypt(encrypted, iv: iv);
    } catch (e) {
      // Check if it's actually valid JSON/Unencrypted text?
      // If decryption fails, it might be corrupt or wrong key.
      rethrow;
    }
  }
  
  /// Helper to check if string looks encrypted (basic check)
  bool isEncrypted(String content) {
    return content.contains(':') && content.split(':').length == 2;
  }
}

import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:pointycastle/export.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Why a backup could not be opened.
enum BackupDecryptFailure {
  /// Not one of ours: there is nothing to decrypt.
  notEncrypted,

  /// Made by a newer version of the app than this one.
  tooNew,

  /// The header or the length is wrong: the file was cut short or altered.
  corrupt,

  /// The passphrase is wrong — or the file was altered after it was made. The two
  /// cannot be told apart, and the message does not pretend otherwise.
  wrongPassphrase,
}

class BackupDecryptException implements Exception {
  const BackupDecryptException(this.failure);

  final BackupDecryptFailure failure;

  /// What to show a person.
  String get message => switch (failure) {
        BackupDecryptFailure.notEncrypted =>
          'This file is not an encrypted DlyMinder backup.',
        BackupDecryptFailure.tooNew =>
          'This backup was made by a newer version of DlyMinder. Update the app to open it.',
        BackupDecryptFailure.corrupt =>
          'This backup file is damaged, so it cannot be opened.',
        BackupDecryptFailure.wrongPassphrase =>
          'That passphrase did not open the backup. Check it and try again.',
      };

  @override
  String toString() => 'BackupDecryptException(${failure.name})';
}

/// A passphrase on an exported backup: AES-256-GCM, with the key made from the
/// passphrase by PBKDF2-HMAC-SHA256.
///
/// The export is a ZIP of every record the person has, handed to the share sheet
/// — to an email, a chat, a drive. Anyone who gets the file can read it. This is
/// the opt-in that makes that not true.
///
/// **There is no recovery.** The passphrase is not stored anywhere; lose it and
/// the file cannot be opened by anyone, this app and its authors included. The
/// screens say so before the file is made, not after.
///
/// ## The file
///
/// `DLYENC` · version (1) · PBKDF2 iterations (4, big-endian) · salt (16) · nonce
/// (12) · ciphertext with its 16-byte tag. The header is authenticated as
/// associated data, so changing the iteration count, the salt or the nonce makes
/// the file fail to open rather than open as something else.
///
/// The iteration count is in the file, so it can be raised later without breaking
/// what was exported before; a count above [maxIterations] is refused, because a
/// crafted file could otherwise ask a phone to compute for minutes.
class BackupEncryption {
  const BackupEncryption._();

  static const String _magic = 'DLYENC';
  static const int version = 1;

  static const int saltLength = 16;
  static const int nonceLength = 12;
  static const int keyLength = 32;
  static const int tagLength = 16;

  /// Magic, version, iterations, salt, nonce.
  static const int headerLength = 6 + 1 + 4 + saltLength + nonceLength;

  /// How many PBKDF2 rounds a new backup uses. Slow on purpose: a stolen file is
  /// attacked offline, and every round costs the attacker as much as it costs
  /// this phone. A few seconds, once, with a progress indicator.
  ///
  /// 600,000 is what the OWASP Password Storage Cheat Sheet asks of
  /// PBKDF2-HMAC-SHA256 today. It was 310,000, the figure from before it was raised.
  /// The count is written into every file, so one made at the old count still opens,
  /// and raising it again later breaks nothing.
  static const int defaultIterations = 600000;

  /// Fewest and most rounds a file may name. Below the first is not protection;
  /// above the second is a denial of service dressed as a backup.
  static const int minIterations = 100000;
  static const int maxIterations = 2000000;

  /// The shortest passphrase accepted, in characters.
  static const int minPassphraseLength = 8;

  /// Why [passphrase] cannot be used, or null when it can.
  ///
  /// Characters are counted as a person counts them — an emoji is one, not the two
  /// halves of a surrogate pair — and a passphrase of nothing but spaces is not one,
  /// however many.
  static String? validatePassphrase(String passphrase) {
    final text = unorm.nfc(passphrase);
    if (text.trim().isEmpty && text.isNotEmpty) {
      return 'A passphrase cannot be only spaces.';
    }
    return text.runes.length < minPassphraseLength
        ? 'Use at least $minPassphraseLength characters.'
        : null;
  }

  /// The bytes the key is made from.
  ///
  /// NFC-normalised first. Unicode writes most accented letters two ways — one
  /// code point, or a letter and a combining mark — and keyboards, operating systems
  /// and pasted text do not agree on which. The same word typed on two phones could
  /// be different bytes and so different keys, and a file that opens on one would say
  /// "wrong passphrase" on the other, with no way back. NFC is what the IETF asks of
  /// passwords (RFC 8265). ASCII is unchanged by it, so nothing made with a plain
  /// passphrase is affected.
  @visibleForTesting
  static Uint8List secretFor(String passphrase) =>
      Uint8List.fromList(utf8.encode(unorm.nfc(passphrase)));

  static final Uint8List _magicBytes = Uint8List.fromList(ascii.encode(_magic));

  /// Whether [bytes] begin like one of these files.
  static bool isEncrypted(Uint8List bytes) {
    if (bytes.length < _magicBytes.length) return false;
    for (var i = 0; i < _magicBytes.length; i++) {
      if (bytes[i] != _magicBytes[i]) return false;
    }
    return true;
  }

  /// [plain] sealed under [passphrase].
  ///
  /// [iterations], [salt] and [nonce] exist for the tests (known-answer vectors,
  /// speed); the app uses the defaults and a fresh random salt and nonce for every
  /// file, which is what keeps two backups of the same data from matching.
  static Future<Uint8List> encrypt(
    Uint8List plain,
    String passphrase, {
    int iterations = defaultIterations,
    Uint8List? salt,
    Uint8List? nonce,
  }) async {
    RangeError.checkValueInInterval(iterations, minIterations, maxIterations, 'iterations');
    final random = Random.secure();
    final s = salt ?? _random(random, saltLength);
    final n = nonce ?? _random(random, nonceLength);
    if (s.length != saltLength || n.length != nonceLength) {
      throw ArgumentError('salt must be $saltLength bytes and nonce $nonceLength');
    }

    final header = _header(iterations, s, n);
    final secret = secretFor(passphrase);
    // The key AND the cipher, on another isolate: both are pure Dart, and the
    // second runs over the whole backup. Only the key used to leave the UI
    // isolate, so a backup of a year of logs froze the screen for as long as it
    // took to encrypt it.
    //
    // The file is put together there too, into one buffer of its final size.
    // Spreading the ciphertext into a list literal first made every byte a boxed
    // slot — eight bytes each — which for a large backup is a few hundred
    // megabytes more than the file, enough to end the app on a small phone.
    return Isolate.run(() {
      final key = pbkdf2(secret, s, iterations, keyLength);
      final cipher = GCMBlockCipher(AESEngine())
        ..init(true, AEADParameters(KeyParameter(key), tagLength * 8, n, header));
      final sealed = cipher.process(plain);
      final file = Uint8List(header.length + sealed.length);
      file.setRange(0, header.length, header);
      file.setRange(header.length, file.length, sealed);
      return file;
    });
  }

  /// The bytes [encrypt] was given, or a [BackupDecryptException] saying why not.
  static Future<Uint8List> decrypt(Uint8List data, String passphrase) async {
    if (!isEncrypted(data)) {
      throw const BackupDecryptException(BackupDecryptFailure.notEncrypted);
    }
    if (data.length < headerLength + tagLength) {
      throw const BackupDecryptException(BackupDecryptFailure.corrupt);
    }
    final fileVersion = data[_magicBytes.length];
    if (fileVersion > version) {
      throw const BackupDecryptException(BackupDecryptFailure.tooNew);
    }
    if (fileVersion < 1) {
      throw const BackupDecryptException(BackupDecryptFailure.corrupt);
    }

    final view = ByteData.sublistView(data);
    final iterations = view.getUint32(_magicBytes.length + 1, Endian.big);
    if (iterations < minIterations || iterations > maxIterations) {
      throw const BackupDecryptException(BackupDecryptFailure.corrupt);
    }
    final saltStart = _magicBytes.length + 1 + 4;
    final salt = Uint8List.sublistView(data, saltStart, saltStart + saltLength);
    final nonce = Uint8List.sublistView(
        data, saltStart + saltLength, saltStart + saltLength + nonceLength);
    final header = Uint8List.sublistView(data, 0, headerLength);
    final sealed = Uint8List.sublistView(data, headerLength);

    final secret = secretFor(passphrase);
    // As in [encrypt]: key and cipher on another isolate. A wrong passphrase comes
    // back as null rather than as an exception thrown across the boundary.
    final plain = await Isolate.run<Uint8List?>(() {
      final key = pbkdf2(secret, salt, iterations, keyLength);
      final cipher = GCMBlockCipher(AESEngine())
        ..init(false, AEADParameters(KeyParameter(key), tagLength * 8, nonce, header));
      try {
        return cipher.process(sealed);
      } on InvalidCipherTextException {
        return null;
      }
    });
    if (plain == null) {
      throw const BackupDecryptException(BackupDecryptFailure.wrongPassphrase);
    }
    return plain;
  }

  static Uint8List _header(int iterations, Uint8List salt, Uint8List nonce) {
    final h = BytesBuilder(copy: false)
      ..add(_magicBytes)
      ..addByte(version)
      ..add((ByteData(4)..setUint32(0, iterations, Endian.big)).buffer.asUint8List())
      ..add(salt)
      ..add(nonce);
    return h.toBytes();
  }

  static Uint8List _random(Random random, int length) =>
      Uint8List.fromList(List<int>.generate(length, (_) => random.nextInt(256)));

  /// PBKDF2-HMAC-SHA256. Public so a test can check it against the published
  /// vectors: the key is only as good as this being the real function.
  static Uint8List pbkdf2(
      Uint8List secret, Uint8List salt, int iterations, int length) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, length));
    return derivator.process(secret);
  }
}

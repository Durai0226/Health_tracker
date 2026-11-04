/// A passphrase on an exported backup: AES-256-GCM, key from PBKDF2-HMAC-SHA256.
///
/// Three layers, because "it round-trips" proves nothing about a cipher: the two
/// primitives against published vectors (so what is called AES-GCM and PBKDF2 is),
/// the wrapper against a key derived independently of it (so the file really is
/// what its doc says), and then the behaviour — what a wrong passphrase, a
/// flipped bit or a hostile iteration count does.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:tablet_remainder/core/services/backup_encryption.dart';

String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List unhex(String s) => Uint8List.fromList([
      for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16)
    ]);

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  // Fast enough to run dozens of times; the default is checked once below.
  const fast = BackupEncryption.minIterations;
  final salt = Uint8List.fromList(List<int>.generate(16, (i) => i));
  final nonce = Uint8List.fromList(List<int>.generate(12, (i) => 0xA0 + i));

  group('the primitives are the real ones', () {
    test('PBKDF2-HMAC-SHA256 against the published vectors', () {
      // RFC 7914 / widely published, "password" and "salt".
      expect(hex(BackupEncryption.pbkdf2(bytes('password'), bytes('salt'), 1, 32)),
          '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
      expect(hex(BackupEncryption.pbkdf2(bytes('password'), bytes('salt'), 4096, 32)),
          'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a');
    });

    test('PBKDF2 at this app\'s lowest count, against Python\'s hashlib', () {
      expect(
          hex(BackupEncryption.pbkdf2(
              bytes('correct horse battery staple'), salt, fast, 32)),
          '49d49c25f597846209f0d92e7770ab64e1c75e94b4ce6c509265ee67175d2a1e');
    });

    test('a passphrase is its UTF-8 bytes: accents and other scripts work', () {
      expect(hex(BackupEncryption.pbkdf2(bytes('pässwörd-密码'), salt, fast, 32)),
          '13277f6dee10710efb04e3ae81d965261a1852871dd05c7afe0e7ddb67160013');
    });

    test('AES-256-GCM against NIST test case 13 (empty plaintext)', () {
      final c = GCMBlockCipher(AESEngine())
        ..init(true, AEADParameters(KeyParameter(Uint8List(32)), 128, Uint8List(12), Uint8List(0)));
      expect(hex(c.process(Uint8List(0))), '530f8afbc74536b9a963b4f1c4cb738b');
    });

    test('AES-256-GCM against NIST test case 14 (one zero block)', () {
      final c = GCMBlockCipher(AESEngine())
        ..init(true, AEADParameters(KeyParameter(Uint8List(32)), 128, Uint8List(12), Uint8List(0)));
      expect(hex(c.process(Uint8List(16))),
          'cea7403d4d606b6e074ec5d3baf39d18d0d1c8a799996bf0265b98b5d48ab919');
    });
  });

  group('the file is what its description says', () {
    test('header, then the sealed bytes, sealed under the independently derived key',
        () async {
      final plain = bytes('hello dlyminder');
      final file = await BackupEncryption.encrypt(plain, 'correct horse battery staple',
          iterations: fast, salt: salt, nonce: nonce);

      // The header: DLYENC, version 1, iterations (big-endian), salt, nonce.
      final header = Uint8List.sublistView(file, 0, BackupEncryption.headerLength);
      expect(ascii.decode(header.sublist(0, 6)), 'DLYENC');
      expect(header[6], 1);
      expect(ByteData.sublistView(header).getUint32(7, Endian.big), fast);
      expect(header.sublist(11, 27), salt);
      expect(header.sublist(27, 39), nonce);

      // The rest: AES-GCM of the plaintext, header as associated data, under the
      // key Python's hashlib derived — not this app's own function.
      final key = unhex('49d49c25f597846209f0d92e7770ab64e1c75e94b4ce6c509265ee67175d2a1e');
      final expected = (GCMBlockCipher(AESEngine())
            ..init(true, AEADParameters(KeyParameter(key), 128, nonce, header)))
          .process(plain);
      expect(hex(file.sublist(BackupEncryption.headerLength)), hex(expected));
    });
  });

  group('round trips', () {
    test('text, with the same passphrase', () async {
      final plain = bytes('{"medicines":[{"name":"Metformin","dose":"500 mg"}]}');
      final file = await BackupEncryption.encrypt(plain, 'open sesame please', iterations: fast);
      expect(await BackupEncryption.decrypt(file, 'open sesame please'), plain);
    });

    test('nothing at all', () async {
      final file = await BackupEncryption.encrypt(Uint8List(0), 'a passphrase', iterations: fast);
      expect(await BackupEncryption.decrypt(file, 'a passphrase'), isEmpty);
    });

    test('every byte value, and a megabyte of it', () async {
      final rnd = Random(7);
      final plain = Uint8List.fromList(List<int>.generate(1 << 20, (_) => rnd.nextInt(256)));
      final file = await BackupEncryption.encrypt(plain, 'a passphrase', iterations: fast);
      expect(await BackupEncryption.decrypt(file, 'a passphrase'), plain);
    });

    test('a passphrase in another script', () async {
      final plain = bytes('record');
      final file = await BackupEncryption.encrypt(plain, 'பாதுகாப்பு-密码-pässwörd', iterations: fast);
      expect(await BackupEncryption.decrypt(file, 'பாதுகாப்பு-密码-pässwörd'), plain);
    });

    test('at the iteration count a real backup uses', () async {
      final plain = bytes('record');
      final file = await BackupEncryption.encrypt(plain, 'a passphrase');
      expect(ByteData.sublistView(file).getUint32(7, Endian.big),
          BackupEncryption.defaultIterations);
      expect(await BackupEncryption.decrypt(file, 'a passphrase'), plain);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('and that count is not below what current guidance asks of PBKDF2-HMAC-SHA256', () {
      // OWASP's password-storage cheat sheet asks for 600,000 rounds. A stolen
      // backup is attacked offline, at whatever speed the attacker's hardware has,
      // and the passphrase is only required to be eight characters.
      expect(BackupEncryption.defaultIterations, greaterThanOrEqualTo(600000));
    });

    test('the same data twice is two different files', () async {
      final plain = bytes('record');
      final a = await BackupEncryption.encrypt(plain, 'a passphrase', iterations: fast);
      final b = await BackupEncryption.encrypt(plain, 'a passphrase', iterations: fast);
      expect(hex(a), isNot(hex(b)));
      expect(hex(a.sublist(11, 27)), isNot(hex(b.sublist(11, 27))), reason: 'salt');
      expect(hex(a.sublist(27, 39)), isNot(hex(b.sublist(27, 39))), reason: 'nonce');
    });

    test('the plaintext is not in the file', () async {
      final plain = bytes('a very recognisable string: Metformin 500 mg');
      final file = await BackupEncryption.encrypt(plain, 'a passphrase', iterations: fast);
      expect(utf8.decode(file, allowMalformed: true), isNot(contains('Metformin')));
    });
  });

  group('what fails to open, and how it says so', () {
    late Uint8List file;

    setUp(() async {
      file = await BackupEncryption.encrypt(bytes('record'), 'right passphrase',
          iterations: fast, salt: salt, nonce: nonce);
    });

    Future<BackupDecryptFailure> failureOf(Uint8List data, String pass) async {
      try {
        await BackupEncryption.decrypt(data, pass);
      } on BackupDecryptException catch (e) {
        return e.failure;
      }
      fail('expected it not to open');
    }

    test('a wrong passphrase', () async {
      expect(await failureOf(file, 'wrong passphrase'), BackupDecryptFailure.wrongPassphrase);
    });

    test('the right passphrase with a character changed or a space added', () async {
      expect(await failureOf(file, 'right passphrasE'), BackupDecryptFailure.wrongPassphrase);
      expect(await failureOf(file, 'right passphrase '), BackupDecryptFailure.wrongPassphrase,
          reason: 'a passphrase is exactly what was typed, spaces included');
    });

    test('an empty passphrase', () async {
      expect(await failureOf(file, ''), BackupDecryptFailure.wrongPassphrase);
    });

    test('a byte flipped anywhere after the header: the ciphertext, the tag', () async {
      for (final at in [BackupEncryption.headerLength, file.length - 1, file.length - 17]) {
        final tampered = Uint8List.fromList(file)..[at] ^= 0x01;
        expect(await failureOf(tampered, 'right passphrase'),
            BackupDecryptFailure.wrongPassphrase, reason: 'byte $at');
      }
    });

    test('the salt, the nonce or the iteration count changed', () async {
      for (final at in [12, 20, 30, 38, 10]) {
        // 10 is the low byte of the iteration count: still a legal count, so only
        // the authentication of the header can refuse it.
        final tampered = Uint8List.fromList(file)..[at] ^= 0x01;
        expect(await failureOf(tampered, 'right passphrase'),
            BackupDecryptFailure.wrongPassphrase, reason: 'byte $at');
      }
    });

    test('a byte added, or taken off the end', () async {
      expect(await failureOf(Uint8List.fromList([...file, 0]), 'right passphrase'),
          BackupDecryptFailure.wrongPassphrase);
      expect(await failureOf(Uint8List.sublistView(file, 0, file.length - 1), 'right passphrase'),
          BackupDecryptFailure.wrongPassphrase);
    });

    test('cut off inside the header, or before the tag', () async {
      expect(await failureOf(Uint8List.sublistView(file, 0, 20), 'right passphrase'),
          BackupDecryptFailure.corrupt);
      expect(
          await failureOf(Uint8List.sublistView(file, 0, BackupEncryption.headerLength + 3),
              'right passphrase'),
          BackupDecryptFailure.corrupt);
    });

    test('something that is not one of these files', () async {
      expect(await failureOf(bytes('PK\x03\x04 a zip'), 'right passphrase'),
          BackupDecryptFailure.notEncrypted);
      expect(await failureOf(Uint8List(0), 'right passphrase'),
          BackupDecryptFailure.notEncrypted);
      expect(await failureOf(bytes('DLY'), 'right passphrase'),
          BackupDecryptFailure.notEncrypted);
    });

    test('a file from a newer version says so, rather than failing as "wrong passphrase"',
        () async {
      final newer = Uint8List.fromList(file)..[6] = BackupEncryption.version + 1;
      expect(await failureOf(newer, 'right passphrase'), BackupDecryptFailure.tooNew);
    });

    test('version zero is damage, not a version', () async {
      final zero = Uint8List.fromList(file)..[6] = 0;
      expect(await failureOf(zero, 'right passphrase'), BackupDecryptFailure.corrupt);
    });

    test('a hostile iteration count is refused at once, not computed', () async {
      for (final iterations in [0, BackupEncryption.minIterations - 1, 0xFFFFFFFF,
          BackupEncryption.maxIterations + 1]) {
        final hostile = Uint8List.fromList(file);
        ByteData.sublistView(hostile).setUint32(7, iterations, Endian.big);
        final clock = Stopwatch()..start();
        expect(await failureOf(hostile, 'right passphrase'), BackupDecryptFailure.corrupt,
            reason: '$iterations');
        expect(clock.elapsed, lessThan(const Duration(seconds: 1)),
            reason: 'a refusal must not run the key derivation first');
      }
    });
  });

  group('limits', () {
    test('a new backup will not use too few rounds or an absurd number', () async {
      await expectLater(
          BackupEncryption.encrypt(bytes('x'), 'a passphrase',
              iterations: BackupEncryption.minIterations - 1),
          throwsRangeError);
      await expectLater(
          BackupEncryption.encrypt(bytes('x'), 'a passphrase',
              iterations: BackupEncryption.maxIterations + 1),
          throwsRangeError);
    });

    test('a salt or nonce of the wrong length is refused', () async {
      await expectLater(
          BackupEncryption.encrypt(bytes('x'), 'a passphrase',
              iterations: fast, salt: Uint8List(8)),
          throwsArgumentError);
      await expectLater(
          BackupEncryption.encrypt(bytes('x'), 'a passphrase',
              iterations: fast, nonce: Uint8List(8)),
          throwsArgumentError);
    });

    test('the passphrase must be at least eight characters', () {
      expect(BackupEncryption.validatePassphrase('1234567'), isNotNull);
      expect(BackupEncryption.validatePassphrase('12345678'), isNull);
      expect(BackupEncryption.validatePassphrase(''), isNotNull);
      expect(BackupEncryption.validatePassphrase('密码密码密码密码'), isNull,
          reason: 'characters, not bytes');
    });

    test('characters are counted as a person counts them', () {
      // An emoji is one character, not the two halves of a surrogate pair: four of
      // them used to pass for eight.
      expect(BackupEncryption.validatePassphrase('😀😀😀😀'), isNotNull);
      expect(BackupEncryption.validatePassphrase('😀😀😀😀😀😀😀😀'), isNull);
      // A letter and its combining accent is one character once composed.
      expect(BackupEncryption.validatePassphrase('cafe\u0301caf'), isNotNull,
          reason: 'seven characters, though eight code points');
      expect(BackupEncryption.validatePassphrase('cafe\u0301cafe'), isNull,
          reason: 'eight characters, nine code points');
    });

    test('a passphrase of nothing but spaces is not one, however many', () {
      expect(BackupEncryption.validatePassphrase('        '), contains('only spaces'));
      expect(BackupEncryption.validatePassphrase('\t\t\t\t\t\t\t\t'), contains('only spaces'));
      expect(BackupEncryption.validatePassphrase('\u00A0' * 10), contains('only spaces'));
      // Spaces inside it are fine, and so are spaces round it.
      expect(BackupEncryption.validatePassphrase('correct horse battery'), isNull);
      expect(BackupEncryption.validatePassphrase('  ab cd ef  '), isNull);
    });

    test('too short and only spaces are different answers', () {
      expect(BackupEncryption.validatePassphrase('   '), contains('only spaces'));
      expect(BackupEncryption.validatePassphrase('abc'), contains('at least'));
    });
  });

  group('the same word typed two ways', () {
    // Unicode writes an accented letter as one code point (NFC) or as a letter and a
    // combining mark (NFD), and keyboards and pasted text do not agree. Different
    // bytes were different keys, and a file that opened on one phone said "wrong
    // passphrase" on the other, with no way back.
    const composed = 'Caf\u00E9 au lait 2026';
    const decomposed = 'Cafe\u0301 au lait 2026';

    test('the two are different strings, which is the problem', () {
      expect(composed == decomposed, isFalse);
    });

    test('but the same secret', () {
      expect(BackupEncryption.secretFor(composed), BackupEncryption.secretFor(decomposed));
    });

    test('so a backup made with one opens with the other, both ways', () async {
      final plain = bytes('a year of logs');
      final a = await BackupEncryption.encrypt(plain, composed, iterations: fast);
      final b = await BackupEncryption.encrypt(plain, decomposed, iterations: fast);

      expect(await BackupEncryption.decrypt(a, decomposed), plain);
      expect(await BackupEncryption.decrypt(b, composed), plain);
    });

    test('an ASCII passphrase is exactly what it was: nothing made before is affected', () {
      expect(BackupEncryption.secretFor('plain ascii words'), bytes('plain ascii words'));
    });

    test('and a different word is still a different secret', () {
      expect(BackupEncryption.secretFor('Caf\u00E9'), isNot(BackupEncryption.secretFor('Cafe')));
    });

    test('compatibility characters are NOT folded together — only the composition is', () {
      // NFC, not NFKC: a full-width letter is a different character, and treating
      // it as the plain one would make two passphrases the same that were typed
      // differently on purpose.
      expect(BackupEncryption.secretFor('\uFF21'), isNot(BackupEncryption.secretFor('A')));
    });
  });

  group('recognising one', () {
    test('a file this made is one; a zip, nothing and a stub are not', () async {
      final file = await BackupEncryption.encrypt(bytes('x'), 'a passphrase', iterations: fast);
      expect(BackupEncryption.isEncrypted(file), isTrue);
      expect(BackupEncryption.isEncrypted(bytes('PK\x03\x04')), isFalse);
      expect(BackupEncryption.isEncrypted(Uint8List(0)), isFalse);
      expect(BackupEncryption.isEncrypted(bytes('DLYEN')), isFalse);
    });
  });

  test('every message says something a person can act on', () {
    for (final f in BackupDecryptFailure.values) {
      expect(BackupDecryptException(f).message, isNotEmpty);
    }
    expect(const BackupDecryptException(BackupDecryptFailure.wrongPassphrase).message,
        contains('passphrase'));
  });
}

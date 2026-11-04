/// The share sheet is opened from one place.
///
/// Five exports each called the sharing package's deprecated `Share.shareXFiles`
/// themselves. Now they hand a file to `shareFile`, which owns the call — so what
/// it passes to the package is proved here, and the rule that nothing else calls
/// the package is a test too, because a sixth export would otherwise copy the first
/// one it finds.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tablet_remainder/core/utils/share_file.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<ShareParams> shared;

  setUp(() {
    shared = [];
    shareParamsForTesting = (params) async => shared.add(params);
  });

  tearDown(() => shareParamsForTesting = null);

  group('what is handed to the sheet', () {
    test('the file, by its path, with the type it was given', () async {
      await shareFile(File('/tmp/medication-log.csv'), mimeType: 'text/csv');

      final params = shared.single;
      expect(params.files, hasLength(1));
      expect(params.files!.single.path, '/tmp/medication-log.csv');
      expect(params.files!.single.mimeType, 'text/csv');
    });

    test('the text that goes beside it', () async {
      await shareFile(File('/tmp/emergency-card.png'), mimeType: 'image/png', text: 'Name: A');

      expect(shared.single.text, 'Name: A');
      expect(shared.single.subject, isNull);
    });

    test('the subject of a mail', () async {
      await shareFile(File('/tmp/a.csv'), subject: 'Medicine log (last 30 days)');

      expect(shared.single.subject, 'Medicine log (last 30 days)');
      expect(shared.single.text, isNull);
    });

    test('and no type at all when none is given, as for a backup', () async {
      await shareFile(File('/tmp/backup.zip'), text: 'DlyMinder Backup');

      expect(shared.single.files!.single.mimeType, isNull);
    });

    test('once per call', () async {
      await shareFile(File('/tmp/a.csv'));
      await shareFile(File('/tmp/b.csv'));

      expect(shared.map((p) => p.files!.single.path), ['/tmp/a.csv', '/tmp/b.csv']);
    });

    test('a share that fails is the caller\'s to hear about', () async {
      shareParamsForTesting = (_) async => throw StateError('no share sheet');

      await expectLater(shareFile(File('/tmp/a.csv')), throwsStateError);
    });
  });

  group('and nothing else opens it', () {
    final lib = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    String code(File f) => f
        .readAsLinesSync()
        .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
        .join('\n');

    test('no other file imports the sharing package', () {
      final importing = [
        for (final f in lib)
          if (code(f).contains('package:share_plus/') && !f.path.endsWith('core/utils/share_file.dart'))
            f.path,
      ];

      expect(importing, isEmpty,
          reason: 'use shareFile(...) from core/utils/share_file.dart, so a change to the '
              'package is made once');
    });

    test('and nothing calls the deprecated API', () {
      final calling = [
        for (final f in lib)
          if (RegExp(r'\bShare\.(shareXFiles|share|shareUri)\b').hasMatch(code(f))) f.path,
      ];

      expect(calling, isEmpty);
    });
  });
}

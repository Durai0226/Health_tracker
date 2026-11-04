/// "Delete all data" removes every key an import keeps.
///
/// The wipe finds them by prefix, from a list kept by hand. An import that keeps a
/// key under a different name — its switch, where its last run ended, the ids it has
/// seen, the "asked" flag — survives the wipe: the consent stays given, and the ids
/// make the next opt-in skip everything the health store still holds. Nothing else
/// notices, so the source is read.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';

void main() {
  final libFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();

  String code(File f) => f
      .readAsLinesSync()
      .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
      .join('\n');

  const prefixes = CleanStorageService.healthImportPrefixes;

  test('every key that names an import starts with a prefix the wipe removes', () {
    final keys = <String, String>{};
    for (final f in libFiles) {
      for (final m in RegExp(r"'([a-z0-9_]*health_import[a-z0-9_]*)'").allMatches(code(f))) {
        keys[m.group(1)!] = f.path;
      }
    }

    expect(keys, isNotEmpty, reason: 'the scan found the keys that exist');
    final loose = {
      for (final e in keys.entries)
        if (!prefixes.any(e.key.startsWith)) e.key: e.value,
    };
    expect(loose, isEmpty,
        reason: 'these survive "Delete all data": rename them under one of $prefixes, or '
            'add their prefix to CleanStorageService.healthImportPrefixes');
  });

  test('every import is built with keys of that shape', () {
    var found = 0;
    for (final f in libFiles) {
      final source = code(f);
      for (final start in RegExp(r'HealthImportControl\(').allMatches(source)) {
        final end = source.indexOf(');', start.end);
        final args = source.substring(start.end, end);
        final enabled = RegExp(r"enabledKey:\s*'([^']+)'").firstMatch(args)?.group(1);
        final lastRun = RegExp(r"lastRunKey:\s*'([^']+)'").firstMatch(args)?.group(1);
        if (enabled == null || lastRun == null) continue; // the class's own constructor
        found++;
        expect(prefixes.any(enabled.startsWith), isTrue, reason: '${f.path}: $enabled');
        expect(prefixes.any(lastRun.startsWith), isTrue, reason: '${f.path}: $lastRun');
      }
    }
    expect(found, greaterThanOrEqualTo(2), reason: 'the vitals and the drinks import');
  });

  test('and the prefixes are the ones the two imports and the permission flags use', () {
    expect(prefixes, containsAll(['water_health_import_', 'vitals_health_import_']));
  });
}

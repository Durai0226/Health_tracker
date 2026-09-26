import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// SB-11 and SB-14 — the file-backup screen described a feature the app does
/// not have, and wore the other screen's iconography.
///
/// SB-11: two places warned that "Locked notes are encrypted" and would need
/// "the encryption key from the device that created them". There is no lockable
/// or encrypted note anywhere in this app. A warning about a feature that does
/// not exist teaches the user to distrust the warnings that do.
///
/// SB-14: this screen exports to a FILE the user shares themselves; the cloud
/// one is settings/screens/backup_screen.dart. Both wore `cloud_upload_rounded`,
/// so the two entry points were indistinguishable — and here the icon
/// contradicted the subtitle beside it, which already said "Export your data to
/// a file".
///
/// Source-scanned because BackupService reaches FirebaseFirestore.instance in a
/// field initialiser, so the screen cannot be pumped in a host VM
/// (`[core/no-app] No Firebase App '[DEFAULT]' has been created`) — the
/// responsive harness allow-lists it for the same reason.
void main() {
  const fileScreen =
      'lib/features/backup/presentation/screens/backup_settings_screen.dart';

  test('SB-11 — no copy anywhere names a feature the app does not have', () {
    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (f.readAsStringSync().toLowerCase().contains('locked note')) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'there is no lockable/encrypted note feature to warn about:\n'
            '  ${offenders.join('\n  ')}');
  });

  test('SB-11 — and the diary still has no such feature to warn about', () {
    // If encrypted notes are ever ADDED, this fails and the removed warning
    // becomes legitimate again — at which point both should be reconsidered
    // together rather than one silently drifting back.
    final diary = Directory('lib/features/diary');
    if (!diary.existsSync()) return;
    final hits = diary
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => RegExp(r'\b(isLocked|encryptNote|noteEncryption)\b')
            .hasMatch(f.readAsStringSync()))
        .map((f) => f.path)
        .toList();
    expect(hits, isEmpty,
        reason: 'encrypted notes now exist — revisit the removed warning');
  });

  test('SB-14 — the file flow does not wear cloud iconography', () {
    final src = File(fileScreen).readAsStringSync();
    expect(src.contains('cloud_upload_rounded'), isFalse,
        reason: 'this screen exports to a file; the cloud screen is '
            'settings/screens/backup_screen.dart. Identical glyphs made the '
            'two entry points indistinguishable');
    expect(src, contains('Symbols.save_alt_rounded'));
    expect(src, contains("title: 'Backup to a file'"),
        reason: 'the section title is the other half of telling them apart');
  });

  test('the scanner is reading the real screen', () {
    final src = File(fileScreen).readAsStringSync();
    expect(src.length, greaterThan(5000));
    expect(src, contains('class BackupSettingsScreen'));
  });
}

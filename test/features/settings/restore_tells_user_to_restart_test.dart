/// Both restore screens have to mention the restart the restore depends on.
///
/// `CleanStorageService.importData` states the contract: the SleepService /
/// PeriodService / StepService singletons hold their own in-memory copy and
/// reload it in `init()`, "so the restored nights, cycles and step days appear
/// after the app restart the restore screens already ask for".
///
/// The LOCAL screen asks ("Data restored. Please restart the app."). The CLOUD
/// screen reported plain success and left a `// Maybe ... restart app logic?`
/// note where the ask should have been — so a user came back to Sleep and
/// Period still showing pre-restore values, with every reason to believe the
/// restore had silently failed.
///
/// Asserted on the source because both messages are built inside async
/// handlers behind a file picker and a signed-in cloud account.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// [path]'s source with comments stripped — a guard its own prose satisfies
  /// is not a guard.
  String code(String path) => File(path)
      .readAsStringSync()
      .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '')
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');

  const screens = <String, String>{
    'cloud': 'lib/features/settings/screens/backup_screen.dart',
    'local': 'lib/features/backup/presentation/screens/backup_settings_screen.dart',
  };

  screens.forEach((which, path) {
    test('the $which restore screen asks for a restart', () {
      final src = code(path);

      // Sanity: it really does report a successful restore.
      expect(RegExp(r'[Rr]estored').hasMatch(src), isTrue,
          reason: '$path no longer reports a restore at all — this test is '
              'measuring nothing');

      expect(RegExp(r'[Rr]estart').hasMatch(src), isTrue,
          reason: '$path tells the user the restore succeeded without '
              'mentioning the restart it depends on. Sleep, period and step '
              'data keep showing their pre-restore values until then.');
    });
  });
}

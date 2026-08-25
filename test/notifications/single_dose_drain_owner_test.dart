import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `drainPendingDoseActions()` is read-and-clear: whoever calls it first gets the
/// ids and everyone after gets an empty list.
///
/// Two places called it — `AppShell.didChangeAppLifecycleState` and the medicine
/// dashboard's own `_loadDataOnce` — each with its own hand-maintained
/// "Logged N doses · Undo" toast. So they raced. On a resume into the Meds tab,
/// whichever ran first reported the doses and the other reported nothing: whether
/// the user was TOLD that a dose had been logged on their behalf depended on which
/// tab they happened to have open. Two independent Undo implementations for one
/// action, and one of them always dead.
///
/// The drain also has to happen on COLD START, which is the likeliest case of all
/// — a notification action tapped while the app was dead is exactly what fills the
/// queue — and `didChangeAppLifecycleState` does not fire for the initial launch.
/// That is why the dashboard's drain could not simply be deleted: it was the only
/// cold-start drain there was.
String _codeOnly(String source) => source
    .split('\n')
    .where((l) {
      final t = l.trimLeft();
      return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
    })
    .join('\n');

void main() {
  const shellPath = 'lib/features/home/screens/app_shell.dart';
  const dashPath =
      'lib/features/medication/screens/nunito_medication_dashboard.dart';

  late String shell;
  late String dash;

  setUpAll(() {
    shell = _codeOnly(File(shellPath).readAsStringSync());
    dash = _codeOnly(File(dashPath).readAsStringSync());
  });

  group('exactly one owner drains the dose queue', () {
    test('AppShell is the only caller in lib/', () {
      final callers = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (_codeOnly(f.readAsStringSync()).contains('drainPendingDoseActions(')) {
          callers.add(f.path);
        }
      }
      // The service that defines it, plus the single UI owner.
      expect(
        callers.where((p) => p.contains('screens')).toList(),
        [shellPath],
        reason: 'a second draining screen races the first for the ids, and the '
            'loser silently reports nothing',
      );
    });

    test('the dashboard no longer drains or reports', () {
      expect(dash.contains('drainPendingDoseActions'), isFalse);
      expect(dash.contains('_drainedLogIds'), isFalse,
          reason: 'the field and its toast block are unreachable once the '
              'drain moves out');
    });

    test('the dashboard still refreshes when the drain writes', () {
      // This is what makes removing its drain safe: the drain bumps `revision`,
      // and the dashboard reloads from that. Without this listener the Meds tab
      // would show stale numbers after a cold-start drain.
      expect(shell, contains('_drainQueuedDoseActions'));
      expect(dash, contains('MedicineCleanStorageService.revision.addListener'));
    });
  });

  group('the drain runs on cold start, not only on resume', () {
    test('AppShell drains from initState as well as the lifecycle hook', () {
      final initState = shell.substring(
        shell.indexOf('void initState()'),
        shell.indexOf('void dispose()'),
      );
      expect(initState, contains('_drainQueuedDoseActions()'),
          reason: 'didChangeAppLifecycleState never fires for the initial '
              'launch, so a dose tapped while the app was dead would sit '
              'unapplied until the user backgrounded and foregrounded');
      expect(initState, contains('addPostFrameCallback'),
          reason: 'the drain shows a toast, which needs a mounted Scaffold');
    });

    test('the resume path still drains', () {
      final onResume = shell.substring(
        shell.indexOf('void didChangeAppLifecycleState'),
        shell.indexOf('Future<void> _drainBackgroundHealthSync'),
      );
      expect(onResume, contains('_drainQueuedDoseActions()'));
    });

    test('both entry points drain the same three queues', () {
      // Water and the health-sync snapshot have the same cold-start problem.
      final initState = shell.substring(
        shell.indexOf('void initState()'),
        shell.indexOf('void dispose()'),
      );
      final onResume = shell.substring(
        shell.indexOf('void didChangeAppLifecycleState'),
        shell.indexOf('Future<void> _drainBackgroundHealthSync'),
      );
      for (final drain in [
        '_drainQueuedDoseActions()',
        '_drainQueuedWaterActions()',
        '_drainBackgroundHealthSync()',
      ]) {
        expect(initState, contains(drain), reason: 'cold start: $drain');
        expect(onResume, contains(drain), reason: 'resume: $drain');
      }
    });
  });
}

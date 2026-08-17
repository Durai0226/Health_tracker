import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A source-grep guard, in the spirit of `no_generative_ai_guard_test.dart`.
///
/// The background health worker runs in its own isolate with its own
/// FlutterEngine. Four things it must never do are invisible to any behavioural
/// test — they only fail on a real device, in the background, silently — so
/// they are asserted against the source instead.
///
/// This is a blunt instrument on purpose. A reviewer adding one plausible-
/// looking import is exactly how each of these gets reintroduced.
/// Comments are stripped before every check.
///
/// Both files explain WHY each of these is banned, naming the very symbols
/// being banned — so a naive grep flags the documentation that exists to
/// prevent the bug. Asserting against code only is the difference between a
/// guard and a nuisance.
String _codeOnly(String source) => source
    .split('\n')
    .where((l) {
      final t = l.trimLeft();
      return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
    })
    .join('\n');

void main() {
  final worker = _codeOnly(
      File('lib/core/services/background_health_sync_service.dart')
          .readAsStringSync());
  final queue = _codeOnly(
      File('lib/core/services/health_sync_queue.dart').readAsStringSync());

  /// Only the `executeTask` closure — the part that actually runs in the
  /// background isolate. `enable()` and `disable()` are ordinary main-isolate
  /// methods and return false legitimately.
  final dispatcher = worker.substring(
    worker.indexOf('healthSyncCallbackDispatcher'),
    worker.indexOf('Future<Map<String, dynamic>?> _readSnapshot'),
  );

  group('the background worker stays out of the main isolate\'s territory', () {
    test('never touches Drift', () {
      // The main isolate owns the database. A background write would need
      // shareAcrossIsolates:true, which reroutes every query in the app through
      // a port and lets a worker run a schema migration with no UI to report a
      // failure — and it would be invisible to the in-memory ValueNotifiers the
      // screens render from anyway.
      for (final banned in ['app_database', 'drift', 'Dao']) {
        expect(worker.contains(banned), isFalse,
            reason: '$banned in the worker: it must hand off through '
                'HealthSyncQueue, not write rows itself');
        expect(queue.contains(banned), isFalse, reason: '$banned in the queue');
      }
    });

    test('never touches Firestore', () {
      // It cannot read CleanStorageService.cloudSyncEnabled (that needs Drift),
      // so any upload from here would bypass the consent gate entirely — the
      // exact class of bug main.dart:132-153 was written to close.
      for (final banned in ['cloud_firestore', 'FirebaseFirestore', 'firebase']) {
        expect(worker.toLowerCase().contains(banned.toLowerCase()), isFalse,
            reason: '$banned in the worker would bypass cloud-sync consent');
      }
    });

    test('never initialises local notifications', () {
      // FlutterLocalNotificationsPlugin().initialize() from a background
      // isolate overwrites the app-wide background-response handle and
      // silently breaks "✓ Take" from a notification — documented at
      // background_alarm_service.dart:214.
      expect(worker.contains('FlutterLocalNotificationsPlugin'), isFalse);
      expect(worker.contains('flutter_local_notifications'), isFalse);
    });

    test('never rides the exact-alarm path', () {
      // _registerAlarm writes exactAlarmsDowngradedKey, which feeds the
      // "your reminders are inexact" warning. A data sync registering
      // inexactly would tell the user their MEDICINE REMINDERS are degraded.
      expect(worker.contains('_registerAlarm'), isFalse);
      expect(worker.contains('AndroidAlarmManager'), isFalse);
      expect(worker.contains('android_alarm_manager'), isFalse);
    });
  });

  group('failure handling', () {
    test('the task never returns false', () {
      // Returning false triggers exponential-backoff retries. On a revoked
      // permission that means waking the device forever for a grant that
      // cannot come back without the user opening the app.
      expect(dispatcher.contains('return false;'), isFalse,
          reason: 'a failing background read must self-cancel or record a '
              'breadcrumb, never ask WorkManager to retry it');
      expect(dispatcher.contains('return true;'), isTrue);
    });

    test('it self-cancels when the permission is gone', () {
      expect(worker.contains('cancelByUniqueName'), isTrue);
    });
  });

  test('the job never waits on a network connection', () {
    // Health Connect is entirely local. A network constraint would delay — or
    // wake the radio for — a job that has no use for it.
    expect(worker.contains('NetworkType.notRequired'), isTrue);
  });
}

/// When the cloud sync runs: at start, the moment it is switched on, and when the
/// app comes back after a while — behind the same two gates every time.
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/cloud_sync_runner.dart';

void main() {
  final start = DateTime(2026, 6, 20, 9);
  final ran = <String>[];

  setUp(() {
    ran.clear();
    CloudSyncRunner.resetForTesting();
  });

  Future<bool> run({
    bool force = false,
    bool authenticated = true,
    bool enabled = true,
    String? userId = 'u-1',
    Future<void> Function(String)? sync,
    DateTime? at,
  }) =>
      withClock(
        Clock.fixed(at ?? start),
        () => CloudSyncRunner.maybeSync(
          force: force,
          authenticated: authenticated,
          enabled: enabled,
          userId: userId ?? '',
          sync: sync ?? (id) async => ran.add(id),
        ),
      );

  group('the two gates', () {
    test('a real account, and their own opt-in: it runs', () async {
      expect(await run(), isTrue);
      expect(ran, ['u-1']);
    });

    test('an anonymous or guest account never syncs — health data stays put',
        () async {
      expect(await run(authenticated: false), isFalse);
      expect(ran, isEmpty);
      expect(CloudSyncRunner.lastSkipReason, contains('signed in'));
    });

    test('switched off never syncs, however it was asked for', () async {
      expect(await run(enabled: false), isFalse);
      expect(await run(enabled: false, force: true), isFalse);
      expect(ran, isEmpty);
      expect(CloudSyncRunner.lastSkipReason, contains('switched off'));
    });

    test('and force does not open either gate', () async {
      expect(await run(force: true, authenticated: false), isFalse);
      expect(ran, isEmpty);
    });

    test('no user id', () async {
      expect(await run(userId: ''), isFalse);
      expect(ran, isEmpty);
    });
  });

  group('how often', () {
    test('the moment it is switched on: now, never mind when it last ran',
        () async {
      await run();
      expect(await run(force: true, at: start.add(const Duration(minutes: 2))), isTrue);
      expect(ran, hasLength(2));
    });

    test('coming back soon after a run does not sync again', () async {
      await run();
      expect(await run(at: start.add(const Duration(minutes: 10))), isFalse);
      expect(ran, hasLength(1));
      expect(CloudSyncRunner.lastSkipReason, contains('min ago'));
    });

    test('coming back after the interval does', () async {
      await run();
      expect(
          await run(at: start.add(CloudSyncRunner.resumeInterval)), isTrue,
          reason: 'at the interval, not just past it');
      expect(ran, hasLength(2));
    });

    test('one minute short of it does not', () async {
      await run();
      expect(
          await run(
              at: start.add(CloudSyncRunner.resumeInterval - const Duration(minutes: 1))),
          isFalse);
    });

    test('the first run of a session is never held back', () async {
      expect(await run(), isTrue);
    });
  });

  group('failing', () {
    test('a sync that throws is false, not an exception', () async {
      expect(await run(sync: (_) async => throw Exception('offline')), isFalse);
    });

    test('and does not count: it is tried again at the next chance', () async {
      await run(sync: (_) async => throw Exception('offline'));
      expect(await run(at: start.add(const Duration(minutes: 1))), isTrue,
          reason: 'a run that did not finish must not hold the next one back');
    });
  });

  group('wired in', () {
    String src(String p) => File(p).readAsStringSync();

    test('start-up goes through it, not around it', () {
      final main = src('lib/main.dart');
      expect(main, contains('CloudSyncRunner.maybeSync(force: true)'));
      expect(main, isNot(contains('syncUserData(')),
          reason: 'a second copy of the gates is how they drift apart');
    });

    test('switching it on starts a run at once', () {
      final s = src('lib/features/settings/screens/settings_screen.dart');
      final at = s.indexOf('setCloudSyncEnabled(v)');
      expect(at, greaterThan(0));
      expect(s.substring(at, at + 700),
          contains('if (v) unawaited(CloudSyncRunner.maybeSync(force: true));'));
    });

    test('coming back to the app runs it, throttled', () {
      final shell = src('lib/features/home/screens/app_shell.dart');
      expect(shell, contains('unawaited(CloudSyncRunner.maybeSync());'));
    });
  });
}

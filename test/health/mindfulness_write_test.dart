import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/mindfulness_channel.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';

/// Mindfulness write-back — the Dart half of the contract.
///
/// What this CAN prove: that the right call is made with the right arguments,
/// that nothing is written when the toggle is off or the feature is unavailable,
/// and — the one that matters most — that a work session is never written as
/// mindfulness practice.
///
/// What it cannot: that Health Connect stores it. That needs a device with a
/// recent Play System Update, and it is written down as a manual check in
/// `docs/release-checklist.md` rather than implied to be covered here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  const channel = MethodChannel('dlyminder/mindfulness');

  void mock({bool available = true, bool permitted = true, bool wrote = true}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'isAvailable':
          return available;
        case 'hasPermission':
          return permitted;
        case 'writeSession':
          return wrote;
      }
      return null;
    });
  }

  setUp(() {
    calls = [];
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    MindfulnessChannel.channelForTesting = channel;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('what counts as mindfulness', () {
    test('meditation does', () {
      expect(mindfulnessKindFor(FocusActivityType.meditation),
          MindfulnessKind.meditation);
    });

    test('concentration does not — every kind of it', () {
      // The single most important assertion in this file. Forest logs all focus
      // sessions to Apple Health as Mindful Minutes; a coding sprint filed as
      // mindfulness practice is a false claim in a permanent health record.
      for (final t in FocusActivityType.values) {
        if (t == FocusActivityType.meditation) continue;
        expect(mindfulnessKindFor(t), isNull, reason: t.name);
      }
    });

    test('the kind ordinals are the wire format and must not move', () {
      // MindfulnessChannel.kt switches on these integers.
      expect(MindfulnessKind.breathing.index, 0);
      expect(MindfulnessKind.meditation.index, 1);
      expect(MindfulnessKind.music.index, 2);
    });
  });

  group('the channel', () {
    test('reports unavailable off Android without calling anything', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      mock();
      expect(await MindfulnessChannel.instance.isAvailable(), isFalse);
      expect(calls, isEmpty,
          reason: 'iOS goes through package:health, which supports MINDFULNESS '
              'there — this channel must stay out of its way');
    });

    test('writes with the right arguments', () async {
      mock();
      final start = DateTime(2026, 3, 15, 10, 0);
      final end = DateTime(2026, 3, 15, 10, 20);
      final ok = await MindfulnessChannel.instance.writeSession(
        start: start,
        end: end,
        kind: MindfulnessKind.breathing,
        title: 'Breathing exercise',
        clientId: 'abc',
      );
      expect(ok, isTrue);

      final write = calls.singleWhere((c) => c.method == 'writeSession');
      final args = Map<String, dynamic>.from(write.arguments as Map);
      expect(args['startMs'], start.millisecondsSinceEpoch);
      expect(args['endMs'], end.millisecondsSinceEpoch);
      expect(args['kind'], MindfulnessKind.breathing.index);
      expect(args['clientId'], 'abc',
          reason: 'doubles as the Health Connect clientRecordId, so a retry '
              'after a crash cannot double-write');
    });

    test('refuses a zero-length or reversed session', () async {
      mock();
      final t = DateTime(2026, 3, 15, 10, 0);
      expect(
          await MindfulnessChannel.instance.writeSession(
              start: t, end: t, kind: MindfulnessKind.meditation),
          isFalse);
      expect(
          await MindfulnessChannel.instance.writeSession(
              start: t,
              end: t.subtract(const Duration(minutes: 5)),
              kind: MindfulnessKind.meditation),
          isFalse);
      expect(calls.where((c) => c.method == 'writeSession'), isEmpty,
          reason: 'nothing to write is not an error to raise');
    });

    test('a platform failure never escapes', () async {
      // This runs off the completion path. An exception here would propagate into
      // the code that has just saved the user's session.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'boom');
      });
      expect(await MindfulnessChannel.instance.isAvailable(), isFalse);
      expect(await MindfulnessChannel.instance.hasPermission(), isFalse);
      expect(
          await MindfulnessChannel.instance.writeSession(
            start: DateTime(2026, 3, 15, 10, 0),
            end: DateTime(2026, 3, 15, 10, 20),
            kind: MindfulnessKind.meditation,
          ),
          isFalse);
    });

    test('a missing native implementation is a no, not a crash', () async {
      // The case on any build where the channel is not registered.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      expect(await MindfulnessChannel.instance.isAvailable(), isFalse);
    });
  });
}

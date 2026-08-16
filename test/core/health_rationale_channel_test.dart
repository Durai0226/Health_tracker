import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/health_rationale_channel.dart';
import 'package:tablet_remainder/features/settings/screens/health_privacy_screen.dart';
import 'package:tablet_remainder/main.dart' show navigatorKey;

/// Health Connect's "show your rationale" deep link had no destination at all
/// before this channel existed: AndroidManifest declared the filters, but
/// MainActivity handled no intents, so the app just came forward on whatever
/// route it was on. Google reviews that flow for any app declaring health
/// permissions, so these are release-blocking behaviours, not conveniences.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(HealthRationaleChannel.instance.resetForTesting);

  tearDown(() {
    messenger.setMockMethodCallHandler(HealthRationaleChannel.channel, null);
  });

  /// Fixed-frame pump, never `pumpAndSettle`.
  ///
  /// This app runs continuous animations (nav orb, skeletons, ad views) that
  /// never reach a settled state, so `pumpAndSettle` burns its full ten-minute
  /// timeout instead of returning — the same reason it is banned in
  /// `integration_test/support/e2e.dart`.
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 250));
    }
  }

  /// The service is Android-only, and `defaultTargetPlatform` is macOS under
  /// `flutter test` — without this override every expectation below would pass
  /// vacuously.
  ///
  /// Cleared inside the body rather than in `tearDown`, because the framework
  /// asserts all debug vars are unset at the END OF THE TEST BODY, before
  /// tearDown ever runs.
  Future<void> onPlatform(
      TargetPlatform platform, Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  /// Real navigator, because the push path is the thing under test — and it is
  /// keyed by the app's own [navigatorKey], which the service reaches through.
  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('host')),
    ));
  }

  /// Answers `consumePendingRationale` with [action], and records every call so
  /// a test can assert the buffer was drained exactly once.
  List<MethodCall> mockNative(String? action) {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(HealthRationaleChannel.channel,
        (call) async {
      calls.add(call);
      return call.method == 'consumePendingRationale' ? action : null;
    });
    return calls;
  }

  Future<void> pushFromNative() => messenger.handlePlatformMessage(
        HealthRationaleChannel.channel.name,
        HealthRationaleChannel.channel.codec
            .encodeMethodCall(const MethodCall('showHealthPrivacy')),
        (_) {},
      );

  const kRationale = 'androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE';

  testWidgets('a buffered cold-start intent opens the disclosure', (t) async {
    await onPlatform(TargetPlatform.android, () async {
      await pumpHost(t);
      final calls = mockNative(kRationale);

      await HealthRationaleChannel.instance.drainPending();
      await settle(t);

      expect(find.byType(HealthPrivacyScreen), findsOneWidget);
      expect(calls.map((c) => c.method), ['consumePendingRationale']);
    });
  });

  testWidgets('no buffered intent means no screen', (t) async {
    await onPlatform(TargetPlatform.android, () async {
      await pumpHost(t);
      mockNative(null);

      await HealthRationaleChannel.instance.drainPending();
      await settle(t);

      expect(find.byType(HealthPrivacyScreen), findsNothing);
    });
  });

  testWidgets('a warm push while already open does not stack a second copy',
      (t) async {
    await onPlatform(TargetPlatform.android, () async {
      await pumpHost(t);
      mockNative(null);
      HealthRationaleChannel.instance.attach();

      // Health Connect can re-deliver the intent while the screen is up.
      for (var i = 0; i < 3; i++) {
        await pushFromNative();
        await settle(t);
      }

      expect(find.byType(HealthPrivacyScreen), findsOneWidget);
    });
  });

  testWidgets('closing it lets a later intent open it again', (t) async {
    await onPlatform(TargetPlatform.android, () async {
      await pumpHost(t);
      mockNative(kRationale);

      await HealthRationaleChannel.instance.drainPending();
      await settle(t);
      expect(find.byType(HealthPrivacyScreen), findsOneWidget);

      navigatorKey.currentState!.pop();
      await settle(t);
      expect(find.byType(HealthPrivacyScreen), findsNothing);

      // The guard must have been released by the pop, not latched forever.
      await HealthRationaleChannel.instance.drainPending();
      await settle(t);
      expect(find.byType(HealthPrivacyScreen), findsOneWidget);
    });
  });

  testWidgets('a push before the navigator exists is deferred, not dropped',
      (t) async {
    await onPlatform(TargetPlatform.android, () async {
      // No host pumped yet: navigatorKey.currentState is null, which is exactly
      // the cold-start race this service exists to survive.
      HealthRationaleChannel.instance.attach();
      await pushFromNative();

      await pumpHost(t);
      // Returns null, so only the deferred flag can produce the screen here.
      mockNative(null);

      await HealthRationaleChannel.instance.drainPending();
      await settle(t);

      expect(find.byType(HealthPrivacyScreen), findsOneWidget);
    });
  });

  testWidgets('a missing native side is survivable', (t) async {
    await onPlatform(TargetPlatform.android, () async {
      await pumpHost(t);
      // A null BINARY reply is how the framework signals "no implementation"
      // — it is what MethodChannel turns into MissingPluginException, and it
      // models a host that never registered the channel. Leaving the handler
      // unset instead would post to an engine that does not exist in
      // `flutter test`, and the reply would simply never arrive.
      messenger.setMockMessageHandler(
          HealthRationaleChannel.channel.name, (_) async => null);
      addTearDown(() => messenger.setMockMessageHandler(
          HealthRationaleChannel.channel.name, null));

      await expectLater(
          HealthRationaleChannel.instance.drainPending(), completes);
      await settle(t);
      expect(find.byType(HealthPrivacyScreen), findsNothing);
    });
  });

  testWidgets('non-Android hosts never touch the channel', (t) async {
    await onPlatform(TargetPlatform.iOS, () async {
      await pumpHost(t);
      final calls = mockNative(kRationale);

      await HealthRationaleChannel.instance.drainPending();
      await settle(t);

      expect(calls, isEmpty);
      expect(find.byType(HealthPrivacyScreen), findsNothing);
    });
  });
}

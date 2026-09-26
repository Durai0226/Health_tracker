import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/services/home_widget_service.dart';

/// Two pieces of "keep what the user sees current" work that had no caller on
/// the path that matters, and one missing stamp on the widget's data.
///
///  * `WaterService.refreshWeatherGoal()` was reachable only from a button on
///    the hydration profile screen. So "adjust for the weather" raised the
///    goal the once, and then never again — not at launch, not on the next
///    hot afternoon, not on the next day.
///  * `HomeWidgetService.pushSnapshot()` ran only when the steps or sleep
///    dashboard was opened. The widget stores no date of its own, so after
///    midnight — or after a day with the app unopened — it kept drawing
///    yesterday's step count as today's.
///
/// The push itself needs a platform channel and the shell wiring needs the
/// whole app, so the day stamp is asserted against a mocked channel and the
/// wiring is checked by reading the source, the way
/// `home_widget_wiring_test.dart` already does for the Kotlin side.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the widget snapshot says which day it describes', () {
    final saved = <String, Object?>{};
    const channel = MethodChannel('home_widget');

    setUp(() {
      saved.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'saveWidgetData') {
          final args = (call.arguments as Map).cast<String, Object?>();
          saved[args['id'] as String] = args['data'];
        }
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('pushSnapshot stamps the calendar day alongside the values', () async {
      await withClock(Clock.fixed(DateTime(2026, 1, 5, 7, 30)),
          HomeWidgetService.pushSnapshot);

      expect(saved.containsKey('steps'), isTrue,
          reason: 'sanity: the push must have run at all');
      expect(saved[HomeWidgetService.snapshotDayKey], '2026-01-05',
          reason: 'without a date the widget cannot tell that the steps it is '
              'holding belong to yesterday, so it draws them as today\'s');
    });

    test('the stamp follows the clock rather than being written once',
        () async {
      await withClock(Clock.fixed(DateTime(2026, 1, 5, 23, 59)),
          HomeWidgetService.pushSnapshot);
      expect(saved[HomeWidgetService.snapshotDayKey], '2026-01-05');

      await withClock(Clock.fixed(DateTime(2026, 1, 6, 0, 1)),
          HomeWidgetService.pushSnapshot);
      expect(saved[HomeWidgetService.snapshotDayKey], '2026-01-06');
    });
  });

  group('AppShell keeps the ambient data current', () {
    late String shell;

    setUpAll(() {
      shell = File('lib/features/home/screens/app_shell.dart')
          .readAsStringSync();
    });

    /// The body of one member, bounded by ITS OWN closing brace — never a fixed
    /// character count, which would silently stop covering the method as it
    /// grows.
    String body(String signature) {
      final start = shell.indexOf(signature);
      expect(start, greaterThan(-1),
          reason: '$signature is gone from app_shell.dart — this test needs '
              'rewriting, not deleting');
      final end = shell.indexOf('\n  }', start);
      expect(end, greaterThan(start));
      return shell.substring(start, end);
    }

    test('the refresh runs on cold start and on resume', () {
      // Cold start is the likelier of the two: an app opened for the first time
      // today is exactly when the goal and the widget are most stale.
      expect(body('void initState()'), contains('_refreshAmbientData()'));
      expect(body('void didChangeAppLifecycleState('),
          contains('_refreshAmbientData()'));
    });

    test('the refresh covers both the weather goal and the widget push', () {
      final refresh = body('void _refreshAmbientData()');
      expect(refresh, contains('WaterService.refreshWeatherGoal()'));
      expect(refresh, contains('HomeWidgetService.pushSnapshot()'));
      // Resume fires on every return from a permission dialog or the app
      // switcher; the push reads services and hits a platform channel.
      expect(refresh, contains('_widgetPushInterval'),
          reason: 'an undebounced push on every resume is a battery bug');
    });

    test('Undo removes the drink from the day it was filed under', () {
      final drain = body('Future<void> _drainQueuedWaterActions()');
      expect(drain, contains('removeWaterLogForDate('),
          reason: 'removeWaterLog() means TODAY, and a quick-add tapped at '
              '23:30 belongs to yesterday');
      expect(drain, isNot(contains('WaterActionQueue.defaultQuickAddMl')),
          reason: 'the toast must report the volumes actually applied, not '
              'count x 250');
    });
  });
}

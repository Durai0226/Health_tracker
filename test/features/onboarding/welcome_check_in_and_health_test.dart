/// First-run setup: the daily check-in time can be seen and changed, skipping
/// records "off", and — where there is a health app — it is offered, never forced.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/daily_check_in.dart';
import 'package:tablet_remainder/core/services/health_data_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/onboarding/screens/welcome_screen.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late RecordingNotificationScheduler scheduler;

  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    scheduler = RecordingNotificationScheduler();
    NotificationService().schedulerForTesting = scheduler;
  });

  tearDown(() async {
    NotificationService().permissionForTesting = null;
    await db.close();
  });

  Future<void> open(
    WidgetTester tester, {
    HealthAvailability availability = HealthAvailability.unavailable,
    Future<bool> Function()? connect,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(411, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: WelcomeScreen(
        healthAvailability: () async => availability,
        connectHealth: connect,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> toReminders(WidgetTester tester, {bool health = false}) async {
    await next(tester, 'Get started');
    await next(tester, 'Continue'); // what to start with
    await next(tester, 'Continue'); // the health pane, or the reminders
    if (health) await next(tester, 'Continue');
  }

  group('the check-in time', () {
    testWidgets('is on the reminders pane, 9:00 AM to begin with', (tester) async {
      await open(tester);
      await toReminders(tester);

      expect(find.text('Daily check-in at 9:00 AM'), findsOneWidget);
    });

    testWidgets('shows a time already recorded', (tester) async {
      await CleanStorageService.setAppPreference(DailyCheckIn.hourKey, 7);
      await CleanStorageService.setAppPreference(DailyCheckIn.minuteKey, 30);
      await open(tester);
      await toReminders(tester);

      expect(find.text('Daily check-in at 7:30 AM'), findsOneWidget);
    });

    testWidgets('tapping it opens the picker', (tester) async {
      await open(tester);
      await toReminders(tester);

      await tester.tap(find.text('Daily check-in at 9:00 AM'));
      await tester.pumpAndSettle();

      expect(find.text('Check-in time'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Daily check-in at 9:00 AM'), findsOneWidget,
          reason: 'cancelling keeps the time');
    });

    testWidgets('Turn on reminders arms the check-in and records it as on',
        (tester) async {
      await open(tester);
      await toReminders(tester);

      await tester.tap(find.text('Turn on reminders').last);
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      tester.takeException();

      expect(await DailyCheckIn.isEnabled(), isTrue);
      final a = scheduler.lastFor(DailyCheckIn.notificationId)!;
      expect([a.when.hour, a.when.minute], [9, 0]);
    });

    testWidgets('Turn on reminders with the permission declined arms nothing, and is recorded as off',
        (tester) async {
      // Scheduled anyway, it was recorded as on while nothing could ever appear —
      // and Settings then said "on" over a check-in the person had refused.
      NotificationService().permissionForTesting = () async => false;
      await open(tester);
      await toReminders(tester);

      await tester.tap(find.text('Turn on reminders').last);
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Continue as guest'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      tester.takeException();

      expect(scheduler.scheduled, isEmpty);
      expect(CleanStorageService.getAppPreference(DailyCheckIn.enabledKey, null), false);
      expect(await DailyCheckIn.isEnabled(), isFalse);
    });

    testWidgets('Skip for now records it as off, and arms nothing', (tester) async {
      await open(tester);
      await toReminders(tester);

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue as guest'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      tester.takeException();

      expect(CleanStorageService.getAppPreference(DailyCheckIn.enabledKey, null), false);
      expect(scheduler.scheduled, isEmpty);
    });
  });

  group('the health app pane, when the platform answers late', () {
    /// Open with an availability answer that arrives when the test says so.
    Future<Completer<HealthAvailability>> openLate(WidgetTester tester) async {
      final answer = Completer<HealthAvailability>();
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(411, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: WelcomeScreen(healthAvailability: () => answer.future),
      ));
      await tester.pumpAndSettle();
      return answer;
    }

    testWidgets('an answer while the person is still on the benefits adds the pane',
        (tester) async {
      final answer = await openLate(tester);
      await next(tester, 'Get started');

      answer.complete(HealthAvailability.available);
      await tester.pumpAndSettle();
      await next(tester, 'Continue'); // what to start with
      await next(tester, 'Continue');

      expect(find.text('Bring in your health data'), findsOneWidget);
    });

    testWidgets('an answer after they have reached the reminders does not move them',
        (tester) async {
      final answer = await openLate(tester);
      await next(tester, 'Get started');
      await next(tester, 'Continue'); // what to start with
      await next(tester, 'Continue');
      expect(find.text('Daily check-in at 9:00 AM'), findsOneWidget,
          reason: 'the premise: the reminders pane');

      answer.complete(HealthAvailability.available);
      await tester.pumpAndSettle();

      expect(find.text('Daily check-in at 9:00 AM'), findsOneWidget,
          reason: 'still the pane they were on');
      expect(find.text('Bring in your health data'), findsNothing);
    });

    testWidgets('an answer in the middle of the swipe to the reminders does not redirect it',
        (tester) async {
      // `onPageChanged` only reports a page once the pager is past its midpoint, so
      // the screen still thinks they are on the page before while they are on their
      // way to the reminders. Inserted then, the page they travel to is the health
      // pane instead.
      final answer = await openLate(tester);
      await next(tester, 'Get started');
      await next(tester, 'Continue'); // what to start with

      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60)); // under way, short of halfway
      answer.complete(HealthAvailability.available);
      await tester.pumpAndSettle();

      expect(find.text('Daily check-in at 9:00 AM'), findsOneWidget,
          reason: 'the pane they were heading for');
      expect(find.text('Bring in your health data'), findsNothing);
      expect(find.byType(AnimatedContainer), findsNWidgets(4), reason: 'no fifth pane');
    });

    testWidgets('and the dots still count four, not five', (tester) async {
      final answer = await openLate(tester);
      await next(tester, 'Get started');
      await next(tester, 'Continue'); // what to start with
      await next(tester, 'Continue');

      answer.complete(HealthAvailability.available);
      await tester.pumpAndSettle();

      // Four indicator dots: the screen was not given a fifth pane.
      expect(find.byType(AnimatedContainer), findsNWidgets(4));
    });
  });

  group('the health app pane', () {
    testWidgets('is not there when there is no health app to connect',
        (tester) async {
      await open(tester, availability: HealthAvailability.unavailable);
      await next(tester, 'Get started');
      await next(tester, 'Continue'); // what to start with
      await next(tester, 'Continue');

      expect(find.text('Bring in your health data'), findsNothing);
      expect(find.text('Turn on reminders'), findsWidgets,
          reason: 'the third Continue lands on reminders, as before');
    });

    testWidgets('nor when Health Connect needs installing or updating', (tester) async {
      await open(tester, availability: HealthAvailability.needsProviderUpdate);
      await next(tester, 'Get started');
      await next(tester, 'Continue'); // what to start with
      await next(tester, 'Continue');

      expect(find.text('Bring in your health data'), findsNothing);
    });

    testWidgets('is there when it can be asked, between the benefits and the reminders',
        (tester) async {
      await open(tester, availability: HealthAvailability.notDetermined);
      await next(tester, 'Get started');
      await next(tester, 'Continue'); // what to start with
      await next(tester, 'Continue');

      expect(find.text('Bring in your health data'), findsOneWidget);
      expect(find.text('Connect Health Connect'), findsOneWidget);
      expect(find.text('Optional — you can skip this and connect later from Today.'),
          findsOneWidget);

      await next(tester, 'Continue');
      expect(find.text('Turn on reminders'), findsWidgets);
    });

    testWidgets('promises only what Connect asks for: steps and sleep, not heart rate',
        (tester) async {
      // Connect requests steps and sleep (with distance and active calories). Heart
      // rate is a separate grant asked for where it is shown; promising it here sent
      // people to Today expecting a number that never came.
      await open(tester, availability: HealthAvailability.notDetermined);
      await next(tester, 'Get started');
      await next(tester, 'Continue'); // what to start with
      await next(tester, 'Continue');

      expect(find.textContaining('steps and sleep'), findsOneWidget);
      expect(find.textContaining('heart rate'), findsNothing);
    });

    testWidgets('connecting asks once and says Connected', (tester) async {
      var asked = 0;
      await open(tester,
          availability: HealthAvailability.notDetermined,
          connect: () async {
            asked++;
            return true;
          });
      await toReminders(tester);
      // `toReminders` without health stops on the health pane here.
      expect(find.text('Bring in your health data'), findsOneWidget);

      await tester.tap(find.text('Connect Health Connect'));
      await tester.pumpAndSettle();

      expect(asked, 1);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Connect Health Connect'), findsNothing);
    });

    testWidgets('declined: says so, offers to try again, and does not block',
        (tester) async {
      await open(tester,
          availability: HealthAvailability.notDetermined, connect: () async => false);
      await toReminders(tester);

      await tester.tap(find.text('Connect Health Connect'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Not connected. You can try again from Today'),
          findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await next(tester, 'Continue');
      expect(find.text('Turn on reminders'), findsWidgets);
    });

    testWidgets('already connected: it says so without asking again', (tester) async {
      var asked = 0;
      await open(tester,
          availability: HealthAvailability.available,
          connect: () async {
            asked++;
            return true;
          });
      await toReminders(tester);

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Connect Health Connect'), findsNothing);
      expect(asked, 0);
    });

    testWidgets('a platform failure is a decline, not a crash', (tester) async {
      await open(tester,
          availability: HealthAvailability.notDetermined,
          connect: () async => throw StateError('no provider'));
      await toReminders(tester);

      await tester.tap(find.text('Connect Health Connect'));
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('on an iPhone, where read access is never disclosed to an app', () {
    /// Resets the platform override INSIDE the test body: the framework checks it
    /// is unset before any tearDown runs.
    void onIPhone(String name, Future<void> Function(WidgetTester) body) {
      testWidgets(name, (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          await body(tester);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    onIPhone('getting through the sheet says Asked, not Connected', (tester) async {
      await open(tester,
          availability: HealthAvailability.notDetermined,
          connect: () async => true);
      await toReminders(tester);

      await tester.tap(find.text('Connect Health Connect'));
      await tester.pumpAndSettle();

      expect(find.text('Asked'), findsOneWidget);
      expect(find.text('Connected'), findsNothing,
          reason: 'nobody can check it: iPhone does not say what was allowed');
    });

    onIPhone('and says where to look if the numbers do not appear', (tester) async {
      await open(tester,
          availability: HealthAvailability.notDetermined,
          connect: () async => true);
      await toReminders(tester);

      await tester.tap(find.text('Connect Health Connect'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Apple Health keeps your choices private'),
          findsOneWidget);
      expect(find.textContaining('Health → Sharing → Apps → DlyMinder'),
          findsOneWidget);
      expect(find.textContaining('Optional — you can skip this'), findsNothing,
          reason: 'the explanation takes that line\'s place');
    });

    onIPhone('a decline still says Not connected, which is true', (tester) async {
      await open(tester,
          availability: HealthAvailability.notDetermined,
          connect: () async => false);
      await toReminders(tester);

      await tester.tap(find.text('Connect Health Connect'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Not connected. You can try again from Today'),
          findsOneWidget);
      expect(find.text('Asked'), findsNothing);
    });

    testWidgets('Android is unchanged: Connected, and no iPhone explanation',
        (tester) async {
      await open(tester,
          availability: HealthAvailability.notDetermined,
          connect: () async => true);
      await toReminders(tester);

      await tester.tap(find.text('Connect Health Connect'));
      await tester.pumpAndSettle();

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Asked'), findsNothing);
      expect(find.textContaining('Apple Health keeps your choices'), findsNothing);
    });
  });
}

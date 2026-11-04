/// The Focus screen's side of "Your usual round around now": the card, what its
/// buttons do, and the switch that turns it off.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/audio_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/notification_service.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart'
    show AppSwitch, ProactiveNudgeBanner;
import 'package:tablet_remainder/core/widgets/toast/toast_overlay.dart';
import 'package:tablet_remainder/features/focus/models/ambient_sound.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/services/coins_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/focus_session_alarm.dart';
import 'package:tablet_remainder/features/focus/services/stats_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';

import '../../support/fake_audio_engine.dart';
import '../../support/recording_notification_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  final focus = FocusService();
  final now = DateTime(2026, 3, 14, 9, 30);

  const title = 'Your usual round around now';

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.loadAppPreferences();
    AudioService().engineForTesting = FakeAudioEngine();
    NotificationService().schedulerForTesting = RecordingNotificationScheduler();
    focus.alarmForTesting = RecordingFocusSessionAlarm();
    focus.resetForTesting();
    CoinsService().resetForTesting();
    TagService().resetForTesting();
    StatsService().resetForTesting();
    ToastOverlay.instance.resetForTesting();
    await focus.init();
  });

  tearDown(() async {
    ToastOverlay.instance.resetForTesting();
    focus.resetForTesting();
    StatsService().resetForTesting();
    await db.close();
  });

  void quietOverflow() {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(seconds: 10));
  }

  var counter = 0;

  /// [days] mornings of studying for 45 minutes with rain.
  Future<void> seedRoutine(int days) async {
    await focus.importSessionsJson([
      for (var d = 1; d <= days; d++)
        () {
          counter++;
          final start = DateTime(2026, 3, 14 - d, 9);
          return FocusSession(
            id: 'habit-ui-$counter',
            startedAt: start,
            completedAt: start.add(const Duration(minutes: 45)),
            targetMinutes: 45,
            actualMinutes: 45,
            wasCompleted: true,
            activityType: FocusActivityType.study,
            plantType: PlantType.seedling,
            soundUsed: AmbientSoundType.rain,
          ).toJson();
        }(),
    ]);
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: FocusScreen()));
    await pump(tester);
  }

  void screenTest(
    String description,
    Future<void> Function(WidgetTester tester) body, {
    int days = 5,
  }) {
    testWidgets(description, (tester) async {
      quietOverflow();
      await withClock(Clock.fixed(now), () async {
        await seedRoutine(days);
        await open(tester);
        try {
          await body(tester);
        } finally {
          if (focus.isRunning) await focus.abandonSession();
          await settle(tester);
        }
      });
    });
  }

  /// The "Why this?" on the habit's own card: five finished rounds also earn the
  /// Focus screen an insight of its own, with one of its own.
  Finder whyOnCard() => find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(ProactiveNudgeBanner)),
        matching: find.text('Why this?'),
      );

  group('the card', () {
    screenTest('a routine at this hour shows it, with what it would set', (tester) async {
      expect(find.text(title), findsOneWidget);
      expect(find.textContaining('Study for 45 minutes, with Rain'), findsOneWidget);
      expect(find.text('Use this'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(whyOnCard(), findsOneWidget);
    });

    screenTest('"Why this?" shows the working, and that nothing changes until Use this',
        (tester) async {
      await tester.ensureVisible(whyOnCard());
      await tester.pump();
      await tester.tap(whyOnCard());
      await settle(tester);

      expect(find.textContaining('5 were Study, on 5 different days'), findsOneWidget);
      expect(find.textContaining('Nothing is changed until you tap Use this'),
          findsOneWidget);
    });

    screenTest('three mornings is not a routine', (tester) async {
      expect(find.text(title), findsNothing);
    }, days: 3);

    screenTest('not when the setup already is that', (tester) async {
      focus.setActivity(FocusActivityType.study);
      focus.setDuration(45);
      focus.setSound(AmbientSoundType.rain);
      await pump(tester);

      expect(find.text(title), findsNothing);
    });

    screenTest('not while a round is running', (tester) async {
      await focus.startSession();
      await pump(tester);

      expect(find.text(title), findsNothing);
    });
  });

  group('Use this', () {
    screenTest('sets the activity, the length and the sound, and says so', (tester) async {
      await tester.ensureVisible(find.text('Use this'));
      await tester.pump();
      await tester.tap(find.text('Use this'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(focus.selectedActivity, FocusActivityType.study);
      expect(focus.selectedMinutes, 45);
      expect(focus.selectedSound, AmbientSoundType.rain);
      expect(find.text(title), findsNothing);
      expect(find.text('Round set'), findsOneWidget);
      expect(find.text('Study for 45 minutes, with Rain.'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    // The card is drawn at one moment and tapped at another. The hour can move on in
    // between, and the service reads the habit again at the tap.
    screenTest('a card tapped after its suggestion has gone says it is out of date, and changes nothing',
        (tester) async {
      await tester.ensureVisible(find.text('Use this'));
      await tester.pump();

      // Hours later the routine no longer fits "now".
      await withClock(Clock.fixed(now.add(const Duration(hours: 5))), () async {
        await tester.tap(find.text('Use this'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      });

      expect(find.text('That suggestion is out of date now.'), findsOneWidget);
      expect(focus.selectedActivity, isNot(FocusActivityType.study),
          reason: 'nothing was applied');
      expect(find.text('Round set'), findsNothing);
      expect(find.text(title), findsNothing,
          reason: 'and the card that offered it is gone, not left to repeat itself');
    });

    screenTest('a card tapped after a DIFFERENT habit has taken its place says what was set, not what it showed',
        (tester) async {
      // An afternoon routine too: coding for 30 minutes, with no sound.
      await focus.importSessionsJson([
        for (var d = 1; d <= 5; d++)
          () {
            counter++;
            final start = DateTime(2026, 3, 14 - d, 14);
            return FocusSession(
              id: 'habit-ui-pm-$counter',
              startedAt: start,
              completedAt: start.add(const Duration(minutes: 30)),
              targetMinutes: 30,
              actualMinutes: 30,
              wasCompleted: true,
              activityType: FocusActivityType.coding,
              plantType: PlantType.seedling,
            ).toJson();
          }(),
      ]);
      await tester.ensureVisible(find.text('Use this'));
      await tester.pump();
      expect(find.textContaining('Study for 45 minutes, with Rain'), findsOneWidget,
          reason: 'the premise: the card shows the morning habit');

      await withClock(Clock.fixed(DateTime(2026, 3, 14, 14, 30)), () async {
        await tester.tap(find.text('Use this'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      });

      expect(focus.selectedActivity, FocusActivityType.coding);
      expect(focus.selectedMinutes, 30);
      expect(find.text('Coding for 30 minutes.'), findsOneWidget,
          reason: 'what it SET');
      expect(find.text('Study for 45 minutes, with Rain.'), findsNothing,
          reason: 'not what the card was showing');
    });

    screenTest('Undo puts the old setup back, and the card returns', (tester) async {
      focus.setActivity(FocusActivityType.coding);
      focus.setDuration(50);
      await pump(tester);
      await tester.ensureVisible(find.text('Use this'));
      await tester.pump();
      await tester.tap(find.text('Use this'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(focus.selectedActivity, FocusActivityType.study);

      await tester.tap(find.text('Undo'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(focus.selectedActivity, FocusActivityType.coding);
      expect(focus.selectedMinutes, 50);
      expect(focus.selectedSound, AmbientSoundType.none);
      expect(find.text(title), findsOneWidget);
    });
  });

  group('Dismiss', () {
    screenTest('puts it away, changing nothing, and it stays away on the next visit',
        (tester) async {
      await tester.ensureVisible(find.text('Dismiss'));
      await tester.pump();
      await tester.tap(find.text('Dismiss'));
      await pump(tester);

      expect(find.text(title), findsNothing);
      expect(focus.selectedActivity, FocusActivityType.work, reason: 'it changes nothing');

      await tester.pumpWidget(const SizedBox());
      await open(tester);
      expect(find.text(title), findsNothing);
    });
  });

  group('the switch in Session setup', () {
    Future<void> openSetup(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Session setup'));
      await tester.pump();
      await tester.tap(find.text('Session setup'));
      await pump(tester);
      await tester.ensureVisible(find.text('Suggest my usual setup'));
      await tester.pump();
    }

    screenTest('is on, and says what it offers and that nothing changes unasked',
        (tester) async {
      await openSetup(tester);

      expect(tester.widget<AppSwitch>(find.byType(AppSwitch).at(3)).value, isTrue,
          reason: 'fourth switch in the sheet: breaths, step away, break, this');
      expect(find.textContaining('Offers what you usually do at this time of day'),
          findsOneWidget);
      expect(find.textContaining('Nothing changes until you tap Use this'),
          findsOneWidget);
    });

    screenTest('off, the card is gone', (tester) async {
      await openSetup(tester);

      await tester.tap(find.text('Suggest my usual setup'));
      await pump(tester);

      expect(focus.habitOffers, isFalse);
      expect(tester.widget<AppSwitch>(find.byType(AppSwitch).at(3)).value, isFalse);
      await tester.tapAt(const Offset(10, 10));
      await pump(tester);
      expect(find.text(title), findsNothing);
    });
  });
}

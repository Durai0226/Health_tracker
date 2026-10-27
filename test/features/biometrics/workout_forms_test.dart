/// The two sheets behind a workout you entered by hand: the form that takes it,
/// and the detail that shows it.
///
/// Driven without a route, so a test is about what the form does with what is
/// typed — not about how a sheet slides up.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/biometrics/models/biometric_metric.dart';
import 'package:tablet_remainder/features/biometrics/models/workout_session.dart';
import 'package:tablet_remainder/features/biometrics/widgets/workout_detail_sheet.dart';
import 'package:tablet_remainder/features/biometrics/widgets/workout_log_sheet.dart';

import '../../support/font_free_theme.dart';

void main() {
  final now = DateTime(2026, 6, 20, 12);

  /// A saved session, entered by hand unless [id] says otherwise.
  WorkoutSession session({
    String id = 'wm_1781852400000_RUNNING',
    String type = 'RUNNING',
    DateTime? startedAt,
    int minutes = 40,
    int? kcal,
    double? meters,
    int? steps,
    int? avgHr,
    int? maxHr,
    String? note,
    BiometricSource source = BiometricSource.manual,
  }) {
    final start = startedAt ?? DateTime(2026, 6, 19, 7, 30);
    return WorkoutSession(
      id: id,
      dateKey: '2026-06-19',
      startedAt: start,
      endedAt: start.add(Duration(minutes: minutes)),
      durationMinutes: minutes,
      activityType: type,
      energyKcal: kcal,
      distanceMeters: meters,
      steps: steps,
      avgHr: avgHr,
      maxHr: maxHr,
      note: note,
      source: source,
      createdAt: start,
      updatedAt: start,
    );
  }

  /// Overflow is the one error these tests do not want to hear: under the Ahem
  /// test font every glyph is a square, so a wrapped label at the default size
  /// is not the fault the fit tests below look for.
  void quietOverflow() {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
  }

  Future<void> pumpBody(
    WidgetTester tester,
    Widget body, {
    double width = 430,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 1800);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: fontFreeTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: body,
        ),
      ),
    ));
    await tester.pump();
  }

  group('the log form', () {
    final saved = <WorkoutLogResult>[];
    setUp(saved.clear);

    Future<void> pumpForm(WidgetTester tester,
            {WorkoutSession? existing, double width = 430, double scale = 1}) =>
        pumpBody(tester, WorkoutLogForm(existing: existing, onSave: saved.add),
            width: width, scale: scale);

    Finder field(String label) => find.descendant(
        of: find.byWidgetPredicate((w) => w is AppTextField && w.label == label),
        matching: find.byType(TextField));

    String textIn(WidgetTester tester, String label) =>
        tester.widget<TextField>(field(label)).controller!.text;

    Future<void> type(WidgetTester tester, String label, String text) async {
      await tester.enterText(field(label), text);
      await tester.pump();
    }

    Future<void> save(WidgetTester tester, {String label = 'Save workout'}) async {
      await tester.ensureVisible(find.text(label));
      await tester.pump();
      await tester.tap(find.text(label));
      await tester.pump();
    }

    bool chipSelected(WidgetTester tester, String label) =>
        tester.widget<AppChip>(find.widgetWithText(AppChip, label)).selected;

    testWidgets('a new one offers the kinds, and starts on the first', (tester) async {
      quietOverflow();
      await withClock(Clock.fixed(now), () async {
        await pumpForm(tester);
        for (final kind in [
          'Walking', 'Running', 'Biking', 'Swimming',
          'Strength training', 'Yoga', 'Hiking', 'Other',
        ]) {
          expect(find.widgetWithText(AppChip, kind), findsOneWidget, reason: kind);
        }
        expect(chipSelected(tester, 'Walking'), isTrue);
        expect(chipSelected(tester, 'Running'), isFalse);
        expect(find.text('Save workout'), findsOneWidget);
        expect(textIn(tester, 'Minutes'), isEmpty,
            reason: 'no length is assumed: a guess saved unread is a wrong record');
      });
    });

    testWidgets('what is typed comes back as it was meant', (tester) async {
      quietOverflow();
      await withClock(Clock.fixed(now), () async {
        await pumpForm(tester);
        await tester.tap(find.widgetWithText(AppChip, 'Running'));
        await tester.pump();
        expect(chipSelected(tester, 'Running'), isTrue);
        expect(chipSelected(tester, 'Walking'), isFalse, reason: 'one kind at a time');

        await type(tester, 'Minutes', '40');
        await type(tester, 'Calories (optional)', '380');
        await type(tester, 'Distance (optional)', '5,5');
        await type(tester, 'Note (optional)', '  park loop  ');
        await save(tester);

        final r = saved.single;
        expect(r.activityType, 'RUNNING');
        expect(r.durationMinutes, 40);
        expect(r.kcal, 380);
        expect(r.distanceKm, 5.5, reason: 'a comma is a decimal point to many keyboards');
        expect(r.note, 'park loop');
        expect(r.startedAt, now.subtract(const Duration(hours: 1)),
            reason: 'logging is for what is over: an hour ago, not now');
      });
    });

    testWidgets('calories, distance and a note may be left blank', (tester) async {
      quietOverflow();
      await withClock(Clock.fixed(now), () async {
        await pumpForm(tester);
        await type(tester, 'Minutes', '30');
        await type(tester, 'Note (optional)', '   ');
        await save(tester);

        final r = saved.single;
        expect(r.kcal, isNull);
        expect(r.distanceKm, isNull, reason: 'blank is not 0 km');
        expect(r.note, isNull);
      });
    });

    group('refuses, and says why', () {
      Future<void> refused(WidgetTester tester, String why) async {
        expect(find.text(why), findsOneWidget);
        expect(saved, isEmpty, reason: 'nothing is saved while an error is showing');
      }

      testWidgets('no length', (tester) async {
        quietOverflow();
        await withClock(Clock.fixed(now), () async {
          await pumpForm(tester);
          await save(tester);
          await refused(tester, 'How long did it last? At least a minute.');
        });
      });

      testWidgets('a length that is not a number counts as none', (tester) async {
        quietOverflow();
        await withClock(Clock.fixed(now), () async {
          await pumpForm(tester);
          await type(tester, 'Minutes', 'an hour');
          await save(tester);
          await refused(tester, 'How long did it last? At least a minute.');
        });
      });

      testWidgets('more than a day', (tester) async {
        quietOverflow();
        await withClock(Clock.fixed(now), () async {
          await pumpForm(tester);
          await type(tester, 'Minutes', '1441');
          await save(tester);
          await refused(tester, 'That is more than a day. Check the length.');
        });
      });

      testWidgets('calories that are not a whole number are an error, not "left blank"',
          (tester) async {
        quietOverflow();
        await withClock(Clock.fixed(now), () async {
          await pumpForm(tester);
          await type(tester, 'Minutes', '30');
          await type(tester, 'Calories (optional)', '380.5');
          await save(tester);
          await refused(tester, 'Calories should be a whole number.');
        });
      });

      testWidgets('a distance that is not a number is an error too', (tester) async {
        quietOverflow();
        await withClock(Clock.fixed(now), () async {
          await pumpForm(tester);
          await type(tester, 'Minutes', '30');
          await type(tester, 'Distance (optional)', 'five');
          await save(tester);
          await refused(tester, 'Distance should be a number of kilometres.');
        });
      });

      testWidgets('calories and distance beyond what a person could do', (tester) async {
        quietOverflow();
        await withClock(Clock.fixed(now), () async {
          await pumpForm(tester);
          await type(tester, 'Minutes', '30');
          await type(tester, 'Calories (optional)', '25000');
          await save(tester);
          await refused(tester, 'Calories should be between 0 and 20000.');

          await type(tester, 'Calories (optional)', '');
          await type(tester, 'Distance (optional)', '1500');
          await save(tester);
          await refused(tester, 'Distance should be between 0 and 1000 km.');
        });
      });

      testWidgets('a start that has not happened yet', (tester) async {
        quietOverflow();
        await withClock(Clock.fixed(now), () async {
          // Editing one whose start sits in the future: the same check the
          // date picker would otherwise be the only guard for.
          await pumpForm(tester,
              existing: session(startedAt: now.add(const Duration(hours: 3))));
          await save(tester, label: 'Save changes');
          await refused(tester, 'That start time has not happened yet.');
        });
      });

      testWidgets('and fixing the figure it was about clears it, in any field',
          (tester) async {
        quietOverflow();
        await withClock(Clock.fixed(now), () async {
          await pumpForm(tester);
          await type(tester, 'Minutes', '30');

          await type(tester, 'Calories (optional)', 'lots');
          await save(tester);
          expect(find.text('Calories should be a whole number.'), findsOneWidget);
          await type(tester, 'Calories (optional)', '300');
          expect(find.text('Calories should be a whole number.'), findsNothing,
              reason: 'the figure it complained about has changed');

          await type(tester, 'Distance (optional)', 'far');
          await save(tester);
          expect(find.text('Distance should be a number of kilometres.'), findsOneWidget);
          await type(tester, 'Distance (optional)', '4');
          expect(find.text('Distance should be a number of kilometres.'), findsNothing);

          await save(tester);
          expect(saved.single.kcal, 300);
          expect(saved.single.distanceKm, 4);
        });
      });

      testWidgets('and moving the start clears it, and is what gets saved', (tester) async {
        quietOverflow();
        await withClock(Clock.fixed(now), () async {
          await pumpForm(tester,
              existing: session(startedAt: now.add(const Duration(hours: 3))));
          await save(tester, label: 'Save changes');
          expect(find.text('That start time has not happened yet.'), findsOneWidget);

          // What the date and time pickers hand back, without driving the two
          // sheets: the form's wiring is what is under test.
          final moved = DateTime(2026, 6, 19, 18, 15);
          tester.widget<AppDateTimeField>(find.byType(AppDateTimeField)).onChanged(moved);
          await tester.pump();
          expect(find.text('That start time has not happened yet.'), findsNothing);

          await save(tester, label: 'Save changes');
          expect(saved.single.startedAt, moved);
        });
      });

      testWidgets('and picking another kind clears it', (tester) async {
        quietOverflow();
        await withClock(Clock.fixed(now), () async {
          await pumpForm(tester);
          await save(tester);
          expect(find.text('How long did it last? At least a minute.'), findsOneWidget);
          await tester.tap(find.widgetWithText(AppChip, 'Yoga'));
          await tester.pump();
          expect(find.text('How long did it last? At least a minute.'), findsNothing);
        });
      });

      testWidgets('and typing again clears the message', (tester) async {
        quietOverflow();
        await withClock(Clock.fixed(now), () async {
          await pumpForm(tester);
          await save(tester);
          expect(find.text('How long did it last? At least a minute.'), findsOneWidget);

          await type(tester, 'Minutes', '3');
          expect(find.text('How long did it last? At least a minute.'), findsNothing,
              reason: 'a message about a field that has since changed is stale');

          await save(tester);
          expect(find.text('How long did it last? At least a minute.'), findsNothing);
          expect(saved.single.durationMinutes, 3);
        });
      });
    });

    group('editing one', () {
      testWidgets('opens on what was entered, and says it is saving changes',
          (tester) async {
        quietOverflow();
        await withClock(Clock.fixed(now), () async {
          await pumpForm(
              tester,
              existing: session(
                  type: 'YOGA', minutes: 45, kcal: 210, meters: 5500, note: 'studio'));
          expect(chipSelected(tester, 'Yoga'), isTrue);
          expect(chipSelected(tester, 'Walking'), isFalse);
          expect(textIn(tester, 'Minutes'), '45');
          expect(textIn(tester, 'Calories (optional)'), '210');
          expect(textIn(tester, 'Distance (optional)'), '5.5');
          expect(textIn(tester, 'Note (optional)'), 'studio');
          expect(find.text('Save changes'), findsOneWidget);
          expect(find.text('Save workout'), findsNothing);
        });
      });

      testWidgets('a distance is shown the way it would be typed', (tester) async {
        quietOverflow();
        await withClock(Clock.fixed(now), () async {
          for (final (meters, shown) in [
            (5000.0, '5'),
            (5250.0, '5.25'),
            (5500.0, '5.5'),
            (10000.0, '10'),
            (800.0, '0.8'),
          ]) {
            // A fresh form each time: the same widget in the same place would
            // keep the first one's controllers.
            await tester.pumpWidget(const SizedBox.shrink());
            await pumpForm(tester, existing: session(meters: meters));
            expect(textIn(tester, 'Distance (optional)'), shown, reason: '$meters m');
          }
        });
      });

      testWidgets('with nothing changed, hands back the same workout', (tester) async {
        quietOverflow();
        await withClock(Clock.fixed(now), () async {
          final before = session(
              type: 'SWIMMING', minutes: 30, kcal: 250, meters: 1500, note: 'lane 3');
          await pumpForm(tester, existing: before);
          await save(tester, label: 'Save changes');

          final r = saved.single;
          expect(r.activityType, 'SWIMMING');
          expect(r.startedAt, before.startedAt, reason: 'its time is kept, not reset to now');
          expect(r.durationMinutes, 30);
          expect(r.kcal, 250);
          expect(r.distanceKm, 1.5);
          expect(r.note, 'lane 3');
        });
      });

      testWidgets('a figure taken out is gone, not kept', (tester) async {
        quietOverflow();
        await withClock(Clock.fixed(now), () async {
          await pumpForm(tester, existing: session(kcal: 250, meters: 1500, note: 'x'));
          await type(tester, 'Calories (optional)', '');
          await type(tester, 'Distance (optional)', '');
          await type(tester, 'Note (optional)', '');
          await save(tester, label: 'Save changes');

          final r = saved.single;
          expect(r.kcal, isNull);
          expect(r.distanceKm, isNull);
          expect(r.note, isNull);
        });
      });
    });

    for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0)]) {
      testWidgets('fits $width wide at ${scale}x text', (tester) async {
        final errors = <FlutterErrorDetails>[];
        final prev = FlutterError.onError;
        FlutterError.onError = errors.add;
        try {
          await withClock(Clock.fixed(now), () async {
            await pumpForm(tester, width: width, scale: scale);
            await type(tester, 'Minutes', '0');
            await save(tester);
          });
        } finally {
          FlutterError.onError = prev;
        }
        expect(errors.where((e) => '${e.exception}'.contains('overflowed')), isEmpty,
            reason: 'with the error line showing as well');
      });
    }
  });

  group('the detail', () {
    final actions = <WorkoutDetailAction>[];
    var closed = 0;
    setUp(() {
      actions.clear();
      closed = 0;
    });

    Future<void> pumpDetail(WidgetTester tester, WorkoutSession w,
            {double width = 430, double scale = 1}) =>
        pumpBody(
            tester,
            WorkoutDetailBody(
                workout: w, onAction: actions.add, onClose: () => closed++),
            width: width,
            scale: scale);

    testWidgets('one you entered says so, and can be edited or deleted', (tester) async {
      quietOverflow();
      await pumpDetail(tester, session(minutes: 40, kcal: 380, meters: 5500, note: 'park loop'));

      expect(find.text('Added by you'), findsOneWidget);
      expect(find.textContaining('came from your health app'), findsNothing);
      expect(find.text('Close'), findsNothing);

      await tester.tap(find.text('Edit'));
      await tester.tap(find.text('Delete'));
      expect(actions, [WorkoutDetailAction.edit, WorkoutDetailAction.delete]);
    });

    testWidgets('one a watch wrote is read-only, and says where to change it',
        (tester) async {
      quietOverflow();
      await pumpDetail(
          tester,
          session(
              id: 'hw_1781852400000_RUNNING',
              source: BiometricSource.healthConnect,
              avgHr: 142,
              maxHr: 171));

      expect(find.text('From Health Connect'), findsOneWidget);
      expect(find.text('Edit'), findsNothing,
          reason: 'a device\'s session is the device\'s to correct');
      expect(find.text('Delete'), findsNothing);
      expect(find.textContaining('came from your health app'), findsOneWidget);

      await tester.tap(find.text('Close'));
      expect(closed, 1);
      expect(actions, isEmpty);
    });

    testWidgets('an Apple Health session names Apple Health', (tester) async {
      quietOverflow();
      await pumpDetail(tester,
          session(id: 'hw_1_WALKING', source: BiometricSource.healthKit));
      expect(find.text('From Apple Health'), findsOneWidget);
    });

    testWidgets('the id, not the source field, decides what is yours', (tester) async {
      quietOverflow();
      // An entered session is `manual` today, but "yours" must not depend on a
      // field a later import could set: the `wm_` id is what a sync never writes.
      await pumpDetail(tester,
          session(id: 'wm_5_YOGA', source: BiometricSource.healthConnect));
      expect(find.text('Added by you'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('shows only what the session has', (tester) async {
      quietOverflow();
      await pumpDetail(tester, session());
      expect(find.text('When'), findsOneWidget);
      expect(find.text('Length'), findsOneWidget);
      expect(find.text('Energy'), findsNothing, reason: 'not "0 kcal"');
      expect(find.text('Distance'), findsNothing, reason: 'not "0 km"');
      expect(find.text('Steps'), findsNothing);
      expect(find.text('Heart rate'), findsNothing);

      await pumpDetail(
          tester,
          session(
              kcal: 380, meters: 5500, steps: 6200, avgHr: 142, maxHr: 171,
              note: 'park loop'));
      expect(find.text('380 kcal'), findsOneWidget);
      expect(find.text('5.50 km'), findsOneWidget);
      expect(find.text('6200'), findsOneWidget);
      expect(find.text('average 142 · highest 171 bpm'), findsOneWidget);
      expect(find.text('park loop'), findsOneWidget);
    });

    testWidgets('an average with no maximum is still an average', (tester) async {
      quietOverflow();
      await pumpDetail(tester, session(avgHr: 118));
      expect(find.text('average 118 bpm'), findsOneWidget);
    });

    testWidgets('says when it started and how long it lasted', (tester) async {
      quietOverflow();
      await pumpDetail(tester, session(minutes: 95));
      expect(find.text('1 h 35 min'), findsOneWidget);
      expect(find.textContaining('7:30'), findsOneWidget);
    });

    test('lengths read as an hour or a few minutes', () {
      expect(WorkoutDetailBody.duration(45), '45 min');
      expect(WorkoutDetailBody.duration(60), '1 h');
      expect(WorkoutDetailBody.duration(90), '1 h 30 min');
      expect(WorkoutDetailBody.duration(1), '1 min');
    });

    test('distances read to two places, one past ten kilometres', () {
      expect(WorkoutDetailBody.distance(5000), '5.00 km');
      expect(WorkoutDetailBody.distance(800), '0.80 km');
      expect(WorkoutDetailBody.distance(12345), '12.3 km');
    });

    for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0)]) {
      testWidgets('fits $width wide at ${scale}x text', (tester) async {
        final errors = <FlutterErrorDetails>[];
        final prev = FlutterError.onError;
        FlutterError.onError = errors.add;
        try {
          await pumpDetail(
              tester,
              session(
                  kcal: 380, meters: 5500, steps: 6200, avgHr: 142, maxHr: 171,
                  note: 'a longer note about how the whole thing went'),
              width: width,
              scale: scale);
        } finally {
          FlutterError.onError = prev;
        }
        expect(errors.where((e) => '${e.exception}'.contains('overflowed')), isEmpty);
      });
    }
  });
}

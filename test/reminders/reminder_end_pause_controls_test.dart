import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/design/app_design.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/vacation_mode.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/reminders/widgets/reminder_end_pause_controls.dart';
import 'package:tablet_remainder/features/reminders/widgets/vacation_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  AccentSwatch accent(WidgetTester tester) =>
      AppColorsExt.light.reminders;

  final first = DateTime(2026, 3, 10);

  group('ReminderEndsControl', () {
    testWidgets('a reminder with no end reads "Never"', (tester) async {
      await tester.pumpWidget(host(ReminderEndsControl(
        endsAt: null,
        limit: null,
        firstDate: first,
        accent: accent(tester),
        onChanged: (_, __) {},
      )));
      expect(find.text('Never'), findsOneWidget);
      expect(find.textContaining('Last on'), findsNothing);
      expect(find.textContaining('Stops after'), findsNothing);
    });

    testWidgets('choosing "On a date" sets an end and clears the count',
        (tester) async {
      DateTime? gotEnd;
      int? gotLimit = -1;
      await tester.pumpWidget(host(ReminderEndsControl(
        endsAt: null,
        limit: 5,
        firstDate: first,
        accent: accent(tester),
        onChanged: (e, l) {
          gotEnd = e;
          gotLimit = l;
        },
      )));
      await tester.tap(find.text('After a number').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('On a date').last);
      await tester.pumpAndSettle();

      expect(gotEnd, isNotNull);
      expect(gotEnd!.isAfter(first), isTrue,
          reason: 'a default end must not precede the first reminder');
      expect(gotEnd!.hour, 23, reason: 'the whole last day counts');
      expect(gotLimit, isNull, reason: 'one mode at a time');
    });

    testWidgets('choosing "After a number" starts at 10 and clears the date',
        (tester) async {
      DateTime? gotEnd = DateTime(2000);
      int? gotLimit;
      await tester.pumpWidget(host(ReminderEndsControl(
        endsAt: DateTime(2026, 4, 1),
        limit: null,
        firstDate: first,
        accent: accent(tester),
        onChanged: (e, l) {
          gotEnd = e;
          gotLimit = l;
        },
      )));
      await tester.tap(find.text('On a date').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('After a number').last);
      await tester.pumpAndSettle();

      expect(gotLimit, ReminderEndsControl.defaultCount);
      expect(gotEnd, isNull);
    });

    testWidgets('"Never" clears both', (tester) async {
      DateTime? gotEnd = DateTime(2000);
      int? gotLimit = -1;
      await tester.pumpWidget(host(ReminderEndsControl(
        endsAt: DateTime(2026, 4, 1),
        limit: null,
        firstDate: first,
        accent: accent(tester),
        onChanged: (e, l) {
          gotEnd = e;
          gotLimit = l;
        },
      )));
      await tester.tap(find.text('On a date').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Never').last);
      await tester.pumpAndSettle();
      expect(gotEnd, isNull);
      expect(gotLimit, isNull);
    });

    testWidgets('the count steps up and down and stops at 1', (tester) async {
      int? limit = 2;
      late StateSetter set;
      await tester.pumpWidget(host(StatefulBuilder(builder: (c, s) {
        set = s;
        return ReminderEndsControl(
          endsAt: null,
          limit: limit,
          firstDate: first,
          accent: accent(tester),
          onChanged: (e, l) => s(() => limit = l),
        );
      })));
      expect(find.text('Stops after 2 times'), findsOneWidget);
      await tester.tap(find.byTooltip('More'));
      await tester.pump();
      expect(find.text('Stops after 3 times'), findsOneWidget);
      await tester.tap(find.byTooltip('Fewer'));
      await tester.pump();
      await tester.tap(find.byTooltip('Fewer'));
      await tester.pump();
      expect(find.text('Stops after 1 time'), findsOneWidget,
          reason: '"1 time", not "1 times"');
      final fewer = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Symbols.remove_rounded));
      expect(fewer.onPressed, isNull, reason: 'cannot go below one occurrence');
      set(() {});
    });

    test('mode is a date when both are somehow set, and nothing is lost', () {
      expect(ReminderEndsControl.modeOf(DateTime(2026), 5), 'date');
      expect(ReminderEndsControl.modeOf(null, 5), 'count');
      expect(ReminderEndsControl.modeOf(null, null), 'never');
    });
  });

  group('ReminderPauseControl', () {
    testWidgets('off shows only the switch', (tester) async {
      await tester.pumpWidget(host(ReminderPauseControl(
        paused: false,
        until: null,
        accent: accent(tester),
        onChanged: (_, __) {},
      )));
      expect(find.text('Pause'), findsOneWidget);
      expect(find.textContaining('Resume on'), findsNothing);
    });

    testWidgets('on offers an optional resume date, and says what no date means',
        (tester) async {
      await tester.pumpWidget(host(ReminderPauseControl(
        paused: true,
        until: null,
        accent: accent(tester),
        onChanged: (_, __) {},
      )));
      expect(find.text('Resume on a date (optional)'), findsOneWidget);
      expect(find.text('Stays paused until you switch it back on.'),
          findsOneWidget);
    });

    testWidgets('with a date it says when it comes back and how', (tester) async {
      await tester.pumpWidget(host(ReminderPauseControl(
        paused: true,
        until: DateTime(2026, 4, 20),
        accent: accent(tester),
        onChanged: (_, __) {},
      )));
      expect(find.textContaining('Back on'), findsOneWidget);
      expect(find.textContaining('first time you open the app'), findsOneWidget);
    });

    testWidgets('clearing the date keeps it paused', (tester) async {
      bool? p;
      DateTime? u = DateTime(2000);
      await tester.pumpWidget(host(ReminderPauseControl(
        paused: true,
        until: DateTime(2026, 4, 20),
        accent: accent(tester),
        onChanged: (paused, until) {
          p = paused;
          u = until;
        },
      )));
      await tester.tap(find.byTooltip('Clear the resume date'));
      expect(p, isTrue);
      expect(u, isNull);
    });

    testWidgets('switching it off drops the date', (tester) async {
      bool? p;
      DateTime? u = DateTime(2000);
      await tester.pumpWidget(host(ReminderPauseControl(
        paused: true,
        until: DateTime(2026, 4, 20),
        accent: accent(tester),
        onChanged: (paused, until) {
          p = paused;
          u = until;
        },
      )));
      await tester.tap(find.byType(AppSwitch));
      expect(p, isFalse);
      expect(u, isNull, reason: 'a resume date means nothing for a reminder '
          'that is not paused');
    });
  });

  group('VacationSheetBody', () {
    final today = DateTime(2026, 3, 13, 10);
    var reArmed = 0;
    bool? done;

    Future<void> pump(WidgetTester tester) async {
      reArmed = 0;
      done = null;
      await tester.pumpWidget(host(VacationSheetBody(
        onDone: (c) => done = c,
        reArm: () async => reArmed++,
      )));
    }

    testWidgets('starting for a week sets the period, re-arms, and reports it',
        (tester) async {
      await withClock(Clock.fixed(today), () async {
        await pump(tester);
        await tester.runAsync(() async {
          await tester.tap(find.text('1 week'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();

        final v = VacationMode.active();
        expect(v, isNotNull);
        expect(v!.start, DateTime(2026, 3, 13));
        expect(v.end, DateTime(2026, 3, 19),
            reason: 'seven days including today');
        expect(reArmed, 1, reason: 'reminders must be taken off the OS now');
        expect(done, isTrue);
      });
    });

    testWidgets('says what it does NOT touch', (tester) async {
      await withClock(Clock.fixed(today), () async {
        await pump(tester);
        expect(find.textContaining('Medicine reminders and medicine streaks'),
            findsOneWidget);
      });
    });

    testWidgets('while on vacation it offers to end it, and ending re-arms',
        (tester) async {
      await withClock(Clock.fixed(today), () async {
        await VacationMode.start(until: DateTime(2026, 3, 19));
        await pump(tester);
        expect(find.textContaining('On vacation until'), findsOneWidget);
        expect(find.text('1 week'), findsNothing,
            reason: 'no new vacation while one is running');

        await tester.runAsync(() async {
          await tester.tap(find.text('End vacation now'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();

        expect(VacationMode.active(), isNull);
        expect(reArmed, 1);
        expect(done, isTrue);
      });
    });

    testWidgets('Close changes nothing', (tester) async {
      await withClock(Clock.fixed(today), () async {
        await pump(tester);
        await tester.tap(find.text('Close'));
        expect(done, isFalse);
        expect(VacationMode.active(), isNull);
        expect(reArmed, 0);
      });
    });
  });

  group('VacationBanner', () {
    final today = DateTime(2026, 3, 13, 10);

    testWidgets('renders nothing when not on vacation', (tester) async {
      await withClock(Clock.fixed(today), () async {
        await tester.pumpWidget(host(VacationBanner(onTap: () {})));
        expect(find.textContaining('On vacation'), findsNothing);
      });
    });

    testWidgets('says until when, and what that means', (tester) async {
      await withClock(Clock.fixed(today), () async {
        await VacationMode.start(until: DateTime(2026, 3, 19));
        await tester.pumpWidget(host(VacationBanner(onTap: () {})));
        expect(find.text('On vacation until Mar 19'), findsOneWidget);
        expect(find.textContaining('medicines unaffected'), findsOneWidget);
      });
    });
  });
}

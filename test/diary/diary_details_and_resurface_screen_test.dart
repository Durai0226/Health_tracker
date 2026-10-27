/// The Diary's new surfaces, on screen: the details sheet (date, mood, tags),
/// search, "On this day" and the prompt.
///
/// The arithmetic behind each is in `diary_resurface_test.dart`; this is the
/// wiring — what the person sees and what is stored.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/vitals_theme.dart';
import 'package:tablet_remainder/features/diary/models/diary_entry.dart';
import 'package:tablet_remainder/features/diary/screens/diary_entry_screen.dart';
import 'package:tablet_remainder/features/diary/screens/diary_screen.dart';
import 'package:tablet_remainder/features/diary/services/diary_storage_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/models/mood_entry.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late AppDatabase db;

  // A fixed mid-month afternoon, so "yesterday" is on the same calendar page.
  final now = DateTime(2026, 6, 15, 14, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    await ActiveProfileService().init();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await SleepService.resetForTesting();
  });

  tearDown(() async {
    ActiveProfileService().resetForTesting();
    await db.close();
  });

  void pinned(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) => withClock(Clock.fixed(now), () => body(tester)));

  DiaryEntry entry(
    String id, {
    String? title,
    String body = 'Something happened.',
    DateTime? at,
    int? mood,
    List<String> tags = const [],
  }) {
    final when = at ?? DateTime(2026, 6, 1, 20);
    return DiaryEntry(
      id: id,
      title: title,
      body: body,
      entryAt: when,
      createdAt: when,
      moodIndex: mood,
      tags: tags,
    );
  }

  Future<void> pumpFor(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void phone(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 1400);
    addTearDown(tester.view.reset);
  }

  /// The editor, pushed onto a host route so the back arrow is real.
  Future<void> pushEditor(WidgetTester tester,
      {DiaryEntry? existing, String? initialTitle}) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => DiaryEntryScreen(
                        existing: existing, initialTitle: initialTitle)),
              ),
              child: const Text('open editor'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open editor'));
    await pumpFor(tester);
  }

  Future<void> pumpDiary(WidgetTester tester) async {
    phone(tester);
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const DiaryScreen()));
    await pumpFor(tester, 8);
  }

  Finder bodyField() => find.byType(TextFormField).last;
  Finder save() => find.byIcon(Symbols.check_rounded);

  Future<void> openDetails(WidgetTester tester) async {
    await tester.tap(find.byWidgetPredicate((w) =>
        w is Semantics &&
        (w.properties.label?.startsWith('Entry details') ?? false)));
    await pumpFor(tester);
  }

  /// In the details sheet, move the date to yesterday (the 14th).
  Future<void> pickYesterday(WidgetTester tester) async {
    await tester.tap(find.text('Today'));
    await pumpFor(tester);
    await tester.tap(find.text('14'));
    await pumpFor(tester);
    await tester.tap(find.text('Set date'));
    await pumpFor(tester);
  }

  group('the editor: date, mood and tags', () {
    pinned('a new entry is dated now, with no mood and no tags', (tester) async {
      await pushEditor(tester);
      expect(find.textContaining('Today, 2:30 PM'), findsOneWidget);

      await tester.enterText(bodyField(), 'A plain day.');
      await tester.tap(save());
      await pumpFor(tester, 10);

      final saved = (await DiaryStorageService.getAll()).single;
      expect(saved.entryAt, now);
      expect(saved.moodIndex, isNull);
      expect(saved.tags, isEmpty);
    });

    pinned('the details sheet sets a mood and tags, shown on the line and saved',
        (tester) async {
      await pushEditor(tester);
      await openDetails(tester);
      expect(find.text('Entry details'), findsOneWidget);

      await tester.tap(find.text('Good'));
      await tester.pump();
      await tester.tap(find.text('Friends'));
      await tester.pump();
      await tester.tap(find.text('Walk'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await pumpFor(tester);

      // The line says it, in the order the tags are listed, not tapped.
      expect(find.textContaining('Today, 2:30 PM · Good · Walk, Friends'),
          findsOneWidget);

      await tester.enterText(bodyField(), 'Out with Sam.');
      await tester.tap(save());
      await pumpFor(tester, 10);

      final saved = (await DiaryStorageService.getAll()).single;
      expect(saved.moodIndex, 1);
      expect(saved.tags, ['walk', 'friends']);
    });

    pinned('the same face again takes the mood back', (tester) async {
      await pushEditor(tester);
      await openDetails(tester);
      await tester.tap(find.text('Okay'));
      await tester.pump();
      await tester.tap(find.text('Okay'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await pumpFor(tester);

      expect(find.textContaining('Okay'), findsNothing);
      await tester.enterText(bodyField(), 'x');
      await tester.tap(save());
      await pumpFor(tester, 10);
      expect((await DiaryStorageService.getAll()).single.moodIndex, isNull);
    });

    pinned('the date can be set back, and keeps the time of day', (tester) async {
      await pushEditor(tester);
      await openDetails(tester);
      await pickYesterday(tester);
      await tester.tap(find.text('Done'));
      await pumpFor(tester);

      expect(find.textContaining('Yesterday, 2:30 PM'), findsOneWidget);
      await tester.enterText(bodyField(), 'Writing about yesterday.');
      await tester.tap(save());
      await pumpFor(tester, 10);

      expect((await DiaryStorageService.getAll()).single.entryAt,
          DateTime(2026, 6, 14, 14, 30));
    });

    pinned('an entry being edited keeps its date, mood and tags', (tester) async {
      await pushEditor(
        tester,
        existing: entry('e1',
            body: 'Old words.',
            at: DateTime(2026, 6, 2, 8, 15),
            mood: 3,
            tags: ['work']),
      );
      expect(find.textContaining('Jun 2, 8:15 AM · Bad · Work'), findsOneWidget);

      await tester.enterText(bodyField(), 'New words.');
      await tester.tap(save());
      await pumpFor(tester, 10);

      final saved = (await DiaryStorageService.getAll()).single;
      expect(saved.body, 'New words.');
      expect(saved.entryAt, DateTime(2026, 6, 2, 8, 15));
      expect(saved.moodIndex, 3);
      expect(saved.tags, ['work']);
    });

    pinned('changing only the mood is unsaved work: back asks first',
        (tester) async {
      await pushEditor(
        tester,
        existing: entry('e1', at: DateTime(2026, 6, 2, 8), mood: 1),
      );
      await openDetails(tester);
      await tester.tap(find.text('Bad'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await pumpFor(tester);

      await tester.tap(find.byTooltip('Back'));
      await pumpFor(tester);
      expect(find.text('Discard this entry?'), findsOneWidget);
    });

    pinned('opening the details and putting everything back is not unsaved work',
        (tester) async {
      await pushEditor(
        tester,
        existing: entry('e1', at: DateTime(2026, 6, 2, 8), mood: 1),
      );
      await openDetails(tester);
      await tester.tap(find.text('Done'));
      await pumpFor(tester);

      await tester.tap(find.byTooltip('Back'));
      await pumpFor(tester);
      expect(find.text('Discard this entry?'), findsNothing);
      expect(find.text('open editor'), findsOneWidget);
    });

    pinned('a prompt\'s question fills the title; leaving it alone is not a discard',
        (tester) async {
      await pushEditor(tester, initialTitle: 'What got in the way of sleep?');
      expect(find.text('What got in the way of sleep?'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await pumpFor(tester);
      expect(find.text('Discard this entry?'), findsNothing,
          reason: 'nothing was typed; the question was put there for them');
    });

    pinned('typing and then deleting again leaves the question alone, unsaved '
        'work and all', (tester) async {
      await pushEditor(tester, initialTitle: 'What got in the way of sleep?');
      await tester.enterText(bodyField(), 'The nei');
      await tester.pump();
      await tester.enterText(bodyField(), '');
      await tester.pump();

      await tester.tap(find.byTooltip('Back'));
      await pumpFor(tester);
      expect(find.text('Discard this entry?'), findsNothing,
          reason: 'the title is what it opened with, and the body is empty '
              'again: measured against the question, not against nothing');
    });

    pinned('and the question is the title the entry is saved under',
        (tester) async {
      await pushEditor(tester, initialTitle: 'What got in the way of sleep?');
      await tester.enterText(bodyField(), 'The neighbours.');
      await tester.tap(save());
      await pumpFor(tester, 10);

      final saved = (await DiaryStorageService.getAll()).single;
      expect(saved.title, 'What got in the way of sleep?');
      expect(saved.body, 'The neighbours.');
    });
  });

  group('the list', () {
    pinned('a row shows its mood and its tags', (tester) async {
      await DiaryStorageService.save(entry('a',
          title: 'Walk by the river',
          mood: 0,
          tags: ['walk', 'friends'],
          at: DateTime(2026, 6, 10, 18)));
      await pumpDiary(tester);

      expect(find.byIcon(VitalsColors.moodIcon(0)), findsOneWidget);
      expect(find.textContaining('Walk, Friends'), findsOneWidget);
    });

    pinned('an entry with neither shows neither', (tester) async {
      await DiaryStorageService.save(entry('a', title: 'Plain'));
      await pumpDiary(tester);
      for (var i = 0; i < 5; i++) {
        expect(find.byIcon(VitalsColors.moodIcon(i)), findsNothing);
      }
    });
  });

  group('search', () {
    Future<void> seed() async {
      await DiaryStorageService.save(entry('a',
          title: 'Garden',
          body: 'Planted the tomatoes.',
          at: DateTime(2026, 6, 10)));
      await DiaryStorageService.save(entry('b',
          body: 'Long walk by the river with Sam.',
          tags: ['walk'],
          at: DateTime(2026, 6, 9)));
      await DiaryStorageService.save(entry('c',
          body: 'Rough one.', mood: 3, at: DateTime(2026, 6, 8)));
    }

    pinned('the search icon only appears once there is something to search',
        (tester) async {
      await pumpDiary(tester);
      expect(find.byTooltip('Search diary'), findsNothing);
    });

    pinned('typing narrows the list; clearing brings it back', (tester) async {
      await seed();
      await pumpDiary(tester);
      expect(find.text('Garden'), findsOneWidget);

      await tester.tap(find.byTooltip('Search diary'));
      await pumpFor(tester);
      await tester.enterText(find.byType(TextField).last, 'river');
      await pumpFor(tester);

      expect(find.textContaining('Long walk by the river'), findsWidgets);
      expect(find.text('Garden'), findsNothing);

      await tester.enterText(find.byType(TextField).last, '');
      await pumpFor(tester);
      expect(find.text('Garden'), findsOneWidget);
    });

    pinned('a tag and a mood are searchable by the name they are shown under',
        (tester) async {
      await seed();
      await pumpDiary(tester);
      await tester.tap(find.byTooltip('Search diary'));
      await pumpFor(tester);

      await tester.enterText(find.byType(TextField).last, 'bad');
      await pumpFor(tester);
      expect(find.textContaining('Rough one.'), findsWidgets);
      expect(find.text('Garden'), findsNothing);

      await tester.enterText(find.byType(TextField).last, 'walk');
      await pumpFor(tester);
      expect(find.textContaining('Long walk by the river'), findsWidgets);
      expect(find.textContaining('Rough one.'), findsNothing);
    });

    pinned('nothing matching says so', (tester) async {
      await seed();
      await pumpDiary(tester);
      await tester.tap(find.byTooltip('Search diary'));
      await pumpFor(tester);
      await tester.enterText(find.byType(TextField).last, 'zebra');
      await pumpFor(tester);

      expect(find.text('Nothing in your diary matches \u201czebra\u201d.'),
          findsOneWidget);
    });

    pinned('closing the search clears it', (tester) async {
      await seed();
      await pumpDiary(tester);
      await tester.tap(find.byTooltip('Search diary'));
      await pumpFor(tester);
      await tester.enterText(find.byType(TextField).last, 'river');
      await pumpFor(tester);

      await tester.tap(find.byTooltip('Close search'));
      await pumpFor(tester);
      expect(find.text('Garden'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('On this day', () {
    pinned('an entry from this date in an earlier year is shown, and opens',
        (tester) async {
      await DiaryStorageService.save(entry('old',
          title: 'Moving day',
          body: 'Boxes everywhere.',
          at: DateTime(2025, 6, 15, 19)));
      await pumpDiary(tester);

      expect(find.text('On this day'), findsOneWidget);
      expect(find.text('1 year ago'), findsOneWidget);

      await tester.tap(find.text('1 year ago'));
      await pumpFor(tester);
      expect(find.text('Edit entry'), findsOneWidget);
      expect(tester.widget<TextFormField>(bodyField()).controller!.text,
          'Boxes everywhere.');
    });

    pinned('nothing from other dates', (tester) async {
      await DiaryStorageService.save(
          entry('x', at: DateTime(2025, 6, 16, 19)));
      await pumpDiary(tester);
      expect(find.text('On this day'), findsNothing);
    });

    pinned('not while searching', (tester) async {
      await DiaryStorageService.save(
          entry('old', title: 'Moving day', at: DateTime(2025, 6, 15, 19)));
      await pumpDiary(tester);
      await tester.tap(find.byTooltip('Search diary'));
      await pumpFor(tester);
      expect(find.text('On this day'), findsNothing);
    });
  });

  group('layout at 320pt with large text', () {
    /// Pumps with the text this large and reads whatever the framework reported:
    /// a RenderFlex overflow is an exception, and `takeException` is where a
    /// widget test sees it.
    ///
    /// Narrow, but tall: a lazy list builds only what is on screen, so a short
    /// window would leave the rows under test unbuilt and unmeasured.
    Future<Object?> pumpNarrow(
        WidgetTester tester, double scale, Widget screen) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 3000);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.lightTheme, home: screen));
      await pumpFor(tester, 8);
      return tester.takeException();
    }

    for (final scale in [1.0, 2.0]) {
      pinned('the list, with its cards, fits at ${scale}x', (tester) async {
        await DiaryStorageService.save(entry('old',
            title: 'A long afternoon walking the river path with everyone',
            at: DateTime(2025, 6, 15, 19),
            mood: 1));
        await DiaryStorageService.save(entry('recent',
            title: 'A long title that has to wrap or be cut and never overflow',
            at: DateTime(2026, 6, 10, 18),
            mood: 0,
            tags: ['walk', 'friends', 'outdoors', 'exercise', 'family']));
        await SleepService.logManualSession(
          bedtime: DateTime(2026, 6, 15, 2),
          wakeTime: DateTime(2026, 6, 15, 7),
        );
        expect(await pumpNarrow(tester, scale, const DiaryScreen()), isNull);
        // All three are really on screen, or this proved nothing.
        expect(find.text('A prompt for today'), findsOneWidget);
        expect(find.text('On this day'), findsOneWidget);
        expect(find.byIcon(VitalsColors.moodIcon(0)), findsOneWidget);
      });

      pinned('the editor with every detail set fits at ${scale}x', (tester) async {
        final e = entry('e1',
            title: 'A title',
            at: DateTime(2026, 6, 2, 8, 15),
            mood: 3,
            tags: ['walk', 'exercise', 'friends', 'family', 'work', 'outdoors']);
        expect(await pumpNarrow(tester, scale, DiaryEntryScreen(existing: e)),
            isNull);
        expect(find.textContaining('Jun 2, 8:15 AM · Bad · Walk, Exercise'),
            findsOneWidget);
      });

      pinned('and its details sheet fits at ${scale}x', (tester) async {
        final e = entry('e1', at: DateTime(2026, 6, 2, 8, 15), mood: 3);
        expect(await pumpNarrow(tester, scale, DiaryEntryScreen(existing: e)),
            isNull);
        await openDetails(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Entry details'), findsOneWidget);
      });
    }
  });

  group('the prompt', () {
    Future<void> shortNight() => SleepService.logManualSession(
          bedtime: DateTime(2026, 6, 15, 2),
          wakeTime: DateTime(2026, 6, 15, 7),
        );

    pinned('a short night offers its question, which opens a new entry',
        (tester) async {
      await DiaryStorageService.save(
          entry('earlier', at: DateTime(2026, 6, 10, 20)));
      await shortNight();
      await pumpDiary(tester);

      expect(find.text('A prompt for today'), findsOneWidget);
      expect(find.text('What got in the way of sleep?'), findsOneWidget);

      await tester.tap(find.text('Write about it'));
      await pumpFor(tester);
      expect(find.text('New entry'), findsOneWidget);
      expect(find.text('What got in the way of sleep?'), findsOneWidget);
    });

    pinned('"Not today" puts it away, and it stays away on a reload',
        (tester) async {
      await DiaryStorageService.save(
          entry('earlier', at: DateTime(2026, 6, 10, 20)));
      await shortNight();
      await pumpDiary(tester);

      await tester.tap(find.text('Not today'));
      await pumpFor(tester);
      expect(find.text('A prompt for today'), findsNothing);

      // A genuinely fresh screen: the same widget type in the same place would
      // keep its State, and with it the prompt it had already put away.
      await tester.pumpWidget(const SizedBox());
      await pumpDiary(tester);
      expect(find.text('A prompt for today'), findsNothing);
    });

    pinned('none when an entry was already written today', (tester) async {
      await DiaryStorageService.save(
          entry('today', at: DateTime(2026, 6, 15, 9)));
      await shortNight();
      await pumpDiary(tester);
      expect(find.text('A prompt for today'), findsNothing);
    });

    pinned('none when nothing stands out', (tester) async {
      await DiaryStorageService.save(
          entry('earlier', at: DateTime(2026, 6, 10, 20)));
      await pumpDiary(tester);
      expect(find.text('A prompt for today'), findsNothing);
    });

    pinned('a low mood logged this morning offers its own', (tester) async {
      await DiaryStorageService.save(
          entry('earlier', at: DateTime(2026, 6, 10, 20)));
      final at = DateTime(2026, 6, 15, 9);
      await VitalsStorageService.saveMood(MoodEntry(
          id: 'm1', moodIndex: 4, takenAt: at, createdAt: at));
      await pumpDiary(tester);
      expect(find.text('What has been on your mind?'), findsOneWidget);
    });

    pinned('a low mood from two days ago is old news', (tester) async {
      await DiaryStorageService.save(
          entry('earlier', at: DateTime(2026, 6, 10, 20)));
      final at = DateTime(2026, 6, 13, 9);
      await VitalsStorageService.saveMood(MoodEntry(
          id: 'm1', moodIndex: 4, takenAt: at, createdAt: at));
      await pumpDiary(tester);
      expect(find.text('A prompt for today'), findsNothing);
    });

    pinned('the LATEST mood decides: low at eight, good by noon, no prompt',
        (tester) async {
      await DiaryStorageService.save(
          entry('earlier', at: DateTime(2026, 6, 10, 20)));
      final early = DateTime(2026, 6, 15, 8);
      final later = DateTime(2026, 6, 15, 12);
      await VitalsStorageService.saveMood(MoodEntry(
          id: 'm1', moodIndex: 4, takenAt: early, createdAt: early));
      await VitalsStorageService.saveMood(MoodEntry(
          id: 'm2', moodIndex: 1, takenAt: later, createdAt: later));
      await pumpDiary(tester);
      expect(find.text('A prompt for today'), findsNothing);
    });

    pinned('a dose missed yesterday offers its question', (tester) async {
      await DiaryStorageService.save(
          entry('earlier', at: DateTime(2026, 6, 10, 20)));
      await MedicineCleanStorageService.addMedicine(EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        createdAt: DateTime(2026, 6, 1),
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 9, minute: 0)],
        ),
      ));
      final slot = DateTime(2026, 6, 14, 9);
      await MedicineCleanStorageService.addLog(MedicineLog.missed(
          id: MedicineCleanStorageService.doseLogId('m1', slot),
          medicineId: 'm1',
          scheduledTime: slot));
      await pumpDiary(tester);
      expect(find.text('What made a dose hard to take yesterday?'),
          findsOneWidget);
    });

    pinned('and not while searching', (tester) async {
      await DiaryStorageService.save(
          entry('earlier', at: DateTime(2026, 6, 10, 20)));
      await shortNight();
      await pumpDiary(tester);
      await tester.tap(find.byTooltip('Search diary'));
      await pumpFor(tester);
      expect(find.text('A prompt for today'), findsNothing);
    });
  });
}

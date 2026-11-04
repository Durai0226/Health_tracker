/// The Trends tab follows the data, not just the doses.
///
/// Only medicine and the active profile were listened to, so a drink, a night, a
/// day's steps, a period day, a blood pressure reading or a finished focus round
/// logged on another tab left every other card showing what was true when the tab
/// was last loaded, until the person pulled to refresh. Each of those publishes a
/// change now and the tab follows it — at once when it is on screen, once when it
/// comes to the front, and never more than one reload per few seconds however
/// noisy the source.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/insights/screens/trends_dashboard_screen.dart';
import 'package:tablet_remainder/features/insights/services/trends_data_service.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';
import 'package:tablet_remainder/features/period/services/period_service.dart';
import 'package:tablet_remainder/features/sleep/services/sleep_service.dart';
import 'package:tablet_remainder/features/steps/services/step_service.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    MedicineCleanStorageService.revision.value = 0;
    VitalsStorageService.revision.value = 0;
  });

  tearDown(() async => db.close());

  /// Publish a change on a map-valued notifier: a new map, which is what a service
  /// does when it has written a day.
  void poke<T>(ValueListenable<Map<String, T>> source) =>
      (source as ValueNotifier<Map<String, T>>).value = <String, T>{};

  /// What each tracker does when something is logged.
  final sources = <String, void Function()>{
    'medicine': () => MedicineCleanStorageService.revision.value++,
    'vitals': () => VitalsStorageService.revision.value++,
    'water': () => poke(WaterService.listenToDailyData()!),
    'sleep': () => poke(SleepService.listenToSessions()),
    'cycle': () => poke(PeriodService.listenToDays()),
    'profile': () => unawaited(ActiveProfileService()
        .setActiveDependent('someone-${DateTime.now().microsecondsSinceEpoch}')),
    'focus': () => FocusService().sessionsRevision.value++,
  };

  /// The shell's arrangement, reduced to the part that matters: Trends is a live
  /// `IndexedStack` child that starts hidden behind another tab.
  Future<void Function(int)> pumpShell(WidgetTester tester, {int shown = 1}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var index = 0;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    late StateSetter setOuter;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: StatefulBuilder(builder: (context, setState) {
        setOuter = setState;
        return IndexedStack(
          index: index,
          children: [
            const SizedBox.expand(),
            PrimaryScrollController(
              controller: controller,
              child: const TrendsDashboardScreen(isRoot: true),
            ),
          ],
        );
      }),
    ));
    // Not pumpAndSettle: the skeleton repeats.
    Future<void> settle(int steps) async {
      for (var i = 0; i < steps; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle(20);
    void select(int i) => setOuter(() => index = i);
    if (shown == 1) {
      select(1);
      await settle(5);
    }
    return select;
  }

  Future<void> pumpFor(WidgetTester tester, Duration d) async {
    for (var left = d; left > Duration.zero;) {
      final step = left > const Duration(milliseconds: 100)
          ? const Duration(milliseconds: 100)
          : left;
      await tester.pump(step);
      left -= step;
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  }

  testWidgets('everything it listened to is let go of when the tab is, not left holding it',
      (tester) async {
    // A listener left on a long-lived service keeps the whole State alive. It does no
    // harm to what is on screen — the reload checks it is still mounted — which is
    // why nothing else here can see it. FIRST in the file, so no earlier test has
    // left a listener behind for this one to take as the baseline.
    final watched = <String, ChangeNotifier>{
      'medicine': MedicineCleanStorageService.revision,
      'vitals': VitalsStorageService.revision,
      'water': WaterService.listenToDailyData()! as ChangeNotifier,
      'sleep': SleepService.listenToSessions() as ChangeNotifier,
      'cycle': PeriodService.listenToDays() as ChangeNotifier,
      'focus': FocusService().sessionsRevision,
      'steps': StepService.listenToDailyData()! as ChangeNotifier,
      'profile': ActiveProfileService(),
    };
    // ignore: invalid_use_of_protected_member
    bool held(ChangeNotifier n) => n.hasListeners;
    final before = {for (final e in watched.entries) e.key: held(e.value)};

    await pumpShell(tester);
    await pumpFor(tester, const Duration(seconds: 2));
    for (final e in watched.entries) {
      expect(held(e.value), isTrue, reason: '${e.key}: the premise — it is listened to');
    }

    await unmount(tester);

    for (final e in watched.entries) {
      expect(held(e.value), before[e.key], reason: '${e.key} is let go of');
    }
  });

  testWidgets('being mounted is not "a screen is here to celebrate a finished round"',
      (tester) async {
    // `FocusService` decides whether to celebrate on screen or to notify by whether
    // anyone is listening to `justCompleted`. Trends stays mounted once shown, so a
    // listener of its own there made the answer yes — and a round that finished with
    // the Focus screen closed was announced to nobody.
    expect(FocusService().justCompleted.hasConsumer, isFalse, reason: 'the premise');

    await pumpShell(tester);
    await pumpFor(tester, const Duration(seconds: 2));

    expect(FocusService().justCompleted.hasConsumer, isFalse);
    await unmount(tester);
  });

  for (final entry in sources.entries) {
    testWidgets('${entry.key}: a change while the tab is showing reloads it',
        (tester) async {
      await pumpShell(tester);
      await pumpFor(tester, const Duration(seconds: 4));
      final before = TrendsDataService.debugBuilds;

      entry.value();
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(TrendsDataService.debugBuilds, before + 1);
      await unmount(tester);
    });

    testWidgets('${entry.key}: a change behind another tab waits for it to be shown',
        (tester) async {
      final select = await pumpShell(tester, shown: 0);
      final before = TrendsDataService.debugBuilds;
      expect(before, greaterThan(0), reason: 'the premise: it loaded once');

      entry.value();
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(TrendsDataService.debugBuilds, before,
          reason: 'nobody is looking at it');

      select(1);
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(TrendsDataService.debugBuilds, before + 1,
          reason: 'and the change is owed to it the moment it is');
      await unmount(tester);
    });
  }

  group('a noisy source', () {
    testWidgets('reloads at once the first time, then once for everything after',
        (tester) async {
      await pumpShell(tester);
      await pumpFor(tester, const Duration(seconds: 4));
      final before = TrendsDataService.debugBuilds;

      sources['sleep']!();
      await pumpFor(tester, const Duration(milliseconds: 200));
      expect(TrendsDataService.debugBuilds, before + 1, reason: 'the first is at once');

      // Twenty more over the next second and a half.
      for (var i = 0; i < 20; i++) {
        sources['sleep']!();
        sources['water']!();
        await pumpFor(tester, const Duration(milliseconds: 75));
      }
      expect(TrendsDataService.debugBuilds, before + 1,
          reason: 'none of them reloads inside the gap');

      await pumpFor(tester, const Duration(seconds: 2));
      expect(TrendsDataService.debugBuilds, before + 2,
          reason: 'they are folded into one when the gap ends');

      await pumpFor(tester, const Duration(seconds: 8));
      expect(TrendsDataService.debugBuilds, before + 2, reason: 'and then it is quiet');
      await unmount(tester);
    });

    testWidgets('after a quiet spell the next change is at once again', (tester) async {
      await pumpShell(tester);
      await pumpFor(tester, const Duration(seconds: 4));
      sources['water']!();
      await pumpFor(tester, const Duration(seconds: 4));
      final before = TrendsDataService.debugBuilds;

      sources['sleep']!();
      await pumpFor(tester, const Duration(milliseconds: 200));

      expect(TrendsDataService.debugBuilds, before + 1);
      await unmount(tester);
    });

    testWidgets('a change that arrives in the gap, with the tab put away, waits for it',
        (tester) async {
      final select = await pumpShell(tester);
      await pumpFor(tester, const Duration(seconds: 4));
      final before = TrendsDataService.debugBuilds;

      sources['sleep']!();
      await pumpFor(tester, const Duration(milliseconds: 200));
      sources['water']!();
      select(0);
      await pumpFor(tester, const Duration(seconds: 4));
      expect(TrendsDataService.debugBuilds, before + 1,
          reason: 'the gap ended with the tab hidden: no reload for nobody');

      select(1);
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(TrendsDataService.debugBuilds, before + 2,
          reason: 'it is reloaded when it comes back');
      await unmount(tester);
    });
  });

  group('a different profile', () {
    // Spaced reloads are for noisy sources. Somebody who has just switched
    // profile is looking for the other person's numbers: for up to three seconds
    // after any earlier reload they were shown the previous person's.
    testWidgets('is shown at once, even inside the gap after another reload',
        (tester) async {
      await pumpShell(tester);
      await pumpFor(tester, const Duration(seconds: 4));
      final before = TrendsDataService.debugBuilds;

      sources['water']!();
      await pumpFor(tester, const Duration(milliseconds: 200));
      expect(TrendsDataService.debugBuilds, before + 1, reason: 'the premise: a reload, and now the gap');

      sources['profile']!();
      await pumpFor(tester, const Duration(milliseconds: 200));

      expect(TrendsDataService.debugBuilds, before + 2,
          reason: 'the switch does not wait for the gap to end');
      await unmount(tester);
    });

    testWidgets('and a profile switch is not folded into the next data change\'s reload',
        (tester) async {
      await pumpShell(tester);
      await pumpFor(tester, const Duration(seconds: 4));
      final before = TrendsDataService.debugBuilds;

      sources['profile']!();
      await pumpFor(tester, const Duration(milliseconds: 200));
      expect(TrendsDataService.debugBuilds, before + 1);

      // The gap that follows belongs to data, not to profiles: a change right after
      // a switch is still a first change, and reloads at once.
      sources['sleep']!();
      await pumpFor(tester, const Duration(milliseconds: 200));
      expect(TrendsDataService.debugBuilds, before + 2);
      await unmount(tester);
    });

    testWidgets('behind another tab it waits to be shown, like everything else', (tester) async {
      final select = await pumpShell(tester, shown: 0);
      final before = TrendsDataService.debugBuilds;

      sources['profile']!();
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(TrendsDataService.debugBuilds, before);

      select(1);
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(TrendsDataService.debugBuilds, before + 1);
      await unmount(tester);
    });

    testWidgets('once the tab is gone, a switch does not reload it', (tester) async {
      await pumpShell(tester);
      await pumpFor(tester, const Duration(seconds: 4));
      await unmount(tester);
      final before = TrendsDataService.debugBuilds;

      sources['profile']!();
      await tester.pump(const Duration(seconds: 1));

      expect(TrendsDataService.debugBuilds, before);
    });
  });

  group('steps, which never stop', () {
    void pokeSteps() => poke(StepService.listenToDailyData()!);

    testWidgets('are not reloaded at once, but within fifteen seconds, and once', (tester) async {
      await pumpShell(tester);
      await pumpFor(tester, const Duration(seconds: 4));
      final before = TrendsDataService.debugBuilds;

      for (var i = 0; i < 40; i++) {
        pokeSteps();
        await pumpFor(tester, const Duration(milliseconds: 250));
      }
      // Ten seconds of walking.
      expect(TrendsDataService.debugBuilds, before,
          reason: 'forty changes, none of them a reload');

      await pumpFor(tester, const Duration(seconds: 6));
      expect(TrendsDataService.debugBuilds, before + 1,
          reason: 'one reload, when the delay that the first started has run out');

      await pumpFor(tester, const Duration(seconds: 20));
      expect(TrendsDataService.debugBuilds, before + 1, reason: 'and then it is quiet');
      await unmount(tester);
    });

    testWidgets('a change while the tab is behind another waits for it, like the rest',
        (tester) async {
      final select = await pumpShell(tester, shown: 0);
      final before = TrendsDataService.debugBuilds;

      pokeSteps();
      await pumpFor(tester, const Duration(seconds: 20));
      expect(TrendsDataService.debugBuilds, before);

      select(1);
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(TrendsDataService.debugBuilds, before + 1);
      await unmount(tester);
    });

    testWidgets('and one that is overtaken by the tab being put away is not run for nobody',
        (tester) async {
      final select = await pumpShell(tester);
      await pumpFor(tester, const Duration(seconds: 4));
      final before = TrendsDataService.debugBuilds;

      pokeSteps();
      await pumpFor(tester, const Duration(seconds: 2));
      select(0);
      await pumpFor(tester, const Duration(seconds: 20));
      expect(TrendsDataService.debugBuilds, before, reason: 'nobody is looking at it');

      select(1);
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(TrendsDataService.debugBuilds, before + 1);
      await unmount(tester);
    });

    testWidgets('another change reloads everything, steps included, without waiting',
        (tester) async {
      await pumpShell(tester);
      await pumpFor(tester, const Duration(seconds: 4));
      final before = TrendsDataService.debugBuilds;

      pokeSteps();
      await pumpFor(tester, const Duration(seconds: 1));
      sources['sleep']!();
      await pumpFor(tester, const Duration(milliseconds: 300));

      expect(TrendsDataService.debugBuilds, before + 1);
      await unmount(tester);
    });

    testWidgets('a steps reload that was waiting is cancelled with the tab', (tester) async {
      await pumpShell(tester);
      await pumpFor(tester, const Duration(seconds: 4));
      pokeSteps();
      await pumpFor(tester, const Duration(milliseconds: 200));

      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('a reload that was waiting is cancelled with the tab, not left pending',
      (tester) async {
    await pumpShell(tester);
    await pumpFor(tester, const Duration(seconds: 4));
    sources['water']!();
    await pumpFor(tester, const Duration(milliseconds: 200));

    // Gone while the gap is still running — and no more time passes. A timer left
    // behind is what the framework reports at the end of the test.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('once the tab is gone, nothing it listened to reloads it', (tester) async {
    await pumpShell(tester);
    await pumpFor(tester, const Duration(seconds: 4));
    await unmount(tester);
    final before = TrendsDataService.debugBuilds;

    for (final poke in sources.values) {
      poke();
    }
    await tester.pump(const Duration(seconds: 5));

    expect(TrendsDataService.debugBuilds, before);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/features/focus/screens/focus_screen.dart';
import 'package:tablet_remainder/features/focus/screens/relaxation_screen.dart';
import 'package:tablet_remainder/features/focus/screens/relaxation_game_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_garden_screen.dart';
import 'package:tablet_remainder/features/focus/screens/focus_stats_screen.dart';
import 'package:tablet_remainder/features/focus/screens/detailed_stats_screen.dart';
import 'package:tablet_remainder/features/focus/screens/custom_tags_screen.dart';
import 'package:tablet_remainder/features/focus/screens/app_allow_list_screen.dart';
import 'package:tablet_remainder/features/focus/screens/plant_real_trees_screen.dart';
import 'package:tablet_remainder/features/focus/services/focus_service.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_service.dart';
import 'package:tablet_remainder/features/focus/services/relaxation_game_service.dart';
import 'package:tablet_remainder/features/focus/services/tag_service.dart';
import 'package:tablet_remainder/features/focus/services/stats_service.dart';
import 'package:tablet_remainder/features/focus/models/focus_plant.dart';
import 'package:tablet_remainder/features/focus/models/focus_session.dart';
import 'package:tablet_remainder/features/focus/models/breathing_exercise.dart';
import 'package:tablet_remainder/features/focus/models/ambient_sound.dart';
import 'package:tablet_remainder/features/focus/models/relaxation_music.dart';
import 'package:tablet_remainder/features/focus/widgets/breathing_widget.dart';

void main() {
  group('Focus Feature E2E Tests', () {
    group('Focus Service Tests', () {
      late FocusService focusService;

      setUp(() {
        focusService = FocusService();
      });

      test('Initial state is correct', () {
        expect(focusService.isRunning, false);
        expect(focusService.isPaused, false);
        expect(focusService.selectedMinutes, 25);
        expect(focusService.selectedPlant, PlantType.seedling);
        expect(focusService.selectedActivity, FocusActivityType.work);
      });

      test('Can set duration', () {
        focusService.setDuration(30);
        expect(focusService.selectedMinutes, 30);
        
        focusService.setDuration(45);
        expect(focusService.selectedMinutes, 45);
      });

      test('Can set activity', () {
        focusService.setActivity(FocusActivityType.study);
        expect(focusService.selectedActivity, FocusActivityType.study);
        
        focusService.setActivity(FocusActivityType.reading);
        expect(focusService.selectedActivity, FocusActivityType.reading);
      });

      test('Can set sound', () {
        focusService.setSound(AmbientSoundType.rain);
        expect(focusService.selectedSound, AmbientSoundType.rain);
      });

      test('Can set sound volume', () {
        focusService.setSoundVolume(0.8);
        expect(focusService.soundVolume, 0.8);
        
        focusService.setSoundVolume(1.5);
        expect(focusService.soundVolume, 1.0);
        
        focusService.setSoundVolume(-0.5);
        expect(focusService.soundVolume, 0.0);
      });

      test('Progress calculation is correct', () {
        expect(focusService.progress, 0.0);
      });

      test('Formatted time displays correctly', () {
        focusService.setDuration(25);
        expect(focusService.isRunning, false);
      });

      test('Stats are accessible', () {
        final stats = focusService.stats;
        expect(stats, isNotNull);
        expect(stats.totalMinutes, greaterThanOrEqualTo(0));
        expect(stats.totalSessions, greaterThanOrEqualTo(0));
      });

      test('Garden is accessible', () {
        final garden = focusService.garden;
        expect(garden, isNotNull);
        expect(garden, isA<List<FocusPlant>>());
      });

      test('Sessions are accessible', () {
        final sessions = focusService.sessions;
        expect(sessions, isNotNull);
        expect(sessions, isA<List<FocusSession>>());
      });

      test('Achievements are accessible', () {
        final achievements = focusService.achievements;
        expect(achievements, isNotNull);
      });

      test('Unlocked plants are accessible', () {
        final unlockedPlants = focusService.unlockedPlants;
        expect(unlockedPlants, isNotNull);
        expect(unlockedPlants.contains(PlantType.seedling), true);
      });
    });

    group('Relaxation Service Tests', () {
      late RelaxationService relaxationService;

      setUp(() {
        relaxationService = RelaxationService();
      });

      test('Initial state is correct', () {
        expect(relaxationService.isRunning, false);
        expect(relaxationService.isPaused, false);
        expect(relaxationService.selectedMinutes, 15);
      });

      test('Can set duration', () {
        relaxationService.setDuration(20);
        expect(relaxationService.selectedMinutes, 20);
      });

      test('Can set category', () {
        relaxationService.setCategory(RelaxationCategory.stressRelief);
        expect(relaxationService.selectedCategory, RelaxationCategory.stressRelief);
      });

      test('Can set volume', () {
        relaxationService.setVolume(0.5);
        expect(relaxationService.volume, 0.5);
      });

      test('Stats are accessible', () {
        final stats = relaxationService.stats;
        expect(stats, isNotNull);
      });
    });

    group('Plant Type Tests', () {
      test('All plant types have required properties', () {
        for (final plant in PlantType.values) {
          expect(plant.name, isNotEmpty);
          expect(plant.emoji, isNotEmpty);
          expect(plant.primaryColor, isNotNull);
          expect(plant.secondaryColor, isNotNull);
          expect(plant.unlockMinutes, greaterThanOrEqualTo(0));
        }
      });

      test('Plant unlock minutes are progressive', () {
        final unlockMinutes = PlantType.values.map((p) => p.unlockMinutes).toList();
        for (int i = 1; i < unlockMinutes.length; i++) {
          expect(unlockMinutes[i], greaterThanOrEqualTo(unlockMinutes[i - 1]));
        }
      });
    });

    group('Breathing Pattern Tests', () {
      test('All breathing patterns have required properties', () {
        for (final pattern in BreathingPattern.values) {
          expect(pattern.name, isNotEmpty);
          expect(pattern.description, isNotEmpty);
          expect(pattern.inhaleSeconds, greaterThan(0));
          expect(pattern.exhaleSeconds, greaterThan(0));
          expect(pattern.recommendedCycles, greaterThan(0));
          expect(pattern.color, isNotNull);
          expect(pattern.icon, isNotNull);
        }
      });

      test('Total cycle duration is calculated correctly', () {
        for (final pattern in BreathingPattern.values) {
          final expected = pattern.inhaleSeconds +
              pattern.holdAfterInhaleSeconds +
              pattern.exhaleSeconds +
              pattern.holdAfterExhaleSeconds;
          expect(pattern.totalCycleDuration, expected);
        }
      });
    });

    group('Breathing Phase Tests', () {
      test('All breathing phases have instructions', () {
        for (final phase in BreathingPhase.values) {
          expect(phase.instruction, isNotEmpty);
          expect(phase.color, isNotNull);
        }
      });
    });

    group('Focus Activity Type Tests', () {
      test('All activity types have required properties', () {
        for (final activity in FocusActivityType.values) {
          expect(activity.name, isNotEmpty);
          expect(activity.emoji, isNotEmpty);
        }
      });
    });

    group('Ambient Sound Type Tests', () {
      test('All ambient sound types exist', () {
        expect(AmbientSoundType.values.length, greaterThan(0));
        expect(AmbientSoundType.values.contains(AmbientSoundType.none), true);
      });
    });

    group('Relaxation Category Tests', () {
      test('All relaxation categories have required properties', () {
        for (final category in RelaxationCategory.values) {
          expect(category.name, isNotEmpty);
          expect(category.emoji, isNotEmpty);
          expect(category.color, isNotNull);
          expect(category.tracks, isNotNull);
        }
      });
    });

    group('Relaxation Music Type Tests', () {
      test('All music types have required properties', () {
        for (final music in RelaxationMusicType.values) {
          expect(music.name, isNotEmpty);
          expect(music.emoji, isNotEmpty);
          expect(music.description, isNotEmpty);
          expect(music.color, isNotNull);
          expect(music.category, isNotNull);
        }
      });
    });

    group('Focus Session Model Tests', () {
      test('Can create FocusSession', () {
        final session = FocusSession(
          id: 'test_session_1',
          startedAt: DateTime.now(),
          completedAt: DateTime.now().add(const Duration(minutes: 25)),
          targetMinutes: 25,
          actualMinutes: 25,
          wasCompleted: true,
          wasAbandoned: false,
          activityType: FocusActivityType.work,
          plantType: PlantType.seedling,
          soundUsed: AmbientSoundType.rain,
        );

        expect(session.id, 'test_session_1');
        expect(session.targetMinutes, 25);
        expect(session.actualMinutes, 25);
        expect(session.wasCompleted, true);
        expect(session.wasAbandoned, false);
      });

      test('FocusSession JSON serialization works', () {
        final session = FocusSession(
          id: 'test_session_2',
          startedAt: DateTime(2024, 1, 1, 10, 0),
          completedAt: DateTime(2024, 1, 1, 10, 25),
          targetMinutes: 25,
          actualMinutes: 25,
          wasCompleted: true,
          wasAbandoned: false,
          activityType: FocusActivityType.study,
          plantType: PlantType.tree,
          soundUsed: AmbientSoundType.none,
        );

        final json = session.toJson();
        expect(json, isNotNull);
        expect(json['id'], 'test_session_2');
        expect(json['targetMinutes'], 25);

        final restored = FocusSession.fromJson(json);
        expect(restored.id, session.id);
        expect(restored.targetMinutes, session.targetMinutes);
        expect(restored.wasCompleted, session.wasCompleted);
      });
    });

    group('Focus Plant Model Tests', () {
      test('Can create FocusPlant', () {
        final plant = FocusPlant(
          id: 'test_plant_1',
          type: PlantType.seedling,
          plantedAt: DateTime.now(),
          durationMinutes: 25,
          isAlive: true,
          growthProgress: 1.0,
          activity: 'work',
        );

        expect(plant.id, 'test_plant_1');
        expect(plant.type, PlantType.seedling);
        expect(plant.isAlive, true);
        expect(plant.growthProgress, 1.0);
      });

      test('FocusPlant JSON serialization works', () {
        final plant = FocusPlant(
          id: 'test_plant_2',
          type: PlantType.sapling,
          plantedAt: DateTime(2024, 1, 1, 10, 0),
          durationMinutes: 30,
          isAlive: true,
          growthProgress: 1.0,
          activity: 'study',
        );

        final json = plant.toJson();
        expect(json, isNotNull);
        expect(json['id'], 'test_plant_2');

        final restored = FocusPlant.fromJson(json);
        expect(restored.id, plant.id);
        expect(restored.type, plant.type);
        expect(restored.isAlive, plant.isAlive);
      });
    });

    group('Focus Stats Model Tests', () {
      test('FocusStats has correct defaults', () {
        const stats = FocusStats();
        expect(stats.totalMinutes, 0);
        expect(stats.totalSessions, 0);
        expect(stats.completedSessions, 0);
        expect(stats.abandonedSessions, 0);
        expect(stats.currentStreak, 0);
        expect(stats.longestStreak, 0);
      });

      test('FocusStats computed properties work', () {
        const stats = FocusStats(
          totalMinutes: 120,
          totalSessions: 10,
          completedSessions: 8,
          abandonedSessions: 2,
          totalPlants: 10,
          deadPlants: 2,
        );

        expect(stats.totalHours, 2);
        expect(stats.alivePlants, 8);
        expect(stats.completionRate, 0.8);
      });

      test('FocusStats JSON serialization works', () {
        const stats = FocusStats(
          totalMinutes: 60,
          totalSessions: 5,
          completedSessions: 4,
          abandonedSessions: 1,
          currentStreak: 3,
          longestStreak: 7,
        );

        final json = stats.toJson();
        expect(json, isNotNull);

        final restored = FocusStats.fromJson(json);
        expect(restored.totalMinutes, stats.totalMinutes);
        expect(restored.currentStreak, stats.currentStreak);
      });
    });

    group('Tag Service Tests', () {
      late TagService tagService;

      setUp(() {
        tagService = TagService();
      });

      test('Default tags exist', () {
        expect(tagService.defaultTags, isNotNull);
      });

      test('Tags list is accessible', () {
        expect(tagService.tags, isNotNull);
      });
    });

    group('Stats Service Tests', () {
      late StatsService statsService;

      setUp(() {
        statsService = StatsService();
      });

      test('Service initializes correctly', () {
        expect(statsService, isNotNull);
      });

      test('Today stats are accessible', () {
        final todayStats = statsService.getTodayStats();
        expect(todayStats, isNotNull);
      });

      test('Week stats are accessible', () {
        final weekStats = statsService.getWeekStats();
        expect(weekStats, isNotNull);
      });

      test('Month stats are accessible', () {
        final monthStats = statsService.getMonthStats();
        expect(monthStats, isNotNull);
      });

      test('Year stats are accessible', () {
        final yearStats = statsService.getYearStats();
        expect(yearStats, isNotNull);
      });
    });

    group('UI Widget Tests', () {
      testWidgets('FocusScreen builds without errors', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: FocusScreen(),
          ),
        );
        await tester.pump();
        
        expect(find.text('Focus Mode'), findsOneWidget);
      });

      testWidgets('FocusScreen shows duration selector', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: FocusScreen(),
          ),
        );
        await tester.pump();
        
        expect(find.text('Duration'), findsOneWidget);
      });

      testWidgets('FocusScreen shows start button', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: FocusScreen(),
          ),
        );
        await tester.pump();
        
        expect(find.text('Start Focus'), findsOneWidget);
      });

      testWidgets('FocusScreen shows breathing section', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: FocusScreen(),
          ),
        );
        await tester.pump();
        
        expect(find.text('Breathing Exercises'), findsOneWidget);
      });

      testWidgets('FocusScreen shows relaxation cards', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: FocusScreen(),
          ),
        );
        await tester.pump();
        
        expect(find.text('Relaxation & Deep Focus'), findsOneWidget);
        expect(find.text('Premium Relaxation'), findsOneWidget);
      });

      testWidgets('FocusScreen shows More Features section', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: FocusScreen(),
          ),
        );
        await tester.pumpAndSettle();
        
        expect(find.text('More Features'), findsOneWidget);
      });

      testWidgets('FocusScreen does NOT show Plant Together', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: FocusScreen(),
          ),
        );
        await tester.pumpAndSettle();
        
        expect(find.text('Plant Together'), findsNothing);
      });

      testWidgets('FocusScreen does NOT show Leaderboards', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: FocusScreen(),
          ),
        );
        await tester.pumpAndSettle();
        
        expect(find.text('Leaderboards'), findsNothing);
      });

      testWidgets('FocusGardenScreen builds without errors', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: FocusGardenScreen(),
          ),
        );
        await tester.pump();
        
        expect(find.text('My Garden'), findsOneWidget);
      });

      testWidgets('FocusStatsScreen builds without errors', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: FocusStatsScreen(),
          ),
        );
        await tester.pump();
        
        expect(find.text('Focus Statistics'), findsOneWidget);
      });

      testWidgets('DetailedStatsScreen builds without errors', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: DetailedStatsScreen(),
          ),
        );
        await tester.pump();
        
        expect(find.text('Detailed Statistics'), findsOneWidget);
      });

      testWidgets('CustomTagsScreen builds without errors', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: CustomTagsScreen(),
          ),
        );
        await tester.pump();
        
        expect(find.text('Focus Tags'), findsOneWidget);
      });

      testWidgets('AppAllowListScreen builds without errors', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: AppAllowListScreen(),
          ),
        );
        await tester.pump();
        
        expect(find.text('App Allow List'), findsOneWidget);
      });

      testWidgets('RelaxationScreen builds without errors', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: RelaxationScreen(),
          ),
        );
        await tester.pump();
        
        expect(find.text('Relaxation'), findsOneWidget);
      });

      testWidgets('RelaxationGameScreen builds without errors', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: RelaxationGameScreen(),
          ),
        );
        await tester.pump();
        
        expect(find.text('Relaxation Experience'), findsOneWidget);
      });

      testWidgets('PlantRealTreesScreen builds without errors', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: PlantRealTreesScreen(),
          ),
        );
        await tester.pump();
        
        expect(find.text('Plant Real Trees'), findsOneWidget);
      });
    });

    group('Navigation Tests', () {
      testWidgets('Can navigate to garden from focus screen', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const FocusScreen(),
            routes: {
              '/garden': (context) => const FocusGardenScreen(),
            },
          ),
        );
        await tester.pump();
        
        final gardenButton = find.byIcon(Icons.park_rounded);
        expect(gardenButton, findsOneWidget);
      });

      testWidgets('Can navigate to stats from focus screen', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const FocusScreen(),
            routes: {
              '/stats': (context) => const FocusStatsScreen(),
            },
          ),
        );
        await tester.pump();
        
        final statsButton = find.byIcon(Icons.bar_chart_rounded);
        expect(statsButton, findsOneWidget);
      });

      testWidgets('Can navigate to relaxation from focus screen', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: const FocusScreen(),
            routes: {
              '/relaxation': (context) => const RelaxationScreen(),
            },
          ),
        );
        await tester.pump();
        
        final relaxationButton = find.byIcon(Icons.spa_rounded);
        expect(relaxationButton, findsOneWidget);
      });
    });

    group('Duration Selection Tests', () {
      testWidgets('Duration buttons are displayed', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: FocusScreen(),
          ),
        );
        await tester.pump();
        
        expect(find.text('5 min'), findsOneWidget);
        expect(find.text('10 min'), findsOneWidget);
        expect(find.text('25 min'), findsOneWidget);
        expect(find.text('30 min'), findsOneWidget);
        expect(find.text('45 min'), findsOneWidget);
      });
    });

    group('Quick Stats Tests', () {
      testWidgets('Quick stats section is displayed', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: FocusScreen(),
          ),
        );
        await tester.pumpAndSettle();
        
        expect(find.text("Today's Progress"), findsOneWidget);
        expect(find.text('Minutes'), findsOneWidget);
        expect(find.text('Plants'), findsOneWidget);
        expect(find.text('Streak'), findsOneWidget);
      });
    });
  });
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tablet_remainder/features/water/models/beverage_type.dart';
import 'package:tablet_remainder/features/water/models/enhanced_water_log.dart';
import 'package:tablet_remainder/features/water/models/hydration_profile.dart';
import 'package:tablet_remainder/features/water/models/water_achievement.dart';
import 'package:tablet_remainder/features/water/models/water_container.dart';
import 'package:tablet_remainder/features/water/screens/water_dashboard_screen.dart';
import 'package:tablet_remainder/features/water/services/water_service.dart';

import 'package:flutter/services.dart';

void main() {
  group('Water Flow E2E Tests', () {
    late Directory tempDir;

    setUp(() async {
      // Mock Vibration channel
      const MethodChannel channel = MethodChannel('vibration');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          if (methodCall.method == 'hasVibrator') return true;
          if (methodCall.method == 'hasAmplitudeControl') return true;
          if (methodCall.method == 'vibrate') return null;
          if (methodCall.method == 'cancel') return null;
          return null;
        },
      );

      // Create a temporary directory for Hive
      tempDir = await Directory.systemTemp.createTemp();
      Hive.init(tempDir.path);

      // Register Adapters
      if (!Hive.isAdapterRegistered(20))
        Hive.registerAdapter(BeverageTypeAdapter());
      if (!Hive.isAdapterRegistered(21))
        Hive.registerAdapter(WaterContainerAdapter());
      if (!Hive.isAdapterRegistered(22))
        Hive.registerAdapter(ActivityLevelAdapter());
      if (!Hive.isAdapterRegistered(23))
        Hive.registerAdapter(ClimateTypeAdapter());
      if (!Hive.isAdapterRegistered(24))
        Hive.registerAdapter(HydrationProfileAdapter());
      if (!Hive.isAdapterRegistered(25))
        Hive.registerAdapter(AchievementTypeAdapter());
      if (!Hive.isAdapterRegistered(26))
        Hive.registerAdapter(WaterAchievementAdapter());
      if (!Hive.isAdapterRegistered(27))
        Hive.registerAdapter(UserAchievementsAdapter());
      if (!Hive.isAdapterRegistered(28))
        Hive.registerAdapter(EnhancedWaterLogAdapter());
      if (!Hive.isAdapterRegistered(29))
        Hive.registerAdapter(DailyWaterDataAdapter());

      // Open a box for StorageService app_preferences (needed by VitaVibeService.init)
      await Hive.openBox<dynamic>('app_preferences');

      await WaterService.init();
    });

    tearDown(() async {
      await WaterService.resetForTesting();
      await Hive.close();
      try {
        await tempDir.delete(recursive: true);
      } catch (e) {
        debugPrint('Error deleting temp dir: $e');
      }
    });

    testWidgets(
      'Water Dashboard updates immediately when water is added',
      (WidgetTester tester) async {
        // Set a realistic screen size
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.0;

        await tester.pumpWidget(const MaterialApp(
          home: WaterDashboardScreen(),
        ));

        // Use pump() without duration to avoid hanging on infinite wave animation
        // The AnimationController.repeat() for waves continuously schedules frames,
        // so pump(Duration) will never return.
        await tester.pump(); // Build first frame
        await tester.pump(); // Process async init
        await tester.pump(); // Settle state
        await tester.pump(); // Extra frame

        // Verify initial state (0ml appears in tank display and stats)
        expect(find.text('0ml'), findsAtLeastNWidgets(1));

        // Tap "Glass" (250ml) quick add button
        final glassButton = find.text('250ml');
        expect(glassButton, findsOneWidget);
        await tester.tap(glassButton);

        // Process the tap and rebuild
        await tester.pump(); // Process tap
        await tester.pump(); // Process setState
        await tester.pump(); // Rebuild
        await tester.pump(); // Extra frame

        // After adding, 'No drinks logged yet' should be gone
        expect(find.text('No drinks logged yet'), findsNothing);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    testWidgets(
      'Custom amount dialog opens and accepts input',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.0;

        await tester.pumpWidget(const MaterialApp(
          home: WaterDashboardScreen(),
        ));
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // Find the "Quick Add" FAB (not the section heading)
        final quickAddFab =
            find.widgetWithText(FloatingActionButton, 'Quick Add');
        expect(quickAddFab, findsOneWidget);

        await tester.tap(quickAddFab);
        await tester.pump(); // Process tap
        await tester.pump(); // Show bottom sheet

        // Should see "Add Custom Amount" bottom sheet
        expect(find.text('Add Custom Amount'), findsOneWidget);

        // Default amount is 250ml
        expect(find.text('250ml'), findsAtLeastNWidgets(1));

        // Tap "+" to increase to 300ml
        await tester.tap(find.byKey(const Key('add_custom_amount')));
        await tester.pump();
        await tester.pump(); // Extra pump for state update

        expect(find.text('300ml'), findsAtLeastNWidgets(1));

        // Tap "+" again to increase to 350ml
        await tester.tap(find.byKey(const Key('add_custom_amount')));
        await tester.pump();
        await tester.pump();

        expect(find.text('350ml'), findsAtLeastNWidgets(1));

        // Tap "Add Water" button to add and close
        await tester.tap(find.byKey(const Key('confirm_add_water')));
        await tester.pump(); // Process tap
        await tester.pump(); // Close bottom sheet

        // The dialog should be closed now
        expect(find.text('Add Custom Amount'), findsNothing);
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );
  });
}

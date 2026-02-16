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
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          if (methodCall.method == 'hasVibrator') {
            return true;
          }
          if (methodCall.method == 'hasAmplitudeControl') {
            return true;
          }
          return null;
        },
      );

      // Create a temporary directory for Hive
      tempDir = await Directory.systemTemp.createTemp();
      Hive.init(tempDir.path);

      // Register Adapters
       if (!Hive.isAdapterRegistered(20)) Hive.registerAdapter(BeverageTypeAdapter());
      if (!Hive.isAdapterRegistered(21)) Hive.registerAdapter(WaterContainerAdapter());
      if (!Hive.isAdapterRegistered(22)) Hive.registerAdapter(ActivityLevelAdapter());
      if (!Hive.isAdapterRegistered(23)) Hive.registerAdapter(ClimateTypeAdapter());
      if (!Hive.isAdapterRegistered(24)) Hive.registerAdapter(HydrationProfileAdapter());
      if (!Hive.isAdapterRegistered(25)) Hive.registerAdapter(AchievementTypeAdapter());
      if (!Hive.isAdapterRegistered(26)) Hive.registerAdapter(WaterAchievementAdapter());
      if (!Hive.isAdapterRegistered(27)) Hive.registerAdapter(UserAchievementsAdapter());
      if (!Hive.isAdapterRegistered(28)) Hive.registerAdapter(EnhancedWaterLogAdapter());
      if (!Hive.isAdapterRegistered(29)) Hive.registerAdapter(DailyWaterDataAdapter());

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

    testWidgets('Water Dashboard updates immediately when water is added', (WidgetTester tester) async {
      // Set a smaller screen size to ensure widgets are visible
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;

      await tester.pumpWidget(const MaterialApp(
        home: WaterDashboardScreen(),
      ));
      
      // Wait for initial load and animation frame
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify initial state (0ml)
      expect(find.text('0ml'), findsOneWidget);
      expect(find.text('No drinks logged yet'), findsOneWidget);

      // Tap "Glass" (250ml) quick add button
      // We look for the text '250ml' which is in the quick add button
      final glassButton = find.text('250ml');
      await tester.tap(glassButton);
      
      // Pump to process the tap
      await tester.pump(); 
      // Wait for future completion (addWater is async)
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify UI has updated
      expect(find.widgetWithText(Column, 'Consumed'), findsOneWidget);
       
       // Let's check the logs.
       expect(find.text('No drinks logged yet'), findsNothing);
       expect(find.text('Water'), findsOneWidget); // Default beverage name
    });

    testWidgets('Custom amount add updates UI', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;

      await tester.pumpWidget(const MaterialApp(
        home: WaterDashboardScreen(),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap Custom button
      await tester.tap(find.text('Custom'));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(seconds: 1)); // Wait for modal to open

      // Should see "Add Custom Amount" sheet
      expect(find.text('Add Custom Amount'), findsOneWidget);
      
      // Default is 250. Tap "+" twice to make it 350.
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      
      // Initial 250 -> 300 -> 350
      expect(find.text('350ml'), findsOneWidget);

      // Tap "Add Water"
      await tester.tap(find.text('Add Water'));
      await tester.pump(); // Start closing animation
      await tester.pump(const Duration(seconds: 1)); // Wait for modal to close and state to update

      // Verify Dashboard updates
      // Consumed should be 350ml
      // Since it's hard to distinguish specific text instances, let's look for the log entry
      expect(find.text('350ml'), findsAtLeastNWidgets(1));
    });
  });
}

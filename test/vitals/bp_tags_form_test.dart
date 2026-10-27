/// "What was going on?" on a blood-pressure reading.
///
/// A reading after a coffee or a run reads differently from a calm one, and a
/// doctor looking at a fortnight of numbers wants to know which were which. The
/// reading already carried a tags list that no control could set — and every edit
/// through the form silently wiped whatever was in it.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppChip;
import 'package:tablet_remainder/features/medication/models/blood_pressure_reading.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  Future<void> open(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const BloodPressureScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String sys, String dia) async {
    await tester.enterText(find.byType(TextFormField).at(0), sys);
    await tester.enterText(find.byType(TextFormField).at(1), dia);
  }

  testWidgets('the form offers the circumstances, each tickable', (tester) async {
    await open(tester);
    await tester.tap(find.text('Log reading'));
    await tester.pumpAndSettle();

    expect(find.text('Anything that might have affected it?'), findsOneWidget);
    for (final label in [
      'After exercise',
      'After caffeine',
      'After a meal',
      'Stressed',
      'Rushed',
      'Slept badly',
      'Missed my medicine',
      'At a clinic',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('ticked ones are saved, in a stable order', (tester) async {
    await open(tester);
    await tester.tap(find.text('Log reading'));
    await tester.pumpAndSettle();
    await enter(tester, '124', '82');

    // Ticked out of catalogue order.
    await tester.ensureVisible(find.text('Stressed'));
    await tester.tap(find.text('Stressed'));
    await tester.pump();
    await tester.ensureVisible(find.text('After caffeine'));
    await tester.tap(find.text('After caffeine'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save reading'));
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();

    final all = await tester.runAsync(() => VitalsStorageService.getAllBp());
    expect(all!.single.tags, ['after_caffeine', 'stressed']);
  });

  testWidgets('ticking again unticks', (tester) async {
    await open(tester);
    await tester.tap(find.text('Log reading'));
    await tester.pumpAndSettle();
    await enter(tester, '124', '82');
    await tester.ensureVisible(find.text('Rushed'));
    await tester.tap(find.text('Rushed'));
    await tester.pump();
    await tester.tap(find.text('Rushed'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save reading'));
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();

    final all = await tester.runAsync(() => VitalsStorageService.getAllBp());
    expect(all!.single.tags, isEmpty);
  });

  testWidgets('no circumstances is the usual case, and costs nothing', (tester) async {
    await open(tester);
    await tester.tap(find.text('Log reading'));
    await tester.pumpAndSettle();
    await enter(tester, '118', '76');
    await tester.ensureVisible(find.text('Save reading'));
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();

    final all = await tester.runAsync(() => VitalsStorageService.getAllBp());
    expect(all!.single.tags, isEmpty);
  });

  testWidgets('a second reading is the same sitting: the circumstances carry over',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('Log reading'));
    await tester.pumpAndSettle();
    await enter(tester, '130', '84');
    await tester.ensureVisible(find.text('After caffeine'));
    await tester.pump();
    await tester.tap(find.text('After caffeine'));
    await tester.pump();
    await tester.ensureVisible(find.text('Save reading'));
    await tester.pump();
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();

    expect(find.text('Take a second reading?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
    await tester.tap(find.text('Log second reading'));
    await tester.pumpAndSettle();

    expect(find.text('Second reading'), findsOneWidget);
    final chip = tester.widget<AppChip>(find.widgetWithText(AppChip, 'After caffeine'));
    expect(chip.selected, isTrue,
        reason: 'a second measurement a minute later is after the same coffee');

    await enter(tester, '126', '80');
    await tester.ensureVisible(find.text('Save reading'));
    await tester.pump();
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();

    final all = await tester.runAsync(() => VitalsStorageService.getAllBp());
    expect(all!.map((r) => r.tags), [
      ['after_caffeine'],
      ['after_caffeine'],
    ]);
  });

  group('an existing reading', () {
    /// The history row, not the summary cards that quote the same numbers.
    Future<void> openRow(WidgetTester tester) async {
      final row = find.text('130/85 mmHg').last;
      await tester.ensureVisible(row);
      await tester.pump();
      await tester.tap(row);
      await tester.pumpAndSettle();
    }

    Future<void> seed(WidgetTester tester, List<String> tags) async {
      await tester.runAsync(() => VitalsStorageService.saveBp(
          BloodPressureReading(
              id: 'bp-1',
              systolic: 130,
              diastolic: 85,
              takenAt: DateTime.now().subtract(const Duration(hours: 2)),
              createdAt: DateTime.now(),
              tags: tags),
          syncToHealthConnect: false));
    }

    testWidgets('shows its circumstances in the list', (tester) async {
      await seed(tester, ['after_exercise', 'stressed']);
      await open(tester);
      expect(find.textContaining('After exercise, Stressed'), findsOneWidget);
    });

    testWidgets('opens with them ticked, and an edit keeps them', (tester) async {
      await seed(tester, ['after_exercise']);
      await open(tester);
      await openRow(tester);

      await tester.ensureVisible(find.text('Save changes').evaluate().isEmpty
          ? find.text('Update reading')
          : find.text('Save changes'));
      await tester.tap(find.text('Update reading'));
      await tester.pumpAndSettle();

      final all = await tester.runAsync(() => VitalsStorageService.getAllBp());
      expect(all!.single.tags, ['after_exercise'],
          reason: 'an edit used to wipe tags the form had no control for');
    });

    testWidgets('a tag this build does not know survives an edit', (tester) async {
      await seed(tester, ['after_swim', 'stressed']);
      await open(tester);
      await openRow(tester);
      // Untick one it does know.
      await tester.ensureVisible(find.text('Stressed'));
      await tester.tap(find.text('Stressed'));
      await tester.pump();
      await tester.ensureVisible(find.text('Update reading'));
      await tester.tap(find.text('Update reading'));
      await tester.pumpAndSettle();

      final all = await tester.runAsync(() => VitalsStorageService.getAllBp());
      expect(all!.single.tags, ['after_swim'],
          reason: 'what another build wrote is not the form\'s to throw away');
    });

    testWidgets('and says it in the list: "After swim"', (tester) async {
      await seed(tester, ['after_swim']);
      await open(tester);
      expect(find.textContaining('After swim'), findsOneWidget);
    });
  });
}

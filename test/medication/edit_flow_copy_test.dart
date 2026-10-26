/// The add-medicine wizard doubles as the EDIT wizard, and has to say so.
///
/// `_isEditing` already drives the app bar title ("Edit medicine") and the
/// final button ("Save changes"). Step 1's headline did not, so editing
/// Metformin showed:
///
///     Edit medicine                  <- app bar
///     What medicine are you adding?  <- headline, directly beneath
///     [Metformin]                    <- the prefilled name field
///
/// Three lines in one viewport, one of them describing a different task.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_add_medication_flow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  EnhancedMedicine metformin() => EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        strength: '500mg',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        schedule: MedicineSchedule(
          frequencyType: FrequencyType.onceDaily,
          times: [ScheduledTime(hour: 8, minute: 0)],
        ),
      );

  Future<List<String>> pump(WidgetTester tester, {EnhancedMedicine? edit}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(411, 1200);
    addTearDown(tester.view.reset);

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: NunitoAddMedicationFlow(editMedicine: edit),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    } finally {
      FlutterError.onError = prev;
    }
    return tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  testWidgets('editing does not ask what you are adding', (tester) async {
    final texts = await pump(tester, edit: metformin());

    expect(texts, contains('Edit medicine'),
        reason: 'premise: the app bar already knows this is an edit. Without '
            'it this test is not on the edit flow at all.');

    expect(texts, isNot(contains('What medicine are you adding?')),
        reason: 'printed directly under "Edit medicine", above a name field '
            'prefilled with Metformin. Screen said:\n$texts');
    expect(texts, contains('What are you changing?'),
        reason: 'screen said:\n$texts');
  });

  testWidgets('adding still asks what you are adding', (tester) async {
    final texts = await pump(tester);

    expect(texts, contains('Add medicine'),
        reason: 'premise: this is the add flow');
    expect(texts, contains('What medicine are you adding?'),
        reason: 'the add-mode copy must survive the fix. Screen said:\n$texts');
    expect(texts, isNot(contains('What are you changing?')));
  });
}

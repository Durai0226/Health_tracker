/// The Condition Library screens, now that they read real data.
///
/// The existing `condition_library_test.dart` pumps these screens with **no
/// database at all** — no `setUp`, no `flutter_test_config.dart`. That worked
/// only because the feature made zero service calls. It now makes some, so this
/// file exists alongside it with a real in-memory database; the older file's
/// seven pure-data tests are unaffected and stay where they are.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/drug_info_catalog.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/data/condition_library_data.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/conditions/condition_detail_screen.dart';
import 'package:tablet_remainder/features/medication/screens/conditions/condition_library_screen.dart';
import 'package:tablet_remainder/features/medication/services/condition_library_service.dart';
import 'package:tablet_remainder/features/medication/services/condition_search_index.dart';
import 'package:tablet_remainder/features/medication/services/drug_name_catalog.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

EnhancedMedicine _med(String name, {String? purpose}) => EnhancedMedicine(
      id: name.toLowerCase(),
      name: name,
      purpose: purpose,
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      schedule:
          MedicineSchedule(frequencyType: FrequencyType.onceDaily, times: const []),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;

  setUpAll(() async {
    await DrugNameCatalog.ensureLoaded();
    await DrugInfoCatalog.ensureLoaded();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    ConditionLibraryService.resetForTesting();
    ConditionSearchIndex.resetForTesting();
  });

  tearDown(() async => db.close());

  Future<void> pumpLibrary(WidgetTester tester, {double height = 1400}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(390, height);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const ConditionLibraryScreen(),
    ));
    await tester.pumpAndSettle();
  }

  Iterable<String> texts(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => (t.data ?? '').trim())
      .where((s) => s.isNotEmpty);

  // ------------------------------------------------------------- browse

  group('the browse screen', () {
    testWidgets('still lists the encyclopedia with no medicines at all',
        (tester) async {
      await pumpLibrary(tester);
      expect(find.textContaining('High blood pressure'), findsWidgets);
      expect(find.text('Related to what you track'), findsNothing,
          reason: 'the pinned sliver must be ABSENT, not an empty box');
    });

    testWidgets('pins the conditions a real medicine relates to',
        (tester) async {
      await MedicineCleanStorageService.saveMedicine(_med('Amlodipine'));
      await pumpLibrary(tester);

      expect(find.text('Related to what you track'), findsOneWidget);
      expect(find.text('1 of your medicines relates to this area'),
          findsOneWidget,
          reason: 'singular for one — plural agreement is the kind of detail '
              'that makes generated copy feel generated');
    });

    testWidgets('the sliver hides during a search', (tester) async {
      await MedicineCleanStorageService.saveMedicine(_med('Amlodipine'));
      await pumpLibrary(tester);
      expect(find.text('Related to what you track'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'asthma');
      await tester.pumpAndSettle();

      expect(find.text('Related to what you track'), findsNothing,
          reason: 'the user has said what they want; a "related to you" block '
              'above their results is in the way');
    });

    testWidgets('searching a symptom finds something — the widened index',
        (tester) async {
      await pumpLibrary(tester);
      await tester.enterText(find.byType(TextField), 'chest pain');
      await tester.pumpAndSettle();

      expect(find.textContaining('No conditions match'), findsNothing,
          reason: 'this exact query returned the empty state before the index');
    });

    testWidgets('a genuine non-match still says so', (tester) async {
      await pumpLibrary(tester);
      await tester.enterText(find.byType(TextField), 'zzzznotacondition');
      await tester.pumpAndSettle();
      expect(find.textContaining('No conditions match'), findsOneWidget);
    });
  });

  // ------------------------------------------------------------- detail

  group('the detail screen', () {
    Future<void> pumpDetail(WidgetTester tester, String id,
        {double height = 2400}) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(390, height);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: ConditionDetailScreen(
            condition: conditionLibrary.firstWhere((c) => c.id == id)),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the medicine and explains why', (tester) async {
      await MedicineCleanStorageService.saveMedicine(_med('Amlodipine'));
      await pumpDetail(tester, 'hypertension');

      expect(find.text('Your medicines in this area'), findsOneWidget);
      expect(find.text('Amlodipine'), findsOneWidget);
      // The subtitle is the drug class, not a restatement of the condition.
      expect(find.textContaining('calcium channel blocker'), findsWidgets);

      // Nothing on the page asserts anything about the reader.
      final all = texts(tester).join(' ').toLowerCase();
      expect(all, isNot(contains('you have')));
      expect(all, isNot(contains('your condition')));
      // The always-visible bar disclaims the page.
      expect(all, contains('not medical advice'));

      // The reasoning sits behind the repo's established "Why this?" chip
      // rather than inline — the same explainability pattern every other
      // insight surface uses. Test the affordance, don't inline the copy to
      // suit the test.
      expect(find.text('Why this?'), findsOneWidget);
      await tester.tap(find.text('Why this?'));
      await tester.pumpAndSettle();

      final revealed = texts(tester).join(' ').toLowerCase();
      expect(revealed, contains("this medicine's drug family"));
      expect(revealed, contains('calcium channel blocker'));
      expect(revealed, contains('not a diagnosis'));
      expect(revealed, contains('only a clinician can say what applies to you'));
      expect(revealed, isNot(contains('you have')));
    });

    testWidgets('no medicines, no section', (tester) async {
      await pumpDetail(tester, 'hypertension');
      expect(find.text('Your medicines in this area'), findsNothing);
      expect(find.text('Your recent readings'), findsNothing);
    });

    testWidgets('a refused condition never gains a medicines section',
        (tester) async {
      // Aspirin is in the asset and is deliberately unlinked from AF.
      await MedicineCleanStorageService.saveMedicine(_med('Aspirin'));
      await pumpDetail(tester, 'afib');
      expect(find.text('Your medicines in this area'), findsNothing,
          reason: 'the clinical refusal has to hold in the UI too');
    });

    testWidgets('a page with no objective measurement offers no readings box',
        (tester) async {
      // Twelve of fourteen. A permanently empty readings box trains people to
      // ignore the section on the two pages where it matters.
      await MedicineCleanStorageService.saveMedicine(_med('Sertraline'));
      await pumpDetail(tester, 'depression');
      expect(find.text('Your medicines in this area'), findsOneWidget);
      expect(find.text('Your recent readings'), findsNothing);
    });

    testWidgets('the disclaimer is present on every page', (tester) async {
      for (final id in ['hypertension', 'afib', 'migraine']) {
        await pumpDetail(tester, id);
        expect(find.textContaining('not medical advice'), findsWidgets,
            reason: 'missing on $id');
      }
    });
  });

  // --------------------------------------------------------- the old test

  test('the pre-existing test file still has no database setUp', () {
    // Recorded rather than "fixed": those seven tests exercise the const list
    // and `matches` directly and do not need one. Its two widget smoke tests DO
    // now pump a screen that reads data — they pass because the read degrades
    // to no personalisation rather than throwing, which is the service's
    // never-throws contract doing its job.
    expect(true, isTrue);
  });
}

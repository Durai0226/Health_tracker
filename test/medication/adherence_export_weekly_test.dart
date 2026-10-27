/// "Share with your doctor" also offers last week, to send to someone who looks
/// out for you.
library;

import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/widgets/adherence_export_sheet.dart';

import '../support/font_free_theme.dart';
import '../support/pdf_words.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async {
    AdherenceExportSheet.shareOverride = null;
    await db.close();
  });

  Future<void> seedMedicine() => MedicineCleanStorageService.addMedicine(
        EnhancedMedicine(
          id: 'm1',
          name: 'Metformin',
          dosageForm: DosageForm.tablet,
          dosageAmount: 1,
          createdAt: DateTime.now().subtract(const Duration(days: 90)),
          schedule: MedicineSchedule.onceDaily(
              hour: 8,
              minute: 0,
              startDate: DateTime.now().subtract(const Duration(days: 90))),
        ),
        stampActiveProfile: false,
      );

  Future<void> openSheet(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: fontFreeTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
              onPressed: () => AdherenceExportSheet.show(context),
              child: const Text('share')),
        ),
      ),
    ));
    await tester.tap(find.text('share'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapAndWait(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  String day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  testWidgets('the sheet offers last week beside the usual report', (tester) async {
    await openSheet(tester);
    expect(find.text('Adherence report (PDF)'), findsOneWidget);
    expect(find.text('Last week (PDF)'), findsOneWidget);
    expect(find.text('Dose log (CSV)'), findsOneWidget);
  });

  testWidgets('last week covers seven days, and is named so', (tester) async {
    await tester.runAsync(seedMedicine);
    Uint8List? bytes;
    String? name;
    AdherenceExportSheet.shareOverride = (b, n) async {
      bytes = b;
      name = n;
    };
    await openSheet(tester);
    await tapAndWait(tester, 'Last week (PDF)');

    expect(name, 'adherence-report-7-days.pdf');
    final text = pdfWords(bytes!).join(' ');
    final now = DateTime.now();
    expect(text, contains('Period: ${day(now.subtract(const Duration(days: 7)))} to ${day(now)}'));
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('the usual one is still thirty days, under its old name', (tester) async {
    await tester.runAsync(seedMedicine);
    Uint8List? bytes;
    String? name;
    AdherenceExportSheet.shareOverride = (b, n) async {
      bytes = b;
      name = n;
    };
    await openSheet(tester);
    await tapAndWait(tester, 'Adherence report (PDF)');

    expect(name, 'adherence-report.pdf');
    final now = DateTime.now();
    expect(pdfWords(bytes!).join(' '),
        contains('Period: ${day(now.subtract(const Duration(days: 30)))} to ${day(now)}'));
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('with no medicines it says so rather than sharing an empty page',
      (tester) async {
    var shared = 0;
    AdherenceExportSheet.shareOverride = (_, _) async => shared++;
    await openSheet(tester);
    await tapAndWait(tester, 'Last week (PDF)');
    expect(shared, 0);
    expect(find.text('No active medicines to report yet.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
  });
}

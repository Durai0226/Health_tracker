/// "Ibuprofen · 3 h ago · 2 of 4 · OK after 2:30 PM", with a one-tap Take.
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';
import 'package:tablet_remainder/features/home/widgets/as_needed_card.dart';
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/services/as_needed_service.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  final now = DateTime(2026, 6, 20, 15, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    MedicineCleanStorageService.revision.value = 0;
  });

  tearDown(() async => db.close());

  Future<void> medicine(
    String id,
    String name, {
    bool asNeeded = true,
    int? max,
    int? hours,
    int? stock,
    double dose = 1,
  }) =>
      MedicineCleanStorageService.addMedicine(EnhancedMedicine(
        id: id,
        name: name,
        dosageForm: DosageForm.tablet,
        dosageAmount: dose,
        currentStock: stock,
        createdAt: now.subtract(const Duration(days: 30)),
        schedule: asNeeded
            ? MedicineSchedule(
                frequencyType: FrequencyType.asNeeded,
                times: const [],
                isPRN: true,
                maxDailyDoses: max,
                minHoursBetweenDoses: hours,
              )
            : MedicineSchedule(
                frequencyType: FrequencyType.onceDaily,
                times: [ScheduledTime(hour: 9, minute: 0)],
              ),
      ));

  Future<void> took(String id, Duration ago) {
    final at = now.subtract(ago);
    return MedicineCleanStorageService.addLog(MedicineLog.taken(
      id: MedicineCleanStorageService.doseLogId(id, at),
      medicineId: id,
      scheduledTime: at,
      actionTime: at,
    ));
  }

  Future<R> pinned<R>(Future<R> Function() body) => withClock(Clock.fixed(now), body);

  group('the statuses', () {
    test('only active as-needed medicines', () async {
      await pinned(() async {
        await medicine('a', 'Ibuprofen');
        await medicine('b', 'Metformin', asNeeded: false);
        final es = await AsNeededService.entries(now: now);
        expect(es.map((e) => e.medicine.name), ['Ibuprofen']);
      });
    });

    test('built from the medicine\'s own limits and its taken doses', () async {
      await pinned(() async {
        await medicine('a', 'Ibuprofen', max: 4, hours: 6);
        await took('a', const Duration(hours: 3));
        await took('a', const Duration(hours: 9));
        final s = (await AsNeededService.entries(now: now)).single.status;
        expect(s.takenIn24h, 2);
        expect(s.maxPer24h, 4);
        expect(s.okFrom, now.add(const Duration(hours: 3)));
      });
    });

    test('a skipped or missed dose is not a dose taken', () async {
      await pinned(() async {
        await medicine('a', 'Ibuprofen', max: 4, hours: 6);
        final at = now.subtract(const Duration(hours: 2));
        await MedicineCleanStorageService.addLog(MedicineLog.skipped(
          id: MedicineCleanStorageService.doseLogId('a', at),
          medicineId: 'a',
          scheduledTime: at,
          reason: SkipReason.other,
        ).copyWith(actionTime: at));
        final s = (await AsNeededService.entries(now: now)).single.status;
        expect(s.takenIn24h, 0);
        expect(s.allowedNow, isTrue);
      });
    });

    test('takeNow logs a dose at this moment and takes the stock down', () async {
      await pinned(() async {
        await medicine('a', 'Ibuprofen', stock: 10, dose: 2);
        final log = await AsNeededService.takeNow(
            (await MedicineCleanStorageService.getMedicine('a'))!,
            now: now);
        expect(log.countsAsTaken, isTrue);
        expect(log.scheduledTime, now);
        expect((await MedicineCleanStorageService.getMedicine('a'))!.currentStock, 8);
      });
    });
  });

  test('Today has it, under the next-dose hero and above the briefing', () {
    final src = File('lib/features/home/screens/home_dashboard.dart').readAsStringSync();
    final hero = src.indexOf('_buildNextDoseHero(ext),');
    final card = src.indexOf('AsNeededCard(medicines:');
    final briefing = src.indexOf('_buildBriefingStrip(ext),');
    expect(hero, greaterThan(0));
    expect(card, greaterThan(hero));
    expect(briefing, greaterThan(card));
  });

  testWidgets('Today shows it, from the medicines Today read', (tester) async {
    await pinned(() async {
      await medicine('a', 'Ibuprofen', max: 4, hours: 6);
      await took('a', const Duration(hours: 3));
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 2400);
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {}; // overflow is the responsive suite's job
      try {
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme,
            home: HomeDashboard(onNavigate: (int i, {int? healthTab}) {})));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      } finally {
        FlutterError.onError = prev;
      }
      expect(find.text('As needed'), findsOneWidget);
      expect(find.text('3 h ago · 1 of 4 · OK after 6:00 PM'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });
  });

  group('the card', () {
    Future<void> pump(WidgetTester tester, {double width = 430, double scale = 1}) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 2400);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: SingleChildScrollView(child: AsNeededCard()))));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('says where each stands, in words', (tester) async {
      await pinned(() async {
        await medicine('a', 'Ibuprofen', max: 4, hours: 6);
        await took('a', const Duration(hours: 3));
        await took('a', const Duration(hours: 9));
        await pump(tester);

        expect(find.text('As needed'), findsOneWidget);
        expect(find.text('Ibuprofen'), findsOneWidget);
        expect(find.text('3 h ago · 2 of 4 · OK after 6:00 PM'), findsOneWidget);
        expect(find.textContaining('Follow the label'), findsOneWidget);
      });
    });

    testWidgets('given the medicines, it reads none of its own', (tester) async {
      await pinned(() async {
        // The database holds an as-needed medicine; the screen was handed a list
        // without it. The card believes the list.
        await medicine('a', 'Ibuprofen');
        final all = await MedicineCleanStorageService.getAllMedicines();
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 2400);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
                body: SingleChildScrollView(
                    child: AsNeededCard(medicines: [
              for (final m in all)
                if (!m.schedule.isPRN) m,
            ])))));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('As needed'), findsNothing);
      });
    });

    testWidgets('and shows what it was given, not what the database holds',
        (tester) async {
      await pinned(() async {
        await medicine('a', 'Ibuprofen', max: 4, hours: 6);
        final given = await MedicineCleanStorageService.getAllMedicines();
        // Remove the row: the list the screen holds is all there is.
        await MedicineCleanStorageService.deleteMedicine('a');
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(430, 2400);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
                body: SingleChildScrollView(child: AsNeededCard(medicines: given)))));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Ibuprofen'), findsOneWidget);
      });
    });

    testWidgets('nothing without an as-needed medicine', (tester) async {
      await pinned(() async {
        await medicine('b', 'Metformin', asNeeded: false);
        await pump(tester);
        expect(find.text('As needed'), findsNothing);
      });
    });

    testWidgets('one tap logs a dose that is OK, and says so with an Undo',
        (tester) async {
      await pinned(() async {
        await medicine('a', 'Ibuprofen', max: 4, hours: 6, stock: 10);
        await pump(tester);
        expect(find.text('Not taken in 24 h · 0 of 4 · OK now'), findsOneWidget);

        await tester.tap(find.text('Take'));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.text('Ibuprofen taken'), findsOneWidget);
        expect(await MedicineCleanStorageService.getLogsForMedicine('a'), hasLength(1));
        expect((await MedicineCleanStorageService.getMedicine('a'))!.currentStock, 9);

        await tester.tap(find.text('Undo'));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(await MedicineCleanStorageService.getLogsForMedicine('a'), isEmpty);
        expect((await MedicineCleanStorageService.getMedicine('a'))!.currentStock, 10,
            reason: 'Undo puts the unit back');
      });
    });

    testWidgets('a dose that is not yet OK asks first, and "Not now" logs nothing',
        (tester) async {
      await pinned(() async {
        await medicine('a', 'Ibuprofen', max: 4, hours: 6);
        await took('a', const Duration(hours: 1));
        await pump(tester);

        await tester.tap(find.text('Take'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('A little early'), findsOneWidget);
        expect(find.textContaining('not up until 8:00 PM'), findsOneWidget,
            reason: 'taken at 2 PM with a six-hour gap');

        await tester.tap(find.text('Not now'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(await MedicineCleanStorageService.getLogsForMedicine('a'), hasLength(1));
      });
    });

    testWidgets('and "Log it" logs it anyway: nothing is blocked', (tester) async {
      await pinned(() async {
        await medicine('a', 'Ibuprofen', max: 4, hours: 6);
        await took('a', const Duration(hours: 1));
        await pump(tester);

        await tester.tap(find.text('Take'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.tap(find.text('Log it'));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(await MedicineCleanStorageService.getLogsForMedicine('a'), hasLength(2));
      });
    });

    testWidgets('at the daily limit the question says so', (tester) async {
      await pinned(() async {
        await medicine('a', 'Ibuprofen', max: 2);
        await took('a', const Duration(hours: 10));
        await took('a', const Duration(hours: 2));
        await pump(tester);

        expect(find.textContaining('Limit reached'), findsOneWidget);
        await tester.tap(find.text('Take'));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Daily limit reached'), findsOneWidget);
      });
    });

    testWidgets('the first three, and the rest in Medicines', (tester) async {
      await pinned(() async {
        for (var i = 0; i < 5; i++) {
          await medicine('m$i', 'Medicine $i');
        }
        await pump(tester);
        expect(find.text('Take'), findsNWidgets(AsNeededCard.maxShown));
        expect(find.text('And 2 more in Medicines.'), findsOneWidget);
      });
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('fits at 320pt and ${scale}x text', (tester) async {
        await pinned(() async {
          await medicine('a', 'Ibuprofen 400 mg film-coated tablets', max: 4, hours: 6);
          await took('a', const Duration(hours: 3));
          final reports = <String>[];
          final prev = FlutterError.onError;
          FlutterError.onError = (d) => reports.add(d.toString());
          try {
            await pump(tester, width: 320, scale: scale);
          } finally {
            FlutterError.onError = prev;
          }
          expect(find.text('As needed'), findsOneWidget);
          expect(reports.where((r) => r.contains('as_needed_card.dart')), isEmpty);
        });
      });
    }
  });
}

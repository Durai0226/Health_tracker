/// The medicine's history: every dose, and a way to put one right.
///
/// The page showed the last five doses with nothing to tap. A dose from two
/// months ago that was written down wrong had nowhere to be seen, let alone
/// corrected.
library;

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppChip;
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_log.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/medicine_history_screen.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_detail_screen.dart';
import 'package:tablet_remainder/features/medication/services/dose_history_edit.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';
import 'package:tablet_remainder/features/medication/widgets/dose_edit_sheet.dart';
import 'package:tablet_remainder/features/medication/widgets/dose_log_row.dart';

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

  EnhancedMedicine medicine({bool asNeeded = false}) => EnhancedMedicine(
        id: 'm1',
        name: 'Metformin',
        dosageForm: DosageForm.tablet,
        dosageAmount: 1,
        currentStock: 30,
        schedule: asNeeded
            ? MedicineSchedule.asNeeded()
            : MedicineSchedule(
                frequencyType: FrequencyType.onceDaily,
                times: [ScheduledTime(hour: 8, minute: 0)],
                startDate: DateTime(2025, 12, 1),
              ),
        createdAt: DateTime(2025, 12, 1),
      );

  MedicineLog log(MedicineStatus status, {DateTime? slot, DateTime? at}) {
    final when = slot ?? DateTime(2026, 3, 10, 8);
    return MedicineLog(
      id: 'l-${when.millisecondsSinceEpoch}',
      medicineId: 'm1',
      scheduledTime: when,
      status: status,
      actionTime: at,
    );
  }

  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  void quietOverflow() {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!'${d.exception}'.contains('overflowed')) prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
  }

  group('the sheet', () {
    Future<DoseEdit?> tapAndRead(
        WidgetTester tester, MedicineLog l, String label,
        {EnhancedMedicine? med}) async {
      quietOverflow();
      DoseEdit? got;
      await tester.pumpWidget(host(DoseEditBody(
          log: l,
          medicine: med ?? medicine(),
          onEdit: (e) => got = e,
          onClose: () {})));
      await tester.tap(find.text(label));
      await tester.pump();
      return got;
    }

    Future<void> pump(WidgetTester tester, MedicineLog l, {EnhancedMedicine? med}) async {
      quietOverflow();
      await tester.pumpWidget(host(DoseEditBody(
          log: l, medicine: med ?? medicine(), onEdit: (_) {}, onClose: () {})));
    }

    testWidgets('names the medicine, when it was due and what it says now',
        (tester) async {
      await pump(
          tester,
          log(MedicineStatus.taken,
              at: DateTime(2026, 3, 10, 8, 10)));
      expect(find.text('Metformin'), findsOneWidget);
      expect(find.textContaining('8:00 AM'), findsWidgets);
      expect(find.text('Now: Taken at 8:10 AM'), findsOneWidget);
    });

    testWidgets('a missed dose: it was taken, or it was not', (tester) async {
      await pump(tester, log(MedicineStatus.missed));
      expect(find.text('Now: Missed'), findsOneWidget);
      expect(find.text('I took it at 8:00 AM'), findsOneWidget);
      expect(find.text('I took it at…'), findsOneWidget);
      expect(find.text('I did not take it'), findsOneWidget);
      expect(find.text('Remove this entry'), findsNothing,
          reason: 'the next sweep would only write the miss again');
    });

    testWidgets('a taken dose: change the time, say it was not taken, or remove it',
        (tester) async {
      await pump(tester, log(MedicineStatus.taken, at: DateTime(2026, 3, 10, 8, 10)));
      expect(find.text('Change the time taken'), findsOneWidget);
      expect(find.text('I did not take it'), findsOneWidget);
      expect(find.text('Remove this entry'), findsOneWidget);
      expect(find.text('I took it at 8:00 AM'), findsNothing,
          reason: 'it is already taken');
    });

    testWidgets('a skipped dose: it was taken after all', (tester) async {
      await pump(tester, log(MedicineStatus.skipped));
      expect(find.text('Now: Skipped'), findsOneWidget);
      expect(find.text('I took it at 8:00 AM'), findsOneWidget);
      expect(find.text('I did not take it'), findsNothing);
    });

    testWidgets('each button answers with its own correction', (tester) async {
      expect((await tapAndRead(tester, log(MedicineStatus.missed), 'I took it at 8:00 AM'))
              ?.correction,
          DoseCorrection.tookAtSlot);
      expect((await tapAndRead(tester, log(MedicineStatus.missed), 'I did not take it'))
              ?.correction,
          DoseCorrection.didNotTake);
      expect((await tapAndRead(tester, log(MedicineStatus.skipped), 'Remove this entry'))
              ?.correction,
          DoseCorrection.remove);
    });

    testWidgets('says a removed dose that was due comes back as missed', (tester) async {
      await pump(tester, log(MedicineStatus.taken, at: DateTime(2026, 3, 10, 8, 10)));
      expect(find.textContaining('comes back as missed'), findsOneWidget);
    });

    testWidgets('but not for an as-needed medicine, which has no slot to miss',
        (tester) async {
      await pump(tester, log(MedicineStatus.taken, at: DateTime(2026, 3, 10, 8, 10)),
          med: medicine(asNeeded: true));
      expect(find.text('Remove this entry'), findsOneWidget);
      expect(find.textContaining('comes back as missed'), findsNothing);
    });

    testWidgets('Close answers nothing', (tester) async {
      var closed = 0;
      quietOverflow();
      await tester.pumpWidget(host(DoseEditBody(
          log: log(MedicineStatus.missed),
          medicine: medicine(),
          onEdit: (_) => fail('a close is not a correction'),
          onClose: () => closed++)));
      await tester.tap(find.text('Close'));
      expect(closed, 1);
    });

    for (final (width, scale) in [(320.0, 1.0), (320.0, 2.0)]) {
      testWidgets('fits $width wide at ${scale}x text', (tester) async {
        final errors = <FlutterErrorDetails>[];
        final prev = FlutterError.onError;
        FlutterError.onError = errors.add;
        try {
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = Size(width, 2400);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          addTearDown(tester.view.reset);
          await tester.pumpWidget(host(DoseEditBody(
              log: log(MedicineStatus.taken, at: DateTime(2026, 3, 10, 8, 10)),
              medicine: medicine(),
              onEdit: (_) {},
              onClose: () {})));
        } finally {
          FlutterError.onError = prev;
        }
        expect(errors.where((e) => '${e.exception}'.contains('overflowed')), isEmpty);
      });
    }
  });

  group('the row', () {
    testWidgets('is tappable only when given something to do', (tester) async {
      quietOverflow();
      var taps = 0;
      await tester.pumpWidget(host(Column(children: [
        DoseLogRow(log: log(MedicineStatus.taken), onTap: () => taps++),
        DoseLogRow(log: log(MedicineStatus.missed)),
      ])));

      final chevron = find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Symbols.chevron_right_rounded);
      expect(chevron, findsOneWidget,
          reason: 'only the row with something to do shows that it can be tapped');
      await tester.tap(find.text('Taken'));
      expect(taps, 1);
      expect(DoseLogRow.statusLabel(log(MedicineStatus.skipped)), 'Skipped');
      expect(DoseLogRow.statusLabel(log(MedicineStatus.preLogged)), 'Pre-logged');
    });
  });

  group('the full history', () {
    /// Three taken in March, two skipped in February, three missed in January.
    Future<void> seedEight() async {
      await MedicineCleanStorageService.saveMedicine(medicine());
      final entries = <(DateTime, MedicineStatus)>[
        for (final d in [10, 11, 12])
          (DateTime(2026, 3, d, 8), MedicineStatus.taken),
        for (final d in [3, 4]) (DateTime(2026, 2, d, 8), MedicineStatus.skipped),
        for (final d in [5, 6, 7]) (DateTime(2026, 1, d, 8), MedicineStatus.missed),
      ];
      for (final (slot, status) in entries) {
        await MedicineCleanStorageService.addLog(MedicineLog(
          id: MedicineCleanStorageService.doseLogId('m1', slot),
          medicineId: 'm1',
          scheduledTime: slot,
          status: status,
          actionTime: status == MedicineStatus.taken ? slot : null,
        ));
      }
    }

    Future<void> open(WidgetTester tester) async {
      quietOverflow();
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 2400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: MedicineHistoryScreen(medicine: medicine()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('lists every dose newest first, by month, with a count', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 20, 9)), () async {
        await seedEight();
        await open(tester);

        expect(find.text('8 doses · 3 taken · 2 skipped · 3 missed'), findsOneWidget);
        final march = tester.getTopLeft(find.text('March 2026')).dy;
        final feb = tester.getTopLeft(find.text('February 2026')).dy;
        final jan = tester.getTopLeft(find.text('January 2026')).dy;
        expect(march, lessThan(feb));
        expect(feb, lessThan(jan));
        expect(find.byType(DoseLogRow), findsNWidgets(8));
      });
    });

    testWidgets('a filter narrows it, and says when nothing matches', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 20, 9)), () async {
        await seedEight();
        await open(tester);

        await tester.tap(find.widgetWithText(AppChip, 'Missed'));
        await tester.pump();
        expect(find.byType(DoseLogRow), findsNWidgets(3));
        expect(find.text('January 2026'), findsOneWidget);
        expect(find.text('March 2026'), findsNothing);

        await tester.tap(find.widgetWithText(AppChip, 'Skipped'));
        await tester.pump();
        expect(find.byType(DoseLogRow), findsNWidgets(2));
      });
    });

    testWidgets('an empty history says so', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 20, 9)), () async {
        await MedicineCleanStorageService.saveMedicine(medicine());
        await open(tester);
        expect(find.text('No doses recorded yet'), findsOneWidget);
        expect(find.byType(DoseLogRow), findsNothing);
      });
    });

    testWidgets('a missed dose can be opened and marked taken — and Undo puts it back',
        (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 20, 9)), () async {
        await seedEight();
        await open(tester);

        await tester.tap(find.widgetWithText(AppChip, 'Missed'));
        await tester.pump();
        await tester.tap(find.byType(DoseLogRow).first);
        await tester.pumpAndSettle();
        expect(find.text('Change this dose'), findsOneWidget);

        await tester.tap(find.text('I took it at 8:00 AM'));
        await tester.pumpAndSettle();

        expect(find.text('Dose updated'), findsOneWidget);
        await tester.tap(find.widgetWithText(AppChip, 'All'));
        await tester.pumpAndSettle();
        expect(find.text('8 doses · 4 taken · 2 skipped · 2 missed'), findsOneWidget,
            reason: 'the list read the dose again');
        final stored = await MedicineCleanStorageService.getLog(
            MedicineCleanStorageService.doseLogId('m1', DateTime(2026, 1, 7, 8)));
        expect(stored!.isTaken, isTrue);

        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect(find.text('8 doses · 3 taken · 2 skipped · 3 missed'), findsOneWidget);
        await tester.pump(const Duration(seconds: 8));
      });
    });
  });

  group('on the medicine\'s page', () {
    Future<void> openDetail(WidgetTester tester, int doses) async {
      quietOverflow();
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 3600);
      addTearDown(tester.view.reset);
      await MedicineCleanStorageService.saveMedicine(medicine());
      for (var i = 0; i < doses; i++) {
        final slot = DateTime(2026, 3, 1 + i, 8);
        await MedicineCleanStorageService.addLog(MedicineLog(
          id: MedicineCleanStorageService.doseLogId('m1', slot),
          medicineId: 'm1',
          scheduledTime: slot,
          status: MedicineStatus.taken,
          actionTime: slot,
        ));
      }
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: NunitoMedicationDetailScreen(medicine: medicine()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('more than five doses offers all of them', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 20, 9)), () async {
        await openDetail(tester, 12);
        expect(find.text('Show all 12 doses'), findsOneWidget);

        await tester.ensureVisible(find.text('Show all 12 doses'));
        await tester.pump();
        await tester.tap(find.text('Show all 12 doses'));
        await tester.pumpAndSettle();

        expect(find.byType(MedicineHistoryScreen), findsOneWidget);
        expect(find.byType(DoseLogRow), findsNWidgets(12));
      });
    });

    testWidgets('five or fewer have nothing more to show', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 20, 9)), () async {
        await openDetail(tester, 4);
        expect(find.textContaining('Show all'), findsNothing);
        expect(find.byType(DoseLogRow), findsNWidgets(4));
      });
    });

    testWidgets('a dose in the short list opens for correction', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 20, 9)), () async {
        await openDetail(tester, 3);

        await tester.ensureVisible(find.byType(DoseLogRow).first);
        await tester.pump();
        await tester.tap(find.byType(DoseLogRow).first);
        await tester.pumpAndSettle();

        expect(find.text('Change this dose'), findsOneWidget);
        expect(find.text('Change the time taken'), findsOneWidget);
      });
    });
  });
}

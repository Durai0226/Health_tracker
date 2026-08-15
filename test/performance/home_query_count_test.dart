@Tags(['performance'])
library;

/// Loading the Today surface must not re-read the same tables per consumer.
///
/// `_loadMedicineData()` awaited four service calls in series —
/// `getDailySummaryAsync`, `getAllMedicines`, `getCurrentStreak`,
/// `getTodaysDoses` — and each re-fetched what it needed. Measured against a
/// real in-memory database, one Home load issued **6 reads of
/// `enhanced_medicines` and 4 of `medicine_logs`**. `getAllMedicines()` re-maps
/// every row and re-decodes every schedule JSON, so the duplicates cost CPU on
/// the UI isolate, not just round trips. Sharing one fetch brings that to 4 and
/// 3 (the remainder belong to other Today cards).
///
/// NOTE ON THE MATCHER: the Drift table is `enhanced_medicines`, not
/// `medicines`. An earlier version of this file matched `from "medicines"`,
/// matched nothing, and therefore passed with the bug deliberately restored.
/// The thresholds below are measured numbers, not guesses, for that reason.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_header.dart';
import 'package:tablet_remainder/features/home/screens/home_dashboard.dart';

import '../support/counting_executor.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_dashboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CountingExecutor counter;
  late AppDatabase db;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    counter = CountingExecutor(NativeDatabase.memory())..recording = false;
    db = AppDatabase.forTesting(counter);
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  Future<void> pumpHome(WidgetTester tester, {double width = 390}) async {
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(size: Size(width, 844)),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: HomeDashboard(onNavigate: (int i, {int? healthTab}) {}),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('one Home load does not re-read the same tables per consumer',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      counter.recording = true;
      await pumpHome(tester);
      counter.recording = false;
    } finally {
      FlutterError.onError = prev;
    }

    final t = counter.tally;
    expect(
      t['enhanced_medicines'] ?? 0,
      lessThanOrEqualTo(4),
      reason: 'enhanced_medicines was read ${t['enhanced_medicines']} times '
          'for one Home load. Measured: 4 with a shared fetch, 6 when '
          '_loadMedicineData let getDailySummaryAsync, getTodaysDoses and the '
          'bare getAllMedicines each pull their own copy. Full tally: $t',
    );
    expect(
      t['medicine_logs'] ?? 0,
      lessThanOrEqualTo(3),
      reason: 'medicine_logs was read ${t['medicine_logs']} times. Measured: 3 '
          'shared, 4 duplicated. Full tally: $t',
    );

    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('the medication dashboard does not re-read medicines per consumer',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      counter.recording = true;
      await tester.pumpWidget(const MaterialApp(
        home: NunitoMedicationDashboard(),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));
      counter.recording = false;
    } finally {
      FlutterError.onError = prev;
    }

    final t = counter.tally;
    expect(
      t['enhanced_medicines'] ?? 0,
      lessThanOrEqualTo(4),
      reason: 'enhanced_medicines was read ${t['enhanced_medicines']} times for '
          'one dashboard open. Measured: 4 once _buildTodaySchedule and '
          'getAdherenceStats reuse the list this screen already loaded, 6 when '
          'each re-fetched its own copy. Full tally: $t',
    );

    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('the header profile future survives a rebuild', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Object? headerFuture() {
      final f = find.descendant(
        of: find.byType(AppHeader),
        matching: find.byType(FutureBuilder<String>),
      );
      if (f.evaluate().isEmpty) return null;
      return (f.evaluate().first.widget as FutureBuilder<String>).future;
    }

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {};
    try {
      await pumpHome(tester);
      final before = headerFuture();
      // `isNotNull` is ambiguous here: drift exports one and matcher exports
      // another. Compare explicitly rather than adding an import shadow.
      expect(before != null, isTrue,
          reason: 'the header profile FutureBuilder was not found');

      // Force a genuine rebuild of the subtree WITHOUT changing the active
      // profile, by changing an inherited value the tree depends on. The State
      // (and therefore the memo) survives, so a correct implementation hands
      // back the same Future.
      await pumpHome(tester, width: 391);

      expect(
        identical(before, headerFuture()),
        isTrue,
        reason: 'The profile-label Future was reconstructed on rebuild. Built '
            'inline in build(), it re-queries the dependents table and — '
            'because FutureBuilder resubscribes when the Future identity '
            'changes — flashes the "Me" fallback before resolving. Home '
            'rebuilds once a second while a Focus timer runs, so that is once '
            'per second for the length of the session.',
      );
    } finally {
      FlutterError.onError = prev;
    }

    await tester.pump(const Duration(seconds: 8));
  });
}

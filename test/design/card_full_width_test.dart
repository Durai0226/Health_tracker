/// Cards must fill their column, not shrink to their contents.
///
/// `docs/ui-audit.md` logged this as a P1 that outlived two passes: the
/// adherence Overview card sat at ~60% width, visibly out of line with the
/// SectionHeader above it and the StatTileRow below it. The cause is easy to
/// reintroduce and invisible in review — every OTHER section on that screen
/// happens to contain a Row/Expanded and so fills the column for free, while
/// this one's contents are all intrinsically sized (a fixed-diameter ring and
/// two centred labels), so under the parent's loose constraints it shrank to
/// the ring's width.
///
/// Asserted as RENDERED GEOMETRY rather than by grepping for the fix, because
/// there are several correct ways to write it (`CrossAxisAlignment.stretch`, a
/// `SizedBox(width: double.infinity)`, an `Expanded` inside a Row) and a source
/// guard would pass or fail on the spelling instead of the result.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_card.dart';
import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart';
import 'package:tablet_remainder/core/dev/qa_seed.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/medication/screens/analytics/nunito_adherence_report_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// A column whose children are all intrinsically sized — the shape that
  /// shrank. Mirrors the Overview card: a fixed-size disc and centred labels.
  Widget intrinsicCard({required bool stretched}) {
    final card = AppCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(width: 148, height: 148),
          Text('Adherence'),
        ],
      ),
    );
    return stretched ? SizedBox(width: double.infinity, child: card) : card;
  }

  Future<double> cardWidth(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [child],
          ),
        ),
      ),
    ));
    await tester.pump();
    return tester.getSize(find.byType(AppCard)).width;
  }

  const available = 390.0 - 32; // the 16pt padding either side

  testWidgets('negative: an intrinsically-sized card DOES shrink unaided',
      (tester) async {
    final w = await cardWidth(tester, intrinsicCard(stretched: false));
    expect(w, lessThan(available),
        reason: 'if this no longer shrinks, the positive assertion below is '
            'vacuous and this whole file needs rewriting');
  });

  testWidgets('positive: stretching it fills the column', (tester) async {
    final w = await cardWidth(tester, intrinsicCard(stretched: true));
    expect(w, closeTo(available, 0.5),
        reason: 'a card out of line with the SectionHeader above it and the '
            'StatTileRow below it reads as a rendering bug');
  });

  testWidgets('the real Overview card fills the column', (tester) async {
    // The mirror above proves the MECHANISM; this proves the screen. A guard
    // that only tests a lookalike passes happily while the real card shrinks.
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    addTearDown(() async => db.close());
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
    await withClock(
        Clock.fixed(DateTime(2026, 4, 15, 10)), () => seedQaData(force: true));

    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prev = FlutterError.onError;
    FlutterError.onError = (_) {}; // overflow is the responsive suite's job
    try {
      await tester.pumpWidget(const MaterialApp(
        home: NunitoAdherenceReportScreen(),
      ));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final cards = find.byType(AppCard);
      expect(cards, findsWidgets, reason: 'the report should render cards');
      // The Overview card is the first one on the screen.
      final w = tester.getSize(cards.first).width;
      final screenW = tester.getSize(find.byType(MaterialApp)).width;
      expect(w, greaterThan(screenW * 0.85),
          reason: 'it sat at ~60% of the column, out of line with the '
              'SectionHeader above and the StatTileRow below it');
    } finally {
      FlutterError.onError = prev;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 8));
    }
  });
}

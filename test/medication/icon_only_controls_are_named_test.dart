/// Icon-only medication controls announce a name.
///
/// Two of them drew an icon (or a bare colour) inside a `GestureDetector` and
/// nothing else: the refill sheet's −/+ stepper and the appearance step's
/// colour swatch. A `GestureDetector` takes no `tooltip:`, so neither was
/// visible to the `IconButton` rule in `test/design/design_tokens_guard_test`,
/// and both reached the semantics tree as a tappable node with an EMPTY label
/// — VoiceOver and TalkBack read them out as nothing at all.
///
/// The source guard pins the spelling; this pins the behaviour, by reading the
/// live semantics tree of the real screens. A `Semantics` wrapper that fails to
/// merge with the `GestureDetector` under it, or one whose label never reaches
/// a node carrying the tap action, passes the guard and fails here.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart' show AppTextField;
import 'package:tablet_remainder/features/medication/models/enhanced_medicine.dart';
import 'package:tablet_remainder/features/medication/models/medicine_enums.dart';
import 'package:tablet_remainder/features/medication/models/medicine_schedule.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_add_medication_flow.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_detail_screen.dart';
import 'package:tablet_remainder/features/medication/services/medicine_storage_service.dart';

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

  /// Every node in the live semantics tree, read from the owner rather than by
  /// walking elements — `tester.getSemantics` routes through a debug-only
  /// element visitor that throws on this app's viewports.
  List<SemanticsNode> nodes(WidgetTester tester) {
    // ignore: deprecated_member_use
    final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
    expect(root, isNotNull, reason: 'ensureSemantics() must be held open');
    final out = <SemanticsNode>[];
    void walk(SemanticsNode n) {
      out.add(n);
      n.visitChildren((c) {
        walk(c);
        return true;
      });
    }

    walk(root!);
    return out;
  }

  /// Labels of the nodes a screen reader can actually activate. The tap action
  /// is the point: a label parked on a node with no action is a caption, and
  /// the control beside it still announces as nothing.
  List<String> tappableLabels(WidgetTester tester) => [
        for (final n in nodes(tester))
          if ((n.getSemanticsData().actions & SemanticsAction.tap.index) != 0)
            n.label,
      ];

  testWidgets("the refill sheet's −/+ buttons say which way they go",
      (tester) async {
    final handle = tester.ensureSemantics();
    // A tall viewport so every sliver of the detail screen is built: the Stock
    // card sits well below the fold, and a lazy sliver that never builds finds
    // nothing to assert on. Layout follows the view, not MediaQuery.
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // currentStock non-null is what makes the Stock card (and its Refill
    // button) render at all — see _buildStockSection.
    final med = EnhancedMedicine(
      id: 'm1',
      name: 'Metformin',
      dosageForm: DosageForm.tablet,
      dosageAmount: 1,
      currentStock: 20,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      schedule: MedicineSchedule(
        frequencyType: FrequencyType.twiceDaily,
        times: [
          ScheduledTime(hour: 8, minute: 0),
          ScheduledTime(hour: 20, minute: 0),
        ],
      ),
    );
    await MedicineCleanStorageService.addMedicine(med,
        stampActiveProfile: false);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: NunitoMedicationDetailScreen(medicine: med),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Refill'));
    await tester.pumpAndSettle();

    final labels = tappableLabels(tester);
    expect(labels, contains('Decrease refill amount'),
        reason: 'the − button announces as "". Tappable labels: $labels');
    expect(labels, contains('Increase refill amount'),
        reason: 'the + button announces as "". Tappable labels: $labels');

    handle.dispose();
  });

  testWidgets('a colour swatch says its colour and whether it is chosen',
      (tester) async {
    final handle = tester.ensureSemantics();

    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const NunitoAddMedicationFlow(),
    ));
    await tester.pumpAndSettle();

    // Walk the wizard to the Appearance step. Only the first step has a
    // required field; the dosage and schedule defaults already validate. From
    // Schedule on, the primary button finishes — the ghost one pages forward.
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(AppTextField, 'Medicine name'),
        matching: find.byType(TextField),
      ),
      'Metformin',
    );
    await tester.pump();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Add appearance & extras'));
    await tester.pumpAndSettle();
    expect(find.text('What does it look like?'), findsOneWidget,
        reason: 'the wizard did not reach the Appearance step');

    final labels = tappableLabels(tester);
    for (final colour in ['White', 'Yellow', 'Blue']) {
      expect(labels, contains(colour),
          reason: 'the $colour swatch announces as "". '
              'Tappable labels: $labels');
    }

    // Selection shows as a ring and a check mark, neither of which a reader
    // can see — so it has to be in the node, not just in the paint.
    await tester.tap(find.bySemanticsLabel('Blue'));
    await tester.pumpAndSettle();
    final selected = [
      for (final n in nodes(tester))
        if (n.hasFlag(SemanticsFlag.isSelected)) n.label,
    ];
    expect(selected, contains('Blue'),
        reason: 'the chosen swatch is not announced as selected. '
            'Selected nodes: $selected');

    handle.dispose();
  });
}

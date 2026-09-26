import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/constants/app_spacing.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/core/widgets/app/app_widgets.dart';
import 'package:tablet_remainder/features/medication/screens/analytics/nunito_adherence_report_screen.dart';
import 'package:tablet_remainder/features/medication/screens/appointments/nunito_appointment_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/clinics/nunito_clinic_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/doctors/nunito_doctor_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/nunito_medication_list_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_pressure_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/mood_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/vitals_trend_chart.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/weight_screen.dart';

/// Design-system conformance for the MEDICATION screens, as behaviour rather
/// than as a source-grep. Everything here is a defect that was real once and
/// would come back silently: a card that quietly renders at 60% width, chart
/// labels that ignore Dynamic Type, a picker that overflows only above 1.0x,
/// and a second primary button appearing next to the first.
///
/// The per-file deviation COUNTS live in `test/design/design_tokens_guard_test.dart`
/// and are a separate, ratcheting instrument. This file is about what the user
/// sees, which a count cannot express.
///
/// Two groups at the end read source instead of pumping widgets, and the last
/// of them — DS-15 — is deliberately NOT medication-scoped: it walks every
/// hand-written file under `lib/`, because the noun it polices leaks into
/// `reminders`, `core/health` and `core/services`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() {
    // Same reason the responsive harness pins it: async font resolution makes a
    // borderline measurement depend on whether it happened to finish between
    // pumps. The fallback metric is WIDER than shipped Inter, so a pass here
    // errs toward over-reporting.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    Size size = const Size(390, 844),
    double scale = 1.0,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: MaterialApp(theme: AppTheme.lightTheme, home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  // ───────────────────────────── MED-UI-19 ─────────────────────────────

  group('MED-UI-19 the vitals trend chart obeys the text scaler', () {
    Widget chart() => Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: VitalsTrendChart(
                series: const [
                  VitalsSeries(
                      values: [110, 118, 124, 119],
                      color: Color(0xFF3366CC),
                      label: 'Systolic'),
                ],
                minY: 90,
                maxY: 140,
                bandColor: const Color(0xFF33AA66),
              ),
            ),
          ),
        );

    CustomPainter painterOf(WidgetTester tester) => tester
        .widget<CustomPaint>(
            find.descendant(of: find.byType(VitalsTrendChart), matching: find.byType(CustomPaint)))
        .painter!;

    testWidgets('a change of text scale repaints the axis labels',
        (tester) async {
      await pump(tester, chart());
      final atOneX = painterOf(tester);

      await pump(tester, chart(), scale: 2.0);
      final atTwoX = painterOf(tester);

      // The whole defect: the painter took its label size from a literal and
      // compared only series/minY/maxY in shouldRepaint, so a Dynamic Type
      // change produced an identical verdict and the labels never grew while
      // every other string on the screen did.
      expect(atOneX.shouldRepaint(atTwoX), isTrue,
          reason: 'the painter must repaint when the text scaler changes — '
              'without it the y-axis labels are the only text on the screen '
              'that ignores the user font size');
    });

    testWidgets('the axis label style comes from the type scale, not a literal',
        (tester) async {
      await pump(tester, chart());
      // labelSmall is 11, the floor of the scale. The painter used to hardcode
      // 10, which has no slot.
      final style = (painterOf(tester) as dynamic).labelStyle as TextStyle;
      expect(style.fontSize, 11);
    });
  });

  // ───────────────────────────── MED-UI-09 ─────────────────────────────

  testWidgets('MED-UI-09 the adherence Overview card fills the content width',
      (tester) async {
    // Deliberately a WIDE viewport, and not because anyone runs this screen on
    // a 900pt one. The card's widest child is an unclamped caption, and
    // flutter_test's fallback font is about twice the advance width of shipped
    // Inter — at phone width that caption fills the row on its own, so the
    // broken layout and the fixed one measure the same and the check can never
    // fail. Give the row more width than any caption can claim and the
    // difference is unambiguous: shrink-wrapped (~half) versus full-bleed.
    const width = 900.0;
    await pump(tester, const NunitoAdherenceReportScreen(),
        size: const Size(width, 1200));

    // The Overview card is the first on the screen. It contains only
    // intrinsically-sized children (a fixed-diameter ring and two centred
    // labels), so under the column's loose constraints it collapsed to its
    // widest child — visibly narrower than the SectionHeader and StatTileRow
    // it sits between.
    final card = find.byType(AppCard).first;
    expect(card, findsOneWidget);
    expect(tester.getSize(card).width, width - AppSpacing.gutter * 2,
        reason: 'the Overview card must span the gutters like every other '
            'section, not shrink to its contents');
  });

  // ───────────────────────────── MED-UI-15 ─────────────────────────────

  testWidgets('MED-UI-15 the mood picker fits a 320pt sheet at 2.0x text',
      (tester) async {
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final s = details.exception.toString();
      if (s.contains('overflowed by') || s.contains('A RenderFlex overflowed')) {
        overflows.add(s.split('\n').first);
      } else {
        previous?.call(details);
      }
    };
    addTearDown(() => FlutterError.onError = previous);

    await pump(tester, const MoodScreen(),
        size: const Size(320, 844), scale: 2.0);
    await tester.tap(find.text('Log mood'));
    await tester.pumpAndSettle();

    // Five 48pt faces plus their labels used to sit in a non-flex Row, which
    // overflowed the sheet as soon as the labels grew.
    expect(find.text('Great'), findsWidgets);
    expect(overflows, isEmpty, reason: overflows.join('\n'));
  });

  // ───────────────────────────── DS-16 ─────────────────────────────

  group('DS-16 one primary action per state', () {
    testWidgets('mood: the FAB stays away while the empty state owns the CTA',
        (tester) async {
      await pump(tester, const MoodScreen());
      expect(find.text('Log mood'), findsOneWidget);
      expect(find.byType(AppFab), findsNothing,
          reason: 'the empty state already carries the same action');

      await tester.tap(find.text('Log mood'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Great'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();

      // With history there is something to add to, so the FAB comes back and
      // the full-width CTA is gone — never both.
      expect(find.byType(AppFab), findsOneWidget);
      expect(find.text('Log mood'), findsNothing);
    });

    // Every vitals screen with a conditional FAB, named individually.
    //
    // Blood sugar used to be the one missing from this group, and the omission
    // was invisible: restoring an unconditional FAB on it — the exact defect
    // DS-16 is about — left the whole suite green, because the other three
    // screens were what the group enumerated. Counted the same way as the list
    // screens below, so ZERO fails as loudly as TWO.
    //
    // One screen per test: a second `pumpWidget` reuses the Navigator element,
    // so anything the first flow pushed is still on the route stack.
    for (final screen in <({String name, Widget widget, String cta})>[
      (name: 'blood pressure', widget: const BloodPressureScreen(), cta: 'Log reading'),
      (name: 'blood sugar', widget: const BloodSugarScreen(), cta: 'Log reading'),
      (name: 'weight', widget: const WeightScreen(), cta: 'Log reading'),
    ]) {
      testWidgets('${screen.name}: an empty screen offers exactly one way to '
          'log', (tester) async {
        await pump(tester, screen.widget);

        // These screens hand-roll their empty state rather than using the
        // shared [EmptyState], so the CTA is counted as rendered rather than
        // read off a constructor argument.
        final fabs = find.byType(AppFab).evaluate().length;
        final ctas =
            find.widgetWithText(AppButton, screen.cta).evaluate().length;

        expect(fabs + ctas, 1,
            reason: fabs + ctas == 0
                ? '${screen.name} has NO way to log the first reading: no FAB '
                    'and an empty state with no "${screen.cta}" button.'
                : '${screen.name} shows $fabs FAB(s) and $ctas empty-state '
                    'CTA(s) for the same job.');
      });
    }

    testWidgets('doctors hides the FAB when empty', (tester) async {
      await pump(tester, const NunitoDoctorListScreen());
      expect(find.text('Add doctor'), findsOneWidget,
          reason: 'exactly one — the empty-state CTA, with no FAB beside it');
      expect(find.byType(AppFab), findsNothing);
    });

    testWidgets('appointments hides the FAB when empty', (tester) async {
      await pump(tester, const NunitoAppointmentListScreen());
      expect(find.text('Add appointment'), findsOneWidget);
      expect(find.byType(AppFab), findsNothing);
    });

    // The rule is ONE primary action, which cuts both ways — and the second
    // way is the dangerous one. Clinics and the medicine list keep an
    // unconditional FAB *because* their empty states carry no CTA: copying
    // `_x.isEmpty ? null : AppFab` onto them would leave a new user looking at
    // an empty screen with no way to add anything at all.
    //
    // So this counts affordances rather than asserting a shape. Zero fails as
    // loudly as two, and a screen that later grows an empty-state button will
    // fail here until its FAB is made conditional to match.
    for (final screen in <({String name, Widget widget})>[
      (name: 'medicines', widget: const NunitoMedicationListScreen()),
      (name: 'doctors', widget: const NunitoDoctorListScreen()),
      (name: 'clinics', widget: const NunitoClinicListScreen()),
      (name: 'appointments', widget: const NunitoAppointmentListScreen()),
    ]) {
      testWidgets('${screen.name}: an empty screen offers exactly one way to '
          'add', (tester) async {
        await pump(tester, screen.widget);

        final empty = tester.widget<EmptyState>(find.byType(EmptyState));
        final fabs = find.byType(AppFab).evaluate().length;
        final ctas = empty.action == null ? 0 : 1;

        expect(fabs + ctas, 1,
            reason: fabs + ctas == 0
                ? '${screen.name} has NO way to add the first one: no FAB and '
                    'an empty state with no action.'
                : '${screen.name} shows $fabs FAB(s) and $ctas empty-state '
                    'CTA(s) for the same job.');
      });
    }
  });

  // ───────────────────────── MED-UI-17 / DS-23 ─────────────────────────

  group('source-level conformance in lib/features/medication/{screens,widgets}',
      () {
    List<File> uiFiles() => [
          for (final d in const [
            'lib/features/medication/screens',
            'lib/features/medication/widgets',
          ])
            for (final e in Directory(d).listSync(recursive: true))
              if (e is File && e.path.endsWith('.dart')) e,
        ];

    test('MED-UI-17 the dead Nunito glass-card file stays deleted', () {
      expect(File('lib/features/medication/widgets/nunito_glass_card.dart').existsSync(),
          isFalse);
      // ...and nothing reintroduces a reference to what it defined.
      final refs = <String>[];
      for (final f in uiFiles()) {
        final src = f.readAsStringSync();
        for (final name in const [
          'NunitoGlassCard',
          'NunitoAnimatedCard',
          'NunitoHeaderCard',
          'NunitoDosageIcon',
        ]) {
          if (src.contains(name)) refs.add('${f.path}: $name');
        }
      }
      expect(refs, isEmpty, reason: refs.join('\n'));
    });

    test('DS-23 button and header copy is sentence case', () {
      // A second capitalised word in a `label:`/`title:` string is Title Case
      // unless it is a proper noun. The allow-list is the proper nouns this
      // feature actually uses.
      const properNouns = <String>['A1C', 'PDF', 'PRN', 'Apple', 'Google', 'Health'];
      final labels = RegExp(r"\b(?:label|title|confirmLabel): '([^'\n]*)'");
      // Both words have to be real words: "Day N+" is a field label with a
      // placeholder in it, not Title Case.
      final titleCase = RegExp(r'^[A-Z][a-z]+ [A-Z][a-z]+');
      final offenders = <String>[];
      for (final f in uiFiles()) {
        for (final m in labels.allMatches(f.readAsStringSync())) {
          final text = m.group(1)!;
          if (!titleCase.hasMatch(text)) continue;
          if (properNouns.any(text.contains)) continue;
          offenders.add('${f.path}: $text');
        }
      }
      expect(offenders, isEmpty,
          reason: 'DS-23: Material 3 is sentence case.\n${offenders.join('\n')}');
    });
  });

  // ───────────────────────────── DS-15 ─────────────────────────────

  group('DS-15 one feature, one noun', () {
    /// Every hand-written `.dart` file under `lib/`. Generated output is
    /// excluded: it is regenerated from the tables, not written as copy.
    List<File> libFiles() => [
          for (final e in Directory('lib').listSync(recursive: true))
            if (e is File &&
                e.path.endsWith('.dart') &&
                !e.path.endsWith('.g.dart') &&
                !e.path.endsWith('.freezed.dart') &&
                !e.path.endsWith('.mocks.dart'))
              e,
        ];

    /// The string literals on one line of Dart, with any trailing `//` comment
    /// dropped. Walking the line is what separates a literal from the same
    /// word inside a comment that happens to quote it, and what keeps an
    /// apostrophe in "don't" from being read as the start of a string.
    List<String> literalsOf(String line) {
      final out = <String>[];
      var i = 0;
      while (i < line.length) {
        final quote = line[i];
        if (quote == '/' && i + 1 < line.length && line[i + 1] == '/') break;
        if (quote != "'" && quote != '"') {
          i++;
          continue;
        }
        // r'...' keeps its backslashes; an ordinary literal escapes them, so
        // there a `\'` must not be read as the closing quote.
        final raw = i > 0 && line[i - 1] == 'r';
        final buf = StringBuffer();
        i++;
        while (i < line.length && line[i] != quote) {
          if (!raw && line[i] == r'\' && i + 1 < line.length) {
            buf.write(line[i]);
            i++;
          }
          buf.write(line[i]);
          i++;
        }
        i++; // past the closing quote
        out.add(buf.toString());
      }
      return out;
    }

    test('no user-visible string in lib/ says "medication"', () {
      // Scoped to lib/ as a whole rather than to the medication feature,
      // because feature-only scoping is exactly how four strings survived it:
      // the alarm screen lives in `reminders`, the adherence insight in
      // `core/health`, the battery dialog and the feature catalogue in
      // `core/services`.
      //
      // The allow-list below is SHRINK-ONLY. The second expectation enforces
      // the coming-off half mechanically — an entry matching nothing fails, so
      // fixing a string forces deleting its exemption. Keeping NEW entries OFF
      // the list is a review call the test cannot make for you: adding one
      // silences its copy and still passes.

      // Persisted keys and an existing export's filename. Renaming one of
      // these orphans a stored preference or breaks a file the user already
      // holds — a data change, not a copy change.
      const persisted = <String>[
        'medicationViewMode',
        'medication_reminders_master_enabled',
        'medication_clinics',
        r'${dir.path}/medication-log.csv',
      ];

      // The adherence PDF's headings, on the same argument as the CSV above:
      // it is a document users file with a doctor, so the format stays put.
      const exported = <String>[
        'Medication Adherence Report',
        'Per-medication adherence',
        'Medication',
        'Medications',
      ];

      // Matchers over what the USER typed, not copy shown back to them.
      // People do say "medication", so the patterns have to keep the word.
      const matchers = <String>[
        r'\b(medicine|medication|pill|pills|dose|tablet|meds?|vitamin|insulin)\b',
        'medication',
      ];

      // "medication" as the pharmacological noun rather than as this app's
      // feature name. Drug-interaction guidance talks about drugs in general:
      // "use alternative pain medication" is clinical advice, and swapping in
      // "medicine" would reword the advice rather than the branding.
      const clinical = <String>[
        'Use alternative pain medication or monitor closely.',
        'Avoid combination. Use alternative pain medication.',
        'Never combine. Wait 14 days between switching medications.',
        'Never combine. Avoid alcohol when taking sleep medications.',
        'Calcium reduces thyroid medication absorption.',
        'Iron reduces thyroid medication absorption.',
        'Check other medications for acetaminophen',
        'Separate from other medications',
        'First-line medication for type 2 diabetes.',
        'Blood pressure medication that protects heart and kidneys.',
        'Blood pressure and angina medication.',
        'Cholesterol-lowering medication.',
        'Antidepressant and anti-anxiety medication.',
      ];

      final allowed = {...persisted, ...exported, ...matchers, ...clinical};
      final matched = <String>{};
      final offenders = <String>[];
      for (final f in libFiles()) {
        for (final line in f.readAsStringSync().split('\n')) {
          final trimmed = line.trimLeft();
          // Comments, imports/exports/parts and debug logging are not copy.
          if (trimmed.startsWith('//') ||
              trimmed.startsWith('*') ||
              trimmed.startsWith('/*') ||
              trimmed.startsWith('import ') ||
              trimmed.startsWith('export ') ||
              trimmed.startsWith('part ') ||
              line.contains('debugPrint(')) {
            continue;
          }
          for (final text in literalsOf(line)) {
            if (!text.toLowerCase().contains('medication')) continue;
            if (allowed.contains(text)) {
              matched.add(text);
              continue;
            }
            offenders.add('${f.path}: $text');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'DS-15: one feature, one noun. Use "medicine".\n'
              '${offenders.join('\n')}');

      final stale = allowed.difference(matched);
      expect(stale, isEmpty,
          reason: 'DS-15: these exemptions match nothing in lib/ any more, so '
              'the copy they covered is fixed — delete them:\n'
              '${stale.join('\n')}');
    });
  });
}

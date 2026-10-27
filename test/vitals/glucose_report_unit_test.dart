import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/health/vitals_analyzer.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/theme/app_theme.dart';
import 'package:tablet_remainder/features/medication/models/glucose_reading.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/blood_sugar_report_screen.dart';
import 'package:tablet_remainder/features/medication/screens/vitals/vitals_trend_chart.dart';
import 'package:tablet_remainder/features/medication/services/vitals_report_service.dart';
import 'package:tablet_remainder/features/medication/services/vitals_storage_service.dart';

/// The blood-sugar report and its PDF printed mg/dL for everyone. A person who
/// reads their glucose in mmol/L saw "7.0" on the Blood sugar screen and "126"
/// on the report they handed to a clinician.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('unit helpers', () {
    test('format in each unit', () {
      expect(VitalsAnalyzer.formatGlucose(126, GlucoseUnit.mgdl), '126');
      expect(VitalsAnalyzer.formatGlucose(126, GlucoseUnit.mmoll), '7.0');
      expect(VitalsAnalyzer.formatGlucose(70, GlucoseUnit.mmoll), '3.9');
    });
    test('labels', () {
      expect(VitalsAnalyzer.glucoseUnitLabel(GlucoseUnit.mgdl), 'mg/dL');
      expect(VitalsAnalyzer.glucoseUnitLabel(GlucoseUnit.mmoll), 'mmol/L');
    });
    test('the stored preference maps to a unit; junk is mg/dL', () {
      expect(VitalsAnalyzer.glucoseUnitFromPref('mmoll'), GlucoseUnit.mmoll);
      expect(VitalsAnalyzer.glucoseUnitFromPref('mgdl'), GlucoseUnit.mgdl);
      expect(VitalsAnalyzer.glucoseUnitFromPref(null), GlucoseUnit.mgdl);
      expect(VitalsAnalyzer.glucoseUnitFromPref('???'), GlucoseUnit.mgdl);
    });
  });

  group('the PDF', () {
    /// Every word drawn on every page, in order. The pdf package writes standard
    /// fonts as literal strings, one per word, inside Flate-compressed content
    /// streams, with parentheses escaped.
    List<String> wordsOf(List<int> bytes) {
      final raw = latin1.decode(bytes, allowInvalid: true);
      final words = <String>[];
      final show = RegExp(r'\[\(((?:\\.|[^\\)])*)\)\]TJ');
      for (final m in RegExp(r'stream\r?\n').allMatches(raw)) {
        final end = raw.indexOf('endstream', m.end);
        if (end < 0) continue;
        try {
          final inflated = latin1.decode(
              zlib.decode(bytes.sublist(m.end, end).toList()),
              allowInvalid: true);
          for (final w in show.allMatches(inflated)) {
            words.add(w.group(1)!.replaceAll(r'\(', '(').replaceAll(r'\)', ')'));
          }
        } catch (_) {
          // Not every stream is Flate (fonts, images).
        }
      }
      return words;
    }

    final readings = [
      for (var i = 0; i < 4; i++)
        GlucoseReading(
            id: 'g$i',
            valueMgdl: 126,
            context: GlucoseContext.fasting,
            takenAt: DateTime(2026, 3, 1 + i, 8),
            createdAt: DateTime(2026, 3, 1 + i, 8)),
    ];

    Future<List<String>> pdf(GlucoseUnit unit) async => wordsOf(
        await VitalsReportService.buildGlucosePdf(
            readings: readings,
            from: DateTime(2026, 3, 1),
            to: DateTime(2026, 3, 31),
            generatedAt: DateTime(2026, 3, 25),
            unit: unit));

    test('the premise: the text really can be read back out', () async {
      final t = (await pdf(GlucoseUnit.mgdl)).join(' ');
      expect(t, contains('Glucose (mg/dL)'));
    });

    test('mg/dL by default, as before', () async {
      final w = await pdf(GlucoseUnit.mgdl);
      expect(w.join(' '), contains('mg/dL avg'));
      expect(w, contains('126'));
      expect(w.join(' '), isNot(contains('mmol')));
    });

    test('in mmol/L the values, headings and targets all change together',
        () async {
      final w = await pdf(GlucoseUnit.mmoll);
      final t = w.join(' ');
      expect(t, contains('Glucose (mmol/L)'));
      expect(t, contains('mmol/L avg'));
      expect(w, contains('7.0'));
      expect(t, contains('4.4-7.2'));
      expect(w, isNot(contains('126')),
          reason: 'a value in the wrong unit beside a right label is the '
              'dangerous kind of wrong');
      expect(t, isNot(contains('Glucose (mg/dL)')));
    });
  });

  test('the report screen hands its unit to the PDF it shares', () {
    // `Printing.sharePdf` is a platform channel, so the export itself cannot be
    // driven headlessly; the call is pinned by source, bounded to the builder.
    final src = File(
            'lib/features/medication/screens/vitals/blood_sugar_report_screen.dart')
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    final from = src.indexOf('buildGlucosePdf(');
    expect(from, greaterThan(-1));
    expect(src.substring(from, src.indexOf(');', from)), contains('unit: _unit'),
        reason: 'the screen shows mmol/L and the PDF it shares must too');
  });

  group('the report screen', () {
    late AppDatabase db;

    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(NativeDatabase.memory());
      AppDatabase.setInstanceForTesting(db);
      ActiveProfileService().resetForTesting();
      CleanStorageService.resetForTesting();
      await CleanStorageService.init();
      final at = DateTime.now().subtract(const Duration(days: 1));
      await VitalsStorageService.saveGlucose(
        GlucoseReading(id: 'g', valueMgdl: 126, takenAt: at, createdAt: at),
        syncToHealthConnect: false,
      );
    });

    tearDown(() async => db.close());

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final prev = FlutterError.onError;
      FlutterError.onError = (_) {};
      addTearDown(() => FlutterError.onError = prev);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme, home: const BloodSugarReportScreen()));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('mg/dL users see what they always saw', (tester) async {
      await open(tester);
      expect(find.text('Avg mg/dL'), findsOneWidget);
      expect(find.text('126'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('an mmol/L user sees their own unit throughout, chart included',
        (tester) async {
      await CleanStorageService.setAppPreference('glucose_unit', 'mmoll');
      await open(tester);
      expect(find.text('Avg mmol/L'), findsOneWidget);
      expect(find.text('7.0'), findsOneWidget);
      final chart =
          tester.widget<VitalsTrendChart>(find.byType(VitalsTrendChart));
      expect(chart.series.single.values.single, 7.0);
      expect(chart.bandLow, VitalsAnalyzer.mgdlToMmol(70));
      expect(chart.bandHigh, VitalsAnalyzer.mgdlToMmol(180));
      expect(chart.maxY, lessThan(40),
          reason: 'an mmol/L line against a 20-500 axis would be a flat line '
              'at the bottom');
      await tester.pump(const Duration(seconds: 8));
    });
  });
}

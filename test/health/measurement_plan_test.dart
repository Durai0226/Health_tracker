import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/measurement_plan.dart';

void main() {
  group('kindsFor — which reading goes with the medicine', () {
    test('blood-pressure, diabetes and water pills each map to one reading', () {
      expect(MeasurementPlan.kindsFor('Amlodipine'),
          {MeasurementKind.bloodPressure});
      expect(MeasurementPlan.kindsFor('Metformin'),
          {MeasurementKind.bloodGlucose});
      expect(MeasurementPlan.kindsFor('Furosemide'), {MeasurementKind.weight});
    });

    test('a strength, form or case does not hide the drug', () {
      expect(MeasurementPlan.kindsFor('METOPROLOL 50 mg SR'),
          {MeasurementKind.bloodPressure});
      expect(MeasurementPlan.kindsFor('Insulin glargine pen'),
          {MeasurementKind.bloodGlucose});
    });

    test('a brand the user typed resolves through the catalogue generic', () {
      expect(MeasurementPlan.kindsFor('Glycomet 500', generic: 'Metformin'),
          {MeasurementKind.bloodGlucose});
    });

    test('whole words only: a longer word never matches the drug it begins with',
        () {
      expect(MeasurementPlan.kindsFor('Metforminol'), isEmpty);
      expect(MeasurementPlan.kindsFor('Insulinoma tablets'), isEmpty);
    });

    test('unrelated medicines get no offer', () {
      expect(MeasurementPlan.kindsFor('Paracetamol'), isEmpty);
      expect(MeasurementPlan.kindsFor('Dolo 650', generic: 'Paracetamol'),
          isEmpty);
      expect(MeasurementPlan.kindsFor(''), isEmpty);
    });

    test('a combination can carry more than one reading', () {
      expect(
          MeasurementPlan.kindsFor('Telmisartan + Furosemide'),
          {MeasurementKind.bloodPressure, MeasurementKind.weight});
    });
  });

  group('the routine offered', () {
    test('blood pressure is morning AND evening; the others are once a day', () {
      final bp = MeasurementPlan.suggestionFor(
          MeasurementKind.bloodPressure, 'Amlodipine');
      expect(bp.slots.map((s) => '${s.hour}:${s.minute}'), ['8:0', '19:0']);
      expect(
          MeasurementPlan.suggestionFor(MeasurementKind.bloodGlucose, 'X')
              .slots,
          hasLength(1));
      expect(
          MeasurementPlan.suggestionFor(MeasurementKind.weight, 'X').slots,
          hasLength(1));
    });

    test('the reason names the user\'s medicine and never instructs', () {
      for (final k in MeasurementKind.values) {
        final s = MeasurementPlan.suggestionFor(k, 'Zedrol');
        expect(s.reason, contains('Zedrol'));
        expect(s.reason.toLowerCase(), isNot(contains('you must')));
        expect(s.reason.toLowerCase(), isNot(contains('should take')));
      }
    });

    test('every offer defers the frequency to the clinician where it names one',
        () {
      final bp = MeasurementPlan.suggestionFor(
          MeasurementKind.bloodPressure, 'X');
      expect(bp.reason, contains('clinician'));
    });
  });

  group('offer — what is actually shown', () {
    test('a kind already set up is not offered again', () {
      expect(
          MeasurementPlan.offer('Amlodipine',
              alreadyOn: {MeasurementKind.bloodPressure}),
          isEmpty);
    });

    test('a kind the user said not-now to is not offered again', () {
      expect(
          MeasurementPlan.offer('Metformin',
              declined: {MeasurementKind.bloodGlucose}),
          isEmpty);
    });

    test('only the unanswered half of a combination is offered', () {
      final o = MeasurementPlan.offer('Telmisartan + Furosemide',
          declined: {MeasurementKind.bloodPressure});
      expect(o.map((s) => s.kind), [MeasurementKind.weight]);
    });

    test('order is fixed, whatever the medicine order', () {
      final o = MeasurementPlan.offer('Furosemide + Metformin + Amlodipine');
      expect(o.map((s) => s.kind), MeasurementKind.values);
    });
  });
}

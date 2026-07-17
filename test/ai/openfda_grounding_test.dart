import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/ai/openfda_grounding.dart';

void main() {
  Map<String, dynamic> label({
    List<String>? interactions,
    List<String>? dosage,
    List<String>? adverse,
    List<String>? indications,
    List<String>? warnings,
  }) =>
      {
        'results': [
          {
            if (interactions != null) 'drug_interactions': interactions,
            if (dosage != null) 'dosage_and_administration': dosage,
            if (adverse != null) 'adverse_reactions': adverse,
            if (indications != null) 'indications_and_usage': indications,
            if (warnings != null) 'warnings': warnings,
            'openfda': {
              'brand_name': ['Aspirin'],
              'generic_name': ['aspirin']
            },
          }
        ]
      };

  group('buildQueryUrl', () {
    test('targets openFDA with the encoded drug name + limit', () {
      final u = OpenFdaGrounding.buildQueryUrl('Aspirin');
      expect(u.host, 'api.fda.gov');
      expect(u.path, '/drug/label.json');
      expect(u.query, contains('aspirin'));
      expect(u.queryParameters['limit'], '1');
    });
  });

  group('selectSection', () {
    test('interaction question → drug_interactions section', () {
      final r = OpenFdaGrounding.selectSection(
        label(interactions: ['Do not take with warfarin.'], indications: ['Pain relief.']),
        'does this interact with my other meds?',
      );
      expect(r, isNotNull);
      expect(r!.section, 'Interactions');
      expect(r.text, contains('warfarin'));
      expect(r.source, contains('openFDA'));
    });

    test('dosage question → dosage section', () {
      final r = OpenFdaGrounding.selectSection(
        label(dosage: ['Take 1 tablet every 4 hours.']),
        'how much should I take?',
      );
      expect(r!.section, 'Dosage & administration');
      expect(r.text, contains('every 4 hours'));
    });

    test('falls back to indications when the target section is missing', () {
      final r = OpenFdaGrounding.selectSection(
        label(indications: ['For temporary relief of minor aches.']),
        'does this interact with anything?', // no interactions section present
      );
      expect(r, isNotNull);
      expect(r!.text, contains('minor aches'));
    });

    test('no results → null (falls back to on-device answer)', () {
      expect(OpenFdaGrounding.selectSection({'results': []}, 'what is it for?'), isNull);
      expect(OpenFdaGrounding.selectSection({}, 'what is it for?'), isNull);
    });

    test('long section text is clipped', () {
      final long = List.filled(50, 'This is a sentence about the drug label. ').join();
      final r = OpenFdaGrounding.selectSection(
        label(indications: [long]),
        'what is it for?',
      );
      expect(r!.text.length, lessThan(long.length));
      expect(r.text.trimRight(), endsWith('…'));
    });
  });
}

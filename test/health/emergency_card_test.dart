/// What the card says, and what it refuses to claim.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:tablet_remainder/core/health/emergency_card.dart';

void main() {
  final now = DateTime(2026, 6, 30);
  EmergencyCard card({
    String? name,
    DateTime? dob,
    String? blood,
    List<String>? allergies,
    List<String>? conditions,
    List<EmergencyMedicine> meds = const [],
    EmergencyCardContact? contact,
  }) =>
      EmergencyCard.build(
        name: name,
        dateOfBirth: dob,
        bloodType: blood,
        allergies: allergies,
        conditions: conditions,
        medicines: meds,
        contact: contact,
        now: now,
      );

  group('who', () {
    test('the placeholder name is not a name', () {
      expect(card(name: 'Me').name, isNull);
      expect(card(name: ' me ').name, isNull);
      expect(card(name: '').name, isNull);
      expect(card().name, isNull);
    });

    test('a real name is kept, trimmed', () {
      expect(card(name: '  Priya Nair ').name, 'Priya Nair');
    });

    test('a name that merely starts with Me is a name', () {
      expect(card(name: 'Meera').name, 'Meera');
    });

    test('age is whole years, birthday not yet come', () {
      expect(card(dob: DateTime(1990, 6, 30)).age, 36, reason: 'today is the birthday');
      expect(card(dob: DateTime(1990, 7, 1)).age, 35, reason: 'tomorrow is');
      expect(card(dob: DateTime(1990, 12, 31)).age, 35);
      expect(card(dob: DateTime(1990, 1, 1)).age, 36);
      expect(card().age, isNull);
    });

    test('a date of birth in the future is not a negative age', () {
      expect(card(dob: DateTime(2030, 1, 1)).age, 0);
    });

    test('blood type is trimmed; blank is none', () {
      expect(card(blood: ' O+ ').bloodType, 'O+');
      expect(card(blood: '  ').bloodType, isNull);
    });
  });

  group('allergies and conditions', () {
    test('trimmed, blanks and repeats dropped, in the order given', () {
      final c = card(allergies: [' Penicillin', '', 'peanuts', 'PENICILLIN', 'Latex  ']);
      expect(c.allergies, ['Penicillin', 'peanuts', 'Latex']);
    });

    test('conditions the same way', () {
      expect(card(conditions: ['Asthma', ' asthma ', 'Type 2 diabetes']).conditions,
          ['Asthma', 'Type 2 diabetes']);
    });

    test('nothing entered reads "Not recorded", never "None"', () {
      final c = card();
      expect(c.allergiesText, 'Not recorded');
      expect(c.conditionsText, 'Not recorded');
      expect(c.toPlainText(), isNot(contains('None')));
    });

    test('and an empty list is the same as nothing entered', () {
      expect(card(allergies: const []).allergiesText, 'Not recorded');
      expect(card(allergies: const ['  ']).allergiesText, 'Not recorded');
    });

    test('entered ones read as a list', () {
      expect(card(allergies: ['Penicillin', 'Peanuts']).allergiesText, 'Penicillin, Peanuts');
    });
  });

  group('medicines', () {
    test('alphabetical, each with its dose', () {
      final c = card(meds: const [
        EmergencyMedicine('Metformin 500 mg', '1 tablet'),
        EmergencyMedicine('aspirin', '75 mg'),
        EmergencyMedicine('Levothyroxine'),
      ]);
      expect(c.medicines.map((m) => m.line), [
        'aspirin · 75 mg',
        'Levothyroxine',
        'Metformin 500 mg · 1 tablet',
      ]);
    });

    test('the same medicine twice is listed once', () {
      final c = card(meds: const [
        EmergencyMedicine('Metformin', '1 tablet'),
        EmergencyMedicine('metformin', '1 TABLET'),
      ]);
      expect(c.medicines, hasLength(1));
    });

    test('two doses of one medicine are two lines', () {
      final c = card(meds: const [
        EmergencyMedicine('Insulin', '10 units'),
        EmergencyMedicine('Insulin', '4 units'),
      ]);
      expect(c.medicines, hasLength(2));
    });
  });

  group('as text', () {
    test('a full card', () {
      final c = card(
        name: 'Priya Nair',
        dob: DateTime(1990, 1, 1),
        blood: 'O+',
        allergies: ['Penicillin', 'Peanuts'],
        conditions: ['Asthma'],
        meds: const [EmergencyMedicine('Metformin', '1 tablet')],
        contact: const EmergencyCardContact(name: 'Arun', phone: '+91 98765 43210'),
      );
      expect(c.toPlainText(), '''EMERGENCY CARD
Priya Nair · 36 years · blood type O+

Allergies: Penicillin, Peanuts
Conditions: Asthma

Medicines:
- Metformin · 1 tablet

Emergency contact: Arun · +91 98765 43210''');
    });

    test('an empty card says what is not recorded, and nothing else', () {
      expect(card().toPlainText(), '''EMERGENCY CARD

Allergies: Not recorded
Conditions: Not recorded

Medicines: Not recorded

Emergency contact: Not recorded''');
    });

    test('a contact with no name is just the number', () {
      const c = EmergencyCardContact(phone: '112');
      expect(c.line, '112');
    });
  });
}

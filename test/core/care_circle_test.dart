/// Telling someone about a missed dose: an offer, off by default, with words that
/// carry nothing private.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/care_circle.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/core/services/emergency_contact.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    CleanStorageService.resetForTesting();
    await CleanStorageService.init();
  });

  tearDown(() async => db.close());

  group('the offer', () {
    test('is off until the person turns it on', () {
      expect(CareCircle.offerOnMissedDose, isFalse);
    });

    test('and is kept', () async {
      await CareCircle.setOfferOnMissedDose(true);
      expect(CareCircle.offerOnMissedDose, isTrue);
      await CareCircle.setOfferOnMissedDose(false);
      expect(CareCircle.offerOnMissedDose, isFalse);
    });

    test('survives a restart', () async {
      await CareCircle.setOfferOnMissedDose(true);
      CleanStorageService.resetForTesting();
      await CleanStorageService.init();
      expect(CareCircle.offerOnMissedDose, isTrue);
    });
  });

  test('Delete all data turns the offer off, and forgets the contact', () async {
    await EmergencyContact.save(name: 'Priya', phone: '+91 98765 43210');
    await CareCircle.setOfferOnMissedDose(true);
    await CleanStorageService.clearAllPersistentData();
    expect(CareCircle.offerOnMissedDose, isFalse);
    expect(CareCircle.contactToOffer(), isNull);
    expect(EmergencyContact.isSet, isFalse);
  });

  test('a backup carries the offer with the other preferences', () async {
    await CareCircle.setOfferOnMissedDose(true);
    final backup = await CleanStorageService.exportAllData();
    expect((backup['preferences'] as Map)[CareCircle.offerKey], isTrue);
    await CareCircle.setOfferOnMissedDose(false);
    await CleanStorageService.importData(backup);
    expect(CareCircle.offerOnMissedDose, isTrue);
  });

  group('who would be told', () {
    test('nobody while the offer is off, even with a contact', () async {
      await EmergencyContact.save(name: 'Priya', phone: '+91 98765 43210');
      expect(CareCircle.contactToOffer(), isNull);
    });

    test('nobody while there is no contact, even with the offer on', () async {
      await CareCircle.setOfferOnMissedDose(true);
      expect(CareCircle.contactToOffer(), isNull);
    });

    test('the emergency contact, when both are so', () async {
      await EmergencyContact.save(name: 'Priya', phone: '+91 98765 43210');
      await CareCircle.setOfferOnMissedDose(true);
      final c = CareCircle.contactToOffer()!;
      expect(c.name, 'Priya');
      expect(c.phone, '+91 98765 43210');
    });

    test('a name without a number is a note, not someone to message', () async {
      await EmergencyContact.save(name: 'Priya', phone: '');
      await CareCircle.setOfferOnMissedDose(true);
      expect(CareCircle.contactToOffer(), isNull);
    });
  });

  group('the words', () {
    test('a missed dose, and nothing else', () {
      expect(CareCircle.missedDoseMessage('Priya'),
          'Hi Priya, I missed a dose today and could use a nudge. Sent from DlyMinder.');
    });

    test('without a name, still polite', () {
      expect(CareCircle.missedDoseMessage(''),
          'Hi, I missed a dose today and could use a nudge. Sent from DlyMinder.');
      expect(CareCircle.missedDoseMessage('  '), startsWith('Hi, '));
    });

    test('a name is trimmed', () {
      expect(CareCircle.missedDoseMessage('  Priya '), startsWith('Hi Priya, '));
    });

    test('and carries no medicine, dose, time or health word', () {
      final m = CareCircle.missedDoseMessage('Priya').toLowerCase();
      for (final word in [
        'mg', 'tablet', 'pill', 'metformin', 'insulin', 'pm', ' am ', 'morning',
        'blood', 'pressure', 'sugar', 'diabet',
      ]) {
        expect(m, isNot(contains(word)), reason: word);
      }
    });

    test('the weekly summary\'s words say nothing private either', () {
      expect(CareCircle.weeklySummaryMessage.toLowerCase(), isNot(contains('mg')));
    });
  });
}

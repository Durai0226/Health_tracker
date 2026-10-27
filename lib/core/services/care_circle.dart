import 'clean_storage_service.dart';
import 'emergency_contact.dart';

/// Someone to tell, when a dose is missed.
///
/// The person is the emergency contact the app already holds, and telling them
/// is an offer, never an action: it is off until switched on, it opens the
/// messages app with the words typed in, and the person presses send. Nothing
/// is sent by the app, and the words carry no medicine, no dose and no time —
/// only that a dose was missed and a nudge would help.
class CareCircle {
  const CareCircle._();

  static const String offerKey = 'care_offer_missed_dose';

  /// Whether to offer to tell the contact when a dose is missed. Off by default.
  static bool get offerOnMissedDose =>
      CleanStorageService.getAppPreference(offerKey, false) == true;

  static Future<void> setOfferOnMissedDose(bool on) =>
      CleanStorageService.setAppPreference(offerKey, on);

  /// Who to offer to tell, or null when nobody is to be asked: the offer is off,
  /// or there is no contact with a number to message.
  static EmergencyContact? contactToOffer() {
    if (!offerOnMissedDose) return null;
    return EmergencyContact.get();
  }

  /// "Hi Priya, I missed a dose today and could use a nudge."
  ///
  /// Never the medicine's name, the dose or when: a text lingers on a lock
  /// screen and in a thread, and what a person takes is theirs to tell.
  static String missedDoseMessage(String contactName) {
    final name = contactName.trim();
    return '${name.isEmpty ? 'Hi' : 'Hi $name'}, I missed a dose today and could use a '
        'nudge. Sent from DlyMinder.';
  }

  /// The words that go with a weekly summary shared by hand.
  static const String weeklySummaryMessage =
      "Here is my week with my medicines. Sent from DlyMinder.";
}

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/health/emergency_card.dart';
import '../../../core/services/active_profile_service.dart';
import '../../../core/services/emergency_contact.dart';
import '../../medication/models/dependent_profile.dart';
import '../../medication/services/medicine_storage_service.dart';

/// The emergency card of whoever is active: the account holder, or a person
/// they look after.
class EmergencyCardService {
  const EmergencyCardService._();

  /// The card from what the app holds today. An empty card, not an error, when
  /// the database cannot be read.
  static Future<EmergencyCardData> load({DateTime? now}) async {
    final n = now ?? clock.now();
    final id = ActiveProfileService().activeDependentId;
    DependentProfile? profile;
    try {
      profile = await MedicineCleanStorageService.profileFor(id);
      // The active profile's, as the card is: and the ones taken now, not
      // stopped or shelved, which is what this call returns by default.
      final medicines = await MedicineCleanStorageService.getAllMedicines();
      return EmergencyCardData(
        profile: profile,
        card: EmergencyCard.build(
          name: profile?.name,
          dateOfBirth: profile?.dateOfBirth,
          bloodType: profile?.bloodType,
          allergies: profile?.allergies,
          conditions: profile?.conditions,
          medicines: [
            for (final m in medicines)
              EmergencyMedicine(m.fullDisplayName, m.displayDosage),
          ],
          contact: _contact(id, profile),
          now: n,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ Emergency card failed: $e');
      return EmergencyCardData(profile: profile, card: EmergencyCard.build(now: n));
    }
  }

  /// The account holder's contact is the one set from the setup checklist or
  /// the profile form (which writes it there); a dependent has only the one
  /// written on their profile.
  static EmergencyCardContact? _contact(String? dependentId, DependentProfile? profile) {
    if (dependentId == null) {
      final own = EmergencyContact.get();
      return own == null ? null : EmergencyCardContact(name: own.name, phone: own.phone);
    }
    final phone = profile?.emergencyPhone?.trim() ?? '';
    if (!EmergencyContact.isDialable(phone)) return null;
    return EmergencyCardContact(name: profile?.emergencyContact?.trim() ?? '', phone: phone);
  }
}

/// The card and the profile it came from, which the screen needs to edit it.
class EmergencyCardData {
  const EmergencyCardData({required this.card, required this.profile});

  final EmergencyCard card;

  /// Null when the profile row cannot be found.
  final DependentProfile? profile;
}

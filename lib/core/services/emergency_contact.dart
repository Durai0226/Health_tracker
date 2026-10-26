import 'clean_storage_service.dart';

/// The person to reach if something goes wrong — kept for the user themselves.
///
/// Family members already have an `emergencyContact` field; the account holder
/// ("Me") had nowhere to put one, so the Emergency card and the setup checklist
/// had nothing to read. Two plain strings in preferences: no schema change, and
/// it is device-local like the rest of the profile.
class EmergencyContact {
  final String name;
  final String phone;
  const EmergencyContact({required this.name, required this.phone});

  static const _nameKey = 'emergency_contact_name';
  static const _phoneKey = 'emergency_contact_phone';

  /// A phone is the only part that makes the contact usable, so it is what
  /// "set" means. A name alone is a note, not a way to reach anyone.
  static EmergencyContact? get() {
    final name = CleanStorageService.getAppPreference(_nameKey, '');
    final phone = CleanStorageService.getAppPreference(_phoneKey, '');
    final n = name is String ? name.trim() : '';
    final p = phone is String ? phone.trim() : '';
    if (p.isEmpty) return null;
    return EmergencyContact(name: n, phone: p);
  }

  static bool get isSet => get() != null;

  /// Whether [phone] looks like something that can be dialled: at least 5
  /// digits, and only digits and the usual punctuation. Deliberately lax about
  /// format — this is a number to ring, not an address to validate.
  static bool isDialable(String phone) {
    final t = phone.trim();
    if (!RegExp(r'^[+0-9()\-\s.]+$').hasMatch(t)) return false;
    return RegExp(r'\d').allMatches(t).length >= 5;
  }

  static Future<void> save({required String name, required String phone}) async {
    await CleanStorageService.setAppPreference(_nameKey, name.trim());
    await CleanStorageService.setAppPreference(_phoneKey, phone.trim());
  }

  static Future<void> clear() async {
    await CleanStorageService.setAppPreference(_nameKey, '');
    await CleanStorageService.setAppPreference(_phoneKey, '');
  }
}

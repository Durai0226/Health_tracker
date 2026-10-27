/// What an emergency card says: who, their allergies and conditions, the
/// medicines they take and who to call.
///
/// Plain data from what the app already holds about one person. It says only
/// what was written down: a section nobody filled in reads "Not recorded", never
/// "None" — a card that claimed no allergies because nobody was asked would be
/// worse than no card.
library;

class EmergencyMedicine {
  const EmergencyMedicine(this.name, [this.dose = '']);

  final String name;

  /// "1 tablet", "500 mg"; empty when not known.
  final String dose;

  String get line => dose.isEmpty ? name : '$name · $dose';
}

class EmergencyCardContact {
  const EmergencyCardContact({this.name = '', required this.phone});

  final String name;
  final String phone;

  String get line => name.isEmpty ? phone : '$name · $phone';
}

class EmergencyCard {
  const EmergencyCard({
    this.name,
    this.age,
    this.bloodType,
    this.allergies = const [],
    this.conditions = const [],
    this.medicines = const [],
    this.contact,
  });

  /// Null when the profile still carries the placeholder name.
  final String? name;
  final int? age;
  final String? bloodType;
  final List<String> allergies;
  final List<String> conditions;
  final List<EmergencyMedicine> medicines;
  final EmergencyCardContact? contact;

  /// The name a new profile is created with, before the person gives their own.
  static const String placeholderName = 'Me';

  static const String notRecorded = 'Not recorded';

  /// A card from raw profile fields: trimmed, blanks and repeats dropped,
  /// medicines in alphabetical order.
  static EmergencyCard build({
    String? name,
    DateTime? dateOfBirth,
    String? bloodType,
    List<String>? allergies,
    List<String>? conditions,
    List<EmergencyMedicine> medicines = const [],
    EmergencyCardContact? contact,
    required DateTime now,
  }) {
    final n = name?.trim() ?? '';
    final blood = bloodType?.trim() ?? '';
    final meds = _distinct(medicines, (m) => m.line.toLowerCase()).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return EmergencyCard(
      name: n.isEmpty || n.toLowerCase() == placeholderName.toLowerCase()
          ? null
          : n,
      age: dateOfBirth == null ? null : _age(dateOfBirth, now),
      bloodType: blood.isEmpty ? null : blood,
      allergies: _clean(allergies),
      conditions: _clean(conditions),
      medicines: meds,
      contact: contact,
    );
  }

  /// "Penicillin, Peanuts", or [notRecorded].
  String get allergiesText => allergies.isEmpty ? notRecorded : allergies.join(', ');

  String get conditionsText => conditions.isEmpty ? notRecorded : conditions.join(', ');

  /// The whole card as text, for a message or a note.
  String toPlainText() {
    final b = StringBuffer('EMERGENCY CARD');
    final who = [
      ?name,
      if (age != null) '$age years',
      if (bloodType != null) 'blood type $bloodType',
    ];
    if (who.isNotEmpty) b.write('\n${who.join(' · ')}');
    b
      ..write('\n\nAllergies: $allergiesText')
      ..write('\nConditions: $conditionsText')
      ..write('\n\nMedicines:');
    if (medicines.isEmpty) {
      b.write(' $notRecorded');
    } else {
      for (final m in medicines) {
        b.write('\n- ${m.line}');
      }
    }
    b.write('\n\nEmergency contact: ${contact?.line ?? notRecorded}');
    return b.toString();
  }

  static List<String> _clean(List<String>? raw) =>
      _distinct([for (final s in raw ?? const <String>[]) s.trim()].where((s) => s.isNotEmpty),
              (s) => s.toLowerCase())
          .toList();

  static Iterable<T> _distinct<T>(Iterable<T> items, String Function(T) key) sync* {
    final seen = <String>{};
    for (final i in items) {
      if (seen.add(key(i))) yield i;
    }
  }

  static int _age(DateTime dob, DateTime now) {
    var years = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years < 0 ? 0 : years;
  }
}

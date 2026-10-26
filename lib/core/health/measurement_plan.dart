/// Which home measurement usually goes with what a person is taking.
///
/// Adding a blood-pressure pill, a diabetes pill or a water pill is the moment
/// the matching check routine is most useful, and the app already has reminders
/// for each reading. This table is the missing link between the two.
///
/// It is a SUGGESTION table and nothing more. It never turns a reminder on by
/// itself, carries no thresholds and gives no instruction beyond "this is the
/// reading usually paired with it". How often to measure is the prescriber's
/// call, and the copy says so.
///
/// Keyed on single lower-case words, matched against the whole words of both
/// the typed name and its resolved generic, so "Metoprolol 50 mg" and an
/// "Insulin glargine" pen both reach their rule while "Lipril" cannot reach a
/// hypothetical "Liprilstatin".
library;

import 'package:flutter/foundation.dart';

/// A reading the app can remind about.
enum MeasurementKind { bloodPressure, bloodGlucose, weight }

/// One reminder in a routine, as a clock time.
@immutable
class RoutineSlot {
  final int hour;
  final int minute;
  const RoutineSlot(this.hour, this.minute);
}

/// The routine offered for one [MeasurementKind].
@immutable
class MeasurementSuggestion {
  final MeasurementKind kind;

  /// Short title for the offer ("Blood pressure, morning and evening").
  final String title;

  /// Why this reading goes with the medicine. Written as "people taking this",
  /// never as an instruction.
  final String reason;

  /// Reminder times. BP is two (morning and evening); the others one.
  final List<RoutineSlot> slots;

  const MeasurementSuggestion({
    required this.kind,
    required this.title,
    required this.reason,
    required this.slots,
  });
}

class MeasurementPlan {
  const MeasurementPlan._();

  static const _bloodPressure = <String>{
    'amlodipine', 'losartan', 'telmisartan', 'olmesartan', 'valsartan',
    'irbesartan', 'candesartan', 'enalapril', 'lisinopril', 'ramipril',
    'perindopril', 'atenolol', 'metoprolol', 'bisoprolol', 'carvedilol',
    'nebivolol', 'propranolol', 'nifedipine', 'diltiazem', 'verapamil',
    'hydrochlorothiazide', 'chlorthalidone', 'indapamide', 'clonidine',
    'prazosin',
  };

  static const _bloodGlucose = <String>{
    'metformin', 'glimepiride', 'gliclazide', 'glipizide', 'glibenclamide',
    'sitagliptin', 'vildagliptin', 'linagliptin', 'saxagliptin',
    'teneligliptin', 'dapagliflozin', 'empagliflozin', 'canagliflozin',
    'pioglitazone', 'insulin', 'glargine', 'lispro', 'aspart', 'liraglutide',
    'semaglutide',
  };

  /// Loop and potassium-sparing diuretics ("water pills"). Daily weight is the
  /// usual way a change in fluid shows up first.
  static const _weight = <String>{
    'furosemide', 'torsemide', 'torasemide', 'bumetanide', 'spironolactone',
  };

  /// Whole lower-case words of every name given, so a strength or a form
  /// ("500 mg", "SR", "pen") is just more words that match nothing.
  static Set<String> _words(Iterable<String?> names) => {
        for (final n in names)
          if (n != null)
            ...n.toLowerCase().split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty),
      };

  /// The kinds that go with a medicine called [name], whose catalogue generic
  /// is [generic] when the catalogue knew it.
  static Set<MeasurementKind> kindsFor(String name, {String? generic}) {
    final words = _words([name, generic]);
    return {
      if (words.any(_bloodPressure.contains)) MeasurementKind.bloodPressure,
      if (words.any(_bloodGlucose.contains)) MeasurementKind.bloodGlucose,
      if (words.any(_weight.contains)) MeasurementKind.weight,
    };
  }

  /// The offer for [kind]. [medicineName] is what the user typed, shown back so
  /// the reason reads as being about THEIR medicine.
  static MeasurementSuggestion suggestionFor(
      MeasurementKind kind, String medicineName) {
    switch (kind) {
      case MeasurementKind.bloodPressure:
        return MeasurementSuggestion(
          kind: kind,
          title: 'Blood pressure, morning and evening',
          reason: 'Home readings show how $medicineName is working. Two a '
              'day gives the clearest picture; ask your clinician how often '
              'they want them.',
          slots: const [RoutineSlot(8, 0), RoutineSlot(19, 0)],
        );
      case MeasurementKind.bloodGlucose:
        return MeasurementSuggestion(
          kind: kind,
          title: 'Fasting blood sugar',
          reason: 'A reading before breakfast is the one most often paired '
              'with $medicineName. Ask your clinician if you need more.',
          slots: const [RoutineSlot(7, 30)],
        );
      case MeasurementKind.weight:
        return MeasurementSuggestion(
          kind: kind,
          title: 'Daily weight',
          reason: '$medicineName changes how your body holds fluid, and '
              'weight is where that shows first. Weigh in the morning, before '
              'eating.',
          slots: const [RoutineSlot(7, 0)],
        );
    }
  }

  /// What to offer for a new medicine.
  ///
  /// [alreadyOn] are the kinds whose reminders the user has already set up, and
  /// [declined] the ones they said "not now" to: neither is asked again.
  static List<MeasurementSuggestion> offer(
    String name, {
    String? generic,
    Set<MeasurementKind> alreadyOn = const {},
    Set<MeasurementKind> declined = const {},
  }) {
    final kinds = kindsFor(name, generic: generic)
        .difference(alreadyOn)
        .difference(declined);
    // Fixed order, so the sheet never shuffles between two runs.
    return [
      for (final k in MeasurementKind.values)
        if (kinds.contains(k)) suggestionFor(k, name),
    ];
  }
}

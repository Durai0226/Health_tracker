import '../models/medicine_log.dart'
    show MedicineLog, moodRatingLabels, effectivenessRatingLabels, nearestRatingLabel;

/// One medicine's side-effect / mood / effectiveness signal over a report
/// window. Medisafe's own report covers adherence and measurements but not
/// this — DailyMinder already captures mood, side effects and effectiveness
/// on every dose ([nunito_take_medication_sheet.dart]) and never surfaces any
/// of it. This turns those captured-but-unread fields into the "Symptoms &
/// well-being" section of [AdherenceReportService.buildPdf] and new CSV
/// columns.
class MedicineSymptomSummary {
  final String medicineLabel;
  final int takenCount;

  /// Side-effect label -> how many taken doses reported it.
  final Map<String, int> sideEffectCounts;

  /// Mean of every non-null `moodRating` among taken doses (1-5), or null if
  /// none were recorded.
  final double? meanMood;

  /// Mean of every non-null `effectivenessRating` among taken doses (1-5), or
  /// null if none were recorded.
  final double? meanEffectiveness;

  const MedicineSymptomSummary({
    required this.medicineLabel,
    required this.takenCount,
    required this.sideEffectCounts,
    required this.meanMood,
    required this.meanEffectiveness,
  });

  bool get hasAnyData =>
      sideEffectCounts.isNotEmpty || meanMood != null || meanEffectiveness != null;

  /// Nearest mood label for [meanMood] (e.g. "Okay"), or null if unrecorded.
  ///
  /// Prefer this over the raw number when mood and effectiveness might be
  /// shown side by side (e.g. a report table): [moodRatingLabels] and
  /// [effectivenessRatingLabels] run in OPPOSITE directions (mood: 1 = best,
  /// effectiveness: 1 = worst), so a bare "3.2/5" for each reads as "higher
  /// is better" for both when that's only true for one of them.
  String? get moodLabel =>
      meanMood != null ? nearestRatingLabel(meanMood!, moodRatingLabels) : null;

  /// Nearest effectiveness label for [meanEffectiveness] (e.g. "Good"), or
  /// null if unrecorded. See [moodLabel] for why a label, not a raw number.
  String? get effectivenessLabel => meanEffectiveness != null
      ? nearestRatingLabel(meanEffectiveness!, effectivenessRatingLabels)
      : null;

  /// Side effects as `"Nausea x6, Headache x2"`, most-reported first — or
  /// null if none were recorded.
  String? get sideEffectsLabel {
    if (sideEffectCounts.isEmpty) return null;
    final sorted = sideEffectCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => '${e.key} x${e.value}').join(', ');
  }
}

/// Summarizes [dedupedLogs] for one medicine. [dedupedLogs] MUST already be
/// deduped (`MedicineCleanStorageService.dedupeByDose`) and windowed to the
/// report range by the caller — the same list it uses for its own
/// taken/missed/skipped counts — or a slot with a stale duplicate row (e.g. a
/// `missed` row later superseded by a `taken` one) double-counts here too.
///
/// Only TAKEN (or pre-logged — the detail expander is captured at pre-log
/// time too) doses can carry symptom data (`MedicineLog.skipped`/`.missed`
/// never set `sideEffects`/`moodRating`/`effectivenessRating`), so only those
/// are considered.
MedicineSymptomSummary summarizeSymptoms(
  String medicineLabel,
  List<MedicineLog> dedupedLogs,
) {
  final taken = dedupedLogs.where((l) => l.countsAsTaken).toList();

  final sideEffectCounts = <String, int>{};
  final moods = <int>[];
  final effectiveness = <int>[];

  for (final log in taken) {
    final raw = log.sideEffects;
    if (raw != null && raw.trim().isNotEmpty) {
      for (final label in raw.split(',')) {
        final trimmed = label.trim();
        if (trimmed.isEmpty) continue;
        sideEffectCounts[trimmed] = (sideEffectCounts[trimmed] ?? 0) + 1;
      }
    }
    if (log.moodRating != null) moods.add(log.moodRating!);
    if (log.effectivenessRating != null) {
      effectiveness.add(log.effectivenessRating!);
    }
  }

  double? mean(List<int> xs) =>
      xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;

  return MedicineSymptomSummary(
    medicineLabel: medicineLabel,
    takenCount: taken.length,
    sideEffectCounts: sideEffectCounts,
    meanMood: mean(moods),
    meanEffectiveness: mean(effectiveness),
  );
}

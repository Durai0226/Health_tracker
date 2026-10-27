import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/health/visit_brief.dart';
import '../../../core/health/vitals_analyzer.dart';
import '../models/blood_pressure_reading.dart';
import '../models/doctor_pharmacy.dart';
import '../models/enhanced_medicine.dart';
import '../models/glucose_reading.dart';
import '../models/weight_reading.dart';
import 'adherence_report_service.dart';
import 'bp_sessions.dart';
import 'medicine_storage_service.dart';
import 'vitals_storage_service.dart';

/// Blood pressure over the window, as sessions (two readings a minute apart are
/// one measurement).
class BpSummary {
  const BpSummary({
    required this.sessions,
    required this.readings,
    required this.avgSystolic,
    required this.avgDiastolic,
    required this.minSystolic,
    required this.maxSystolic,
    required this.minDiastolic,
    required this.maxDiastolic,
  });

  final int sessions;
  final int readings;
  final int avgSystolic;
  final int avgDiastolic;
  final int minSystolic;
  final int maxSystolic;
  final int minDiastolic;
  final int maxDiastolic;
}

class GlucoseSummary {
  const GlucoseSummary({
    required this.readings,
    required this.avgMgdl,
    required this.minMgdl,
    required this.maxMgdl,
    this.inRangePercent,
  });

  final int readings;
  final int avgMgdl;
  final int minMgdl;
  final int maxMgdl;

  /// Share of readings within the target for their context, 0..100.
  final int? inRangePercent;
}

class WeightSummary {
  const WeightSummary({required this.firstKg, required this.lastKg, required this.readings});

  final double firstKg;
  final double lastKg;
  final int readings;

  double get changeKg => lastKg - firstKg;
}

/// What a visit's summary holds: the days it covers, how the doses went, what
/// was measured, what changed on the list and what the person wants to raise.
class VisitBrief {
  const VisitBrief({
    required this.appointment,
    required this.window,
    required this.generatedAt,
    required this.medicines,
    required this.due,
    required this.taken,
    required this.missed,
    required this.skipped,
    this.bp,
    this.glucose,
    this.weight,
    this.started = const [],
    this.stopped = const [],
    this.discuss = const [],
    this.patientName,
  });

  final Appointment appointment;
  final VisitBriefWindow window;
  final DateTime generatedAt;

  /// Every medicine that was being taken, the one that went least well first.
  final List<MedicineAdherence> medicines;

  /// Doses due, taken, missed and skipped, over all of them.
  final int due;
  final int taken;
  final int missed;
  final int skipped;

  final BpSummary? bp;
  final GlucoseSummary? glucose;
  final WeightSummary? weight;

  /// Medicines added in the window, and those put away in it.
  final List<EnhancedMedicine> started;
  final List<EnhancedMedicine> stopped;

  /// What the person wrote down to raise: the purpose, the notes and the
  /// medicines linked to the visit.
  final List<String> discuss;

  /// Whose brief, for someone looked after; null for the account holder.
  final String? patientName;

  /// Percent of due doses taken; null when none came due.
  int? get overallPercent => due > 0 ? (taken / due * 100).round() : null;

  bool get hasVitals => bp != null || glucose != null || weight != null;
}

/// Builds the brief for an appointment from what the app already holds.
class VisitBriefService {
  const VisitBriefService._();

  /// A brief with no medicines or readings is still a brief: it says what it
  /// covers and what there is to discuss. A database that cannot be read gives
  /// the same, rather than an error where someone is getting ready to see their
  /// doctor.
  static Future<VisitBrief> build(Appointment a, {DateTime? now}) async {
    final n = now ?? clock.now();
    var earlier = const <DateTime>[];
    try {
      final all = await MedicineCleanStorageService.getAllAppointments(
          scopeToActiveProfile: false);
      earlier = [
        for (final o in all)
          if (o.dependentId == a.dependentId &&
              _sameDoctor(o, a) &&
              (o.isCompleted || o.dateTime.isBefore(n)))
            o.dateTime,
      ];
    } catch (e) {
      debugPrint('⚠️ Visit brief: appointments failed: $e');
    }
    final window = VisitBriefs.window(visitAt: a.dateTime, now: n, earlierVisits: earlier);

    var medicines = <EnhancedMedicine>[];
    try {
      medicines = (await MedicineCleanStorageService.getAllMedicines(
              includeArchived: true, scopeToActiveProfile: false))
          .where((m) => m.dependentId == a.dependentId)
          .toList();
    } catch (e) {
      debugPrint('⚠️ Visit brief: medicines failed: $e');
    }

    final entries = <MedicineReportEntry>[];
    for (final m in medicines.where((m) => m.isActive && !m.isArchived)) {
      try {
        final logs = await MedicineCleanStorageService.getLogsForMedicine(m.id,
            scopeToActiveProfile: false);
        entries.add(MedicineReportEntry(medicine: m, logs: logs));
      } catch (e) {
        debugPrint('⚠️ Visit brief: logs for ${m.id} failed: $e');
      }
    }
    final perMedicine = AdherenceReportService.perMedicine(entries, window.from, window.to, n)
      ..sort(MedicineAdherence.leastWellFirst);
    final due = perMedicine.fold<int>(0, (s, m) => s + m.due);
    final taken = perMedicine.fold<int>(0, (s, m) => s + m.taken);
    final missed = perMedicine.fold<int>(0, (s, m) => s + m.missed);
    final skipped = perMedicine.fold<int>(0, (s, m) => s + m.skipped);

    BpSummary? bp;
    GlucoseSummary? glucose;
    WeightSummary? weight;
    try {
      bp = _bp(await VitalsStorageService.getBpForRange(window.from, window.to,
          scopeToActiveProfile: false), a.dependentId);
      glucose = _glucose(await VitalsStorageService.getGlucoseForRange(
          window.from, window.to,
          scopeToActiveProfile: false), a.dependentId);
      weight = _weight(await VitalsStorageService.getWeightForRange(
          window.from, window.to,
          scopeToActiveProfile: false), a.dependentId);
    } catch (e) {
      debugPrint('⚠️ Visit brief: vitals failed: $e');
    }

    bool inWindow(DateTime t) => !t.isBefore(window.from) && !t.isAfter(window.to);
    final started = [
      for (final m in medicines)
        if (inWindow(m.createdAt)) m,
    ];
    final stopped = [
      for (final m in medicines)
        if ((!m.isActive || m.isArchived) && m.updatedAt != null && inWindow(m.updatedAt!)) m,
    ];

    String? patient;
    if (a.dependentId != null) {
      try {
        patient = (await MedicineCleanStorageService.profileFor(a.dependentId))?.name;
      } catch (_) {}
    }

    return VisitBrief(
      appointment: a,
      window: window,
      generatedAt: n,
      medicines: perMedicine,
      due: due,
      taken: taken,
      missed: missed,
      skipped: skipped,
      bp: bp,
      glucose: glucose,
      weight: weight,
      started: started,
      stopped: stopped,
      discuss: _discuss(a, medicines),
      patientName: patient,
    );
  }

  /// The same doctor: by id when both have one, otherwise by name.
  static bool _sameDoctor(Appointment x, Appointment y) {
    if (x.doctorId != null && y.doctorId != null) return x.doctorId == y.doctorId;
    return x.doctorName.trim().toLowerCase() == y.doctorName.trim().toLowerCase();
  }

  static List<String> _discuss(Appointment a, List<EnhancedMedicine> medicines) {
    String? clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    final linked = <String>[
      for (final id in a.medicineIds ?? const <String>[])
        for (final m in medicines)
          if (m.id == id) m.name,
    ];
    return [
      ?clean(a.purpose),
      ?clean(a.notes),
      if (linked.isNotEmpty) 'Medicines to talk about: ${linked.join(', ')}',
    ];
  }

  static BpSummary? _bp(List<BloodPressureReading> all, String? dependentId) {
    final mine = [for (final r in all) if (r.dependentId == dependentId) r];
    final sessions = BpSessions.collapse(mine);
    if (sessions.isEmpty) return null;
    final sys = [for (final s in sessions) s.systolic];
    final dia = [for (final s in sessions) s.diastolic];
    int lo(List<int> v) => v.reduce((a, b) => a < b ? a : b);
    int hi(List<int> v) => v.reduce((a, b) => a > b ? a : b);
    return BpSummary(
      sessions: sessions.length,
      readings: mine.length,
      avgSystolic: VitalsAnalyzer.mean(sys)!.round(),
      avgDiastolic: VitalsAnalyzer.mean(dia)!.round(),
      minSystolic: lo(sys),
      maxSystolic: hi(sys),
      minDiastolic: lo(dia),
      maxDiastolic: hi(dia),
    );
  }

  static GlucoseSummary? _glucose(List<GlucoseReading> all, String? dependentId) {
    final mine = [for (final r in all) if (r.dependentId == dependentId) r];
    if (mine.isEmpty) return null;
    final v = [for (final r in mine) r.valueMgdl];
    final inRange = VitalsAnalyzer.inRangePercent(
        [for (final r in mine) (mgdl: r.valueMgdl, ctx: r.context)]);
    return GlucoseSummary(
      readings: mine.length,
      avgMgdl: VitalsAnalyzer.mean(v)!.round(),
      minMgdl: v.reduce((a, b) => a < b ? a : b),
      maxMgdl: v.reduce((a, b) => a > b ? a : b),
      inRangePercent: inRange == null ? null : (inRange * 100).round(),
    );
  }

  static WeightSummary? _weight(List<WeightReading> all, String? dependentId) {
    final mine = [for (final r in all) if (r.dependentId == dependentId) r]
      ..sort((a, b) => a.takenAt.compareTo(b.takenAt));
    if (mine.isEmpty) return null;
    return WeightSummary(
        firstKg: mine.first.valueKg, lastKg: mine.last.valueKg, readings: mine.length);
  }
}

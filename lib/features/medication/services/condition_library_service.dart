/// Wires the curated condition pages to the user's own medicines.
///
/// ## The claim, and the line it must not cross
///
/// Suggestions are allowed; findings are not. *"People taking Amlodipine often
/// read about high blood pressure"* is a reading suggestion. *"Your condition:
/// hypertension"* is a diagnostic claim, and under Play's Health Content policy
/// that is a different product.
///
/// Every link this service produces is therefore framed as **the medicine's
/// drug family**, on a page **the user chose to open**. The subject of the
/// sentence is always the medicine, never the reader.
///
/// ## What it reads, and what it deliberately does not
///
/// | signal | status |
/// |---|---|
/// | name → generic → monograph `class` | **primary.** Deterministic, curated, and measured against all 160 monographs. |
/// | `purpose` free text | **secondary, and weak.** The user typed it, which is worth something, but it is untrimmed free text whose own form hint suggests "Blood pressure" — a measurement, not a condition. |
/// | `healthCategories` | **unusable.** The column is written on every save as a carry-forward, but nothing in the app ever *originates* a non-null value, so it is null for every real user. |
/// | `EnhancedMedicine.condition` | **unusable.** No backing column on the medicines table; always null after a round-trip. |
///
/// ## Query-count contract: 1–3 selects, constant in the number of conditions
///
/// The trap is asking "which medicines match THIS condition" fourteen times.
/// This inverts instead: **one** pass over the medicines, resolving each
/// generic once, then a fold into `Map<conditionId, links>`. Vitals are read
/// **only** when the conditions that use them are actually linked, so a user
/// with neither hypertension nor diabetes pays for one select and no more.
///
/// ## It never throws
///
/// The curated content is a compile-time `const`, so there is no failure mode
/// that should show the user an error. A failed medicine read degrades to "no
/// personalisation" — the encyclopedia still works.
library;

import 'package:flutter/foundation.dart';

import '../../../core/health/drug_info_catalog.dart';
import '../../../core/health/vitals_analyzer.dart';
import '../data/condition_library_data.dart';
import '../models/condition_info.dart';
import '../models/enhanced_medicine.dart';
import 'condition_taxonomy.dart';
import 'drug_name_catalog.dart';
import 'medicine_storage_service.dart';
import 'vitals_storage_service.dart';

/// Why a medicine appears on a condition page.
///
/// Rendered verbatim into a "why am I seeing this" chip, so the user can always
/// inspect the reasoning rather than take it on trust.
enum LinkBasis {
  /// The monograph's drug family matched. High precision, and the only basis
  /// backed by the 160-monograph sweep.
  drugClass,

  /// The user's own free-text "Purpose" mentioned this condition by name or by
  /// one of its aliases. Lower precision, but it is the user's own words.
  purpose,
}

@immutable
class ConditionMedicineLink {
  /// The medicine itself, so tapping through to its detail screen needs no
  /// second read. `buildFrom` already holds it.
  final EnhancedMedicine medicine;

  final LinkBasis basis;

  /// The monograph class, when there is one — e.g. "Blood-pressure medicine
  /// (calcium channel blocker)". Null for a [LinkBasis.purpose] link.
  final String? drugClass;

  /// The family phrase for the chip — "calcium channel blocker".
  final String? family;

  const ConditionMedicineLink({
    required this.medicine,
    required this.basis,
    this.drugClass,
    this.family,
  });

  String get medicineId => medicine.id;
  String get medicineName => medicine.name;

  /// The explanatory sentence. Deliberately about the MEDICINE.
  ///
  /// No second person, no "your condition", no "diagnosed", no "you may have" —
  /// `condition_library_copy_guard_test.dart` fails the build on any of those
  /// appearing in this feature's user-facing strings.
  String get why => switch (basis) {
        // "It does not mean you have this condition" was the first draft. It is
        // a NEGATION of the banned claim and perfectly honest — but the copy
        // guard is a blunt substring check, and a guard that has to understand
        // negation is a guard that will eventually be wrong about it. Reworded
        // so a lay reader and a grep read it the same way.
        LinkBasis.drugClass => family == null
            ? "This medicine's drug family is commonly used for conditions in "
                'this area. That is not a diagnosis — only a clinician can say '
                'what applies to you.'
            : "This medicine's drug family ($family) is commonly used for "
                'conditions in this area. That is not a diagnosis — only a '
                'clinician can say what applies to you.',
        LinkBasis.purpose =>
          'You noted what this medicine is for when you added it, and it '
              'mentions this area.',
      };
}

@immutable
class ConditionLibraryPersonalisation {
  /// conditionId → the user's medicines related to it, drug-class links first.
  final Map<String, List<ConditionMedicineLink>> byCondition;

  /// True once a medicine read has completed, whatever it found. Distinguishes
  /// "nothing to show" from "not looked yet", so the browse sliver is ABSENT
  /// rather than empty before the first load.
  final bool loaded;

  const ConditionLibraryPersonalisation({
    this.byCondition = const {},
    this.loaded = false,
  });

  static const empty = ConditionLibraryPersonalisation();

  List<ConditionMedicineLink> linksFor(String conditionId) =>
      byCondition[conditionId] ?? const [];

  /// Conditions with at least one link, in the curated library's own order so
  /// the pinned sliver does not reshuffle between builds.
  List<ConditionInfo> get relatedConditions => [
        for (final c in conditionLibrary)
          if ((byCondition[c.id] ?? const []).isNotEmpty) c,
      ];
}

/// The user's own recent readings for a condition that has an objective
/// measurement with published thresholds.
///
/// Two conditions only — hypertension and type-2-diabetes. Both are measured
/// numbers that [VitalsAnalyzer] already classifies against published
/// thresholds, which is a different kind of claim from a self-report.
///
/// Deliberately NOT offered for the Depression or Anxiety pages, even though
/// the mood data exists: mood here is a 1-5 self-report with no validated
/// instrument behind it, and rendering "your average mood: 2.8" on a page
/// titled Depression invites reading it as a severity score — the most
/// diagnosis-like thing this feature could do.
@immutable
class ConditionReadings {
  final int count;
  final DateTime? latestAt;

  /// Pre-formatted for display, e.g. "128/82" or "112 mg/dL".
  final String? latestValue;

  /// The analyzer's own label for the latest reading, e.g. "Elevated".
  final String? latestLabel;

  const ConditionReadings({
    required this.count,
    this.latestAt,
    this.latestValue,
    this.latestLabel,
  });

  bool get hasAny => count > 0;
}

abstract final class ConditionLibraryService {
  static ConditionLibraryPersonalisation _cache =
      ConditionLibraryPersonalisation.empty;
  static int _cachedRevision = -1;

  /// The personalisation layer. Never throws.
  ///
  /// Cached against `MedicineCleanStorageService.revision`, which already ticks
  /// on every medicine write — so adding a medicine refreshes this without a
  /// second notifier to keep in step.
  static Future<ConditionLibraryPersonalisation> load({
    bool force = false,
  }) async {
    final revision = MedicineCleanStorageService.revision.value;
    if (!force && _cachedRevision == revision && _cache.loaded) return _cache;

    try {
      await DrugNameCatalog.ensureLoaded();
      await DrugInfoCatalog.ensureLoaded();
      // THE one select. Archived medicines are included on purpose: a page
      // about a condition you used to treat is still the page you want to read.
      final medicines =
          await MedicineCleanStorageService.getAllMedicines(includeArchived: true);
      _cache = buildFrom(medicines);
      _cachedRevision = revision;
    } catch (e) {
      debugPrint('ConditionLibraryService.load failed: $e');
      // Degrade to the plain encyclopedia rather than an error screen.
      _cache = const ConditionLibraryPersonalisation(loaded: true);
      _cachedRevision = revision;
    }
    return _cache;
  }

  /// The pure half, so the whole mapping is testable without a database.
  ///
  /// Invert, don't scan: one pass over [medicines], each generic resolved once,
  /// folded into a map keyed by condition. Cost is O(medicines), independent of
  /// how many conditions the library holds.
  @visibleForTesting
  static ConditionLibraryPersonalisation buildFrom(
      List<EnhancedMedicine> medicines) {
    final byCondition = <String, List<ConditionMedicineLink>>{};
    // Two medicines can resolve to the same generic; resolve each one once.
    final classByGeneric = <String, String?>{};

    void add(String conditionId, ConditionMedicineLink link) {
      final list = byCondition.putIfAbsent(conditionId, () => []);
      // A medicine already linked by drug class is not re-added by purpose —
      // the stronger basis wins, and one row per medicine is what the UI shows.
      if (list.any((l) => l.medicineId == link.medicineId)) return;
      list.add(link);
    }

    for (final m in medicines) {
      final key = (m.genericName?.trim().isNotEmpty ?? false)
          ? m.genericName!.trim()
          : m.name.trim();
      if (key.isEmpty) continue;

      final drugClass = classByGeneric.putIfAbsent(key.toLowerCase(), () {
        final generic = DrugNameCatalog.genericFor(key) ?? key;
        return DrugInfoCatalog.find(generic: generic, displayName: key)?.klass;
      });

      if (drugClass != null) {
        for (final id in ConditionTaxonomy.conditionsForClass(drugClass)) {
          add(
            id,
            ConditionMedicineLink(
              medicine: m,
              basis: LinkBasis.drugClass,
              drugClass: drugClass,
              family: ConditionTaxonomy.familyPhrase(drugClass),
            ),
          );
        }
      }

      for (final id in _conditionsFromPurpose(m.purpose)) {
        add(
          id,
          ConditionMedicineLink(
            medicine: m,
            basis: LinkBasis.purpose,
          ),
        );
      }
    }

    // Drug-class links first within each condition: the stronger basis reads
    // first, and the ordering is stable rather than insertion-dependent.
    for (final list in byCondition.values) {
      list.sort((a, b) {
        final byBasis = a.basis.index.compareTo(b.basis.index);
        return byBasis != 0
            ? byBasis
            : a.medicineName.toLowerCase().compareTo(b.medicineName.toLowerCase());
      });
    }

    return ConditionLibraryPersonalisation(
        byCondition: byCondition, loaded: true);
  }

  /// Conditions whose name or an alias appears in the user's own `purpose` text.
  ///
  /// Word-boundary matched, not `contains`. A bare substring test puts every
  /// medicine whose purpose mentions "pressure" onto the hypertension page, and
  /// — worse — the alias "AF" would match the word "affects".
  @visibleForTesting
  static Set<String> conditionsFromPurpose(String? purpose) =>
      _conditionsFromPurpose(purpose);

  static Set<String> _conditionsFromPurpose(String? purpose) {
    final text = purpose?.trim().toLowerCase();
    if (text == null || text.isEmpty) return const {};

    final out = <String>{};
    for (final c in conditionLibrary) {
      for (final term in [c.name, ...c.aliases]) {
        final t = term.trim().toLowerCase();
        // Single letters and two-letter abbreviations are too collision-prone
        // in free text to be worth the false positives.
        if (t.length < 3) continue;
        if (_containsWord(text, t)) {
          out.add(c.id);
          break;
        }
      }
    }
    return out;
  }

  static final RegExp _nonWord = RegExp(r'[^a-z0-9]+');

  /// Whether [needle] appears in [haystack] on word boundaries.
  static bool _containsWord(String haystack, String needle) {
    final hs = haystack.split(_nonWord).where((w) => w.isNotEmpty).toList();
    final ns = needle.split(_nonWord).where((w) => w.isNotEmpty).toList();
    if (ns.isEmpty || ns.length > hs.length) return false;
    for (var i = 0; i + ns.length <= hs.length; i++) {
      var ok = true;
      for (var j = 0; j < ns.length; j++) {
        if (hs[i + j] != ns[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  }

  /// Which conditions have an objective measurement worth showing.
  ///
  /// Anything not in here renders no readings section at all — absent, not
  /// empty. A permanently empty "Your recent readings" box on twelve of the
  /// fourteen pages is noise that trains people to ignore the section on the
  /// two where it matters.
  static const Set<String> conditionsWithReadings = {
    'hypertension',
    'type-2-diabetes',
  };

  /// Recent readings for [conditionId], or null when this condition has none to
  /// offer or the read failed.
  ///
  /// **Conditional by design** — this is the second and third select of the
  /// 1-3 contract, and a user with neither condition linked never pays for
  /// either. The caller decides whether to ask.
  static Future<ConditionReadings?> readingsFor(
    String conditionId, {
    DateTime? now,
    Duration window = const Duration(days: 90),
  }) async {
    if (!conditionsWithReadings.contains(conditionId)) return null;
    final to = now ?? DateTime.now();
    final from = to.subtract(window);

    try {
      if (conditionId == 'hypertension') {
        final rows = await VitalsStorageService.getBpForRange(from, to);
        if (rows.isEmpty) return const ConditionReadings(count: 0);
        final latest = rows.reduce((a, b) => a.takenAt.isAfter(b.takenAt) ? a : b);
        return ConditionReadings(
          count: rows.length,
          latestAt: latest.takenAt,
          latestValue: '${latest.systolic}/${latest.diastolic}',
          latestLabel: VitalsAnalyzer.bpLabel(
              VitalsAnalyzer.classifyBp(latest.systolic, latest.diastolic)),
        );
      }

      final rows = await VitalsStorageService.getGlucoseForRange(from, to);
      if (rows.isEmpty) return const ConditionReadings(count: 0);
      final latest = rows.reduce((a, b) => a.takenAt.isAfter(b.takenAt) ? a : b);
      return ConditionReadings(
        count: rows.length,
        latestAt: latest.takenAt,
        latestValue: '${latest.valueMgdl} mg/dL',
        // The reading's own context matters: 110 fasting and 110 after a meal
        // classify differently, and the service already carries it.
        latestLabel: VitalsAnalyzer.glucoseLabel(
            VitalsAnalyzer.classifyGlucose(latest.valueMgdl, latest.context)),
      );
    } catch (e) {
      debugPrint('ConditionLibraryService.readingsFor failed: $e');
      // Null, not zero. "We could not read" and "you have logged none" are
      // different facts and must not share a rendering.
      return null;
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _cache = ConditionLibraryPersonalisation.empty;
    _cachedRevision = -1;
  }
}

/// The data behind the Weekly Recap.
///
/// ## Built on TrendsBundle, not on its own reads
///
/// The plan for this rebuild called for a new `InsightInputs` layer to
/// de-duplicate the recap's reads. Reading `TrendsDataService.build` made that
/// unnecessary: it already computes **exactly** the window this screen needs
/// (`today - 6 days .. today`, both day-only), already runs its four store
/// inits through one `Future.wait` and its four async series concurrently, and
/// already reads blood pressure and glucose through the **ranged** variants.
///
/// So the recap composes that bundle instead of duplicating it. What this buys,
/// against the screen being replaced:
///
/// | | before | after |
/// |---|---|---|
/// | awaits in series | **6** | 1 bundle + 2, concurrent |
/// | unbounded full-table reads per open | **5** | 0 |
/// | `medicine_logs` reads per open | **3** | 1 |
/// | window definitions in one method | **2, disagreeing** | 1, shared with Trends |
///
/// An earlier version of this table said 8 awaits. It was wrong, and the count
/// matters because it is the thing being fixed: water and focus are *synchronous*
/// getters over in-memory stores, so the real figure is six
/// (`weekly_recap_screen.dart` lines 75, 109, 118, 128, 136, 146).
///
/// The unbounded-read count was also an undercount. One open issues five
/// full-table selects — `vitals_bp` twice, `vitals_glucose` twice, `mood_entries`
/// once — and three reads of `medicine_logs`, two of them inside
/// `InsightService.gatherAll` itself rather than duplicated between the screen
/// and the service.
///
/// That "2, disagreeing" is worth spelling out because it was not in the brief.
/// The old gather used `now.subtract(Duration(days: 7))` plus `isAfter(from)`
/// for adherence, vitals and focus — a rolling 168-hour window measured from the
/// current clock time — while water, steps and sleep looped over seven calendar
/// days including today. Two different weeks, on one screen, under one heading.
///
/// ## The three-state contract
///
/// **null means "we don't know". Zero means "we measured zero". A thrown error
/// means "ask again."** The screen this replaces collapsed all three: every one
/// of its six data blocks was wrapped in `catch (_) {}`, so a real database
/// failure rendered as legitimate zeros and the retry panel could never appear.
///
/// Here, a failure in the bundle is fatal to the load and surfaces the retry
/// panel. A failure in a non-hero extra lands in [failedSources] and surfaces a
/// partial banner, because losing the personal-bests row should not cost the
/// user the whole page.
///
/// It also removes a fabricated default the brief missed: the old gather
/// initialised `var regularity = 0.75` and then swallowed the exception that
/// would leave it there, so a failed sleep read rendered a plausible-looking
/// regularity index that no data supported.
library;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/health/insight.dart';
import '../../medication/services/medicine_storage_service.dart';
import 'insight_service.dart';
import 'trends_data_service.dart';
import '../../../core/utils/calendar_day.dart';

/// The hero figure's subject, chosen by what the week actually contains.
enum RecapHeroKind {
  /// Dose adherence, with the number of days that had doses due as its
  /// denominator.
  adherence,

  /// Nothing was due all week, so adherence has no denominator and a percentage
  /// would be invented. Falls back to how many days were logged at all.
  daysLogged,
}

@immutable
class RecapHero {
  final RecapHeroKind kind;

  /// Null when there is genuinely nothing to show — never 0 as a stand-in.
  final int? value;

  /// The denominator, spelled out. "86%" alone is magic; "86%" with *across 5
  /// days with doses due* underneath is checkable.
  final String? denominator;

  /// Change against the previous seven days, or null when there is no
  /// comparable previous week.
  final int? deltaPct;

  const RecapHero({
    required this.kind,
    this.value,
    this.denominator,
    this.deltaPct,
  });

  bool get hasValue => value != null;
}

@immutable
class WeeklyRecap {
  /// Every daily series for the week, from the same source Trends uses.
  final TrendsBundle bundle;

  final RecapHero hero;

  /// Week-scoped insights only.
  final List<Insight> highlights;

  /// Sources that failed but were not fatal. Non-empty means a partial banner.
  final Set<String> failedSources;

  /// First and last day of the window, both day-only. Exposed so the screen can
  /// state the range rather than implying one.
  final DateTime from;
  final DateTime to;

  const WeeklyRecap({
    required this.bundle,
    required this.hero,
    required this.highlights,
    required this.from,
    required this.to,
    this.failedSources = const {},
  });

  /// True when no tracker recorded anything all week.
  ///
  /// Distinct from "first run", which the screen decides separately — *you are
  /// new* and *you stopped* deserve different words.
  bool get isEmptyWeek => !bundle.adherence.hasData &&
      !bundle.water.hasData &&
      !bundle.steps.hasData &&
      !bundle.sleep.hasData &&
      !bundle.focus.hasData &&
      !bundle.bloodPressure.hasData &&
      !bundle.glucose.hasData &&
      !bundle.weight.hasData &&
      !bundle.period.hasData;
}

abstract final class WeeklyRecapService {
  /// Insight ids whose signal covers a MULTI-DAY window.
  ///
  /// `InsightService.gatherAll` mixes windows. Roughly half its signals are
  /// scoped to today — "you're behind on water this afternoon", "you hit your
  /// step goal", "you slept short last night" — and rendering any of those under
  /// a heading that says *your last 7 days* is an off-window claim, however true
  /// the sentence is on its own.
  ///
  /// An allow-list rather than a deny-list on purpose: a new insight is
  /// today-scoped until someone decides otherwise, which is the safe default
  /// for a page making a weekly claim.
  static const Set<String> weekScopedInsightIds = {
    'med_adherence',
    'med_adherence_good',
    'med_streak',
    'med_missrisk',
    'med_refill',
    'water_streak',
    'focus_completion',
    'focus_besthour',
    'focus_streak',
    'steps_streak',
    // 'steps_short' is NOT here. Its own sentence says "about N steps from
    // today's goal" and its why is "Today's steps vs your daily goal" — a
    // true statement about today, which is exactly what this list exists to
    // keep out of a heading that says "your last 7 days". It sat here for
    // months because the guard test enumerated the EXCLUDED ids by hand and
    // simply never named this one; see weekly_recap_service_test.dart, which
    // now derives the full id set from the engine instead.
    'sleep_regularity',
    'sleep_balance_low',
    'sleep_balance_up',
    'period_irregular',
  };

  /// Load everything the recap renders.
  ///
  /// Throws only when the bundle itself fails — the one failure that leaves
  /// nothing worth showing. Everything else degrades into [failedSources].
  static Future<WeeklyRecap> load({DateTime? now}) async {
    final ref = now ?? clock.now();
    final today = startOfDay(ref);
    final from = dayOffset(today, -6);

    // Deliberately NOT wrapped: a bundle failure is the one case where the
    // screen has nothing to render and the retry panel is the right answer.
    final bundleF = TrendsDataService.build(TrendRange.d7);

    // Concurrent with it, and each independently non-fatal.
    final insightsF = _insights();
    final heroF = _hero(from: from, to: today);

    final bundle = await bundleF;
    final (highlights, insightsFailed) = await insightsF;
    final (hero, heroFailed) = await heroF;

    return WeeklyRecap(
      bundle: bundle,
      hero: hero,
      highlights: highlights,
      from: from,
      to: today,
      failedSources: {
        if (insightsFailed) 'highlights',
        if (heroFailed) 'adherence',
      },
    );
  }

  static Future<(List<Insight>, bool)> _insights() async {
    try {
      final all = await InsightService.gatherAll();
      return (
        all.where((i) => weekScopedInsightIds.contains(i.id)).toList(),
        false,
      );
    } catch (e) {
      debugPrint('WeeklyRecapService insights failed: $e');
      // Empty and flagged, not silently empty. The screen shows a partial
      // banner rather than implying the week produced no highlights.
      return (const <Insight>[], true);
    }
  }

  /// The hero figure, with its denominator.
  ///
  /// Two honesty rules, both of which the previous screen broke:
  ///
  /// * A percentage needs a stated denominator. `adherencePct` alone was shown
  ///   as "86%" with nothing to check it against.
  /// * With nothing due all week the percentage has no denominator at all, so
  ///   the hero changes SUBJECT rather than rendering an em dash. A dash is what
  ///   a screen shows when it has given up.
  static Future<(RecapHero, bool)> _hero({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final thisWeek = await _adherence(from, to);
      // The previous seven days, for the delta. Failing to get it costs the
      // chip, not the hero.
      int? previousPct;
      try {
        final prevTo = dayOffset(from, -1);
        final prev = await _adherence(dayOffset(prevTo, -6), prevTo);
        previousPct = prev.pct;
      } catch (_) {
        // A missing comparison is not a failure worth reporting.
      }

      if (thisWeek.daysDue > 0 && thisWeek.pct != null) {
        return (
          RecapHero(
            kind: RecapHeroKind.adherence,
            value: thisWeek.pct,
            denominator: 'across ${thisWeek.daysDue} '
                '${thisWeek.daysDue == 1 ? 'day' : 'days'} with doses due',
            deltaPct: previousPct == null ? null : thisWeek.pct! - previousPct,
          ),
          false,
        );
      }

      // Zero days logged is measured, not unknown — but it is still a terrible
      // hero. A 32px "0" as the lead figure of a report is a scolding, and the
      // cover has words for this case that carry the same fact more kindly.
      // So: no value, and the copy takes over.
      return (
        RecapHero(
          kind: RecapHeroKind.daysLogged,
          value: thisWeek.daysLogged > 0 ? thisWeek.daysLogged : null,
          denominator: thisWeek.daysLogged > 0 ? 'of 7 days' : null,
        ),
        false,
      );
    } catch (e) {
      debugPrint('WeeklyRecapService hero failed: $e');
      // No value at all rather than a zero. "We could not work it out" and
      // "you took nothing" must never share a rendering.
      return (const RecapHero(kind: RecapHeroKind.adherence), true);
    }
  }

  /// Adherence over a day-only range, with the denominator it was computed from.
  @visibleForTesting
  static Future<({int? pct, int daysDue, int daysLogged})> adherenceFor(
          DateTime from, DateTime to) =>
      _adherence(from, to);

  static Future<({int? pct, int daysDue, int daysLogged})> _adherence(
      DateTime from, DateTime to) async {
    // The same batched range read Trends uses — one query for the window, not
    // two per day.
    final byDay =
        await MedicineCleanStorageService.getDailySummariesForRange(from, to);

    var due = 0;
    var taken = 0;
    var daysDue = 0;
    var daysLogged = 0;
    for (final s in byDay.values) {
      // `totalScheduled` is the slots already DUE, which the model's own doc
      // names as the adherence denominator — not `totalPlanned`, which counts
      // slots still ahead of the clock today and would punish the user for not
      // yet having taken tonight's dose.
      if (s.totalScheduled > 0) {
        daysDue++;
        due += s.totalScheduled;
        taken += s.taken;
      }
      if (s.taken > 0 || s.totalScheduled > 0) daysLogged++;
    }

    return (
      // Null, not zero, when there was nothing to measure.
      pct: due > 0 ? (taken / due * 100).round() : null,
      daysDue: daysDue,
      daysLogged: daysLogged,
    );
  }
}

/// The Weekly Recap's data layer, and the honesty rules it exists to hold.
///
/// The screen this replaces collapsed three different facts into one rendering.
/// Every one of its six data blocks was wrapped in `catch (_) {}`, so:
///
/// * a real database failure rendered as legitimate zeros,
/// * the retry panel could never appear, and
/// * `var regularity = 0.75` survived the swallowed exception, so a failed sleep
///   read showed a plausible regularity index that no data supported.
///
/// **null means "we don't know". Zero means "we measured zero". A thrown error
/// means "ask again."**
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart' show AppDatabase;
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/features/insights/services/weekly_recap_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  // A Wednesday, so the window straddles a week boundary and any accidental
  // calendar-week logic shows up.
  final fixedNow = DateTime(2026, 8, 26, 14, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
  });

  tearDown(() async => db.close());

  // ------------------------------------------------------------- the window

  group('one window definition', () {
    test('is seven day-only days ending today', () async {
      await withClock(Clock.fixed(fixedNow), () async {
        final r = await WeeklyRecapService.load();
        expect(r.to, DateTime(2026, 8, 26));
        expect(r.from, DateTime(2026, 8, 20));
        expect(r.to.difference(r.from).inDays, 6,
            reason: 'seven days INCLUSIVE — the off-by-one this closes is the '
                'difference between subtracting 7 and subtracting 6');
      });
    });

    test('carries no time component', () async {
      // The old gather measured from the current clock time for three sources
      // and from midnight for the other three. Two weeks, one screen.
      await withClock(Clock.fixed(fixedNow), () async {
        final r = await WeeklyRecapService.load();
        for (final d in [r.from, r.to]) {
          expect(d.hour, 0);
          expect(d.minute, 0);
          expect(d.second, 0);
        }
      });
    });

    test('the bundle covers exactly that window', () async {
      await withClock(Clock.fixed(fixedNow), () async {
        final r = await WeeklyRecapService.load();
        expect(r.bundle.adherence.points, hasLength(7));
        expect(r.bundle.adherence.points.first.date, r.from);
        expect(r.bundle.adherence.points.last.date, r.to);
      });
    });

    test('holds across a DST boundary', () async {
      // 2026-11-01 is the US fall-back. A Duration-based step over it lands on
      // the wrong calendar day; `subtract(Duration(days: 6))` on a day-only
      // DateTime is what makes this safe, and the out-of-process probe under
      // TZ=America/New_York is what proves it.
      await withClock(Clock.fixed(DateTime(2026, 11, 3, 9)), () async {
        final r = await WeeklyRecapService.load();
        expect(r.from, DateTime(2026, 10, 28));
        expect(r.to, DateTime(2026, 11, 3));
        expect(r.bundle.adherence.points, hasLength(7));
      });
    });
  });

  // --------------------------------------------------------------- the hero

  group('the hero states its denominator', () {
    test('with nothing logged at all, the value is NULL not zero', () async {
      await withClock(Clock.fixed(fixedNow), () async {
        final r = await WeeklyRecapService.load();
        // Nothing due all week -> the hero changes SUBJECT rather than showing
        // 0% or an em dash. 0% would say the user took nothing.
        expect(r.hero.kind, RecapHeroKind.daysLogged);
        // And with ZERO days logged there is no figure either: a 32px "0" as
        // the lead of a report is a scolding, so the cover's words take over.
        expect(r.hero.hasValue, isFalse);
        expect(r.hero.denominator, isNull);
      });
    });

    test('a percentage always arrives with the days it was computed from',
        () async {
      await withClock(Clock.fixed(fixedNow), () async {
        final a = await WeeklyRecapService.adherenceFor(
            DateTime(2026, 8, 20), DateTime(2026, 8, 26));
        // Null when there is no denominator — the whole point.
        expect(a.pct, isNull);
        expect(a.daysDue, 0);
      });
    });
  });

  // --------------------------------------------------- the insight window

/// Ids whose claim is about a SINGLE day, so they must never appear under the
/// recap's "your last 7 days" heading. Kept here rather than in the service
/// because the service already states the positive rule; this is the other half
/// of the classification, and the completeness test below fails if an engine id
/// belongs to neither set.
/// Multi-day signals that are NOT part of the recap's content set.
///
/// The recap's allow-list answers "may this appear under a heading that says
/// *your last 7 days*". These ids pass that test on scope — a week-over-week
/// delta and a cross-feature correlation are both multi-day — but they are not
/// recap material: the recap already carries its own hero and per-feature
/// figures, and correlations belong to the correlations surface.
///
/// Kept as a third, explicit category rather than filed under
/// [_knownTodayScoped], because calling a week-over-week comparison
/// "today-scoped" would be false, and a classification that lies is worse than
/// one that is missing. Moving an id from here into
/// `WeeklyRecapService.weekScopedInsightIds` is a product decision about what
/// the recap shows, not a bug fix.
const _notRecapContent = <String>{
  'water_trend',
  'steps_trend',
  'correlation_hydration_sleep',
  'correlation_hydration_adherence',
  'correlation_focus_sleep',
  'correlation_bp_adherence',
  'correlation_mood_adherence',
};

const _knownTodayScoped = <String>{
  'water_behind',
  'water_goal',
  'steps_goal',
  'steps_short',
  'sleep_short',
  'sleep_vs_avg',
  'sleep_good',
  'period_soon',
  'period_late',
  'period_fertile',
};

  group('only week-scoped insights are shown', () {
    // The engine is the source of truth for what ids exist. Reading them from
    // it — rather than retyping them here — is the whole point: the previous
    // version of this test hand-listed the nine ids it expected to be excluded
    // and asserted they were. `steps_short` was not among the nine, so it sat
    // in the allow-list for months while a test named "the allow-list excludes
    // every today-scoped signal" passed on every run.
    // THREE files, not one. The first version of this scanner read only
    // insight_engine.dart — but `water_trend` and `steps_trend` are string
    // literals in insight_service.dart that reach the engine as a PARAMETER
    // (`id: id`), and the five `correlation_*` ids live in
    // correlation_engine.dart. So seven emittable ids were invisible to a guard
    // whose entire stated purpose is completeness. That is the same defect this
    // test was written to fix, one level up: the rule was right and its input
    // was short.
    const idSources = <String>[
      'lib/core/health/insight_engine.dart',
      'lib/core/health/correlation_engine.dart',
      'lib/features/insights/services/insight_service.dart',
    ];

    /// Every `id: '...'` the app can emit, with the source text that carries it
    /// (bounded by the NEXT id in the same file, so a block can never absorb
    /// its neighbour's copy).
    Map<String, String> insightBlocks() {
      final out = <String, String>{};
      for (final path in idSources) {
        final src = File(path).readAsStringSync();
        final matches = RegExp(r"id: '([a-z_]+)'").allMatches(src).toList();
        for (var i = 0; i < matches.length; i++) {
          final start = matches[i].start;
          final end = i + 1 < matches.length ? matches[i + 1].start : src.length;
          out[matches[i].group(1)!] = src.substring(start, end);
        }
      }
      return out;
    }

    test('the scanner finds every source and its insights', () {
      // A source scan that reads nothing passes forever.
      for (final path in idSources) {
        expect(File(path).existsSync(), isTrue,
            reason: '$path has moved; this guard is now scanning less than it '
                'claims to');
      }
      final blocks = insightBlocks();
      expect(blocks.length, greaterThanOrEqualTo(27),
          reason: 'expected many insights across all three sources; '
              'found ${blocks.length}');
      expect(blocks.keys, contains('steps_short'));
      expect(blocks['steps_short'], contains("today's goal"));
      // One id from each of the two files the first version could not see.
      expect(blocks.keys, contains('water_trend'));
      expect(blocks.keys, contains('correlation_hydration_sleep'));
    });

    test('every emittable id is classified — a new one cannot slip through',
        () {
      final all = insightBlocks().keys.toSet();
      final unclassified =
          all.difference(WeeklyRecapService.weekScopedInsightIds)
              .difference(_knownTodayScoped)
              .difference(_notRecapContent);
      expect(unclassified, isEmpty,
          reason: 'These insight ids exist in the engine but nobody has said '
              'whether they are week-scoped. Add each to '
              'WeeklyRecapService.weekScopedInsightIds if its claim covers a '
              'multi-day window AND belongs in the recap; to _knownTodayScoped '
              'if its claim is about a single day; or to _notRecapContent if it '
              'is multi-day but not recap material:'
              '\n  ${unclassified.join('\n  ')}');

      // And nothing may be classified both ways, or in neither direction by
      // being invented here but absent from the engine.
      expect(_knownTodayScoped.difference(all), isEmpty,
          reason: '_knownTodayScoped names ids the engine no longer emits');
      expect(_notRecapContent.difference(all), isEmpty,
          reason: '_notRecapContent names ids nothing emits any more');
      expect(_notRecapContent.intersection(_knownTodayScoped), isEmpty);
      expect(
          WeeklyRecapService.weekScopedInsightIds
              .intersection(_notRecapContent),
          isEmpty,
          reason: 'an id cannot be both recap content and not');
      expect(
          WeeklyRecapService.weekScopedInsightIds.difference(all), isEmpty,
          reason: 'the allow-list names ids the engine no longer emits');
      expect(
          WeeklyRecapService.weekScopedInsightIds
              .intersection(_knownTodayScoped),
          isEmpty);
    });

    test('no allow-listed insight speaks about today', () {
      // The rule with teeth. An insight whose own copy says "today" or "last
      // night" is making a claim about a single day, and a heading that reads
      // "your last 7 days" makes it false. This is what would have caught
      // steps_short.
      final todayWords = RegExp(
          r"\b(today|today's|tonight|this morning|this afternoon|"
          r"this evening|last night|right now)\b",
          caseSensitive: false);
      final offenders = <String>[];
      insightBlocks().forEach((id, block) {
        if (!WeeklyRecapService.weekScopedInsightIds.contains(id)) return;
        // Only the user-visible copy — a comment mentioning today is fine.
        for (final field in ['detail', 'title', 'why', 'metric']) {
          final m = RegExp("$field: [\"']([^\"']*)[\"']").firstMatch(block);
          final text = m?.group(1) ?? '';
          if (todayWords.hasMatch(text)) {
            offenders.add('$id  ($field: "$text")');
          }
        }
      });
      expect(offenders, isEmpty,
          reason: 'These are allow-listed as week-scoped but their own copy '
              'describes a single day:\n  ${offenders.join('\n  ')}');
    });

    test('the multi-day signals are included', () {
      for (final id in [
        'med_adherence',
        'med_streak',
        'water_streak',
        'steps_streak',
        'sleep_regularity',
        'focus_completion',
      ]) {
        expect(WeeklyRecapService.weekScopedInsightIds, contains(id));
      }
    });

    test('it is an allow-list, so a new insight defaults to excluded', () {
      // The safe default for a page making a weekly claim: an id nobody has
      // classified does not appear.
      expect(WeeklyRecapService.weekScopedInsightIds,
          isNot(contains('some_future_insight')));
    });

    test('a real load surfaces only allow-listed ids', () async {
      await withClock(Clock.fixed(fixedNow), () async {
        final r = await WeeklyRecapService.load();
        for (final i in r.highlights) {
          expect(WeeklyRecapService.weekScopedInsightIds, contains(i.id));
        }
      });
    });
  });

  // ------------------------------------------------------------ empty week

  group('an empty week is a conclusion, not a failure', () {
    test('isEmptyWeek is true with nothing logged', () async {
      await withClock(Clock.fixed(fixedNow), () async {
        final r = await WeeklyRecapService.load();
        expect(r.isEmptyWeek, isTrue);
        expect(r.failedSources, isEmpty,
            reason: 'nothing FAILED — there is simply nothing there, and the '
                'screen must be able to tell those apart');
      });
    });
  });

  // ------------------------------------------------------ no invented score

  test('the hero can only ever be one of two real measures', () {
    // focus_readiness.dart opens with argued rationale against a composite
    // wellness score, citing App Store 1.4.1 and Play's Health Content policy.
    // A "week score: 78" is the most tempting thing a recap could add, and this
    // pins the hero to measures with a stated denominator instead.
    expect(RecapHeroKind.values,
        [RecapHeroKind.adherence, RecapHeroKind.daysLogged]);
  });

  test('a hero with no value reports hasValue false rather than zero', () {
    const h = RecapHero(kind: RecapHeroKind.adherence);
    expect(h.hasValue, isFalse);
    expect(h.value, isNull);
  });
}

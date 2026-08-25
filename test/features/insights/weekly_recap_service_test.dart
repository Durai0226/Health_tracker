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

  group('only week-scoped insights are shown', () {
    test('the allow-list excludes every today-scoped signal', () {
      // These are true sentences about TODAY. Under a heading that says "your
      // last 7 days" they are off-window claims.
      for (final id in [
        'water_behind',
        'water_goal',
        'steps_goal',
        'sleep_short',
        'sleep_vs_avg',
        'sleep_good',
        'period_soon',
        'period_late',
        'period_fertile',
      ]) {
        expect(WeeklyRecapService.weekScopedInsightIds, isNot(contains(id)),
            reason: '$id is scoped to today');
      }
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

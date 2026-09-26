@Tags(['performance'])
library;

/// The pre-`runApp` storage loads must go out together, not one after another.
///
/// `CleanStorageService.init()` awaited four whole-table loads in series, and
/// read `reminder_categories` twice on the way (once to decide whether to seed
/// the defaults, once to build the cache). `PeriodService.init()` awaited its
/// day read and its settings read in series. Both are awaited before the first
/// frame from `main()`.
///
/// Measured as a STATEMENT COUNT and a PIPELINE DEPTH, never elapsed time:
/// wall-clock on a shared machine swings far more than the thing being
/// measured, while both numbers here are the same on every machine.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tablet_remainder/core/database/app_database.dart';
import 'package:tablet_remainder/core/services/active_profile_service.dart';
import 'package:tablet_remainder/core/services/clean_storage_service.dart';
import 'package:tablet_remainder/features/period/models/flow_intensity.dart';
import 'package:tablet_remainder/features/period/models/period_day.dart';
import 'package:tablet_remainder/features/period/services/period_service.dart';

/// A [QueryExecutor] that records how many statements are IN FLIGHT at once.
///
/// `test/support/counting_executor.dart` answers "how many reads", which is the
/// wrong question for a serialisation fix: parallelising four loads issues the
/// same four statements. What changes is whether each one waits for the
/// previous one's answer, so that is what this counts.
///
/// **[ensureOpen] is cached here deliberately, and the measurement is worthless
/// without it.** Drift asks the executor to `ensureOpen` ahead of every
/// statement, and `NativeDatabase` answers that through the same lock it runs
/// statements on — so against an in-memory database every read queues behind
/// the previous one and [maxInFlight] reads 1 no matter what the app does
/// (verified: even `Future.wait` over three raw `customSelect`s measured 1
/// without this cache). The connection the app actually ships,
/// `driftDatabase(name: 'dlyminder')` → `NativeDatabase.createBackgroundConnection`,
/// has no such lock: drift's remote client caches the open in
/// `_RemoteQueryExecutor._serverIsOpen` and posts every statement straight down
/// the isolate port. Caching it here is what makes the in-memory database model
/// the connection the cold start really runs against.
class PipelineProbe extends QueryExecutor {
  PipelineProbe(this._inner);

  final QueryExecutor _inner;

  /// Every SELECT seen.
  final List<String> statements = [];

  /// Highest number of SELECTs dispatched but not yet answered.
  int maxInFlight = 0;
  int _inFlight = 0;

  /// When set, any SELECT containing this text fails instead of running.
  String? failSelectsContaining;

  void reset() {
    statements.clear();
    maxInFlight = 0;
    _inFlight = 0;
  }

  /// Reads per table, e.g. `{app_preferences: 1, reminders: 1}`.
  ///
  /// The table names are the real trap: an earlier query test in this repo
  /// matched `from "medicines"` when the Drift table is `enhanced_medicines`,
  /// so every count was zero and the test passed with the bug restored. The
  /// expectations below are written against a printed tally from a real run.
  Map<String, int> get tally {
    final out = <String, int>{};
    for (final s in statements) {
      final m = RegExp(r'FROM "(\w+)"').firstMatch(s);
      if (m != null) out[m.group(1)!] = (out[m.group(1)!] ?? 0) + 1;
    }
    return out;
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
      String statement, List<Object?> args) async {
    statements.add(statement);
    final fail = failSelectsContaining;
    if (fail != null && statement.contains(fail)) {
      throw StateError('injected read failure: $statement');
    }
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      return await _inner.runSelect(statement, args);
    } finally {
      _inFlight--;
    }
  }

  // ---- everything below just delegates --------------------------------------

  Future<bool>? _open;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) =>
      _open ??= _inner.ensureOpen(user);

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      _inner.runBatched(statements);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      _inner.runCustom(statement, args);

  @override
  Future<int> runDelete(String statement, List<Object?> args) =>
      _inner.runDelete(statement, args);

  @override
  Future<int> runInsert(String statement, List<Object?> args) =>
      _inner.runInsert(statement, args);

  @override
  Future<int> runUpdate(String statement, List<Object?> args) =>
      _inner.runUpdate(statement, args);

  @override
  QueryExecutor beginExclusive() => _inner.beginExclusive();

  @override
  TransactionExecutor beginTransaction() => _inner.beginTransaction();

  @override
  SqlDialect get dialect => _inner.dialect;

  @override
  Future<void> close() => _inner.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PipelineProbe probe;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    probe = PipelineProbe(NativeDatabase.memory());
    db = AppDatabase.forTesting(probe);
    AppDatabase.setInstanceForTesting(db);
    ActiveProfileService().resetForTesting();
    CleanStorageService.resetForTesting();
    await PeriodService.resetForTesting();
  });

  tearDown(() async => db.close());

  group('CleanStorageService.init', () {
    /// A genuinely COLD init against a database that already holds its default
    /// categories — i.e. every launch after the very first one.
    ///
    /// Both halves matter. Without the first `init()` the seeding branch runs
    /// and the steady-state cost is never measured; without
    /// `resetForTesting()` the second `init()` early-returns on
    /// `_isInitialized` and measures nothing at all.
    Future<void> coldInitOnWarmDatabase() async {
      await CleanStorageService.init();
      CleanStorageService.resetForTesting();
      probe.reset();
      await CleanStorageService.init();
    }

    test('reads each of its four tables exactly once', () async {
      await coldInitOnWarmDatabase();

      expect(
        probe.tally,
        {
          'app_preferences': 1,
          'reminder_categories': 1,
          'enhanced_medicines': 1,
          'reminders': 1,
        },
        reason: 'A cold start read `reminder_categories` twice: once to decide '
            'whether to seed the three defaults and again to build the cache. '
            'Statements: ${probe.statements}',
      );
    });

    test('issues its four reads together, not one after another', () async {
      await coldInitOnWarmDatabase();

      expect(
        probe.maxInFlight,
        4,
        reason: 'Only ${probe.maxInFlight} of the four startup reads were in '
            'flight at once, so they are still awaited in series. On the '
            'background-isolate connection the app ships, that is four '
            'sequential port round trips before the first frame.',
      );
    });

    test('still fills every cache it promised before returning', () async {
      await CleanStorageService.init();
      await db.into(db.enhancedMedicines).insert(
            EnhancedMedicinesCompanion.insert(
              id: 'med-1',
              name: 'Metformin',
              dosageForm: 0,
              startDate: DateTime(2026, 3, 1, 9),
              createdAt: DateTime(2026, 3, 1, 9),
              updatedAt: DateTime(2026, 3, 1, 9),
              scheduleJson: '{}',
            ),
          );
      await db.into(db.reminders).insert(
            RemindersCompanion.insert(
              id: 'rem-1',
              title: 'Refill prescription',
              body: 'Pharmacy closes at 6',
              scheduledTime: DateTime(2026, 3, 1, 9),
              createdAt: DateTime(2026, 3, 1, 9),
              updatedAt: DateTime(2026, 3, 1, 9),
            ),
          );
      await CleanStorageService.setAppPreference('themeModePreference', 'dark');

      CleanStorageService.resetForTesting();
      await CleanStorageService.init();

      // Parallelising must not turn "loaded" into "loading" — every one of
      // these is read synchronously from the first frame onward.
      expect(CleanStorageService.getAllMedicines().map((m) => m.id), ['med-1']);
      expect(CleanStorageService.getReminders().map((r) => r.id), ['rem-1']);
      expect(CleanStorageService.getAppPreference('themeModePreference'),
          'dark');
      expect(CleanStorageService.getAllCategories().map((c) => c.id),
          containsAll(['personal', 'work', 'health']));
    });

    test('one failing table does not abandon the other three loads', () async {
      await CleanStorageService.init();
      await db.into(db.enhancedMedicines).insert(
            EnhancedMedicinesCompanion.insert(
              id: 'med-1',
              name: 'Metformin',
              dosageForm: 0,
              startDate: DateTime(2026, 3, 1, 9),
              createdAt: DateTime(2026, 3, 1, 9),
              updatedAt: DateTime(2026, 3, 1, 9),
              scheduleJson: '{}',
            ),
          );

      CleanStorageService.resetForTesting();
      probe.failSelectsContaining = 'FROM "reminders"';
      await CleanStorageService.init();
      probe.failSelectsContaining = null;

      // Proof the injection actually landed — `FROM "reminders"` must not be
      // confused with `FROM "reminder_categories"`, and a matcher that hit
      // nothing would make everything below vacuous.
      expect(probe.statements.where((s) => s.contains('FROM "reminders"')),
          isNotEmpty);
      expect(CleanStorageService.getReminders(), isEmpty,
          reason: 'the reminder read was made to fail');

      // The surviving loads are what `Future.wait` would have dropped: it
      // rejects on the FIRST error, so an unguarded load would take the whole
      // startup cache down with it.
      expect(CleanStorageService.getAllMedicines().map((m) => m.id), ['med-1']);
      expect(CleanStorageService.getAllCategories(), isNotEmpty);

      // And the service is initialised, so the next caller does not re-run all
      // four reads. This is the observable difference: a rejected `Future.wait`
      // skips `_isInitialized = true`.
      probe.reset();
      await CleanStorageService.init();
      expect(probe.statements, isEmpty,
          reason: 'init() must be complete despite the failed table; it '
              're-read ${probe.tally} instead');
    });
  });

  group('PeriodService.init', () {
    test('issues its day and settings reads together', () async {
      await CleanStorageService.init();
      await PeriodService.init();
      await PeriodService.resetForTesting();

      probe.reset();
      await PeriodService.init();

      expect(probe.tally,
          {'period_days': 1, 'period_settings_table': 1});
      expect(
        probe.maxInFlight,
        2,
        reason: 'Only ${probe.maxInFlight} read was in flight, so the day load '
            'and the settings load are still awaited in series before the '
            'first frame.',
      );
    });

    test('loads the FULL day history, not a recent window', () async {
      await CleanStorageService.init();
      await PeriodService.init();

      // Deliberately spread across years: a 90-day or even 1-year window would
      // keep only the newest of these.
      const logged = [
        [2026, 9, 20],
        [2026, 6, 1],
        [2025, 11, 3],
        [2024, 8, 14],
      ];
      for (final d in logged) {
        await PeriodService.setFlow(
            DateTime(d[0], d[1], d[2]), FlowIntensity.medium);
      }

      await PeriodService.resetForTesting();
      await PeriodService.init();

      // The calendar pages back to any month off this map with no second
      // fetch (`PeriodCalendarScreen._shiftMonth` has no floor), and
      // `getCycles()`/`getStats()` derive every cycle from it. Windowing the
      // read at startup would silently blank older months.
      for (final d in logged) {
        final key = PeriodDay.keyFor(DateTime(d[0], d[1], d[2]));
        expect(PeriodService.days.containsKey(key), isTrue,
            reason: '$key was dropped; loaded ${PeriodService.days.keys}');
      }
    });
  });
}

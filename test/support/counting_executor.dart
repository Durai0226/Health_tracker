import 'package:drift/drift.dart';

/// A Drift [QueryExecutor] that records the SELECTs run through it.
///
/// Extracted because two test files had grown their own copy — a rich one that
/// tallied reads per table and a weaker one that only counted — roughly 60
/// duplicated lines of delegating boilerplate between them.
///
/// **The table names are the real trap.** An earlier query test matched
/// `from "medicines"`; the Drift table is `enhanced_medicines`, so it matched
/// nothing, every count was zero, and the test passed with the bug
/// deliberately restored. Always confirm a matcher against [tally] output from
/// a real run before writing a threshold.
class CountingExecutor extends QueryExecutor {
  final QueryExecutor _inner;

  /// Every SELECT seen while [recording] was true.
  final List<String> statements = [];

  /// Set false to exclude setup/teardown noise from a measurement window.
  bool recording = true;

  CountingExecutor(this._inner);

  /// Every INSERT/UPDATE/DELETE seen while [recording] was true.
  ///
  /// Writes matter as much as reads on the startup path: `setAppPreference` is
  /// one Drift write per key, each its own transaction with its own WAL fsync,
  /// and a service persisting 19 keys unconditionally in `init()` costs 19 of
  /// them before the first frame. A read-only counter cannot see that.
  final List<String> writeStatements = [];

  /// Total SELECTs recorded.
  int get selects => statements.length;

  /// Total writes recorded.
  int get writes => writeStatements.length;

  /// Writes per table.
  Map<String, int> get writeTally {
    final out = <String, int>{};
    for (final s in writeStatements) {
      final m = RegExp(r'(?:INTO|UPDATE|FROM)\s+"(\w+)"').firstMatch(s);
      if (m != null) out[m.group(1)!] = (out[m.group(1)!] ?? 0) + 1;
    }
    return out;
  }

  /// Reads per table, e.g. `{enhanced_medicines: 4, medicine_logs: 3}`.
  Map<String, int> get tally {
    final out = <String, int>{};
    for (final s in statements) {
      final m = RegExp(r'FROM "(\w+)"').firstMatch(s);
      if (m != null) out[m.group(1)!] = (out[m.group(1)!] ?? 0) + 1;
    }
    return out;
  }

  /// Tables read more than once — the duplicate-fetch signal.
  Map<String, int> get duplicates =>
      Map.fromEntries(tally.entries.where((e) => e.value > 1));

  void reset() {
    statements.clear();
    writeStatements.clear();
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
      String statement, List<Object?> args) {
    if (recording) statements.add(statement);
    return _inner.runSelect(statement, args);
  }

  // ---- everything below just delegates -------------------------------------

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _inner.ensureOpen(user);

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      _inner.runBatched(statements);

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      _inner.runCustom(statement, args);

  @override
  Future<int> runDelete(String statement, List<Object?> args) {
    if (recording) writeStatements.add(statement);
    return _inner.runDelete(statement, args);
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    if (recording) writeStatements.add(statement);
    return _inner.runInsert(statement, args);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) {
    if (recording) writeStatements.add(statement);
    return _inner.runUpdate(statement, args);
  }

  @override
  QueryExecutor beginExclusive() => _inner.beginExclusive();

  /// Wrapped, NOT delegated.
  ///
  /// Drift routes every statement inside `transaction(() {...})` through the
  /// executor this returns — so plain delegation made all transactional work
  /// INVISIBLE to the counters. A test asserting "this path issues at most N
  /// writes" would pass no matter what, as long as the writes were batched into
  /// a transaction, which is exactly the code a perf test is written to check.
  @override
  TransactionExecutor beginTransaction() =>
      _CountingTransaction(_inner.beginTransaction(), this);

  @override
  SqlDialect get dialect => _inner.dialect;

  @override
  Future<void> close() => _inner.close();
}

/// Records into its parent [CountingExecutor], so statements issued inside a
/// transaction land in the same tally as statements issued outside one.
class _CountingTransaction extends TransactionExecutor {
  _CountingTransaction(this._inner, this._parent);

  final TransactionExecutor _inner;
  final CountingExecutor _parent;

  @override
  Future<List<Map<String, Object?>>> runSelect(
      String statement, List<Object?> args) {
    if (_parent.recording) _parent.statements.add(statement);
    return _inner.runSelect(statement, args);
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    if (_parent.recording) _parent.writeStatements.add(statement);
    return _inner.runInsert(statement, args);
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) {
    if (_parent.recording) _parent.writeStatements.add(statement);
    return _inner.runUpdate(statement, args);
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) {
    if (_parent.recording) _parent.writeStatements.add(statement);
    return _inner.runDelete(statement, args);
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) =>
      _inner.runCustom(statement, args);

  @override
  Future<void> runBatched(BatchedStatements statements) =>
      _inner.runBatched(statements);

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) => _inner.ensureOpen(user);

  @override
  Future<void> send() => _inner.send();

  @override
  Future<void> rollback() => _inner.rollback();

  @override
  SqlDialect get dialect => _inner.dialect;

  @override
  QueryExecutor beginExclusive() => _inner.beginExclusive();

  @override
  TransactionExecutor beginTransaction() =>
      _CountingTransaction(_inner.beginTransaction(), _parent);

  @override
  bool get supportsNestedTransactions => _inner.supportsNestedTransactions;
}

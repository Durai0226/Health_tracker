import 'package:health/health.dart';

import '../../../core/services/health_data_service.dart';
import '../../../core/services/health_store_name.dart';

/// Where past periods are read from: the phone's health store.
///
/// A seam so the flow that asks, reads and writes can be driven without the
/// platform plugin, which headless tests cannot reach.
abstract class CycleImportSource {
  /// "Health Connect" or "Apple Health".
  String get storeName;

  /// Whether menstrual flow may already be read.
  Future<bool> allowed();

  /// Ask to read it. True only when the platform confirms the grant.
  Future<bool> ask();

  /// Whether more than the last month can be read (Health Connect limits an app
  /// to 30 days before its first grant unless history is allowed too). Asks once
  /// where the platform has that grant to ask.
  Future<bool> fullHistory();

  /// The flow samples in [from]..[to]; null when the read itself failed.
  Future<List<HealthDataPoint>?> read(DateTime from, DateTime to);
}

/// The real source: [HealthDataService] on the running platform.
class HealthStoreCycleSource implements CycleImportSource {
  const HealthStoreCycleSource();

  HealthDataService get _service => HealthDataService.instance;

  @override
  String get storeName => healthStoreName();

  @override
  Future<bool> allowed() => _service.hasCyclePermission();

  @override
  Future<bool> ask() => _service.requestCyclePermission();

  @override
  Future<bool> fullHistory() => _service.ensureCycleHistoryAccess();

  @override
  Future<List<HealthDataPoint>?> read(DateTime from, DateTime to) =>
      _service.readCycleFlow(from, to);
}

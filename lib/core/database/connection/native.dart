import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Opens a database connection for native platforms (iOS, Android, macOS, Windows, Linux).
QueryExecutor openConnection() {
  return driftDatabase(name: 'dlyminder');
}

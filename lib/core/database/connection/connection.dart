import 'package:drift/drift.dart';

// Conditional import for platform-specific implementations
import 'native.dart' if (dart.library.html) 'web.dart' as impl;

/// Creates a database connection for the current platform.
/// On native platforms (iOS, Android, macOS, Windows, Linux), uses NativeDatabase.
/// On web, uses WebDatabase with sql.js.
QueryExecutor openConnection() {
  return impl.openConnection();
}

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Opens a database connection for web platform using sql.js (WebAssembly).
QueryExecutor openConnection() {
  return driftDatabase(
    name: 'dlyminder',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
      onResult: (result) {
        if (result.missingFeatures.isNotEmpty) {
          print('Using ${result.chosenImplementation} due to unsupported '
              'browser features: ${result.missingFeatures}');
        }
      },
    ),
  );
}

// Driver for `flutter drive`, which is the only path that runs an
// integration_test in --profile AND writes reportData to disk.
//
// `flutter test integration_test/...` does not accept --profile, and it
// discards binding.reportData — so watchPerformance results reach neither a
// real frame budget nor a file. Three lines here fix both.
//
// Output lands at build/integration_response_data.json.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();

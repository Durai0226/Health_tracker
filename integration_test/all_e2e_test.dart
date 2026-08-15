import 'a01_shell_nav_e2e_test.dart' as a01;
import 'a02_today_e2e_test.dart' as a02;
import 'a03_headers_e2e_test.dart' as a03;
import 'c06_diary_e2e_test.dart' as c06;
import 'z01_perf_e2e_test.dart' as z01;

/// One entrypoint for the whole device pass.
///
/// `flutter test integration_test/` starts the app ONCE PER FILE — each file
/// triggers its own gradle assemble and install, which on this project costs
/// minutes. Importing the suites into a single `main()` pays that cost once.
///
/// Ordering is by filename prefix and is deliberate: `a*` shell and IA, `b*`
/// medication, `c*` trackers, `d*` reminders, `e*` focus, `f*` insights,
/// `g*` destructive (own hermetic database), `z*` measurement last.
///
/// Two caveats, both learned the hard way:
///
///  * Every suite here shares ONE app container and one isolate. `AppDatabase`
///    is a singleton and `CleanStorageService` caches preferences in memory, so
///    suite N sees whatever suite N-1 wrote. Every suite must therefore namespace
///    the rows it creates and clean up after itself — which the CRUD round-trips
///    do by construction, since they end by deleting what they made.
///  * Suites that mutate shared state destructively (backup/restore, delete-all,
///    app lock) are NOT listed here. They run standalone against a hermetic
///    in-memory database, because a fresh container is the only way their
///    assertion counts are stable.
void main() {
  a01.main();
  a02.main();
  a03.main();
  c06.main();
  z01.main();
}

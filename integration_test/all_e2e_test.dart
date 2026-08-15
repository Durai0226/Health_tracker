import 'a01_shell_nav_e2e_test.dart' as a01;
import 'a03_headers_e2e_test.dart' as a03;
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
/// Suites that MUTATE shared state and need a fresh container are run
/// standalone instead, not from here — see the run recipe in the plan.
void main() {
  a01.main();
  a03.main();
  z01.main();
}

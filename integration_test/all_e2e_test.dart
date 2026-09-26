import 'a01_shell_nav_e2e_test.dart' as a01;
import 'a02_today_e2e_test.dart' as a02;
import 'a03_headers_e2e_test.dart' as a03;
import 'b01_add_medication_e2e_test.dart' as b01;
import 'b02_dose_e2e_test.dart' as b02;
import 'c01_water_e2e_test.dart' as c01;
import 'c05_vitals_e2e_test.dart' as c05;
import 'c06_diary_e2e_test.dart' as c06;
import 'd02_smart_add_e2e_test.dart' as d02;
import 'e01_focus_e2e_test.dart' as e01;
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
///  * A suite that mutated shared state destructively (backup/restore,
///    delete-all, app lock) would have to run standalone against a hermetic
///    in-memory database, because a fresh container is the only way its
///    assertion counts would be stable. No such suite exists today: every file
///    in `integration_test/` is registered below, and
///    `test/e2e_hygiene/all_suites_registered_test.dart` fails if one is added
///    and not registered here.
void main() {
  a01.main();
  a02.main();
  a03.main();
  // `b*` is medication. b01 and b02 were exempted from the registration guard
  // as "destructive", but neither is: b01 deletes every medicine it creates,
  // and b02's whole subject is Undo, which restores the stock and the log it
  // just wrote. Both end on `E2E.assertClean`, so the exemption was hiding two
  // suites — one of them the drug-interaction safety dialog — from every run.
  b01.main();
  b02.main();
  // `c*` is trackers. Same omission as e01 below: the water device suite
  // existed and was never imported, so the pass ran every suite except the
  // largest feature in the app.
  c01.main();
  // c05 creates one 185/120 crisis reading and deletes it again as the second
  // half of its own assertion — the card must go when the reading does — so it
  // leaves the vitals table exactly as it found it.
  c05.main();
  c06.main();
  // `d*` is reminders. d02 drives Smart Add as far as the prefilled FORM and
  // never taps Save, so it writes no reminder at all.
  d02.main();
  // `e*` is focus. The file existed and was never imported here, so the device
  // pass ran every suite EXCEPT the feature it was written for — and running it
  // standalone would pay the whole assemble-and-install cost again for one file.
  e01.main();
  z01.main();
}

# Deep E2E pass — findings

Defects found by driving the app on a real Android emulator (Pixel-class,
1080×1920 @ 420dpi) against seeded data. Every entry names its evidence, and
every fix is mutation-checked where a test can express it.

Severity follows `docs/ui-audit.md` and `test/support/perf_rating.dart`:
**P0 broken · P1 clearly poor · P2 polish** (−40 / −15 / −5 from 100).

---

## The finding that explains the other findings

**No integration test in this repo could fail.** `lib/main.dart` overwrote
`FlutterError.onError` with a logger at the top of `main()`:

```dart
FlutterError.onError = (FlutterErrorDetails details) {
  debugPrint('Flutter Error: ${details.exception}');
  // Don't crash the app, just log the error
};
```

Every suite calls `app.main()` as its first statement, and the test binding's
reporter — the thing that turns a framework error into a **failing test** — is
`FlutterError.onError`. From that line onwards, for the rest of the test, every
`RenderFlex overflowed`, every `setState() after dispose()`, and every exception
thrown inside a builder was printed to the log and discarded. `runZonedGuarded`
did the same for escaping async errors.

That is why five suites could walk a visibly broken app and report green, and
why P1 below had been shipping unnoticed: Flutter was reporting it, loudly, on
every single sheet, and the app was throwing the report away.

Both handlers now delegate when `kE2ETest` is set. Production is unaffected —
the flag is a compile-time `false` there.

---

## P0 · Every brand-new user landed on a blank screen

**Where:** `lib/features/home/screens/app_shell.dart`, with
`lib/features/onboarding/screens/welcome_screen.dart:136`.

Onboarding deliberately finishes onto the Meds tab, so its empty state can guide
a new user to "Add your first medicine":

```dart
pageBuilder: (_, __, ___) => const AppShell(initialIndex: 1),
```

`AppShell` sets `_slot = widget.initialIndex`, so `_stackIndex` is 1. But the
lazy-mount set was a constant:

```dart
final Set<int> _mounted = {0};
```

and the `IndexedStack` renders `const SizedBox.shrink()` for any index not in
that set. Selected child 1, child 1 not mounted, **blank body**.

The lazy first-mount optimisation and the non-zero initial tab were each correct
in isolation and silently cancelled each other out. The comment above the call
site describes the intended behaviour, which made the bug invisible in review.

**Fix:** seed `_mounted` from `initialIndex`, plus asserts rejecting slot 2 (the
Log action is not a destination). Lazy mount is preserved — landing on Today
still does not build the Meds dashboard, which matters because that dashboard
also *writes* (it drains queued dose actions and reconciles missed doses).

**Mutation-checked:** restoring `_mounted = {0}` fails
`test/features/home/app_shell_initial_tab_test.dart` with
`Found 0 widgets with type "NunitoMedicationDashboard"`.

---

## P1 · Every tappable row in every bottom sheet had invisible tap feedback

**Where:** `lib/core/widgets/app/app_bottom_sheet.dart`.

The sheet painted an opaque `Container` with no `Material` inside it:

```dart
Container(
  decoration: BoxDecoration(color: ext.surfaceElevated, borderRadius: ...),
  child: SafeArea(...),
)
```

`ListTile` and `InkWell` paint their splash on the **nearest `Material`
ancestor**, which here is behind the sheet's own opaque background. So the ink
was drawn underneath the sheet, where nobody can see it. Flutter says so
explicitly, once per affected row:

> ListTile background color or ink splashes may be invisible. The ListTile is
> wrapped in a DecoratedBox that has a background color … this DecoratedBox will
> hide those effects.

Affected every sheet in the app, including Customize Today
(`home_dashboard.dart:600`), the water quick actions
(`water_quick_actions.dart:693`) and the take-medication sheet
(`nunito_take_medication_sheet.dart:284`).

**Fix:** a `Material(type: MaterialType.transparency)` inside the decoration, so
ink paints on top of it while the container keeps its colour and radius.

**Why it survived so long:** it was never silent — it was *swallowed*. See the
first section.

---

## P1 · Sleep and Period were dead ends when pushed

**Where:** `lib/features/sleep/screens/sleep_dashboard_screen.dart`,
`lib/features/period/screens/period_dashboard.dart`.

The Health hub and the Log sheet PUSH every tracker. Water and Steps both gate a
back button on `Navigator.canPop()`. Sleep had three header `actions` and no
`leading`; Period's header carried only a notifications action. So on both, the
on-screen chrome offered no way out — the user's only exit was the platform
back gesture, which a custom header cannot rely on.

Sleep was worse than it looks: its LOADING state header had no back button
either, so the way out would have appeared only once data arrived — absent
exactly when a slow load makes leaving most likely.

**Why nothing caught it:** no harness had ever *pushed* these screens. The
responsive sweep and the build-cost harness mount each screen as a route ROOT,
where `Navigator.canPop()` is false and a back button is correctly absent. The
one configuration that matters was the one never tested.

**Fix + gate:** back affordance on both, matching the Water/Steps pattern, and
`test/features/pushed_screens_have_back_test.dart` now pushes all five trackers
through a real `Navigator`. Mutation-checked: removing Sleep's `leading` fails
it with "Sleep has no back affordance when pushed". Writing that test
immediately found Period, which had the identical defect.

---

## P1 · The seeder raced itself

**Where:** `lib/core/dev/qa_seed.dart`.

`seedQaData` was guarded by a persisted preference written **after** the seed
completes. Integration tests call `app.main()` once per *test*, in the same
isolate against the same database, so when one test timed out mid-seed the next
launch started a second, concurrent seed. The two raced into:

```
seed medicines failed: SqliteException(1555):
  UNIQUE constraint failed: enhanced_medicines.id
```

because `MedicationDao.addMedicine` is a plain `insert`, not an upsert.

**Fix:** an in-flight future so a second caller awaits the first instead of
racing it. The persisted guard still handles relaunches; it just cannot handle
concurrency, because it is only written at the end.

---

## P2 · The seeder left two of the four Today pillars empty

**Where:** `lib/core/dev/qa_seed.dart`.

It planted steps, sleep, medicines, water, vitals, period and diary — but **no
reminders and no focus sessions**. Those are two of the four Today pulse-row
pillars, so every reminders screen, the Focus stats and the Today row itself
were only ever measured, rated and screenshotted in their *empty* state while
the other five features had a month of history behind them.

**Fix:** `_seedReminders` (four, including one deliberately overdue — the state
with the most UI) and `_seedFocus` (60 days with a gap every fifth day, so the
streak logic's "at risk" and grace-day branches are actually exercised).

Also: the guard key was the bare string `qa_seeded`, which is **the same key
`main_qa.dart` writes** for its own three-table seed. Same bundle id means the
same data container, so whichever ran first blocked the other and a measurement
could silently be taken against nine days of steps and nothing else. Now
`qa_seed_v2`.

---

## Not a defect, but it invalidated the first three runs

The AVD's display was **320 × 640 at density 160** — the emulator's fallback
skin, not a device any user owns. At that size roughly one Health tracker tile
sits above the fold, so tests failed for reasons that said nothing about the
app.

Pinned to Pixel-class before any result was trusted:

```bash
adb -s emulator-5554 shell wm size 1080x2400
adb -s emulator-5554 shell wm density 420
```

Check `adb shell wm size` before believing any UI result. Rendered line counts,
what is above the fold, and every overflow are functions of this.

---

## Verified sound (worth recording, because the test first said otherwise)

**The dose stock invariant holds.** Taking a dose decrements that medicine's
stock and no other's, writes exactly one log, and Undo restores both. The
invariant the app's own comment names — *"Reverse the stock decrement first, or
Undo silently loses inventory"* — is correctly implemented.

An earlier version of `b02_dose_e2e_test.dart` reported it broken (`40 before,
40 after`). That was the TEST, not the app: it snapshotted `meds.first` while
tapping whichever dose happened to scroll into view, so it was asserting against
a different medicine. Which dose is actionable depends on the time of day and on
which slots have already reconciled to Missed, so pinning one in advance is
never safe here.

The suite now snapshots every medicine's stock, reads back the log that was
actually written, and asserts against *that* log's medicine — plus that no other
medicine moved. Under-specified assertions do not just miss defects; they invent
them, and an invented defect costs more than a missed one because someone goes
looking for it in working code.

---

## Test-side lessons worth keeping

Three of the first failures were my assertions, not the app. They are recorded
because each is a trap the next person will hit:

1. **Assert location by screen TYPE, not by a heading.** `'Your trackers'`
   scrolls out of the viewport's cache extent and leaves the tree, so asserting
   it to prove "I am on the Health hub" fails as soon as anything scrolled.
2. **`KpiCell` uppercases its label**, so Today's pulse row renders `MEDS`, not
   `Meds`. The registry keeps the source casing (it greps `lib/`); the test
   applies `.toUpperCase()`.
3. **This app has no `SwitchListTile`** — it is `ListTile` + `AppSwitch`.

4. **Neither of Flutter's scroll helpers fits this app.** `scrollUntilVisible`
   rejects a finder matching many widgets (`dragUntilVisible` calls
   `controller.element`, which demands exactly one), and passing `.first` to
   make it unique throws `Bad state: No element` from `evaluate()` on every
   step before the target scrolls in. Several doses show a Take button and none
   are built until you scroll, so both failure modes hit at once.
   `E2E.scrollUntilPresent` handles it.
5. **`find.textContaining('Take')` matches `'Taken'`** — a stat tile at the top
   of the Meds screen. The scroll stopped instantly and the tap landed on a
   statistic. Prefix matching on short verbs is a trap; match exactly.

And one harness bug worth naming: a `FlutterError.onError` collector must
**forward** to the handler it replaced. One that merely records leaves the
binding's `_pendingExceptionDetails` null, and the first escaping async error
then surfaces as *"a test overrode FlutterError.onError …"*, burying the real
failure underneath it.

# Device E2E harness

How the app is driven on a real device, and why each piece exists. Every rule
here was written because a suite in this repo broke it and reported green.

## Run it

```bash
# one build, all suites
~/flutter/bin/flutter test integration_test/all_e2e_test.dart \
  -d emulator-5554 \
  --dart-define=E2E_TEST=true \
  --dart-define=SKIP_NOTIF_INIT=true \
  --dart-define=E2E_SEED=true \
  -r expanded
```

`~/flutter/bin/flutter` explicitly — a bare `flutter` resolves to a **different
SDK** at `/opt/homebrew/share/flutter/bin`.

Frame timings need the driver, because `flutter test` rejects `--profile` and
throws `binding.reportData` away:

```bash
~/flutter/bin/flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/z01_perf_e2e_test.dart \
  -d emulator-5554 --profile \
  --dart-define=E2E_TEST=true --dart-define=E2E_SEED=true
```

### Device pinning — not optional

Rendered line counts, what sits below the fold, and every overflow depend on the
device. Pin one and keep it:

```bash
adb -s emulator-5554 shell wm size 1080x2400   # Pixel-class
adb -s emulator-5554 shell wm density 420      # -> ~411 logical width
adb -s emulator-5554 shell settings put global window_animation_scale 1.0
```

The AVD's fallback skin is **320x640 at density 160**, which is not a phone any
user has — and at that size only about one Health tracker tile is above the
fold, so tests fail for reasons that say nothing about the app. Check with
`adb shell wm size` before trusting a run. Do NOT set animation scale to 0:
these suites measure animation.

## Why `pumpAndSettle` is banned

The app runs continuous animations — the nav orb, loading skeletons, ad views —
so `pumpAndSettle` never returns, it TIMES OUT. `integration_test` sets
`defaultTestTimeout = Timeout.none`, so `--timeout` cannot shorten it and each
call burns **ten real minutes**. One deleted suite had 24 of them. Use
`settle(t)`, which pumps a fixed number of frames.

**Always run a device suite under a watchdog.** There is no `timeout(1)` on this
machine.

## The three silencers, and what replaced them

| Was | Why it could not fail | Now |
|---|---|---|
| `app.main()` first | It overwrote `FlutterError.onError`, destroying the binding's reporter. Every overflow, `setState() after dispose()` and builder exception was printed and discarded for the rest of the test. | `main.dart` hands errors back when `kE2ETest` is set; `E2E.launch` collects **and forwards** them |
| `if (finder.evaluate().isNotEmpty) expect(...)` | An assertion that only runs when it would pass. | `E2E.at(marker, where:)` |
| `reachHome()` returning silently after 24 rounds | The real failure surfaced 40 lines later as "'Today' not found", pointing at the nav bar. | `E2E.launch` throws with the visible text and the likely cause |

`test/e2e_hygiene/` enforces all three mechanically, headless, in under a
second — plus: no `Icons.*` (the app draws `Symbols.*`, so `find.byIcon(Icons.x)`
is a permanent zero-match — `IconData ==` compares `fontFamily`), no `app.main()`
outside `support/`, no `testWidgets` without an assertion, no bare
`markTestSkipped`.

## `E2E.tapWhenHittable` vs `tap`

`tap` reports a miss as a *warning* and carries on, so the test fails later and
somewhere else. `tapWhenHittable` scrolls the target into view, polls while a
route transition is in flight, and on real occlusion fails with the geometry:
target rect, screen size, nav-bar top, and what received the tap instead. That
distinguishes the three causes — below the fold, behind the docked nav, covered
by an overlay — without a second run.

## Seeding

`--dart-define=E2E_SEED=true` runs `seedQaData()` after every service init and
before `runApp` (`main.dart`). Deterministic — no `Random` — so two runs give
identical numbers.

Guarded by `qa_seed_v2`, deliberately NOT the `qa_seeded` key `main_qa.dart`
owns: same bundle id means the same data container, so a shared key let whichever
ran first block the other, and a measurement could silently be taken against nine
days of steps and nothing else.

## Adding a suite

1. Prefix the filename by phase: `a*` shell/IA, `b*` medication, `c*` trackers,
   `d*` reminders, `e*` focus, `f*` insights, `g*` destructive, `z*` measurement.
2. Start with `await E2E.launch(t)`, end with `E2E.assertClean('<journey>')`.
3. Put every asserted string in `integration_test/support/app_strings.dart` with
   its `file:line`. The registry test greps `lib/` for all of them, which is what
   would have caught `'Save Reminder'`, `'Medicine Tracker'` and `'AI Assistant'`
   the day each was deleted.
4. Prefer a CRUD round-trip — create → appears → edit → survives a nav-away →
   delete → gone — over a presence check. Presence checks are what let four
   suites rot.
5. Register it in `all_e2e_test.dart`, unless it mutates shared state
   destructively; those run standalone against a hermetic database.

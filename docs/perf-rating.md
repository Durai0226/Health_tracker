# Tap effects, the tab-switch glitch, and per-feature performance ratings

## 1. The reported glitch

> "when switch the tab remove the ripple effect or any effect added remove
> that's the glitch reason"

**The bottom nav has no ripple.** Each destination is a bare `GestureDetector`
(`app_nav_bar.dart:190`) — no `InkWell`, no `Material`, so no ink can render.
The bottom nav was explicitly reported as working well; the complaint was about
the other switchers, and a real ripple did exist there.

Ripple was enabled **globally**, in the theme (`app_theme.dart`, `splashColor` /
`highlightColor` on the brand colour), which is why all 17 `InkWell` sites
rippled — including the Health hub tracker cards and the app's only `TabBar`.

### What was actually removed

| Surface | Before | After |
|---|---|---|
| All 17 `InkWell` sites, `TabBar`, M3 buttons, `IconButton`, `ListTile` | brand ripple + pressed wash | nothing |
| `SegmentedToggle` (12+ screens) | 260ms lerp of fill **and** `AppShadows.resting` — one blurred shadow animating out while another animated in, every switch | selection completes on the tap frame |
| `CommonTabBar` etc. | Material ripple | nothing (and 7 of 10 classes deleted, 622 → 128 lines) |
| Timeline ⇄ Pillbox | already unanimated | unchanged — nothing to remove |

### A regression introduced and caught

The first version set `overlayColor` to a flat transparent on the button and tab
themes. That **also removes the keyboard focus ring**, because `InkResponse`
resolves `overlayColor(focused)` *before* falling back to `focusColor`:

```
overlayColor?.resolve(focused) ?? focusColor ?? theme.focusColor
```

A flat transparent short-circuits the whole chain — **WCAG 2.4.7 Focus Visible**.
Stripping tap feedback is a design choice; stripping the focus indicator is a
conformance failure. It is now a resolver: dead on press and hover, alive on
focus, and `tap_effect_test.dart` mutation-verifies exactly that trap.

## 2. What the evidence says the glitch actually was

Ripples and small shadows are cheap. Two much larger things happened on switch:

**The Trends dashboard blanked itself on every range tap.** `_setRange` assigned
a fresh `Future` and the `FutureBuilder` fell straight to `_loading` — four solid
grey blocks — tearing down and re-animating every chart card. It now keeps the
last good bundle on screen while the new range loads. The regression test
measures it directly: **16 strings before the tap, 4 after** when the fix is
reverted.

**An ad banner inserted ~84pt of content during navigation.**
`SmartDashboardBanner` read `SimpleAdService.bannerLoaded` with **no listener**,
so it stayed a zero-height box until an unrelated rebuild ran — and on this app
that is a tab switch. It now listens to a `bannerReady` notifier, so the
insertion happens when the ad loads rather than under the user's thumb.

## 3. Per-feature rating

`test/support/perf_rating.dart`. Deduction from 100, using the severity
vocabulary already in `docs/ui-audit.md`:

```
P0 = −40    P1 = −15    P2 = −5
A 90-100 · B 75-89 · C 60-74 · D 40-59 · F 0-39
```

The arithmetic encodes the rule instead of special-casing it: one P0 is −40, so
it caps a feature at exactly **C** however clean everything else is. A weighted
average of milliseconds, widget counts and read counts would let a P0 be diluted
away — precisely wrong for "broken".

### Dimensions

Headless (runs today, no device):

| Dimension | Instrument | Source of the threshold |
|---|---|---|
| Build error | `screen_build_cost_test` | binary: it threw |
| Never settles | frames-to-settle | binary: perpetual animation costs battery unobserved |
| Element budget | measured baseline + 15% | this repo's own measurement |
| Tree size vs run median | within-run ratio | machine-independent by construction |
| Duplicate table reads | `CountingExecutor.tally` | this repo's own measurement |
| Overflow / text wrap | 564-combination sweep | WCAG 2.2 SC 1.4.4 |
| Touch targets | rendered size | WCAG 2.2 SC 2.5.8 |

Device-only: build p90, **raster p90**, worst frame, jank rate — against the
16.7ms (60Hz) / 8.3ms (120Hz) budget.

### The honesty rule

With no device the frame-timing dimensions are unmeasured, and device
dimensions can only ever *add* deductions. So a headless-only score is a strict
**upper bound** and prints as `≤ B`, never `B`. Host wall-clock is never
substituted for device raster time — the build-cost harness disclaims that it
can represent it, and it is right to.

Current headless output:

```
feature        score  grade   findings
Focus             85    ≤ B   1xP1
  [P1] Focus/timer · tree-size
        2321 elements vs run median 580 (4.0x)
```

### Why timing is not in the formula

`firstFrameMicros` is debug-mode wall clock on a shared host; the harness itself
recorded an ~8× swing between two runs of an identical screen. Every headless
dimension is a **count**, a **boolean**, or a **within-run ratio** — all
invariant across machines. A threshold that passes on one laptop and fails in CI
is worthless.

## 4. Instrumentation changes

- `test/performance/screen_build_cost_test.dart` had **zero `expect()` calls** —
  the last report-generator-wearing-a-test's-clothes in the repo, the same
  defect that let a broken header ship past "564 combinations, NO OVERFLOWS".
  Now gated on build errors, perpetual animations, and element budgets. Both
  gates mutation-verified (`Focus/timer 2321 elements > budget 100`,
  `Home/home has NO budget entry`).
- `CountingExecutor` extracted to `test/support/` — it had grown two divergent
  copies, ~120 duplicated lines.
- `integration_test/support/e2e_helpers.dart` — `settle()` / `reachHome()` were
  byte-identical in two suites; a third copy was one too many.

## 5. Running the device half

```bash
flutter test integration_test/perf_e2e_test.dart \
  -d <android-device-id> --profile \
  --dart-define=E2E_TEST=true
```

Three parts are not optional:

- **A physical Android device.** An iOS simulator has no real GPU pipeline, so
  its raster numbers are fiction.
- **`--profile`.** Debug is 2-10× pessimistic and is not a frame budget.
- **`--dart-define=E2E_TEST=true`.** Skips onboarding (`main.dart:321`) and
  notification/ad init (`:106`), keeping that work out of the measured windows.

`binding.reportData` is populated under plain `flutter test` and then discarded
— only the `flutter drive` path persists it — which is why every scenario also
prints its numbers.

## 6. Dead code removed

- `common_tab_widgets.dart`: 7 of 10 classes had zero callers → 622 → 128 lines.
- `integration_test/notes_e2e_test.dart` (513 lines) — targeted a "Notes"
  feature that does not exist in `lib/features/`.
- `integration_test/category_selection_e2e_test.dart` (336 lines) — never called
  `app.main()`; 37 assertions against an empty widget tree.
- `integration_test/premium_integration_test.dart` — `expect(true, isTrue)`. A
  test that cannot fail is worse than no test: it inflates the passing count
  that the gate table reports.
- `redesign_e2e_test.dart` asserted `'Insights'`; the shell renders `'Trends'`
  (`app_shell.dart:212`). Fixed, not deleted.

## 7. Open — needs a decision

- **`AppCard` press effect.** `app_card.dart` runs a 180ms `AnimatedScale(0.98)`
  on every card press. It is the last press affordance on cards, and it is used
  by the Health hub's Trends card. `pressEffect` already exists as a parameter,
  so flipping its default is a one-character change — but it removes the only
  visual response those cards give.
- **Double haptic on Focus mode switch.** `focus_screen.dart` fires
  `_hapticService.selection()` and `SegmentedToggle` fires
  `HapticFeedback.selectionClick()` — two buzzes per switch. One-line deletion,
  and a genuine "feels glitchy" generator.
- **Haptics are not an accessible substitute** for visual feedback: absent on
  web/desktop, unreliable on low-end Android, and this app ships a user-facing
  off switch. With haptics off, the retained feedback is the instant state
  change plus the focus ring — which is why the focus ring had to survive.

## 8. Still not done

- **`AppShell` mounts all four dashboards** into an `IndexedStack` on cold
  start, and is measured by neither harness. Likely the largest startup cost in
  the app. Lazy first-mount would keep the per-tab `ScrollController` design
  intact while deferring three dashboards.
- **`FocusScreen`, 2321 elements** — 4× the run median, built eagerly by
  `SingleChildScrollView` + `Column` over 13 sections. Converting to a lazy list
  needs `Center` around each child to preserve `Column`'s centring contract, and
  should be verified on a device.
- **`weekly_recap` and `adherence` duplicate table reads** — measured, unfixed.
- **The seeder still only covers steps and sleep.** Ratings on an empty database
  understate every screen; medicines, water, period and vitals are missing.

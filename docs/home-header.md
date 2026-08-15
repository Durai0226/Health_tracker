# The Home header: what broke, why the tests missed it, what changed

A user screenshotted the Home screen on an Android phone. The header showed
`Good evening · Wednesday, Aug 12` wrapped across **three lines**, the title
read `User`, the streak pill and settings button were crushed against the right
edge, and the AI briefing was cut mid-sentence at *"…a glass no…"*.

## 1. Why the layout collapsed

`AppHeader.buildRow` was a single `Row` with exactly **one** flex child:

| slot | flexible? | width at 360pt |
|---|---|---|
| `leading` — the "Me" profile chip | no, intrinsic | ~73 + 8 |
| `Expanded(Column[greeting, title])` | **yes — the only one** | **~114, whatever is left** |
| streak `AppChip` | no, intrinsic | ~65 + 8 |
| settings `AppIconButton` | no, intrinsic | 44 + 8 |

`Good evening · Wednesday, Aug 12` needs ~215pt. It got ~114pt. And the greeting
`Text` had **no `maxLines` and no `overflow`**, so it simply wrapped.

The inverted hierarchy followed arithmetically: three lines of 20px greeting is
60px tall, against a 26px title — **the least useful element on screen rendered
twice the size of the most useful one.**

Two further defects in the same widget:

- The badge-drop heuristic reserved `actions.length * 52.0`. It protected the
  title but never the greeting, under-measured real chips (73 and 65, not 52),
  and counted the streak action even when it rendered `SizedBox.shrink()`. Home
  passed no `icon:`, so the escape valve could not fire there at all.
- `leading` sat in the `Row` as a non-flex child, so it received **unbounded**
  constraints and `AppChip`'s own `Flexible` + ellipsis never engaged. A
  dependent named "Grandmother Elizabeth" would grow without limit — a latent
  real overflow, not a cosmetic one.

## 2. Why 564 automated combinations reported green

Two separate reasons, and the second is the serious one.

**A soft wrap is not an overflow.** Flutter throws nothing when an unclamped
`Text` wraps to three lines — it is a legal layout. The harness matched
`RenderFlex`/`RenderBox` overflow exceptions, so it was structurally blind to
this entire bug class.

**The harness could not fail at all.** `responsive_overflow_test.dart` and
`touch_target_audit_test.dart` accumulated results into maps and `print()`ed
them in `tearDownAll`. Between them they contained **zero `expect()` calls**.
They reported green on a genuine `RenderFlex overflowed by 44 pixels` exactly as
happily as on a clean run. "564 combinations, NO OVERFLOWS" was a true count
attached to a meaningless pass.

Both files now gate on `overflows`, `wraps` and `unrenderable` being empty
(and `belowWcag` for touch targets), and both gates are mutation-verified:
injecting `Row(children: [SizedBox(width: 9999), SizedBox(width: 9999)])` as a
screen builder turns the file red across 12 combinations.

## 3. What the published guidance actually says

- **Material 3 / Apple HIG** — a large title gets its **own full-width line**
  beneath the chrome (M3 medium/large top app bar; Apple large-title navigation
  bar). The old header was a *small* app-bar layout carrying *large* app-bar
  content, which is exactly the shape both platforms tell you not to build.
- **Apple HIG** — a title is a short phrase describing the view, under ~15
  characters, never the app name. `User` is not a title.
- **NN/g, [Homepage Design Principles](https://www.nngroup.com/articles/homepage-design-principles/)**
  — generic welcomes carry no information. A greeting plus a date the status bar
  already shows is the textbook case.
- **NN/g, [Visual Hierarchy](https://www.nngroup.com/articles/visual-hierarchy-ux-definition/)**
  — no more than three sizes; size signals importance. Here size was inversely
  correlated with importance.
- **NN/g, [10 Usability Heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/)** #8
  — "every extra unit of information competes with the relevant units and
  diminishes their relative visibility." The header carried six competing
  elements before any content.

## 4. What changed

**`lib/core/widgets/app/app_header.dart`**

- New `HeaderLayout { auto, inline, stacked }`. `stacked` puts chrome on row 1
  and the title full-width on row 2 — the M3/Apple structure. `auto` (the
  default) stacks iff a greeting is present, so the ~49 title-only and
  title-plus-back-arrow headers are untouched; only 6 of 55 call sites pass a
  greeting.
- The greeting is clamped to `maxLines: 1` + ellipsis **unconditionally**. This
  is the actual bug fix; the stacked layout is the quality fix.
- `leading` is bounded to 40% of the content width, so `AppChip`'s ellipsis
  finally engages.
- A greeting-only header no longer pays for an empty chrome row.

**`lib/features/home/screens/home_dashboard.dart`**

- `title: 'Today'`, `layout: HeaderLayout.stacked`, greeting and date removed.
- The profile-label future is memoized against the active dependent, mirroring
  the existing `_medicineData(rev)` pattern. It was previously constructed
  inline in `build()`, so it re-queried the database and flashed `'Me'` on every
  frame — and Home rebuilds once a second while a Focus timer runs.
- The next-dose hero moved **above** the briefing strip: the first thing under
  the title is now the next action.
- The `Today` section header became `Your day` — a page titled Today containing
  a section titled Today is both bad IA and ambiguous to every test finder.

**`lib/core/health/coach_text.dart`** — `dailyBriefing` returns the advice
clause alone. It used to return
`'$greeting! Today so far: meds 1/2 · water 40%. $nudge'`, which at `maxLines: 2`
reliably truncated `$nudge` — the only actionable clause — to pay for a greeting
the header already showed and numbers the pulse row renders directly below.

**`lib/core/services/auth_service.dart`** — `displayName ?? 'User'` became
`?? ''`. `User` is a placeholder, not a name, and no in-app setting ever fed it.

## 5. Coverage added

| File | What it pins |
|---|---|
| `test/support/text_layout.dart` | Real rendered line counts via `TextPainter.computeLineMetrics()`. `didExceedMaxLines` is useless here — it is `false` by construction when `maxLines == null`, i.e. for the exact widget that broke. |
| `test/core/widgets/app_header_test.dart` | 30 tests: 5 widths × 3 text scales for greeting and title, a pathological profile name, hidden actions, stacked width, and that inline call sites keep their geometry. |
| `test/features/home/home_header_test.dart` | Home renders `Today`, no greeting, no date, never the string `User`, and the briefing is advice rather than a recap. |
| `test/responsive/responsive_overflow_test.dart` | A `WRAPPED HEADER TEXT` section across all 47 screens, plus the three gates. |
| `integration_test/home_header_e2e_test.dart` | The same assertions against real hardware — real font, real width, real Dynamic Type. Needs a device. |

**Mutation-verified.** Every fix was reverted one line at a time to confirm the
tests fail: dropping the greeting clamp fails 16 header tests and lights up 4
screens in the app-wide sweep (`focus`, `focus_stats`, `weekly_recap`,
`medicine` — all of which were wrapping too); removing the `leading` bound fails
5; forcing inline fails 2; restoring the `User` title or the briefing greeting
fails 3 each.

---

# Performance work in the same pass

Re-measured with `test/performance/screen_build_cost_test.dart` (median of 7,
host VM, relative signal — not device frame budget).

## Home: 80.1 ms → 27.4 ms first frame, at an unchanged widget count

The tree did not shrink (798 → 799 widgets), so the saving is work removed from
`build()`, not markup deleted:

- the profile-label `Future` was constructed **inline in `build()`**, so it
  re-queried the dependents table and re-subscribed the `FutureBuilder` — which
  flashed the "Me" fallback — on every frame
- the greeting rebuilt a `DateFormat` and formatted the date every frame
- `_loadMedicineData()` awaited four service calls in series, and each re-fetched
  what it needed

Measured against a real in-memory database, one Home load issued **6 reads of
`enhanced_medicines` and 4 of `medicine_logs`**. `getAllMedicines()` re-maps
every row and re-decodes every schedule JSON, so those duplicates were CPU on
the UI isolate, not just round trips. Each table is now read once, the
independent reads run concurrently, and the summary and dose list are computed
from the rows already in hand: **4 and 3**.

New seams, both pure over already-fetched rows:
`MedicineCleanStorageService.summaryFrom` and `TodayScheduleService.dosesFrom`.

## Focus: 2322 widgets no longer rebuild once a second

`FocusService._startTimer` called `notifyListeners()` every second. The Focus
screen wraps its **entire body** in one `ListenableBuilder` on that service, and
that body is a `SingleChildScrollView` over thirteen configuration sections —
**2322 widgets, the largest tree in the app by roughly 3×**. So a 25-minute
pomodoro rebuilt all of it about 1500 times. `HomeDashboard` listens to the same
service, so it was rebuilding at 1 Hz as well.

The per-second signal now travels on its own `ValueNotifier`
(`FocusService.tick`), which only the clock and the progress ring listen to. The
`ChangeNotifier` still fires for real state changes — start, pause, phase
change, completion — which are user-driven and rare.

The tick body was extracted to `applyTick(int)` (`@visibleForTesting`)
specifically so the regression test drives the **real** code path. Asserting
against the notifier in isolation would have passed with `notifyListeners()`
reinstated.

## Medication dashboard: `enhanced_medicines` 6 → 4

A sweep of all 20 data-backed screens with the same counting executor found the
medication dashboard was worse than Home had been: it loaded `_medicines`, then
called `getCurrentStreak`, `getAdherenceStats` and the schedule builder, each of
which re-read the same table. `_buildTodaySchedule` now computes from the list
already in hand via `dosesFrom`, and `getAdherenceStats` takes an optional
`medicines` argument.

Two caveats on that sweep, both learned the hard way:

- Several services here are **static singletons that cache across tests**, so
  per-screen numbers shift with test ordering. Anything acted on was re-measured
  in a controlled single-screen test before and after.
- The other screens with duplicate reads — `adherence` (4×/2×) and
  `weekly_recap` — are **not** fixed.

## Coverage

| File | Pins |
|---|---|
| `test/performance/home_query_count_test.dart` | Reads per table for one Home load, and that the header profile `Future` survives a rebuild. |
| `test/performance/focus_tick_scope_test.dart` | That a tick does not fire the `ChangeNotifier`. |

The query test also covers the medication dashboard (mutation: restoring both
re-fetches reports `read 6 times`).

Both mutation-verified: restoring the serialized fetches reports
`enhanced_medicines was read 6 times`; reinstating `notifyListeners()` in
`applyTick` fails the scope test.

> A first version of the query test matched `from "medicines"`. The Drift table
> is `enhanced_medicines`, so it matched nothing and **passed with the bug
> deliberately restored**. The thresholds in that file are measured numbers for
> exactly this reason — assume nothing about SQL a test greps for.

## Not done

The broader performance audit (85 findings: 2 critical, 21 high, 33 medium, 29
low) is **not** complete. The critical two plus `H01`/`H19` were fixed by hand;
the batch dispatched to fix the remaining 76 failed outright — every agent
errored and returned nothing — and **the finding list itself was lost with it**,
having never been written to disk. What is fixed above was re-derived by
measurement, not recovered from that list. Regenerating it means re-running the
audit.

# The rating: one command, one number

```bash
dart run tool/rate.dart
```

Exit `0` clean · `1` findings · `2` **INVALID** (a harness did not report).

## Why the number used to move

It was not the app being unstable. It was that **"the score" had no definition**:

- `renderRatingTable` was called exactly once in the repo — inside
  `screen_build_cost_test.dart`'s own `tearDownAll`, over **25 of ~81 screens**.
  Run a different command, get a different number, or none at all.
- The 720-combination responsive sweep and the touch-target audit could turn the
  build **red** while leaving the score at **100** — neither ever constructed a
  `Finding`.
- The device suite had **zero assertions** and passed on an empty result.
- `deviceMeasured: false` was a hardcoded literal: a claim about a different
  process, asserted by a process with no way to know.

A score that has never once gone down is not a score.

## What makes it reproducible now

**1. Everything scored is a count, a boolean, or a within-run ratio.** No
wall-clock enters the number. The build-cost harness itself observed an ~8×
swing between two runs of an identical screen; admitting a timing threshold
would trade reproducibility for a figure nobody can reproduce. Frame timing IS
measured on device (`integration_test/z01_perf_e2e_test.dart`) and is
**reported, never scored** — an emulator's GPU is the host's.

**2. A manifest, and the tool refuses to score without it.**
`rating/manifest.json` lists every priced dimension and the harness that owns
it. If a declared dimension does not report, `tool/rate.dart` prints `INVALID`
and exits 2 instead of a flattering number.

> **This section was false for as long as it existed, and an adversarial audit
> caught it.** The claim was written, repeated here and in the manifest's own
> `_comment`, and never implemented. The validation block contained exactly three
> rules — harness-never-ran, harness-crashed, and unknown-dimension — and the
> first was *unreachable dead code* (`ran.add()` ran unconditionally one line
> after the only thing that could distinguish members from non-members). Worse,
> the check was **unimplementable in the old protocol**: `emitFinding` only prints
> when something is wrong, so "measured and clean" and "never measured" were
> byte-identical silence. Pointing all seven harness paths at nonexistent files
> printed `SCORE 100 / 100  GRADE A  5.00 / 5`, the words `manifest OK`, and
> exit 0, with sixteen dimensions unmeasured.
>
> Fixed by adding the missing half: `reportMeasured()` in
> `test/support/perf_rating.dart` emits one `DIM|<id>` beacon per dimension,
> unconditionally, from every harness. `rate.dart` now requires a beacon for every
> manifest dimension. Verified three ways — all seven harnesses missing → INVALID
> naming all sixteen; one harness missing → INVALID naming exactly its two; the
> real run → a valid score with 16 beacons. The exit-code heuristic is kept only
> as a secondary signal, because a missing file, a missing `main()` and a compile
> error all exit **1**, the same code a harness returns when it merely found
> something.
>
> Severity is now taken from the **manifest**, not from the finding. "A harness
> cannot invent a severity" was asserted at the same time and equally unenforced:
> `d['sev']` was never read, so a harness emitting P2 for a dimension priced P1
> silently repriced its own defect. A mismatch is now `INVALID`.
>
> **A second audit then defeated the beacon fix.** A bare `DIM|<id>` certifies that
> the harness FILE ran, not that the dimension was measured. Demonstrated on
> `screen_build_cost_test.dart`: run with only its `warmup` test it emitted all four
> beacons, zero findings, exit 0, and printed its cost table with a header and no
> data rows — output indistinguishable from an honest 29-screen run, because every
> gate in it is "is this collection empty" and one line actively hardens the empty
> case. Beacons now carry a sample count (`DIM|element-budget|29`); a reported zero
> is `INVALID`; and that harness asserts it measured every screen. Three sibling
> harnesses already asserted their own non-vacuity — it was the one that did not.
>
> **And `exit 1` was still swallowed.** Only `exitCode > 1` was inspected, but exit
> 1 is what a harness returns *both* when its `expect`s threw over real findings
> *and* when a gate went red that emits no finding at all — `couldNotBuild`,
> `motionRemoved`, the vacuity guards, the geometry header floor. Those fail the
> build and are invisible to the score, so a red harness with zero findings printed
> as perfectly clean. Exit 1 with zero findings is now `INVALID`.
>
> Two smaller holes closed with them: a malformed `PERF|` line was silently
> discarded (a finding the tool could not READ simply vanished, while the beacon
> still reported the dimension measured), and the report grouped findings by the
> raw `f['sev']` while iterating uppercase literals, so a correctly-priced finding
> could render as `1 finding(s):` followed by nothing.
>
> All three new rules were verified by making them fire: a harness that beacons and
> fails → INVALID; a *passing* harness reporting `samples: 0` → INVALID, exit 2;
> `screen_build_cost` restricted to `warmup` → "measured 0 of 29 screens".
>
> The lesson worth keeping is not any one of these bugs. It is that each fix for
> "the instrument cannot tell measured from unmeasured" introduced a narrower
> version of the same hole, three times running, and each was found only by someone
> trying to break it rather than trying to confirm it.

**3. Findings are grouped per surface.** 4 devices × 3 scales meant one blank
screen emitted twelve findings and cost 12 × P1 — pricing a single defect above
the entire app.

> The same audit found this reintroduced one scope up.
> `focus_screen_geometry_test.dart` called `emitAll` at the end of **each of its
> four tests** over a `findings` map declared in `main()` and never cleared, so one
> alignment drift recorded by the first test was re-emitted by the three later
> calls: 4 × P2 = −20, grade B, for a single defect. The grouping worked *within* a
> test and broke *across* them. Emission now happens once, in `tearDownAll`; the
> per-test `expect`s stay where they are, because they gate.

**4. A dimension that cries wolf is worse than no dimension.**
`renders-blank` first reported 24 findings, all from two surfaces that render
nothing *correctly*: `ProactiveNudge` is a frequency-capped banner
(`if (_insight == null) return const SizedBox.shrink()`), and `BackupScreen` was
caught mid-load. Both are allowlisted **with written reasons** in
`responsive_overflow_test.dart`. `a11y-contrast` is excluded for the same
reason and says so in the manifest's `excluded` block.

## What 4.5 means

`docs/app-rating.md` publishes `score / 20 = out of 5`. So:

> **4.5 / 5  ⇔  score ≥ 90  ⇔  zero P0, zero P1, and at most two P2 findings,
> across the whole app, across every dimension in the manifest.**

A cliff, not a dial: one P1 lands at 85 = 4.25. "Make it 4.5" and "fix every P0
and P1" are the same instruction.

## The blind spot this had, and what closed it

For its first twelve dimensions the score measured **structure only**: does it
build, does it overflow, is the text visible, are the targets big enough. Every
one of those can be green on a screen that a blind user cannot operate, that
ignores the reduce-motion preference, that offers a new user nothing to do, and
that answers a finished session with silence.

That was not the score being wrong. It was the score being **blind**, and it
showed: the app printed **95/100, 4.75/5** while `Semantics(` appeared **zero
times** in the whole Focus feature, `disableAnimations` was respected nowhere in
it, six of its eight screens had never had a tap target measured, and the 144-line
celebration in `focus_toast.dart` had zero callers.

Four **experience** dimensions now sit alongside the structural twelve, held to
exactly the same standard — each is a count or a boolean against a citable
standard or a structural contract in this codebase:

| Dimension | Sev | Measures |
|---|---|---|
| `no-semantics` | P1 | WCAG 2.2 SC 4.1.2 / 1.1.1 — tap targets with no accessible name, and informational `CustomPaint` with no text alternative |
| `motion-not-reduced` | P1 | WCAG 2.2 SC 2.3.3 — `transientCallbackCount` still non-zero with `disableAnimations: true` |
| `dead-end-empty-state` | P1 | a fresh install must render an `EmptyState` with a non-null action |
| `silent-completion` | P1 | a session completing with the screen mounted must produce in-app feedback |

Adding them took the same working tree from **4.75/5 to 0.00/5** (15 × P1 +
2 × P2) before a line of UX work was done. Both numbers were accurate about
different questions.

Two design notes worth keeping:

- **`motion-not-reduced` is two-sided.** "Nothing is scheduled with reduce-motion
  on" is satisfied perfectly by *deleting* the animation, which would turn the
  gate green while making the app worse. A paired opposite assertion requires the
  motion to still run when it is allowed, so the only way through is the real fix.
- **`silent-completion` defaults to a finding.** Its first version left the result
  null until a defect was found, so when the probe threw on its own sanity check
  the report printed a clean result for a measurement that never happened — the
  exact failure this document exists to prevent, reproduced inside a new harness.

## What the number still cannot see

Disclosed rather than hidden — an undisclosed hole is worse than a low score:

- **Delight is not in here.** These four dimensions can prove nothing is
  unlabelled, unreachable, undersized, motion-forced, a dead end, or silent. They
  cannot prove the particles feel good, that the plant is charming rather than
  twee, or that the copy sounds human. That needs eyes on a device, and no score
  should be read as a substitute for it.
- **Coverage is the headless harnesses.** The device suites (`integration_test/`)
  assert hard and fail the build, but do not yet emit findings, so they gate
  without scoring.
- **Frame timing is unscored by design** (see above).
- **`disposal-leak`, `n-plus-one`, `a11y-contrast` are unwired.** The manifest's
  `excluded` block records why for each.

The honest reading of any number this prints is therefore an **upper bound**:
the dimensions not yet wired can only ever subtract.

## Re-baselining

Element budgets are measured numbers plus ~15%, in `screen_build_cost_test.dart`.
Change them **in a commit of their own, with the reason written down** — as when
the seeder gained reminders and focus and three screens legitimately grew
(`Reminders/list` 392 → 1354, because the old budget was measured against a list
with zero rows in it).

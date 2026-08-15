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
it. If a harness crashes or never runs, `tool/rate.dart` prints `INVALID`
instead of a flattering number. Before this, "nothing found" and "nothing
measured" printed identically — which is precisely how the number moved.

**3. Findings are grouped per surface.** 4 devices × 3 scales meant one blank
screen emitted twelve findings and cost 12 × P1 — pricing a single defect above
the entire app.

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

## What the number still cannot see

Disclosed rather than hidden — an undisclosed hole is worse than a low score:

- **Coverage is the three headless harnesses.** The device suites
  (`integration_test/`) assert hard and fail the build, but do not yet emit
  findings, so they gate without scoring.
- **Frame timing is unscored by design** (see above).
- **`disposal-leak`, `n-plus-one`, `a11y-*` are unwired.** The manifest's
  `excluded` block records why for each.

The honest reading of any number this prints is therefore an **upper bound**:
the dimensions not yet wired can only ever subtract.

## Re-baselining

Element budgets are measured numbers plus ~15%, in `screen_build_cost_test.dart`.
Change them **in a commit of their own, with the reason written down** — as when
the seeder gained reminders and focus and three screens legitimately grew
(`Reminders/list` 392 → 1354, because the old budget was measured against a list
with zero rows in it).

# Correctness bug hunt — August 2026

A deep per-feature audit for bugs that produce **wrong health data**, lose data, or
fail silently. Not a style review — the UI conformance work is in
[`ux-review.md`](ux-review.md) and [`ui-audit.md`](ui-audit.md).

## Result

| | |
|---|---|
| Raw findings | **64** |
| Adversarially verified | **30** |
| **Confirmed real** | **29** |
| Refuted as false positives | **1** |
| Medium/low, unverified by design | **34** |

| Gate | Result |
|---|---|
| Analyze | **0 errors**, 23 warnings |
| Tests | **925 passing** (822 before; the fixes brought ~100 regression tests) |
| Overflow — 320→428px × text 1.0/1.3/2.0× | **0 across 564 combinations** |
| Touch targets below WCAG 24pt | **none** |
| Android release | **122.2 MB APK** |

## Method

Eight parallel agents, one per feature area, each seeded with the six bugs of this
class already found in this codebase — fabricated adherence, invented chart data,
`NaN.clamp` returning the *upper* bound, doses saving as 0 or negative, a snooze
reminder lost on reboot, sync gated on a check anonymous accounts satisfy. Those
established the *shape* of mistake to look for.

Every critical/high finding then went to a **separate agent instructed to refute
it** — check reachability, look for a guard upstream, confirm the input state can
actually occur, and default to "not a bug" when uncertain. In health logic a false
positive is worse than a miss, because it sends someone editing dose maths for
nothing.

Several verifiers proved their case by **executing the code** rather than reading
it, notably under `TZ=America/New_York`.

## The most serious findings

### Medicine alarms were silently never scheduled

`android_alarm_manager_plus`' native `AlarmService.java:147-158`: with
`alarmClock: true` and `SCHEDULE_EXACT_ALARM` not granted, it logs an error and
**returns without scheduling** — while `oneShotAt` still resolves `true`. The app
could not detect it. The patient believed reminders were set and received none.

*Fixed:* a single `_registerAlarm` entry point checks the permission first and falls
back to an inexact `setAndAllowWhileIdle` alarm (late beats never), records the
downgrade, and `NotificationPermissionBanner` now surfaces it as "Reminders may
arrive late" with an "Allow exact alarms" action.

### "✓ Take" on a notification recorded nothing after any cold start

flutter_local_notifications stores **one app-wide** background callback handle
(`FlutterLocalNotificationsPlugin.java:1658-1662`). `NotificationService.init()`
runs on every cold start and overwrote the alarm isolate's handler with one that
handled only `snooze`/`dismiss` — and `ActionBroadcastReceiver` routes *every*
`showsUserInterface:false` action to that handle. The dose was never queued, never
logged, stock never decremented.

### One root cause behind five findings: DST

`Duration(days: 1)` stepping and `.difference().inDays` measure **elapsed time**, not
calendar days, so a 23- or 25-hour day drifts them by one. Verified consequences
after a spring-forward:

- A **10-day antibiotic course stayed active on day 11**.
- An **every-2-days medicine moved to the opposite days** — the correct day returned
  *no slots*, so no reminder fired **and** missed-dose reconciliation recorded
  nothing. A silently skipped medicine.
- A 21-on/7-off contraceptive cycle shifted phase.
- Streaks reset or halved across medication, water and steps.
- Titration escalations landed a day late.

The fix pass found two more the audit had missed: `deriveCycles` collapsed a 23-hour
step to `0`, hitting a duplicate-day `continue` that **silently dropped a day from a
period run** (a 5-day bleed recorded as 4, corrupting median cycle length and every
downstream prediction); and `phaseOn` returned `ovulation` for a day that is actually
luteal.

Measured: **34 assertion failures → 0** under `TZ=America/New_York`. Pinned by a test
that spawns an out-of-process probe, because a Dart VM reads its timezone once at
startup and cannot switch at runtime.

### Restoring a backup permanently destroyed data

Settings → Cloud Backup → Restore called `restoreBackup(clearExisting: true)`, which
wiped **18 tables**; `importData()` restores **8**. Deleted with nothing to put them
back:

- **All dose/adherence history** — `exportMedicinesJson` serialises medicines only;
  the logs-carrying `exportAllMedicineData` has *no callers*
- Period days, cycles and settings — not in the export format at all
- Sleep sessions and **hand-typed step entries** — unrecoverable from Health Connect
- Per-drink water logs, plus any water older than 90 days

The rollback snapshot used the *same lossy export*, so the failure path could not
recover them either. The screen reported **"Backup restored successfully."**

*Fixed:* `clearRestorableData()` clears only what `importData` can repopulate, and the
rollback only runs when we were the ones who cleared (a non-destructive restore
deletes nothing, so wiping there destroyed strictly more than the failure did).
`test/core/restore_does_not_destroy_test.dart` pins the invariant that the two lists
stay in sync.

### The adherence streak counted by clock time only

`takenKeys` was built as `'y-m-d-H-M'` with **no medicine id**. Two medicines at 08:00
— the normal case, since `groupRemindersBySlot` exists specifically to collapse
same-minute medicines into one reminder — meant taking *one* marked *both* taken, so
the day counted complete and the patient was shown a perfect streak while never
taking the second drug. The log set was also never filtered to eligible ids, so a PRN
or archived medicine logged at 08:00 marked the 08:00 statin taken.

The same file's `dedupeByDose` and `getAdherenceStats` both do this correctly; the
streak function was the sole outlier.

### Clinically wrong displays

- The BP trend chart shaded **80–120 mmHg as "normal" for both series**, so a
  diastolic of 100 — hypertensive — rendered inside the green band.
- The **severe-low glucose emergency card had no recency bound**, so a reading from
  days earlier re-fired a false medical emergency.

### Health data silently discarded

- **Manual step entries were dropped** on any day that also had a sensor reading.
- A **hand-logged sleep night was replaced** by the Health-imported night on the next
  sync.
- **Deleted sleep sessions and step days were resurrected** by cloud sync — hard
  deletes with no tombstone, so the sync saw the row missing locally and
  re-downloaded it.

### Other confirmed

Doses logged from a notification always recorded `dosageTaken = 1`, under-decrementing
stock for any multi-unit dose. The daily-adherence chart counted doses from medicines
its own denominator excluded. The medicine detail screen computed adherence as
`taken / log-rows`. "Add Medication" on the Schedule step bypassed every step-2 guard.
Titration steps accepted 0 and negative doses. Only 90 days of water history loaded,
and *editing* an older day destroyed it. Medicine sync died permanently after the
first upload while reporting success. Today's water was overwritten by a stale cloud
snapshot.

## The refuted finding — why the skeptic stage paid for itself

**Claim:** clearing a period day's mood/BBT/note never persists, because
`PeriodDao.deleteDay` is a hard delete and cloud sync resurrects the row.

Both cited code facts were **correct**. But the entire period sync is gated behind
`PeriodSettings.cloudSyncEnabled`, which defaults to `false` and has **no UI anywhere
that sets it**. The precondition is unreachable, so the bug cannot fire.

A correct reading of two code locations still produced a non-bug. Without the refute
stage this would have sent someone editing cycle logic for nothing.

## A process failure worth recording

Adversarial verification was capped at 24 findings. There were **30** critical/high.
**All six that fell outside the cap turned out to be real** — including the
data-destroying restore above, the single worst bug in the set. An arbitrary number in
a workflow script decided that a claimed data-loss bug went unchecked.

They were verified in a follow-up pass and fixed. The lesson is not "raise the cap" —
it is that a cap on *which* findings get verified must be justified by severity, never
by convenience.

## Outstanding

- **Soft-delete tombstones for sleep and period rows need a Drift schema migration.**
  Two fix agents flagged this and deliberately did not do it blind. Until then the
  resurrection bug is mitigated but not structurally closed for cloud-sync users.
- **34 medium/low findings** remain unverified by design.
- Six critical/high findings were verified late; their fixes are in, but they did not
  go through the same fix-then-reverify cycle as the original 23.

---

# Second pass — September 2026

A whole-app re-audit: every feature line by line for critical bugs, performance,
code quality, positive **and** negative user scenarios, UX, and UI/typography —
then fix what was found. Where the August pass hunted wrong health data, this one
kept finding a second class underneath it: **tests that could not fail**, so a
defect and its "fix" both looked correct.

## Result

| | |
|---|---|
| Raw findings | **257** |
| Verified against the code by 6 agents + 6 skeptics | **205** |
| Closed this pass | **~215** |
| Refuted on evidence (no fix written) | **8** |
| Cannot be done in this environment | **4** |

| Gate | Before | After |
|---|---|---|
| Analyze | 0 errors | **0 errors** (4 intentional Drift warnings) |
| Tests | 2,197 passing | **3,030 passing** |
| Test files | 203 | **349** |
| Responsive sweep | clean | **clean**, and the report is now trustworthy |
| Raw `SnackBar` in `lib/features` | 24 files | **0** |
| Raw `AlertDialog` in `lib/features` | 12 files | **4**, each with a written reason |

## The finding that outranks the rest

**The tests were lying more often than the code was.** Not as a slogan — as a
count. Every one of these was found during this pass, and several were in tests
written *during* it:

* A responsive harness that printed a report with **zero `expect()` calls**, so
  "564 combinations, NO OVERFLOWS" could never fail.
* A guard named *"the allow-list excludes every today-scoped signal"* that
  enumerated **nine** ids by hand and omitted the tenth — the broken one.
* A lock test whose paused→resumed round trip took **milliseconds** against a
  **30-second** grace period, so its branch was unreachable in either direction.
* A test asserting on `DailyFocusStats.minutesByTag` — a field **no widget
  renders**.
* A test that built its **own** `ValueListenableBuilder` and so measured Flutter
  rather than the app's use of one.
* A suite that proved a helper's truth table but never executed the `!` at the
  shipped call site — so `_deleteBackup` running on **Cancel** passed 8 tests.
* A guard whose string also matched a *different* call on the next line, so
  deleting the thing it guarded still passed. (That one was mine.)
* A `find.byIcon(Icons.*)` rule matching any identifier *ending* in "Icons", so
  it fired on correct code and got suppressed.
* A `CountingExecutor` blind to Drift transactions, so every "at most N writes"
  budget passed as long as the writes were batched — exactly what such a test
  exists to catch.

The method that worked is **mutation verification**: break the production code,
watch the test fail, restore. It is the only thing that separates a test from a
comment. Two fixes in this pass were caught *only* because their mutation
returned zero failures.

## The most serious findings

* **The Forgot-PIN wipe left cloud sync on and the user signed in** — so the
  cloud restored everything the wipe was meant to destroy, with the lock now off.
  A privacy control that did the opposite of what it promised.
* **A correct PIN read "Incorrect PIN"** for up to 30 minutes during lockout,
  with no countdown — the user was told they were wrong when they were right.
* **The glucose chart ignored the mmol/L setting.** The hero read 7.0 and the
  plot beneath it drew 126 on a mg/dL axis with a 70–180 band. Out by ~18× on
  one card, on the screen a person checks before treating a low.
* **"Call emergency" only showed a snackbar.** A button on a hypo/hypertensive
  crisis screen that did nothing.
* **The water download fetched the OLDEST 30 days** (a missing
  `descending: true`), so a returning user restored ancient data.
* **Deleted drinks came back**, and deleted nights and period days never
  propagated — cloud sync read the `deletedAt`-filtered DAO getters, so
  tombstones could not travel.
* **Backups over Firestore's 1 MiB limit threw**, and the catch only
  `debugPrint`ed: the user's backup silently did not exist.
* **~20 sites did calendar arithmetic with `Duration`.** A civil day is 23 or 25
  hours: focus charts dropped Monday, the water week rendered **M T W T F S M**,
  a reminder armed an hour late, and "yesterday" matched today.

## Refuted, and why that matters

Eight findings were refuted on evidence rather than fixed. Two are worth
recording because the "fix" would have been worse than the bug:

* **L20** — a stale tag id in the stats breakdown. `calculateTagStatistics`
  projects over the **live** tag list, so a deleted id structurally cannot reach
  the screen. The fix that had been written filtered a field nothing renders and
  added a `TagService` singleton dependency that would have zeroed every tag's
  minutes if called before init. It was reverted.
* **R14** — `checkPermissions()` returns `true` on error. Real, but it gates
  **13 early returns**, so failing closed converts a rare "armed but muted" into
  a rare "nothing armed at all". The audit's stated harm also proved
  unreachable. The right fix is to report permission state *alongside* the
  schedule result rather than gate on it — a design change needing device
  verification, so it stays open with the reasoning written down.

## Process notes

* **Directory-exclusive ownership** is what made parallel agents safe. Splitting
  by *finding* produced collisions; splitting by *directory* did not.
* **Review is not optional.** Every unreviewed agent group in this pass had
  something wrong with it — including one whose doc comment claimed a call was
  inside a `try/catch` when it was outside, so the one failure it was written for
  was still uncaught.
* **Session limits killed agents mid-mutation**, twice leaving production methods
  gutted with only a `// MUTATION:` marker to show for it. Both compiled and the
  analyzer was clean. Grep for that marker after any interrupted run.
* A perf budget that is quietly raised has stopped measuring anything. When
  `Insights/trends` grew 130 elements, the cause was checked first — a ring
  reporting progress against an invented 60-minute goal became a bar chart — and
  the reason was written into the budget.

## Outstanding

* **Four items need Android hardware** and are deliberately not written:
  **F6** (`requestPermission` in `MindfulnessChannel.kt`), **SS-08** and
  **SS-09** (`StepsSleepWidgetProvider.kt` and its layout), **TQ-23**
  (permission-denied device suites). Shipping an unverified permission flow
  marked "done" is the exact failure this audit kept finding.
* **R14** as above — open by judgement, not omission.
* **`textTertiary` measures 3.78:1 at 11pt** app-wide. Fixing it is a design
  decision about the palette, not a bug fix, so it is flagged rather than
  changed.
* **The weekly recap can show a 7-day adherence hero beside a 180-day
  `med_adherence` figure.** The copy hedges ("lately"), so it never literally
  claims the week — but two different percentages sit on one page. Relabel,
  rescope, or leave: a product call.

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

---

# Device pass — Android emulator, Sep 29–30 2026

The audit above was entirely headless. This pass opened each screen on an
emulator (`dlyminder_test`, 1080x2400 @ 420dpi, seeded debug build), drove the
primary action, and read the result back. Fourteen defects, none of which any of
the 3,273 existing tests could see.

## Method

Flutter exposes its semantics tree to `uiautomator` as `content-desc` with real
bounds, so a screen can be *addressed* rather than tapped at guessed pixels:
dump the hierarchy, find the widget by its accessibility label, tap its centre,
dump again to confirm where you landed. That also yields every touch target's
size in dp for free.

The first attempt did not do this — it tapped a list of remembered y-offsets in
a loop. Five captures came back, two of them byte-identical to each other and
one of them a Gmail onboarding screen that had stolen the foreground. **A blind
tap loop cannot tell you it missed.**

## What was found

| # | Area | Defect |
|---|---|---|
| 1 | `AppListTile` | Subtitle capped at one line; 27 rows truncated, two of them explaining irreversible actions |
| 2 | Water | Beverage chips announced `selected:` and "select beverage" but opened a picker; tapping "Coffee" selected nothing |
| 3 | Water statistics | `Row` of per-hour columns defaulted to `CrossAxisAlignment.center`, so no bar and no axis label shared a baseline |
| 4 | Hydration profile | Sex chips 32dp against the app's own 44dp floor |
| 5 | Today | Briefing said "5 doses left" above a card saying "Nothing left today" — two definitions of *left* from one summary |
| 6 | Steps | Trimming past zero stored the whole over-subtraction; the day showed 0 and the next `+4,000` came out as 700 |
| 7 | Workouts | Day headers rendered the raw `dateKey` — "2026-09-28" |
| 8 | Workouts | One dumbbell for every activity; Running, Walking and Strength training were identical |
| 9 | Blood pressure | "Most readings above target" fires from 40%, printed above its own "50%" |
| 10 | Period | "Due today" for an estimate that had already passed — `days <= 0` swallowed every overdue day |
| 11 | `RelativeTime` | `delta.inDays` truncates: a reading from the 28th read "yesterday" on the 30th. Five screens share it |
| 12 | Diary | `displayTitle` falls back to the body's first line, and the row then printed the whole body underneath — every entry twice |
| 13 | Sleep | A constant `LAST NIGHT` eyebrow over the most recent *logged* night, beneath a "Log last night" button |
| 14 | Log sheet | "Period / mood" wrote `PeriodDay.mood` while a separate "Mood" row wrote `MoodEntry` — same word, different stores |

## A vacuous guard, found by fixing one of these

`e2e_string_registry_test.dart` checks that every string the device suites assert
still exists in `lib/`, by searching the concatenated source for `'literal'`.
Renaming the log-sheet tile should have failed it. It passed — because the
comment written *above the rename*, explaining what the string used to be, still
contained the old literal. This project's convention of recording what changed
right where it changed defeats the guard by construction. The corpus now has its
comments stripped, and only code counts as evidence that a string is on screen.

## Notes

* **`Container(alignment: …)` expands to its constraints.** Adding a 44dp floor
  *and* an alignment to the sex chips put "Male" and "Female" on separate lines.
  Nothing headless caught it: the touch-target audit measures a target's size,
  not its position, and a `Wrap` given an over-wide child does not overflow — it
  wraps, silently. The regression test asserts position, not just size.
* **Three of these are the same bug.** #10, #11 and #13 are all "a duration was
  truncated where a calendar day was meant". `calendar_day.dart` exists for
  exactly this and `AGENTS.md` bans `add(Duration(days: n))` for the same
  reason; the rule had not reached the read paths.
* **Four are one screen contradicting itself** (#5, #9, #10, #13). None is a
  crash, none is reachable by a unit test of either half, and all four are
  obvious within two seconds of looking at the screen.
* Running across midnight was free coverage: it exercised the day rollover and
  produced #10 and #13 without being arranged.

## Still not covered

* iOS — `MLKitCommon` ships no simulator-arm64 slice, so the app cannot link
  against an Apple-Silicon simulator. Needs a physical device.
* The hardware-only four (**F6**, **SS-08**, **SS-09**, **TQ-23**) and **R14**,
  unchanged from above.
* Remaining bottom sheets: `_RefillSheet`, `_RefillAmountSheet`,
  `_AddEditEntrySheet`, `_SmartAddSheet`, `_CategoryEditorSheet`, `AuthGateSheet`,
  `ConfirmationBottomSheet`. `LogSomethingSheet`, `AquaBeverageSheet`,
  `StepManualEntrySheet`, `LogTodaySheet`, `SleepManualLogSheet` and
  `NunitoTakeMedicationSheet` were opened in this pass.
* `BackupScreen` (cloud) still has no coverage — it needs a signed-in account,
  and this pass ran as a guest.
* Dark mode. Every capture here is light.

## Second round — the signature sweep, and what dark mode hid

The fourteen above were found by opening screens. Two more things followed.

### Dark mode, which no harness had ever rendered

`ShaderMask` defaults to `BlendMode.modulate` — it MULTIPLIES the shader by its
child rather than replacing it. The "Hydration" title's child colour is
`fillFg(water)`, which is `isDark ? swatch.on : Colors.white`. In light mode
that is white, `white * gradient == gradient`, and the title looks exactly as
designed. In dark mode it is the swatch's dark `on` colour, and the title
collapsed to rgb(0,27,38) on a rgb(12,67,80) header. Measured off the device
screenshot, the BEST contrast any pixel of the word reached was **1.71:1** —
the whole title was below that. `BlendMode.srcIn` takes the same measurement to
3.89:1. The comment above the widget had asserted for some time that the mask
"replaces this colour outright"; it did not.

Worth noting the codebase had already removed two other gradient-text
`ShaderMask`s for contrast — one measured at 1.03:1 for milk. The title
survived both passes because in light mode it is genuinely correct.

### Hunting the signatures elsewhere

Those fourteen have shapes. A sweep of the seven areas the device pass had not
reached, hunting the same seven signatures, produced 50 candidates; adversarial
verification (refute-by-default) killed 13 and confirmed 37. The five rated
high are fixed:

| File | What |
|---|---|
| `coach_text.dart` + `insight_engine.dart` | Both told a **fluid-restricted** user to drink. `HydrationProfile` returns the prescribed ceiling as the effective goal, so "behind" means "safely under the limit your clinician set". `hydrationTip` has refused this for a while and says why; the Home briefing strip and the proactive nudge banner never got the same guard, and `isRestricted` was already in hand at both call sites |
| `health_privacy_screen.dart` | The Play disclosure named **four** read types while the app requests **twelve** — the whole biometrics tier (heart rate, resting HR, HRV, SpO2, respiratory rate, body and skin temperature, workouts), every one declared in the manifest. The screen's own contract says "Claiming less than you read is the specific thing that fails review" |
| `adherence_report_service.dart` | The doctor-facing PDF divided by log ROWS while the Adherence screen divides by slots that came DUE. An un-actioned slot gets no row until `reconcileMissedDoses` reaches it, and its lookback is 14 days against a 30-day report — so three weeks of ignored doses were invisible and the PDF read 100% where the screen read half that. Both print "scheduled doses taken" |
| `background_alarm_service.dart` | The reminder-window nudges had only the `isActiveOnDate` half of the fire-time gate, so a windowed weekday dose nudged three times across a weekend morning the user had moved the dose away from — and a Take from one wrote a log at an instant that is not a slot, decrementing stock. The medicine-slot gate already had the missing half, with a comment explaining exactly why |

### Two guards that were not guarding

* **`e2e_string_registry_test.dart`** checks that every string the device suites
  assert still exists in `lib/`, by searching the concatenated source for
  `'literal'`. Renaming the log-sheet tile should have failed it. It passed —
  because the comment written above the rename, explaining what the string used
  to be, still contained the old literal. This project's convention of
  recording what changed right where it changed defeats the guard by
  construction. The corpus now has comments stripped.
* **My own first attempt at the adherence guard** pinned the denominator
  helper, and stayed green when the call site was reverted to counting rows:
  the helper was still correct, merely unused. The computation now lives in one
  function and the test asserts the headline percentage the clinician is shown.
  The same shape bit the weekend-gate test, where the two call sites live in an
  alarm isolate that a widget test cannot reach — there the wiring is asserted
  by source, with comments stripped first for the reason above.

### Notes

* **`Container(alignment: …)` expands to its constraints.** Adding a 44pt floor
  *and* an alignment to the sex chips put "Male" and "Female" on separate
  lines. Nothing headless caught it: the touch-target audit measures a target's
  size, not where it landed, and a `Wrap` given an over-wide child does not
  overflow — it wraps. The regression test asserts position.
* **Viewport clipping reads exactly like an undersized target.** Three separate
  times a control measured 6–37dp in the hierarchy dump and was simply behind
  the footer; scrolling gave 44–88dp. Every measurement here is taken twice.
* **The device disagreed with the audit twice, in the app's favour.** A second
  "Atorvastatin" looked like the add-medicine flow double-writing, and was the
  name already in the seed. A 2.97:1 contrast reading looked like a failed fix,
  and was a single antialiased pixel.

### Third round — working the confirmed list

The five high findings were fixed first. Working down the mediums produced ten
more, and two of them were caused by the same missing idea.

| File | What |
|---|---|
| `date_formats.dart` | `DateFormat('EEE, MMM d at h:mm a')` renders **"Sat, Mar 14 AMt 8:05 AM"** — intl reads the `a` of "at" as its am/pm character and only the `t` survives. Shipped under the heading "Next Dose" |
| `water_history_edit_screen.dart` | The beverage tiles overwrote the amount on every tap, and this sheet is the EDIT sheet too. Correcting only the drink type on "Coffee 400ml" silently rewrote it to Tea's 200ml |
| `enhanced_medicine.dart` (+2 screens) | Three screens each invented their own "is stock tracked". `currentStock != null` is never false (NOT NULL, default 0) so every medicine showed a fabricated "0 pill(s) remaining"; `> 0` dropped a tracked medicine the moment it hit zero — the exact moment it needs refilling. Now one `isStockTracked` |
| `focus_service.dart` | "Plants" in Today's Progress counted withered ones, so giving up on a session read `Minutes 0 · Plants 1 · Streak 0` |
| `stats_service.dart` | `getLast7Days` returned EIGHT days against an inclusive range, and D-7 shares today's weekday — so the Week chart summed two rows into one bar |
| `stats_service.dart` | "Productivity Patterns" asserted Peak Hour 12 AM / Best Day Mon for a user with no completed sessions: `analyze` returns a non-null object for an empty list, leaving its initialisers to pose as answers |
| `relaxation_screen.dart` | The progress bar and "% complete" sat outside the per-tick listener, so they held 0% for the whole session under a clock counting down correctly beside them |
| `blood_pressure_report_screen.dart` | One chart, two series, one 80–120 band. That is the SYSTOLIC range — so a diastolic of 95 (stage 2) was painted inside the green "normal" band, on the screen built to hand a clinician |

### A third vacuous guard, found the same way

`date_formats_test.dart` pinned each shared formatter against a freshly-built
`DateFormat` **with the same pattern**. That catches a wrong mapping and cannot
catch a wrong pattern — the comparison is a tautology the moment the pattern is
the bug. It asserted "AMt" against "AMt" and passed. Formatters carrying a
literal word are now pinned to their expected string.

That makes three guards in this pass that were structurally incapable of
failing: the string registry (satisfied by a comment), my own first adherence
test (pinned an unused helper), and this one. All three passed continuously
while the defect they covered was live.

### Where the fixes came from

Nine of these were fixed by copying something the codebase already had:
`calendarDaysBetween` for the date arithmetic, `isLowStock`'s opt-in rule for
stock tracking, the main BP screen's per-series band, the medicine-slot fire
gate for the window nudges, `hydrationTip`'s fluid-restriction guard for the
briefing strip and the nudge banner. In each case one surface had the right
answer and the other had never been told. That is what the signature sweep was
actually finding.

### Fourth round — the rest of the mediums

| File | What |
|---|---|
| `clinic.dart` | `isOpenNow` tested `now >= open && now <= close`, which assumes close follows open. A night pharmacy entered as "20:00 - 08:00" showed a red **Closed** dot at 22:00, beside its own printed hours |
| `AndroidManifest.xml` + `nunito_doctor_list_screen.dart` | The `<queries>` block declared the dialer — with a comment explaining Android 11+ package visibility — and never declared mail. So `canLaunchUrl('mailto:')` was false on a phone with Gmail, and the handler was a bare `if` with no else: the Email button did nothing, silently. Both handlers now report when nothing can take the intent |
| `trends_dashboard_screen.dart` | "Best this period · X at N% of goal" read the **clamped** `goalProgress` while the cards below it print the uncapped `goalPercent`, so one screen showed "Steps · 128%" and "Steps at 100% of goal". It also picked the winner on the clamped value, so anything at or above goal tied at 1.0 and "best" was whichever was added first |
| `medicine_storage_service.dart` | `getAdherenceStats` opened its window at `now.subtract(Duration(days: n))` — an elapsed instant, and the banned DST pattern — while the chart under the same ring used `dayOffset(now, -(n-1))`. At 14:00 the ring counted a 20:00 dose from a day the chart never draws |
| `backup_settings_screen.dart` | Warned "This overwrites current data… Any changes not in the backup will be lost", labelled the button "Restore & overwrite" and marked it dangerous — for a call that leaves `clearExisting` false and is, in the service's own words, a merge. A warning about data loss that cannot happen, on the screen people reach when they are already anxious |
| `backup_screen.dart` | The cloud restore reported plain success. `importData` documents that sleep, period and step singletons only reload in `init()`, "after the app restart the restore screens already ask for" — the local screen asks; this one had a `// Maybe … restart app logic?` note where the ask should have been |
| `haptic_settings_screen.dart` | Seven rows over four `HapticFeature` keys: three pairs were one setting wearing two names, and `.fitness` and `.notifications` had no row at all despite both firing haptics. Rows now generate from `HapticFeature.values` with exhaustive switches, so a new feature is a compile error rather than a missing row |

Two of these were the same shape as earlier finds: `isOpenNow` and `getAdherenceStats` both answered a calendar question with elapsed-time arithmetic, which is now five separate instances in this audit.

### Fifth round — the last of the mediums

| File | What |
|---|---|
| `vitals_pattern_detector.dart` + `blood_pressure_screen.dart` | The AM/PM card renders directly under the Morning / Evening tiles. The tiles average the last 7 days; the card walks `recentWindow` — 30 — and neither its detail nor its `why` said so, so the screen contradicted itself with nothing to explain it. The card now names both windows, and the tiles' filter moved off `difference().inDays` |
| `stats_service.dart` | The Focus Overview hero uses the calendar Mon–Sun week and the calendar month; Activity Breakdown two cards below used rolling windows. On a Wednesday the hero covered Mon–Wed while the breakdown covered the previous Thursday onward, so the breakdown could total MORE minutes than the hero said existed — under one control labelled "Week" |
| `weekly_recap_screen.dart` | The cover printed "Nothing logged yet this week." whenever no cards rendered. `_cards` builds no row for `bundle.period`, though the bundle carries it and `isEmptyWeek` counts it — so a week in which somebody logged their cycle and nothing else was told they had logged nothing |
| `weekly_recap_screen.dart` | The `_emptyWeek` card is gated on `cards.isEmpty && r.hero.hasValue` — its own comment says "Only when something WAS logged but nothing is chartable" — and its title read **"Nothing logged this week"**, the one claim that condition rules out, under a cover printing the hero figure that disproved it |

`isOpenNow`, `getAdherenceStats` and the BP tiles' filter were all the same
elapsed-vs-calendar shape; that is six instances across this audit.

### A fourth test that could not fail

`weekly_recap_screen_test.dart` had a case named "a genuinely empty week still
says so". Its fixture was `weekWithoutDoses()` — which carries water, steps,
sleep and weight — with `hasCards: false` passed by hand. It was testing the
cover's reaction to a *flag*, not to an empty week, and it only stopped passing
once the cover learned to tell the two apart. It now has a genuinely empty
fixture, and asserts the premise before the conclusion.

### Sixth round — the lows, and the sweep is closed

All 37 confirmed findings are now fixed. The last nine:

| File | What |
|---|---|
| `dependent_profile.dart` | Infant age was `difference().inDays ~/ 30`. Twelve 30-day "months" is 360 days, so a child five days short of their first birthday was listed as **"12 months"**. Now calendar months — and `age` itself moved to `clock.now()`, which is why this could not be tested against a pinned date before |
| `app_date_time_field.dart` | The shared vitals Date & time field labelled a reading dated the 8th "Today" on the 9th, on the day after spring-forward |
| `steps_history_screen.dart` | Same arithmetic, and the history list drew **two consecutive rows headed "Today"** |
| `reminders_screen.dart` | `today.add(Duration(days: 1))` on a fall-back day stays on the same date, so the "Tomorrow" bucket matched today and tomorrow's reminders were filed under "Upcoming" |
| `focus_screen.dart` | `_setupSummary` branched only on pomodoro, so Flow fell into the else and the collapsed row read "Single session" beside a Flow button |
| `focus_screen.dart` | The leave dialog printed "Time remaining: 40:00" during a Flow session, where `formattedTime` counts UP — its own comment says "time SPENT, not time left. Same formatting, opposite meaning" |
| `trends_dashboard_screen.dart` | The Sleep card's headline read the clamped ratio while its own ring centre printed the average: "8.0 h" over "100% of goal" against a 7h target |
| `water_history_edit_screen.dart` | The ring printed a percentage clamped at 150% beside the real ml figures |
| `weight_screen.dart` | The "vs last" delta was taken at full precision and rounded separately from the two readings it compares, so 70.44 and 70.36 rendered as "70.4", "70.4" and "+0.1 vs last" |

Four of the nine are the elapsed-vs-calendar shape: **ten instances** across the
whole audit, in a codebase that already had `calendar_day.dart`, a DST probe
that re-runs under `TZ=America/New_York`, and a rule in `AGENTS.md`. Having the
utility, the test and the written rule was not enough; the call sites still had
to be found one at a time.

### Two more guards that would not have failed

* The calendar-day assertions in `low_severity_display_fixes_test.dart` pass in
  any zone without DST *whatever arithmetic the screens use* — they state what
  the helpers mean and catch nothing on their own. The source guard beside
  them, with comments stripped, is what holds the three call sites; all three
  were mutation-checked through it.
* The Focus guard first asserted `contains('FocusMode.flow =>')` — and passed
  with the setup summary's own arm deleted, because the start-button label 90
  lines above contains the same substring. Tightened to the full arm, then
  re-checked.

That is six structurally-vacuous guards found or written during this audit. The
pattern is always the same: the assertion is true for a reason other than the
one intended.

### Back to the screens

With the sweep closed, the device pass resumed on surfaces it had not reached.

* **Focus garden day headers** were ellipsised at the DEFAULT text size on a
  411dp phone — "Monday, Septemb…", losing the date the header exists for. The
  row deliberately caps the label so it cannot push the minutes total off the
  edge, and that is right; the Long month name simply did not fit. Abbreviating
  it keeps the date.

Two things checked and found NOT to be defects, recorded so they are not
re-investigated:

* **The garden's "20 alive" header vs its type chips.** Both derive from
  `garden.where((p) => p.isAlive)`, so they agree by construction — the
  apparent mismatch was incomplete scroll sampling of a horizontally
  scrolling chip row.
* **Smart Add's Create button doing nothing on an empty field.** This is the
  same shape as the `_CategoryEditorSheet` finding the verification pass
  refuted, and for the same reasons: the blank field is directly above the
  button with its hint visible, and it is consistent across the app's sheets.
  Re-opening it on personal taste would defeat the point of having refuted it.

The garden header fix is also a reminder about the test font: asserting
`RenderParagraph.didExceedMaxLines` reported the label as clipped for a string
the device renders in full. The guard pins the FORMATTER instead, which is what
actually changed and is font-independent.

### The refill rate — found by reading a stock card

The Metformin stock card read **"39 left · ~16.3/day · runs out in 2 days"** for
a medicine the list two screens earlier described as "Once a day". Sixteen pills
a day is not a plausible reading of a once-daily prescription.

`RefillPredictor` averages the user's OWN taken-dose history rather than the
scheduled rate, which is the better idea. But it captured the window's start
with `earliestInWindow ??= t` — element ZERO of the list — and the production
caller feeds `getLogsForMedicine`, which orders `desc(scheduledTime)`. Element
zero is the NEWEST dose. So the "observed span" measured from now back to the
most recent dose, a few hours, which `clamp(1.0, …)` rounded up to a single day,
and the average daily rate became the entire window's total.

The effect: 16 doses over 21 days reported as 16.3/day, 39 pills projected to
last 2 days instead of about 47, and an "ACT NOW · Refill soon — reorder now to
avoid a gap" card on a medicine with seven weeks of supply. The same figure
feeds `refill_reminder_service`, so it also drives the notifications.

Taking the minimum makes it independent of how the caller sorted. On the device
the card now reads "39 left · ~0.8/day · runs out in 47 days" and the false
alarm is gone.

**Why the tests did not catch it.** `refill_predictor_test.dart`'s helper builds
its doses oldest-first, and with an ascending list `??=` happens to pick the
right element. Every test fed the one ordering production never uses. The new
group asserts the two orderings agree, which is a property no single-ordering
test can express.

### The refill sheet, and a wizard that forgot which job it was doing

`_RefillSheet` itself is sound — the stepper clamps at 1 (you cannot refill
zero units), the quick chips SET rather than add, "New total" tracks the
arithmetic at every step, and the write persists across a cold start.

The edit flow does not. `NunitoAddMedicationFlow` doubles as the edit wizard and
`_isEditing` already drives the app bar title and the final button. Step 1's
headline did not, so editing Metformin rendered three lines in one viewport:

    Edit medicine                  <- app bar
    What medicine are you adding?  <- headline, directly beneath
    [Metformin]                    <- the prefilled name field

The other four step headers ("How much do you take?", "When do you take it?" …)
read correctly either way and were left alone. The add-mode wording is kept and
tested, because `add_medication_discard_guard_test.dart` legitimately asserts it
while typing a NEW medicine called Metformin — which is also why the string
stays in the e2e registry.

### Numbers that did not add up on the Adherence screen

"17 of 36 scheduled doses taken", above tiles reading **Taken 17** and
**Missed 16**. Three doses unaccounted for, on the one screen whose job is
explaining that percentage.

They were SKIPPED — deliberately not taken, which the denominator counts and
the doctor-facing PDF has always listed. `_AdherenceSummary` parsed `skipped`
from the stats map and nothing ever rendered it. No comment explained the
omission; the number was simply loaded and dropped.

The tile is conditional (`if (_summary.skipped > 0)`) so an ordinary clean
record still shows three tiles rather than carrying a permanent "0 Skipped".
On device the row now reads 1 · 17 · 16 · 3, and 17 + 16 + 3 = 36.

Worth noting how this was found: not by opening a new screen, but by adding up
the numbers on one already visited. Two rounds of opening unseen screens found
nothing; reading the seen ones arithmetically found this, the refill rate and
the edit-wizard headline.

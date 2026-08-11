# UX conformance review — August 2026

## Result

| Gate | Result |
|---|---|
| Overflow, 320→428px × text 1.0 / 1.3 / **2.0×** | **0 across 564 combinations** |
| Touch targets below the WCAG 24pt floor | **none** (311 tappables measured) |
| Whole-project analyze | **0 errors**, 23 warnings |
| Test suite | **822 passing** (805 baseline + 17 new) |

**The app now meets WCAG 2.2 SC 1.4.4** — text resizes to 200% with no loss of
content. It was capped at 130% at the start of this work because 12 screens
overflowed at 2.0×; those are fixed, so the cap now sits at the standard rather
than below it.


Not a taste review. Every finding below is measured against published guidance,
and each carries its source. Where the app already does the right thing, that is
recorded too — an audit that only lists faults isn't calibrated.

## Method

**35 testable rules** were extracted from primary sources before the app was
looked at:

- **Apple HIG** — read via Apple's own JSON data endpoints
  (`/tutorials/data/design/human-interface-guidelines/*.json`), because the HTML
  pages are client-rendered and return only `<title>`.
- **Material Design 3** — read through a rendering proxy for the same reason.
  Several M3 numbers (type-scale sp values, FAB dp sizes, nav-bar height) exist
  **only inside images** on m3.material.io and could not be extracted; they were
  left out of the rubric rather than guessed. The commonly-quoted M3 "nav bar
  80dp" and "disabled container 12%" are **not** used here for that reason.
- **WCAG 2.2** — w3.org success criteria, quoted verbatim.
- **NN/g** — the 10 heuristics plus the empty-state, error-message,
  form-simplification, permission-request and duplicate-controls articles.
- **Peer-reviewed medication-adherence research** — JMIR/PMC systematic reviews
  and two older-adult co-design studies on adherence visualisation.
- **Google Play** health-permissions and Data-safety policy.

FTC enforcement pages returned HTTP 403; those citations are **secondary**
(law-firm analysis) and are flagged inline. If the privacy finding is acted on
commercially, verify against the FTC complaints directly.

Measurement was automated where possible:
`test/responsive/responsive_overflow_test.dart` (47 screens × 4 widths × 3 text
scales) and `test/responsive/touch_target_audit_test.dart` (311 tappables
measured at their **rendered** size, not their icon size).

---

## P0 — fixed

### 1. Health data uploaded without consent, while the UI promised otherwise

Three facts combined:

1. `AuthService.init()` created an **anonymous Firebase account on first launch**
   — no UI, no prompt (`auth_service.dart:106-131`, called from `main.dart:210`).
2. `main.dart` synced to Firestore gated only on `currentUser?.id != null`,
   which an anonymous account satisfies.
3. `firestore.rules:50-56` accepts any authenticated uid, so the writes succeeded.

Uploaded automatically for **every** user, including "guests": all medicines,
today's water, and via `HealthCloudSyncService` the last 60 days of steps, sleep
sessions and the health profile.

The codebase already contained the correct guards and did not use them —
`isAuthenticated` excludes anonymous users (`auth_service.dart:70`), and
`SyncService` already skips them (`sync_service.dart:70`).

Meanwhile: "Private · on-device · no account" (`welcome_screen.dart:376`),
"Your health data stays on your phone" (`:405`), "Guest data stays on this
device" (`auth_gate_sheet.dart:202`), and "Your data stays on your device."
(`ios/Runner/Info.plist:46` — an **App Review** string).

A **second upload path** was found during the fix: Google sign-in uploaded all
local health data (`auth_service.dart:370`). A user signing in only to use cloud
*backup* had everything uploaded.

Compounding: sign-out immediately re-signed-in anonymously, so **no UI path
reached a no-Firebase state**; there was no sync toggle anywhere; and the one
genuinely gated category (period data, `cloudSyncEnabled`, default false) had
**no UI able to set the flag**.

> The FTC has enforced this exact pattern — BetterHelp ($7.8M) and GoodRx
> ($1.5M) — treating in-flow UI claims as representations regardless of the
> privacy policy. *[secondary source: Holland & Knight analysis; ftc.gov returned 403]*

**Fixed:** a `cloudSyncEnabled` consent flag defaulting to **false** gates both
upload paths; a Cloud sync toggle in Settings; sign-out no longer manufactures
an anonymous identity; copy corrected in all four places. Pinned by
`test/core/cloud_sync_consent_test.dart`.

### 2. Two fabricated health metrics

- **`adherenceRate` returned `1.0` — "100% adherence" — when nothing was
  scheduled** (`medicine_storage_service.dart:1327`). The dashboard showed
  "100% adherence" beside "0 Medicines". A patient could have shown that to a
  clinician. *Fixed:* renders `--` / "no doses scheduled yet"; when data exists
  the label now names what it measures ("doses taken · 30 days") per the finding
  that a bare percentage is uninterpretable.
- **A hydration chart invented 70–100% progress** for any past day missing from
  the data: `progress = 0.7 + (index * 0.05); // Demo data for past days`
  (`aqua_weekly_progress.dart:118`), live on the water dashboard. *Fixed.*

### 3. Tap targets below the WCAG floor

WCAG 2.2 SC 2.5.8 requires ≥ 24×24; Apple requires a 44×44 hit region; Flutter's
own guidance says 48×48.

Measured: the "Edit" and "History" links on the water dashboard were **17pt
tall** — bare text + a 12px chevron in a `Row(mainAxisSize: min)` with no
padding. *Fixed to 44pt.* Audit now reports **nothing** below the 24pt floor
across 311 measured tappables.

Still below Apple's 44pt comfort target (not a hard failure): `period_calendar`
date cells at 41×41, several 40×40 controls, and 32pt chips on `focus`.

---

## P1 — fixed

| Defect | Rule | Location |
|---|---|---|
| Dose quantity accepted `0` and negative values (`double.tryParse` passes both) | error prevention | `nunito_add_medication_flow.dart:308` |
| Dose quantity and steps-entry fields had **no persistent label** (hint only) | WCAG 3.3.2 | `:1327`, `step_manual_entry_sheet.dart:121` |
| BP inputs never showed `mmHg` on screen | NN/g input steppers | `blood_pressure_screen.dart:543,554` |
| No date/time control on **any** vitals form — a reading could never be back-dated or corrected on edit | NN/g form design | 4 vitals screens |
| Undo missing on 3 of 4 dose paths incl. the flagship 2-tap path, and on the fast water path | NN/g H3 user control | `home_dashboard.dart:129`, `log_something_sheet.dart:124,140` |
| Snooze re-fire omitted `rescheduleOnReboot: true` (every other `oneShotAt` sets it) — a reboot during snooze silently dropped that dose | reminder reliability | `background_alarm_service.dart:145-153` |
| Bottom nav drew **two** active indicators; the non-destination orb was larger than the real selection | M3 navigation-bar | `app_nav_bar.dart:122-128,144-206` |
| "Skipped"/"Missed" **colour-swapped** between dashboard and detail — amber meant *Missed* on one and *Skipped* on the other | adherence-visualisation research | `nunito_medication_dashboard.dart:1213` vs `nunito_medication_detail_screen.dart:1278` |
| Streak forgiveness only half-adopted — `StreakEngine` used by medicine/steps, but water and focus hard-reset | behaviour-change research | `water_service.dart:812`, `focus_service.dart:804` |
| Status shown as a bare 10×10 coloured circle while `bpIcon`/`glucoseIcon` existed unused for exactly that redundancy | WCAG 1.4.1 | `blood_pressure_screen.dart:281` |
| Text capped at 130%; WCAG requires 200%. 12 screens overflowed at 2.0× | WCAG 1.4.4 | 12 screens |
| Toast durations below M3's 4s floor (success 3s, info 3.5s); `maxLines: 3` exceeded the 2-line max | M3 snackbar | `app_toast.dart:79-92,207` |

---

## What the app already gets right

Reported because the medication-app literature found most apps fail these.

- **Seven separate notification channels** (`medicine`, `water`, `period`,
  `fitness`, `health`, `reminders`, `alarm`). The single highest-consequence
  notification defect is one shared channel — muting hydration nudges would kill
  dose reminders. Not a problem here.
- **Genuine missed/skipped dose logging** — `taken`/`skipped`/`missed`/
  `snoozed`/`pending`, plus a "Why are you skipping?" reason prompt. Reviewers
  found many adherence apps cannot record a missed dose at all, which silently
  fabricates adherence.
- **Snooze in three places** and **per-medicine reminder silencing**
  (`reminderEnabled`), so a user can mute one medicine without muting all.
- **Three independent reboot-rescheduling mechanisms**, plus an app-start full
  recompute.
- **HealthKit/Health Connect permissions requested at point of use**, behind a
  state-aware rationale card, with an explicit denied-state message and a
  preserved manual-entry path. This is textbook.
- **The `persist: false` SnackBar gotcha is fully mitigated** — all 7 action
  snackbars set it, and the central toast helper forces it.
- **`TrendTimeInRangeCard`** is the best patient-facing chart in the app: band,
  numeric thresholds, per-segment percentages, and text redundancy.
- **BP entry shows a live category preview** as you type, plus a pre-measure
  checklist in the empty state.
- **Dialogs conform**: none has 3+ actions; the confirming action is trailing in
  every case; no dismissive action is disabled.

---

## Judgement calls — reported, not changed

These have no single measurable right answer. They are product decisions.

**1. "Haptic Feedback" and "Haptix" are two settings entries for one concept**,
backed by *different services*, so toggling one doesn't affect the other. NN/g
measured the cost of duplicated controls: increased interaction cost, working-
memory burden, and users clicking both expecting different results — and they
"don't know these are redundant until they have committed the time to read
both". Recommend consolidating, but which service survives is a data question.

**2. Duplicate CTA + FAB on 7 screens** — and on **5 of them the labels differ
for the same action** ("Log" vs "Log your first reading"), which is worse than
plain duplication: it reads as two different features. The in-repo precedent is
already correct — `sleep_dashboard_screen.dart:261-269` and
`steps_dashboard_screen.dart:314-325` gate the FAB off when the empty state
carries the CTA, with a comment explaining why. Which affordance survives on the
other seven is a design call.

**3. Streak is the lead metric on two dashboards** and renders **"0 day streak"**
to brand-new users. In the older-adult co-design study the calendar *without*
streaks was preferred — only 35% favoured the streak format, most finding it
distracting rather than motivating. Meanwhile `StreakEngine`'s own doc comment
says a hard reset is "demoralizing and counter-productive". Consider demoting
it, as the Today screen already does (hidden when ≤ 0).

**4. iOS gets no one-tap "Take" from notifications.** `scheduleMedicineSlotReminder`
early-returns on non-Android (`notification_service.dart:783`), so iOS users get
Snooze/Dismiss only and must open the app. Android's is the app's single best
accelerator; the parity gap is a real capability difference.

**5. The onboarding auth gate cannot be dismissed.** `AuthGateSheet.show` returns
`result ?? false`, and both the ✕ and a barrier/drag dismissal yield `false`,
which aborts `_finish()` and returns the user to onboarding. "Continue as guest"
is the only exit. NN/g names account-gating as a literal abandonment cause;
this isn't quite gating, but the only way out is a deliberate choice.

**6. Amber carries ~15 distinct meanings.** Most are individually defensible, but
`AppPalette.reminders` is **byte-identical** to `AppPalette.warning`
(`#F59E0B`, `app_palette.dart:62-63,140-141`), so an amber chip is genuinely
ambiguous between "this is a Reminder" and "this is a warning". Resolving that
means changing a feature accent — a brand decision.

**7. Dead code inventory** (verified zero external references):
`lib/core/widgets/bottom_nav/` (17 files), most of `lib/core/widgets/toast/`
(16 files, 2 external refs — including a whole `feature_toasts/` family of
purpose-built Undo helpers that were written and never wired), `WaterWeeklyChart`,
`battery_optimization_service.dart`, `RemindersCloudService`, `_QuickLogTile`,
`WaterQuickActions`, and several unused `notification_service` methods.

---

## Known limits of this review

- **320×568 is verified overflow-free but never seen.** iPhone SE 1st gen does
  not pair with iOS 26.5, so no simulator here renders 320pt. "Nothing breaks"
  is proven; "it looks good" is not.
- **47 of ~66 screens** are in the automated harness. The rest need constructor
  arguments or live data and were covered by static analysis only.
- The `flutter test` fallback font is roughly **2× wider** than the shipped
  Nunito/Inter, so the harness **over-reports** rather than under-reports.
- **Nav active/inactive icon contrast (M3 ≥ 3:1) was not measured** — the active
  icon sits on an accent orb and the inactive on the surface, so the ratio needs
  rendering, not token inspection.
- `backup` reports blank under `flutter test` because Firebase is not
  initialised there — environment-only, and labelled as such in the report.
- FTC citations are secondary (403 on ftc.gov).

## Tooling corrections made during this work

Recorded because each produced a wrong answer before it was caught:

1. A script that **counted overflow pixels** reported a perfectly clean screen as
   having 23,900 overflow pixels — it ignored BMP row padding and misread colour
   channels. Discarded; verification is visual.
2. The overflow harness was **nondeterministic** (google_fonts resolves async):
   the same command reported 18 broken screens, then 4. Pinned.
3. The harness **read the element tree after teardown**, producing spurious
   failures.
4. The harness **swallowed non-overflow exceptions**, so a *crashing* screen
   reported as "rendered, no overflow" — a false pass.
5. The harness covered only the screens registered in it; expanding 39 → 47
   immediately found 3 more broken, **including onboarding**.
6. The first consent test closed the in-memory DB in `tearDown`, but
   `CleanStorageService` is a static singleton — later writes failed silently and
   the assertions passed off a stale cache.

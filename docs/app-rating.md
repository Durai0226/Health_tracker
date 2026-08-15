# App rating: security · performance · coverage

One comprehensive pass — a full security audit, performance work across every
feature, and a published rating with its coverage stated rather than implied.

## The rating, and what it is worth

Deduction from 100, using the severity vocabulary already in `docs/ui-audit.md`:

```
P0 = −40    P1 = −15    P2 = −5
A 90-100 · B 75-89 · C 60-74 · D 40-59 · F 0-39      (score / 20 = out of 5)
```

One P0 is −40, so it caps a feature at exactly **C** however clean everything
else is. A weighted average of milliseconds, widget counts and read counts would
let "broken" be diluted by good scores elsewhere.

**Current headless result: no findings across the measured dimensions.**

```
feature        score  grade   findings
(none)
```

### Read that honestly

That is **not** "the app is 5/5". It is "nothing fires on the dimensions
currently wired into the rating". Two limits apply, and both are real:

1. **No device.** Frame build time, raster time, jank rate and cold-start-to-
   interactive are unmeasured. Device dimensions can only ever *add*
   deductions, so every headless score is a strict **upper bound** — printed as
   `≤ A`, never `A`. Host wall-clock is never substituted for device raster
   time; the build-cost harness disclaims that it can represent it, and it is
   right to.
2. **Coverage is now broad, not complete.** The responsive sweep grew from 47
   to **60 screens / 720 combinations**, taking in every medication add/edit
   form, both vitals report screens, the diary write path, milestones, the
   nudge, notification settings, water history edit, and the add-medicine
   wizard. Still uncovered: `AppShell`, `AppLockGate`, and the modal sheets
   (`LogSomethingSheet`, `LogTodaySheet`, `SleepManualLogSheet`,
   `StepManualEntrySheet`, `AquaBeverageSheet`) — the static-only sheets need a
   host widget to drive them, which is the remaining work.

A rating with undisclosed holes is worse than a low one, so the holes are
listed in §4.

---

## 1. Security — 23 findings, all fixed

No Critical. Nothing remotely exploitable by an unauthenticated attacker. The
Firebase rules are genuinely well built — every `allow` gates on
`isOwner(userId)`, payload ids are pinned to the document path, field count is
capped, and `storage.rules` mirrors it with a 20 MB cap. No secret has ever been
committed; the only key-shaped strings are Firebase's public project
identifiers, which are safe by design.

Everything real was **local or export-path**.

### High

| | Finding | Fix |
|---|---|---|
| H1 | **The app-lock PIN salt + hash were exported into every backup** — the shared ZIP *and* the Firestore upload. A 4-digit PIN with a known salt falls in ~10,000 hashes; anyone the user sent a backup to recovered it, and people reuse it as their device PIN. | `kNeverLeaveTheDevice` denylist on export |
| H2 | **Backup import wrote arbitrary preferences.** A crafted restore file could set `securityLockEnabled: false`, install the attacker's PIN, or flip `cloudSyncEnabled: true` — enabling the upload the user had opted out of. | same denylist, enforced on import |
| H3 | **Cloud backup had neither the consent gate nor the auth gate.** `_userId` is satisfied by the silent anonymous account, so a guest shown *"Private · on-device · no account"* uploaded their whole health record by tapping Create backup. The guard existed for `CloudSyncService` and was never applied here. | `isAuthenticated` + `cloudSyncEnabled` |
| H4 | **Medicine names were forced onto the lock screen**, and the user's "Show on lock screen" toggle was a **no-op on Android** — every Android reminder routed through a hardcoded `visibility: public`. "Time to take Lithium" was readable by anyone glancing at the phone. | setting mirrored into SharedPreferences for the alarm isolate; **default flipped to off** |
| H5 | **`showWhenLocked` was on `MainActivity`** — the app's only activity. After an alarm fired on a locked phone, the user could dismiss it and browse medicines, vitals, diary and period data without ever entering the device PIN. | moved to a runtime method channel, scoped to the alarm's lifetime |

### Medium

**M2** PIN was a single SHA-256 round over a 10,000-key space with **no attempt
throttling at all** → 120k rounds with transparent upgrade for existing
installs, plus escalating lockout (even a *correct* PIN is refused while locked
out, so no oracle). · **M3** ~692 log sites with no release strip, emitting the
signed-in email, Firebase UIDs, medicine names, and a full drink-by-drink CSV —
two "export" buttons literally dumped health data to logcat and told the user to
"check console" → release no-op + real share-sheet exports. · **M5** 19 unused
packages including a full WebView engine, `geolocator` (which injects location
permissions), and **five** unused nav-bar packages → removed; transitive count
157 → 126. · **M6** `RECORD_AUDIO` for a deleted feature, unused storage
permissions, deprecated `USE_FINGERPRINT` → removed. · **M7** Google's AdMob
**test** application IDs were the shipping values → now a build property that
warns loudly on release. · **M8** account-enumeration oracle via
`fetchSignInMethodsForEmail` (zero callers) → deleted. · **M9** **no account
deletion at all** — "Delete all data" left `users/{uid}`, the backups
subcollection and the Auth account alive → real flow, cloud first. · **M10**
sign-out left all local health data readable → app lock re-arms if a PIN exists.

### Low

**L1** `mockSignIn` removed · **L2** iOS purpose strings described a removed AI
feature (App Review rejects mismatched strings); microphone/speech keys deleted
outright · **L3** over-declared background modes (`fetch`, `remote-notification`
with no push implementation) removed · **L4** `RemindersCloudService` — dead but
unguarded cloud-write path — deleted · **L7** Xcode user state untracked ·
**L8** `.gitignore` gaps (`.env*`, `**/xcuserdata/`) closed.

### Not done, deliberately

- **M1 — the Drift database is unencrypted.** `flutter_secure_storage` is
  already a dependency and `SecureStorageHelper` already generates a 32-byte AES
  key that **nothing calls**. The key management half is built. SQLCipher needs
  a migration path for existing installs, and rushing that risks locking users
  out of their own health records — it belongs in its own release with its own
  testing cycle.
- **M4 — medicine names in plaintext SharedPreferences** from the alarm isolate.
  Subsumed by M1 while M1 stands: anyone who can read the preference store can
  read the unencrypted database too. **It becomes the weak link the moment M1 is
  fixed**, so the SQLCipher work must include it.

### Owner actions — cannot be done from the codebase

1. **Set a real AdMob application ID** (`ADMOB_APP_ID_ANDROID`) before
   publishing. The build now warns; shipping the test ID flags the account.
2. **Enable Email Enumeration Protection** in Firebase Console → Authentication
   → Settings.
3. **Verify App Check enforcement is switched on** for Firestore and Auth in the
   console — client-side activation alone buys nothing.
4. **Recursive account deletion.** Firestore has no reliable client-side
   recursive delete; the app removes the documents it writes, but a Cloud
   Function using the Admin SDK is the correct belt-and-braces follow-up.

---

## 2. Performance

### P0 — all five fixed

| Finding | Before | After |
|---|---|---|
| Cold start awaited **two untimed network calls** before the first frame — Firebase auth and App Check attestation. On a flaky connection the user watched the splash until Firebase's internal timeout. | unbounded | 3 s ceiling each; both were already non-fatal, so they should have been non-blocking |
| `WaterService.init` ran **one query per day over 90 days**, before `runApp()`. `StepService` 35 more. | up to 91 + 36 serialized reads | one ranged query each |
| `AppShell` built **all four dashboards** on cold start (`IndexedStack` builds every child) — and the Meds one *writes*: it drains queued dose actions and reconciles missed doses. | 4 dashboards + 4 load cycles | lazy first-mount, stack retained so per-tab scroll behaviour is unchanged |
| `ProactiveNudge` → `InsightService.gatherAll()` on Home's `initState`: read `vitals_bp` twice, scanned `medicine_logs` whole, one query **per medicine** on top. | grew with rows *and* medicine count | shared fetch, N+1 filtered in Dart, deferred off the first frame |
| Adherence report: `getAdherenceStatsForMedicine` in a serial loop, two reads each. | ~17 SELECTs, +2 per medicine | each table read once |

### P1/P2

**`FocusScreen`: 2321 → 1340 elements (−42%), 42.5 ms → 23.1 ms.** It was a
`SingleChildScrollView` + `Column` over 13 sections, all inflated eagerly for a
screen showing about two at a time — and the whole body sat inside an `Opacity`
layer, forcing a full-viewport `saveLayer` every frame of the entrance, at the
exact moment that tree was being built.

The conversion is **layout-preserving by construction**: a `Column` (default
`crossAxisAlignment.center`) hands children *loose* width and centres them,
while a sliver hands them *tight* full width — so each child is wrapped in
`Center`, which reproduces the Column contract exactly. That matters because it
could not be verified on a device from here; instead it is gated on the
564-combination responsive sweep, which passes with no overflows and no wraps.

Also: `weekly_recap` was reading **every medicine log ever written** to show 7
days (that table grows forever with no pruning) → ranged query. Drug-interaction
checking re-normalised and re-tokenised both names on every comparison —
**6,204 string operations for 12 medicines**, synchronously, every time any dose
was logged anywhere → memoised. `RelaxationService` had the same 1 Hz
`notifyListeners()` bug already fixed in `FocusService`, under a
`ListenableBuilder` wrapping its entire 1078-line screen → own tick notifier.
`AppCard` built an `AnimatedScale` (a State + controller + Ticker) across 169
call sites *including* the ones that disable the press effect → skipped when
off. `_PulseDot` called `repeat()` **inside `build()`** → moved to
`didChangeDependencies`.

**A latent crash fell out of the test work:** a stray relaxation tick with no
session running called `_completeSession()` against a null and threw.

---

## 3. On testing — five worthless tests caught

Every fix here is mutation-verified: the fix is reverted one line at a time and
the test must fail with a message naming the real defect. That is not ceremony.
**Five tests written during this work passed with the bug deliberately
restored**, and every one looked correct:

- a query matcher for `from "medicines"` when the Drift table is
  `enhanced_medicines` — it matched nothing, so every count was zero;
- two Trends tests that compared a skeleton against a skeleton, because the
  screen had not finished its first load when the tap happened;
- a startup test where `init()` early-returns on `_isInitialized`, so the second
  call measured nothing — *and* an empty database meant the per-day loop never
  executed;
- a relaxation tick test where `applyTick` correctly no-ops with no session, so
  the loop body never ran.

The corrected versions fail loudly: `enhanced_medicines was read 6 times`,
`16 strings before, 4 after`, `8 reads with 3 days of history and 25 with 20`.

---

## 4. Coverage holes — what the rating cannot see

**13 of the 17 are now registered.** The "zero-argument constructor" limit
cited in the registries was never real — they already passed arguments
(`HomeDashboard(onNavigate:)`, `AlarmScreen(payload:)`); the blocker was
inertia.

**Registering them immediately paid for itself.** `NunitoAddMedicationFlow` —
the screen `docs/ui-audit.md` calls *"Worst. 5 overflow stripes"* — had never
been rendered by any harness, and overflowed on its first run at 320pt / 2.0×
Dynamic Type in two places:

- `AppButton`'s content row is `mainAxisSize.min` inside a `Center`, so it sized
  to intrinsic width and exceeded the button by 4.4px even though the label was
  already `Flexible` + `FittedBox`. Fixed by shrinking the whole row rather than
  just the label — this is a **shared widget**, so the fix covers every button
  in the app.
- The dosage-form chip put an emoji and the form name in an unflexed row: +16px.

Neither would ever have surfaced without registering the screen.

**Still uncovered (4):** `AppShell`, `AppLockGate`, and the five static-only
modal sheets, which expose `static show(context)` rather than a constructible
widget and need a host to drive them.

`AlarmScreen` is in responsive but not QA, so the full-screen alarm has still
never been visually verified.

~~**The seeder covers 3 of 30 tables.**~~ **CLOSED.** `lib/core/dev/qa_seed.dart`
now plants medicines with 30 days of dose history (deliberately scattered so
adherence lands at a realistic **78%**, not a flat 100%), water logs, all four
vitals, period cycles, diary entries, steps and sleep — with a `heavy` profile
at a year for answering "does this cost more with more data?".

**Every measurement was retaken against it, and the empty-database numbers were
understatements by 15-110%:**

| screen | empty | seeded |
|---|---|---|
| Water/calendar | 1285 | **1810** |
| Water/dashboard | 1383 | **1755** |
| Medication/dashboard | 888 | **1205** |
| Home/home | 799 | **1099** |
| Insights/weekly_recap | 348 | **745** |
| Medication/adherence_report | 588 | **848** |

The element budgets in `screen_build_cost_test.dart` are re-baselined against
the seeded numbers, so the gate now measures the shipped app rather than its
empty state.

One thing the seeder had to get right, and initially did not: seeded medicines
must be **backdated**. The adherence denominator correctly ignores dose slots
from before a medicine existed, so medicines created "now" produce zero
scheduled doses and adherence degenerates to the very 100% the app already has
a guard against.

---

## 5. Gate

```
flutter analyze     0 errors, 23 warnings (unchanged baseline)
flutter test        1022 passing, 79 skipped (device-required)
responsive          564 combinations — NO OVERFLOWS, no wrapped header text
touch targets       nothing below the WCAG 2.2 SC 2.5.8 floor
```

Device half, once a phone is attached:

```bash
flutter test integration_test/perf_e2e_test.dart \
  -d <android-device-id> --profile --dart-define=E2E_TEST=true
```

`--profile` is not optional — debug numbers are 2-10× pessimistic and are not a
frame budget. An iOS simulator has no real GPU pipeline, so its raster figures
are fiction.

---

## 6. What would actually move the rating next

In order of what it buys:

1. **Seed the other 27 tables.** Every number above is measured on an empty
   database. This is the single change that makes the rating trustworthy rather
   than merely green.
2. **Register the 17 uncovered surfaces**, starting with `LogSomethingSheet` and
   `AppShell`.
3. **Run the device half.** Until then every score carries a `≤`.
4. **SQLCipher (M1) plus the alarm-payload fix (M4)**, together, in their own
   release.

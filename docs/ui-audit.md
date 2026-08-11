# UI/UX audit — iOS simulator, August 2026

Every reachable screen was driven on a booted iPhone 17 Pro simulator via the
`lib/main_qa.dart` harness and reviewed as a user would see it: **66 screens,
74 screenshots** (60 light + 14 dark), reviewed by three independent passes.

The headline is not a list of 200 small defects. It is that **the app ships two
generations of UI**, and the seam is visible to users — most damagingly in dark
mode, where six screens were effectively unusable.

---

## Fixed in this pass

| Fix | Blast radius |
|---|---|
| Six dark-mode screens migrated off the light-only `AppColors` consts | 6 screens, all P0 |
| White back-button chip made theme-aware | 5 screens |
| `AppHeader` title shrinks to fit instead of truncating | every screen with a header |
| `vitavibe_settings_screen` rebuilt on the modern kit | 1 screen, P0 |
| `focus_reminders_settings_screen` rebuilt; now auto-saves | 1 screen, P0 |
| `caffeine_insights_screen` rebuilt on the modern kit | 1 screen |
| `aqua_water_dashboard` title moved clear of the back button | 1 screen, P0 |
| `early_access` status-bar glyphs fixed in both themes | 1 screen |
| `common_tab_widgets` unselected tab label made theme-aware | tabbed screens |
| Legacy `common_widgets.dart` kit deleted (last consumer migrated) | codebase |
| 41 dead files removed, incl. 3 stray `.bak` files under `lib/` | codebase |
| Tag chips lightened for dark mode (Meditation was 2.65:1) | focus tags |
| `plant_trees` "can't afford" branch un-hardcoded from `Colors.grey` | 1 screen |

Still open: everything under **P1** and **P2** below, plus the `sleep` FAB
colour clash, `app_allow_list`'s FAB clearance, and the half-width cards on
`adherence` / `hydration_profile` / `water_calendar`.

---

## Severity key

| | Meaning |
|---|---|
| **P0** | Broken — unreadable, overlapping, or non-functional |
| **P1** | Clearly inconsistent or poor UX |
| **P2** | Polish |

---

## P0 — broken

### Dark mode: six screens rendered white-on-white

The single worst finding. These screens render a `#FFFFFF` card while their
text follows the *dark* theme's `onSurface` (`#F2F4F7`) — measured contrast
**≈1.05:1**. Titles were not "hard to read"; they were invisible.

| Screen | What disappeared |
|---|---|
| `relaxation_screen` | Every goal-card and music-card title; all duration chips |
| `app_allow_list_screen` | All four setting titles, the selected "10s" value, both preset chips, the empty state. Dividers inverted to near-black on white |
| `plant_real_trees_screen` | Two of three tab labels; shop grid rendered as white slabs |
| `custom_tags_screen` | Empty-state card; "Meditation" chip at ~2:1 |
| `focus_garden_screen` | The **only** navigation control on the screen |
| `early_access_screen` | Did not respond to the theme *at all* — the entire light build, with dark toggles reading as black blobs |

**One root cause, not six bugs.** `lib/core/constants/app_colors.dart` exposes
light-only `static const` values (`cardBg`, `textPrimary`, `background`)
*alongside* theme-aware `getCardBg(context)` getters. These screens — and only
these screens — used the consts. They were also the last six files importing
that legacy file.

A related variant: a **white back-button chip whose arrow follows the theme**,
so the control vanishes in dark mode (5 screens).

**Status: fixed and verified on-device.** All six migrated to the theme-aware
getters. A follow-up pass measured actual pixel contrast on the rebuilt
screens: card surface `#171B22` on page `#0F1319`, primary text `#F2F4F7`
(**15.7:1**), secondary `#A5AEBC` (7.7:1), dividers a subtle `#2B323C` — no
white slabs and no harsh rules anywhere.

Two screens needed a second fix from a *different* root cause — hardcoded
Material palette constants bypassing the theme entirely:

- `custom_tag.dart` stored raw tag hues used directly as foreground. Meditation
  (`#795548`) measured **2.65:1** and Reading (`#9C27B0`) **2.80:1** against the
  dark chip. Fixed at the render layer (lighten for dark mode) rather than by
  rewriting user-chosen, persisted colour data.
- `plant_real_trees_screen.dart` used `canAfford ? themed : Colors.grey`. With
  zero coins *every* card took the grey branch, so titles and body text became
  the same flat `#9E9E9E` and all type hierarchy was lost — and at ~2.8:1 it
  was a latent **light-mode** bug too.

### `vitavibe_settings_screen` — unreadable in dark, black-on-teal in light

Every primary row label ("Intensity", "Medicine Taken", "Water Added", "Focus
Start") was hardcoded `Color(0xFF2D3142)` — near-black on the dark background.
Only subtitles survived. In light mode the AppBar title rendered black on the
teal bar, because the `Text` set `fontWeight` but no `color` and so never
inherited `foregroundColor: Colors.white`.

**Status: rebuilt** on `AppScaffold` + `SettingsSection`/`SettingsTile`.

### `focus_reminders_settings_screen` — permanently light

`backgroundColor: Color(0xFFF5F5F5)` and `Colors.white` cards regardless of
theme: a blinding white sheet in dark mode.

**Status: rebuilt.** Settings now persist on change rather than requiring an
explicit Save that silently discarded edits when the user backed out.

### Header titles truncated by their own action buttons

`AppHeader` ellipsized at `maxLines: 1`. With a back button, an icon badge and
2–3 actions, under 100pt remained for the title:

- "Weight" → **"Wei…"**
- "Blood sugar" → **"Blood s…"**
- "Family & caregivers" → **"Family & careg…"**

**Status: fixed** app-wide — the title now shrinks to fit instead of truncating.

### `aqua_water_dashboard` — back button drawn over the title

`SliverAppBar.leading` paints *on top of* `flexibleSpace`, and the title sat at
x=20 underneath it. The header read **"ydration"**.

**Status: fixed** — title row moved clear of the toolbar.

### FABs overlapping content

Partly a false positive, corrected after reading the code: `sleep_dashboard`
and `sleep_history` **already** reserve 96–100px of bottom padding, so a FAB
floating over mid-list content there is normal Material behaviour, not a
layout bug.

What is a real defect:

- `sleep` — the "Log sleep" FAB is the *same purple as the timeline chart it
  floats over*, so it reads as part of the graphic rather than as a button.
- `app_allow_list` — the "Add App" FAB sits on top of the empty-state copy,
  which has no FAB clearance at all.

**Status: not yet fixed.**

### `adherence` — Overview card at ~60% width

The Overview card ends at x≈553 of 870 while the cards below it are full
width, leaving a large gutter that reads as a layout bug. `hydration_profile`
and `water_calendar` have the same half-width-card defect.

**Status: not yet fixed.**

> **Not a bug:** `backup_cloud` renders a red `[core/no-app] No Firebase App`
> screen *in the QA harness only* — `main_qa.dart` does not call
> `Firebase.initializeApp()`. The shipping entrypoint does.

---

## Accessibility text sizes — the app does not survive them

Ten screens were re-driven at iOS Dynamic Type **accessibility-extra-large**.
**7 of 10 broke** with visible Flutter overflow stripes or unreadable text.
Only `settings` and `reminders_hub` held up cleanly; `weight` had a truncated
CTA only.

| Screen | Failure |
|---|---|
| `add_med` | **Worst.** 5 overflow stripes (60px right on the step indicator, 4× 24px under the frequency chips, 21px + 337px on the reminder row). Step labels collide into "InfoDosageScheduleLoo…M"; submit button truncates to "Add M…" |
| `medicine` | 87px right overflow eats the adherence stat; **seven** overflowing weekday chips, every date digit sliced off |
| `focus` | Timer ring overflows 85px; "25:00" wraps mid-number to "25:0 / 0"; coins chip clipped to "coi-ns" |
| `caffeine` | Ring overflows 71px; "of 400 mg" escapes the circle onto the card |
| `water` | Header overflows 64px; "+250" wraps to "+25 / 0" with the unit pushed out |
| `home` | Glance card overflows 24px; CTA truncates to "+ Log so…" |
| `vitavibe` | Feature-pattern rows squeezed the title column to **one character per line** |

### Fixed

Two halves, because a clamp alone would just hide the problem:

**1. A global clamp** in `lib/main.dart` (mirrored in `main_qa.dart` so QA
screenshots reflect what ships):

```dart
textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)
```

**Why 1.3 and not higher.** 1.3× covers essentially the whole *standard*
Dynamic Type range (iOS's largest non-accessibility size is ~1.35×) and cuts
only the five AX sizes (1.6×–3.1×). A higher ceiling is tempting now that the
widgets are resilient — but only **10 of ~66 screens** were verified at large
text. Raising it would expose the other ~56 untested screens. 1.3 is a
deliberately conservative ceiling; raise it as more screens get verified.

**2. The widgets made genuinely resilient**, so the clamp is not load-bearing:

| Root cause | Fix | Reach |
|---|---|---|
| Chip label unconstrained in a bounded `Row` | `Flexible` + ellipsis in `AppChip` | every chip in the app |
| Button label ellipsized to "Add M…" / "+ Log so…" | `FittedBox(scaleDown)` in `AppButton` | every button |
| Trailing value starved the title | flex priority in `SettingsTile` | every settings row |
| Text in a fixed-size circle | `FittedBox(scaleDown)` + `maxLines: 1` | focus/plant ring, vitals rings |
| Clock wrapping mid-number ("25:0 / 0") | `FittedBox(scaleDown)`, `softWrap: false` | focus timer |
| `Container(height: 68)` clipping a 2-line chip | `BoxConstraints(minHeight: 68)` | add-med frequency chips |
| Label/value/chevron collision | `Expanded(flex: 3)` / `Expanded(flex: 2)` | add-med reminder rows |
| 5 step labels in a gapless `spaceBetween` row | `LayoutBuilder` + `TextPainter` measures at the reader's actual scale; falls back to "Step N of 5 · Dosage" **only** when they truly don't fit | add-med stepper |

Two properties held throughout: **no font size was reduced** to dodge the
problem, and `FittedBox(scaleDown)` never enlarges — so default-size rendering
is byte-identical to before.

The highest-leverage fix was in `ProgressRing`, which never fit its centre
content at all. Every ring in the app — caffeine, home glance, vitals, water —
inherits the fix from that one change.

### Verified on-device

Re-shot at accessibility text size after the fixes. Previously-broken screens,
now confirmed by eye:

| Screen | Before | After |
|---|---|---|
| `focus` | ring +85px, "Seed" → "See / d", "25:00" → "25:0 / 0", chip → "0 coi" | all clean, single lines |
| `add_med` | 5 stripes; "Add M…"; label/value collision | all 5 gone; full "Add Medication"; proper separation |
| `medicine` | +87px right, 7 date-chip stripes | streak card intact, all 6 chips render |
| `water` | header +64px, "+250" → "+25 / 0" | header clean, tiles on one line |

> **Method note, honestly recorded:** I first wrote a script to *count* Flutter's
> yellow overflow hatch programmatically, on the theory it beats eyeballing. It
> reported 8 of 10 screens still broken — including `medicine` at 23,900
> "overflow" pixels, which visual inspection showed was **completely clean**.
> The script ignored BMP row padding, so it misaligned the colour channels and
> read garbage. It was deleted. The verification above is visual.

---

## Responsive support across phone sizes

The app assumed ~393×852. It now supports **320×568 → 428×926**, verified by an
automated harness rather than by sampling screens.

### The harness

`test/responsive/responsive_overflow_test.dart` — **47 screens × 4 phone sizes ×
2 text scales = 376 combinations** per run. It stays in the repo, so this class
of bug cannot silently return.

```
combinations rendered: 376
NO OVERFLOWS across all devices and text scales.
```

It reports three distinct failure classes, because the obvious one is not the
only one:

| Class | Why it matters |
|---|---|
| RenderFlex overflow | the visible yellow/black stripe |
| **Rendered blank** | a blank screen never overflows, so an overflow-only check passes it |
| **Build error** | a screen that *crashes* would otherwise report "rendered, no overflow" — a false pass |

### What was broken

**21 screens.** Worst: `water_calendar` 709px bottom, `plant_trees` 250px right,
`water_awards` 232px right. **Nine overflowed at DEFAULT text size**, some on a
428pt Pro Max — users were hitting these.

A static sweep of `lib/` ran as an independent check and inventoried **173
hazards**. Both methods agreed on the key point: **the dominant risk is
horizontal**, unflexed `Row`s on narrow screens — not text scaling.

### Highest-leverage fixes

Most were shared widgets, so one change fixed many screens:

| Widget | Defect |
|---|---|
| `ProgressRing` | never fit its centre content at all — every ring in the app |
| `segmented_toggle` | label unflexed inside its 1/n slice — every segmented control |
| `AppHeader` | title starved to near-zero at 320pt; now drops the decorative badge instead |
| `AppButton` | label ellipsized to "Add M…"; now shrinks |
| `AquaSectionHeader` | title unflexed — whole water dashboard |
| `AppBarTheme` | no `systemOverlayStyle`, so status-bar glyphs were derived from a `Colors.transparent` AppBar (luminance 0 → read as dark → **white glyphs on a light scaffold**) |

Individually notable:

- **`welcome`** — onboarding, the first screen a new user sees, overflowed
  **179px at default text**. A 31-character trust pill in an unflexed `Row`.
- **`water_calendar`'s 709px** was a *consequence* of a horizontal overflow: a
  squeezed column wrapped at one character per line, inflating an 80px header to
  410px inside an 82px box.
- **`alarm`** put the *user-typed* medicine name unflexed in a fixed-width
  button, so a long name broke the Snooze/Dismiss controls.
- **`Container(height: 68)`** hard-capped a two-line chip → `minHeight`.
- A horizontal `ListView`'s fixed viewport forced a tight height on all seven
  weekday chips — one cause, seven stripes.

### Limits of this verification, stated plainly

- **320×568 is verified logically, not visually.** iPhone SE 1st gen cannot pair
  with iOS 26.5, so no simulator here renders 320pt. Zero overflows is proven;
  "looks good" at that width is not.
- **47 of ~66 screens** are in the harness. The rest need constructor arguments
  or live data, and got the static sweep only.
- The test font is roughly **2× wider** than the shipped Nunito/Inter, so the
  harness over-reports rather than under-reports. Errs safe.
- `backup` reports blank under `flutter test` because Firebase is not
  initialised there — environment-only, and now labelled as such in the report.

### Tooling corrections worth recording

The harness was wrong four times before it was trustworthy. Each mattered:

1. **Nondeterministic** — `google_fonts` resolves asynchronously; the same
   command reported 18 broken screens, then 4. Pinned `allowRuntimeFetching`.
2. **Read the element tree after teardown** — spurious failures unrelated to the
   app.
3. **Too narrow** — the first "clean" run covered only the 39 screens
   registered. Expanding to 47 immediately found 3 more broken, including
   onboarding.
4. **Swallowed non-overflow exceptions** — a crashing screen looked clean.

A separate earlier attempt to count overflow pixels programmatically was
discarded outright: it ignored BMP row padding, misread colour channels, and
reported a perfectly clean screen as having 23,900 overflow pixels.

---

## Small phone (iPhone SE, 375×667pt)

**Nothing breaks.** No overflow stripes anywhere — verified by programmatically
scanning every pixel for Flutter's yellow hatch, not just by eye. The failure
mode is uniformly "graceful degradation that got tight". 4 of 10 held up
cleanly (`settings`, `vitavibe`, `add_med`, `focus`).

What hurts:

- **`water`** — the Quick Add amount cards, the screen's *primary* action, sit
  below the fold with only their top third visible. The ring plus ~140pt of
  dead space above it eat two-thirds of the shorter viewport, so you must
  scroll before you can log any water.
- **`medicine`** — the FAB butts into the end of "No medications scheduled",
  and the line below it ("Tap + to add your first medication") is sliced in
  half by the screen bottom.
- **`weight`** — the title auto-shrinks to about half the type size used
  elsewhere. That is the new `AppHeader` shrink-to-fit doing its job, but it
  reveals the real problem: back arrow + icon + title + kg pill + export +
  alarm is one control too many for 375pt.
- **`caffeine`** — "Hydration offset" ellipsizes in the 3-up stat row.
- **`reminders_hub`** — wrapped subtitles come within ~8pt of the trailing
  "Off" value.

## iPad — not adapted

No overflow, no clipping, everything tappable — but unmistakably a phone
layout inflated to tablet width, because **nothing in the settings/detail
surfaces applies a max-width clamp**.

- `settings` — "Haptic Feedback" has its label at the far left and its toggle
  at the far right with **~536pt of blank white between them**. The theme
  segmented control stretches to ~750pt for three options.
- `vitavibe` — the "Navigation" row puts ~594pt (**71% of screen width**)
  between the label and its value. The 4-stop intensity slider stretches to a
  ~714pt track, reading as a continuous fader it isn't.

**Recommended fix (not applied):** clamp content width centrally — wrap the
scroll body in `Center(child: ConstrainedBox(constraints: BoxConstraints(
maxWidth: 640)))` inside `AppScaffold`, so every screen inherits it. This also
improves large phones in landscape. Not shipped here because iOS-simulator
verification was no longer available once ML Kit was restored, and shipping an
unverified layout change is how the water-header overflow got introduced
earlier in this same pass.

> **Capture caveat, honestly noted:** `small/home`, `ipad/home` and
> `ipad/medicine` are unusable captures — the two iPad files are byte-identical
> (same MD5), i.e. a stale frame grabbed twice, and `small/home.png` is 29KB of
> blank white. A 5s settle is not enough for first launch on a freshly-booted
> simulator. Those three screens are **not** covered on those form factors.

---

## P1 — systemic inconsistency

These recur across many screens; each is one decision, not one screen's bug.

**Duplicate primary CTA (7 screens).** `doctors`, `appointments`, `bp`,
`glucose`, `weight`, `diary`, `mood` each show a full-width action button *and*
an extended FAB for the same action — sometimes with different labels ("Write
your first entry" vs "New entry"; "Log how you feel" vs "Log").

**No accent system.** Indigo (medications), burnt orange (categories, mood,
reminders), crimson (BP), violet (glucose), teal (weight, diary, trends, focus
sub-screens), purple (focus), cyan (water), bright blue (weekly-recap values).
Back arrows alone appear in purple, black, teal and orange. Focus is purple but
its own sub-screens are teal.

**Four competing header patterns.** Flat title only · eyebrow + title + icon
chip · back arrow + icon chip + title · chunky solid-colour app bar
(`water_awards`). Left insets vary between x≈48, 64, 96 and 165, so no two
headers align — and the title rarely shares the card grid's left edge.

**Four empty-state treatments.** Icon-in-circle + centred + CTA · icon-in-circle
with no CTA · bare filled glyph, top-anchored, ~1100px of dead space · nothing
at all (`dependents` renders a completely blank body). Several charts reserve
~450px of white space around one line of grey text.

**Emoji used as product iconography (7+ screens).** `water`, `water_awards`,
`custom_cup`, `focus_stats`, `focus_tags`, `focus_apps`, `plant_trees`,
`relaxation`. The rest of the app is on Material Symbols; these won't tint,
scale or theme. `custom_cup` additionally offers 🏃 🧴 🥝 and four alcohol
emoji in a hydration tracker.

**Contradictory data.** `focus` header says "1 day streak" while its own
Statistics screen says "0 Day Streak". `medicine` shows "100% adherence" beside
"0/0 Taken" and "0 Medicines". `weekly_recap` shows two "no data yet" banners
directly above real populated data. `sleep_history` labels a night "Estimated"
that the Sleep hub calls "From your log".

**Wrong product name.** Copy says "DailyMinder"; the shipped app is
**Dlyminder** (`CFBundleDisplayName`, `android:label`). Appears on Settings,
Notifications and App lock.

**Truncation at default text size** — before any accessibility scaling:
`home` summary ("Your water is a little behi…"), `relaxation` goal cards,
`plant_trees` descriptions, `focus_apps` presets row, `water` cups row ("300r").

---

## P2 — polish

- Capitalisation drift: "Add Doctor"/"Add Clinic" vs "Add appointment"/"Add
  medicine"; "Today's Schedule" vs "Care team"; "Day Streak" vs "day streak".
- Terminology: "Medication" / "Medicine" / "Medicines" inside one feature;
  "Period" / "Cycle" with three different icons for one tracker.
- Units: "Km"/"Kcal" vs "km"/"kcal"; "0.0L" vs "0ml" in adjacent tiles;
  "2500 ml" vs "2500ml"; "5260 to go" missing a thousands separator.
- Label triplication: "App lock" ×3 on `security`, "Haptic feedback" ×3 on
  `haptics`, "Create backup" ×3 on `backup_local`.
- One icon, several meanings: flame = goal progress, calories *and* streak on
  one screen; lotus = Wind-down *and* PMS; the same chart glyph for Trends and
  Weekly recap.
- Bare em dashes ("—") used as values where an empty state belongs.
- `welcome` claims "Private · on-device · no account", which contradicts the
  app's Firebase Auth / Firestore sync.
- **Two settings entries configure the same thing:** "Haptic Feedback" →
  `HapticSettingsScreen` and "Haptix" → `VitaVibeSettingsScreen` have the same
  sections and the same six feature rows, but are backed by *different
  services*, so toggling one does not affect the other. Worth a product
  decision on whether both should exist.

---

## Method

- Harness: `lib/main_qa.dart`, ~66 registered screens, seeded data, screen and
  theme switched by rewriting `Documents/qa_config.txt` in the app container —
  no rebuild between screens.
- Driver: `xcrun simctl` (`launch --terminate-running-process`, `ui appearance`,
  `io screenshot`). Screenshots must be captured in the **foreground**; in a
  background shell `simctl io` silently writes nothing.
- Not exercisable on a simulator, so reviewed structurally only: HealthKit /
  Health Connect reads, real notifications and alarms, camera OCR.

### Coverage actually achieved

| Config | Screens | Notes |
|---|---|---|
| iPhone 17 Pro, light | 60 | full baseline |
| iPhone 17 Pro, dark | 14 | targeted at the legacy screens |
| accessibility-extra-large text | 10 | `simctl ui content_size` |
| iPhone SE (small) | 10 | fresh simulator, app installed directly |
| iPad Pro 11" | 5 | cut short by disk exhaustion |

Two environment traps worth recording:

- **Disk exhaustion.** Creating extra simulators alongside a Gradle re-download
  filled the volume, which killed the Android build, truncated the iPad sweep
  and stalled a review agent. Symptoms are cryptic. Clear `build/ios` and
  `~/Library/Developer/Xcode/DerivedData`, and delete throwaway simulators
  (`xcrun simctl delete <udid>`) when done.
- **Pre-existing simulators can be un-bootable** ("cannot be located on disk")
  while still being listed. `xcrun simctl create` a fresh one instead of
  fighting it.

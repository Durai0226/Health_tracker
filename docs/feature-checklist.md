# Feature checklist

Everything from the **App Feature Map** artifact in one place, in the order it is being worked on.
Tick a box when the item is built **and** its tests pass. An unticked item with an italic note is
partly built or waiting on something.

_Generated from the artifact's own data, so the wording matches it. Status last updated 26 Oct 2026._

## Progress

| Part | Done | Total |
| --- | ---: | ---: |
| 1. Smart features to add | 25 | 86 |
| 2. Gaps in existing features | 29 | 146 |
| 3. Not implemented yet | 1 | 38 |
| **Everything** | **55** | **270** (20%) |

Work order: Part 1 top to bottom (quick wins first), then Part 2 by area. Part 3 is larger work and
is not scheduled. Release steps live in `docs/release-checklist.md`.

---

## Part 1 — Smart features to add

### Quick wins — Now priority, small effort (17/17)

- [x] **Nudges that open the fix** · Today & quick access · effort S — _Today nudge opens the screen that fixes it. Not built: pre-filling the fix (e.g. a pre-selected refill)._
  - Tapping an alert opens the screen that fixes it, with the fix filled in.
- [x] **Setup checklist** · Today & quick access · effort S — _7 live checks: notifications, exact alarms, battery, Health Connect, home-screen widget (Android only), emergency contact, backup within 30 days._
  - “3 of 6 set up” on Today until everything that makes reminders reliable is on.
- [x] **Long-press shortcuts** · Today & quick access · effort S — _Water, BP, focus + next-dose slot. Not built: ranking the rest by what you log most._
  - Log water, Log BP, Start focus, plus “Take Metformin 8:00” when a dose is due.
- [x] **Measurement plan from medicines** · Medicines · effort S — _Offered after saving a new BP / diabetes / water pill. Drug lists need clinical review._
  - Adding a BP, diabetes or water pill offers the matching check routine.
- [x] **Two-reading BP sessions** · Vitals · effort S — _Session average drives every number; raw readings stay in History; crisis card still follows the latest raw reading. Responsive harness run pending (batched)._
  - After a reading, a 60-second countdown offers a second one; the average drives every number.
- [x] **Activity-aware goal** · Water · effort S — _Measured active energy raises today's goal (never lowers it); line under the gauge says why. Custom goal and fluid limit untouched._
  - On active days the goal rises and says why: “+350 ml for 420 active kcal”.
- [x] **Weekday-aware goal** · Steps · effort S — _Weekday-aware goal built (blend of same-weekday and 14-day medians) and shown in the goal explanation. Not built: the Monday "Keep or try?" prompt._
  - Saturday's goal fits your Saturdays; on Monday, “Keep 8,200 or try 8,600?”.
- [x] **Heart trends with your usual range** · Sleep & heart · effort S — _30-day charts for resting HR, HRV, blood oxygen and breathing rate with a band from your own previous days (needs 7)._
  - 30-day charts for resting HR, HRV, breathing and SpO₂ with a shaded normal band.
- [x] **HRV status** · Sleep & heart · effort S — _7-day average against the range of the 21 days before it; one HRV metric only._
  - “HRV within your usual range (7-day avg 42 ms; usual 38–51).”
- [x] **Weighted sleep debt** · Sleep & heart · effort S — _14 nights, recent weigh more, a lie-in pays back at most an hour, with a catch-up plan. Credit side still uses the plain figure._
  - “4 h 20 m behind over 14 nights — 25 extra minutes a night for a week clears it.”
- [x] **Adaptive focus nudge** · Focus · effort S — _One nudge 10 min before your best hour, on days you usually focus, quiet once you have; re-planned after every session. "Best hour" switch in Focus reminders._
  - “Time to focus” moves to your best hour and stays quiet once you've focused.
- [x] **Another round?** · Focus · effort S — _The completion toast carries an "Another round" button that restarts the same session._
  - The completion screen restarts the same session in one tap.
- [x] **Pause, end date, vacation** · Reminders · effort S — _Ends (never / on a date / after N times) and Pause (optionally until a date) in the reminder form; Vacation mode pauses reminders and freezes water, steps, focus and reminder streaks. Medicines untouched. A paused-until reminder returns the first time the app opens on or after its day._
  - “Pause until…”, “Ends after N times”, and a vacation mode that freezes streaks.
- [x] **Reminder tune-up** · Reminders · effort S — _One suggestion at a time on a repeating reminder's card: move it (usually done at…, with snoozes if recorded), make it louder, or pause it; dismissals last 30 days. Snoozes were not recorded anywhere before — they are now (new snooze log, written from all three snooze paths), so the "snoozed N of last 6" wording only appears once snoozes have been logged._
  - “Snoozed 4 of last 6 · usually done around 21:40 — Move it.”
- [x] **Swipe to finish** · Reminders · effort S — _Right = done, left = Later (one-offs: this evening, or tomorrow 9:30, with Undo). Delete moved to the card menu with an Undo that restores the history and the alarm. Repeating reminders are not offered Later._
  - Swipe right for Done, left for Later; delete moves to the menu with Undo.
- [x] **Spotting doesn't start a period** · Period & cycle · effort S — _A period starts at light flow or more (a spotting tail stays part of it). Logging a light day under 18 days after the last start asks: start a new period, or log as spotting._
  - One spotting day no longer creates a fake cycle.
- [x] **One mood, logged once** · Mood & diary · effort S — _The period sheet prefills from the day's mood-log entry and writes a changed mood back to it, translating between the two opposite scales; the later write wins._
  - The mood tapped in the period sheet becomes the day's mood everywhere.

### Now — high value, medium effort (8/30)

- [x] **Patterns on Trends** · Today & quick access · effort S–M — _A Patterns section under the Trends summary shows the 8 cross-day insights, grouped Needs attention / Patterns / Wins, each with Why this? and Not useful (hidden 30 days). Renders nothing when empty._
  - A Patterns section shows the 8 insights the app already works out but never shows.
- [ ] **Today in the right order** · Today & quick access · effort M
  - The card you need now moves to the top; your own order stays underneath.
- [ ] **Morning brief & evening wrap-up** · Today & quick access · effort M
  - Two quiet, opt-in notifications: last night and today's doses in the morning; what's left, with Take buttons, before bed.
- [ ] **Setup that fills the app** · Today & quick access · effort M
  - Pick 1–3 goals and connect Health Connect; Today and Trends have data on day one.
- [ ] **Next-dose widget** · Today & quick access · effort M · Android · iOS 17+
  - “Metformin · 8:00 [Take]” on the home screen, and on the lock screen on Android 16.
- [x] **Critical-medicine alerts** · Medicines · effort S–M — _"Must-take" switch on the medicine form: rings at the time, then again at +15 and +30 min until taken or skipped (Android; not with weekend times or every-X-hours schedules). The flag was never saved before — schema v21 adds it. Not built: ordinary medicines still ring as before rather than as a calm check-in._
  - Must-take medicines ring like an alarm and follow up; the rest arrive as a calm check-in.
- [x] **Late dose recovery** · Medicines · effort S–M — _A missed dose can be tapped: Take now / Took it at the scheduled time / Took it at another time / Skip it, with Undo back to missed. Next morning a banner lists yesterday's unlogged doses to tidy in one sheet. In-app only — not on the notification (it runs in a background isolate)._
  - Missed doses get “Took it at…” and “Take now”; the next morning, one tap tidies yesterday.
- [x] **Refill loop with your pharmacy** · Medicines · effort S–M — _Tapping the run-out reminder opens a sheet: call / message / email the saved pharmacy (message pre-filled), "I've asked for it" (arms a "Picked up?" follow-up two days later) and "Picked up" (adds stock; adding stock by any route ends the loop). Refill overview rows show "Asked <date>". Not built: the two choices as buttons on the notification itself._
  - The run-out reminder offers “Request refill” and “Picked up”.
- [ ] **Auto-import BP and glucose** · Vitals · effort M
  - Readings from an Omron, Withings or Qardio cuff or a meter app appear by themselves.
- [x] **Trend weight & goal date** · Vitals · effort S–M — _Weight screen: smoothed trend weight, weekly rate (needs 4 weighed days over a fortnight; read from a line through the raw daily weights), a goal weight you set, and "70.0 kg around Dec 14" only when the trend is heading there at a measurable pace — otherwise it says why (reached / flat / moving away / too far / not enough data). Trend line drawn beside the raw weights._
  - A smoothed trend weight, a weekly rate and “72 kg around 14 Dec”.
- [ ] **Glucose follow-ups & meal patterns** · Vitals · effort M
  - A low schedules a 15-minute recheck; patterns name the meal or hour.
- [ ] **Pace-aware reminders** · Water · effort M — _PARTLY EXISTING, not built: reminders were already pruned to the remaining need and thinned when ahead of pace (ReminderRescheduleService.pruneToRemainingNeed). Not built: "~400 ml behind — your usual mug puts you back on pace" wording, which needs today-specific text on repeating reminders and would mean re-registering every slot per drink._
  - “~400 ml behind — your usual mug puts you back on pace”; quiet when you're ahead.
- [x] **Your usual, one tap** · Water · effort S–M — _Water screen: a "Your usual · Coffee · 200 ml" tile above Quick Add logs the drink you habitually have within 90 min of now (same drink and size on 3+ separate days and ≥40% of the days you drank then; never alcohol; today excluded). Tile only — not the notification action or the home-screen widget (they run outside the app)._
  - The notification, widget and first tile log what you usually drink at this hour.
- [x] **Goal-aware step reminder** · Steps · effort S–M — _Goal met → no reminder today (the repeating one starts tomorrow). Short of it with numbers fresh at fire time (≤90 min old) → "1,800 steps to go — about 18 minutes of walking". Older numbers → a generic line with no figure; no step data → exactly the old reminder. Limit: if you reach the goal while the app is closed, that day's reminder still fires (it cannot read steps at fire time)._
  - “1,800 to go ≈ 18-minute walk”; silent once the goal is met.
- [x] **Rest & sick days** · Steps · effort S–M — _Steps screen card: mark today Rest day or Unwell (Undo anytime). The steps streak holds, the goal is paused, the evening reminder stays quiet, and marked days are left out of what the adaptive goal is learned from. One day, steps only — separate from vacation mode. Not shown on the Home steps summary._
  - Mark today Rest or Unwell: the goal pauses and the streak holds.
- [ ] **Overnight body check** · Sleep & heart · effort M
  - “2 of 5 overnight signals are outside your usual range.”
- [ ] **What moves your sleep** · Sleep & heart · effort M
  - “On nights with caffeine after 2 pm you slept 38 min less (9 vs 21 nights).”
- [ ] **Morning report** · Sleep & heart · effort M
  - One Today card: last night against your usual, debt, body check and one suggestion.
- [ ] **Smart start & Focus tile** · Focus · effort S–M · Tile: Android
  - Setup pre-fills what you usually do at this hour; a Quick Settings tile starts it.
- [ ] **Focus Guard** · Focus · effort M · Android
  - The phone goes quiet during a session and comes back for breaks.
- [ ] **Done and “Later” on every alert** · Reminders · effort S–M
  - Done · Snooze 10 m · Later (this evening or tomorrow 9:30).
- [ ] **Overdue triage** · Reminders · effort S–M
  - Move all to today · Tomorrow morning · Skip all.
- [ ] **Sleep-aware quiet hours** · Reminders · effort M
  - Non-urgent reminders due during sleep or focus arrive afterwards as one summary.
- [ ] **Cycle pattern check** · Period & cycle · effort S–M
  - “Your last 6 cycles varied by 12 days — worth mentioning at a check-up”, plus a PDF.
- [ ] **Honest, adjustable predictions** · Period & cycle · effort S–M
  - “Oct 12–16, most likely the 14th · based on 7 cycles.”
- [ ] **Your PMS pattern** · Period & cycle · effort M
  - “Cramps and low mood usually start 3 days before (4 of 5 cycles).”
- [ ] **Cycle privacy pack** · Period & cycle · effort M
  - One screen to keep cycle data private.
- [ ] **Mood tags, mostly automatic** · Mood & diary · effort M
  - Tap icons like walk or friends; sleep, steps, doses and cycle phase are tagged for you.
- [ ] **What goes with better days** · Mood & diary · effort M
  - “Mood tends to be better on days with a walk (+0.8 · 14 vs 11 days).”
- [ ] **Diary that resurfaces** · Mood & diary · effort M
  - Mood, tags, an editable date, search, and “On this day”.

### Next — second wave (0/33)

- [ ] **How strong is this pattern** · Today & quick access · effort S
  - Each pattern says “Based on 9 vs 7 days · Moderate”.
- [ ] **Care circle** · Today & quick access · effort S–M
  - After a missed dose, “Let Priya know?” opens a text without the medicine name. A weekly PDF you can send.
- [ ] **Emergency card** · Today & quick access · effort S–M
  - A lock-screen-ready card with allergies, conditions, medicines and emergency contact.
- [ ] **Live dose window** · Today & quick access · effort M–L
  - A lock-screen countdown with Take and Snooze while a dose window is open.
- [ ] **Smart as-needed chips** · Medicines · effort S
  - “Ibuprofen · 3 h ago · 2 of 4 · OK after 14:30” on Today, one tap to log.
- [ ] **Travel mode** · Medicines · effort M
  - After a time-zone change: “Keep home times” or “Switch to local”.
- [ ] **Visit brief** · Medicines · effort M
  - Two days before an appointment, a one-page “since your last visit” summary.
- [ ] **Pill look in the notification** · Medicines · effort S
  - The reminder shows the pill's colour and shape.
- [ ] **Home BP week** · Vitals · effort M
  - A guided 7-day check that ends with a doctor-ready home average.
- [ ] **Forecast hot-day goal** · Water · effort S
  - The hot-day bump uses this afternoon's forecast, not the 7 am reading.
- [ ] **Front-loaded pace** · Water · effort S
  - “On pace” expects more by mid-afternoon and backs off near bedtime.
- [ ] **Caffeine cut-off & alcohol balance** · Water · effort S
  - “Coffee after 2:30 pm may affect your 10:30 bedtime”; alcohol offers “+ glass of water”.
- [ ] **Bottle mode** · Water · effort S
  - Log “Finished” or “Half” of your bottle; “2 bottles left”.
- [ ] **Import drinks from other apps** · Water · effort M
  - Drinks logged in other apps count toward today.
- [ ] **Beat last week** · Steps · effort S
  - “2,300 steps ahead of this time last week.”
- [ ] **Active hours & move nudges** · Steps · effort M · Android
  - “6 of 9 active hours”, with an opt-in nudge at :50 if this hour is short.
- [ ] **Walking trends** · Steps · effort M
  - 28- vs 90-day arrows and “600 more steps a day for 3 weeks turns this up”.
- [ ] **Score breakdown** · Sleep & heart · effort S
  - Tap the ring: “Duration 52/60 · Efficiency 21/25 · Regularity 9/15”.
- [ ] **Tonight's bedtime plan** · Sleep & heart · effort M
  - “Aim for 10:40 pm (7 h 45 m + 20 min catch-up)”; the wind-down reminder moves with it.
- [ ] **Night heart-rate dip** · Sleep & heart · effort S–M
  - “Heart rate dropped 18% below daytime; lowest around 2 am.”
- [ ] **Rest mode** · Sleep & heart · effort S–M
  - When body signals are off, offers to pause goals and quiet nudges for a few days.
- [ ] **Automatic distraction log** · Focus · effort S–M
  - Leaving mid-session is logged; “You usually drift at minute 22 — try 20 + 5”.
- [ ] **Earned breaks** · Focus · effort M
  - After 90 minutes without a real break: “Break first?”
- [ ] **One-tap wind-down** · Focus · effort M
  - At wind-down time: 4-7-8 breathing, a calm track and silence until the alarm.
- [ ] **Heads-up & until done** · Reminders · effort S
  - Smart Add understands “30 min before” and “until done”.
- [ ] **Anchor reminders** · Reminders · effort M
  - “After I wake up”, “when I plug in tonight”, “after my next focus”.
- [ ] **Auto-complete from health data** · Reminders · effort M
  - “Walk 20 min” ticks itself off when the steps show up.
- [ ] **Answer from the notification** · Period & cycle · effort S
  - “Started today” or “Not yet” on the period reminder.
- [ ] **Temperature shift** · Period & cycle · effort M
  - “Temperature rise from day 17 — ovulation likely around day 16 (estimate).”
- [ ] **Import cycle history** · Period & cycle · effort S–M
  - Past periods come in from Health Connect or Apple Health at setup.
- [ ] **Year in Pixels** · Mood & diary · effort S
  - A 12 × 31 grid of mood colours, with period dots.
- [ ] **Mood from the notification** · Mood & diary · effort S
  - Good · Okay · Bad buttons at midday and evening.
- [ ] **Prompts from your data** · Mood & diary · effort S–M
  - After a short night: “What got in the way of sleep?”

### Later — large effort or new platform work (0/6)

- [ ] **Wear OS** · Today & quick access · effort S→L
  - Take or skip a dose from the watch, later a tile with the next dose and water.
- [ ] **Siri & Control Center** · Today & quick access · effort M · iOS
  - “Log water in the app”, “Take my next dose”.
- [ ] **NFC pill-box tag** · Medicines · effort S · Android
  - Tap the phone on a sticker on the pill box to log the dose.
- [ ] **Dry-window walk tip** · Steps · effort M
  - “Rain from 6 pm — 4–5 pm looks dry.” Only when you're behind.
- [ ] **Day energy map** · Sleep & heart · effort M
  - A timeline from your wake time: grogginess, best focus, afternoon dip, wind-down.
- [ ] **Location reminders** · Reminders · effort L
  - “When I get home” or “when I leave work”.

---

## Part 2 — Gaps in existing features

_Each is something that is missing or only partly there today. Fixing one does not need a new feature._

### Today & navigation (5/10)

- [x] **Today sections:** Hydration card and “Set goal” open the Health list, not the water screen — _both now open the water screen_
- [ ] **Today sections:** Daily briefing ignores steps and sleep
- [ ] **Today sections:** Focus and Reminders cards can't be hidden
- [x] **Health nudge:** Tapping always opens Trends, whatever the alert is — _fixed by "Nudges that open the fix"_
- [x] **Health nudge:** Pull to refresh doesn't update it — _a refresh re-checks the nudge: takes it down or swaps it, never spends another show or resurrects a dismissed one_
- [x] **Log button (+):** Steps, sleep and period logs have no confirmation or Undo — _each now confirms ("Added 1,000 steps" / "Sleep logged" / "Period log saved") with an Undo that restores what was there before_
- [x] **Log button (+):** No Focus, Reminder or Diary option — _the Log sheet now has Focus session, Reminder and Diary entry, each opening its existing screen_
- [ ] **First-run setup:** No time picker for the check-in, and no way to change or cancel it later
- [ ] **First-run setup:** “Skip for now” still asks for permissions on the next start
- [ ] **First-run setup:** No Health Connect or Apple Health permission step

### Medicines (4/15)

- [x] **Meds dashboard:** A dose marked missed (3 h late) can't be taken from the dashboard — _tap a missed dose: Take now / took it at… / skip, with Undo (Late dose recovery)_
- [ ] **Meds dashboard:** Dose rows don't open the medicine detail
- [ ] **Add or edit a medicine:** No photo, doctor or pharmacy link, cost or critical-alert option
- [x] **Add or edit a medicine:** A stock of 0 comes back blank when editing — _a tracked medicine that has run out shows 0; untracked stays blank_
- [ ] **Schedules:** Every-X-hours times shift by an hour across daylight-saving changes
- [ ] **Dose reminders:** iPhone: weekday, every-X-days and cyclical medicines remind every day
- [ ] **Dose reminders:** iPhone: reminder windows aren't available
- [ ] **Dose reminders:** No setting for per-medicine snooze length
- [ ] **Medicine detail:** History shows the last 5 doses only; past doses can't be edited
- [x] **Medicine detail:** As-needed medicines can only be logged here, not from Today or the Log button — _the Log sheet's "Medicine dose" now offers as-needed medicines (with Undo), alone or beside scheduled doses; Today's own dose list is unchanged_
- [ ] **Refills & supply:** Refill overview is only reachable while a medicine is flagged
- [x] **Refills & supply:** Run-out reminder isn't updated after a dose or refill — _the one medicine is re-armed after a dose, an undo, or added stock_
- [ ] **Adherence report:** No export from this screen (export lives on All medicines)
- [ ] **Safety checks:** No allergy list for yourself, so your own medicines aren't allergy-checked
- [ ] **Safety checks:** Duplicate therapy isn't checked when saving

### Vitals (1/11)

- [ ] **Blood pressure:** No tags
- [ ] **Blood pressure:** Charts space readings evenly, not by time
- [ ] **Blood pressure report:** PDF doesn't show the family member's name
- [ ] **Blood sugar:** Report and PDF always use mg/dL
- [ ] **Blood sugar:** No field for insulin units
- [x] **Weight:** The “vs last” change is overstated in lb — _the difference is now converted once; a 1 kg drop reads -2.2 lb, not -4.9_
- [ ] **Mood:** No report, PDF or tags
- [ ] **Measurement reminders:** Same reminders for every family profile
- [ ] **Share to health apps:** Edits and deletes aren't sent
- [ ] **Share to health apps:** Arm, position and glucose context aren't written
- [ ] **Share to health apps:** Vitals aren't cloud-synced (backup file only)

### Care team & family (2/11)

- [ ] **Doctors:** Shared across all family profiles
- [ ] **Doctors:** Hospital isn't linked to a clinic record
- [x] **Clinics:** Not in backups, and not removed by Delete all data — _clinics ride in the backup (restored by id; an older file without them leaves them alone) and "Delete all data" removes them_
- [ ] **Clinics:** Directions button never appears (no map location can be set)
- [ ] **Clinics:** Shared across all family profiles
- [ ] **Appointments:** Can't link a doctor or medicines to discuss
- [ ] **Family profiles:** Water, sleep, steps, period and focus are shared, not per person
- [ ] **Family profiles:** No fields for weight, height, conditions, insurance or photo
- [ ] **Family profiles:** Deleting a person orphans their weight and mood history
- [ ] **Condition library:** Readings card isn't tappable
- [x] **Condition library:** May show the previous profile's medicines after switching — _the cache now also keys on the active profile, and the screen reloads on a profile switch_

### Water (2/16)

- [ ] **Water dashboard:** Today's log is read-only here; edit it in History
- [ ] **Drinks:** Can't create your own drink type
- [ ] **Cups:** Cups can't be edited or deleted
- [ ] **Cups:** Multi-ingredient cups don't save their ingredients
- [ ] **Personal goal:** Uses the activity level you pick, not tracked activity
- [ ] **Personal goal:** Only ml and kg; no oz or lb
- [x] **Hot-day goal:** Saving the profile drops today's hot-day bump until the next app open — _saving re-applies the cached hot-day adjustment and today's saved activity top-up (no network or health read); custom goal and fluid ceiling untouched_
- [ ] **Fluid limit:** The gauge doesn't count down to the limit
- [ ] **Pacing & tips:** Medicine advice doesn't change the goal
- [ ] **Water reminders:** Reminders aren't re-trimmed as you drink, only on app start or save
- [ ] **Water reminders:** Sound setting has no picker
- [ ] **Home-screen widget:** Shows yesterday's total after midnight until the app opens
- [ ] **Home-screen widget:** Android +250 shows nothing until the app opens
- [ ] **Home-screen widget:** Amount is fixed at 250 ml
- [ ] **Share to health apps:** Write-only: edits and deletes aren't sent, other apps' drinks aren't read
- [x] **Share to health apps:** Setting says “Health Connect” on iPhone too — _the water section and message now name Apple Health on iPhone; Focus's mindful-minutes section too_

### Focus & relaxation (2/18)

- [x] **Focus timer:** No back button in the header — _a back arrow when pushed (from a Today insight or Trends); none as the Focus tab_
- [ ] **Focus timer:** Flow's suggested break is saved as a focus session
- [ ] **Focus timer:** Pomodoro doesn't advance while the app is in the background
- [ ] **Alerts & recovery:** Focus notifications replace each other
- [ ] **Plants & garden:** Garden isn't cloud-synced
- [ ] **Coins & shop:** Redeemed trees don't appear in the garden
- [ ] **Coins & shop:** “Plant Trees” label suggests real trees; they are virtual
- [ ] **Achievements & streaks:** Achievements are only visible inside Statistics
- [ ] **Sounds:** Only 3 of 15 sounds have audio
- [ ] **Sounds:** Sound keeps playing after a session ends in the background
- [ ] **Relaxation:** Only 3 of 14 tracks play; Stress Relief has none
- [ ] **Relaxation:** Not saved to Health Connect; no recovery after a restart
- [ ] **Breathing:** No breathing history
- [ ] **Tags:** Tags can't be renamed
- [ ] **Focus reminders:** On by default for every install
- [x] **Focus reminders:** Streak nudge isn't updated after a session and fires only once — _reminders are re-planned after every session and on each launch_
- [ ] **Mindful minutes:** Permission can't be granted from inside the app
- [ ] **Mindful minutes:** No Apple Health equivalent

### Sleep (0/4)

- [ ] **Auto import:** No pull to refresh; imports mainly on app start
- [ ] **Auto import:** Two apps writing the same night are counted twice
- [ ] **History:** Only about the last 35 nights are shown
- [ ] **History:** Tapping a night doesn't edit it

### Steps (2/6)

- [ ] **Step counting:** Pedometer only counts while the Steps screen is open
- [ ] **Step counting:** Without Health Connect, pedometer permission is never asked
- [ ] **Step counting:** Hourly chart only fills from health-app data
- [x] **Add steps:** A single manual entry can't be removed — _today's Steps screen lists "Added by hand" entries, each removable with Undo; removal now works for entries on any day_
- [ ] **Steps dashboard:** Streak can't go past about 35 days
- [x] **Reminder:** Sent even when the goal is already met — _silent today once the goal is met (while the app has seen the numbers); see "Goal-aware step reminder" for the limit_

### Period & cycle (0/4)

- [ ] **Modes:** Birth-control setting is stored but does nothing
- [ ] **Predictions:** Calendar method only; temperature isn't used
- [ ] **Predictions:** Typical cycle, period and luteal lengths can't be set (28 / 5 / 14)
- [ ] **Cycle insight:** Period data never syncs to the cloud, but cloud backups include it

### Heart, workouts & devices (1/10)

- [x] **Heart dashboard:** No charts — _resting HR, HRV, blood oxygen and breathing rate now chart with a usual range_
- [ ] **Heart dashboard:** Temperature and hourly heart rate are stored but not shown
- [ ] **Heart dashboard:** Not included in backups
- [ ] **Workouts:** No manual entry and no detail view
- [ ] **Connected devices:** Source choice applies to heart data only, not steps or sleep
- [ ] **Connected devices:** No in-app disconnect
- [ ] **What the app reads:** iPhone permission text mentions only steps and sleep
- [ ] **What the app reads:** iPhone may show connected even when access was denied
- [ ] **Background sync:** No iPhone equivalent
- [ ] **Background sync:** The snapshot isn't shown anywhere; the real sync runs when the app opens

### Reminders & alarms (5/17)

- [ ] **Reminders list:** Unticked daily reminders stay in Overdue
- [x] **Reminders list:** Swipe delete has no confirm or Undo — _delete is in the card menu and can be undone_
- [ ] **Reminders list:** Not cloud-synced
- [x] **Add or edit a reminder:** No pause, end date or occurrence limit in the form — _Ends and Pause controls added to the form_
- [ ] **Add or edit a reminder:** Repeats from Smart Add can't be edited here
- [ ] **Smart Add:** Those rule-based repeats complete after the first tick
- [ ] **Escalation:** Quiet and Normal behave the same (both make sound)
- [ ] **Escalation:** Follow-ups are Android only
- [x] **Categories:** Starter categories can be deleted — _Personal, Work and Health are marked Default, are not swipe-deletable, and the service refuses to delete them (the seed never set the flag, so existing installs are covered by id)_
- [ ] **Categories:** Categories aren't in backups
- [ ] **Full-screen alarm:** No Done button for general reminders
- [ ] **Notification buttons:** iPhone: general reminders have no buttons
- [x] **Always re-armed:** Restoring a backup doesn't re-arm until the app restarts — _a restore now re-arms every reminder family straight away_
- [ ] **Always re-armed:** Weekday reminders can clash with neighbouring reminder alarms
- [ ] **Notification settings:** No quiet hours, max-snooze or missed-after setting
- [ ] **Notification settings:** Main alarms ignore some of these switches
- [x] **Exact alarms:** Battery check is only offered from water reminders — _now also offered from the Today setup checklist_

### Diary (0/3)

- [ ] **Diary:** No mood, tags, photos or search
- [ ] **Diary:** Entry date can't be changed
- [ ] **Diary:** Not cloud-synced

### Trends & insights (3/4)

- [ ] **Trends dashboard:** Only medicine changes refresh it live; other cards need pull to refresh
- [x] **Weekly recap:** Only reachable from the Health tab — _the Trends screen header now has a Weekly recap button_
- [x] **Weekly recap:** Retry fails in debug builds — _Retry no longer hands setState a Future_
- [x] **Insight engine:** 8 insights are worked out but never shown (trends and correlations) — _shown in the Patterns section on Trends_

### Settings, account & data (2/17)

- [ ] **Account:** Sign-out returns to onboarding
- [ ] **Account:** Delete account needs a sign-in within the last 5 minutes, with no re-sign-in step
- [ ] **Account:** Google sign-in needs the build's SHA-1 registered in Firebase
- [ ] **Appearance:** English only; no translations
- [ ] **App lock:** App content shows in the recent-apps preview
- [ ] **Export a copy:** The file isn't encrypted
- [ ] **Backup & restore:** Needs an app restart after restoring
- [ ] **Cloud sync:** Runs once per app start; turning it on does nothing until then
- [ ] **Cloud sync:** Water: only today's entries upload
- [ ] **Cloud sync:** Not synced: reminders, vitals, diary, dose logs, doctors, appointments, family
- [ ] **Cloud backup:** Capped at 900 KB per backup
- [ ] **Haptics:** Not included in backups
- [x] **Delete all data:** Some focus data survives — _the Focus, coins, tag and relaxation singletons are reset in memory (they used to save their old data straight back) and the relaxation* preferences are removed_
- [ ] **Delete all data:** With cloud sync on, data downloads again on the next start
- [x] **Delete all data:** Scheduled notifications aren't cancelled — _every scheduled notification and Android alarm is cancelled, and the vitals / water / steps reminder switches, emergency contact, rest days, vacation periods, weight goal and refill requests are cleared so nothing re-arms at the next launch_
- [ ] **Privacy page:** Full privacy policy link is hidden (no URL yet)
- [ ] **Free with ads:** Release builds show no ads until real ad IDs are set

---

## Part 3 — Not implemented yet

### Listed in the app, never built (0/5)

_Feature switches with no screen or data behind them._

- [ ] Fitness tracker (only a read-only workouts list exists)
- [ ] Notes (the Diary is the nearest thing)
- [ ] Expense tracker
- [ ] Exam preparation
- [ ] Habit tracker

### In the code, but no screen opens it (0/11)

_Written and stored, but a user can't reach it._

- [ ] Create your own drink type
- [ ] Favourite drinks and most-used cups
- [ ] Email and password sign-in
- [ ] Pharmacies
- [ ] Typed health logging, e.g. “walked 6000 steps”
- [ ] Emergency triage messages
- [ ] Medicine photo, doctor or pharmacy link, cost, critical alert, reminder sound
- [ ] Period cloud-sync switch
- [ ] Full-screen ads between screens
- [ ] Early-access switches (saved, but nothing reads them)
- [ ] Reminder history export

### Not built at all (1/12)

_Nothing in the code yet._

- [ ] oz and other imperial water units
- [ ] Do Not Disturb or app blocking during Focus
- [ ] 12 of 15 focus sounds, e.g. rain, ocean, forest, café
- [ ] Translations (English only)
- [ ] AI assistant or chat (removed 12 Aug 2026)
- [ ] Subscriptions or in-app purchases
- [ ] iPhone background health sync
- [ ] Mindful minutes to Apple Health
- [x] Heart-rate charts — _resting HR (and HRV, SpO2, breathing) charts; no intraday hourly chart yet_
- [ ] Manual workout entry
- [ ] Quiet-hours setting for reminders
- [ ] Encrypted database and backup file

### Before release (0/10)

_From the release checklist (21 open items)._

- [ ] Privacy policy: fill placeholders, host it, add the link
- [ ] Google Play Health apps declaration
- [ ] Google Play Data safety form
- [ ] Register the iOS App Group for the water widget
- [ ] Enable HealthKit on the iOS App ID
- [ ] Real AdMob IDs (test IDs today)
- [ ] Register the release SHA-1 for Google sign-in
- [ ] Deploy Firestore rules before the client build
- [ ] iOS store ID for the rating prompt
- [ ] First run on a real device


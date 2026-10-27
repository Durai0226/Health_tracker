# Feature checklist

Everything from the **App Feature Map** artifact in one place, in the order it is being worked on.
Tick a box when the item is built **and** its tests pass. An unticked item with an italic note is
partly built or waiting on something.

_Generated from the artifact's own data, so the wording matches it. Status last updated 27 Oct 2026._

## Progress

| Part | Done | Total |
| --- | ---: | ---: |
| 1. Smart features to add | 62 | 86 |
| 2. Gaps in existing features | 77 | 146 |
| 3. Not implemented yet | 2 | 38 |
| **Everything** | **141** | **270** (52%) |

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

### Now — high value, medium effort (22/30)

- [x] **Patterns on Trends** · Today & quick access · effort S–M — _A Patterns section under the Trends summary shows the 8 cross-day insights, grouped Needs attention / Patterns / Wins, each with Why this? and Not useful (hidden 30 days). Renders nothing when empty._
  - A Patterns section shows the 8 insights the app already works out but never shows.
- [x] **Today in the right order** · Today & quick access · effort M — _On "Your day", ONE card is lifted to the top and a line says which and why ("Water moved up — about 450 ml behind"). Medicine (a dose overdue or due within the hour; not one already missed) outranks reminders (open and due in the last 24 h; none on vacation), which outrank water (≥400 ml behind the day's pace; never for a fluid limit or someone who does not log water). Customize Today now drags cards into your own order and has a "Bring forward what needs you" switch (on by default); hidden cards are never lifted. Also fixed on the way: Today's briefing now uses steps and last night's sleep, and two overflows the new layout exposed (Hydration card caption, the nudge banner)._
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
- [x] **Glucose follow-ups & meal patterns** · Vitals · effort M — _A NEW reading below 70 mg/dL arms one 15-minute recheck reminder (the 15-15 rule the severe-low card already quotes): "Recheck your blood sugar" with no value on the lock screen; the toast says when and has Cancel; the next reading of any kind withdraws it, and a second low replaces the first. An edit or a low logged after the fact does not arm one; a reminder the OS refused is not claimed. Patterns: "By time of day" on the Blood sugar screen and in Trends → Patterns — "After breakfast readings often run high: 6 of 8 after breakfast readings in the last 30 days were above range (those averaged 200 mg/dL)" and "Lows tend to happen overnight" — for fasting, bedtime, before or after breakfast, lunch or dinner (named by the hour the reading was taken) and 23:00–05:00. A group needs 5 readings; highs need half of them, lows need 2 and a fifth of them. In the unit you read in; says "worth mentioning to your doctor", never a dose or a change._
  - A low schedules a 15-minute recheck; patterns name the meal or hour.
- [ ] **Pace-aware reminders** · Water · effort M — _PARTLY EXISTING, not built: reminders were already pruned to the remaining need and thinned when ahead of pace (ReminderRescheduleService.pruneToRemainingNeed). Not built: "~400 ml behind — your usual mug puts you back on pace" wording, which needs today-specific text on repeating reminders and would mean re-registering every slot per drink._
  - “~400 ml behind — your usual mug puts you back on pace”; quiet when you're ahead.
- [x] **Your usual, one tap** · Water · effort S–M — _Water screen: a "Your usual · Coffee · 200 ml" tile above Quick Add logs the drink you habitually have within 90 min of now (same drink and size on 3+ separate days and ≥40% of the days you drank then; never alcohol; today excluded). Tile only — not the notification action or the home-screen widget (they run outside the app)._
  - The notification, widget and first tile log what you usually drink at this hour.
- [x] **Goal-aware step reminder** · Steps · effort S–M — _Goal met → no reminder today (the repeating one starts tomorrow). Short of it with numbers fresh at fire time (≤90 min old) → "1,800 steps to go — about 18 minutes of walking". Older numbers → a generic line with no figure; no step data → exactly the old reminder. Limit: if you reach the goal while the app is closed, that day's reminder still fires (it cannot read steps at fire time)._
  - “1,800 to go ≈ 18-minute walk”; silent once the goal is met.
- [x] **Rest & sick days** · Steps · effort S–M — _Steps screen card: mark today Rest day or Unwell (Undo anytime). The steps streak holds, the goal is paused, the evening reminder stays quiet, and marked days are left out of what the adaptive goal is learned from. One day, steps only — separate from vacation mode. Not shown on the Home steps summary._
  - Mark today Rest or Unwell: the goal pauses and the streak holds.
- [x] **Overnight body check** · Sleep & heart · effort M — _Sleep screen card: "2 of 4 overnight signals are outside your usual range", naming each ("Resting heart rate: 66 bpm (usual 54–58, above)"). Resting heart rate, HRV (one statistic only), breathing rate, blood oxygen and skin temperature (an absolute or a change from baseline, never mixed), each against the 28 days before last night (7 needed), with a floor on how narrow a usual range can be. Needs 2 signals; no score and no verdict, and it says it is wellness context, not a diagnosis._
  - “2 of 5 overnight signals are outside your usual range.”
- [x] **What moves your sleep** · Sleep & heart · effort M — _Sleep screen ("What moves your sleep") and Trends → Patterns: "On nights after caffeine after 2 pm you slept 38 min less — 9 nights vs 21", for the day before a night: caffeine of 20 mg or more from 14:00, alcohol after 17:00, or a step goal met. From 5 nights on each side and a gap of 20 minutes, the larger gap first, at most two, with "Based on 9 vs 21 nights · Moderate" and a line that it is not proof one causes the other. A day with no drinks (or steps) logged is UNKNOWN, not "no caffeine", and its night is left out of that comparison. Looks back over the sleep the app holds in memory, about 35 nights._
  - “On nights with caffeine after 2 pm you slept 38 min less (9 vs 21 nights).”
- [x] **Morning report** · Sleep & heart · effort M — _Today card, from the moment a night has ended until noon, once a day (Dismiss puts it away for the day): "You slept 6h 40m — 45 min under your usual 7h 25m" (usual = the 14 nights before, from 5), the sleep debt when it is 30 minutes or more over at least 4 nights, the overnight body check's line, and at most ONE suggestion in priority order — "Your body signals are off this morning. Go a little lighter today" (3+ of 4+ signals outside), then "Try 20 extra minutes of sleep tonight, and for a week: it clears the debt" (an hour of debt and a realistic catch-up), then "A short night: an earlier one tonight helps most" (45+ minutes under usual). No suggestion when nothing calls for one. Not shown when the last night ended yesterday._
  - One Today card: last night against your usual, debt, body check and one suggestion.
- [ ] **Smart start & Focus tile** · Focus · effort S–M · Tile: Android
  - Setup pre-fills what you usually do at this hour; a Quick Settings tile starts it.
- [ ] **Focus Guard** · Focus · effort M · Android
  - The phone goes quiet during a session and comes back for breaks.
- [x] **Done and “Later” on every alert** · Reminders · effort S–M — _A reminder you made carries Done · Snooze · Later on its notification (Done · Later when it is a Quiet one, which never offered Snooze; Dismiss steps in as the third button when Snooze is switched off): Android and, now, iPhone (a registered category, same ids). Done queues the answer — the background isolate has no database — withdraws the "Still pending" follow-up at once and is applied on the next resume through the SAME code a tick in the app uses (the occurrence is recorded against the moment of the tap, source "notification", with an Undo in the resume toast). Later rings again this evening (before 17:00) or tomorrow 9:30 — set up in the background with the snooze machinery but not counted, not logged and not stopped by the snooze cap — and moves a one-off to that time in the list on the next resume (a repeating reminder is put off for one ring and keeps its schedule; a Later never pulls anything earlier). The full-screen alarm gets a "Mark done" button too. The reminder's id now rides in its alarm payload, which is what the buttons act on. Verified headless against the real handlers, the queue and the recording scheduler; the AlarmManager arming and the iPhone buttons themselves can only be seen on a device._
  - Done · Snooze 10 m · Later (this evening or tomorrow 9:30).
- [x] **Overdue triage** · Reminders · effort S–M — _The Overdue heading offers "Catch up" from two reminders up: This evening (or Tonight) / Tomorrow morning move the one-offs, Skip all closes them and sends repeating ones to their next time; each shows what it will do first, and one Undo takes the whole thing back. A moved or skipped occurrence is recorded as skipped, which adherence does not count against you. Fixed on the way: a reminder with an end date or a Smart Add repeat whose own time had not come yet was armed for its NEXT occurrence, so "daily until Friday" set for 18:00 never fired that first day._
  - Move all to today · Tomorrow morning · Skip all.
- [ ] **Sleep-aware quiet hours** · Reminders · effort M
  - Non-urgent reminders due during sleep or focus arrive afterwards as one summary.
- [x] **Cycle pattern check** · Period & cycle · effort S–M — _Period screen card, from 4 completed cycles: "Your last 6 cycles ran from 24 to 36 days" when they spread more than a week, or two of them were under 21 or over 38 days, or two periods ran past 8 days. It reports what was logged, names no condition and says it is not a diagnosis; "Share summary" makes a one-page PDF to bring to a check-up. The thresholds are common rules of thumb and need a clinician's review._
  - “Your last 6 cycles varied by 12 days — worth mentioning at a check-up”, plus a PDF.
- [x] **Honest, adjustable predictions** · Period & cycle · effort S–M — _The prediction now says how wide it is and what it rests on — "Likely Oct 12 – Oct 16, most likely the 14th · based on 7 cycles" (a typical 28-day cycle, then "a rough guess" until 3 cycles) — and "Adjust cycle lengths" sets the typical cycle, period and luteal phase (28 / 5 / 14 by default, with a reset). The luteal length always applies; the other two give way to your own history after 3 cycles, and the sheet says so._
  - “Oct 12–16, most likely the 14th · based on 7 cycles.”
- [x] **Your PMS pattern** · Period & cycle · effort M — _Period screen card, from 3 cycles with enough logging: "Before your period: Cramps — usually from 3 days before (4 of 5 cycles)" with when it is likely to start again. A symptom must show up in 60% of those cycles AND at least twice as often per logged day in the week before as in the rest of the cycle, so one that is simply always there is never reported; needs days logged outside that week to compare against. Says when it was logged, not that it is premenstrual. Thresholds need a clinician's review._
  - “Cramps and low mood usually start 3 days before (4 of 5 cycles).”
- [x] **Cycle privacy pack** · Period & cycle · effort M — _Period screen → lock icon → Cycle privacy: what is stored and where; "Private reminders" (cycle reminders say only "Reminder", re-set straight away); "Leave out of backups" (backup files and cloud backups skip cycle data from then on); and Delete all cycle data (days, cycles, settings and reminders, with confirmation; earlier backups keep their copy). Both switches are off until switched on._
  - One screen to keep cycle data private.
- [x] **Mood tags, mostly automatic** · Mood & diary · effort M — _Logging a mood offers "From your day" tags already chosen and removable — a short night (<6 h) or a good one (≥7 h), a step goal met (or a quiet day, only once the day is over), a period, every dose taken or one missed — read from what the app already knows; a family member's mood is never tagged with the account holder's period. "What went with it?" opens eight hand-picked tags (walk, exercise, friends, family, work, outdoors, rest, hobby). Tags show in the history row, an edited entry keeps its own, and moving the date re-reads the day._
  - Tap icons like walk or friends; sleep, steps, doses and cycle phase are tagged for you.
- [x] **What goes with better days** · Mood & diary · effort M — _Mood screen and Patterns: "Mood tends to be better on days with a walk" with "Based on 14 vs 11 days · Moderate", for up to three tags, largest gap first. Needs 5 days on each side and a gap of half a point out of 4 over the last 90 days; several entries on one day count as one, averaged. Says it is a pattern in your own entries, not that one causes the other._
  - “Mood tends to be better on days with a walk (+0.8 · 14 vs 11 days).”
- [x] **Diary that resurfaces** · Mood & diary · effort M — _Entry editor: a line under the title opens "Entry details" — the date and time (set back to write about yesterday), a mood (same five faces as the Mood log; tap again to clear) and eight tags. The Diary list gets a search (title, body, tag names, mood names; every word must match), an "On this day" card for the same date in earlier years (up to three, the latest year first; 29 Feb returns on 28 Feb) and one gentle prompt a day, offered not forced — after a short night "What got in the way of sleep?", after a missed dose, a low or a great mood — which fills the new entry's title; "Not today" puts it away until tomorrow. A diary entry's mood is its own and is not added to the Mood log. Schema v22 (mood and tags columns, migration tested on a v21 database, one that already has the columns and one with no diary table)._
  - Mood, tags, an editable date, search, and “On this day”.

### Next — second wave (21/33)

- [x] **How strong is this pattern** · Today & quick access · effort S — _Every cross-day pattern card says "Based on 9 vs 7 days · Moderate" (Early signal / Moderate / Strong). Strong needs 14+ days in the smaller group and a gap at least twice the engine's own floor; Moderate 8+ and 1.5×. The thresholds are a judgement, not a statistic._
  - Each pattern says “Based on 9 vs 7 days · Moderate”.
- [x] **Care circle** · Today & quick access · effort S–M — _Off until switched on (on the Emergency contact sheet): when a dose is missed, the late-dose sheets offer "Tell Priya" — it opens the messages app with "Hi Priya, I missed a dose today and could use a nudge." typed in and YOU press send. Nothing is sent by the app and the words never carry the medicine, the dose or the time. The adherence export sheet gained "Last week (PDF)" — seven days, to send to someone who looks out for you, shared by hand. The contact is the emergency contact the app already holds._
  - After a missed dose, “Let Priya know?” opens a text without the medicine name. A weekly PDF you can send.
- [x] **Emergency card** · Today & quick access · effort S–M — _Settings → Emergency card, for the person on screen: name, age, blood group, allergies, conditions, current medicines (alphabetical, with the dose) and the emergency contact with a tap-to-call. What nobody wrote down reads "Not recorded", never "None" — a card claiming no allergies because nobody was asked would be worse than none. Shares as a picture (a picture only: nothing is pushed to the lock screen for you). The profile form gained a Conditions field, a phone check, and for yourself mirrors the emergency contact. Found on the way: your own medicines were never allergy-checked (see Safety checks)._
  - A lock-screen-ready card with allergies, conditions, medicines and emergency contact.
- [ ] **Live dose window** · Today & quick access · effort M–L
  - A lock-screen countdown with Take and Snooze while a dose window is open.
- [x] **Smart as-needed chips** · Medicines · effort S — _A Today card under the next-dose hero for each as-needed medicine (three shown): "Ibuprofen · 3 h ago · 2 of 4 · OK after 6:00 PM", from the limits set on the medicine — a most per 24 hours (counted over the last 24 hours, not the calendar day) and a minimum gap — with one tap to Take (stock decremented, Undo puts it back). A dose that is not yet OK, or past the daily limit, asks "log it anyway?" first and is logged if you say yes: it reports the limits and blocks nothing. A skipped or missed dose is not a dose taken. "Follow the label and your doctor's advice." Nothing at all without an as-needed medicine._
  - “Ibuprofen · 3 h ago · 2 of 4 · OK after 14:30” on Today, one tap to log.
- [ ] **Travel mode** · Medicines · effort M
  - After a time-zone change: “Keep home times” or “Switch to local”.
- [x] **Visit brief** · Medicines · effort M — _Appointments list → Visit brief for a doctor's visit: "since your last visit" (kept between a week and 90 days; the last 30 days when there was none) — doses taken, missed and skipped per medicine, medicines started or stopped in that window, blood pressure (as sessions), blood sugar and weight summaries, and a "to discuss" list (the visit's purpose and notes, and the medicines linked to it) — shown on screen and as a PDF to share. A notification two days before at 9:00 says it is ready and opens it; it is withdrawn with the appointment. The appointment editor can now link the doctor and the medicines to discuss. Summaries are plain figures, no verdicts. Not in the brief: sleep and mood. The window and the summaries need a clinician's review._
  - Two days before an appointment, a one-page “since your last visit” summary.
- [ ] **Pill look in the notification** · Medicines · effort S
  - The reminder shows the pill's colour and shape.
- [x] **Home BP week** · Vitals · effort M — _Blood pressure screen card: "Start a week" asks whether to switch on the usual morning (9:00) and evening (19:00) BP reminders — both offered ON, switched on only when you press Start. Then "Day 3 of 7", seven columns of morning/evening dots (taken / missed / to do, each with a spoken label), what is due now (morning before noon, evening after), and "So far: 126/81". The first day is left out; the rest are averaged (each session already the average of the two readings a minute apart). It becomes a home average from 8 sessions on 4 days. At the end: the average, its range by the same rules as every other reading, morning and evening apart, a "Copy summary" that puts words fit for a message to the doctor on the clipboard, and Close. One person's week (per profile). Not built: adding the week to the PDF report, and ESC's lower home cut-offs — the app's own classifier is used and the card says a doctor may read a home average against slightly lower ones._
  - A guided 7-day check that ends with a doctor-ready home average.
- [x] **Forecast hot-day goal** · Water · effort S — _With "adjust for the weather" on, the day's goal is judged against the HOTTER of the feels-like temperature right now and today's forecast high (Open-Meteo daily apparent_temperature_max, one request with the current reading), so a goal set at 7:30 on a day forecast to reach 38 already says so. The forecast is cached with its date and never reused tomorrow; no forecast in the answer, or an unbelievable one, falls back to the temperature now, exactly as before. The profile screen's refresh says "It feels like 24°C in Chennai, up to 36°C today". A custom goal and a fluid ceiling are still never adjusted._
  - The hot-day bump uses this afternoon's forecast, not the 7 am reading.
- [x] **Front-loaded pace** · Water · effort S — _The pace the water card, Today, the briefing and the reminders judge you against is no longer an even rate: about 37% of the goal is expected by a quarter of the waking day, 67% by the middle (mid-afternoon for 07:00–23:00), 89% by three quarters, and only the last tenth in the final quarter — so "on pace" asks for more early and backs off near bedtime. Someone drinking evenly now reads as behind by mid-afternoon (they were "on pace" before); someone who front-loads is on pace. The end-of-day projection is measured against the same curve (exactly on it projects exactly the goal). The evenly-paced curve is still available to the code._
  - “On pace” expects more by mid-afternoon and backs off near bedtime.
- [x] **Caffeine cut-off & alcohol balance** · Water · effort S — _Under the gauge, for as long as each is true: "Coffee after 2:30 PM may affect your 10:30 PM bedtime" (cut-off = bedtime − 8 h, from your own bedtime; drinks under 20 mg ignored) and, after alcohol with less than a glass of anything non-alcoholic since, "A glass of water alongside your drink helps · + Glass of water". Each can be put away for the day. Never the water offer for someone on a fluid limit. Derived from the log, not a toast: a toast replaced the Undo of the drink just logged._
  - “Coffee after 2:30 pm may affect your 10:30 bedtime”; alcohol offers “+ glass of water”.
- [x] **Bottle mode** · Water · effort S — _Water screen, under Quick Add: set your bottle once (200 ml to 2 litres, steps of 50), then "Finished" logs the whole bottle and "Half" half of it (to the nearest 10 ml), each with the usual Undo, and a line says "About 2 bottles to go" (a few sips / half a bottle / a bottle / a bottle and a half / whole bottles). Under a fluid limit the logging stays and the countdown goes: a ceiling is not a target. The buttons stack at large text or narrow widths. Not built: more than one bottle._
  - Log “Finished” or “Half” of your bottle; “2 bottles left”.
- [ ] **Import drinks from other apps** · Water · effort M
  - Drinks logged in other apps count toward today.
- [x] **Beat last week** · Steps · effort S — _Steps screen, under the ring: "2,300 steps ahead of this time last week" / "behind". Only when last week's day has an hourly record covering ≥85% of its steps (a day synced at 3pm is refused), after 8am, for differences ≥100, and not on a rest day._
  - “2,300 steps ahead of this time last week.”
- [ ] **Active hours & move nudges** · Steps · effort M · Android
  - “6 of 9 active hours”, with an opt-in nudge at :50 if this hour is short.
- [x] **Walking trends** · Steps · effort M — _Steps screen card between the weekly and hourly charts: "Up 12% on your 90-day average — 8,450 a day over the last 4 weeks against 7,540 over 90". Needs 14 days with steps in the last 28 and 45 in the last 90; rest and unwell days, and days with no steps recorded at all, are left out (a day nobody carried a phone says nothing about walking). Within 5% either way is "steady". When it is not up, one line says the extra steps a day (a multiple of 100, at most 3,000), kept up for 21 days, that would turn it — worked out by playing the plan forward on a copy of the real record and reading it with the same windows and rules, so the card and its own promise cannot disagree. It gives a direction and a size, not a verdict._
  - 28- vs 90-day arrows and “600 more steps a day for 3 weeks turns this up”.
- [x] **Score breakdown** · Sleep & heart · effort S — _Tap the sleep-score ring: "Duration 54/60 · Efficiency 22/25 · Regularity 6/15" with a bar and a line on each. The parts always add up to the number on the ring (regularity is what remains of the stored score); a hand-logged night says its efficiency is an estimate._
  - Tap the ring: “Duration 52/60 · Efficiency 21/25 · Regularity 9/15”.
- [x] **Tonight's bedtime plan** · Sleep & heart · effort M — _Sleep screen card: "Aim for 10:40 PM — 7 h 45 m of sleep, 20 m of catch-up, about 15 m awake in bed", the wake time less the sleep you aim for, less the gentle catch-up the sleep-debt figure allows (at most an hour a night, none when the debt is too big to clear that way), less the time you usually lie awake (only from nights a device measured; a standard allowance otherwise, and the card says which). A soft target with its working shown. When your wind-down reminder is at a different time, the card offers to follow the plan (also a "Follow tonight's plan" switch on the sleep schedule screen — offered, never switched on for you): the reminder then lands the usual lead before the plan's bedtime, re-armed with the other reminders as the plan moves. The allowance and catch-up limits need a clinician's review._
  - “Aim for 10:40 pm (7 h 45 m + 20 min catch-up)”; the wind-down reminder moves with it.
- [x] **Night heart-rate dip** · Sleep & heart · effort S–M — _Sleep screen, under "Overnight body check": "Your heart rate was 21% lower overnight than by day (about 55 vs 70 bpm); lowest around 2 am." From the hourly heart rates and the night's sleep: the whole hours asleep (3 needed) against 09:00–21:00 of the day before up to bedtime (6 needed). A night that was as high or higher says so without alarm. No claim about what a healthy dip is._
  - “Heart rate dropped 18% below daytime; lowest around 2 am.”
- [ ] **Rest mode** · Sleep & heart · effort S–M — _PARTLY BUILT: after two nights in a row with 3 or more of at least 4 signals outside their usual range, the Overnight body check offers "Take a rest day" (never done for you; Undo). That is the existing one-day Rest day — it pauses today's step goal, keeps the streak and quiets the evening step reminder. Not built: a few days at a time, or quieting other reminders and goals._
  - When body signals are off, offers to pause goals and quiet nudges for a few days.
- [ ] **Automatic distraction log** · Focus · effort S–M
  - Leaving mid-session is logged; “You usually drift at minute 22 — try 20 + 5”.
- [ ] **Earned breaks** · Focus · effort M
  - After 90 minutes without a real break: “Break first?”
- [ ] **One-tap wind-down** · Focus · effort M
  - At wind-down time: 4-7-8 breathing, a calm track and silence until the alarm.
- [x] **Heads-up & until done** · Reminders · effort S — _Smart Add reads "30 min before", "an hour before", "half an hour before" (up to a day): the reminder fires that much earlier and its message says what it is early for ("At 3:00 PM"). "until done", "until I do it", "keep reminding me", "nag me", "don't let me forget" select the Insistent tier. Neither phrase stays in the title._
  - Smart Add understands “30 min before” and “until done”.
- [ ] **Anchor reminders** · Reminders · effort M
  - “After I wake up”, “when I plug in tonight”, “after my next focus”.
- [ ] **Auto-complete from health data** · Reminders · effort M
  - “Walk 20 min” ticks itself off when the steps show up.
- [x] **Answer from the notification** · Period & cycle · effort S — _The period reminder "Anything to note today?" (on the predicted start day) carries "Started today" and "Not yet". "Started today" logs a medium-flow day for the day of the tap — keeping anything else already logged that day — and says so with Undo; a day already logged as bleeding is left alone; a start that would begin a new period within 18 days of the last one is NOT written (the Log sheet asks about those; a button cannot) and the toast says so. "Not yet" just closes it. Never offered on a private reminder, where "Started today" would say what it is about._
  - “Started today” or “Not yet” on the period reminder.
- [x] **Temperature shift** · Period & cycle · effort M — _Period screen card once your own basal temperature log shows three days in a row each warmer than the six before them, the third by at least 0.2 °C (the common "three over six" rule), from cycle day 8: "Your temperature rose on day 16 (Mar 16) and stayed up for three days: ovulation was likely around day 15", with the days from earlier cycles that had one. Shown for the current cycle or the one before; a shift from older cycles is history. It looks BACK — a shift is only visible three days after it starts — says illness, alcohol and a short night can move it, and carries "not a basis for contraception". Nothing about the calendar prediction changes: temperature confirms ovulation, it does not move the next-period date._
  - “Temperature rise from day 17 — ovulation likely around day 16 (estimate).”
- [ ] **Import cycle history** · Period & cycle · effort S–M
  - Past periods come in from Health Connect or Apple Health at setup.
- [x] **Year in Pixels** · Mood & diary · effort S — _Mood screen header → "Year in pixels": a 12 × 31 grid, one square a day in the colour of how the day felt (several entries in a day: their average), a dot on period days (never shown beside a family member's moods), year stepping across years that have data, and a legend that adds up. One tap target for the whole grid names the day under the finger; each logged square is its own node for a screen reader._
  - A 12 × 31 grid of mood colours, with period dots.
- [x] **Mood from the notification** · Mood & diary · effort S — _The daily "How are you feeling?" reminder carries Good · Okay · Bad (Android action buttons, an iOS category): one tap logs that mood at the moment of the tap, tagged from that day like a mood logged in the app, and on the next resume Today says "Logged your mood: Good · Undo". The button runs in a background isolate with no database, so it only queues the answer; nothing is lost if the write fails or the app is killed between the write and the acknowledgement (the entry's id comes from the tap time, so a replay overwrites rather than duplicates). Not built: a second, midday reminder — there is one reminder, at the time you set (20:00 by default)._
  - Good · Okay · Bad buttons at midday and evening.
- [x] **Prompts from your data** · Mood & diary · effort S–M — _One gentle prompt a day on the Diary screen, picked from what the app knows: after a short night (<6 h) "What got in the way of sleep?", after a dose missed yesterday "What made a dose hard to take yesterday?", after a low mood in the last 24 h "What has been on your mind?", after a great one "What went well today?" — in that order, never on a day that already has an entry, and "Not today" puts it away until tomorrow. It offers a question and fills the new entry's title; it writes nothing. Not shown on Today._
  - After a short night: “What got in the way of sleep?”

### Later — large effort or new platform work (2/6)

- [ ] **Wear OS** · Today & quick access · effort S→L
  - Take or skip a dose from the watch, later a tile with the next dose and water.
- [ ] **Siri & Control Center** · Today & quick access · effort M · iOS
  - “Log water in the app”, “Take my next dose”.
- [ ] **NFC pill-box tag** · Medicines · effort S · Android
  - Tap the phone on a sticker on the pill box to log the dose.
- [x] **Dry-window walk tip** · Steps · effort M — _Steps screen: "Rain from 6 pm — 2–4 pm looks dry for a walk." (or "Rain until 3 pm — 4–6 pm looks dry…") — only when you are clearly behind an even pace through the waking day (under 80%), rain of 50% or more is forecast in the hours left and a dry stretch (under 30%) can be pointed at; capped at two hours, never on a rest day, never on a dry day. It reuses the place you gave for the weather-aware water goal and that switch (no new permission, nothing fetched when it is off), caches the hourly chance of rain for two hours and only for today, and says it is a guess. Hours with no forecast are neither wet nor dry._
  - “Rain from 6 pm — 4–5 pm looks dry.” Only when you're behind.
- [x] **Day energy map** · Sleep & heart · effort M — _Sleep screen card "A typical day": often best for focus 9:00–11:30 AM, with the whole day beneath — waking up, warming up, often best for focus, the usual afternoon dip, a second wind, wind down — laid against your wake time and bedtime (the average of your recent nights from three of them, otherwise your sleep schedule, and the card says which), with "Right now: …" while it is one. It says on its face that it is a general pattern, not measured from you. A day shorter than ten hours awake makes no card; phases are cut short at the wind-down. The hours after waking each phase sits at are rule-of-thumb figures and need a clinician or sleep researcher's review._
  - A timeline from your wake time: grogginess, best focus, afternoon dip, wind-down.
- [ ] **Location reminders** · Reminders · effort L
  - “When I get home” or “when I leave work”.

---

## Part 2 — Gaps in existing features

_Each is something that is missing or only partly there today. Fixing one does not need a new feature._

### Today & navigation (8/10)

- [x] **Today sections:** Hydration card and “Set goal” open the Health list, not the water screen — _both now open the water screen_
- [x] **Today sections:** Daily briefing ignores steps and sleep — _a short night (under 6 h) is named in the morning; early evening short of the step goal says how far and what that is in walking; nothing on a rest day or with no steps read_
- [x] **Today sections:** Focus and Reminders cards can't be hidden — _the card is switched off like the others, and Focus and Reminders now have a row each on the Health tab so they are never reachable only from it_
- [x] **Health nudge:** Tapping always opens Trends, whatever the alert is — _fixed by "Nudges that open the fix"_
- [x] **Health nudge:** Pull to refresh doesn't update it — _a refresh re-checks the nudge: takes it down or swaps it, never spends another show or resurrects a dismissed one_
- [x] **Log button (+):** Steps, sleep and period logs have no confirmation or Undo — _each now confirms ("Added 1,000 steps" / "Sleep logged" / "Period log saved") with an Undo that restores what was there before_
- [x] **Log button (+):** No Focus, Reminder or Diary option — _the Log sheet now has Focus session, Reminder and Diary entry, each opening its existing screen_
- [ ] **First-run setup:** No time picker for the check-in, and no way to change or cancel it later
- [x] **First-run setup:** “Skip for now” still asks for permissions on the next start — _start-up now looks at the notification permission and never asks; the welcome pane, the permission banner and the setup checklist are the only places that do_
- [ ] **First-run setup:** No Health Connect or Apple Health permission step

### Medicines (11/15)

- [x] **Meds dashboard:** A dose marked missed (3 h late) can't be taken from the dashboard — _tap a missed dose: Take now / took it at… / skip, with Undo (Late dose recovery)_
- [x] **Meds dashboard:** Dose rows don't open the medicine detail — _tap a dose that is taken, skipped or still to come; long-press any row (or use the screen reader's action menu) to open the medicine. A due or missed dose still takes or recovers on a tap_
- [ ] **Add or edit a medicine:** No photo, doctor or pharmacy link, cost or critical-alert option
- [x] **Add or edit a medicine:** A stock of 0 comes back blank when editing — _a tracked medicine that has run out shows 0; untracked stays blank_
- [x] **Schedules:** Every-X-hours times shift by an hour across daylight-saving changes — _the slots are whole hours on the clock from the anchor, not elapsed time added to a date, so 00:30 / 06:30 / 12:30 stay that on the day the clocks change (checked with the clocks of New York and London; this machine's own zone has no daylight saving)_
- [ ] **Dose reminders:** iPhone: weekday, every-X-days and cyclical medicines remind every day
- [ ] **Dose reminders:** iPhone: reminder windows aren't available
- [ ] **Dose reminders:** No setting for per-medicine snooze length
- [x] **Medicine detail:** History shows the last 5 doses only; past doses can't be edited — _"Show all N doses" opens the whole history (newest first, by month, with All / Taken / Skipped / Missed); tap any dose, here or in the short list, to say it was taken (at the scheduled minute or a time you name), change the time taken, say it was not taken, or remove the entry — each with Undo, and the tablets left follow it. Found on the way: recovering a missed dose counted one tablet however many the dose was, and Undo gave tablets back to a medicine whose stock nobody counts_
- [x] **Medicine detail:** As-needed medicines can only be logged here, not from Today or the Log button — _the Log sheet's "Medicine dose" now offers as-needed medicines (with Undo), alone or beside scheduled doses; Today's own dose list is unchanged_
- [x] **Refills & supply:** Refill overview is only reachable while a medicine is flagged — _a Refill & supply button on the Medicines screen, always there_
- [x] **Refills & supply:** Run-out reminder isn't updated after a dose or refill — _the one medicine is re-armed after a dose, an undo, or added stock_
- [x] **Adherence report:** No export from this screen (export lives on All medicines) — _the report's header has the same Share with your doctor sheet (PDF or CSV) as the Medicines list; one helper behind both_
- [x] **Safety checks:** No allergy list for yourself, so your own medicines aren't allergy-checked — _the allergy check was never run for a medicine of your own (it was scoped to family members only); the add flow and the medicine detail screen now read the allergies on your own profile ("Me") the way they read a dependent's. Found while building the Emergency card, which reads the same list_
- [x] **Safety checks:** Duplicate therapy isn't checked when saving — _saving a medicine for a person who already takes the same ingredient or name asks "Possible duplicate — Save anyway?"; an edit is asked about only when it changed what the medicine is called, and a failed lookup never blocks a save_

### Vitals (6/11)

- [x] **Blood pressure:** No tags — _chips on the reading form (after exercise, stressed, after coffee, white coat, missed a dose …), carried to the second reading of a session, kept when a reading is edited, shown in the history rows and as a Circumstances column in the doctor report_
- [x] **Blood pressure:** Charts space readings evenly, not by time — _BP (systolic and diastolic), blood sugar and mood charts, and both report screens, now draw on a real time axis_
- [x] **Blood pressure report:** PDF doesn't show the family member's name — _the blood-pressure and blood-sugar PDFs now name the active family member, through the same helper as the adherence report_
- [x] **Blood sugar:** Report and PDF always use mg/dL — _the report screen and its PDF follow the unit set on the Blood sugar screen (values, headings, chart axis and band, and the target guidance)_
- [x] **Blood sugar:** No field for insulin units — _an "Insulin (units, optional)" field on the reading form (0.5 to 200; comma or point), kept when a reading is edited, cleared by emptying it, and shown in the history row_
- [x] **Weight:** The “vs last” change is overstated in lb — _the difference is now converted once; a 1 kg drop reads -2.2 lb, not -4.9_
- [ ] **Mood:** No report, PDF or tags
- [ ] **Measurement reminders:** Same reminders for every family profile
- [ ] **Share to health apps:** Edits and deletes aren't sent
- [ ] **Share to health apps:** Arm, position and glucose context aren't written
- [ ] **Share to health apps:** Vitals aren't cloud-synced (backup file only)

### Care team & family (5/11)

- [ ] **Doctors:** Shared across all family profiles
- [ ] **Doctors:** Hospital isn't linked to a clinic record
- [x] **Clinics:** Not in backups, and not removed by Delete all data — _clinics ride in the backup (restored by id; an older file without them leaves them alone) and "Delete all data" removes them_
- [ ] **Clinics:** Directions button never appears (no map location can be set)
- [ ] **Clinics:** Shared across all family profiles
- [x] **Appointments:** Can't link a doctor or medicines to discuss — _the appointment editor has doctor chips (from your saved doctors) and medicine chips; the visit brief lists the medicines linked to the visit_
- [ ] **Family profiles:** Water, sleep, steps, period and focus are shared, not per person
- [ ] **Family profiles:** No fields for weight, height, conditions, insurance or photo — _PARTLY BUILT: Conditions is on the profile form now (and on the Emergency card). Not built: weight, height, insurance and a photo_
- [x] **Family profiles:** Deleting a person orphans their weight and mood history — _removing a person now asks: keep their records (everything, weight and mood included, comes to you — weight and mood used to be left under a profile that no longer existed) or delete everything held for them, medicines and their reminders, doses, readings, weight, mood and appointments_
- [x] **Condition library:** Readings card isn't tappable — _the card opens Blood pressure (high blood pressure page) or Blood sugar (type 2 diabetes page), and is read again on return so a reading logged there is on it_
- [x] **Condition library:** May show the previous profile's medicines after switching — _the cache now also keys on the active profile, and the screen reloads on a profile switch_

### Water (5/16)

- [x] **Water dashboard:** Today's log is read-only here; edit it in History — _a drink on Today's Log opens the same Edit Entry sheet the history uses; saving reads the day again. The header's Edit still opens the full history for adding and removing_
- [ ] **Drinks:** Can't create your own drink type
- [x] **Cups:** Cups can't be edited or deleted — _long-press a cup you made (or the screen reader's action menu): Edit cup / Delete cup, with Undo. Built-in cups are not offered_
- [ ] **Cups:** Multi-ingredient cups don't save their ingredients
- [ ] **Personal goal:** Uses the activity level you pick, not tracked activity
- [ ] **Personal goal:** Only ml and kg; no oz or lb
- [x] **Hot-day goal:** Saving the profile drops today's hot-day bump until the next app open — _saving re-applies the cached hot-day adjustment and today's saved activity top-up (no network or health read); custom goal and fluid ceiling untouched_
- [x] **Fluid limit:** The gauge doesn't count down to the limit — _on a limit the gauge shows what is LEFT of it, from the raw volume swallowed (a limit is about liquid); at it, "Limit reached"; past it, "Over by 220 ml" — never "Goal reached"_
- [ ] **Pacing & tips:** Medicine advice doesn't change the goal
- [ ] **Water reminders:** Reminders aren't re-trimmed as you drink, only on app start or save — _DELIBERATELY NOT BUILT: the reminders repeat daily at fixed times, so cancelling the rest of today's as you drink would also cancel tomorrow's until the app is next opened. Re-trimming at app start (as now) is the safe half_
- [ ] **Water reminders:** Sound setting has no picker
- [ ] **Home-screen widget:** Shows yesterday's total after midnight until the app opens
- [ ] **Home-screen widget:** Android +250 shows nothing until the app opens
- [ ] **Home-screen widget:** Amount is fixed at 250 ml
- [ ] **Share to health apps:** Write-only: edits and deletes aren't sent, other apps' drinks aren't read
- [x] **Share to health apps:** Setting says “Health Connect” on iPhone too — _the water section and message now name Apple Health on iPhone; Focus's mindful-minutes section too_

### Focus & relaxation (9/18)

- [x] **Focus timer:** No back button in the header — _a back arrow when pushed (from a Today insight or Trends); none as the Focus tab_
- [x] **Focus timer:** Flow's suggested break is saved as a focus session — _the offered break is a break: it counts down, grows no plant, pays no coins, counts toward no streak and is not in the history "your usual length" comes from; nothing starts after it. "End break" stops it with no question, and leaving the screen during one is just leaving. It survives a restart as a break_
- [ ] **Focus timer:** Pomodoro doesn't advance while the app is in the background
- [ ] **Alerts & recovery:** Focus notifications replace each other
- [ ] **Plants & garden:** Garden isn't cloud-synced
- [x] **Coins & shop:** Redeemed trees don't appear in the garden — _an "Added with coins" section on the Garden, newest first, with its own count in the header; a garden with only a redeemed tree is no longer the empty state, and a tree redeemed while it is open appears at once_
- [x] **Coins & shop:** “Plant Trees” label suggests real trees; they are virtual — _the Focus card is now "Garden Shop", the name of the screen it opens_
- [x] **Achievements & streaks:** Achievements are only visible inside Statistics — _an Achievements screen lists all 24 — earned (newest first, with the day and the coins it paid) and still to earn (nearest first, with how far along) — reached from a row on the Focus screen and from "See all" beside Statistics' short list_
- [ ] **Sounds:** Only 3 of 15 sounds have audio
- [ ] **Sounds:** Sound keeps playing after a session ends in the background
- [ ] **Relaxation:** Only 3 of 14 tracks play; Stress Relief has none
- [ ] **Relaxation:** Not saved to Health Connect; no recovery after a restart
- [x] **Breathing:** No breathing history — _each finished exercise is recorded (pattern, cycles, when; the newest 300 kept) and listed by day on a Breathing history screen with sessions, minutes, this week and your most-used pattern, reached from the Breathing sheet. An exercise closed early records nothing_
- [x] **Tags:** Tags can't be renamed — _a tag's sheet has Rename (default or custom); a name another tag has is refused, ignoring case; sessions carry the new name. Fixed on the way: the create-tag sheet disposed its text controller before its exit animation finished_
- [x] **Focus reminders:** On by default for every install — _the daily reminder and the streak nudge are off until switched on (they used to be armed by completing a first session); anyone who already switched them on keeps them_
- [x] **Focus reminders:** Streak nudge isn't updated after a session and fires only once — _reminders are re-planned after every session and on each launch_
- [ ] **Mindful minutes:** Permission can't be granted from inside the app
- [ ] **Mindful minutes:** No Apple Health equivalent

### Sleep (0/4)

- [ ] **Auto import:** No pull to refresh; imports mainly on app start
- [ ] **Auto import:** Two apps writing the same night are counted twice
- [ ] **History:** Only about the last 35 nights are shown
- [ ] **History:** Tapping a night doesn't edit it

### Steps (3/6)

- [ ] **Step counting:** Pedometer only counts while the Steps screen is open
- [ ] **Step counting:** Without Health Connect, pedometer permission is never asked
- [ ] **Step counting:** Hourly chart only fills from health-app data
- [x] **Add steps:** A single manual entry can't be removed — _today's Steps screen lists "Added by hand" entries, each removable with Undo; removal now works for entries on any day_
- [x] **Steps dashboard:** Streak can't go past about 35 days — _the streak reads the date of every goal-reached day, with the days in memory (fresher) overruling them_
- [x] **Reminder:** Sent even when the goal is already met — _silent today once the goal is met (while the app has seen the numbers); see "Goal-aware step reminder" for the limit_

### Period & cycle (2/4)

- [ ] **Modes:** Birth-control setting is stored but does nothing
- [ ] **Predictions:** Calendar method only; temperature isn't used — _a temperature shift is now found and shown as a confirmation of ovulation; the next-period prediction itself still uses cycle length only_
- [x] **Predictions:** Typical cycle, period and luteal lengths can't be set (28 / 5 / 14) — _Adjust cycle lengths on the Period screen sets all three, with a reset to 28 / 5 / 14 (see "Honest, adjustable predictions")_
- [x] **Cycle insight:** Period data never syncs to the cloud, but cloud backups include it — _a "Leave out of backups" switch on Cycle privacy keeps cycle data out of both backup files and cloud backups. It still never syncs live to the cloud (that is the intended default) and it is off until switched on_

### Heart, workouts & devices (4/10)

- [x] **Heart dashboard:** No charts — _resting HR, HRV, blood oxygen and breathing rate now chart with a usual range_
- [x] **Heart dashboard:** Temperature and hourly heart rate are stored but not shown — _a skin-temperature chart with its usual range, and a "Heart rate by hour" card on the Heart screen: 24 slim bars of the hourly average with the lowest and highest hour named, a gap left as a gap (never a short bar). Painted rather than built, so it costs one widget instead of a few hundred_
- [x] **Heart dashboard:** Not included in backups — _heart, workouts and connected devices are in the backup (format version 8) and restored by merge; a file without them leaves what is there alone_
- [x] **Workouts:** No manual entry and no detail view — _a + on the Workouts list logs one (kind, start, minutes, optional calories, distance and note; Undo); tapping any row opens it in full. One you entered can be edited or deleted (with Undo); one a watch wrote is read-only and says where to change it. A sync never drops a session you entered. The form's kinds are named exactly as the list names them afterwards ("Biking", not "Cycling")_
- [ ] **Connected devices:** Source choice applies to heart data only, not steps or sleep
- [ ] **Connected devices:** No in-app disconnect
- [ ] **What the app reads:** iPhone permission text mentions only steps and sleep
- [ ] **What the app reads:** iPhone may show connected even when access was denied
- [ ] **Background sync:** No iPhone equivalent
- [ ] **Background sync:** The snapshot isn't shown anywhere; the real sync runs when the app opens

### Reminders & alarms (13/17)

- [x] **Reminders list:** Unticked daily reminders stay in Overdue — _Overdue → Catch up → Skip all sends every repeating reminder to its next time (recorded as skipped) in one tap. They still wait until you do something; nothing is skipped for you_
- [x] **Reminders list:** Swipe delete has no confirm or Undo — _delete is in the card menu and can be undone_
- [ ] **Reminders list:** Not cloud-synced
- [x] **Add or edit a reminder:** No pause, end date or occurrence limit in the form — _Ends and Pause controls added to the form_
- [x] **Add or edit a reminder:** Repeats from Smart Add can't be edited here — _the form says what the repeat is ("Every 3 days", "Every other week" with the weekday beneath) instead of "Does not repeat", and a stepper moves it further apart or closer together, keeping the weekday, a count and an end date; "Use a standard repeat instead" swaps it for the dropdown, pre-selecting the closest standard repeat_
- [x] **Smart Add:** Those rule-based repeats complete after the first tick — _a repeat is a repeat whether it came from the form or a rule; a repeat past its end date is finished by the tick instead of being "rolled" to its own old time_
- [x] **Escalation:** Quiet and Normal behave the same (both make sound) — _a Quiet reminder has a channel of its own: no sound, no vibration, low importance, never full-screen — a Normal one is an ordinary notification. It carries Done and Later, and a Quiet reminder put off to Later comes back quiet (it used to return as a full-screen alarm). iPhone: no sound either_
- [ ] **Escalation:** Follow-ups are Android only
- [x] **Categories:** Starter categories can be deleted — _Personal, Work and Health are marked Default, are not swipe-deletable, and the service refuses to delete them (the seed never set the flag, so existing installs are covered by id)_
- [x] **Categories:** Categories aren't in backups — _reminder categories ride in the backup and are restored by id; the starter three (Personal, Work, Health) are never wiped by a restore. "Delete all data" now also removes the categories you made_
- [x] **Full-screen alarm:** No Done button for general reminders — _"Mark done" on the alarm for a reminder you made (not on a medicine or the wake alarm): the same completion the list's tick and the notification's Done use_
- [x] **Notification buttons:** iPhone: general reminders have no buttons — _a reminder you made now carries Done · Snooze · Later on iPhone (a registered category with Android's ids; previews hidden). Not seen on a device_
- [x] **Always re-armed:** Restoring a backup doesn't re-arm until the app restarts — _a restore now re-arms every reminder family straight away_
- [x] **Always re-armed:** Weekday reminders can clash with neighbouring reminder alarms — _a reminder that repeats on chosen days is armed under its slot and the seven after it, but slots were handed out one apart, so one reminder's Tuesday was the next one's slot and one of the two never fired. Slots are now a week of ids apart (125 reminders fit the reserved block), and reminders already given neighbouring slots are separated at the next start (the oldest keeps its place)_
- [ ] **Notification settings:** No quiet hours, max-snooze or missed-after setting — _PARTLY BUILT: "Snoozes allowed" (1, 2, 3 or 5) and "Mark as missed" with a wait of 30 minutes to 4 hours (or off) are on the Notifications screen, and both were already honoured by the alarm and the missed sweep. Not built: quiet hours_
- [ ] **Notification settings:** Main alarms ignore some of these switches
- [x] **Exact alarms:** Battery check is only offered from water reminders — _now also offered from the Today setup checklist_

### Diary (1/3)

- [ ] **Diary:** No mood, tags, photos or search — _mood, tags and search are built (see "Diary that resurfaces"); photos are not_
- [x] **Diary:** Entry date can't be changed — _the Entry details sheet sets the date and time, back to five years_
- [ ] **Diary:** Not cloud-synced

### Trends & insights (3/4)

- [ ] **Trends dashboard:** Only medicine changes refresh it live; other cards need pull to refresh
- [x] **Weekly recap:** Only reachable from the Health tab — _the Trends screen header now has a Weekly recap button_
- [x] **Weekly recap:** Retry fails in debug builds — _Retry no longer hands setState a Future_
- [x] **Insight engine:** 8 insights are worked out but never shown (trends and correlations) — _shown in the Patterns section on Trends_

### Settings, account & data (7/17)

- [ ] **Account:** Sign-out returns to onboarding
- [ ] **Account:** Delete account needs a sign-in within the last 5 minutes, with no re-sign-in step
- [ ] **Account:** Google sign-in needs the build's SHA-1 registered in Firebase
- [ ] **Appearance:** English only; no translations
- [x] **App lock:** App content shows in the recent-apps preview — _while App lock is on, the window is secure (Android FLAG_SECURE), so the task switcher shows nothing of the app — which also blocks screenshots, and the lock screen's footer says so. iPhone's app-switcher snapshot is NOT covered_
- [ ] **Export a copy:** The file isn't encrypted
- [x] **Backup & restore:** Needs an app restart after restoring — _a restore reloads Steps, Sleep, Heart and Period from what it wrote, so they show at once; both restore screens no longer ask for a restart_
- [x] **Cloud sync:** Runs once per app start; turning it on does nothing until then — _it also runs the moment it is switched on ("Cloud sync on — syncing now") and when the app returns after 30 minutes or more; both behind the same two gates (a real account and your own opt-in)_
- [ ] **Cloud sync:** Water: only today's entries upload
- [ ] **Cloud sync:** Not synced: reminders, vitals, diary, dose logs, doctors, appointments, family
- [ ] **Cloud backup:** Capped at 900 KB per backup
- [x] **Haptics:** Not included in backups — _the haptic settings are in the backup and restored with it_
- [x] **Delete all data:** Some focus data survives — _the Focus, coins, tag and relaxation singletons are reset in memory (they used to save their old data straight back) and the relaxation* preferences are removed_
- [x] **Delete all data:** With cloud sync on, data downloads again on the next start — _with sync on and an account, "Delete all data" asks how far to go: here and in the cloud (the cloud copy is deleted first, and a failure there stops before anything on the device is touched) or here only (sync is turned off before the wipe, and it says the cloud copy stays). Sync is never left on over an emptied device_
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

### Not built at all (2/12)

_Nothing in the code yet._

- [ ] oz and other imperial water units
- [ ] Do Not Disturb or app blocking during Focus
- [ ] 12 of 15 focus sounds, e.g. rain, ocean, forest, café
- [ ] Translations (English only)
- [ ] AI assistant or chat (removed 12 Aug 2026)
- [ ] Subscriptions or in-app purchases
- [ ] iPhone background health sync
- [ ] Mindful minutes to Apple Health
- [x] Heart-rate charts — _resting HR (and HRV, SpO2, breathing) charts, and an hourly "Heart rate by hour" card_
- [x] Manual workout entry — _see "Workouts: No manual entry and no detail view"_
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


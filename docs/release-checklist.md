# Release checklist — owner actions

Four things block release and none of them are code. Do them in this order: the
privacy policy URL is an input to both Play Console forms, and the Apple step
breaks iOS builds until it is finished.

Your real values, so you can copy them:

| | |
|---|---|
| Android package | `com.dlyminder.app` |
| iOS bundle id | `com.implementation.tabletremainder.tabletRemainder` |
| Firebase project | `remedly-86882` |
| Store name | Dlyminder |

---

## 1. Privacy policy

A draft written against what the app actually does is in
[`docs/privacy-policy.md`](privacy-policy.md). It has four `[PLACEHOLDER]`
fields and one compliance note to read before you publish.

### 1a. Finish the draft

Replace `[ENTITY NAME]`, `[CONTACT EMAIL]` (twice) and `[DATE]`. Read the
Advertising section carefully — it commits you to never using health data for
ads, which is a Google Play requirement, not a nicety. I verified the code
currently honours it (`AdRequest()` is bare and the ad service imports no health
code), but it is a commitment you have to keep.

### 1b. Host it at a public URL

You already pay for nothing here — Firebase Hosting on `remedly-86882` is the
natural home:

```bash
# once
npm install -g firebase-tools
firebase login

# in the repo
mkdir -p public
# convert the markdown to a simple HTML page at public/privacy.html
firebase init hosting        # public dir: "public", single-page app: No
firebase deploy --only hosting
```

That gives you `https://remedly-86882.web.app/privacy.html`.

GitHub Pages works equally well if you prefer. What matters is that it is
public, stable, and reachable without a login.

### 1c. Wire the URL into the app

```dart
// lib/core/config/env_config.dart
static const String privacyPolicyUrl = 'https://remedly-86882.web.app/privacy.html';
```

The in-app link is hidden while this is empty, so nothing breaks before you set
it — but the app cannot pass review without it.

### 1d. Byte-identical in three places

This is the part that fails reviews. The same string, character for character,
must appear in:

1. `EnvConfig.privacyPolicyUrl`
2. Play Console → **Policy → App content → Privacy policy**
3. The page's own canonical URL

`https://x.com/privacy` and `https://x.com/privacy/` are **different**. So are
`http` and `https`, and `www.` and bare. Pick one and paste it everywhere.

Verify after: open Health Connect → App permissions → DlyMinder → the privacy
policy link. It must land on the disclosure screen inside the app, which then
links out to the same URL. (The routing for that shipped in `a389029`.)

---

## 2. Health apps declaration form

**Play Console → Policy → App content → Health apps → Start.**

Mandatory for **every** track, including internal testing. Without it, Play will
not let you publish or update.

### What to select

Page one asks which health features the app offers. For DlyMinder, tick under
**Health and fitness**:

- Activity tracking (steps, exercise)
- Sleep
- Period tracking

and under **Medical**:

- Medication management

Do not tick disease management or clinical decision support — the app gives no
diagnosis or treatment guidance, and claiming those invites scrutiny you cannot
satisfy.

### Per-permission justifications

Page two asks you to justify each Health Connect data type in a text box. The
rule Google applies: **the justification must point at a feature a reviewer can
see in the app.** Generic wording ("to improve the user experience") gets
rejected.

The table below has 22 health permissions. (`WRITE_MINDFULNESS` and
`READ_HEALTH_DATA_IN_BACKGROUND` are declared too and still need rows — see
the Focus section.) Copy these:

| Permission | Justification |
|---|---|
| `READ_STEPS` | Populates the Steps tracker and its daily/weekly charts so the user does not re-enter step counts their phone or watch already recorded. |
| `READ_DISTANCE` | Shown alongside steps on the Steps dashboard. |
| `READ_ACTIVE_CALORIES_BURNED` | Shown alongside steps on the Steps dashboard. |
| `READ_SLEEP` | Populates the Sleep tracker — duration, stages and the sleep score — and times reminders around the user's real sleep schedule. |
| `READ_EXERCISE` | Lists the user's workout sessions with duration, distance and calories. |
| `READ_HEART_RATE` | Daily heart-rate range on the Heart screen, and average/max heart rate per workout. |
| `READ_RESTING_HEART_RATE` | Resting heart-rate trend on the Heart screen. |
| `READ_HEART_RATE_VARIABILITY` | Nightly HRV trend and the user's own HRV baseline on the Heart screen. |
| `READ_OXYGEN_SATURATION` | Daily blood-oxygen range on the Heart screen. |
| `READ_RESPIRATORY_RATE` | Daily breathing-rate range on the Heart screen. |
| `READ_BODY_TEMPERATURE` | Shown with the user's other vitals. |
| `READ_SKIN_TEMPERATURE` | Nightly skin-temperature trend shown with the user's other vitals. |
| `READ_WEIGHT` | User-initiated import of weight readings logged by a smart scale or another app into the Weight tracker. Never read in the background. |
| `READ_BLOOD_PRESSURE` | Optional, off by default: when the user switches on "Readings from other apps" in Vitals settings, blood-pressure readings their cuff app saved to Health Connect appear in the Blood Pressure tracker, marked as imported. This app's own records are skipped. |
| `READ_BLOOD_GLUCOSE` | Optional, off by default: same, for blood sugar from a meter app. |
| `WRITE_BLOOD_PRESSURE` | Optional, off by default: writes blood-pressure readings the user logged in DlyMinder back to Health Connect so their other health apps can see them. |
| `WRITE_BLOOD_GLUCOSE` | Optional, off by default: same, for blood sugar. |
| `WRITE_WEIGHT` | Optional, off by default: same, for weight. |
| `READ_HYDRATION` | Optional, off by default: when the user switches on "Count drinks from other apps" in the Hydration profile, drinks they logged in another app (Samsung Health, Fitbit, a smart-bottle app) are counted toward the day, so the total is their real intake rather than only what they entered here. This app's own drinks are skipped, and what comes in is never written back. |
| `WRITE_HYDRATION` | Optional, off by default: writes each drink the user logs in DlyMinder (amount and time) back to Health Connect so Samsung Health, Fitbit and their other apps can see it. |
| `READ_MENSTRUATION` | User-initiated import of past period days from Health Connect into Cycle history, so the predictions start with real history. Read only, never in the background, and never written back. |
| `READ_HEALTH_DATA_HISTORY` | Health Connect only shows an app the 30 days before it was first granted access. Needed so the same Cycle import can reach the user's past periods (up to two years) rather than one month. Requested only when the user taps Import. |

> The Heart and Workouts screens these justifications name now exist and are
> reachable from the Health tab, so this form is ready to submit — **once the
> privacy policy URL from step 1 is live**, since the form asks for it.

> **Hydration is new and gates the Water feature's headline integration.**
> Declaring `READ_HYDRATION`/`WRITE_HYDRATION` in the manifest is not enough:
> without them on this form, users hit "your app can't access the Health
> Connect data types because they require special approval" and the toggle in
> Water → Hydration Profile → Health Connect silently never writes. The
> declaration is mandatory for **every** track, including closed and open
> testing. The in-app toggle is off by default, so nothing breaks before the
> form is approved — the feature is simply unavailable.

---

## 3. Data safety form

**Play Console → Policy → App content → Data safety → Start.**

Five steps: Overview → Data collection and security → Data types → Data usage
and handling → Preview → Submit.

### Data collection and security

| Question | Answer | Why |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes** | Cloud sync and AdMob both transmit data off-device. |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | Firebase and AdMob are HTTPS-only. |
| Do you provide a way for users to request that their data is deleted? | **Yes** | Settings → Clear all data, plus account deletion. |

Note the definition of *collect*: data leaving the device. Data that only ever
sits in the on-device database is **not** collected and must not be declared.
Since cloud sync is optional, every health type below is **optional**, not
required.

### Data types to declare

| Category | Type | Collected | Shared | Purpose | Optional? |
|---|---|---|---|---|---|
| Health and fitness | Health info | Yes | No | App functionality | Optional |
| Health and fitness | Fitness info | Yes | No | App functionality | Optional |
| Personal info | Name, Email address | Yes | No | App functionality, Account management | Optional |
| App activity | Other user-generated content | Yes | No | App functionality | Optional |
| Device or other IDs | Device or other IDs | Yes | **Yes** | Advertising or marketing | Required |

The last row is AdMob. It is the only **shared** row, and health data must never
appear in it.

**Health info** covers blood pressure, blood sugar, weight, mood, menstrual
cycle and the vitals above. **Fitness info** covers steps, distance, calories,
sleep, exercise, heart rate and HRV. Google splits these, so declare both.

Do **not** declare: Photos (the prescription scan is on-device only and never
uploaded), Location (the app requests none), or Analytics (there is no analytics
SDK).

---

## 3b. Register the iOS App Group (gates the iOS water widget)

The `WaterWidget` extension shares data with the app through an App Group, and
an App Group is a **provisioned capability** — the entitlement is declared in
both `ios/Runner/Runner.entitlements` and
`ios/WaterWidget/WaterWidget.entitlements`, but it cannot be signed until the
group exists on the account.

**Apple Developer → Certificates, Identifiers & Profiles → Identifiers → App Groups → +**

- [ ] Create the group with **exactly** this identifier:
      `group.com.implementation.tabletremainder.tabletRemainder`
- [ ] Add it to the `com.implementation.tabletremainder.tabletRemainder` App ID
- [ ] Create an App ID for the extension,
      `com.implementation.tabletremainder.tabletRemainder.WaterWidget`, and add
      the same group to it
- [ ] Set the development team on both targets in Xcode (the project has none
      set, so signing is unresolved until you do)

Until this is done the widget target still **compiles** — verified with
`xcodebuild -target WaterWidget -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO`,
which reports BUILD SUCCEEDED — but a signed build will fail, and a running
widget would read an empty container. If the group identifier changes, three
places must change together: both entitlements files and `_appGroupId` in
`lib/core/services/home_widget_service.dart` (which must also match
`appGroupId` in `ios/WaterWidget/WaterWidget.swift`). A guard test pins all four.

---

## 4. Enable HealthKit on the iOS App ID

**Order matters. Do the portal first, or every iOS build fails to sign.** The
entitlement is already wired into all three build configurations, so the app
binary now claims a capability the provisioning profile does not yet grant.

1. Sign in at [developer.apple.com/account](https://developer.apple.com/account)
   → **Certificates, Identifiers & Profiles** → **Identifiers**.
2. Open `com.implementation.tabletremainder.tabletRemainder`.
3. Tick **HealthKit**. Leave *Clinical Health Records* unticked — the app does
   not use it, and the empty `healthkit.access` key was deliberately removed.
4. **Save**, and confirm the "Modify App Capabilities" warning. This invalidates
   the existing provisioning profiles, which is expected.
5. **Profiles** → regenerate both the Development and the App Store
   distribution profile for that App ID → Download.
6. In Xcode, either double-click each downloaded profile, or use *Signing &
   Capabilities* with **Automatically manage signing** ticked and let Xcode
   refresh them.

Verify:

```bash
grep -c ENTITLEMENTS ios/Runner.xcodeproj/project.pbxproj   # expect 3
flutter build ios --debug --no-codesign                      # compiles
flutter build ipa                                            # real signing test
```

Do **not** run `flutter clean` before an iOS simulator run — it breaks
CocoaPods and surfaces an MLKit conflict.

---

## Also outstanding

Not blocking the forms, but blocking a real release:

- **AdMob still uses Google's test IDs.** `ios/Runner/Info.plist` has
  `ca-app-pub-3940256099942544~1458002511`, the public test app ID, and the
  Android one comes from a `ADMOB_APP_ID_ANDROID` Gradle property. Shipping
  with test IDs means zero revenue; shipping with a real ID in a debug build
  risks an AdMob policy strike.
- **Firebase console:** register the release keystore's SHA-1, or Google
  Sign-In fails with `ApiException: 10`.
- **Deploy the Firestore rules before the client build** that writes the new
  collections — `firebase deploy --only firestore:rules`. Otherwise every write
  is denied and the sync code swallows the error silently. **This now includes
  `focus_sessions`** (added at schema v15); `firestore.rules` is default-deny, so
  without the deploy every focus session upload fails and `syncLwwCollection`
  logs it and moves on.
- **Nothing here has run on a real device.** Health Connect is mobile-only, so
  the permission sheet, the rationale deep link and any real sync are still
  unverified.

## ✅ Mindfulness write-back: compiled, and it was broken

**Resolved.** `MindfulnessChannel.kt` was written without ever being compiled
(the note below explains why) and it **did not compile**. It carried
`@OptIn(ExperimentalMindfulnessSessionApi::class)` plus the matching import, and
that annotation does not exist in
`androidx.health.connect:connect-client:1.2.0-alpha02` — the AAR ships only
`ExperimentalDeduplicationApi` and `ExperimentalPersonalHealthRecordApi`.
`MindfulnessSessionRecord` itself is present and needs no opt-in at this version.

Three unresolved-reference errors, and because Kotlin compiles the whole module
they failed `:app:compileDebugKotlin` outright — **no Android build of this app
could succeed at all**, for any feature. The suspicion recorded here was correct;
it just needed the compiler actually run against it.

The JDK was there all along, just not on `PATH`:

```bash
export JAVA_HOME=~/android-sdk/jdk/Contents/Home
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_SDK_ROOT=~/android-sdk
cd android && ./gradlew :app:processDebugResources :app:compileDebugKotlin
```

That now reports BUILD SUCCESSFUL, and it is the command to run before any
Android build or after touching anything under `android/`.

Two dependencies were added to `android/app/build.gradle.kts` specifically because
of a trap worth knowing: the `health` plugin pulls in both
`androidx.health.connect:connect-client` and the coroutines library with
`implementation(...)`, which places them on our RUNTIME classpath and deliberately
keeps them off our COMPILE classpath. Assuming they were inherited would have been
a build error waiting for whoever added the next native health call, so both are
now declared explicitly. If the compile fails, that is the first place to look —
followed by the exact `MindfulnessSessionRecord` constructor signature, which is
still marked experimental upstream and may shift between connect-client versions
even though this version needs no opt-in annotation.

Then, on a device with a recent Play System Update:

- [ ] **The toggle appears at all.** Focus reminder settings → "Save mindful
      minutes". If `FEATURE_MINDFULNESS_SESSION` is unavailable the row is hidden
      by design, so its absence is not necessarily a bug — check `isAvailable`
      first. It must be probed BEFORE any permission request: Health Connect
      refuses the whole permission sheet if one requested type is unsupported,
      which would break the permissions the app genuinely needs.
- [ ] **Only WRITE_MINDFULNESS is requested**, never READ.
- [ ] **A completed breathing exercise appears** in Health Connect; one closed
      early does not.
- [ ] **A work session does NOT appear.** This is the point of the feature, not a
      limitation of it — Forest writes every focus session to Apple Health as
      Mindful Minutes, and a coding sprint filed as mindfulness practice is a
      false claim in a record the user may show a clinician.
- [ ] **Revoking the permission in the Health Connect app** bounces the toggle
      back off on next open rather than leaving it stuck on and silently writing
      nothing.
- [ ] `docs/release-checklist.md`'s per-permission justification table needs a
      `WRITE_MINDFULNESS` row, and the declared-health-permission count updating.

## First-run setup: device checks no test can cover

- [ ] **The health pane asks for the right permissions.** On a fresh install with
      Health Connect present, the third pane "Bring in your health data" shows
      *Connect Health Connect*: it opens the Health Connect consent sheet for steps
      and sleep (and distance and active calories), the same one Today's setup
      checklist opens. Deny it: the pane says "Not connected" and Continue still
      works. With Health Connect missing or out of date there is no such pane.
- [ ] **The daily check-in fires at the time chosen.** Pick a time two minutes
      ahead on the reminders pane, tap Turn on reminders, lock the phone: the
      "Daily check-in" notification arrives. Then Settings → Notifications → Daily
      check-in: move the time, and switch it off; nothing arrives after.
- [ ] **Declining the notification prompt leaves the check-in off.** On Android 13+,
      tap Turn on reminders and *Don't allow*: Settings → Notifications shows Daily
      check-in **off**, and switching it on asks again (or, if the phone will not
      ask twice, says notifications are off for DlyMinder). It is never "on" over a
      notification that cannot appear.

## Step sensor: device checks no test can cover

- [ ] **A phone with no Health Connect.** Steps → the card offers *Count with this
      phone's sensor*; tapping it shows the Android "Physical activity" prompt, and
      after Allow the number moves as you walk — without leaving the screen. Deny
      it and the card stays, with where to allow it. (On Android 9 and older there
      is no such prompt: the sensor works, and the offer never appears.)
- [ ] **A device with no step counter at all** (some tablets). The card is offered on
      the permission alone — nothing asks whether the hardware exists — so there the
      number stays at zero after Allow, and the card has promised a count it cannot
      make. Check what Steps shows and whether Allow leaves it saying "Counting steps
      with this phone's sensor". Known gap; the fix is to ask Android for the step
      counter feature before offering (native) or to say so when the sensor stream
      errors on the first read.
- [ ] **Allowed in Settings, then back.** Deny it, follow the toast to Settings →
      Apps → DlyMinder → Permissions, allow Physical activity, return: the offer goes
      and the number starts to move without reopening Steps.
- [ ] **iPhone: the offer is not made, and the count still works.** Android-only
      on purpose: `permission_handler` answers "denied" to every Motion & Fitness
      question unless the Podfile defines `PERMISSION_SENSORS=1`, and it does not,
      so asking would show the card to everyone and send them to Android's route.
      The pedometer raises the system prompt itself on first read — confirm that it
      does on a fresh install, and that denying it leaves Steps at zero with no
      card. Adding the macro (and `NSMotionUsageDescription`, already present) and
      checking `Permission.sensors.status` on a device would let the card explain a
      denial on iPhone too; that is the follow-up, not a blocker.

## Encrypted backup: device checks no test can cover

The cipher is tested against published vectors and the flows against fakes. A real
device is the only place to see how long the key derivation takes and that the
picker offers the file.

- [ ] **How long "Create encrypted backup" takes** on the slowest phone you support.
      The key comes from 600,000 rounds of PBKDF2 in pure Dart on a background
      isolate; the button shows its spinner for that long. If it is over about ten
      seconds, lower `BackupEncryption.defaultIterations` — the count is in each
      file, so older backups still open.
- [ ] **The picker offers a `.dlyenc` file.** Share one to yourself (Drive, Files),
      then Backup & Restore → Restore from file: it must be selectable, ask for the
      passphrase, say "did not open" for a wrong one and ask again, and restore with
      the right one. A plain ZIP still restores without a question.
- [ ] **Opened elsewhere, not readable.** Open the `.dlyenc` in a text or archive
      app: it must look like noise and must not contain a medicine name.

## Reading from the health store: device checks no test can cover

Four things read data that another app wrote — past periods, blood pressure,
blood sugar and drinks. The headless suite proves the logic around the read
(which samples count, that this app's own records are skipped, that nothing is
added twice, that a deleted reading stays deleted) by handing it samples. It
cannot prove what Health Connect or HealthKit actually returns. On a real device
with a cuff or meter app, a hydration app and a cycle app that write to the store:

- [ ] **Past periods (Cycle → Import from Health Connect).** On Android 14+ it
      asks twice: the menstruation read, then "allow access to past data". Deny
      the second and the import must say it only reached about the last 30 days.
      Imported days appear in Cycle history; Undo removes exactly them. A flow the
      cycle app recorded with no level imports as Medium.
- [ ] **A cuff reading appears by itself** (Vitals reminders → Readings from other
      apps → on). Take a reading on the cuff, open DlyMinder: it is in Blood
      pressure, marked "from Health Connect", with the cuff's time.
- [ ] **Its own writes do not come back.** Turn on *Share with Health Connect*,
      log a reading here, then open the app again: there is still ONE reading, not
      two. Same for a blood sugar, a weight imported from the Weight screen, and a
      drink. This is the check that `HealthSampleOrigin` recognises what the platform
      stamps on this app's writes — the test pins the ids to the build files and
      feeds it both platforms' shapes (iPhone: the bundle id in `sourceId`; Android:
      `sourceId` empty and the package in `sourceName`, per the plugin's source), but
      only a device shows the platform agrees. On Android check the weight in
      particular: it has no same-number-same-minute check behind it.
- [ ] **A typed-in reading is not doubled.** Enter 128/82 here and let the cuff app
      write the same reading a minute apart: one stays.
- [ ] **Delete it and it stays deleted.** Swipe an imported reading away, force-stop
      and reopen: it does not return.
- [ ] **Drinks (Hydration profile → Count drinks from other apps).** Log 350 ml in
      Samsung Health / Fitbit: it appears in Today's Log as Water, marked from
      Health Connect, and the Water screen's total includes it. It must NOT then
      appear a second time in the other app (no write-back).
- [ ] **Read access alone is asked for, and is enough.** Turn Readings from other
      apps on: the Health Connect sheet lists only *reading* Blood pressure and
      Blood glucose — no writing, no weight (Count drinks from other apps: reading
      water). Allow it and the switch goes on and the readings come in; refuse it
      and it stays off. Turn *Share with Health Connect* on afterwards and a second
      sheet asks to write — one sheet per feature, each asking only for what it
      does. On iPhone the Health sheet shows the same read-only list; iPhone never
      says whether read was allowed, so "got through the sheet" is what is
      remembered, and a switch that is on stays on until the person turns it off.
- [ ] **Allowing only some of them.** Health Connect grants each type on its own.
      In the sheet for Readings from other apps, allow *Blood pressure* and refuse
      *Blood glucose*: the switch goes on, a cuff reading comes in, and no "did not
      share your readings" message appears. Do it the other way round (glucose only).
      Refuse both and the switch stays off.
- [ ] **Turning it off while it is reading.** With a long history in Health Connect
      (90 days of a glucose monitor is the slowest), turn Readings from other apps
      on and, while it is still working, switch it off. Nothing new appears after the
      switch is off; switching it on again reads the whole first window again, and
      what was already brought in is not doubled. Same for Count drinks from other
      apps. "Delete all data" while a first read is running leaves nothing behind.
- [ ] **Health Connect updating, or not answering, does not switch anything off.**
      With Readings from other apps on, open Vitals reminders while Health Connect
      is being updated (or force-stopped): the switch stays on and no "stopped"
      notice appears. Only a platform that says *no* — the permission revoked in
      Health Connect — switches it off.
- [ ] **A continuous glucose monitor.** With a Libre or Dexcom app writing to
      Health Connect (a reading every few minutes), turn Readings from other apps
      on: up to 90 days arrive at once on iPhone — about 26,000 readings — and about
      30 days on Android (about 8,600), because Health Connect gives an app only the
      last month before its first grant unless it holds `READ_HEALTH_DATA_HISTORY`,
      which this import does not ask for. Confirm the import
      finishes without freezing the app, then delete a reading from six days ago,
      wait an hour, reopen: it stays deleted. **Open product question:** a manual
      tracker is not built for that volume (the list, the report and the patterns
      all read every row); whether to thin monitor data to one reading per N
      minutes is a decision for the owner, not something to do silently.
- [ ] **Revoke the permission in Health Connect.** Reopen Vitals reminders / the
      Hydration profile: the switch is off, and Vitals says why.
- [ ] **Disconnect (Connected devices → Disconnect Health Connect).** On Android,
      confirm, then open Health Connect → App permissions → DlyMinder: it must have
      NO permissions left (this is `revokePermissions`, which needs Health Connect
      14+; on an older provider the toast says to do it by hand). Health Connect may hand
      them back only when DlyMinder is closed rather than at that moment; if the
      screen still finds them held, the toast says "takes its access away completely
      when DlyMinder is closed — or you can take it away yourself in Health Connect →
      App permissions" instead of "Disconnected" — close the app and look again. If
      they are STILL there, Health Connect refused (the plugin cannot say so): remove
      them by hand, as the toast says. Reopen Vitals
      reminders and the Hydration profile: every Health Connect switch is off. The
      steps, sleep and readings already in DlyMinder are all still there. On iPhone
      nothing can be revoked from the app: the toast must name Health → Sharing →
      Apps → DlyMinder, and the Disconnect row switches the in-app features off.
      Focus → *Save mindful minutes* is off too: finish a breathing exercise and
      nothing is written to Health Connect.
- [ ] **Nothing runs when the switches are off.** With all of them off, no read of
      blood pressure, blood sugar or water is made at app start.

## Focus: device checks no test can cover

Notification *delivery* is an OS behaviour. The headless suite asserts the calls,
the channel, the ids and the reminder-migration contract, but only a device can
prove any of it arrives. These are quick and each one guards a defect that
shipped:

- [ ] **Focus notifications are not alarms.** Complete a short session with the
      app backgrounded. The banner must appear under *Settings → Notifications →
      **Focus Sessions***, at notification volume, with **no** Snooze/Dismiss
      buttons and **no** full-screen takeover. Before this work it arrived on
      *Alarm Reminders*, on the alarm audio stream, through Do Not Disturb.
- [ ] **The ambient sound stops when the phase ends, with the app away.** Start a
      1-minute session with Rain, lock the phone or switch apps, and wait. The rain
      must stop at the minute, not when you come back. This is a timer set for the
      end instant while the ticker is stopped, so it depends on the OS keeping the
      app alive while audio plays — true on Android with a media session and on iOS
      with the audio background mode; this is the check that it holds on the device.
- [ ] **A long session's unlocks all arrive.** Complete a 240-minute session on a
      fresh install (or set the clock): each plant it unlocks and each achievement
      it earns must show as its own notification, not one banner that kept being
      replaced. "Session complete" is not wiped by them.
- [ ] **The reminder migration actually fires.** This needs an **upgrade**, not a
      fresh install — a clean install has nothing to migrate. On a build from
      before this change, turn the daily focus reminder on and confirm it fires as
      a full-screen alarm with a `✓ Take` button. Then install the new build,
      launch it once, and confirm the same reminder now arrives as a quiet
      heads-up on *Focus Sessions*. `FocusService.init()` runs the migration
      unawaited on the startup path, so one launch is enough.
- [ ] **Do Not Disturb is respected.** Turn DND on, finish a session, confirm
      silence. The old `alarm_channel` route rang regardless.
- [ ] **The migration does not claim success when it cannot run.** Deny
      notification permission, launch once, grant permission, launch again — the
      reminder must be scheduled by the second launch. The flag is only written
      after the teardown succeeds, so a failed attempt retries.
- [ ] **Relaxation completion** uses the same calm channel — it had the identical
      defect and was fixed in the same pass.

### Leaving the app mid-round is noticed

`FocusService` is told the app went to the background (`hidden`, then `paused`) and
came back (`resumed`). The headless suite sends those in the order the framework
documents; only a device shows they arrive that way. There is nowhere in the app
that lists what was noticed, so these read the log — `adb logcat -s flutter | grep
"drift noticed"`:

- [ ] **Home button.** Start a 25-minute round, press Home at ~12 minutes, come back
      a minute later. One line: `Focus drift noticed: minute 12 of 25`.
- [ ] **Power button.** The same, but lock the screen instead of leaving the app.
      The same line — the phone cannot tell the two apart, which is why the card's
      "Why this?" says so.
- [ ] **Screen timeout.** Start a round, put the phone down, let the screen time
      out and wake it at ~15 minutes. A line appears for the timeout minute only if
      that is ten minutes or more in; with a 30-second timeout there must be none.
- [ ] **Not counted:** back within 5 seconds (open the notification shade and a
      permission dialog); away for more than 10 minutes; back after the round
      ended; leaving while paused; leaving during a break; a Flow (count-up)
      session; leaving in the first ten minutes. No line for any of them.
- [ ] **Switching apps with a gesture** (Android 13+ gesture navigation, iOS app
      switcher) produces exactly one line, not two — `hidden` and `paused` both
      arrive and only the first counts.
- [ ] **The card.** Repeat the Home-button check on five different days (the date
      can be moved forward between rounds), around the same minute. "You often step
      away around minute 12 — Try 10 + 5" appears on the resting Focus screen;
      "Try 10 + 5" sets Pomodoro 10 + 5 and offers Undo; Dismiss makes it go and
      stay gone. Session setup → "Notice when I step away" off clears it.

### The armed completion notification

`FocusSessionAlarm` makes the arm/disarm *decisions* assertable headlessly — 12
cases cover arming at phase start, re-arming against the pushed-forward end time
after a pause, the foreground pre-emption, and the double-announce guard. None of
them can prove the OS delivers. These can:

- [ ] **It arrives when you are away.** Start a 2-minute session, background the
      app, lock the phone. The banner must appear at T+2:00 on *Focus Sessions* —
      and **no second banner** when you unlock. The second half is the real test:
      once completion can be delivered in the background, the resume path is one
      missing guard away from announcing again.
- [ ] **It does NOT arrive when you are watching.** Run a session to zero with the
      Focus screen open. You should get the in-app celebration and no system
      banner. AlarmManager can fire exactly at the end time while the 1 Hz ticker
      reaches it up to a second later, so the app disarms in the final three
      foreground seconds.
- [ ] **Leaving in those last seconds still works.** Background the app with ~2
      seconds left; the banner must still arrive.
- [ ] **Doze.** `adb shell dumpsys deviceidle force-idle`, screen off, confirm a
      25-minute session's ping still lands close enough to be useful.
      `USE_EXACT_ALARM` was deliberately dropped, so on Android 14+ this is
      expected to fall back to inexact — a few minutes late is acceptable here and
      would not be for a dose.
- [ ] **The fallback does not touch the medicine warning.** After a session on a
      device where exact alarms are denied, confirm the app is *not* showing
      "your medicine reminders are inexact". The focus path goes through
      `_notifications` directly and never
      `BackgroundAlarmService.exactAlarmsDowngraded()`, so this should be
      impossible — worth one look.
- [ ] **Reboot mid-session.** Start a long session, reboot, confirm the app
      recovers the session (`ScheduledNotificationBootReceiver` is already
      declared, so the pending notification should survive too).

## Alarms and hand-offs: device checks no test can cover

Android decides what a notification looks like and whether a tap reaches the app;
the headless suite asserts what the app *asks for*. These are the one-minute
checks that the platform does what was asked.

- [ ] **Vibration off silences a medicine alarm.** Settings → Notifications →
      Vibration off, then let a dose alarm ring (a test dose two minutes out). It
      must ring on the alarm sound and **not** vibrate. Switch Vibration back on
      and the same alarm buzzes. The same switch has to hold after tapping Snooze
      or Later: the re-fire is a separate notification. On Android 8+ vibration is
      a property of the notification *channel*, so Vibration off posts to a twin
      channel — the phone's notification settings then list **"Medicine Reminders
      (no vibration)"** (and "Alarm Reminders", "Check-ins & Nudges", "Water
      Reminders", "Sleep & Bedtime", "Step Reminders" and "Focus Sessions", each with
      "(no vibration)") beside the originals, created the first time something is
      posted with the switch off. A reminder of each kind — a dose follow-up ("Still
      time for X"), a water reminder, a bedtime reminder, a step nudge, a finished
      focus round, a caregiver "missed a dose" ping — must be silent with the switch
      off. Confirm they appear, and that Vibration back on
      returns to the original channels with whatever you set there. **Known limit:**
      a twin starts from the app's defaults, so anything you changed on the original
      in the phone's settings (muted it, picked another sound, let it through Do Not
      Disturb) does not follow you to the "(no vibration)" one — set it there too.
      Android offers no way to change a channel's vibration after it exists; the
      alternative, deleting and recreating the original each time the switch moved,
      would discard those same settings on every change.
- [ ] **Vibration off also holds for the last notification of a missed dose.**
      Set the snooze limit to 1, snooze a dose once, then again: the "snooze limit
      reached" notification must not vibrate with Vibration off. (It used to be the
      one that still buzzed.)
- [ ] **Changing how alerts look reaches reminders already waiting.** Make a weekly
      reminder (anything that is not daily), then switch Vibration off in Settings →
      Notifications. Without reopening the app, let it ring: no vibration. The
      screen re-arms every reminder when Vibration, Keep on screen or Full-screen
      alerts changes.
- [ ] **The pill's look is on the reminder.** Give a medicine a colour and a shape
      (Add medicine, step 4), let its dose ring: the notification line ends
      "· white, round", on the full-screen alarm too, and as a line of its own for
      each medicine in a grouped reminder. A medicine with neither set reads as it
      always did. (iPhone: the same line.)
- [ ] **Full-screen alerts off.** The dose arrives as a heads-up notification, not
      over the lock screen; it is still loud, still an alarm, still has Take.
- [ ] **Keep on screen off.** The dose notification can be swiped away; with it on
      (the default) it cannot, until you answer it.
- [ ] **Sound is not one of the three.** A channel's sound is fixed when it is
      created, so Sound off does not silence a medicine alarm — and the Alerts
      footer says so. Confirm the wording matches what you hear.
- [ ] **Take and Skip from a notification are not lost.** With the app closed, tap
      Take on a dose notification, then open the app: the dose is logged, once,
      and the stock went down by one dose. Do it for two medicines at the same
      time (a grouped alarm) and confirm both are logged. (The hand-off is now
      read, applied one at a time and only then forgotten, so a crash or a locked
      database mid-way leaves the rest queued; this is the end-to-end check.)
- [ ] **Directions.** A clinic with only an address shows **Directions**; it opens
      Google Maps (or the browser, if no maps app is installed) with directions to
      that address. On Android 11+ with Google Maps *uninstalled* it must still open
      the browser — `canLaunchUrl` answers false for web links there, which is why
      the launch is not gated on it. On an iPhone it opens Apple Maps.
- [ ] **Export reminder history.** Reminders → the share icon on the adherence card
      → a range → the share sheet offers a `.csv`; open it in a spreadsheet app. A
      reminder titled `=1+1` must show as text (with a leading apostrophe), not as
      `2`. A reminder titled `Café` or in Tamil or Hindi must read correctly **in
      Excel** (the file is UTF-8 behind a byte-order mark, which Excel needs to stop
      reading it as ANSI).
- [ ] **Trends follows the data.** Log a drink on the Water tab, switch to Trends:
      the Water card shows it without pulling to refresh. Do the same with a night
      of sleep, a blood pressure reading and a finished focus round.

## iPhone dose reminders: device checks no test can cover

An iPhone runs nothing when a notification fires, so which dose reminders to hold
is decided when they are armed (`IosDosePlan`). The tests assert what is asked of
the OS; these are the checks that the phone then does it. Use a physical iPhone, or
the simulator for the first three.

- [ ] **A once-a-week medicine reminds once a week.** Add a medicine on one
      weekday only, at a time a few minutes ahead if that is today. It fires then,
      and a week later, and not on the six days in between. This used to remind
      every day.
- [ ] **Every-3-days and on-and-off cycles skip the days between.** Add one of
      each starting today. Over the next week it reminds only on the due days. A
      course with an end date stops reminding the day after.
- [ ] **A plain daily medicine is unchanged.** Still one reminder a day at its time,
      repeating, with the Take / Snooze buttons.
- [ ] **The ones that are armed per dose run out, and are armed again.** An
      every-X-days, cycle or end-dated medicine is armed for its next doses (24
      notifications at most for one medicine, and the phone keeps 64 in all). They
      are armed again at every start of the app and, if the app has stayed in the
      background, when it comes back to the foreground more than twelve hours after
      the last time. Check: with an every-other-day medicine, never force-quit the
      app, only background it and bring it back each morning for two weeks — the
      reminders must keep arriving on the due days past the end of the first batch.
      **Known limit:**
      a person who does not open the app for as long as the armed doses last (about three to seven weeks for an every-other-day medicine taken once or twice a
      day, as little as a day or two for a course of hourly doses) will not be reminded after that.
- [ ] **A reminder that is armed for a dose still opens the right dose.** Tap one
      of the per-dose reminders: it opens the dose for that medicine and time, and
      Take logs it.

## Photos, pharmacies and the care team: device checks no test can cover

The tests replace the camera, the gallery and the app's storage folder with doubles.
These are the checks that the real ones behave. Use a physical Android phone and an
iPhone; the simulator has no camera.

- [ ] **The camera and the gallery both attach a photo.** On a medicine (last step
      of the form → Photo), on a diary entry (Add a photo) and on a family profile
      (tap the picture at the top of Edit profile): take one with the
      camera, then another from the gallery. Each shows as a thumbnail; tapping it
      opens the picture larger (a profile's shows in the circle, and in Family &
      caregivers). If a permission prompt appears, its wording says
      the photo is for a medicine, a diary entry or a family profile (iOS: `NSCameraUsageDescription`,
      `NSPhotoLibraryUsageDescription`), and refusing it leaves the form as it was,
      with no error.
- [ ] **The photo is a copy.** Attach a gallery picture, then delete the original
      from the gallery app. The photo is still there in DlyMinder.
- [ ] **A photo survives a restart.** Save the medicine and an entry with photos,
      force-quit, reopen: both are still shown, in the list and on the detail screen.
- [ ] **Replacing, removing and deleting free the file.** Replace a photo and save,
      remove one and save: the old file goes at once. Delete a diary entry that has
      one and tap Undo: the photo is still there. Delete it again, let the toast go,
      force-quit and reopen: now it is gone. A deleted medicine's photo goes the same
      way, at the next start. Check the phone's storage
      for the app (Settings → Apps → DlyMinder): it does not grow by a picture each
      time. (A photo picked and abandoned without saving is also deleted, at the
      latest by the same check at the next start of the app.)
- [ ] **A denied permission is said, not silent.** Turn off the app's camera
      access in the phone's settings, then Take a photo on a medicine and on a
      diary entry: a message says the photo could not be added and where to allow
      it, and the form is as it was.
- [ ] **iPhone only: photos survive a restore to a new phone.** Restore an
      iPhone from a backup that held the app and some photos, or reinstall from an
      iCloud backup. The photos still show (the app's folder has a new path; photos
      are found by file name), and are still there after a restart and a day.
- [ ] **"Delete all data" deletes the photos.** With photos on a medicine and an
      entry, run it: after the restart there are none, and the app's storage is back
      to its starting size.
- [ ] **A backup does not carry the photos, and says nothing wrong.** Export a copy,
      restore it over the same app: the entries keep their photos. Restore it on a
      different phone: the entries come back with no photo and no error.
- [ ] **Pharmacies.** Add one with a phone number, link it to a medicine from the
      form, and open that medicine's refill errand: the Call button dials that
      pharmacy. Delete the pharmacy: the medicine's form shows Pharmacy as not set.
- [ ] **A doctor linked to a clinic follows it.** Add a clinic, choose it for a
      doctor ("Choose from my clinics"), rename the clinic: the Doctors list shows the
      new name. Delete the clinic: the doctor keeps the name it had, with no link.

## Reminder sounds, source choices and water sync: device checks no test can cover

The tests replace the audio player, the health store and Firestore with doubles. These
are the checks that the real ones behave.

- [ ] **A medicine's chosen sound loops on the alarm screen (Android).** Edit a
      medicine, set Reminder sound to something other than Default, save, and let its
      alarm fire with the phone locked: the full-screen alarm loops that sound, not the
      standard one. With two medicines due in the same minute and different sounds,
      the standard sound plays. Snooze it: the re-fire plays the same sound.
- [ ] **The sheet's preview plays the right file.** In the sound sheet, tap the play
      button on three different sounds: each plays its own, a second tap stops it, and
      closing the sheet while one plays stops it.
- [ ] **iPhone: a medicine's sound plays when the reminder is tapped.** The
      notification itself uses the system sound; tapping it opens the alarm screen,
      which loops the chosen one.
- [ ] **Notifications → Choose sounds (Android only).** The row opens DlyMinder's page
      in the phone's settings; Notifications there lists each kind of reminder with its
      own Sound. Changing the Water Reminders sound changes the next water reminder. On
      an iPhone the row is not there.
- [ ] **A pinned device wins for steps and sleep.** With a watch and a phone tracker
      both writing to Health Connect / Apple Health, pin the watch on Connected
      devices → the watch; reopen Steps and Sleep: today's steps and last night are the
      watch's own, not the phone's or the total. Turn the watch off there instead: the
      phone's figures come back. A day the pinned device missed is still filled.
- [ ] **Water reaches the cloud for the past week.** With cloud sync on, log a drink
      in the evening, do not reopen the app that day, reopen it the next morning, and
      sign in on a second phone: the evening drink is there. Delete a drink from two
      days ago on one phone; after both sync it is gone on both.
- [ ] **Ounces and pounds.** Water → Profile → Units: choose fl oz and lb. The Water
      screen's gauge, quick-add tiles, Custom Amount, the cup and bottle sheets and
      Today's water card all read in fl oz at once (no restart); the weight box
      converts what is in it. Log a 12 fl oz drink and open History: it reads
      12 fl oz. Switch back: every amount returns to ml. The home-screen widget still
      says 250 ml (native). Reminder notifications offer "Log 8.5 fl oz".
- [ ] **A family profile's weight, height, insurance and photo.** Edit a profile, fill
      all four, save, reopen: all four are shown. The photo shows in the list in
      Family & caregivers. Delete the profile, restart twice: its photo file is gone.

## Snooze length, quiet hours, auto-complete: device checks no test can cover

The tests replace the alarm manager and the notification plugin with doubles, and the
step total with a fixed number. These are the checks that the real ones behave.

- [ ] **A medicine's own snooze length (Android).** Edit a medicine, set Snooze length
      to 1 min, let its alarm fire and tap Snooze on the notification: it rings again
      after about a minute, not after the Notifications length. With two medicines due
      in the same minute (one at 1 min, one following Notifications) the alarm snoozes
      for 1 minute.
- [ ] **The in-app Snooze matches the notification's.** Open a due dose from Today and
      tap Snooze: the toast says the same number of minutes as the notification's
      Snooze button (it used to say 10 whatever the Notifications setting was).
- [ ] **iPhone: the medicine's snooze length.** Set a medicine to 30 min, tap its
      reminder, and Snooze on the alarm screen: it returns after 30 minutes.
- [ ] **Quiet hours hold a Normal reminder (Android).** Notifications → Quiet hours →
      on, 22:00 to 07:00. Make a one-off Normal reminder for 23:00: nothing rings at
      23:00 (check the phone is not on Do Not Disturb, which would hide the test); it
      arrives at 07:00. A Quiet reminder at 23:00 still appears silently at 23:00; an
      Insistent or Critical one rings at 23:00; a medicine rings at 23:00.
- [ ] **Quiet hours on a weekday reminder past midnight.** A "weekdays" Normal reminder
      at 23:00 with quiet hours on arrives Tuesday to Saturday at 07:00 (not Monday to
      Friday). Delete it on Friday: nothing arrives the next Saturday morning.
- [ ] **Quiet hours: Use my sleep schedule.** The From and Until rows change to the
      bedtime and wake time on the sleep schedule screen, and an already-armed reminder
      inside the new window moves.
- [ ] **A reminder ticks itself off by its steps.** Make a reminder "Walk" for a few
      minutes from now with Tick off by itself → 1,000 steps. Walk until Steps shows
      1,000 (the phone's sensor or a watch via Health Connect). After the reminder is
      due it shows as done within a few seconds of the count passing 1,000, and its
      history says it was ticked by steps. Walk before it is due: it still rings at its
      time, and is ticked afterwards.
- [ ] **Active hours on Steps.** With a watch or phone writing hourly steps to Health
      Connect / Apple Health, open Steps after a day of walking: "N of 9 active hours"
      with one mark per hour that had at least 250 steps. With no health app the card
      is not there.
- [ ] **iPhone: the first-run health pane.** After the Apple Health sheet it says
      "Asked", with where to look if the numbers do not appear — not "Connected".


## Doctors per profile, birth control, Apple Health mindful minutes: device checks no test can cover

- [ ] **A doctor belongs to a person.** With a family member added, switch to them
      and add a doctor: it is not in the list under "Me", and the appointment picker
      under "Me" does not offer it. Turn on "Share with the family" on it: now every
      profile has it. The same for a clinic. A household of one is never shown the
      switch.
- [ ] **Doctors saved before this update are still everywhere.** Update over an
      install that already had doctors and clinics: switch between profiles; every one
      of them is still listed under each.
- [ ] **Removing a person.** Remove a family member who has a private doctor and a
      shared one: "keep the records" gives both to you; "delete everything" deletes
      the private one and leaves the shared one with you. The sheet's words match.
- [ ] **Hormonal birth control.** On the Cycle screen, "Hormonal birth control" is
      off to begin with and the fertile window shows as before. Turn it on: the
      fertile window, the ovulation day, the ring's ovulation arc, the BBT hint, the
      temperature-shift card, the calendar key's "Fertile window" and the Fertile
      window reminder (Trying to conceive) all go; the next-period estimate stays and
      the card says why. Turn it off: they come back.
- [ ] **Apple Health: mindful minutes (iPhone).** Needs HealthKit enabled on the App ID
      first (see "Enable HealthKit on the iOS App ID" under the release steps). In
      Focus settings "Save mindful minutes" is offered; turn it on and Apple Health asks
      for Mindfulness; finish a breathing exercise: Health → Browse → Mindfulness →
      Mindful Minutes shows it, the right length, from DlyMinder. A work or study round
      writes nothing. Turn it off and decline the sheet: the switch says why and stays
      off. The two Info.plist purpose strings (read and update) now mention mindful
      minutes; the hosted privacy policy's "Health data we write back" section lists
      drinks and mindful minutes and needs republishing.


## Shared readings and drinks follow edits and deletes (Android): device checks no test can cover

The tests prove the app sends the right name and version and the right delete; only
Health Connect can show that it replaces and removes. Needs sharing switched on first
(Vitals reminders settings → "Share with Health Connect"; Water → Hydration profile →
"Share drinks with other health apps").

- [ ] **Edit a shared reading.** Log a blood pressure, a blood sugar and a weight, then
      edit each one's numbers in DlyMinder. Health Connect shows ONE record each with the
      new numbers (Health Connect → Data and access → the type → Entries), not the old
      and the new.
- [ ] **Delete a shared reading.** Delete each: the record is gone from Health Connect
      within a few seconds. Delete another and tap Undo straight away: it is back in
      Health Connect once, not twice.
- [ ] **Edit and remove a shared drink.** Log a drink, change its amount in the history
      editor: Health Connect shows the new amount and not a second drink. Remove one with
      the Undo toast open and let it go: it is gone from Health Connect.
- [ ] **What was shared before this update stays.** A reading or drink shared on an older
      build keeps its old record when edited or deleted (the old record has no name and
      cannot be found); edit one and check it is not duplicated.
- [ ] **iPhone.** Nothing changes on an iPhone: an edit or delete there is not sent to Apple
      Health.


## Relaxation: a session the app was closed under, and as mindful minutes: device checks no test can cover

- [ ] **A running session survives the app being closed.** Start a 10-minute relaxation
      track, swipe the app away from recents (or `adb shell am kill` it) after two
      minutes, reopen within eight: the session is still running with about eight
      minutes left and the track plays again from its start.
- [ ] **A paused session comes back paused.** Pause at five minutes left, close the app,
      reopen an hour later: it is paused with five minutes left; Resume plays the track
      and counts down from five.
- [ ] **One that ended while the app was closed is not counted.** Start 5 minutes, close
      the app, reopen after ten: no completed session in the history and the minutes
      total has not moved.
- [ ] **Stress Relief as mindful minutes.** With "Save mindful minutes" on, finish a Stress
      Relief session: Health Connect (or Apple Health) shows a mindfulness session of the
      right length titled Relaxation. A Deep Focus or Full Reset session writes nothing.


## Steps counted while the app is closed (Android): device checks no test can cover

- [ ] **Sensor allowed, app swiped away.** On a phone with no health app connected, allow
      "Count with this phone's sensor", note today's steps, swipe the app from recents,
      walk about 300 steps, reopen: today's total is higher by roughly what you walked,
      without opening the Steps screen first.
- [ ] **Closing the Steps screen no longer stops counting.** Open the Steps screen, go back
      to Today, walk 50 steps with the app open: the Today steps card moves.
- [ ] **A phone restart claims nothing.** Restart the phone, walk, reopen: steps taken since
      the restart are counted live from the first reading; none are added for the gap.
- [ ] **Overnight is not credited to today.** Leave the app closed overnight and walk after
      waking: the first reading of the morning does not add the evening's steps to today.
- [ ] **Not asked at launch.** With the sensor not yet allowed, opening the app never shows a
      Physical activity prompt; it is asked only from the Steps screen's offer.

## Wind down: device checks no test can cover

- [ ] **The reminder opens the screen.** Turn the bedtime reminder on, set it a minute ahead,
      wait for "Wind-down time", tap it: the Wind down screen opens (behind the PIN if app lock
      is on) and nothing is playing. Do the same with the app swiped away.
- [ ] **Breathing, then the sound.** Tap Start, breathe through: the Relaxation screen opens
      with Deep Sleep running for 20 minutes, and the sound is audible with the screen locked.
- [ ] **It ends in quiet.** Let the 20 minutes run out (or set the clock forward): the sound
      stops by itself and nothing else plays.
- [ ] **Closing early.** Close the breathing half-way: no sound starts, and the breathing
      history does not gain an exercise.
- [ ] **Not over another session.** Start a Relaxation session, then open Wind down: it says
      the session carries on, and Start only does the breathing.

## Large cloud backups: checks that need the real Firestore

- [ ] **A backup over one document.** Fill the app with enough data that the compressed export
      passes 900 KB (a few years of heavy logging, or import a large backup file), then Back up
      to the cloud: it succeeds, and the list shows ONE backup at its full size.
- [ ] **It restores whole.** Restore it on a clean install or after "Delete all data": every
      record comes back, not just the first part's.
- [ ] **Deleting removes every part.** Delete it from the list; in the Firebase console the
      `backups` collection has no `...~p2` documents left.
- [ ] **No rules change needed.** The write succeeds against the rules already deployed (the
      parts pass the existing `create` check). If it is refused, the deployed rules are older
      than `firestore.rules` in the repo: deploy them.
- [ ] **Too big even for this.** An export past about 7 MB compressed is refused with "Export a
      copy", and nothing is written.

## Rest for a few days: device checks no test can cover

- [ ] **Offered, never done for you.** After two bad nights, the Overnight body check shows
      "Take a rest day" and "Rest for 3 days"; neither is marked until tapped.
- [ ] **Three days.** Tap "Rest for 3 days": the Steps screen shows today as a rest day, and
      tomorrow and the day after do too when they arrive; the steps streak is not broken.
- [ ] **The evening step reminder skips them.** With it on, do not open the app on day two: no
      step reminder rings on days one to three, and it rings on day four.
- [ ] **The Focus streak is kept, and not nagged.** With a Focus streak and "Streak reminder"
      on, no streak-at-risk notice arrives on a rest day.
- [ ] **Medicines are untouched.** A medicine due on a rest day rings as always, and so do
      water and your own reminders.
- [ ] **Undo.** Tap Undo: every marked day is back as it was.

## Welcome: what to start with, and the health import: device checks no test can cover

- [ ] **The pane.** On a fresh install the welcome screen has a fourth step, "What would you
      like to start with?", with six chips. Pick Water and Sleep: a third pick is allowed, a
      fourth is refused with a line saying so.
- [ ] **Today afterwards.** Finish setup: the app opens on Today (not Meds) with Water first
      and the Weekly activity card second; Customize on Today shows that order and nothing
      hidden. Picking Medicines opens on Meds as before; picking nothing changes nothing.
- [ ] **Day-one numbers.** On a phone with Health Connect holding steps and sleep, connect it
      on the health step, finish: Today shows steps (and last night's sleep) without opening
      the Steps or Sleep screen first, and Trends has the past week.
- [ ] **A refusal.** Decline the Health Connect prompt: "Try again" shows, and Today has no
      imported numbers.

## Next period from the temperature rise: device checks no test can cover

- [ ] **A rise moves the date.** In a cycle with a logged basal temperature that rises for
      three days (0.2 °C or more above the six before), the prediction card says "Counted on
      from the temperature rise in your log this cycle" and the next-period date is the
      ovulation day plus your luteal length, a few days off the calendar date.
- [ ] **No rise, no change.** With no temperature logged (or fewer than three warm days) the
      card is the calendar estimate with no such note.
- [ ] **Birth control.** With "Hormonal birth control" on, the note never appears and no
      ovulation day or fertile window is shown.
- [ ] **A strange chart is set aside.** A rise more than a week away from the calendar's
      estimate leaves the calendar date in place.

## Text size: device checks the layout harness cannot make

The overflow and touch-target harnesses run with the test font (Ahem), whose glyphs
are about twice as wide as a real font's, and at the app's largest text size (2x).
Their row-truncation baselines (27 on Notification settings, 22 on Vitals reminder
settings) therefore accept labels the harness font cuts but a real font would not —
and cannot catch a cut that only a real font produces. The accepted labels are
listed by name in
`test/responsive/responsive_overflow_test.dart` (`_rowCutLabels`).

- [ ] **Largest text size on a 320dp-wide phone.** Settings → Display → Font size
      and Display size at the maximum, on the smallest phone you have. Open
      Settings → Notifications and Vitals → Reminders: read every row, in particular
      **Daily check-in** and **Bring them in**. A label may wrap onto a second line;
      it must not be cut mid-word or hide its switch.
- [ ] **The Focus suggestion card at the same size.** Finish four focus rounds of
      the same activity, on three different days, at about the same time of day; on
      the next such day the card "Your usual round around now" appears on Focus. Its
      *Why this?*, *Use this* and *Dismiss* controls are each tall enough to tap and
      none runs off the card (on a very narrow card the third drops to its own line).

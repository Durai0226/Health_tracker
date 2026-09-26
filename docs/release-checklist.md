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

The app declares 20 health permissions. Copy these:

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
| `READ_BLOOD_PRESSURE` | Lets the Blood Pressure tracker show readings the user recorded in another app. |
| `READ_BLOOD_GLUCOSE` | Lets the Blood Sugar tracker show readings the user recorded in another app. |
| `WRITE_BLOOD_PRESSURE` | Optional, off by default: writes blood-pressure readings the user logged in DlyMinder back to Health Connect so their other health apps can see them. |
| `WRITE_BLOOD_GLUCOSE` | Optional, off by default: same, for blood sugar. |
| `WRITE_WEIGHT` | Optional, off by default: same, for weight. |
| `READ_HYDRATION` | Lets the Water tracker count drinks the user logged in another app, so the daily total is their real intake rather than only what they entered here. |
| `WRITE_HYDRATION` | Optional, off by default: writes each drink the user logs in DlyMinder (amount and time) back to Health Connect so Samsung Health, Fitbit and their other apps can see it. |

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

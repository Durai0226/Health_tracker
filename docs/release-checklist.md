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

The app declares 18 health permissions. Copy these:

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

> **Do not submit this before the Heart and Workouts screens exist.** Eleven of
> those justifications name screens that are not built yet. A declared
> permission with no visible feature is a rejection, and a rejected health
> declaration is slow to appeal. The backend is done; the screens are not.

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
  is denied and the sync code swallows the error silently.
- **Nothing here has run on a real device.** Health Connect is mobile-only, so
  the permission sheet, the rationale deep link and any real sync are still
  unverified.

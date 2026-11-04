# DlyMinder Privacy Policy

<!--
DRAFT — review before publishing. Written against what the app actually does as
of schema v14; every claim below was checked against the code, not assumed.

Before publishing you MUST:
  1. Replace [CONTACT EMAIL] and [ENTITY NAME].
  2. Set "Last updated" to the real publication date.
  3. Re-read the Advertising section — it is the one with a live compliance
     trap (see the note there).
  4. Host it, then set EnvConfig.privacyPolicyUrl to the exact same URL you
     enter in Play Console. Byte-identical, including https:// and any
     trailing slash.

Keep this file and the published page in sync. If the app starts reading a new
health data type, this page changes in the same commit.
-->

**Last updated:** [DATE]

DlyMinder ("the app") is a personal health and medication reminder app. This
policy explains what the app reads, where it goes, and how to remove it.

The short version: **your health data stays on your phone unless you explicitly
turn on cloud sync.** Cloud sync is off by default.

## Who we are

[ENTITY NAME], contactable at [CONTACT EMAIL].

## What the app stores

Everything you log — medicines and doses, water, sleep, steps, blood pressure,
blood sugar, weight, mood, menstrual cycle, diary entries, reminders — is stored
in a private database on your device.

**Focus.** Alongside your focus sessions the app keeps up to 200 short records of
the times you left the app partway through a round: when, how many minutes in, and
how long the round was. It cannot see which app you went to or why — the screen
turning off looks the same — and it is used for one thing, suggesting a shorter
round if you keep leaving at the same minute. It is on by default; Focus → Session
setup → "Notice when I step away" turns it off and deletes what it noticed. Like
the rest of your data it leaves your phone only if you turn on cloud sync or share
a backup.

## Health data we read from Health Connect / Apple Health

With your permission, the app reads the following so your trackers reflect what
your phone or a connected watch, ring or band already recorded, instead of
asking you to type it in twice:

- **Activity:** steps, distance, active calories, exercise sessions
- **Sleep:** sleep sessions and their stages
- **Heart:** heart rate, resting heart rate, heart rate variability
- **Other vitals:** blood oxygen, respiratory rate, body temperature, skin
  temperature
- **Body:** weight (only when you tap "Import" — never in the background)
- **Cycle:** past period days (only when you tap "Import" on the Cycle screen —
  never in the background, and never written back)
- **Readings from other apps:** blood pressure and blood sugar that a cuff or a
  meter app saved (only when you switch on "Readings from other apps" in Vitals
  settings; readings this app wrote itself are skipped)
- **Water:** drinks that other apps saved (only when you switch on
  "Count drinks from other apps" in the Hydration profile; drinks this app wrote
  itself are skipped, and what comes in is never written back)

Each of these is requested separately and the app works without them. If you
decline, the affected tracker falls back to manual entry.

We also read the **name of the app or device** that supplied each reading (for
example "Galaxy Watch5"), so the app can show you which device your numbers came
from. This is stored on your device only and is never uploaded.

## Health data we write back

If — and only if — you turn each one on, the app writes things **you logged
yourself** back to Health Connect / Apple Health, so other health apps can see
them. Each is its own switch:

- Blood pressure, blood sugar and weight (Vitals settings)
- The drinks you log (Hydration profile)
- Completed breathing, meditation and stress-relief relaxation sessions, as
  mindful minutes (Focus settings). Work and study sessions are never written.

All of these are off by default. The app never writes data it read from
somewhere else. On Android, if you edit or delete a reading or drink in the app
after sharing it, the copy in Health Connect is corrected or removed too; this
only ever touches records this app wrote.

## Cloud sync (optional, off by default)

If you create an account and turn on cloud sync in Settings, a copy of your data
is stored in your own private area of Google Firebase (Firestore), so you can
restore it on a new device. Specifically:

- Only you can read or write it. Access is enforced by server-side rules tied to
  your account.
- Data is encrypted in transit.
- If you do not sign in, or leave cloud sync off, **nothing leaves your device.**
- Guest / anonymous use never syncs anything.

## Account and sign-in

Signing in is optional and only needed for cloud sync and backup. We use
Firebase Authentication, including Google Sign-In. We receive your email address
and, if you use Google Sign-In, your Google account's basic profile. We do not
receive your Google password.

## Backup files

"Export a copy" makes a file of everything in the app and hands it to the share
sheet. You can protect it with a passphrase you choose: the file is then
encrypted on your phone (AES-256), and the passphrase is never stored or sent
anywhere. **We cannot recover it** — a backup whose passphrase is lost cannot be
opened by anyone.

## Camera and photos

The app can scan a prescription label to fill in a medicine's details. Text
recognition runs **entirely on your device**; the photo taken to scan a label is
not uploaded and is not stored.

You can also attach a photo to a medicine, to a diary entry or to a family
member's profile, from the camera or from your gallery. The app keeps a **copy inside its own private storage on your
phone** — not a link to your gallery. These photos are **not uploaded**, and they
are **not part of cloud sync, cloud backup or "Export a copy"**: a backup file
holds your entries, medicines and profiles, not their pictures, so a photo does
not come back on another phone. A photo is deleted when you replace or remove it,
and by "Delete all data". When you delete the medicine, entry or profile it belongs
to, its photo is deleted the next time the app starts.

## Advertising

The app displays ads via Google AdMob. AdMob may collect device identifiers and
usage data for ad delivery and measurement, subject to
[Google's privacy policy](https://policies.google.com/privacy). On iOS you are
asked before any tracking identifier is used.

**Your health data is never used for advertising, never shared with advertisers,
and never sold.** Health data read from Health Connect or Apple Health is used
solely to show you your own trackers and insights inside the app.

<!--
COMPLIANCE TRAP — do not delete this note.

Google Play forbids using Health Connect data for ads, and forbids sharing it
with data brokers or for any advertising purpose. The paragraph above is a
binding commitment. Before shipping, confirm no health value is ever passed to
AdMob targeting, and keep it that way. Breaking this is a policy violation, not
a bug.
-->

## Analytics

The app contains no analytics, crash-reporting or tracking SDK. We do not build
a profile of you and we do not track you across other apps or websites.

## Notifications and alarms

Reminder times and their content are stored on your device and scheduled
locally. Reminder text is not sent to any server unless you have cloud sync on.

## How long we keep it

On-device data is kept until you delete it or uninstall the app. If cloud sync
is on, the cloud copy is kept until you delete your data or your account.

## Deleting your data

- **In the app:** Settings → Clear all data removes everything from the device
  and, if cloud sync is on, your account.
- **Deleting your account** removes your cloud copy.
- **Revoking health access:** in the app, Connected devices → Disconnect (on
  Android this also gives the permissions back); or Health Connect → App
  permissions → DlyMinder on Android, or Health → Sharing → DlyMinder on iPhone.
  This stops new readings arriving. Anything already saved in DlyMinder stays until you delete it in the
  app.
- Or email [CONTACT EMAIL] and we will action a deletion request.

## Children

DlyMinder is not directed at children and we do not knowingly collect data from
children.

## Not medical advice

DlyMinder is a general wellness and reminder tool. It is not a medical device
and not a source of diagnosis or treatment. Always confirm health decisions with
a qualified clinician or pharmacist. In an emergency, contact your local
emergency services.

## Changes

If this policy changes materially we will update this page and the "Last
updated" date above.

## Contact

[CONTACT EMAIL]

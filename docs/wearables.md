# Wearable device integration

How DlyMinder gets data off watches, rings and bands — what is built, what is
not, and what the owner has to do before any of it can ship.

## The approach, and why

We do **not** integrate Fitbit, Garmin, Oura and Whoop one at a time. All of
them already write into **Health Connect** on Android and **HealthKit** on iOS
through their own phone apps. One well-built integration with the OS aggregator
reaches essentially the whole wearable market — free, no server, no per-vendor
OAuth, no approval queues. Samsung Health has synced Galaxy Watch data to Health
Connect since v6.22.5 (Oct 2022).

Every direct-vendor option was evaluated and cut:

| Option | Why not |
|---|---|
| Terra / Rook / Junction | ~$399/month |
| Google Health API (Fitbit's successor; Fitbit Web API sunsets Sept 2026) | needs a server for webhooks, and Google's own consumer path on Android *is* Health Connect |
| Oura v2 | API apps are capped at **10 users** until Oura approves them |
| Whoop | client secret in an APK is extractable and a terms violation |
| Garmin Health | webhook-push by design, so a server is mandatory |

Beyond cost there is a privacy argument: a vendor refresh token is a long-lived
bearer credential to the user's entire health record, sitting on the device. For
an app whose onboarding promises "Private · on-device · no account", Health
Connect — which the OS mediates and the user revokes in one place — is strictly
better.

**Direct BLE** (`flutter_blue_plus`) reaches *accessories* — chest straps, BP
cuffs, smart scales — not watches or rings, which funnel through proprietary
protocols. It is a live-workout feature, not wearable sync, and is out of scope.

## What is built

- **`health` 13.3.2.** Needed for background reads (12.2.0), >30-day history
  (12.1.0) and skin temperature (13.x), none of which exist in 11.1.1.
- **iOS HealthKit entitlement wired.** It was declared in
  `Runner.entitlements` but referenced by no build configuration, so the signed
  app had no HealthKit capability at all.
- **Health Connect rationale deep link** routed to a real disclosure screen.
  Both manifest filters previously pointed at an activity that handled no
  intents.
- **Schema v13** — sync fields + tombstones on the four vitals tables, so blood
  pressure, glucose, weight and mood can finally cloud-sync.
- **Schema v14** — `biometric_daily_data`, `workout_sessions`, `health_sources`.
- **`BiometricsService`** — reads heart rate, resting HR, HRV, blood oxygen,
  breathing rate, body and skin temperature, and workouts; aggregates them to
  one row per day.

## What is NOT built yet

- The Heart / Workouts / Connected-devices **screens**. The data is collected
  and stored; nothing renders it yet.
- **Cloud sync** for the new collections (`firestore.rules` blocks + two
  `_sync` calls).
- **Background sync**, so data still only refreshes while the app is open.
- **iOS background delivery** (`HKObserverQuery`) — deliberately deferred: there
  is no iOS widget target to justify it, and it cannot be tested on a simulator.

## Design decisions worth not re-litigating

**Daily aggregates, never raw samples.** A worn watch writes ~1 heart-rate
sample a minute — ~500k rows a year. `BackupService` uploads the whole export to
the user's Drive, and `HealthCloudSyncService` writes one Firestore doc *per
row* with a 1000-doc read cap. Intraday shape is kept the way Steps already
keeps it: a 24-slot JSON array on the daily row.

**Biometrics are a separate permission tier.** They are deliberately absent from
`readTypesFor` (the first-run steps+sleep sheet). Health Connect is
all-or-nothing per request and throttles re-prompting, so bundling eight more
scopes would make the base grant likelier to be refused and burn the user's
retry budget. Requested from the biometrics screens instead.

**HRV and skin temperature are platform-split, and not comparable.** Health
Connect exposes HRV as RMSSD, HealthKit as SDNN — different statistics over
different ranges (RMSSD ≈ 20–100 ms, SDNN ≈ 30–180 ms). Android skin temperature
is a *delta from baseline*; Apple's is *absolute °C*. Each stored value carries
a metric discriminator, and the trend API takes the metric as a parameter so
mixing them is impossible by accident. Without this, a cross-platform backup
restore invents a step change that never happened.

**One source per metric per day.** When two devices report the same metric, a
deterministic total order picks a winner (user pin → sample count → last seen →
lexicographic id) and only that source's samples are used. Blending an Oura
ring's heart rate with a Galaxy Watch's produces a min/max range no device ever
measured. The final lexicographic tiebreak is not decorative: without it two
equally-ranked devices alternate between syncs and the trend line jumps between
two calibrations.

**No VO2 max.** `health` 13.3.2 declares no VO2MAX type on *either* platform,
even though HealthKit and Health Connect both store one. The column exists so a
future plugin bump needs no migration, but nothing writes it, and
`READ_VO2_MAX` is deliberately absent from the manifest.
`health_data_types_test.dart` fails when the plugin adds the type.

**`sourceDeviceId` is unusable for device identity.** The plugin fills it from
`Health().deviceId`, and since v12.0.0 removed the singleton that expression
builds a fresh, unconfigured instance whose value is the literal `'unknown'`.
Even populated, it names *this phone*, never the watch. The device registry keys
on `(platform, sourceId, sourceName)`, hashed — `sourceName` routinely contains
a person's name and must not become a Firestore document id.

## Owner actions — required before ANY release

These are not code. Nothing ships without them.

1. **Publish a privacy policy and set `EnvConfig.privacyPolicyUrl`.**
   Currently empty, and the in-app link stays hidden while it is. The URL must
   be **byte-identical** in three places: Play Console, in-app, and the page
   itself. Before this work there was no privacy policy anywhere in the app.
2. **Complete the Play Console Health apps declaration form.** Mandatory for
   *every* track, including internal and closed testing. Each health permission
   needs a justification tied to a feature a reviewer can see in the app — which
   is why the biometric permissions and their screens must ship together.
3. **Complete the Data safety form** — every health type listed as collected,
   encryption in transit, deletion supported (true; the account-delete flow
   exists).
4. **Enable HealthKit on the iOS App ID** in the Apple Developer portal and
   regenerate the development + distribution provisioning profiles. The
   entitlement is now wired into all three build configurations, so **the next
   iOS build fails to sign until this is done.** Android is unaffected.

## Testing notes

Health Connect and the pedometer are mobile-only, so the permission sheet, the
rationale deep link and any real sync need a physical Android device or
emulator. None of it can be signed off from `flutter test`.

Three traps that cost real time here:

- **`pumpAndSettle` never returns.** This app runs continuous animations, so it
  burns its full ten-minute timeout — the reason `integration_test/support/e2e.dart`
  bans it. Use fixed-frame pumps in widget tests too.
- **`Platform.isAndroid` is false under `flutter test`** (the host is macOS).
  Guard Android-only code on `defaultTargetPlatform`, or take the platform as a
  parameter — otherwise the test exercises the iOS branch and passes for the
  wrong reason. `BiometricsService.aggregateDay` takes an `android` flag for
  exactly this.
- **A channel with no mock handler does not raise `MissingPluginException`** in
  tests; it posts to a nonexistent engine and hangs. Simulate an unimplemented
  channel with a null *binary* reply via `setMockMessageHandler`.

`onUpgrade` had no coverage before this work — every other DB test builds a
fresh database, so only `onCreate` ever ran.
`test/core/database/vitals_v13_migration_test.dart` drives a real v12 database
with real rows through the upgrade. It immediately caught a bug that would have
**crashed the app on launch for every existing user**: `TableMigration` needs
*every* newly added column listed in `newColumns`, not just the non-defaulted
one, or an absent column arrives as NULL and trips a generated CHECK.

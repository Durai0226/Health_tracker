# DlyMinder – Health Tracker

Flutter health-tracking app. Firebase project `remedly-86882`, repo `Durai0226/Health_tracker`.
Development status — no Play Store release yet. Android is the primary target.

## Stack

- **Flutter** 3.44.6 / **Dart** 3.12.2 (pubspec constrains `sdk: ^3.10.8`)
- **State:** Provider · **Local DB:** Drift/SQLite with code generation
- **Backend:** Firebase Auth, Firestore, Storage, App Check
- **AI:** deterministic rule engine + FTS5 RAG by default; optionally an OpenAI-compatible
  provider the user connects (Groq / Gemini / Ollama on their LAN). See `lib/core/ai/AI_ENGINES.md`.
- **Notifications:** `flutter_local_notifications` + `android_alarm_manager_plus`
- **Health data:** HealthKit (iOS) / Health Connect (Android) via `health` + `pedometer`

## Layout

- `lib/core/` — shared services (auth, database, sync, notifications, AI, health, theme, utils)
- `lib/features/` — feature modules: `medication`, `water`, `sleep`, `steps`, `period`, `focus`,
  `reminders`, `insights`, `backup`, `settings`, `onboarding`, `home`
- `lib/widgets/` — global reusable UI
- `test/`, `integration_test/` — unit + integration tests

Key services: `AuthService`, `CloudSyncService`, `HealthCloudSyncService`, `HealthDataService`,
`RemindersCloudService`, `BackupService`, `LocalNotificationService`, `DatabaseService`.

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenerate Drift code
flutter analyze
flutter test
flutter build apk --release
firebase deploy --only firestore:rules,storage             # rules-only deploy (no functions)
```

## Conventions

- **Never** edit `*.g.dart`, `*.freezed.dart`, `*.mocks.dart` — regenerate with `build_runner`.
  `lib/core/database/app_database.g.dart` alone is ~35k lines; don't read it whole.
- Always use `super.key` in widget constructors.
- Health data types **must be split per platform** — Health Connect types on Android, HealthKit
  types on iOS. Same for `hasPermissions()` checks. See `lib/core/services/health_data_service.dart`.
- Medicine dose updates apply optimistically with Undo; notification actions drain on app resume.
- Every Firestore operation requires an ownership check (`isOwner(userId)`). `firestore.rules` is
  default-deny with id + size validation; `storage.rules` allows user-private backups only.

## Gotchas

- **iOS sim:** never `flutter clean` before a sim run — it breaks CocoaPods and surfaces an MLKit
  conflict. For screenshots use the debug entrypoint + hub-then-push, not a direct push.
- **Disk space:** build failures are cryptic when the disk is full (e.g. `lipo: No space left`).
  Clear `~/.gradle` and `~/Library/Developer/Xcode/DerivedData`.
- **SnackBar:** one with an action never auto-dismisses unless `persist: false` is set.
- **Google Sign-In:** the build's signing SHA-1 must be registered in the Firebase console;
  a mismatch throws `ApiException: 10`.
- **UI runs need real hardware:** HealthKit / Health Connect are mobile-only, so a device
  or emulator is required. `flutter analyze`, `flutter test`, and `build_runner` work headless.

## Not in this project

Despite what earlier notes claimed: no Firebase Remote Config, Crashlytics, Analytics, or
Messaging — those packages are absent from `pubspec.yaml`. There is no web deployment or dev
server; this is a mobile app.

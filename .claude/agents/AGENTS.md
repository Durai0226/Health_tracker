# DlyMinder – Health Tracker

## Tech Stack
- **Flutter** 3.44.6 / **Dart** 3.10.8
- **State Management:** Provider
- **Database:** Drift (SQLite) with code generation (`app_database.g.dart` — 34K+ lines, auto-generated)
- **Backend:** Firebase (Auth, Firestore, Storage, App Check, Remote Config)
- **On-device AI:** flutter_gemma (Android-only, vendored in `third_party/flutter_gemma`)
- **Notifications:** flutter_local_notifications + android_alarm_manager_plus
- **Health Data:** HealthKit (iOS) / Health Connect (Android)
- **Firebase Project:** remedly-86882

## Architecture
- `lib/core/` – Shared services (auth, database, sync, notifications, AI, health data, theme, utils)
- `lib/features/` – Feature modules:
  - `medication/` – Medicine tracking, reminders, dose history
  - `water/` – Daily water intake logging
  - `sleep/` – Sleep tracking, Drift-backed sleep logger
  - `steps/` – Step count, Health Connect / HealthKit integration
  - `period/` – Menstrual cycle tracking, predictive reminders (opt-in)
  - `focus/` – Focus session tracking, productivity stats
  - `reminders/` – Unified reminder system (medication, vitals, custom)
  - `insights/` – Analytics and health insights
  - `backup/` – Cloud backup & restore
  - `settings/` – User preferences, sync, privacy
  - `onboarding/` – Initial setup flow
  - `home/` – Home dashboard / hub
- `lib/widgets/` – Global reusable UI components
- `test/` – Unit tests (522 tests passing)

## Critical Rules
- **NEVER** modify `*.g.dart`, `*.freezed.dart`, `*.mocks.dart` files — they are auto-generated
- Run `dart run build_runner build --delete-conflicting-outputs` to regenerate database code
- Always use `super.key` in widget constructors
- Firebase config lives in `firebase.json`, `firestore.rules`, `storage.rules`
- `flutter_gemma` is vendored; iOS plugin stripped (Android-only)
- Health data types **must be split per platform:**
  - Android: Health Connect data types only
  - iOS: HealthKit data types only
  - See `lib/core/services/health_data_service.dart` for platform-correct lists
- Medicine dose updates apply optimistically (with Undo); notification actions drain on app resume
- All Firestore operations require ownership check (`isOwner(userId)`)

## Build Commands
```bash
# Install deps
flutter pub get

# Regenerate database code
dart run build_runner build --delete-conflicting-outputs

# Static analysis
flutter analyze

# Run tests
flutter test

# Build Android APK
flutter build apk --release

# Build iOS app
flutter build ios --release
```

## Key Services
- **AuthService** – Firebase Auth, Google Sign-In, guest mode, credential linking
- **CloudSyncService** – Bidirectional cloud sync (medicines, water, reminders)
- **HealthCloudSyncService** – Steps & sleep sync (platform-split health data types)
- **HealthDataService** – HealthKit / Health Connect integration (iOS/Android split)
- **RemindersCloudService** – Reminder CRUD, category sync
- **BackupService** – Export/import, cloud storage
- **LocalNotificationService** – Alarm scheduling, push notifications
- **DatabaseService** – Drift ORM (local SQLite)

## Recent Commits (Key Context)
- `88bb906` – **fix(health,medication,firestore):** corrected platform health types, live dose updates, hardened security rules
- `8afe62d` – **feat(vitals,reminders):** surface BP & blood-sugar reminders in hub + settings
- `572d6da` – **feat(period,reminders):** predictive Period reminders + unified Reminders hub

## Known Gotchas
- **iOS sim testing:** Never run `flutter clean` for iOS sim (breaks CocoaPods/MLKit conflict); use `debug_entrypoint` + hub-then-push instead
- **Disk space:** Build failures can be cryptic if disk is full; clear `~/.gradle` (8GB) and `~/Library/Developer/Xcode/DerivedData` (6GB) if needed
- **SnackBar:** SnackBar with action never auto-dismisses unless `persist: false` is set
- **Google Sign-In:** Requires build's SHA-1 fingerprint registered in Firebase console; mismatch causes `ApiException: 10`
- **Health permissions:** Android/iOS have different permission models; `hasPermissions()` checks must be split per platform

## Testing
- **Unit tests:** `flutter test` (522 tests, all passing)
- **Code analysis:** `flutter analyze` (0 errors)
- **UI testing:** Requires a physical device or emulator (mobile-only plugins like HealthKit, Health Connect)

## Firebase Rules
- **Firestore:** `firestore.rules` (least-privilege, default-deny, id+size validation)
- **Storage:** `storage.rules` (user-private backups only)
- **Deploy:** `firebase deploy --only firestore:rules,storage` (rules-only)

## Deployment Notes
- **Android:** Release APK at `~/Downloads/DailyMinder-release.apk`
- **Firebase Project ID:** remedly-86882
- **GitHub:** Durai0226/Health_tracker (slim-to-core-features branch)
- **Status:** Development (no Play Store release yet)

# Google Sign-In Troubleshooting Guide

## Common "Authentication Failed" Causes & Solutions

### 1. **Google Sign-In Not Enabled in Firebase Console** ⚠️ MOST COMMON
**Check:**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `remedly-86882`
3. Go to **Authentication** → **Sign-in method**
4. Find **Google** provider
5. Ensure it's **ENABLED** (status should show "Enabled")

**Fix if disabled:**
- Click on Google provider
- Click "Enable" toggle
- Add support email
- Click "Save"

### 2. **Missing SHA-1/SHA-256 Fingerprints (Android)** 🔑
**Why needed:** Android needs your app's signing fingerprints to verify the app.

**Get your SHA-1 fingerprint:**
```bash
cd android
./gradlew signingReport
```

Or for debug builds:
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**Add to Firebase:**
1. Firebase Console → Project Settings
2. Scroll to "Your apps" → Select Android app
3. Add SHA-1 and SHA-256 fingerprints
4. Download new `google-services.json`
5. Replace in `android/app/google-services.json`

### 3. **iOS Configuration Missing** 🍎
Your iOS Info.plist is missing Google Sign-In configuration.

**Required configuration:**
- URL schemes for reversed client ID
- GoogleService-Info.plist file

### 4. **Firestore Not Enabled**
Since the app now syncs to cloud, Firestore must be enabled.

**Enable Firestore:**
1. Firebase Console → Firestore Database
2. Click "Create Database"
3. Choose Production mode
4. Select your region
5. Add security rules (see below)

### 5. **Network Issues**
- Check internet connection
- Try on different network
- Check if Firebase services are down

## Step-by-Step Debug Process

### Run the App with Debug Logs
1. Run your app in debug mode
2. Open the debug console/logs
3. Try to sign in with Google
4. Look for these debug messages:

```
Starting Google Sign-In flow...
Google Sign-In: Signed out from previous session
Google Sign-In: User selection result: [email]
Google Sign-In: Getting authentication credentials...
Google Sign-In: Creating Firebase credential...
```

**If you see an error, note the exact error code and message.**

### Common Error Codes:

**`operation-not-allowed`**
- **Cause:** Google Sign-In not enabled in Firebase Console
- **Fix:** Enable Google provider in Authentication settings

**`invalid-credential`**
- **Cause:** SHA-1 fingerprint mismatch or missing
- **Fix:** Add SHA-1 fingerprint to Firebase Console

**`network-request-failed`**
- **Cause:** No internet or Firebase connectivity issue
- **Fix:** Check internet connection, try different network

**`credential-already-in-use`**
- **Cause:** This Google account is already linked to another account
- **Fix:** App now handles this automatically

**Missing tokens error**
- **Cause:** Google Sign-In SDK configuration issue
- **Fix:** Re-download google-services.json and rebuild

## Quick Checklist ✅

- [ ] Firebase Console: Google Sign-In is ENABLED
- [ ] Firebase Console: SHA-1 fingerprint added (Android)
- [ ] Firebase Console: Firestore is enabled
- [ ] android/app/google-services.json is up to date
- [ ] iOS GoogleService-Info.plist exists
- [ ] App has internet connection
- [ ] Rebuilt app after configuration changes

## Testing Steps

1. **Clean rebuild:**
   ```bash
   flutter clean
   flutter pub get
   cd ios && pod install && cd ..
   flutter run
   ```

2. **Try Google Sign-In**
3. **Check debug logs for specific error**
4. **Match error to solutions above**

## Get More Help

If still failing:
1. Copy the **exact error message** from debug logs
2. Note your platform (iOS or Android)
3. Check if Google Sign-In provider is enabled in Firebase Console
4. Verify SHA-1 fingerprint is added (Android)

## Firestore Security Rules

After enabling Firestore, add these rules:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

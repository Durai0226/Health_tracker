# ⚠️ IMPORTANT: Firebase Anonymous Authentication Setup Required

## Current Issue
You're seeing "User" with "Sign Out" instead of "Guest" with "Sign in with Google" because **Firebase Anonymous Authentication is not enabled**.

## Required Steps

### 1. Enable Anonymous Authentication in Firebase Console

**CRITICAL: You MUST do this for the app to work correctly**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Click **Authentication** in the left sidebar
4. Go to **Sign-in method** tab
5. Find **Anonymous** in the list
6. Click on it and **Enable** it
7. Click **Save**

### 2. Hot Restart the App

After enabling Anonymous Auth:
- **Stop the app completely**
- **Hot restart** (not just hot reload)
- The app will now sign in anonymously automatically

### 3. Verify It's Working

Check the debug console for these logs:
```
AuthService Init: No Firebase user, signing in anonymously
Auth State Changed: isAnonymous: true, isGuest: true, name: Guest
```

## Expected Behavior After Fix

### Guest Users (Default)
- **Profile shows:**
  - Avatar: "G" (for Guest)
  - Name: "Guest"
  - Label: "Guest User"
  - Button: **"Sign in with Google"** (blue button)

### After Google Sign-In
- **Profile shows:**
  - Avatar: Google photo or initial
  - Name: Your Google name
  - Email: Your Google email
  - Button: **"Sign Out"** (red button)

## Code Changes Made

All code is now correctly implemented:

1. ✅ AuthService properly detects anonymous users
2. ✅ Guest users show "Guest" name
3. ✅ HomeScreen listens to auth changes
4. ✅ Settings screen listens to auth changes
5. ✅ Profile modal shows correct UI based on guest/authenticated state
6. ✅ Debug logging added to track auth state

## Troubleshooting

### Still showing "User"?
1. Check Firebase Console - Anonymous Auth MUST be enabled
2. Completely stop and restart the app
3. Check debug logs in console
4. Clear app data if needed

### "Sign Out" showing for guest?
This means `authService.isGuest` is returning `false`. Check:
1. Firebase Anonymous Auth is enabled
2. App was restarted after enabling it
3. Debug logs show `isAnonymous: true`

### Error: "Guest mode is not enabled in Firebase Console"
This confirms you need to enable Anonymous Authentication in Firebase Console (see step 1 above).

## Why This Happens

Firebase Authentication requires each sign-in method to be explicitly enabled:
- ✅ Google Sign-In: Already enabled (works fine)
- ❌ Anonymous: **NOT enabled yet** ← This is the issue

Without Anonymous Auth enabled, the `signInAnonymously()` call fails silently, and no user is created. The app then shows fallback values.

## Next Steps

**DO THIS NOW:**
1. Enable Anonymous Authentication in Firebase Console
2. Hot restart your app
3. Check the profile - it should now show "Guest" with "Sign in with Google" button
4. Test signing in with Google - profile should update to show your name/email with "Sign Out"

The code is ready. You just need to flip the switch in Firebase Console.

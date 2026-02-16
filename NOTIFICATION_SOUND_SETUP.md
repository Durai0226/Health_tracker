# Notification Sound Setup Guide

## Overview
The notification system is now configured to work like an alarm with:
- ✅ Full-screen intent (wakes up the screen)
- ✅ Vibration pattern
- ✅ LED notification light
- ✅ Custom alarm sound
- ✅ Persistent notification (won't auto-dismiss)
- ✅ Action buttons (Dismiss, Mark Done)

## Adding Custom Alarm Sound

### For Android

1. **Prepare your sound file:**
   - File name: `alarm_sound.mp3` or `alarm_sound.wav`
   - Recommended: MP3 format, 128kbps
   - Duration: 5-30 seconds (will loop automatically)
   - You can use any alarm tone you prefer

2. **Add to Android resources:**
   ```bash
   # Copy your sound file to:
   android/app/src/main/res/raw/alarm_sound.mp3
   ```
   
   **Note:** The `raw` folder has been created for you. Just add your sound file there.

### For iOS

1. **Prepare your sound file:**
   - File name: `alarm_sound.aiff` or `alarm_sound.caf`
   - iOS requires AIFF or CAF format
   - Duration: Less than 30 seconds
   
2. **Convert MP3 to AIFF (if needed):**
   ```bash
   # Using ffmpeg (install via: brew install ffmpeg)
   ffmpeg -i your_alarm.mp3 -acodec pcm_s16le -ar 44100 alarm_sound.aiff
   ```

3. **Add to iOS bundle:**
   ```bash
   # Copy to:
   ios/Runner/alarm_sound.aiff
   ```

4. **Update Info.plist if needed:**
   - Open `ios/Runner/Info.plist`
   - The sound should work automatically, but ensure notification permissions are granted

### Alternative: Use System Default Sound

If you want to use the device's default notification sound temporarily:

1. Open: `lib/core/services/notification_service.dart`
2. Change line 228 from:
   ```dart
   sound: const RawResourceAndroidNotificationSound('alarm_sound'),
   ```
   to:
   ```dart
   sound: null, // Uses default system sound
   ```

3. Change line 261 from:
   ```dart
   sound: 'alarm_sound.aiff',
   ```
   to:
   ```dart
   sound: null, // Uses default system sound
   ```

## Finding Free Alarm Sounds

You can download free alarm sounds from:
- **Zedge**: https://www.zedge.net/find/ringtones/alarm
- **FreeSoundEffects**: https://www.freesoundeffects.com/free-sounds/alarm-10021/
- **Pixabay**: https://pixabay.com/sound-effects/search/alarm/

## Testing the Notification

After adding your sound files:

1. **Run the app:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Test notification:**
   - The app will request notification permissions on first launch
   - Set a reminder for 1-2 minutes in the future
   - Lock your device
   - The notification should:
     - Wake the screen
     - Play your custom sound repeatedly
     - Vibrate in a pattern
     - Show LED light (if device supports it)
     - Display full-screen on some devices
     - Show "Dismiss" and "Mark Done" buttons

## Troubleshooting

### Sound not playing on Android:
1. Check file is in `android/app/src/main/res/raw/alarm_sound.mp3`
2. File name must be lowercase, no spaces, no special characters
3. Ensure app has notification permissions
4. Check device is not in silent/DND mode (the alarm should override DND)

### Sound not playing on iOS:
1. File must be in AIFF or CAF format
2. File must be less than 30 seconds
3. Ensure notification permissions are granted
4. Check iOS notification settings for the app

### Notifications not showing:
1. **Android 13+**: Grant "Notifications" permission in app settings
2. **Android 12+**: Grant "Alarms & reminders" permission in app settings
3. **iOS**: Allow notifications when prompted on first launch

### Full screen not working:
- Some devices/Android versions may not support full-screen notifications
- The notification will still appear in the notification shade with sound and vibration

## Permissions Granted

The following permissions have been added to AndroidManifest.xml:
- `SCHEDULE_EXACT_ALARM` - For precise alarm timing
- `USE_FULL_SCREEN_INTENT` - To wake screen and show full-screen notification
- `VIBRATE` - For vibration pattern
- `WAKE_LOCK` - To keep device awake for notification
- `RECEIVE_BOOT_COMPLETED` - To restore alarms after device restart
- `POST_NOTIFICATIONS` - To show notifications (Android 13+)

## Current Notification Features

### Android:
- **Priority:** Maximum (appears above all apps)
- **Sound:** Custom alarm sound (loops until dismissed)
- **Vibration:** Pattern (1s on, 0.5s off, repeating 3 times)
- **LED:** Green light blinking (if supported)
- **Full Screen:** Shows even when device is locked
- **Category:** Alarm (highest priority)
- **Persistent:** Won't auto-dismiss, requires user action
- **Timeout:** Auto-dismiss after 60 seconds
- **Actions:** Dismiss or Mark Done buttons

### iOS:
- **Sound:** Custom alarm sound
- **Interruption Level:** Time Sensitive (breaks through Focus modes)
- **Alert:** Shows banner and notification center
- **Badge:** Updates app icon badge
- **Category:** Reminder category for custom actions

## Next Steps

1. Add your custom sound file(s) to the locations mentioned above
2. Run `flutter clean && flutter pub get`
3. Rebuild the app
4. Test with a short-term reminder
5. Adjust vibration pattern or sound duration if needed

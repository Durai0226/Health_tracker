# 🧪 Comprehensive Test Plan - Dlyminder App

## Overview
End-to-end testing plan for all reminder features to ensure the app works perfectly.

---

## ✅ Pre-Testing Checklist

### Build & Compile
- [ ] `flutter clean`
- [ ] `flutter pub get`
- [ ] `flutter pub run build_runner build --delete-conflicting-outputs`
- [ ] `flutter analyze` (0 errors)
- [ ] `flutter build apk --debug` (successful build)
- [ ] Install app on test device

### Device Preparation
- [ ] Android 10+ device (or emulator)
- [ ] Notifications enabled in system settings
- [ ] Battery optimization disabled for app
- [ ] Do Not Disturb mode OFF
- [ ] Test with locked and unlocked states

---

## 🎯 Test Scenarios

### 1. App Initialization & Permissions

#### Test 1.1: First Launch
**Steps**:
1. Install fresh app (uninstall previous if exists)
2. Launch app
3. Observe onboarding/splash screen
4. Grant notification permissions when prompted

**Expected**:
- ✅ App launches successfully
- ✅ Permission dialog appears automatically
- ✅ All services initialize without errors
- ✅ Timezone set correctly (Asia/Kolkata)
- ✅ Notification channels created

**Check Logs For**:
```
✓ Timezone set to: Asia/Kolkata
✓ Created 5 notification channels
✓ Android permissions - Notifications: true, ExactAlarms: true
✓ NotificationService initialized successfully
```

#### Test 1.2: Permission Denial & Recovery
**Steps**:
1. Deny notification permission
2. Try to add medicine reminder
3. Check for proper error handling

**Expected**:
- ⚠️ Warning message shown to user
- ✅ App doesn't crash
- ✅ Reminder saved but not scheduled
- ✅ User can re-grant permission via settings

---

### 2. Medicine Reminders

#### Test 2.1: Add Medicine Reminder
**Steps**:
1. Tap home "Add Reminder" → Medicine
2. Enter medicine name: "Paracetamol"
3. Set dosage: 500mg, Tablet
4. Set time: 2 minutes from now
5. Frequency: Daily
6. Duration: 7 days
7. Enable reminder: ON
8. Save

**Expected**:
- ✅ Medicine saved successfully
- ✅ Success message shown
- ✅ Notification scheduled
- ✅ Medicine appears in home screen
- ✅ After 2 minutes: Notification appears
- ✅ Notification visible on lock screen
- ✅ Device wakes up (if screen was off)

**Check Logs For**:
```
✓ Scheduled medicine reminder at HH:MM
```

#### Test 2.2: Edit Medicine Reminder
**Steps**:
1. Tap existing medicine
2. Change time to 3 minutes from now
3. Save

**Expected**:
- ✅ Old notification cancelled
- ✅ New notification scheduled
- ✅ Notification appears at new time

#### Test 2.3: Delete Medicine Reminder
**Steps**:
1. Tap medicine
2. Tap delete button
3. Confirm deletion

**Expected**:
- ✅ Medicine deleted
- ✅ Notification cancelled
- ✅ No longer appears in list

#### Test 2.4: Different Frequencies
**Test each**:
- Daily
- Once a week
- Weekdays only
- Weekends only
- Every other day

**Expected**:
- ✅ Each frequency schedules correctly
- ✅ Weekdays creates 5 notifications (Mon-Fri)
- ✅ Weekends creates 2 notifications (Sat-Sun)

---

### 3. Health Check Reminders

#### Test 3.1: Blood Sugar Reminder
**Steps**:
1. Add health check → Sugar check
2. Set time: 2 minutes from now
3. Frequency: Daily
4. Enable reminder: ON
5. Save

**Expected**:
- ✅ Health check saved
- ✅ Notification scheduled
- ✅ Notification appears with correct icon
- ✅ "Time to check your blood sugar 🩸" message

#### Test 3.2: Blood Pressure Reminder
**Steps**:
1. Add health check → BP check
2. Set time: 2 minutes from now
3. Frequency: Daily
4. Save

**Expected**:
- ✅ Notification appears
- ✅ "Time to check your blood pressure ❤️" message

---

### 4. Fitness Reminders

#### Test 4.1: Daily Fitness Reminder
**Steps**:
1. Add fitness reminder → Yoga
2. Set time: 2 minutes from now
3. Duration: 30 minutes
4. Frequency: Daily
5. Save

**Expected**:
- ✅ Fitness reminder saved
- ✅ Notification scheduled
- ✅ Notification appears with emoji
- ✅ "Time for your 30 min workout! 💪"

#### Test 4.2: Weekdays Fitness
**Steps**:
1. Add fitness → Running
2. Frequency: Weekdays
3. Save

**Expected**:
- ✅ 5 notifications scheduled (one per weekday)
- ✅ Check notification settings shows 5 pending

#### Test 4.3: Weekends Fitness
**Steps**:
1. Add fitness → Swimming
2. Frequency: Weekends
3. Save

**Expected**:
- ✅ 2 notifications scheduled (Sat & Sun)

---

### 5. Water Reminders

#### Test 5.1: Auto-Generate Water Reminders
**Steps**:
1. Go to Water Tracking
2. Tap notification icon (top right)
3. Enable water reminders
4. Set start time: 8:00 AM
5. Set end time: 10:00 PM
6. Interval: 120 minutes (2 hours)
7. Tap "Generate Times"
8. Save

**Expected**:
- ✅ 8 reminder times generated (8 AM to 10 PM, every 2 hours)
- ✅ All times visible in list
- ✅ 8 notifications scheduled
- ✅ Success message shown

#### Test 5.2: Custom Water Reminder Times
**Steps**:
1. Open water reminder settings
2. Tap "Add Custom Time"
3. Select time: 1 minute from now
4. Save
5. Wait for notification

**Expected**:
- ✅ Custom time added to list
- ✅ Notification appears at specified time
- ✅ "Time to drink water! Stay hydrated" message

#### Test 5.3: Delete Water Reminder Time
**Steps**:
1. Open water reminder settings
2. Tap delete icon on a time
3. Save

**Expected**:
- ✅ Time removed from list
- ✅ Notification cancelled
- ✅ Settings updated

---

### 6. Period Reminders

#### Test 6.1: Setup Period Tracking
**Steps**:
1. Settings → Period Tracking
2. Complete intro and setup
3. Set last period date
4. Set cycle length: 28 days

**Expected**:
- ✅ Period data saved
- ✅ Next period date calculated

#### Test 6.2: Configure Period Reminder
**Steps**:
1. (Implement period reminder UI - currently missing)
2. Set reminder: 2 days before period
3. Set time: 9:00 AM
4. Enable reminder
5. Save

**Expected**:
- ✅ Reminder scheduled for 2 days before next period
- ✅ Notification shows "Your period is expected in 2 days"

---

### 7. Lock Screen Notifications

#### Test 7.1: Lock Screen Visibility
**Steps**:
1. Schedule medicine reminder for 1 minute
2. Lock device
3. Wait for notification

**Expected**:
- ✅ Device wakes up
- ✅ Notification visible on lock screen
- ✅ Full content visible (not hidden)
- ✅ Action buttons accessible
- ✅ Sound plays
- ✅ Vibration works

#### Test 7.2: Full Screen Intent
**Steps**:
1. Schedule reminder
2. Lock device
3. Screen should be off
4. Wait for notification

**Expected**:
- ✅ Screen turns on
- ✅ Lock screen shows notification immediately
- ✅ LED light blinks (if device has LED)

---

### 8. Boot Persistence

#### Test 8.1: Restart Device
**Steps**:
1. Add 3-4 reminders (medicine, health, fitness)
2. Note scheduled times
3. Restart device
4. Launch app
5. Check notification settings

**Expected**:
- ✅ App initializes successfully
- ✅ All reminders rescheduled automatically
- ✅ Pending notification count matches
- ✅ Reminders trigger at correct times

**Check Logs For**:
```
🔄 Rescheduling all reminders...
✓ Rescheduled X reminders successfully
```

#### Test 8.2: Force Stop & Reopen
**Steps**:
1. Add reminders
2. Force stop app in settings
3. Wait for scheduled time (reminder should NOT appear)
4. Reopen app
5. Check reminders reschedule

**Expected**:
- ⚠️ Reminders missed during force stop
- ✅ Reminders rescheduled on app launch
- ✅ Future reminders work correctly

---

### 9. Focus Mode

#### Test 9.1: Enable Focus Mode
**Steps**:
1. Settings → Focus Mode
2. Enable toggle
3. Set start time: Current time
4. Set end time: 1 hour from now
5. Select allowed types: Only Medicine
6. Save

**Expected**:
- ✅ Settings saved
- ✅ Success message shown
- ✅ Settings persist after app restart

#### Test 9.2: Focus Mode Filtering
**Steps**:
1. Configure focus mode (active now)
2. Schedule medicine reminder (allowed)
3. Schedule fitness reminder (blocked)
4. Wait for both times

**Expected**:
- ✅ Medicine notification appears (allowed)
- 🚧 Fitness notification blocked (implement filtering logic)
- ✅ Blocked reminders queued for later

**Note**: Focus mode filtering needs to be integrated with notification service.

---

### 10. Reminder Analysis

#### Test 10.1: View Statistics
**Steps**:
1. Add 5 medicine reminders (3 enabled, 2 disabled)
2. Add 2 health checks (both enabled)
3. Add 1 fitness reminder (enabled)
4. Open Settings → Reminder Analysis

**Expected**:
- ✅ Total Reminders: 8
- ✅ Active Reminders: 6
- ✅ Adherence Rate: 75%

#### Test 10.2: Breakdown Accuracy
**Steps**:
1. View reminder breakdown

**Expected**:
- ✅ Medicine: 3
- ✅ Health Check: 2
- ✅ Fitness: 1
- ✅ Water: (depends on setup)
- ✅ Period: (depends on setup)

#### Test 10.3: Today's Schedule
**Steps**:
1. Add reminders at different times today
2. View "Today's Schedule"

**Expected**:
- ✅ All today's reminders listed
- ✅ Sorted by time (earliest first)
- ✅ Shows time, name, dosage
- ✅ Max 5 items displayed

---

### 11. Manage Medicines Screen

#### Test 11.1: View Medicine List
**Steps**:
1. Settings → Manage Medicines

**Expected**:
- ✅ Screen opens (not blank!)
- ✅ All medicines listed
- ✅ Shows dosage, time, frequency
- ✅ Reminder status indicator

#### Test 11.2: Empty State
**Steps**:
1. Delete all medicines
2. Open Manage Medicines

**Expected**:
- ✅ Empty state shown
- ✅ "No Medicines Yet" message
- ✅ "Add Medicine" button visible

#### Test 11.3: Quick Actions
**Steps**:
1. Tap + icon in header
2. Tap floating action button
3. Tap a medicine card

**Expected**:
- ✅ Header + opens add flow
- ✅ FAB opens add flow
- ✅ Card tap opens edit screen

---

### 12. Notification Settings Screen

#### Test 12.1: View Status
**Steps**:
1. Settings → Notifications

**Expected**:
- ✅ Permission status shown
- ✅ Pending notification count
- ✅ Test notification button works

#### Test 12.2: Test Notification
**Steps**:
1. Tap "Send Test Notification"

**Expected**:
- ✅ Notification appears immediately
- ✅ Visible on lock screen
- ✅ Sound and vibration work

#### Test 12.3: Pending Notifications List
**Steps**:
1. Schedule multiple reminders
2. View pending list

**Expected**:
- ✅ All scheduled notifications shown
- ✅ Shows time, title, body
- ✅ Updates when reminders added/removed

---

### 13. All Reminders Screen

#### Test 13.1: View Overview
**Steps**:
1. Navigation → All Reminders

**Expected**:
- ✅ Statistics card shows correct counts
- ✅ Each category displays active/total
- ✅ Icons and colors correct

#### Test 13.2: Navigation Links
**Steps**:
1. Tap each category card

**Expected**:
- ✅ Medicine → Add medicine flow
- ✅ Health Check → Add health check
- ✅ Fitness → Add fitness
- ✅ Water → Water reminder settings
- ✅ Period → (implement navigation)

---

### 14. Edge Cases & Error Handling

#### Test 14.1: No Internet
**Steps**:
1. Disable WiFi and mobile data
2. Add reminder
3. Restart app

**Expected**:
- ✅ App works offline
- ✅ Reminders schedule locally
- ✅ Firebase sync queued for later

#### Test 14.2: Time Change
**Steps**:
1. Schedule reminder for tomorrow 9 AM
2. Change device time to tomorrow 8:55 AM
3. Wait 5 minutes

**Expected**:
- ✅ Notification appears at "9 AM"
- ✅ No duplicate notifications

#### Test 14.3: Timezone Change
**Steps**:
1. Schedule reminder
2. Change device timezone
3. Restart app

**Expected**:
- ✅ Reminders adjusted to new timezone
- ✅ Times display correctly

#### Test 14.4: Low Battery Mode
**Steps**:
1. Enable battery saver
2. Schedule reminder
3. Lock device
4. Wait for reminder

**Expected**:
- ✅ Notification still appears
- ✅ exactAllowWhileIdle works

#### Test 14.5: Multiple Simultaneous Reminders
**Steps**:
1. Schedule 5 reminders at same time
2. Wait for time

**Expected**:
- ✅ All 5 notifications appear
- ✅ No crashes
- ✅ All visible in notification shade

---

### 15. Performance & UX

#### Test 15.1: App Launch Time
**Expected**:
- ✅ Cold start < 3 seconds
- ✅ Warm start < 1 second

#### Test 15.2: Memory Usage
**Monitor**:
- App size < 50MB
- Memory usage < 150MB
- No memory leaks

#### Test 15.3: UI Responsiveness
**Test**:
- Smooth scrolling in lists
- No lag when adding reminders
- Animations smooth (60fps)

#### Test 15.4: Battery Impact
**Expected**:
- Minimal battery drain
- Background work optimized
- No wakelocks

---

## 🐛 Known Issues to Fix

### Critical
1. **Period Reminder UI**: No UI to configure period reminders
2. **Focus Mode Integration**: Settings saved but not applied to notifications
3. **Notification Action Buttons**: "Mark Done" and "Dismiss" need handlers

### Medium
4. **Medicine Stock Tracking**: Buy reminder not implemented
5. **Notification Sound**: Custom sound not loading (fallback to default)
6. **Recurring Notification Gaps**: Edge case with frequency calculations

### Low
7. **Deprecated APIs**: withOpacity warnings (cosmetic)
8. **Empty State Animations**: Could be more engaging
9. **Error Messages**: Could be more user-friendly

---

## 🎯 Success Criteria

### Must Pass (Blockers)
- ✅ All reminder types schedule successfully
- ✅ Notifications appear on time
- ✅ Lock screen notifications work
- ✅ Boot persistence works
- ✅ No crashes during normal use
- ✅ Permission handling works correctly

### Should Pass (Important)
- ✅ Focus mode settings save correctly
- ✅ Reminder analysis shows accurate data
- ✅ Manage medicines screen works
- ✅ All UI screens render properly
- ✅ Navigation works smoothly

### Nice to Have (Future)
- ⏳ Focus mode actually filters notifications
- ⏳ Period reminder UI implementation
- ⏳ Custom notification sounds work
- ⏳ Medicine stock tracking
- ⏳ Notification action button handlers

---

## 📊 Test Results Template

### Device Info
- **Device**: [Model]
- **Android Version**: [Version]
- **App Version**: 1.0.0
- **Test Date**: [Date]

### Results Summary
- **Total Tests**: 70+
- **Passed**: ___
- **Failed**: ___
- **Blocked**: ___
- **Pass Rate**: ___%

### Critical Failures
1. [Issue description]
2. [Issue description]

### Recommendations
1. [Priority fix]
2. [Priority fix]

---

## 🚀 Next Steps After Testing

1. **Fix Critical Issues**: Address all blockers first
2. **Optimize Performance**: Address any slowness
3. **Implement Missing Features**:
   - Period reminder UI
   - Focus mode notification filtering
   - Notification action handlers
4. **Polish UI/UX**: Fix any visual glitches
5. **Beta Testing**: Distribute to test users
6. **Production Release**: Deploy to Play Store

---

**This comprehensive test plan ensures your reminder app is production-ready and works flawlessly! 🎉**

/// Every user-facing literal the device suites assert on, in ONE place, each
/// with the `file:line` it came from.
///
/// **Why this file exists.** Four integration suites rotted into uselessness by
/// asserting strings that had been deleted from `lib/` months earlier —
/// `'Save Reminder'`, `'Medicine Tracker'`, `'What would you like to add?'`,
/// `'Add Medicine'`, `'AI Assistant'`. Each still "passed" or failed for a
/// reason nobody read. Scattered across seven files, nothing could check them.
///
/// Collected here, `test/e2e_hygiene/e2e_string_registry_test.dart` greps `lib/`
/// for every one of them in under a second, headless, on every `flutter test`.
/// The day a string is renamed, that test names it.
///
/// Rules:
///  * one `const` per line, plain literal — the registry test parses this file
///  * every entry carries the source it was copied from
///  * if a string legitimately disappears, delete the const AND its assertions
library;

// ── shell / nav ───────────────────────────────────────────────────────────
const kNavToday = 'Today'; // app_shell.dart:208
const kNavMeds = 'Meds'; // app_shell.dart:214
const kNavLog = 'Log'; // app_shell.dart:220
const kNavHealth = 'Health'; // app_shell.dart:227
const kNavTrends = 'Trends'; // app_shell.dart:233

// ── Today ─────────────────────────────────────────────────────────────────
const kTodayHeader = 'Today'; // home_dashboard.dart:661
const kTodayCustomizeSheet = 'Customize Today'; // home_dashboard.dart:566
const kTodayYourDay = 'Your day'; // home_dashboard.dart:733
const kTodayNoMedicines = 'No medicines yet'; // home_dashboard.dart:1108
const kTodayCustomize = 'Customize'; // home_dashboard.dart:735
const kHeroNothingLeft = 'Nothing left to take today'; // home_dashboard.dart:412

// Today pulse-row KPI labels.
//
// Two traps. 'Meds'/'Water'/'Focus' also appear in the nav bar and the Health
// hub, and the shell keeps every tab alive, so assertions must be SCOPED to
// HomeDashboard. And KpiCell renders `label.toUpperCase()` (insight_kit.dart),
// so the text on screen is MEDS — assert with `.toUpperCase()`. The constants
// stay in their source casing because the registry test greps lib/ for them.
const kKpiMeds = 'Meds'; // home_dashboard.dart:779
const kKpiWater = 'Water'; // home_dashboard.dart:789
const kKpiFocus = 'Focus'; // home_dashboard.dart:799
const kKpiReminders = 'Reminders'; // home_dashboard.dart:809

// ── Log something sheet ───────────────────────────────────────────────────
const kLogSheetTitle = 'Log something'; // log_something_sheet.dart:31
const kLogMedicineDose = 'Medicine dose'; // log_something_sheet.dart:43
const kLogWater = 'Water'; // log_something_sheet.dart:45
const kLogBloodPressure = 'Blood pressure'; // log_something_sheet.dart:48
const kLogBloodSugar = 'Blood sugar'; // log_something_sheet.dart:50
const kLogWeight = 'Weight'; // log_something_sheet.dart:53
const kLogMood = 'Mood'; // log_something_sheet.dart:55
const kLogSteps = 'Steps'; // log_something_sheet.dart:57
const kLogSleep = 'Sleep'; // log_something_sheet.dart:59
const kLogPeriod = 'Period / mood'; // log_something_sheet.dart:61

// ── Health hub ────────────────────────────────────────────────────────────
const kHealthTrackers = 'Your trackers'; // health_browse_screen.dart:128
const kHealthWeeklyRecap = 'Weekly recap'; // health_browse_screen.dart:107
const kHealthConditionLibrary = 'Condition library'; // health_browse_screen.dart:118

// ── Medication ────────────────────────────────────────────────────────────
const kMedsHeader = 'Medicine'; // nunito_medication_dashboard.dart:545
const kMedsCareTeam = 'Care team'; // nunito_medication_dashboard.dart:1579

// ── Trends ────────────────────────────────────────────────────────────────
const kTrends7 = '7 days'; // trends_data_service.dart:43
const kTrends14 = '14 days'; // trends_data_service.dart:45
const kTrends30 = '30 days'; // trends_data_service.dart:47

// ── Diary ─────────────────────────────────────────────────────────────────
const kDiaryTile = 'Diary'; // health_browse_screen.dart:77
const kDiaryNewEntry = 'New entry'; // diary_screen.dart:76
const kDiaryEditEntry = 'Edit entry'; // diary_entry_screen.dart:72
const kDiaryEntryDeleted = 'Entry deleted'; // diary_screen.dart:54

// ── shared ────────────────────────────────────────────────────────────────
const kUndo = 'Undo'; // diary_screen.dart:57, app_shell.dart:99, and others

// ── Water ─────────────────────────────────────────────────────────────────
const kWaterTodayLog = "Today's Log"; // aqua_water_dashboard.dart:563

// ── Medication: dose actions ──────────────────────────────────────────────
const kMedsTakeNow = 'Take Now'; // nunito_medication_dashboard.dart:1276
const kMedsTake = 'Take'; // nunito_medication_dashboard.dart:1276
const kMedsTakeMedication = 'Take Medication'; // nunito_take_medication_sheet.dart:784
const kMedsSkip = 'Skip'; // nunito_take_medication_sheet.dart:809

// ── Vitals: blood pressure ────────────────────────────────────────────────
const kBpLogFab = 'Log'; // blood_pressure_screen.dart:121
const kBpSystolic = 'Systolic (mmHg)'; // blood_pressure_screen.dart:631
const kBpDiastolic = 'Diastolic (mmHg)'; // blood_pressure_screen.dart:642
const kBpSaveReading = 'Save reading'; // blood_pressure_screen.dart:705
const kBpCrisisTitle = 'Possible hypertensive crisis'; // blood_pressure_screen.dart:209
const kBpCallEmergency = 'Call emergency'; // blood_pressure_screen.dart:214
const kBpReMeasure = 'Re-measure'; // blood_pressure_screen.dart:216
const kBpReadingDeleted = 'Reading deleted'; // blood_pressure_screen.dart:99

// ── Reminders / Smart Add ─────────────────────────────────────────────────
const kRemindersCard = 'Reminders'; // home_dashboard.dart:1458 (Today card)
const kSmartAddTitle = 'Smart Add'; // reminders_screen.dart:139
const kSmartAddCreate = 'Create'; // reminders_screen.dart:203
const kSmartAddUnparsed =
    "Couldn't parse — fill it in manually"; // reminders_screen.dart:165
const kReminderTitleField = 'Title'; // add_reminder_screen.dart:392
const kRepeatEveryDay = 'Every Day'; // add_reminder_screen.dart:466

// ── Add-medication wizard ─────────────────────────────────────────────────
const kWizStep1 =
    'What medication are you adding?'; // nunito_add_medication_flow.dart:904
const kWizNameField = 'Medication Name'; // :910
const kWizStep2 = 'How much do you take?'; // :1419
const kWizStep3 = 'When do you take it?'; // :1748
const kWizContinue = 'Continue'; // :3180
const kWizAddMedication = 'Add Medication'; // :3179
const kWizInteraction = 'Possible drug interaction'; // :550
const kWizSaveAnyway = 'Save anyway'; // :568
const kWizCancel = 'Cancel'; // :563

import 'package:drift/drift.dart';

/// User Settings Table
class UserSettingsTable extends Table {
  @override
  String get tableName => 'user_settings';

  TextColumn get id => text().withDefault(const Constant('settings'))();
  IntColumn get waterDailyGoalMl => integer().withDefault(const Constant(2500))();
  BoolColumn get darkModeEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get soundEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get vibrationEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get preferredRingtone => text().nullable()();
  BoolColumn get showCompletedReminders => boolean().withDefault(const Constant(true))();
  IntColumn get reminderSnoozeMinutes => integer().withDefault(const Constant(10))();
  BoolColumn get autoMarkMissed => boolean().withDefault(const Constant(true))();
  IntColumn get missedThresholdMinutes => integer().withDefault(const Constant(60))();
  DateTimeColumn get lastSyncTime => dateTime().nullable()();
  BoolColumn get analyticsEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get locale => text().nullable()();
  IntColumn get alarmRingDurationSeconds => integer().withDefault(const Constant(30))();
  BoolColumn get snoozeEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get snoozeIntervalMinutes => integer().withDefault(const Constant(5))();
  IntColumn get maxSnoozeCount => integer().withDefault(const Constant(3))();
  TextColumn get notificationSound => text().withDefault(const Constant('default'))();
  BoolColumn get persistentNotification => boolean().withDefault(const Constant(true))();
  BoolColumn get showOnLockScreen => boolean().withDefault(const Constant(true))();
  BoolColumn get fullScreenNotification => boolean().withDefault(const Constant(true))();
  BoolColumn get isAdsDisabled => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Action Logs Table
class ActionLogs extends Table {
  TextColumn get id => text()();
  IntColumn get actionType => integer()(); // ActionType enum index
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get metadata => text().nullable()(); // JSON string
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// App Preferences Table (key-value store)
class AppPreferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();
  IntColumn get intValue => integer().nullable()();
  BoolColumn get boolValue => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

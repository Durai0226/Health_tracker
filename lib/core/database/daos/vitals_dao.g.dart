// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vitals_dao.dart';

// ignore_for_file: type=lint
mixin _$VitalsDaoMixin on DatabaseAccessor<AppDatabase> {
  $BloodPressureReadingsTable get bloodPressureReadings =>
      attachedDatabase.bloodPressureReadings;
  $GlucoseReadingsTable get glucoseReadings => attachedDatabase.glucoseReadings;
  $WeightReadingsTable get weightReadings => attachedDatabase.weightReadings;
  $MoodEntriesTable get moodEntries => attachedDatabase.moodEntries;
  VitalsDaoManager get managers => VitalsDaoManager(this);
}

class VitalsDaoManager {
  final _$VitalsDaoMixin _db;
  VitalsDaoManager(this._db);
  $$BloodPressureReadingsTableTableManager get bloodPressureReadings =>
      $$BloodPressureReadingsTableTableManager(
        _db.attachedDatabase,
        _db.bloodPressureReadings,
      );
  $$GlucoseReadingsTableTableManager get glucoseReadings =>
      $$GlucoseReadingsTableTableManager(
        _db.attachedDatabase,
        _db.glucoseReadings,
      );
  $$WeightReadingsTableTableManager get weightReadings =>
      $$WeightReadingsTableTableManager(
        _db.attachedDatabase,
        _db.weightReadings,
      );
  $$MoodEntriesTableTableManager get moodEntries =>
      $$MoodEntriesTableTableManager(_db.attachedDatabase, _db.moodEntries);
}

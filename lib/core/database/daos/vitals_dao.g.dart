// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vitals_dao.dart';

// ignore_for_file: type=lint
mixin _$VitalsDaoMixin on DatabaseAccessor<AppDatabase> {
  $BloodPressureReadingsTable get bloodPressureReadings =>
      attachedDatabase.bloodPressureReadings;
  $GlucoseReadingsTable get glucoseReadings => attachedDatabase.glucoseReadings;
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
}

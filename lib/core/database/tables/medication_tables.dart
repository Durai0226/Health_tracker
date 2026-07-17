import 'package:drift/drift.dart';

/// Enhanced Medicines Table
class EnhancedMedicines extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get genericName => text().nullable()();
  TextColumn get brandName => text().nullable()();
  IntColumn get dosageForm => integer()(); // DosageForm enum
  RealColumn get strength => real().withDefault(const Constant(1.0))();
  TextColumn get strengthUnit => text().withDefault(const Constant('mg'))();
  // The user-entered clinical strength string (e.g. "500mg"). Kept separate from
  // the strength/strengthUnit columns above, which store the dose amount+unit.
  TextColumn get strengthText => text().nullable()();
  TextColumn get instructions => text().nullable()();
  TextColumn get purpose => text().nullable()();
  TextColumn get sideEffectsJson => text().nullable()(); // JSON array
  TextColumn get warningsJson => text().nullable()(); // JSON array
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  IntColumn get shapeIndex => integer().withDefault(const Constant(0))();
  TextColumn get imagePath => text().nullable()();
  TextColumn get doctorId => text().nullable()();
  TextColumn get pharmacyId => text().nullable()();
  TextColumn get dependentId => text().nullable()();
  TextColumn get treatmentId => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get currentStock => integer().withDefault(const Constant(0))();
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(7))();
  BoolColumn get refillReminder => boolean().withDefault(const Constant(true))();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  TextColumn get prescriptionNumber => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get scheduleJson => text()(); // Serialized MedicineSchedule
  
  // Missing fields from EnhancedMedicine
  TextColumn get healthCategoriesJson => text().nullable()(); // List<int> indices
  TextColumn get customHealthCategory => text().nullable()();
  TextColumn get patientProfileId => text().nullable()();
  BoolColumn get requiresContinuousIntake => boolean().withDefault(const Constant(false))();
  IntColumn get minimumConsecutiveDays => integer().nullable()();
  TextColumn get customFieldsJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Medicine Logs Table
class MedicineLogs extends Table {
  TextColumn get id => text()();
  TextColumn get medicineId => text()();
  DateTimeColumn get scheduledTime => dateTime()();
  DateTimeColumn get actualTime => dateTime().nullable()();
  BoolColumn get isTaken => boolean().withDefault(const Constant(false))();
  BoolColumn get isSkipped => boolean().withDefault(const Constant(false))();
  BoolColumn get isMissed => boolean().withDefault(const Constant(false))();
  RealColumn get dosageTaken => real().withDefault(const Constant(1.0))();
  IntColumn get skipReason => integer().nullable()(); // SkipReason enum
  TextColumn get skipNote => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get sideEffects => text().nullable()();
  IntColumn get moodRating => integer().nullable()();
  IntColumn get effectivenessRating => integer().nullable()();
  TextColumn get vitalsJson => text().nullable()(); // JSON
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  
  // Missing fields from MedicineLog
  TextColumn get dependentId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Medicine Schedules Table
class MedicineSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get medicineId => text()();
  IntColumn get frequencyType => integer()(); // FrequencyType enum
  TextColumn get timesJson => text()(); // JSON array of scheduled times
  TextColumn get daysOfWeekJson => text().nullable()(); // JSON array
  IntColumn get intervalDays => integer().nullable()();
  IntColumn get mealTiming => integer().nullable()(); // MealTiming enum
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Doctors Table
class Doctors extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get specialty => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get hospital => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Pharmacies Table
class Pharmacies extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get hours => text().nullable()();
  BoolColumn get hasDelivery => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Appointments Table
class Appointments extends Table {
    TextColumn get id => text()();
  // Missing fields from Appointment
  TextColumn get dependentId => text().nullable()();
  TextColumn get medicineIdsJson => text().nullable()(); // List<String>

  TextColumn get doctorId => text().nullable()();
  TextColumn get title => text()();
  DateTimeColumn get appointmentDateTime => dateTime()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(30))();
  TextColumn get location => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get reminderEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get reminderMinutesBefore => integer().withDefault(const Constant(60))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Dependent Profiles Table
class DependentProfiles extends Table {
  TextColumn get id => text()();
    TextColumn get name => text()();
  // Missing fields from DependentProfile
  TextColumn get gender => text().nullable()();
  RealColumn get weight => real().nullable()();
  RealColumn get height => real().nullable()();
  TextColumn get emergencyContact => text().nullable()();
  TextColumn get emergencyPhone => text().nullable()();
  TextColumn get primaryDoctorId => text().nullable()();
  TextColumn get insuranceInfo => text().nullable()();
  TextColumn get avatarPath => text().nullable()(); // Duplicate of photoPath? Domain has avatarPath.

  IntColumn get relationshipType => integer()(); // RelationshipType enum
  DateTimeColumn get dateOfBirth => dateTime().nullable()();
  TextColumn get bloodType => text().nullable()();
  TextColumn get allergiesJson => text().nullable()(); // JSON array
  TextColumn get conditionsJson => text().nullable()(); // JSON array
  TextColumn get notes => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  BoolColumn get isSelf => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Treatment Courses Table
class TreatmentCourses extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get condition => text().nullable()();
  TextColumn get doctorId => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get medicineIdsJson => text()(); // JSON array
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  
  // Missing fields from TreatmentCourse
  TextColumn get description => text().nullable()();
  TextColumn get dependentId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'doctor_pharmacy.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DoctorAdapter extends TypeAdapter<Doctor> {
  @override
  final int typeId = 62;

  @override
  Doctor read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Doctor(
      id: fields[0] as String,
      name: fields[1] as String,
      specialty: fields[2] as String?,
      phone: fields[3] as String?,
      email: fields[4] as String?,
      address: fields[5] as String?,
      clinicName: fields[6] as String?,
      notes: fields[7] as String?,
      isPrimary: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Doctor obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.specialty)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.email)
      ..writeByte(5)
      ..write(obj.address)
      ..writeByte(6)
      ..write(obj.clinicName)
      ..writeByte(7)
      ..write(obj.notes)
      ..writeByte(8)
      ..write(obj.isPrimary);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DoctorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PharmacyAdapter extends TypeAdapter<Pharmacy> {
  @override
  final int typeId = 63;

  @override
  Pharmacy read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Pharmacy(
      id: fields[0] as String,
      name: fields[1] as String,
      phone: fields[2] as String?,
      address: fields[3] as String?,
      email: fields[4] as String?,
      website: fields[5] as String?,
      hours: fields[6] as String?,
      hasDelivery: fields[7] as bool,
      isPrimary: fields[8] as bool,
      notes: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Pharmacy obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.phone)
      ..writeByte(3)
      ..write(obj.address)
      ..writeByte(4)
      ..write(obj.email)
      ..writeByte(5)
      ..write(obj.website)
      ..writeByte(6)
      ..write(obj.hours)
      ..writeByte(7)
      ..write(obj.hasDelivery)
      ..writeByte(8)
      ..write(obj.isPrimary)
      ..writeByte(9)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PharmacyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AppointmentAdapter extends TypeAdapter<Appointment> {
  @override
  final int typeId = 64;

  @override
  Appointment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Appointment(
      id: fields[0] as String,
      doctorId: fields[1] as String?,
      doctorName: fields[2] as String,
      dateTime: fields[3] as DateTime,
      location: fields[4] as String?,
      purpose: fields[5] as String?,
      notes: fields[6] as String?,
      reminderEnabled: fields[7] as bool,
      reminderMinutesBefore: fields[8] as int,
      isCompleted: fields[9] as bool,
      dependentId: fields[10] as String?,
      medicineIds: (fields[11] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Appointment obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.doctorId)
      ..writeByte(2)
      ..write(obj.doctorName)
      ..writeByte(3)
      ..write(obj.dateTime)
      ..writeByte(4)
      ..write(obj.location)
      ..writeByte(5)
      ..write(obj.purpose)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.reminderEnabled)
      ..writeByte(8)
      ..write(obj.reminderMinutesBefore)
      ..writeByte(9)
      ..write(obj.isCompleted)
      ..writeByte(10)
      ..write(obj.dependentId)
      ..writeByte(11)
      ..write(obj.medicineIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppointmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttendanceModelAdapter extends TypeAdapter<AttendanceModel> {
  @override
  final int typeId = 55;

  @override
  AttendanceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AttendanceModel(
      studentKeyHive: fields[0] as int,
      studentName: fields[1] as String,
      className: fields[2] as String,
      date: fields[3] as DateTime,
      status: fields[4] as String,
      reason: fields[5] as String?,
      subject: fields[6] as String,
      studentId: fields[7] as int?,
      classCycleType: fields[8] as String?,
      sectionId: fields[9] as String?,
      sectionName: fields[10] as String?,
      classFirestoreId: fields[11] as String?,
      studentFirestoreId: fields[12] as String?,
      schoolId: fields[13] as String?,
      attendanceFirestoreId: fields[14] as String?,
      classId: fields[15] as String?,
      studentIdFirestore: fields[16] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AttendanceModel obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.studentKeyHive)
      ..writeByte(1)
      ..write(obj.studentName)
      ..writeByte(2)
      ..write(obj.className)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.reason)
      ..writeByte(6)
      ..write(obj.subject)
      ..writeByte(7)
      ..write(obj.studentId)
      ..writeByte(8)
      ..write(obj.classCycleType)
      ..writeByte(9)
      ..write(obj.sectionId)
      ..writeByte(10)
      ..write(obj.sectionName)
      ..writeByte(11)
      ..write(obj.classFirestoreId)
      ..writeByte(12)
      ..write(obj.studentFirestoreId)
      ..writeByte(13)
      ..write(obj.schoolId)
      ..writeByte(14)
      ..write(obj.attendanceFirestoreId)
      ..writeByte(15)
      ..write(obj.classId)
      ..writeByte(16)
      ..write(obj.studentIdFirestore);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

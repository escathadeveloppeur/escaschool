// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StudentModelAdapter extends TypeAdapter<StudentModel> {
  @override
  final int typeId = 2;

  @override
  StudentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StudentModel(
      fullName: fields[0] as String,
      className: fields[1] as String,
      birthDate: fields[2] as String,
      birthPlace: fields[3] as String,
      fatherName: fields[4] as String,
      motherName: fields[5] as String,
      parentPhone: fields[6] as String,
      address: fields[7] as String,
      documentsVerified: fields[8] as bool,
      userId: fields[9] as int?,
      classHiveKey: fields[10] as int?,
      HiveKey: fields[11] as int?,
      parentUserId: fields[12] as int?,
      parentRelation: fields[13] as String?,
      schoolId: fields[14] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, StudentModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.fullName)
      ..writeByte(1)
      ..write(obj.className)
      ..writeByte(2)
      ..write(obj.birthDate)
      ..writeByte(3)
      ..write(obj.birthPlace)
      ..writeByte(4)
      ..write(obj.fatherName)
      ..writeByte(5)
      ..write(obj.motherName)
      ..writeByte(6)
      ..write(obj.parentPhone)
      ..writeByte(7)
      ..write(obj.address)
      ..writeByte(8)
      ..write(obj.documentsVerified)
      ..writeByte(9)
      ..write(obj.userId)
      ..writeByte(10)
      ..write(obj.classHiveKey)
      ..writeByte(11)
      ..write(obj.HiveKey)
      ..writeByte(12)
      ..write(obj.parentUserId)
      ..writeByte(13)
      ..write(obj.parentRelation)
      ..writeByte(14)
      ..write(obj.schoolId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudentModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

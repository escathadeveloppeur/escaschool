// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'professor_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProfessorModelAdapter extends TypeAdapter<ProfessorModel> {
  @override
  final int typeId = 7;

  @override
  ProfessorModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProfessorModel(
      id: fields[0] as int,
      userId: fields[1] as int?,
      fullName: fields[2] as String,
      email: fields[3] as String,
      phone: fields[4] as String?,
      specialty: fields[5] as String?,
      status: fields[6] as String,
      createdAt: fields[7] as String,
      updatedAt: fields[8] as String?,
      schoolId: fields[9] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, ProfessorModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.fullName)
      ..writeByte(3)
      ..write(obj.email)
      ..writeByte(4)
      ..write(obj.phone)
      ..writeByte(5)
      ..write(obj.specialty)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.schoolId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessorModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

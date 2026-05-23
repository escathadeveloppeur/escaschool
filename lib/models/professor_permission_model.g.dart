// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'professor_permission_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProfessorPermissionModelAdapter
    extends TypeAdapter<ProfessorPermissionModel> {
  @override
  final int typeId = 9;

  @override
  ProfessorPermissionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProfessorPermissionModel(
      id: fields[0] as int,
      professorId: fields[1] as int,
      classId: fields[2] as int,
      permissionType: fields[3] as String,
      grantedAt: fields[4] as String,
      updatedAt: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProfessorPermissionModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.professorId)
      ..writeByte(2)
      ..write(obj.classId)
      ..writeByte(3)
      ..write(obj.permissionType)
      ..writeByte(4)
      ..write(obj.grantedAt)
      ..writeByte(5)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfessorPermissionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

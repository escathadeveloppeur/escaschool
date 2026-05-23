// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'departement_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DepartementModelAdapter extends TypeAdapter<DepartementModel> {
  @override
  final int typeId = 17;

  @override
  DepartementModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DepartementModel(
      id: fields[0] as int,
      faculteId: fields[1] as int,
      nom: fields[2] as String,
      code: fields[3] as String?,
      responsable: fields[4] as String?,
      description: fields[5] as String?,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DepartementModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.faculteId)
      ..writeByte(2)
      ..write(obj.nom)
      ..writeByte(3)
      ..write(obj.code)
      ..writeByte(4)
      ..write(obj.responsable)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepartementModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

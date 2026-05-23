// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'faculte_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FaculteModelAdapter extends TypeAdapter<FaculteModel> {
  @override
  final int typeId = 16;

  @override
  FaculteModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FaculteModel(
      id: fields[0] as int,
      etablissementId: fields[1] as int,
      nom: fields[2] as String,
      code: fields[3] as String?,
      description: fields[4] as String?,
      doyen: fields[5] as String?,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FaculteModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.etablissementId)
      ..writeByte(2)
      ..write(obj.nom)
      ..writeByte(3)
      ..write(obj.code)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.doyen)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaculteModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

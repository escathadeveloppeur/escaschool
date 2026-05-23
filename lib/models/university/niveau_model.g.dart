// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'niveau_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NiveauModelAdapter extends TypeAdapter<NiveauModel> {
  @override
  final int typeId = 18;

  @override
  NiveauModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NiveauModel(
      id: fields[0] as int,
      departementId: fields[1] as int,
      nom: fields[2] as String,
      ordre: fields[3] as int,
      duree: fields[4] as int,
      description: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, NiveauModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.departementId)
      ..writeByte(2)
      ..write(obj.nom)
      ..writeByte(3)
      ..write(obj.ordre)
      ..writeByte(4)
      ..write(obj.duree)
      ..writeByte(5)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NiveauModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

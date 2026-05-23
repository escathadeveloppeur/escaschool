// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'module_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ModuleModelAdapter extends TypeAdapter<ModuleModel> {
  @override
  final int typeId = 19;

  @override
  ModuleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ModuleModel(
      id: fields[0] as int,
      niveauId: fields[1] as int,
      code: fields[2] as String,
      nom: fields[3] as String,
      creditsECTS: fields[4] as int,
      heuresCM: fields[5] as int,
      heuresTD: fields[6] as int,
      heuresTP: fields[7] as int,
      coefficient: fields[8] as double,
      semestre: fields[9] as String,
      professeurId: fields[10] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ModuleModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.niveauId)
      ..writeByte(2)
      ..write(obj.code)
      ..writeByte(3)
      ..write(obj.nom)
      ..writeByte(4)
      ..write(obj.creditsECTS)
      ..writeByte(5)
      ..write(obj.heuresCM)
      ..writeByte(6)
      ..write(obj.heuresTD)
      ..writeByte(7)
      ..write(obj.heuresTP)
      ..writeByte(8)
      ..write(obj.coefficient)
      ..writeByte(9)
      ..write(obj.semestre)
      ..writeByte(10)
      ..write(obj.professeurId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModuleModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'etablissement_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EtablissementModelAdapter extends TypeAdapter<EtablissementModel> {
  @override
  final int typeId = 15;

  @override
  EtablissementModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EtablissementModel(
      id: fields[0] as int?,
      nom: fields[1] as String,
      type: fields[2] as String,
      adresse: fields[3] as String?,
      telephone: fields[4] as String?,
      email: fields[5] as String?,
      siteWeb: fields[6] as String?,
      firestoreId: fields[7] as String?,
      createdAt: fields[8] as DateTime?,
      updatedAt: fields[9] as DateTime?,
      isActive: fields[10] as bool,
      schoolCode: fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, EtablissementModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nom)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.adresse)
      ..writeByte(4)
      ..write(obj.telephone)
      ..writeByte(5)
      ..write(obj.email)
      ..writeByte(6)
      ..write(obj.siteWeb)
      ..writeByte(7)
      ..write(obj.firestoreId)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.isActive)
      ..writeByte(11)
      ..write(obj.schoolCode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EtablissementModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

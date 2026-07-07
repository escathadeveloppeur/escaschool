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
      pays: fields[12] as String?,
      province: fields[13] as String?,
      ville: fields[14] as String?,
      commune: fields[15] as String?,
      codePostal: fields[16] as String?,
      statut: fields[17] as String?,
      directeurNom: fields[18] as String?,
      directeurEmail: fields[19] as String?,
      directeurTelephone: fields[20] as String?,
      anneeCreation: fields[21] as int?,
      capacite: fields[22] as int?,
      langueEnseignement: fields[23] as String?,
      logoUrl: fields[24] as String?,
      signaturePrefet: fields[25] as String?,
      signatureChef: fields[26] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, EtablissementModel obj) {
    writer
      ..writeByte(27)
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
      ..write(obj.schoolCode)
      ..writeByte(12)
      ..write(obj.pays)
      ..writeByte(13)
      ..write(obj.province)
      ..writeByte(14)
      ..write(obj.ville)
      ..writeByte(15)
      ..write(obj.commune)
      ..writeByte(16)
      ..write(obj.codePostal)
      ..writeByte(17)
      ..write(obj.statut)
      ..writeByte(18)
      ..write(obj.directeurNom)
      ..writeByte(19)
      ..write(obj.directeurEmail)
      ..writeByte(20)
      ..write(obj.directeurTelephone)
      ..writeByte(21)
      ..write(obj.anneeCreation)
      ..writeByte(22)
      ..write(obj.capacite)
      ..writeByte(23)
      ..write(obj.langueEnseignement)
      ..writeByte(24)
      ..write(obj.logoUrl)
      ..writeByte(25)
      ..write(obj.signaturePrefet)
      ..writeByte(26)
      ..write(obj.signatureChef);
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

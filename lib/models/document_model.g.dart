// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DocumentModelAdapter extends TypeAdapter<DocumentModel> {
  @override
  final int typeId = 4;

  @override
  DocumentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DocumentModel(
      fullName: fields[0] as String,
      className: fields[1] as String,
      docType: fields[2] as String,
      keyHive: fields[4] as int,
      isValidated: fields[3] as bool,
      schoolId: fields[5] as int,
      firestoreId: fields[6] as String?,
      fileUrl: fields[7] as String?,
      createdAt: fields[8] as DateTime?,
      schoolFirestoreId: fields[9] as String?,
      classId: fields[10] as String?,
      studentId: fields[11] as String?,
      documentFirestoreId: fields[12] as String?,
      validatedBy: fields[13] as String?,
      validatedAt: fields[14] as DateTime?,
      localKey: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DocumentModel obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.fullName)
      ..writeByte(1)
      ..write(obj.className)
      ..writeByte(2)
      ..write(obj.docType)
      ..writeByte(3)
      ..write(obj.isValidated)
      ..writeByte(4)
      ..write(obj.keyHive)
      ..writeByte(5)
      ..write(obj.schoolId)
      ..writeByte(6)
      ..write(obj.firestoreId)
      ..writeByte(7)
      ..write(obj.fileUrl)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.schoolFirestoreId)
      ..writeByte(10)
      ..write(obj.classId)
      ..writeByte(11)
      ..write(obj.studentId)
      ..writeByte(12)
      ..write(obj.documentFirestoreId)
      ..writeByte(13)
      ..write(obj.validatedBy)
      ..writeByte(14)
      ..write(obj.validatedAt)
      ..writeByte(15)
      ..write(obj.localKey);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

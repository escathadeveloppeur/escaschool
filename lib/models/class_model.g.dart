// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'class_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ClassModelAdapter extends TypeAdapter<ClassModel> {
  @override
  final int typeId = 1;

  @override
  ClassModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ClassModel(
      key: fields[0] as int?,
      className: fields[1] as String,
      level: fields[2] as String?,
      year: fields[3] as String?,
      teacher: fields[4] as String?,
      schoolId: fields[8] as String?,
      students: (fields[5] as List).cast<String>(),
      hiveKey: fields[6] as int?,
      subjects: (fields[7] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      firestoreId: fields[9] as String?,
      sectionId: fields[10] as String?,
      section: fields[11] as String?,
      cycleType: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ClassModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.key)
      ..writeByte(1)
      ..write(obj.className)
      ..writeByte(2)
      ..write(obj.level)
      ..writeByte(3)
      ..write(obj.year)
      ..writeByte(4)
      ..write(obj.teacher)
      ..writeByte(5)
      ..write(obj.students)
      ..writeByte(6)
      ..write(obj.hiveKey)
      ..writeByte(7)
      ..write(obj.subjects)
      ..writeByte(8)
      ..write(obj.schoolId)
      ..writeByte(9)
      ..write(obj.firestoreId)
      ..writeByte(10)
      ..write(obj.sectionId)
      ..writeByte(11)
      ..write(obj.section)
      ..writeByte(12)
      ..write(obj.cycleType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SectionModelAdapter extends TypeAdapter<SectionModel> {
  @override
  final int typeId = 2;

  @override
  SectionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SectionModel(
      id: fields[0] as String?,
      name: fields[1] as String,
      description: fields[2] as String,
      subjects: (fields[3] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      schoolId: fields[4] as String,
      createdAt: fields[5] as DateTime,
      firestoreId: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SectionModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.subjects)
      ..writeByte(4)
      ..write(obj.schoolId)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.firestoreId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SectionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

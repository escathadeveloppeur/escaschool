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
      schoolId: fields[8] as int?,
      students: (fields[5] as List).cast<String>(),
      hiveKey: fields[6] as int?,
      subjects: (fields[7] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      firestoreId: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ClassModel obj) {
    writer
      ..writeByte(10)
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
      ..write(obj.firestoreId);
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

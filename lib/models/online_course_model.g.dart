// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'online_course_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OnlineCourseModelAdapter extends TypeAdapter<OnlineCourseModel> {
  @override
  final int typeId = 14;

  @override
  OnlineCourseModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OnlineCourseModel(
      id: fields[0] as int,
      title: fields[1] as String,
      description: fields[2] as String,
      subject: fields[3] as String,
      className: fields[4] as String,
      classId: fields[5] as int,
      professorId: fields[6] as int,
      chapters: (fields[7] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      resources: (fields[8] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      createdAt: fields[9] as DateTime,
      updatedAt: fields[10] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, OnlineCourseModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.subject)
      ..writeByte(4)
      ..write(obj.className)
      ..writeByte(5)
      ..write(obj.classId)
      ..writeByte(6)
      ..write(obj.professorId)
      ..writeByte(7)
      ..write(obj.chapters)
      ..writeByte(8)
      ..write(obj.resources)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnlineCourseModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

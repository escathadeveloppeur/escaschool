// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'online_exam_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OnlineExamModelAdapter extends TypeAdapter<OnlineExamModel> {
  @override
  final int typeId = 12;

  @override
  OnlineExamModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OnlineExamModel(
      id: fields[0] as int,
      title: fields[1] as String,
      description: fields[2] as String,
      subject: fields[3] as String,
      className: fields[4] as String,
      classId: fields[5] as int,
      professorId: fields[6] as int,
      startDate: fields[7] as DateTime,
      endDate: fields[8] as DateTime,
      duration: fields[9] as int,
      totalPoints: fields[10] as int,
      questions: (fields[11] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      status: fields[12] as String,
      createdAt: fields[13] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, OnlineExamModel obj) {
    writer
      ..writeByte(14)
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
      ..write(obj.startDate)
      ..writeByte(8)
      ..write(obj.endDate)
      ..writeByte(9)
      ..write(obj.duration)
      ..writeByte(10)
      ..write(obj.totalPoints)
      ..writeByte(11)
      ..write(obj.questions)
      ..writeByte(12)
      ..write(obj.status)
      ..writeByte(13)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnlineExamModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

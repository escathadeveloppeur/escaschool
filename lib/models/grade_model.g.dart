// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grade_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GradeModelAdapter extends TypeAdapter<GradeModel> {
  @override
  final int typeId = 6;

  @override
  GradeModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GradeModel(
      studentKeyHive: fields[0] as int,
      studentName: fields[1] as String,
      className: fields[2] as String,
      subject: fields[3] as String,
      evaluationType: fields[4] as String,
      score: fields[5] as double,
      maxScore: fields[6] as double,
      date: fields[7] as DateTime,
      coefficient: fields[8] as double,
      comments: fields[9] as String?,
      firestoreId: fields[10] as String?,
      teacher: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, GradeModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.studentKeyHive)
      ..writeByte(1)
      ..write(obj.studentName)
      ..writeByte(2)
      ..write(obj.className)
      ..writeByte(3)
      ..write(obj.subject)
      ..writeByte(4)
      ..write(obj.evaluationType)
      ..writeByte(5)
      ..write(obj.score)
      ..writeByte(6)
      ..write(obj.maxScore)
      ..writeByte(7)
      ..write(obj.date)
      ..writeByte(8)
      ..write(obj.coefficient)
      ..writeByte(9)
      ..write(obj.comments)
      ..writeByte(10)
      ..write(obj.firestoreId)
      ..writeByte(11)
      ..write(obj.teacher);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GradeModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

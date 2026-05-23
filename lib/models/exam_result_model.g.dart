// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_result_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExamResultModelAdapter extends TypeAdapter<ExamResultModel> {
  @override
  final int typeId = 13;

  @override
  ExamResultModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExamResultModel(
      examId: fields[0] as int,
      studentId: fields[1] as int,
      studentName: fields[2] as String,
      score: fields[3] as int,
      totalPoints: fields[4] as int,
      answers: (fields[5] as List)
          .map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
      submittedAt: fields[6] as DateTime,
      isGraded: fields[7] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ExamResultModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.examId)
      ..writeByte(1)
      ..write(obj.studentId)
      ..writeByte(2)
      ..write(obj.studentName)
      ..writeByte(3)
      ..write(obj.score)
      ..writeByte(4)
      ..write(obj.totalPoints)
      ..writeByte(5)
      ..write(obj.answers)
      ..writeByte(6)
      ..write(obj.submittedAt)
      ..writeByte(7)
      ..write(obj.isGraded);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExamResultModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

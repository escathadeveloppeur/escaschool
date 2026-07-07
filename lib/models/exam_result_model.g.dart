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
      examFirestoreId: fields[8] as String?,
      studentFirestoreId: fields[9] as String?,
      resultFirestoreId: fields[10] as String?,
      localKey: fields[11] as String?,
      schoolId: fields[12] as String?,
      schoolFirestoreId: fields[13] as String?,
      percentage: fields[14] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, ExamResultModel obj) {
    writer
      ..writeByte(15)
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
      ..write(obj.isGraded)
      ..writeByte(8)
      ..write(obj.examFirestoreId)
      ..writeByte(9)
      ..write(obj.studentFirestoreId)
      ..writeByte(10)
      ..write(obj.resultFirestoreId)
      ..writeByte(11)
      ..write(obj.localKey)
      ..writeByte(12)
      ..write(obj.schoolId)
      ..writeByte(13)
      ..write(obj.schoolFirestoreId)
      ..writeByte(14)
      ..write(obj.percentage);
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

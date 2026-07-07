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
      schoolFirestoreId: fields[14] as String?,
      examFirestoreId: fields[15] as String?,
      classFirestoreId: fields[16] as String?,
      professorFirestoreId: fields[17] as String?,
      localKey: fields[18] as String?,
      schoolId: fields[19] as int?,
      enrolledStudents: fields[20] as int?,
      averageScore: fields[21] as double?,
      isPublished: fields[22] as bool?,
      updatedAt: fields[23] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, OnlineExamModel obj) {
    writer
      ..writeByte(24)
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
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.schoolFirestoreId)
      ..writeByte(15)
      ..write(obj.examFirestoreId)
      ..writeByte(16)
      ..write(obj.classFirestoreId)
      ..writeByte(17)
      ..write(obj.professorFirestoreId)
      ..writeByte(18)
      ..write(obj.localKey)
      ..writeByte(19)
      ..write(obj.schoolId)
      ..writeByte(20)
      ..write(obj.enrolledStudents)
      ..writeByte(21)
      ..write(obj.averageScore)
      ..writeByte(22)
      ..write(obj.isPublished)
      ..writeByte(23)
      ..write(obj.updatedAt);
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

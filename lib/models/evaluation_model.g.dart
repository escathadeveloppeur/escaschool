// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'evaluation_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EvaluationModelAdapter extends TypeAdapter<EvaluationModel> {
  @override
  final int typeId = 11;

  @override
  EvaluationModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EvaluationModel(
      studentKey: fields[0] as int,
      classKey: fields[1] as int,
      subject: fields[2] as String,
      evaluationName: fields[3] as String,
      score: fields[4] as double,
      maxScore: fields[5] as double,
      date: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, EvaluationModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.studentKey)
      ..writeByte(1)
      ..write(obj.classKey)
      ..writeByte(2)
      ..write(obj.subject)
      ..writeByte(3)
      ..write(obj.evaluationName)
      ..writeByte(4)
      ..write(obj.score)
      ..writeByte(5)
      ..write(obj.maxScore)
      ..writeByte(6)
      ..write(obj.date);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EvaluationModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

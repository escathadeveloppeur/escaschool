// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timetable_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TimetableModelAdapter extends TypeAdapter<TimetableModel> {
  @override
  final int typeId = 12;

  @override
  TimetableModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimetableModel(
      classKey: fields[0] as int,
      day: fields[1] as String,
      startTime: fields[2] as String,
      endTime: fields[3] as String,
      subject: fields[4] as String,
      teacher: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TimetableModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.classKey)
      ..writeByte(1)
      ..write(obj.day)
      ..writeByte(2)
      ..write(obj.startTime)
      ..writeByte(3)
      ..write(obj.endTime)
      ..writeByte(4)
      ..write(obj.subject)
      ..writeByte(5)
      ..write(obj.teacher);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimetableModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

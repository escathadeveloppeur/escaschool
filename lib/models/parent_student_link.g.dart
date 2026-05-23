// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'parent_student_link.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ParentStudentLinkAdapter extends TypeAdapter<ParentStudentLink> {
  @override
  final int typeId = 33;

  @override
  ParentStudentLink read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ParentStudentLink(
      parentUserId: fields[0] as int,
      studentKeyHive: fields[1] as int,
      relation: fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ParentStudentLink obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.parentUserId)
      ..writeByte(1)
      ..write(obj.studentKeyHive)
      ..writeByte(2)
      ..write(obj.relation);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParentStudentLinkAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StaffModelAdapter extends TypeAdapter<StaffModel> {
  @override
  final int typeId = 90;

  @override
  StaffModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StaffModel(
      id: fields[0] as int?,
      fullName: fields[1] as String,
      position: fields[2] as String,
      phone: fields[3] as String?,
      email: fields[4] as String?,
      address: fields[5] as String?,
      hireDate: fields[6] as DateTime,
      salary: fields[7] as double,
      photoUrl: fields[8] as String?,
      isActive: fields[9] as bool,
      schoolId: fields[10] as String?,
      firestoreId: fields[11] as String?,
      createdAt: fields[12] as DateTime?,
      updatedAt: fields[13] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, StaffModel obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fullName)
      ..writeByte(2)
      ..write(obj.position)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.email)
      ..writeByte(5)
      ..write(obj.address)
      ..writeByte(6)
      ..write(obj.hireDate)
      ..writeByte(7)
      ..write(obj.salary)
      ..writeByte(8)
      ..write(obj.photoUrl)
      ..writeByte(9)
      ..write(obj.isActive)
      ..writeByte(10)
      ..write(obj.schoolId)
      ..writeByte(11)
      ..write(obj.firestoreId)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

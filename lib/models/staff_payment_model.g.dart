// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_payment_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StaffPaymentModelAdapter extends TypeAdapter<StaffPaymentModel> {
  @override
  final int typeId = 80;

  @override
  StaffPaymentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StaffPaymentModel(
      id: fields[0] as int?,
      staffId: fields[1] as int,
      staffName: fields[2] as String,
      month: fields[3] as String,
      year: fields[4] as int,
      baseSalary: fields[5] as double,
      bonus: fields[6] as double,
      deduction: fields[7] as double,
      netSalary: fields[8] as double,
      paymentDate: fields[9] as String,
      paymentMethod: fields[10] as String,
      reference: fields[11] as String?,
      notes: fields[12] as String?,
      schoolId: fields[13] as int,
      createdAt: fields[14] as DateTime?,
      firestoreId: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, StaffPaymentModel obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.staffId)
      ..writeByte(2)
      ..write(obj.staffName)
      ..writeByte(3)
      ..write(obj.month)
      ..writeByte(4)
      ..write(obj.year)
      ..writeByte(5)
      ..write(obj.baseSalary)
      ..writeByte(6)
      ..write(obj.bonus)
      ..writeByte(7)
      ..write(obj.deduction)
      ..writeByte(8)
      ..write(obj.netSalary)
      ..writeByte(9)
      ..write(obj.paymentDate)
      ..writeByte(10)
      ..write(obj.paymentMethod)
      ..writeByte(11)
      ..write(obj.reference)
      ..writeByte(12)
      ..write(obj.notes)
      ..writeByte(13)
      ..write(obj.schoolId)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.firestoreId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffPaymentModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

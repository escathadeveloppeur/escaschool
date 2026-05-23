// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PaymentModelAdapter extends TypeAdapter<PaymentModel> {
  @override
  final int typeId = 3;

  @override
  PaymentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaymentModel(
      studentKeyHive: fields[0] as int,
      month: fields[1] as int,
      feeType: fields[2] as String,
      amount: fields[3] as double,
      paymentDate: fields[4] as String,
      fullName: fields[5] as String,
      className: fields[6] as String,
      year: fields[7] as int,
      schoolId: fields[8] as int,
      firestoreId: fields[9] as String?,
      status: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PaymentModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.studentKeyHive)
      ..writeByte(1)
      ..write(obj.month)
      ..writeByte(2)
      ..write(obj.feeType)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.paymentDate)
      ..writeByte(5)
      ..write(obj.fullName)
      ..writeByte(6)
      ..write(obj.className)
      ..writeByte(7)
      ..write(obj.year)
      ..writeByte(8)
      ..write(obj.schoolId)
      ..writeByte(9)
      ..write(obj.firestoreId)
      ..writeByte(10)
      ..write(obj.status);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

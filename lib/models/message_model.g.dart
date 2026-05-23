// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MessageModelAdapter extends TypeAdapter<MessageModel> {
  @override
  final int typeId = 10;

  @override
  MessageModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MessageModel(
      senderName: fields[0] as String,
      senderRole: fields[1] as String,
      recipientName: fields[2] as String,
      recipientRole: fields[3] as String,
      studentName: fields[4] as String,
      subject: fields[5] as String,
      content: fields[6] as String,
      date: fields[7] as DateTime,
      read: fields[8] as bool,
      important: fields[9] as bool,
      firestoreId: fields[10] as String?,
      replyTo: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MessageModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.senderName)
      ..writeByte(1)
      ..write(obj.senderRole)
      ..writeByte(2)
      ..write(obj.recipientName)
      ..writeByte(3)
      ..write(obj.recipientRole)
      ..writeByte(4)
      ..write(obj.studentName)
      ..writeByte(5)
      ..write(obj.subject)
      ..writeByte(6)
      ..write(obj.content)
      ..writeByte(7)
      ..write(obj.date)
      ..writeByte(8)
      ..write(obj.read)
      ..writeByte(9)
      ..write(obj.important)
      ..writeByte(10)
      ..write(obj.firestoreId)
      ..writeByte(11)
      ..write(obj.replyTo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

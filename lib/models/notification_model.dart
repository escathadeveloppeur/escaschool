import 'package:hive/hive.dart';

part 'notification_model.g.dart';

@HiveType(typeId: 11)
class NotificationModel extends HiveObject {  // ← Étendre HiveObject
  @HiveField(0)
  final String type;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final String studentName;

  @HiveField(4)
  final DateTime date;

  @HiveField(5)
  bool read;

  @HiveField(6)
  bool responded;

  @HiveField(7)
  final bool requiresResponse;
  @HiveField(8)
  int key;

  NotificationModel({
    required this.type,
    required this.title,
    required this.content,
    required this.studentName,
    required this.date,
    this.read = false,
    this.responded = false,
    this.requiresResponse = false,
    required this.key,
  });
}
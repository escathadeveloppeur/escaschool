import 'package:hive/hive.dart';

part 'schedule_model.g.dart';

@HiveType(typeId: 8)
class ScheduleModel {
  @HiveField(0)
  final int id;
  
  @HiveField(1)
  final int professorId;
  
  @HiveField(2)
  final int classId;
  
  @HiveField(3)
  final String dayOfWeek;
  
  @HiveField(4)
  final String startTime;
  
  @HiveField(5)
  final String endTime;
  
  @HiveField(6)
  final String subject;
  
  @HiveField(7)
  final String? room;
  
  @HiveField(8)
  final String createdAt;
  
  @HiveField(9)
  final String? updatedAt;
  
  ScheduleModel({
    required this.id,
    required this.professorId,
    required this.classId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.subject,
    this.room,
    required this.createdAt,
    this.updatedAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'professorId': professorId,
      'classId': classId,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'subject': subject,
      'room': room,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
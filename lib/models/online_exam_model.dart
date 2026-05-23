// lib/models/online_exam_model.dart

import 'package:hive/hive.dart';

part 'online_exam_model.g.dart';

@HiveType(typeId: 12)
class OnlineExamModel {
  @HiveField(0)
  final int id;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final String description;
  
  @HiveField(3)
  final String subject;
  
  @HiveField(4)
  final String className;
  
  @HiveField(5)
  final int classId;
  
  @HiveField(6)
  final int professorId;
  
  @HiveField(7)
  final DateTime startDate;
  
  @HiveField(8)
  final DateTime endDate;
  
  @HiveField(9)
  final int duration; // en minutes
  
  @HiveField(10)
  final int totalPoints;
  
  @HiveField(11)
  final List<Map<String, dynamic>> questions;
  
  @HiveField(12)
  final String status; // 'upcoming', 'ongoing', 'completed'
  
  @HiveField(13)
  final DateTime createdAt;
  
  OnlineExamModel({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.className,
    required this.classId,
    required this.professorId,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.totalPoints,
    required this.questions,
    required this.status,
    required this.createdAt,
  });
}
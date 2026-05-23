// lib/models/online_course_model.dart

import 'package:hive/hive.dart';

part 'online_course_model.g.dart';

@HiveType(typeId: 14)
class OnlineCourseModel {
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
  final List<Map<String, dynamic>> chapters;
  
  @HiveField(8)
  final List<Map<String, dynamic>> resources;
  
  @HiveField(9)
  final DateTime createdAt;
  
  @HiveField(10)
  final DateTime updatedAt;
  
  OnlineCourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.className,
    required this.classId,
    required this.professorId,
    required this.chapters,
    required this.resources,
    required this.createdAt,
    required this.updatedAt,
  });
}
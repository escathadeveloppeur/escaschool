// lib/models/exam_result_model.dart

import 'package:hive/hive.dart';

part 'exam_result_model.g.dart';

@HiveType(typeId: 13)
class ExamResultModel {
  @HiveField(0)
  final int examId;
  
  @HiveField(1)
  final int studentId;
  
  @HiveField(2)
  final String studentName;
  
  @HiveField(3)
  final int score;
  
  @HiveField(4)
  final int totalPoints;
  
  @HiveField(5)
  final List<Map<String, dynamic>> answers;
  
  @HiveField(6)
  final DateTime submittedAt;
  
  @HiveField(7)
  final bool isGraded;
  
  ExamResultModel({
    required this.examId,
    required this.studentId,
    required this.studentName,
    required this.score,
    required this.totalPoints,
    required this.answers,
    required this.submittedAt,
    this.isGraded = false,
  });
  
  double get percentage => (score / totalPoints) * 100;
}
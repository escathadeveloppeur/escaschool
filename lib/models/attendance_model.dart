import 'package:hive/hive.dart';

part 'attendance_model.g.dart';

@HiveType(typeId: 55)
class AttendanceModel extends HiveObject {
  @HiveField(0)
  int studentKeyHive;
  
  @HiveField(1)
  String studentName;
  
  @HiveField(2)
  String className;
  
  @HiveField(3)
  DateTime date;
  
  @HiveField(4)
  String status; // 'present', 'absent', 'late', 'excused'
  
  @HiveField(5)
  String? reason;
  
  @HiveField(6)
  String subject;
  @HiveField(7)
   int? studentId;  // ← AJOUTER CETTE PROPRIÉTÉ
  
  AttendanceModel({
    required this.studentKeyHive,
    required this.studentName,
    required this.className,
    required this.date,
    required this.status,
    this.reason,
    required this.subject,
    required studentId,
  });
}
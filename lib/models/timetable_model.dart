import 'package:hive/hive.dart';
part 'timetable_model.g.dart';

@HiveType(typeId: 12)
class TimetableModel extends HiveObject {
  @HiveField(0)
  int classKey; // classe liée
  @HiveField(1)
  String day; // "Lundi" ...
  @HiveField(2)
  String startTime; // "08:00"
  @HiveField(3)
  String endTime;   // "09:30"
  @HiveField(4)
  String subject;
  @HiveField(5)
  String teacher;

  TimetableModel({
    required this.classKey,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.teacher,
  });
}

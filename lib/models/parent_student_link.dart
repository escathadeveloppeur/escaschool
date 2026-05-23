// lib/models/parent_student_link.dart

import 'package:hive/hive.dart';

part 'parent_student_link.g.dart';

@HiveType(typeId: 33)
class ParentStudentLink {
  @HiveField(0)
  int parentUserId;  // ID du parent dans la table users
  
  @HiveField(1)
  int studentKeyHive; // Clé Hive de l'étudiant
  
  @HiveField(2)
  String relation; // "père", "mère", "tuteur"
  
  ParentStudentLink({
    required this.parentUserId,
    required this.studentKeyHive,
    required this.relation,
  });
}
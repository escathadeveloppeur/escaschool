import 'package:hive/hive.dart';

part 'class_model.g.dart';

@HiveType(typeId: 1)
class ClassModel {
  @HiveField(0)
  final int? key;

  @HiveField(1)
  final String className;
  
  @HiveField(2)
  final String? level;
  
  @HiveField(3)
  final String? year;
  
  @HiveField(4)
  final String? teacher;
  
  @HiveField(5)
  final List<String> students;
  
  @HiveField(6)
  final int? hiveKey; 
  
  @HiveField(7)
  final List<Map<String, dynamic>> subjects;
  
  @HiveField(8)
  final int? schoolId;  
  
  @HiveField(9)
  final String? firestoreId;

  ClassModel({
    this.key,
    required this.className,
    this.level,
    this.year,
    this.teacher,
    this.schoolId,
    this.students = const [],
    this.hiveKey,
    this.subjects = const [],
    this.firestoreId,
  });
  
  // Factory pour créer depuis Firestore
  factory ClassModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return ClassModel(
      firestoreId: docId,
      className: data['className'] ?? '',
      level: data['level'] ?? '',
      year: data['year'] ?? '',
      subjects: List<Map<String, dynamic>>.from(data['subjects'] ?? []),
      schoolId: data['schoolId'],
    );
  }
  
  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'className': className,
      'level': level,
      'year': year,
      'subjects': subjects,
      'schoolId': schoolId,
    };
  }
}
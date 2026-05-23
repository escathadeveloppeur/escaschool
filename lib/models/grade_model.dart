// lib/models/grade_model.dart

import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'grade_model.g.dart';

@HiveType(typeId: 6)
class GradeModel extends HiveObject {
  @HiveField(0)
  int studentKeyHive;
  
  @HiveField(1)
  String studentName;
  
  @HiveField(2)
  String className;
  
  @HiveField(3)
  String subject;
  
  @HiveField(4)
  String evaluationType; // 'devoir', 'examen', 'participation'
  
  @HiveField(5)
  double score;
  
  @HiveField(6)
  double maxScore;
  
  @HiveField(7)
  DateTime date;
  
  @HiveField(8)
  double coefficient;
  
  @HiveField(9)
  String? comments;
  
  @HiveField(10)
  String? firestoreId;
  
  @HiveField(11)
  String? teacher;

  GradeModel({
    required this.studentKeyHive,
    required this.studentName,
    required this.className,
    required this.subject,
    required this.evaluationType,
    required this.score,
    required this.maxScore,
    required this.date,
    required this.coefficient,
    this.comments,
    this.firestoreId,
    this.teacher,
  });
  
  double get percentage => (score / maxScore) * 100;
  
  // Constructeur depuis Firestore
  factory GradeModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return GradeModel(
      studentKeyHive: data['studentKeyHive'] ?? 0,
      studentName: data['studentName'] ?? '',
      className: data['className'] ?? '',
      subject: data['subject'] ?? '',
      evaluationType: data['evaluationType'] ?? 'devoir',
      score: (data['score'] as num?)?.toDouble() ?? 0.0,
      maxScore: (data['maxScore'] as num?)?.toDouble() ?? 20.0,
      date: data['date'] != null ? (data['date'] as Timestamp).toDate() : DateTime.now(),
      coefficient: (data['coefficient'] as num?)?.toDouble() ?? 1.0,
      comments: data['comments'],
      firestoreId: docId,
      teacher: data['teacher'],
    );
  }
  
  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'studentKeyHive': studentKeyHive,
      'studentName': studentName,
      'className': className,
      'subject': subject,
      'evaluationType': evaluationType,
      'score': score,
      'maxScore': maxScore,
      'date': FieldValue.serverTimestamp(),
      'coefficient': coefficient,
      'comments': comments,
      'teacher': teacher,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
  
  // Convertir en Map pour affichage (correction de l'erreur)
  Map<String, dynamic> toMap() {
    return {
      'id': key,
      'studentKeyHive': studentKeyHive,
      'studentName': studentName,
      'className': className,
      'subject': subject,
      'evaluationType': evaluationType,
      'score': score,
      'maxScore': maxScore,
      'date': date,
      'coefficient': coefficient,
      'comments': comments,
      'firestoreId': firestoreId,
      'teacher': teacher,
    };
  }
  
  // Constructeur depuis Map
  factory GradeModel.fromMap(Map<String, dynamic> map) {
    return GradeModel(
      studentKeyHive: map['studentKeyHive'] ?? 0,
      studentName: map['studentName'] ?? '',
      className: map['className'] ?? '',
      subject: map['subject'] ?? '',
      evaluationType: map['evaluationType'] ?? 'devoir',
      score: (map['score'] ?? 0.0).toDouble(),
      maxScore: (map['maxScore'] ?? 20.0).toDouble(),
      date: map['date'] ?? DateTime.now(),
      coefficient: (map['coefficient'] ?? 1.0).toDouble(),
      comments: map['comments'],
      firestoreId: map['firestoreId'],
      teacher: map['teacher'],
    );
  }
}
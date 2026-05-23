// lib/models/student_model.dart

import 'package:hive/hive.dart';

part 'student_model.g.dart'; // à générer avec build_runner

@HiveType(typeId: 2)
class StudentModel extends HiveObject {
  @HiveField(0)
  String fullName;

  @HiveField(1)
  String className;


  @HiveField(2)
  String birthDate;

  @HiveField(3)
  String birthPlace;

  @HiveField(4)
  String fatherName;

  @HiveField(5)
  String motherName;

  @HiveField(6)
  String parentPhone;

  @HiveField(7)
  String address;

  @HiveField(8)
  bool documentsVerified;// 0 = non vérifié, 1 = OK

  @HiveField(9)
  final int? userId; // ID du compte utilisateur (pour élève)

  @HiveField(10)
  final int? classHiveKey; // Clé Hive de la classe

  @HiveField(11)
  int? HiveKey; // Clé Hive de l'étudiant

  // Nouveaux champs pour la relation parent
  @HiveField(12)
  final int? parentUserId; // ID du parent associé

  @HiveField(13)
  final String? parentRelation; 
  @HiveField(14)
  final int? schoolId;// Relation avec le parent (père, mère, tuteur)

  StudentModel({
    required this.fullName,
    required this.className,
    required this.birthDate,
    required this.birthPlace,
    required this.fatherName,
    required this.motherName,
    required this.parentPhone,
    required this.address,
    this.documentsVerified = false,
    this.userId,
    this.classHiveKey,
    this.HiveKey,
    this.parentUserId,
    this.parentRelation,
    this.schoolId
  });

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'className': className,
      'birthDate': birthDate,
      'birthPlace': birthPlace,
      'fatherName': fatherName,
      'motherName': motherName,
      'parentPhone': parentPhone,
      'address': address,
      'documentsVerified': documentsVerified,
      'userId': userId,
      'classHiveKey': classHiveKey,
      'HiveKey': HiveKey,
      'parentUserId': parentUserId,
      'parentRelation': parentRelation,
    };
  }

  factory StudentModel.fromMap(Map<String, dynamic> map) {
    return StudentModel(
      fullName: map['fullName'] ?? '',
      className: map['className'] ?? '',
      birthDate: map['birthDate'] ?? '',
      birthPlace: map['birthPlace'] ?? '',
      fatherName: map['fatherName'] ?? '',
      motherName: map['motherName'] ?? '',
      parentPhone: map['parentPhone'] ?? '',
      address: map['address'] ?? '',
documentsVerified: map['documentsVerified'] ?? false,
      userId: map['userId'],
      classHiveKey: map['classHiveKey'],
      HiveKey: map['HiveKey'],
      parentUserId: map['parentUserId'],
      parentRelation: map['parentRelation'],
    );
  }
}
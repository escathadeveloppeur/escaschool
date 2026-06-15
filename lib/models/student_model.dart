// lib/models/student_model.dart

import 'package:flutter/material.dart';
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
  bool documentsVerified; // false = non vérifié, true = OK

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
  final String? parentRelation; // Relation avec le parent (père, mère, tuteur)
  
  @HiveField(14)
  final String? schoolId; // ID de l'école

  // ===============================================================
  // NOUVEAUX CHAMPS POUR LE CYCLE ET LA SECTION
  // ===============================================================
  
  @HiveField(15)
  final String? classCycleType; // 'primaire' ou 'secondaire'
  
  @HiveField(16)
  final String? sectionId; // ID de la section (pour le secondaire)
  
  @HiveField(17)
  final String? sectionName; // Nom de la section (pour le secondaire)
  
  @HiveField(18)
  final String? classFirestoreId; // ID Firestore de la classe
  
  @HiveField(19)
  final String? classLevel; // Niveau de la classe
  
  @HiveField(20)
  final String? classYear; // Année scolaire de la classe

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
    this.schoolId,
    this.classCycleType,
    this.sectionId,
    this.sectionName,
    this.classFirestoreId,
    this.classLevel,
    this.classYear,
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
      'schoolId': schoolId,
      'classCycleType': classCycleType,
      'sectionId': sectionId,
      'sectionName': sectionName,
      'classFirestoreId': classFirestoreId,
      'classLevel': classLevel,
      'classYear': classYear,
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
      schoolId: map['schoolId'],
      classCycleType: map['classCycleType'],
      sectionId: map['sectionId'],
      sectionName: map['sectionName'],
      classFirestoreId: map['classFirestoreId'],
      classLevel: map['classLevel'],
      classYear: map['classYear'],
    );
  }

  // ===============================================================
  // MÉTHODES UTILITAIRES
  // ===============================================================
  
  /// Vérifie si l'étudiant est au primaire
  bool get isPrimary => classCycleType == 'primaire';
  
  /// Vérifie si l'étudiant est au secondaire
  bool get isSecondary => classCycleType == 'secondaire';
  
  /// Vérifie si l'étudiant a une section
  bool get hasSection => sectionId != null && sectionId!.isNotEmpty;
  
  /// Retourne le libellé du cycle
  String get cycleLabel => isPrimary ? 'Primaire' : 'Secondaire';
  
  /// Retourne le nom complet avec section pour l'affichage
  String get displayName {
    if (isSecondary && sectionName != null && sectionName!.isNotEmpty) {
      return '$fullName ($sectionName)';
    }
    return fullName;
  }
}

// ===============================================================
// EXTENSION POUR FACILITER LA MANIPULATION DES ÉTUDIANTS
// ===============================================================

extension StudentModelExtension on List<StudentModel> {
  /// Filtre les étudiants par cycle
  List<StudentModel> filterByCycle(String cycleType) {
    if (cycleType == 'all') return this;
    return where((s) => s.classCycleType == cycleType).toList();
  }
  
  /// Filtre les étudiants par section
  List<StudentModel> filterBySection(String? sectionId) {
    if (sectionId == null) return this;
    return where((s) => s.sectionId == sectionId).toList();
  }
  
  /// Filtre les étudiants par classe
  List<StudentModel> filterByClass(String className) {
    return where((s) => s.className == className).toList();
  }
  
  /// Trie les étudiants par nom
  List<StudentModel> sortedByName() {
    final list = List<StudentModel>.from(this);
    list.sort((a, b) => a.fullName.compareTo(b.fullName));
    return list;
  }
  
  /// Récupère les étudiants du primaire
  List<StudentModel> get primaryStudents => where((s) => s.isPrimary).toList();
  
  /// Récupère les étudiants du secondaire
  List<StudentModel> get secondaryStudents => where((s) => s.isSecondary).toList();
  
  /// Récupère les étudiants par section (secondaire)
  Map<String, List<StudentModel>> groupBySection() {
    final Map<String, List<StudentModel>> result = {};
    for (var student in where((s) => s.isSecondary)) {
      final sectionKey = student.sectionId ?? 'sans_section';
      if (!result.containsKey(sectionKey)) {
        result[sectionKey] = [];
      }
      result[sectionKey]!.add(student);
    }
    return result;
  }
  
  /// Récupère les statistiques des étudiants
  Map<String, dynamic> getStatistics() {
    final total = length;
    final primary = primaryStudents.length;
    final secondary = secondaryStudents.length;
    final boys = where((s) => s.fullName.isNotEmpty).length; // À adapter selon votre champ sexe
    final girls = total - boys;
    
    return {
      'total': total,
      'primary': primary,
      'secondary': secondary,
      'boys': boys,
      'girls': girls,
      'primaryPercentage': total > 0 ? (primary / total) * 100 : 0,
      'secondaryPercentage': total > 0 ? (secondary / total) * 100 : 0,
    };
  }
}
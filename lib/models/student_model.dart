// lib/models/student_model.dart

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  // CHAMPS POUR LE CYCLE ET LA SECTION
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

  // ===============================================================
  // NOUVEAUX CHAMPS POUR LA STRUCTURE HIÉRARCHIQUE
  // ===============================================================
  
  @HiveField(21)
  String? studentFirestoreId; // ID Firestore de l'étudiant
  
  @HiveField(22)
  String? schoolFirestoreId; // ID Firestore de l'école
  
  @HiveField(23)
  String? localKey; 
  @HiveField(24)
  String? gender; // 'Masculin' ou 'Féminin'// Clé locale pour la synchronisation

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
    this.studentFirestoreId,
    this.schoolFirestoreId,
    this.localKey,
    this.gender
  });

  // ===============================================================
  // PROPRIÉTÉS CALCULÉES
  // ===============================================================
  
  /// Vérifie si l'étudiant est au primaire
  bool get isPrimary => classCycleType == 'primaire';
  
  /// Vérifie si l'étudiant est au secondaire
  bool get isSecondary => classCycleType == 'secondaire';
  
  /// Vérifie si l'étudiant a une section
  bool get hasSection => sectionId != null && sectionId!.isNotEmpty;
  
  /// Vérifie si l'étudiant a un ID Firestore
  bool get hasFirestoreId => studentFirestoreId != null && studentFirestoreId!.isNotEmpty;
  
  /// Retourne le libellé du cycle
  String get cycleLabel => isPrimary ? 'Primaire' : 'Secondaire';
  
  /// Retourne le nom complet avec section pour l'affichage
  String get displayName {
    if (isSecondary && sectionName != null && sectionName!.isNotEmpty) {
      return '$fullName ($sectionName)';
    }
    return fullName;
  }
  
  /// Retourne la clé pour la synchronisation
  String get key => localKey ?? HiveKey?.toString() ?? '${fullName}_${birthDate}';

  // ===============================================================
  // CONVERSION POUR FIRESTORE
  // ===============================================================
  
  /// Convertir en Map pour Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'fullName': fullName,
      'className': className,
      'classFirestoreId': classFirestoreId,
      'classCycleType': classCycleType,
      'classLevel': classLevel,
      'classYear': classYear,
      'sectionId': sectionId,
      'sectionName': sectionName,
      'birthDate': birthDate,
      'birthPlace': birthPlace,
      'fatherName': fatherName,
      'motherName': motherName,
      'parentPhone': parentPhone,
      'address': address,
      'documentsVerified': documentsVerified,
      'userId': userId,
      'parentUserId': parentUserId,
      'parentRelation': parentRelation,
      'schoolId': schoolId,
      'schoolFirestoreId': schoolFirestoreId,
      'localKey': key,
      'HiveKey': HiveKey,
      'classHiveKey': classHiveKey,
      'gender': gender,
    };
  }

  // ===============================================================
  // CONSTRUCTEUR DEPUIS FIRESTORE
  // ===============================================================
  
  /// Créer une instance depuis Firestore
  factory StudentModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return StudentModel(
      fullName: data['fullName'] ?? '',
      className: data['className'] ?? '',
      classFirestoreId: data['classFirestoreId'],
      classCycleType: data['classCycleType'],
      classLevel: data['classLevel'],
      classYear: data['classYear'],
      sectionId: data['sectionId'],
      sectionName: data['sectionName'],
      birthDate: data['birthDate'] ?? '',
      birthPlace: data['birthPlace'] ?? '',
      fatherName: data['fatherName'] ?? '',
      motherName: data['motherName'] ?? '',
      parentPhone: data['parentPhone'] ?? '',
      address: data['address'] ?? '',
      documentsVerified: data['documentsVerified'] ?? false,
      userId: data['userId'],
      parentUserId: data['parentUserId'],
      parentRelation: data['parentRelation'],
      schoolId: data['schoolId']?.toString(),
      schoolFirestoreId: data['schoolFirestoreId'],
      studentFirestoreId: docId,
      localKey: data['localKey'] ?? data['HiveKey']?.toString(),
      HiveKey: data['HiveKey'],
      classHiveKey: data['classHiveKey'],
    );
  }

  // ===============================================================
  // CONVERSION POUR HIVE (LOCAL)
  // ===============================================================
  
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
      'studentFirestoreId': studentFirestoreId,
      'schoolFirestoreId': schoolFirestoreId,
      'localKey': localKey,
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
      studentFirestoreId: map['studentFirestoreId'],
      schoolFirestoreId: map['schoolFirestoreId'],
      localKey: map['localKey'],
    );
  }

  // ===============================================================
  // MÉTHODES UTILITAIRES
  // ===============================================================
  
  /// Retourne une copie avec des champs modifiés
  StudentModel copyWith({
    String? fullName,
    String? className,
    String? birthDate,
    String? birthPlace,
    String? fatherName,
    String? motherName,
    String? parentPhone,
    String? address,
    bool? documentsVerified,
    int? userId,
    int? classHiveKey,
    int? HiveKey,
    int? parentUserId,
    String? parentRelation,
    String? schoolId,
    String? classCycleType,
    String? sectionId,
    String? sectionName,
    String? classFirestoreId,
    String? classLevel,
    String? classYear,
    String? studentFirestoreId,
    String? schoolFirestoreId,
    String? localKey,
  }) {
    return StudentModel(
      fullName: fullName ?? this.fullName,
      className: className ?? this.className,
      birthDate: birthDate ?? this.birthDate,
      birthPlace: birthPlace ?? this.birthPlace,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      parentPhone: parentPhone ?? this.parentPhone,
      address: address ?? this.address,
      documentsVerified: documentsVerified ?? this.documentsVerified,
      userId: userId ?? this.userId,
      classHiveKey: classHiveKey ?? this.classHiveKey,
      HiveKey: HiveKey ?? this.HiveKey,
      parentUserId: parentUserId ?? this.parentUserId,
      parentRelation: parentRelation ?? this.parentRelation,
      schoolId: schoolId ?? this.schoolId,
      classCycleType: classCycleType ?? this.classCycleType,
      sectionId: sectionId ?? this.sectionId,
      sectionName: sectionName ?? this.sectionName,
      classFirestoreId: classFirestoreId ?? this.classFirestoreId,
      classLevel: classLevel ?? this.classLevel,
      classYear: classYear ?? this.classYear,
      studentFirestoreId: studentFirestoreId ?? this.studentFirestoreId,
      schoolFirestoreId: schoolFirestoreId ?? this.schoolFirestoreId,
      localKey: localKey ?? this.localKey,
    );
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
    if (sectionId == null || sectionId.isEmpty) return this;
    return where((s) => s.sectionId == sectionId).toList();
  }
  
  /// Filtre les étudiants par classe
  List<StudentModel> filterByClass(String className) {
    return where((s) => s.className == className).toList();
  }
  
  /// Filtre les étudiants par classe Firestore ID
  List<StudentModel> filterByClassFirestore(String classFirestoreId) {
    return where((s) => s.classFirestoreId == classFirestoreId).toList();
  }
  
  /// Filtre les étudiants par école
  List<StudentModel> filterBySchool(String schoolFirestoreId) {
    return where((s) => s.schoolFirestoreId == schoolFirestoreId).toList();
  }
  
  /// Filtre les étudiants par nom
  List<StudentModel> filterByName(String query) {
    if (query.isEmpty) return this;
    return where((s) => 
      s.fullName.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }
  
  /// Filtre les étudiants par parent
  List<StudentModel> filterByParent(int? parentUserId) {
    if (parentUserId == null) return this;
    return where((s) => s.parentUserId == parentUserId).toList();
  }
  
  /// Filtre les étudiants vérifiés
  List<StudentModel> getVerified() {
    return where((s) => s.documentsVerified).toList();
  }
  
  /// Filtre les étudiants non vérifiés
  List<StudentModel> getUnverified() {
    return where((s) => !s.documentsVerified).toList();
  }
  
  /// Trie les étudiants par nom
  List<StudentModel> sortedByName() {
    final list = List<StudentModel>.from(this);
    list.sort((a, b) => a.fullName.compareTo(b.fullName));
    return list;
  }
  
  /// Trie les étudiants par classe
  List<StudentModel> sortedByClass() {
    final list = List<StudentModel>.from(this);
    list.sort((a, b) => a.className.compareTo(b.className));
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
  
  /// Groupe les étudiants par classe
  Map<String, List<StudentModel>> groupByClass() {
    final Map<String, List<StudentModel>> result = {};
    for (var student in this) {
      final key = student.classFirestoreId ?? student.className;
      if (!result.containsKey(key)) {
        result[key] = [];
      }
      result[key]!.add(student);
    }
    return result;
  }
  
  /// Groupe les étudiants par cycle
  Map<String, List<StudentModel>> groupByCycle() {
    return {
      'primaire': where((s) => s.isPrimary).toList(),
      'secondaire': where((s) => s.isSecondary).toList(),
    };
  }
  
  /// Récupère les étudiants non synchronisés
  List<StudentModel> getUnsynced() {
    return where((s) => !s.hasFirestoreId).toList();
  }
  
  /// Récupère les statistiques des étudiants
  Map<String, dynamic> getStatistics() {
    final total = length;
    final primary = primaryStudents.length;
    final secondary = secondaryStudents.length;
    final verified = getVerified().length;
    final unverified = getUnverified().length;
    
    return {
      'total': total,
      'primary': primary,
      'secondary': secondary,
      'verified': verified,
      'unverified': unverified,
      'primaryPercentage': total > 0 ? (primary / total) * 100 : 0,
      'secondaryPercentage': total > 0 ? (secondary / total) * 100 : 0,
      'verifiedPercentage': total > 0 ? (verified / total) * 100 : 0,
    };
  }
}
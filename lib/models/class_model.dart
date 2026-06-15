import 'package:cloud_firestore/cloud_firestore.dart';
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
  final String? schoolId;  
  
  @HiveField(9)
  final String? firestoreId;

  // ===============================================================
  // NOUVEAUX CHAMPS POUR LA SECTION (UNE SEULE SECTION PAR CLASSE)
  // ===============================================================
  
  @HiveField(10)
  final String? sectionId; // ID de la section associée à cette classe
  
  @HiveField(11)
  final String? section; // Nom de la section associée (ex: 'A', 'B', 'C')
  
  // ===============================================================
  // NOUVEAU CHAMP POUR LE CYCLE (PRIMAIRE / SECONDAIRE)
  // ===============================================================
  
  @HiveField(12)
  final String cycleType; // 'primaire' ou 'secondaire'

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
    this.sectionId,      // NOUVEAU
    this.section,        // NOUVEAU
    this.cycleType = 'primaire', // Par défaut 'primaire'
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
      sectionId: data['sectionId'],          // NOUVEAU
      section: data['section'],              // NOUVEAU
      cycleType: data['cycleType'] ?? 'primaire',
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
      'sectionId': sectionId,    // NOUVEAU
      'section': section,        // NOUVEAU
      'cycleType': cycleType,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
  
  // ===============================================================
  // MÉTHODES UTILITAIRES
  // ===============================================================
  
  /// Vérifie si la classe est du primaire
  bool get isPrimary => cycleType == 'primaire';
  
  /// Vérifie si la classe est du secondaire
  bool get isSecondary => cycleType == 'secondaire';
  
  /// Vérifie si la classe a une section associée (uniquement pour secondaire)
  bool get hasSection => isSecondary && sectionId != null && section != null;
  
  /// Récupère toutes les matières (communes uniquement)
  List<Map<String, dynamic>> getAllSubjects() {
    return List<Map<String, dynamic>>.from(subjects);
  }
  
  /// Récupère la catégorie d'une matière
  String getSubjectCategory(Map<String, dynamic> subject) {
    return subject['category'] ?? 'premiere';
  }
  
  /// Récupère les maxValues d'une matière
  Map<String, dynamic> getSubjectMaxValues(Map<String, dynamic> subject) {
    return subject['maxValues'] ?? {
      'p1': 10, 'p2': 10, 'ex1': 20, 'tot1': 40,
      'p3': 10, 'p4': 10, 'ex2': 20, 'tot2': 40,
      'total': 80,
    };
  }
  
  /// Retourne le nom complet de la classe avec section (ex: "3ème A")
  String get fullName {
    if (isSecondary && section != null && section!.isNotEmpty) {
      return '$className - $section';
    }
    return className;
  }
  
  /// Retourne la configuration JSON complète pour le bulletin
  Map<String, dynamic> toBulletinConfig() {
    return {
      'className': className,
      'level': level,
      'year': year,
      'cycleType': cycleType,
      'section': section,
      'sectionId': sectionId,
      'subjects': subjects,
      'totalSubjects': subjects.length,
    };
  }
}

// ===============================================================
// MODÈLE POUR LES SECTIONS (OPTIONS)
// ===============================================================

@HiveType(typeId: 2)
class SectionModel {
  @HiveField(0)
  final String? id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String description;
  
  @HiveField(3)
  final List<Map<String, dynamic>> subjects;
  
  @HiveField(4)
  final String schoolId;
  
  @HiveField(5)
  final DateTime createdAt;
  
  @HiveField(6)
  final String? firestoreId;

  SectionModel({
    this.id,
    required this.name,
    required this.description,
    required this.subjects,
    required this.schoolId,
    required this.createdAt,
    this.firestoreId,
  });
  
  // Factory pour créer depuis Firestore
  factory SectionModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return SectionModel(
      id: docId,
      firestoreId: docId,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      subjects: List<Map<String, dynamic>>.from(data['subjects'] ?? []),
      schoolId: data['schoolId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
  
  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'subjects': subjects,
      'schoolId': schoolId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
  
  // Copie avec modifications
  SectionModel copyWith({
    String? id,
    String? name,
    String? description,
    List<Map<String, dynamic>>? subjects,
    String? schoolId,
    DateTime? createdAt,
    String? firestoreId,
  }) {
    return SectionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      subjects: subjects ?? this.subjects,
      schoolId: schoolId ?? this.schoolId,
      createdAt: createdAt ?? this.createdAt,
      firestoreId: firestoreId ?? this.firestoreId,
    );
  }
  
  /// Récupère le nombre total de matières dans la section
  int get totalSubjects => subjects.length;
  
  /// Récupère le coefficient total de la section
  double get totalCoefficient {
    double total = 0;
    for (var subject in subjects) {
      total += (subject['coefficient'] as num?)?.toDouble() ?? 1.0;
    }
    return total;
  }
  
  /// Récupère la liste des professeurs de la section
  List<String> getProfessorNames() {
    return subjects.map((s) => s['professorName'] as String? ?? '').where((n) => n.isNotEmpty).toList();
  }
}

// ===============================================================
// EXTENSION POUR FACILITER LA MANIPULATION DES CLASSES
// ===============================================================

extension ClassModelExtension on ClassModel {
  /// Récupère les matières communes (non optionnelles)
  List<Map<String, dynamic>> getCommonSubjects() {
    return subjects;
  }
  
  /// Vérifie si la classe a des matières optionnelles
  bool get hasOptions => false; // Plus d'options, les classes ont une seule section
  
  /// Retourne l'affichage complet de la classe
  String get displayName {
    if (isSecondary && section != null && section!.isNotEmpty) {
      return '$className (Section $section)';
    }
    return className;
  }
}
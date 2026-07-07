// lib/models/document_model.dart

import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // ✅ AJOUTÉ pour Colors

part 'document_model.g.dart';
 // Généré par build_runner

@HiveType(typeId: 4) // Chaque modèle Hive doit avoir un typeId unique
class DocumentModel extends HiveObject {
  @HiveField(0)
  String fullName;

  @HiveField(1)
  String className;

  @HiveField(2)
  String docType;

  @HiveField(3)
  bool isValidated;
  
  @HiveField(4)
  int keyHive;
  
  // ===============================================================
  // ANCIENS CHAMPS (à conserver pour compatibilité)
  // ===============================================================
  
  @HiveField(5)
  int schoolId; // ID local (Hive) - à conserver

  @HiveField(6)
  String? firestoreId; // ID Firestore du document

  @HiveField(7)
  String? fileUrl;

  @HiveField(8)
  DateTime? createdAt;

  // ===============================================================
  // NOUVEAUX CHAMPS POUR LA STRUCTURE HIÉRARCHIQUE
  // ===============================================================
  
  @HiveField(9)
  String? schoolFirestoreId; // ID Firestore de l'école (pour les sous-collections)
  
  @HiveField(10)
  String? classId; // ID Firestore de la classe
  
  @HiveField(11)
  String? studentId; // ID Firestore de l'étudiant
  
  @HiveField(12)
  String? documentFirestoreId; // ID Firestore du document (alias)
  
  @HiveField(13)
  String? validatedBy; // ID de l'utilisateur qui a validé
  
  @HiveField(14)
  DateTime? validatedAt; // Date de validation
  
  @HiveField(15)
  String? localKey; // Clé locale pour la synchronisation

  DocumentModel({
    required this.fullName,
    required this.className,
    required this.docType,
    required this.keyHive,
    this.isValidated = false,
    required this.schoolId,
    this.firestoreId,
    this.fileUrl,
    this.createdAt,
    this.schoolFirestoreId,
    this.classId,
    this.studentId,
    this.documentFirestoreId,
    this.validatedBy,
    this.validatedAt,
    this.localKey,
  });

  // ===============================================================
  // CONSTRUCTEUR DEPUIS FIRESTORE
  // ===============================================================

  /// Créer une instance depuis Firestore
  factory DocumentModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return DocumentModel(
      fullName: data['fullName'] ?? '',
      className: data['className'] ?? '',
      docType: data['docType'] ?? '',
      keyHive: data['keyHive'] ?? 0,
      isValidated: data['isValidated'] ?? false,
      schoolId: data['schoolId'] ?? 0,
      firestoreId: docId,
      fileUrl: data['fileUrl'] ?? '',
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      // Nouveaux champs
      schoolFirestoreId: data['schoolFirestoreId'],
      classId: data['classId'],
      studentId: data['studentId'],
      documentFirestoreId: docId,
      validatedBy: data['validatedBy'],
      validatedAt: data['validatedAt'] != null 
          ? (data['validatedAt'] as Timestamp).toDate() 
          : null,
      localKey: data['localKey'] ?? data['keyHive']?.toString(),
    );
  }

  // ===============================================================
  // CONVERSION POUR FIRESTORE
  // ===============================================================

  /// Convertir en Map pour Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'fullName': fullName,
      'className': className,
      'classId': classId,
      'docType': docType,
      'keyHive': keyHive,
      'isValidated': isValidated,
      'schoolId': schoolId,
      'schoolFirestoreId': schoolFirestoreId,
      'fileUrl': fileUrl,
      'studentId': studentId,
      'validatedBy': validatedBy,
      'validatedAt': validatedAt != null 
          ? Timestamp.fromDate(validatedAt!) 
          : null,
      'localKey': localKey ?? keyHive.toString(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ===============================================================
  // CONVERSION POUR HIVE (LOCAL)
  // ===============================================================

  /// Convertir en Map pour Hive
  Map<String, dynamic> toMap() {
    return {
      'id': key,
      'fullName': fullName,
      'className': className,
      'docType': docType,
      'isValidated': isValidated,
      'keyHive': keyHive,
      'schoolId': schoolId,
      'firestoreId': firestoreId,
      'fileUrl': fileUrl,
      'createdAt': createdAt,
      'schoolFirestoreId': schoolFirestoreId,
      'classId': classId,
      'studentId': studentId,
      'documentFirestoreId': documentFirestoreId,
      'validatedBy': validatedBy,
      'validatedAt': validatedAt,
      'localKey': localKey,
    };
  }

  /// Créer une instance depuis Hive
  factory DocumentModel.fromMap(Map<String, dynamic> map) {
    return DocumentModel(
      fullName: map['fullName'] ?? '',
      className: map['className'] ?? '',
      docType: map['docType'] ?? '',
      keyHive: map['keyHive'] ?? 0,
      isValidated: map['isValidated'] ?? false,
      schoolId: map['schoolId'] ?? 0,
      firestoreId: map['firestoreId'],
      fileUrl: map['fileUrl'],
      createdAt: map['createdAt'],
      schoolFirestoreId: map['schoolFirestoreId'],
      classId: map['classId'],
      studentId: map['studentId'],
      documentFirestoreId: map['documentFirestoreId'],
      validatedBy: map['validatedBy'],
      validatedAt: map['validatedAt'],
      localKey: map['localKey'],
    );
  }

  // ===============================================================
  // MÉTHODES UTILITAIRES
  // ===============================================================

  /// Vérifie si le document est validé
  bool get isValid => isValidated;
  
  /// Vérifie si le document a un ID Firestore
  bool get hasFirestoreId => documentFirestoreId != null && documentFirestoreId!.isNotEmpty;
  
  /// Vérifie si le document a une URL de fichier
  bool get hasFileUrl => fileUrl != null && fileUrl!.isNotEmpty;
  
  /// Retourne le libellé du type de document
  String get docTypeLabel {
    switch (docType) {
      case 'bulletin': return '📄 Bulletin';
      case 'attestation': return '📜 Attestation';
      case 'certificat': return '📋 Certificat';
      case 'photo': return '🖼️ Photo';
      case 'autre': return '📎 Autre';
      default: return docType;
    }
  }

  /// Retourne la couleur du statut de validation
  Color get validationColor {
    return isValidated ? Colors.green : Colors.orange;
  }

  /// Retourne le libellé du statut de validation
  String get validationLabel {
    return isValidated ? '✅ Validé' : '⏳ En attente';
  }

  /// Retourne une copie du document avec validation
  DocumentModel copyWith({
    String? fullName,
    String? className,
    String? docType,
    bool? isValidated,
    int? keyHive,
    int? schoolId,
    String? firestoreId,
    String? fileUrl,
    DateTime? createdAt,
    String? schoolFirestoreId,
    String? classId,
    String? studentId,
    String? documentFirestoreId,
    String? validatedBy,
    DateTime? validatedAt,
    String? localKey,
  }) {
    return DocumentModel(
      fullName: fullName ?? this.fullName,
      className: className ?? this.className,
      docType: docType ?? this.docType,
      keyHive: keyHive ?? this.keyHive,
      isValidated: isValidated ?? this.isValidated,
      schoolId: schoolId ?? this.schoolId,
      firestoreId: firestoreId ?? this.firestoreId,
      fileUrl: fileUrl ?? this.fileUrl,
      createdAt: createdAt ?? this.createdAt,
      schoolFirestoreId: schoolFirestoreId ?? this.schoolFirestoreId,
      classId: classId ?? this.classId,
      studentId: studentId ?? this.studentId,
      documentFirestoreId: documentFirestoreId ?? this.documentFirestoreId,
      validatedBy: validatedBy ?? this.validatedBy,
      validatedAt: validatedAt ?? this.validatedAt,
      localKey: localKey ?? this.localKey,
    );
  }
}

// ===============================================================
// EXTENSION POUR FACILITER LA MANIPULATION DES DOCUMENTS
// ===============================================================

extension DocumentModelExtension on List<DocumentModel> {
  /// Filtre les documents par classe
  List<DocumentModel> filterByClass(String classId) {
    return where((doc) => doc.classId == classId).toList();
  }

  /// Filtre les documents par étudiant
  List<DocumentModel> filterByStudent(String studentId) {
    return where((doc) => doc.studentId == studentId).toList();
  }

  /// Filtre les documents par type
  List<DocumentModel> filterByType(String docType) {
    return where((doc) => doc.docType == docType).toList();
  }

  /// Filtre les documents validés
  List<DocumentModel> getValidated() {
    return where((doc) => doc.isValidated).toList();
  }

  /// Filtre les documents non validés
  List<DocumentModel> getUnvalidated() {
    return where((doc) => !doc.isValidated).toList();
  }

  /// Filtre les documents par école
  List<DocumentModel> filterBySchool(String schoolFirestoreId) {
    return where((doc) => doc.schoolFirestoreId == schoolFirestoreId).toList();
  }

  /// Filtre les documents par nom d'étudiant
  List<DocumentModel> filterByStudentName(String query) {
    if (query.isEmpty) return this;
    return where((doc) => 
      doc.fullName.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  /// Groupe les documents par type
  Map<String, List<DocumentModel>> groupByType() {
    final Map<String, List<DocumentModel>> result = {};
    for (var doc in this) {
      if (!result.containsKey(doc.docType)) {
        result[doc.docType] = [];
      }
      result[doc.docType]!.add(doc);
    }
    return result;
  }

  /// Groupe les documents par statut de validation
  Map<String, List<DocumentModel>> groupByValidation() {
    return {
      'validated': getValidated(),
      'unvalidated': getUnvalidated(),
    };
  }

  /// Groupe les documents par classe
  Map<String, List<DocumentModel>> groupByClass() {
    final Map<String, List<DocumentModel>> result = {};
    for (var doc in this) {
      final key = doc.classId ?? 'unknown';
      if (!result.containsKey(key)) {
        result[key] = [];
      }
      result[key]!.add(doc);
    }
    return result;
  }

  /// Récupère les statistiques
  Map<String, dynamic> getStatistics() {
    return {
      'total': length,
      'validated': getValidated().length,
      'unvalidated': getUnvalidated().length,
      'byType': groupByType().map((key, value) => MapEntry(key, value.length)),
      'byClass': groupByClass().map((key, value) => MapEntry(key, value.length)),
    };
  }

  /// Récupère les documents non synchronisés
  List<DocumentModel> getUnsynced() {
    return where((doc) => !doc.hasFirestoreId).toList();
  }

  /// Trie les documents par date (plus récents en premier)
  List<DocumentModel> sortedByDateDesc() {
    final list = [...this];
    list.sort((a, b) => 
      (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now())
    );
    return list;
  }

  /// Trie les documents par nom
  List<DocumentModel> sortedByName() {
    final list = [...this];
    list.sort((a, b) => a.fullName.compareTo(b.fullName));
    return list;
  }
}
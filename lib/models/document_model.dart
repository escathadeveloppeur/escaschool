// lib/models/document_model.dart

import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'document_model.g.dart'; // Généré par build_runner

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
  
  @HiveField(5)
  int schoolId;

  @HiveField(6)
  String? firestoreId;

  @HiveField(7)
  String? fileUrl;

  @HiveField(8)
  DateTime? createdAt;

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
  });

  // Constructeur depuis Firestore
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
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'fullName': fullName,
      'className': className,
      'docType': docType,
      'keyHive': keyHive,
      'isValidated': isValidated,
      'schoolId': schoolId,
      'fileUrl': fileUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Convertir en Map pour affichage
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
    };
  }

  // Constructeur depuis Map
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
    );
  }
}
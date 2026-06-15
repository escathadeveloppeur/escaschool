// lib/models/staff_model.dart

import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'staff_model.g.dart';

@HiveType(typeId: 90)
class StaffModel {
  @HiveField(0)
  int? id;
  
  @HiveField(1)
  String fullName;
  
  @HiveField(2)
  String position; // Poste: Ménage, Sentinelle, Chauffeur, Cuisinier, Jardinier, etc.
  
  @HiveField(3)
  String? phone;
  
  @HiveField(4)
  String? email;
  
  @HiveField(5)
  String? address;
  
  @HiveField(6)
  DateTime hireDate;
  
  @HiveField(7)
  double salary; // Salaire mensuel
  
  @HiveField(8)
  String? photoUrl;
  
  @HiveField(9)
  bool isActive;
  
  @HiveField(10)
  String? schoolId;
  
  @HiveField(11)
  String? firestoreId;
  
  @HiveField(12)
  DateTime? createdAt;
  
  @HiveField(13)
  DateTime? updatedAt;

  StaffModel({
    this.id,
    required this.fullName,
    required this.position,
    this.phone,
    this.email,
    this.address,
    required this.hireDate,
    required this.salary,
    this.photoUrl,
    this.isActive = true,
    this.schoolId,
    this.firestoreId,
    this.createdAt,
    this.updatedAt,
  });

  /// Méthode copyWith pour créer une copie du modèle avec des champs modifiés
  StaffModel copyWith({
    int? id,
    String? fullName,
    String? position,
    String? phone,
    String? email,
    String? address,
    DateTime? hireDate,
    double? salary,
    String? photoUrl,
    bool? isActive,
    String? schoolId,
    String? firestoreId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StaffModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      position: position ?? this.position,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      hireDate: hireDate ?? this.hireDate,
      salary: salary ?? this.salary,
      photoUrl: photoUrl ?? this.photoUrl,
      isActive: isActive ?? this.isActive,
      schoolId: schoolId ?? this.schoolId,
      firestoreId: firestoreId ?? this.firestoreId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'position': position,
      'phone': phone,
      'email': email,
      'address': address,
      'hireDate': hireDate.toIso8601String(),
      'salary': salary,
      'photoUrl': photoUrl,
      'isActive': isActive,
      'schoolId': schoolId,
      'firestoreId': firestoreId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory StaffModel.fromMap(Map<String, dynamic> map) {
    return StaffModel(
      id: map['id'],
      fullName: map['fullName'] ?? '',
      position: map['position'] ?? '',
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      hireDate: map['hireDate'] != null ? DateTime.parse(map['hireDate']) : DateTime.now(),
      salary: map['salary'] ?? 0.0,
      photoUrl: map['photoUrl'],
      isActive: map['isActive'] ?? true,
      schoolId: map['schoolId'] ?? '',
      firestoreId: map['firestoreId'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  /// Convertir pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'fullName': fullName,
      'position': position,
      'phone': phone,
      'email': email,
      'address': address,
      'hireDate': hireDate.toIso8601String(),
      'salary': salary,
      'photoUrl': photoUrl,
      'isActive': isActive,
      'schoolId': schoolId,
      'localId': id,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  /// Créer depuis Firestore
  factory StaffModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return StaffModel(
      id: data['localId'],
      fullName: data['fullName'] ?? '',
      position: data['position'] ?? '',
      phone: data['phone'],
      email: data['email'],
      address: data['address'],
      hireDate: data['hireDate'] != null ? DateTime.parse(data['hireDate']) : DateTime.now(),
      salary: (data['salary'] ?? 0.0).toDouble(),
      photoUrl: data['photoUrl'],
      isActive: data['isActive'] ?? true,
      schoolId: data['schoolId'] ?? '',
      firestoreId: docId,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }
}
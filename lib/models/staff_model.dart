// lib/models/staff_model.dart

import 'package:hive/hive.dart';

part 'staff_model.g.dart';

@HiveType(typeId: 90)
class StaffModel {
  @HiveField(0)
  int? id;
  
  @HiveField(1)
  String fullName;
  
  @HiveField(2)
  String position; // Poste: Ménage, Santinel, Chauffeur, Cuisinier, Jardinier, etc.
  
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
  int? schoolId;
  
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
      schoolId: map['schoolId'],
      firestoreId: map['firestoreId'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }
}
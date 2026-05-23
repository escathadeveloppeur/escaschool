import 'package:hive/hive.dart';

part 'professor_model.g.dart';

@HiveType(typeId: 7)
class ProfessorModel {
  @HiveField(0)
  final int id;
  
  @HiveField(1)
  final int? userId;
  
  @HiveField(2)
  final String fullName;
  
  @HiveField(3)
  final String email;
  
  @HiveField(4)
  final String? phone;
  
  @HiveField(5)
  final String? specialty;
  
  @HiveField(6)
  final String status;
  
  @HiveField(7)
  final String createdAt;
  
  @HiveField(8)
  final String? updatedAt;
  @HiveField(9)
  final int? schoolId;
  
  ProfessorModel({
    required this.id,
    this.userId,
    required this.fullName,
    required this.email,
    this.phone,
    this.specialty,
    this.status = 'active',
    required this.createdAt,
    this.updatedAt,
    this.schoolId
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'specialty': specialty,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
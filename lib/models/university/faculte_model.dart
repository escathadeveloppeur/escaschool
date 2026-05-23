// lib/models/university/faculte_model.dart

import 'package:hive/hive.dart';

part 'faculte_model.g.dart';

@HiveType(typeId: 16)
class FaculteModel {
  @HiveField(0)
  final int id;
  
  @HiveField(1)
  final int etablissementId;
  
  @HiveField(2)
  final String nom;
  
  @HiveField(3)
  final String? code;
  
  @HiveField(4)
  final String? description;
  
  @HiveField(5)
  final String? doyen;
  
  @HiveField(6)
  final DateTime createdAt;
  
  FaculteModel({
    required this.id,
    required this.etablissementId,
    required this.nom,
    this.code,
    this.description,
    this.doyen,
    required this.createdAt,
  });
}
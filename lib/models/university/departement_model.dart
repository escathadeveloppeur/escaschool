// lib/models/university/departement_model.dart

import 'package:hive/hive.dart';

part 'departement_model.g.dart';

@HiveType(typeId: 17)
class DepartementModel {
  @HiveField(0)
  final int id;
  
  @HiveField(1)
  final int faculteId;
  
  @HiveField(2)
  final String nom;
  
  @HiveField(3)
  final String? code;
  
  @HiveField(4)
  final String? responsable;
  
  @HiveField(5)
  final String? description;
  
  @HiveField(6)
  final DateTime createdAt;
  
  DepartementModel({
    required this.id,
    required this.faculteId,
    required this.nom,
    this.code,
    this.responsable,
    this.description,
    required this.createdAt,
  });
}
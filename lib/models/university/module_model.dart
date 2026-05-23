// lib/models/university/module_model.dart

import 'package:hive/hive.dart';

part 'module_model.g.dart';

@HiveType(typeId: 19)
class ModuleModel {
  @HiveField(0)
  final int id;
  
  @HiveField(1)
  final int niveauId;
  
  @HiveField(2)
  final String code; // UE101
  
  @HiveField(3)
  final String nom;
  
  @HiveField(4)
  final int creditsECTS;
  
  @HiveField(5)
  final int heuresCM; // Cours Magistraux
  
  @HiveField(6)
  final int heuresTD; // Travaux Dirigés
  
  @HiveField(7)
  final int heuresTP; // Travaux Pratiques
  
  @HiveField(8)
  final double coefficient;
  
  @HiveField(9)
  final String semestre; // S1, S2, S3, S4, S5, S6
  
  @HiveField(10)
  final int professeurId;
  
  ModuleModel({
    required this.id,
    required this.niveauId,
    required this.code,
    required this.nom,
    required this.creditsECTS,
    required this.heuresCM,
    required this.heuresTD,
    required this.heuresTP,
    required this.coefficient,
    required this.semestre,
    required this.professeurId,
  });
}
// lib/models/university/niveau_model.dart

import 'package:hive/hive.dart';

part 'niveau_model.g.dart';

@HiveType(typeId: 18)
class NiveauModel {
  @HiveField(0)
  final int id;
  
  @HiveField(1)
  final int departementId;
  
  @HiveField(2)
  final String nom; // Licence 1, Master 2, Doctorat
  
  @HiveField(3)
  final int ordre; // 1, 2, 3
  
  @HiveField(4)
  final int duree; // en années
  
  @HiveField(5)
  final String? description;
  
  NiveauModel({
    required this.id,
    required this.departementId,
    required this.nom,
    required this.ordre,
    required this.duree,
    this.description,
  });
}
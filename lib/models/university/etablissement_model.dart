// lib/models/university/etablissement_model.dart

import 'package:hive/hive.dart';
import 'dart:math';

part 'etablissement_model.g.dart';

@HiveType(typeId: 15)
class EtablissementModel {
  @HiveField(0)
  int? id;
  
  @HiveField(1)
  String nom;
  
  @HiveField(2)
  String type;
  
  @HiveField(3)
  String? adresse;
  
  @HiveField(4)
  String? telephone;
  
  @HiveField(5)
  String? email;
  
  @HiveField(6)
  String? siteWeb;
  
  @HiveField(7)
  String? firestoreId;
  
  @HiveField(8)
  DateTime? createdAt;
  
  @HiveField(9)
  DateTime? updatedAt;
  
  @HiveField(10)
  bool isActive;
  
  @HiveField(11)
  String schoolCode;  // Code unique de l'école

  EtablissementModel({
    this.id,
    required this.nom,
    this.type = 'École',
    this.adresse,
    this.telephone,
    this.email,
    this.siteWeb,
    this.firestoreId,
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
    required this.schoolCode,
  });

  // Générer un code unique pour l'école
  static String generateSchoolCode(String schoolName) {
    // Prendre les 3 premières lettres du nom en majuscules
    String prefix = schoolName.length >= 3 
        ? schoolName.substring(0, 3).toUpperCase() 
        : schoolName.toUpperCase().padRight(3, 'X');
    
    // Générer 4 caractères aléatoires
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    String suffix = String.fromCharCodes(
      Iterable.generate(4, (_) => chars.codeUnitAt(rnd.nextInt(chars.length)))
    );
    
    return '$prefix-$suffix';
  }

  // Méthode pour convertir en Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'type': type,
      'adresse': adresse,
      'telephone': telephone,
      'email': email,
      'siteWeb': siteWeb,
      'firestoreId': firestoreId,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive,
      'schoolCode': schoolCode,
    };
  }

  // Factory pour créer un objet depuis une Map
  factory EtablissementModel.fromMap(Map<String, dynamic> map) {
    return EtablissementModel(
      id: map['id'],
      nom: map['nom'] ?? '',
      type: map['type'] ?? 'École',
      adresse: map['adresse'],
      telephone: map['telephone'],
      email: map['email'],
      siteWeb: map['siteWeb'],
      firestoreId: map['firestoreId'],
      createdAt: map['createdAt'] != null 
          ? DateTime.tryParse(map['createdAt']) 
          : null,
      updatedAt: map['updatedAt'] != null 
          ? DateTime.tryParse(map['updatedAt']) 
          : null,
      isActive: map['isActive'] ?? true,
      schoolCode: map['schoolCode'] ?? '',
    );
  }

  // Méthode pour copier l'objet avec des modifications
  EtablissementModel copyWith({
    int? id,
    String? nom,
    String? type,
    String? adresse,
    String? telephone,
    String? email,
    String? siteWeb,
    String? firestoreId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? schoolCode,
  }) {
    return EtablissementModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      type: type ?? this.type,
      adresse: adresse ?? this.adresse,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      siteWeb: siteWeb ?? this.siteWeb,
      firestoreId: firestoreId ?? this.firestoreId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      schoolCode: schoolCode ?? this.schoolCode,
    );
  }

  // Getter pour savoir si l'école est active
  bool get isSchoolActive => isActive;

  // Getter pour le statut texte
  String get statusText => isActive ? 'Active' : 'Suspendue';

  // Getter pour la couleur du statut
  int get statusColor => isActive ? 0xFF10B981 : 0xFFEF4444;
}
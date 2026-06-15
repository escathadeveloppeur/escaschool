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

  // ========== NOUVEAUX CHAMPS ==========
  
  @HiveField(12)
  String? pays;
  
  @HiveField(13)
  String? province;
  
  @HiveField(14)
  String? ville;
  
  @HiveField(15)
  String? commune;
  
  @HiveField(16)
  String? codePostal;
  
  @HiveField(17)
  String? statut;  // Public, Privé, Conventionné, etc.
  
  @HiveField(18)
  String? directeurNom;
  
  @HiveField(19)
  String? directeurEmail;
  
  @HiveField(20)
  String? directeurTelephone;
  
  @HiveField(21)
  int? anneeCreation;
  
  @HiveField(22)
  int? capacite;  // Nombre d'élèves maximum
  
  @HiveField(23)
  String? langueEnseignement;
  
  @HiveField(24)
  String? logoUrl;  // URL du logo dans Firebase Storage
  
  @HiveField(25)
  String? signaturePrefet;  // Nom du préfet des études
  
  @HiveField(26)
  String? signatureChef;  // Nom du chef d'établissement

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
    // Nouveaux champs
    this.pays,
    this.province,
    this.ville,
    this.commune,
    this.codePostal,
    this.statut,
    this.directeurNom,
    this.directeurEmail,
    this.directeurTelephone,
    this.anneeCreation,
    this.capacite,
    this.langueEnseignement,
    this.logoUrl,
    this.signaturePrefet,
    this.signatureChef,
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
      // Nouveaux champs
      'pays': pays,
      'province': province,
      'ville': ville,
      'commune': commune,
      'codePostal': codePostal,
      'statut': statut,
      'directeurNom': directeurNom,
      'directeurEmail': directeurEmail,
      'directeurTelephone': directeurTelephone,
      'anneeCreation': anneeCreation,
      'capacite': capacite,
      'langueEnseignement': langueEnseignement,
      'logoUrl': logoUrl,
      'signaturePrefet': signaturePrefet,
      'signatureChef': signatureChef,
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
      // Nouveaux champs
      pays: map['pays'],
      province: map['province'],
      ville: map['ville'],
      commune: map['commune'],
      codePostal: map['codePostal'],
      statut: map['statut'],
      directeurNom: map['directeurNom'],
      directeurEmail: map['directeurEmail'],
      directeurTelephone: map['directeurTelephone'],
      anneeCreation: map['anneeCreation'],
      capacite: map['capacite'],
      langueEnseignement: map['langueEnseignement'],
      logoUrl: map['logoUrl'],
      signaturePrefet: map['signaturePrefet'],
      signatureChef: map['signatureChef'],
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
    // Nouveaux champs
    String? pays,
    String? province,
    String? ville,
    String? commune,
    String? codePostal,
    String? statut,
    String? directeurNom,
    String? directeurEmail,
    String? directeurTelephone,
    int? anneeCreation,
    int? capacite,
    String? langueEnseignement,
    String? logoUrl,
    String? signaturePrefet,
    String? signatureChef,
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
      // Nouveaux champs
      pays: pays ?? this.pays,
      province: province ?? this.province,
      ville: ville ?? this.ville,
      commune: commune ?? this.commune,
      codePostal: codePostal ?? this.codePostal,
      statut: statut ?? this.statut,
      directeurNom: directeurNom ?? this.directeurNom,
      directeurEmail: directeurEmail ?? this.directeurEmail,
      directeurTelephone: directeurTelephone ?? this.directeurTelephone,
      anneeCreation: anneeCreation ?? this.anneeCreation,
      capacite: capacite ?? this.capacite,
      langueEnseignement: langueEnseignement ?? this.langueEnseignement,
      logoUrl: logoUrl ?? this.logoUrl,
      signaturePrefet: signaturePrefet ?? this.signaturePrefet,
      signatureChef: signatureChef ?? this.signatureChef,
    );
  }

  // Getter pour savoir si l'école est active
  bool get isSchoolActive => isActive;

  // Getter pour le statut texte
  String get statusText => isActive ? 'Active' : 'Suspendue';

  // Getter pour la couleur du statut
  int get statusColor => isActive ? 0xFF10B981 : 0xFFEF4444;
  
  // Getter pour l'adresse complète formatée
  String get adresseComplete {
    List<String> parts = [];
    if (adresse != null && adresse!.isNotEmpty) parts.add(adresse!);
    if (ville != null && ville!.isNotEmpty) parts.add(ville!);
    if (commune != null && commune!.isNotEmpty) parts.add(commune!);
    if (province != null && province!.isNotEmpty) parts.add(province!);
    if (codePostal != null && codePostal!.isNotEmpty) parts.add(codePostal!);
    if (pays != null && pays!.isNotEmpty) parts.add(pays!);
    return parts.join(', ');
  }
  
  // Getter pour le pays affiché
  String get paysDisplay => pays ?? 'Non spécifié';
  
  // Getter pour la province affichée
  String get provinceDisplay => province ?? 'Non spécifié';
  
  // Getter pour la ville affichée
  String get villeDisplay => ville ?? 'Non spécifié';
}
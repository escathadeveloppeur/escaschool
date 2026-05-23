// lib/models/user.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final int id;
  final String? firestoreId;
  final String name;
  final String email;
  final String role;
  final String password;
  final int? schoolId;
  final String? firebaseUid;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  User({
    required this.id,
    this.firestoreId,
    required this.name,
    required this.email,
    required this.role,
    required this.password,
    this.schoolId,
    this.firebaseUid,
    this.createdAt,
    this.lastLogin,
  });

  // ================= CONVERSION POUR HIVE (LOCAL) =================
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firestoreId': firestoreId,
      'name': name,
      'email': email,
      'role': role,
      'password': password,
      'schoolId': schoolId,
      'firebaseUid': firebaseUid,
      'createdAt': createdAt?.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> m) {
    return User(
      id: m['id'] as int? ?? 0,
      firestoreId: m['firestoreId'] as String?,
      name: m['name'] as String? ?? '',
      email: m['email'] as String? ?? '',
      role: m['role'] as String? ?? 'student',
      password: m['password'] as String? ?? '',
      schoolId: m['schoolId'] as int?,
      firebaseUid: m['firebaseUid'] as String?,
      createdAt: m['createdAt'] != null 
          ? DateTime.tryParse(m['createdAt']) 
          : null,
      lastLogin: m['lastLogin'] != null 
          ? DateTime.tryParse(m['lastLogin']) 
          : null,
    );
  }

  // ================= CONVERSION POUR FIRESTORE (CLOUD) =================
  
  /// Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'localId': id,
      'name': name,
      'email': email,
      'role': role,
      'schoolId': schoolId,
      'firebaseUid': firebaseUid,
      'createdAt': createdAt != null 
          ? Timestamp.fromDate(createdAt!) 
          : FieldValue.serverTimestamp(),
      'lastLogin': lastLogin != null 
          ? Timestamp.fromDate(lastLogin!) 
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
  
  /// Créer un User depuis Firestore
  factory User.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return User(
      id: data['localId'] as int? ?? 0,
      firestoreId: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'student',
      password: '',
      schoolId: data['schoolId'] as int?,
      firebaseUid: doc.id,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
    );
  }

  // ================= MÉTHODES UTILITAIRES =================
  
  /// Copier l'utilisateur avec modifications
  User copyWith({
    int? id,
    String? firestoreId,
    String? name,
    String? email,
    String? role,
    String? password,
    int? schoolId,
    String? firebaseUid,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      password: password ?? this.password,
      schoolId: schoolId ?? this.schoolId,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  /// Mettre à jour la date de dernière connexion
  User updateLastLogin() {
    return copyWith(lastLogin: DateTime.now());
  }

  // ================= GETTERS DE RÔLES =================
  
  bool get isSuperAdmin => role == 'super_admin';
  bool get isSchoolAdmin => role == 'admin';
  bool get isTeacher => role == 'teacher';
  bool get isStudent => role == 'student';
  bool get isParent => role == 'parent';
  bool get isStaff => role == 'staff' || isTeacher || isSchoolAdmin;
  bool get hasSchool => schoolId != null;
  bool get hasFirebaseAccount => firebaseUid != null && firebaseUid!.isNotEmpty;
  
  // ================= TEXTE DES RÔLES =================
  
  String get roleLabel {
    switch (role) {
      case 'super_admin':
        return 'Super Administrateur';
      case 'admin':
        return 'Administrateur';
      case 'teacher':
        return 'Enseignant';
      case 'student':
        return 'Étudiant';
      case 'parent':
        return 'Parent';
      case 'staff':
        return 'Personnel';
      default:
        return role;
    }
  }
  
  // ================= COULEUR DU RÔLE =================
  
  Color get roleColor {
    switch (role) {
      case 'super_admin':
        return const Color(0xFF8B5CF6);
      case 'admin':
        return const Color(0xFFEF4444);
      case 'teacher':
        return const Color(0xFF3B82F6);
      case 'student':
        return const Color(0xFF10B981);
      case 'parent':
        return const Color(0xFFF59E0B);
      case 'staff':
        return const Color(0xFF6366F1);
      default:
        return Colors.grey;
    }
  }
  
  // ================= ICÔNE DU RÔLE =================
  
  IconData get roleIcon {
    switch (role) {
      case 'super_admin':
        return Icons.admin_panel_settings;
      case 'admin':
        return Icons.security;
      case 'teacher':
        return Icons.school;
      case 'student':
        return Icons.person;
      case 'parent':
        return Icons.family_restroom;
      case 'staff':
        return Icons.work;
      default:
        return Icons.person;
    }
  }

  // ================= VALIDATIONS =================
  
  bool get isValidEmail => RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  bool get isValidName => name.trim().length >= 2;
  bool get isValidPassword => password.length >= 6;
  bool get isComplete => 
      id > 0 && 
      name.isNotEmpty && 
      email.isNotEmpty && 
      role.isNotEmpty;

  // ================= JSON =================
  
  Map<String, dynamic> toJson() => toMap();
  
  factory User.fromJson(Map<String, dynamic> json) => User.fromMap(json);
  
  // ================= TOSTRING =================
  
  @override
  String toString() {
    return 'User(id: $id, firestoreId: $firestoreId, name: $name, email: $email, role: $role, schoolId: $schoolId, hasFirebase: $hasFirebaseAccount)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;  // ← CORRIGÉ : getter au lieu de méthode
}
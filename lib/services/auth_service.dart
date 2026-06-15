// lib/services/auth_service.dart

import '../models/user.dart';
import 'db_helper.dart';

class AuthService {
  final DBHelper _db = DBHelper();

  /// Connexion - Retourne un User si email + mot de passe correct, sinon null
  Future<User?> login(String email, String password) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final normalizedPassword = password.trim();

      final userMap = await _db.getUserByEmail(normalizedEmail);
      if (userMap == null) return null;

      final dbPassword = (userMap['password'] as String? ?? '').trim();
      if (dbPassword == normalizedPassword) {
        final id = userMap['id'];
        final int safeId = id is int ? id : (int.tryParse(id.toString()) ?? 0);
        
        return User(
          id: safeId,
          name: userMap['name'] as String? ?? '',
          email: userMap['email'] as String? ?? '',
          role: userMap['role'] as String? ?? 'student',
          password: dbPassword,
          schoolId: userMap['schoolId'] as String?,
        );
      }
      return null;
    } catch (e) {
      print('Erreur login: $e');
      return null;
    }
  }

  /// Enregistrement d'un nouvel utilisateur
  Future<User?> register(User user) async {
    try {
      final userMap = user.toMap();
      userMap['email'] = (userMap['email'] as String).trim().toLowerCase();
      userMap['password'] = (userMap['password'] as String).trim();
      
      if (user.schoolId != null) {
        userMap['schoolId'] = user.schoolId;
      }

      final id = await _db.insertUser(userMap);
      
      return User(
        id: id,
        name: user.name,
        email: userMap['email'],
        role: user.role,
        password: userMap['password'],
        schoolId: user.schoolId,
      );
    } catch (e) {
      print('Erreur register: $e');
      return null;
    }
  }

  /// Vérifier si un email existe déjà
  Future<bool> emailExists(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final userMap = await _db.getUserByEmail(normalizedEmail);
      return userMap != null;
    } catch (e) {
      return false;
    }
  }

  /// Récupérer un utilisateur par son ID
  Future<User?> getUserById(int id) async {
    try {
      final users = await _db.getAllUsers();
      final userMap = users.firstWhere(
        (user) => user['id'] == id,
        orElse: () => {},
      );
      
      if (userMap.isEmpty) return null;
      
      return User(
        id: userMap['id'] as int? ?? 0,
        name: userMap['name'] as String? ?? '',
        email: userMap['email'] as String? ?? '',
        role: userMap['role'] as String? ?? 'student',
        password: userMap['password'] as String? ?? '',
        schoolId: userMap['schoolId'] as String?,
      );
    } catch (e) {
      print('Erreur getUserById: $e');
      return null;
    }
  }

  /// Récupérer tous les utilisateurs d'une école
  Future<List<User>> getUsersBySchool(int schoolId) async {
    try {
      final allUsers = await _db.getAllUsers();
      final schoolUsers = allUsers.where((u) => u['schoolId'] == schoolId).toList();
      
      return schoolUsers.map((userMap) => User(
        id: userMap['id'] as int? ?? 0,
        name: userMap['name'] as String? ?? '',
        email: userMap['email'] as String? ?? '',
        role: userMap['role'] as String? ?? 'student',
        password: userMap['password'] as String? ?? '',
        schoolId: userMap['schoolId'] as String?,
      )).toList();
    } catch (e) {
      print('Erreur getUsersBySchool: $e');
      return [];
    }
  }

  /// Récupérer les utilisateurs par rôle
  Future<List<User>> getUsersByRole(String role) async {
    try {
      final allUsers = await _db.getAllUsers();
      final roleUsers = allUsers.where((u) => u['role'] == role).toList();
      
      return roleUsers.map((userMap) => User(
        id: userMap['id'] as int? ?? 0,
        name: userMap['name'] as String? ?? '',
        email: userMap['email'] as String? ?? '',
        role: userMap['role'] as String? ?? 'student',
        password: userMap['password'] as String? ?? '',
        schoolId: userMap['schoolId'] as String?,
      )).toList();
    } catch (e) {
      print('Erreur getUsersByRole: $e');
      return [];
    }
  }

  /// Mettre à jour le profil utilisateur
  Future<bool> updateUser(int userId, Map<String, dynamic> updates) async {
    try {
      await _db.updateUser(userId, updates);
      return true;
    } catch (e) {
      print('Erreur updateUser: $e');
      return false;
    }
  }

  /// Supprimer un utilisateur
  Future<bool> deleteUser(int userId) async {
    try {
      return await _db.deleteUser(userId);
    } catch (e) {
      print('Erreur deleteUser: $e');
      return false;
    }
  }

  /// Statistiques d'une école
  Future<Map<String, int>> getSchoolStats(int schoolId) async {
    try {
      final users = await getUsersBySchool(schoolId);
      
      return {
        'total': users.length,
        'students': users.where((u) => u.role == 'student').length,
        'teachers': users.where((u) => u.role == 'teacher').length,
        'admins': users.where((u) => u.role == 'admin').length,
        'staff': users.where((u) => u.role == 'staff').length,
        'parents': users.where((u) => u.role == 'parent').length,
      };
    } catch (e) {
      print('Erreur getSchoolStats: $e');
      return {
        'total': 0,
        'students': 0,
        'teachers': 0,
        'admins': 0,
        'staff': 0,
        'parents': 0,
      };
    }
  }

  /// Déconnexion
  void logout() {
    // Rien à faire ici, le provider gère l'état
  }
}
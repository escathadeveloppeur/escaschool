// lib/services/settings_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DBHelper _dbHelper = DBHelper();

  // ==================== GESTION DU MOT DE PASSE ====================

  /// Modifier le mot de passe de l'utilisateur connecté
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // Réauthentifier l'utilisateur
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      
      // Changer le mot de passe
      await user.updatePassword(newPassword);
      
      // Log l'action
      await _dbHelper.addLog("Modification du mot de passe par l'utilisateur: ${user.email}");
      
      print('✅ Mot de passe modifié avec succès');
      return true;
      
    } catch (e) {
      print('❌ Erreur modification mot de passe: $e');
      throw e;
    }
  }

  // ==================== GESTION DES UTILISATEURS ====================

  /// Réinitialiser le mot de passe d'un utilisateur (admin seulement)
  Future<bool> resetUserPassword(String email, String newPassword) async {
    try {
      // Note: Firebase n'a pas d'API directe pour réinitialiser sans email
      // Solution alternative: envoyer un email de réinitialisation
      await _auth.sendPasswordResetEmail(email: email);
      print('✅ Email de réinitialisation envoyé à: $email');
      return true;
      
    } catch (e) {
      print('❌ Erreur réinitialisation mot de passe: $e');
      throw e;
    }
  }

  // ==================== PARAMÈTRES DE L'APPLICATION ====================

  /// Sauvegarder les paramètres généraux
  Future<void> saveAppSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    for (var entry in settings.entries) {
      await prefs.setString(entry.key, entry.value.toString());
    }
  }

  /// Récupérer les paramètres
  Future<Map<String, dynamic>> getAppSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'darkMode': prefs.getBool('darkMode') ?? false,
      'notifications': prefs.getBool('notifications') ?? true,
      'language': prefs.getString('language') ?? 'fr',
    };
  }
}
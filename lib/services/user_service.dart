// lib/services/user_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  // ==================== CRUD UTILISATEURS ====================

  /// ✅ Créer un utilisateur dans Firestore (sous-collection de l'école)
  Future<String> createUser(Map<String, dynamic> user, String schoolId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('Utilisateur non connecté');

      // 🔥 Utiliser une sous-collection de l'école
      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .doc();

      final userData = {
        'name': user['name'],
        'email': user['email'],
        'role': user['role'],
        'localId': user['id'],
        'localKey': user['id']?.toString(),
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isSynced': true,
      };

      await docRef.set(userData);
      
      // Mettre à jour l'ID Firestore dans le document local
      user['firestoreId'] = docRef.id;
      
      print('✅ Utilisateur créé dans Firestore: ${docRef.id}');
      return docRef.id;
      
    } catch (e) {
      print('❌ Erreur création utilisateur Firestore: $e');
      throw e;
    }
  }

  /// ✅ Mettre à jour un utilisateur dans Firestore
  Future<void> updateUser(String schoolId, String userId, Map<String, dynamic> user) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('Utilisateur non connecté');

      final updateData = {
        'name': user['name'],
        'email': user['email'],
        'role': user['role'],
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': currentUser.uid,
      };

      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .doc(userId)
          .update(updateData);
          
      print('✅ Utilisateur mis à jour dans Firestore: $userId');

    } catch (e) {
      print('❌ Erreur mise à jour utilisateur Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer un utilisateur de Firestore
  Future<void> deleteUser(String schoolId, String userId) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .doc(userId)
          .delete();
          
      print('🗑️ Utilisateur supprimé de Firestore: $userId');

    } catch (e) {
      print('❌ Erreur suppression utilisateur Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer tous les utilisateurs d'une école
  Future<void> deleteAllUsers(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Tous les utilisateurs supprimés pour l\'école: $schoolId');

    } catch (e) {
      print('❌ Erreur suppression tous les utilisateurs: $e');
      throw e;
    }
  }

  /// ✅ Supprimer les utilisateurs par rôle
  Future<void> deleteUsersByRole(String schoolId, String role) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .where('role', isEqualTo: role)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Utilisateurs supprimés pour le rôle: $role');

    } catch (e) {
      print('❌ Erreur suppression utilisateurs par rôle: $e');
      throw e;
    }
  }

  // ==================== RÉCUPÉRATION DES UTILISATEURS ====================

  /// ✅ Récupérer tous les utilisateurs d'une école
  Future<List<Map<String, dynamic>>> getUsersBySchool(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'firestoreId': doc.id,
          'id': data['localId'],
          'name': data['name'],
          'email': data['email'],
          'role': data['role'],
          'schoolId': data['schoolId'],
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération utilisateurs par école: $e');
      return [];
    }
  }

  /// ✅ Récupérer les utilisateurs par rôle
  Future<List<Map<String, dynamic>>> getUsersByRole(String schoolId, String role) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .where('role', isEqualTo: role)
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'firestoreId': doc.id,
          'id': data['localId'],
          'name': data['name'],
          'email': data['email'],
          'role': data['role'],
          'schoolId': data['schoolId'],
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération utilisateurs par rôle: $e');
      return [];
    }
  }

  /// ✅ Récupérer un utilisateur par son ID local
  Future<Map<String, dynamic>?> getUserById(String schoolId, int userId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .where('localId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      
      final doc = snapshot.docs.first;
      final data = doc.data();
      return {
        'firestoreId': doc.id,
        'id': data['localId'],
        'name': data['name'],
        'email': data['email'],
        'role': data['role'],
        'schoolId': data['schoolId'],
        'createdAt': data['createdAt'],
        'updatedAt': data['updatedAt'],
      };

    } catch (e) {
      print('❌ Erreur récupération utilisateur par ID: $e');
      return null;
    }
  }

  /// ✅ Récupérer un utilisateur par son email
  Future<Map<String, dynamic>?> getUserByEmail(String schoolId, String email) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      
      final doc = snapshot.docs.first;
      final data = doc.data();
      return {
        'firestoreId': doc.id,
        'id': data['localId'],
        'name': data['name'],
        'email': data['email'],
        'role': data['role'],
        'schoolId': data['schoolId'],
        'createdAt': data['createdAt'],
        'updatedAt': data['updatedAt'],
      };

    } catch (e) {
      print('❌ Erreur récupération utilisateur par email: $e');
      return null;
    }
  }

  /// ✅ Récupérer un utilisateur par son Firestore ID
  Future<Map<String, dynamic>?> getUserByFirestoreId(String schoolId, String firestoreId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .doc(firestoreId)
          .get();
      
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      return {
        'firestoreId': doc.id,
        'id': data['localId'],
        'name': data['name'],
        'email': data['email'],
        'role': data['role'],
        'schoolId': data['schoolId'],
        'createdAt': data['createdAt'],
        'updatedAt': data['updatedAt'],
      };

    } catch (e) {
      print('❌ Erreur récupération utilisateur par Firestore ID: $e');
      return null;
    }
  }

  // ==================== ÉCOUTE EN TEMPS RÉEL ====================

  /// ✅ Écouter les utilisateurs d'une école en temps réel
  Stream<List<Map<String, dynamic>>> listenToUsers(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('users')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'firestoreId': doc.id,
              'id': data['localId'],
              'name': data['name'],
              'email': data['email'],
              'role': data['role'],
              'schoolId': data['schoolId'],
              'createdAt': data['createdAt'],
              'updatedAt': data['updatedAt'],
            };
          }).toList();
        });
  }

  /// ✅ Écouter les utilisateurs par rôle en temps réel
  Stream<List<Map<String, dynamic>>> listenToUsersByRole(String schoolId, String role) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('users')
        .where('role', isEqualTo: role)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'firestoreId': doc.id,
              'id': data['localId'],
              'name': data['name'],
              'email': data['email'],
              'role': data['role'],
              'schoolId': data['schoolId'],
              'createdAt': data['createdAt'],
              'updatedAt': data['updatedAt'],
            };
          }).toList();
        });
  }

  // ==================== SYNCHRONISATION ====================

  /// ✅ Synchroniser tous les utilisateurs locaux vers Firestore
  Future<void> syncAllUsersToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des utilisateurs vers Firestore...');
      final users = await _dbHelper.getAllUsers();
      
      if (users.isEmpty) {
        print('📭 Aucun utilisateur à synchroniser');
        return;
      }
      
      int syncedCount = 0;
      
      for (var user in users) {
        try {
          final existing = await _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('users')
              .where('localId', isEqualTo: user['id'])
              .get();

          if (existing.docs.isEmpty) {
            await createUser(user, schoolId);
            syncedCount++;
          } else {
            final firestoreId = existing.docs.first.id;
            user['firestoreId'] = firestoreId;
            await updateUser(schoolId, firestoreId, user);
            syncedCount++;
          }
        } catch (e) {
          print('❌ Erreur synchronisation utilisateur ${user['id']}: $e');
        }
      }

      print('✅ Synchronisation terminée: $syncedCount/${users.length} utilisateurs');

    } catch (e) {
      print('❌ Erreur synchronisation utilisateurs: $e');
      throw e;
    }
  }

  /// ✅ Synchroniser les utilisateurs depuis Firestore vers local
  Future<void> syncUsersFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des utilisateurs depuis Firestore...');
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .get();

      if (snapshot.docs.isEmpty) {
        print('📭 Aucun utilisateur à synchroniser depuis Firestore');
        return;
      }

      int addedCount = 0;
      int updatedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          
          final user = {
            'id': data['localId'],
            'firestoreId': doc.id,
            'name': data['name'],
            'email': data['email'],
            'role': data['role'],
            'schoolId': data['schoolId'],
            'createdAt': data['createdAt'],
            'updatedAt': data['updatedAt'],
          };
          
          final existing = await _dbHelper.getUserById(user['id']);
          
          if (existing == null) {
            await _dbHelper.insertUser(user);
            addedCount++;
          } else {
            await _dbHelper.updateUserById(user['id'], user);
            updatedCount++;
          }
        } catch (e) {
          print('  ⚠️ Erreur traitement utilisateur ${doc.id}: $e');
        }
      }

      print('✅ Synchronisation terminée: +$addedCount ajoutés, $updatedCount mis à jour');

    } catch (e) {
      print('❌ Erreur synchronisation utilisateurs depuis Firestore: $e');
      throw e;
    }
  }

  /// ✅ Synchronisation complète (bidirectionnelle)
  Future<void> syncAllUserData(String schoolId) async {
    try {
      print('🔄 Synchronisation complète des utilisateurs...');
      await syncAllUsersToFirestore(schoolId);
      await syncUsersFromFirestore(schoolId);
      print('✅ Synchronisation complète des utilisateurs terminée');
    } catch (e) {
      print('❌ Erreur synchronisation complète: $e');
      throw e;
    }
  }

  // ==================== STATISTIQUES ====================

  /// ✅ Compter les utilisateurs par rôle
  Future<Map<String, int>> countUsersByRole(String schoolId) async {
    try {
      final Map<String, int> counts = {};
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .get();
      
      for (var doc in snapshot.docs) {
        final role = doc['role'] ?? 'unknown';
        counts[role] = (counts[role] ?? 0) + 1;
      }
      
      return counts;

    } catch (e) {
      print('❌ Erreur comptage utilisateurs par rôle: $e');
      return {};
    }
  }

  /// ✅ Obtenir les statistiques complètes
  Future<Map<String, dynamic>> getUserStats(String schoolId) async {
    try {
      final byRole = await countUsersByRole(schoolId);
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .get();
      
      return {
        'totalUsers': snapshot.docs.length,
        'byRole': byRole,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

    } catch (e) {
      print('❌ Erreur statistiques utilisateurs: $e');
      return {};
    }
  }

  /// ✅ Écouter les statistiques en temps réel
  Stream<Map<String, dynamic>> listenToUserStats(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('users')
        .snapshots()
        .map((snapshot) {
          final Map<String, int> byRole = {};
          
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final role = data['role'] ?? 'unknown';
            byRole[role] = (byRole[role] ?? 0) + 1;
          }
          
          return {
            'totalUsers': snapshot.docs.length,
            'byRole': byRole,
            'lastUpdated': DateTime.now().toIso8601String(),
          };
        });
  }

  // ==================== RECHERCHE ====================

  /// ✅ Rechercher des utilisateurs par nom
  Future<List<Map<String, dynamic>>> searchUsersByName(String schoolId, String query) async {
    try {
      if (query.isEmpty) return [];
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: query + '\uf8ff')
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'firestoreId': doc.id,
          'id': data['localId'],
          'name': data['name'],
          'email': data['email'],
          'role': data['role'],
          'schoolId': data['schoolId'],
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur recherche utilisateurs par nom: $e');
      return [];
    }
  }

  /// ✅ Vérifier si un utilisateur existe déjà
  Future<bool> userExists(String schoolId, String email) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;

    } catch (e) {
      print('❌ Erreur vérification utilisateur: $e');
      return false;
    }
  }

  /// ✅ Vérifier si un utilisateur existe par ID local
  Future<bool> userExistsById(String schoolId, int userId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .where('localId', isEqualTo: userId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;

    } catch (e) {
      print('❌ Erreur vérification utilisateur par ID: $e');
      return false;
    }
  }
}
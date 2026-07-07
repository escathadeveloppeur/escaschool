// lib/services/professor_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';

class ProfessorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  // ==================== CRUD PROFESSEURS ====================

  /// ✅ Créer un professeur dans Firestore (sous-collection de l'école)
  Future<String> createProfessor(Map<String, dynamic> professor, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 🔥 Utiliser une sous-collection de l'école
      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .doc();

      final professorData = {
        'fullName': professor['fullName'],
        'email': professor['email'],
        'phone': professor['phone'],
        'specialty': professor['specialty'],
        'status': professor['status'],
        'userId': professor['userId'],
        'schoolId': schoolId,
        'localId': professor['id'],
        'isHomeroomTeacher': professor['isHomeroomTeacher'] ?? false,
        'homeroomClassId': professor['homeroomClassId'],
        'homeroomClassName': professor['homeroomClassName'],
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(professorData);
      
      // Mettre à jour l'ID Firestore dans le document local
      professor['firestoreId'] = docRef.id;
      
      print('✅ Professeur créé dans Firestore: ${docRef.id}');
      if (professorData['isHomeroomTeacher'] == true) {
        print('   🏫 Est titulaire de la classe: ${professorData['homeroomClassName']}');
        // Donner les permissions automatiquement
        await _grantFullPermission(docRef.id, professor['homeroomClassId'], professor['homeroomClassName']);
      }
      return docRef.id;

    } catch (e) {
      print('❌ Erreur création professeur Firestore: $e');
      throw e;
    }
  }

  /// ✅ Mettre à jour un professeur dans Firestore
  Future<void> updateProfessor(String schoolId, String firestoreId, Map<String, dynamic> professor) async {
    try {
      final updateData = {
        'fullName': professor['fullName'],
        'email': professor['email'],
        'phone': professor['phone'],
        'specialty': professor['specialty'],
        'status': professor['status'],
        'isHomeroomTeacher': professor['isHomeroomTeacher'] ?? false,
        'homeroomClassId': professor['homeroomClassId'],
        'homeroomClassName': professor['homeroomClassName'],
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .doc(firestoreId)
          .update(updateData);
          
      print('✅ Professeur mis à jour dans Firestore: $firestoreId');
      if (updateData['isHomeroomTeacher'] == true) {
        print('   🏫 Maintenant titulaire de la classe: ${updateData['homeroomClassName']}');
        await _grantFullPermission(firestoreId, professor['homeroomClassId'], professor['homeroomClassName']);
      }

    } catch (e) {
      print('❌ Erreur mise à jour professeur Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer un professeur de Firestore
  Future<void> deleteProfessor(String schoolId, String firestoreId) async {
    try {
      // Supprimer aussi ses permissions
      final permissions = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professor_permissions')
          .where('professorFirestoreId', isEqualTo: firestoreId)
          .get();
      
      final batch = _firestore.batch();
      for (var perm in permissions.docs) {
        batch.delete(perm.reference);
      }
      
      // Supprimer le professeur
      final professorRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .doc(firestoreId);
      batch.delete(professorRef);
      
      await batch.commit();
      
      print('🗑️ Professeur supprimé de Firestore: $firestoreId');
      print('   📋 ${permissions.docs.length} permissions supprimées');
      
    } catch (e) {
      print('❌ Erreur suppression professeur Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer tous les professeurs d'une école
  Future<void> deleteAllProfessors(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Tous les professeurs supprimés pour l\'école: $schoolId');
      
    } catch (e) {
      print('❌ Erreur suppression tous les professeurs: $e');
      throw e;
    }
  }

  // ==================== GESTION DES PERMISSIONS ====================

  /// ✅ Donner une permission complète pour une classe
  Future<void> _grantFullPermission(String professorFirestoreId, String classFirestoreId, String className) async {
    try {
      if (classFirestoreId == null || classFirestoreId.isEmpty) return;
      
      // Vérifier si la permission existe déjà
      final existing = await _firestore
          .collection('professors')
          .doc(professorFirestoreId)
          .collection('permissions')
          .where('classFirestoreId', isEqualTo: classFirestoreId)
          .get();
      
      if (existing.docs.isEmpty) {
        await _firestore
            .collection('professors')
            .doc(professorFirestoreId)
            .collection('permissions')
            .add({
          'classFirestoreId': classFirestoreId,
          'className': className,
          'permissionType': 'full',
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('   🔐 Permission complète accordée pour $className');
      } else {
        await existing.docs.first.reference.update({
          'permissionType': 'full',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('   🔐 Permission mise à jour pour $className');
      }
    } catch (e) {
      print('❌ Erreur grantFullPermission: $e');
    }
  }

  /// ✅ Donner une permission à un professeur
  Future<void> grantPermission(String schoolId, String professorId, String classId, String className, String permissionType) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .doc(professorId)
          .collection('permissions')
          .add({
        'classFirestoreId': classId,
        'className': className,
        'permissionType': permissionType, // 'full', 'read', 'write'
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Permission $permissionType accordée pour $className');
      
    } catch (e) {
      print('❌ Erreur grantPermission: $e');
      throw e;
    }
  }

  /// ✅ Retirer une permission
  Future<void> revokePermission(String schoolId, String professorId, String permissionId) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .doc(professorId)
          .collection('permissions')
          .doc(permissionId)
          .delete();
      
      print('🗑️ Permission révoquée');
      
    } catch (e) {
      print('❌ Erreur revokePermission: $e');
      throw e;
    }
  }

  /// ✅ Définir un professeur comme titulaire d'une classe
  Future<void> setAsHomeroomTeacher(String schoolId, String professorId, String classFirestoreId, String className) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .doc(professorId)
          .update({
        'isHomeroomTeacher': true,
        'homeroomClassId': classFirestoreId,
        'homeroomClassName': className,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Donner automatiquement les permissions complètes pour cette classe
      await _grantFullPermission(professorId, classFirestoreId, className);
      
      print('✅ Professeur $professorId est maintenant titulaire de $className');
      
    } catch (e) {
      print('❌ Erreur setAsHomeroomTeacher: $e');
      throw e;
    }
  }

  /// ✅ Retirer le statut de titulaire
  Future<void> removeHomeroomTeacher(String schoolId, String professorId) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .doc(professorId)
          .update({
        'isHomeroomTeacher': false,
        'homeroomClassId': null,
        'homeroomClassName': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Professeur $professorId n\'est plus titulaire');
      
    } catch (e) {
      print('❌ Erreur removeHomeroomTeacher: $e');
      throw e;
    }
  }

  // ==================== RÉCUPÉRATION DES PROFESSEURS ====================

  /// ✅ Récupérer tous les professeurs d'une école
  Future<List<Map<String, dynamic>>> getProfessorsBySchool(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .orderBy('fullName')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'firestoreId': doc.id,
          ...data,
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération professeurs par école: $e');
      return [];
    }
  }

  /// ✅ Récupérer un professeur par son ID Firestore
  Future<Map<String, dynamic>?> getProfessorById(String schoolId, String firestoreId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .doc(firestoreId)
          .get();
      
      if (doc.exists) {
        return {
          'firestoreId': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }
      return null;
      
    } catch (e) {
      print('❌ Erreur getProfessorById: $e');
      return null;
    }
  }

  /// ✅ Récupérer les professeurs par spécialité
  Future<List<Map<String, dynamic>>> getProfessorsBySpecialty(String schoolId, String specialty) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .where('specialty', isEqualTo: specialty)
          .orderBy('fullName')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'firestoreId': doc.id,
          ...data,
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération professeurs par spécialité: $e');
      return [];
    }
  }

  /// ✅ Récupérer les professeurs par statut
  Future<List<Map<String, dynamic>>> getProfessorsByStatus(String schoolId, String status) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .where('status', isEqualTo: status)
          .orderBy('fullName')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'firestoreId': doc.id,
          ...data,
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération professeurs par statut: $e');
      return [];
    }
  }

  /// ✅ Récupérer les professeurs titulaires
  Future<List<Map<String, dynamic>>> getHomeroomTeachers(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .where('isHomeroomTeacher', isEqualTo: true)
          .orderBy('fullName')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'firestoreId': doc.id,
          ...data,
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération professeurs titulaires: $e');
      return [];
    }
  }

  /// ✅ Récupérer le professeur titulaire d'une classe
  Future<Map<String, dynamic>?> getHomeroomTeacherByClass(String schoolId, String classFirestoreId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .where('homeroomClassId', isEqualTo: classFirestoreId)
          .where('isHomeroomTeacher', isEqualTo: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return {
          'firestoreId': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }
      return null;
      
    } catch (e) {
      print('❌ Erreur getHomeroomTeacherByClass: $e');
      return null;
    }
  }

  /// ✅ Récupérer les permissions d'un professeur
  Future<List<Map<String, dynamic>>> getProfessorPermissions(String schoolId, String professorId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .doc(professorId)
          .collection('permissions')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'permissionId': doc.id,
          ...data,
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération permissions: $e');
      return [];
    }
  }

  /// ✅ Vérifier si un professeur a accès complet à une classe
  Future<bool> hasFullAccessToClass(String schoolId, String professorId, String classFirestoreId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .doc(professorId)
          .collection('permissions')
          .where('classFirestoreId', isEqualTo: classFirestoreId)
          .where('permissionType', isEqualTo: 'full')
          .get();
      
      return snapshot.docs.isNotEmpty;
      
    } catch (e) {
      print('❌ Erreur hasFullAccessToClass: $e');
      return false;
    }
  }

  // ==================== ÉCOUTE EN TEMPS RÉEL ====================

  /// ✅ Écouter les professeurs d'une école en temps réel
  Stream<List<Map<String, dynamic>>> listenToProfessors(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('professors')
        .orderBy('fullName')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'firestoreId': doc.id,
              ...data,
            };
          }).toList();
        });
  }

  /// ✅ Écouter les professeurs titulaires en temps réel
  Stream<List<Map<String, dynamic>>> listenToHomeroomTeachers(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('professors')
        .where('isHomeroomTeacher', isEqualTo: true)
        .orderBy('fullName')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'firestoreId': doc.id,
              ...data,
            };
          }).toList();
        });
  }

  // ==================== SYNCHRONISATION ====================

  /// ✅ Synchroniser tous les professeurs locaux vers Firestore
  Future<void> syncAllProfessorsToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des professeurs vers Firestore...');
      final localProfessors = await _dbHelper.getAllProfessors();
      
      if (localProfessors.isEmpty) {
        print('📭 Aucun professeur à synchroniser');
        return;
      }
      
      int syncedCount = 0;
      
      for (var professor in localProfessors) {
        try {
          final existing = await _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('professors')
              .where('localId', isEqualTo: professor['id'])
              .get();

          if (existing.docs.isEmpty) {
            await createProfessor(professor, schoolId);
            syncedCount++;
          } else {
            final firestoreId = existing.docs.first.id;
            await updateProfessor(schoolId, firestoreId, professor);
            syncedCount++;
          }
        } catch (e) {
          print('❌ Erreur synchronisation professeur ${professor['id']}: $e');
        }
      }

      print('✅ Synchronisation terminée: $syncedCount/${localProfessors.length} professeurs');

    } catch (e) {
      print('❌ Erreur synchronisation professeurs: $e');
      throw e;
    }
  }

  /// ✅ Synchroniser les professeurs depuis Firestore vers local
  Future<void> syncProfessorsFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des professeurs depuis Firestore...');
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .get();

      if (snapshot.docs.isEmpty) {
        print('📭 Aucun professeur à synchroniser depuis Firestore');
        return;
      }

      int addedCount = 0;
      int updatedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          
          final professor = {
            'id': data['localId'],
            'firestoreId': doc.id,
            'fullName': data['fullName'] ?? '',
            'email': data['email'] ?? '',
            'phone': data['phone'] ?? '',
            'specialty': data['specialty'] ?? '',
            'status': data['status'] ?? 'active',
            'userId': data['userId'],
            'schoolId': data['schoolId'],
            'isHomeroomTeacher': data['isHomeroomTeacher'] ?? false,
            'homeroomClassId': data['homeroomClassId'],
            'homeroomClassName': data['homeroomClassName'],
          };
          
          final existing = await _dbHelper.getProfessorByLocalId(professor['id']);
          
          if (existing == null) {
            await _dbHelper.addProfessor(professor);
            addedCount++;
          } else {
            await _dbHelper.updateProfessorByLocalId(professor['id'], professor);
            updatedCount++;
          }
        } catch (e) {
          print('  ⚠️ Erreur traitement professeur ${doc.id}: $e');
        }
      }

      print('✅ Synchronisation terminée: +$addedCount ajoutés, $updatedCount mis à jour');

    } catch (e) {
      print('❌ Erreur synchronisation professeurs depuis Firestore: $e');
      throw e;
    }
  }

  /// ✅ Synchronisation complète (bidirectionnelle)
  Future<void> syncAllProfessorData(String schoolId) async {
    try {
      print('🔄 Synchronisation complète des professeurs...');
      await syncAllProfessorsToFirestore(schoolId);
      await syncProfessorsFromFirestore(schoolId);
      print('✅ Synchronisation complète des professeurs terminée');
    } catch (e) {
      print('❌ Erreur synchronisation complète: $e');
      throw e;
    }
  }

  // ==================== STATISTIQUES ====================

  /// ✅ Compter les professeurs par statut
  Future<Map<String, int>> countProfessorsByStatus(String schoolId) async {
    try {
      final Map<String, int> counts = {
        'active': 0,
        'inactive': 0,
      };
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .get();
      
      for (var doc in snapshot.docs) {
        final status = doc['status'] ?? 'active';
        counts[status] = (counts[status] ?? 0) + 1;
      }
      
      return counts;
      
    } catch (e) {
      print('❌ Erreur comptage professeurs par statut: $e');
      return {};
    }
  }

  /// ✅ Compter les professeurs par spécialité
  Future<Map<String, int>> countProfessorsBySpecialty(String schoolId) async {
    try {
      final Map<String, int> counts = {};
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .get();
      
      for (var doc in snapshot.docs) {
        final specialty = doc['specialty'] ?? 'other';
        counts[specialty] = (counts[specialty] ?? 0) + 1;
      }
      
      return counts;
      
    } catch (e) {
      print('❌ Erreur comptage professeurs par spécialité: $e');
      return {};
    }
  }

  /// ✅ Obtenir les statistiques complètes
  Future<Map<String, dynamic>> getProfessorStats(String schoolId) async {
    try {
      final byStatus = await countProfessorsByStatus(schoolId);
      final bySpecialty = await countProfessorsBySpecialty(schoolId);
      
      // Compter les professeurs titulaires
      final homeroomSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .where('isHomeroomTeacher', isEqualTo: true)
          .get();
      
      final totalSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .get();
      
      return {
        'total': totalSnapshot.docs.length,
        'byStatus': byStatus,
        'bySpecialty': bySpecialty,
        'homeroomTeachers': homeroomSnapshot.docs.length,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      print('❌ Erreur statistiques professeurs: $e');
      return {};
    }
  }

  /// ✅ Écouter les statistiques en temps réel
  Stream<Map<String, dynamic>> listenToProfessorStats(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('professors')
        .snapshots()
        .map((snapshot) {
          final Map<String, int> byStatus = {};
          final Map<String, int> bySpecialty = {};
          int homeroomCount = 0;
          
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final status = data['status'] ?? 'active';
            byStatus[status] = (byStatus[status] ?? 0) + 1;
            
            final specialty = data['specialty'] ?? 'other';
            bySpecialty[specialty] = (bySpecialty[specialty] ?? 0) + 1;
            
            if (data['isHomeroomTeacher'] == true) {
              homeroomCount++;
            }
          }
          
          return {
            'total': snapshot.docs.length,
            'byStatus': byStatus,
            'bySpecialty': bySpecialty,
            'homeroomTeachers': homeroomCount,
            'lastUpdated': DateTime.now().toIso8601String(),
          };
        });
  }

  // ==================== RECHERCHE ====================

  /// ✅ Rechercher des professeurs par nom
  Future<List<Map<String, dynamic>>> searchProfessors(String schoolId, String query) async {
    try {
      if (query.isEmpty) return [];
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .where('fullName', isGreaterThanOrEqualTo: query)
          .where('fullName', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'firestoreId': doc.id,
          ...data,
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur recherche professeurs: $e');
      return [];
    }
  }

  /// ✅ Rechercher un professeur par email
  Future<Map<String, dynamic>?> getProfessorByEmail(String schoolId, String email) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('professors')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return {
          'firestoreId': doc.id,
          ...doc.data() as Map<String, dynamic>,
        };
      }
      return null;
      
    } catch (e) {
      print('❌ Erreur getProfessorByEmail: $e');
      return null;
    }
  }
}
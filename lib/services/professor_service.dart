// lib/services/professor_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';

class ProfessorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  /// Créer un professeur dans Firestore
  Future<String> createProfessor(Map<String, dynamic> professor, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final docRef = _firestore.collection('professors').doc();
      final professorData = {
        'fullName': professor['fullName'],
        'email': professor['email'],
        'phone': professor['phone'],
        'specialty': professor['specialty'],
        'status': professor['status'],
        'userId': professor['userId'],
        'schoolId': schoolId,
        'localId': professor['id'],
        'isHomeroomTeacher': professor['isHomeroomTeacher'] ?? false,  // NOUVEAU: est titulaire ?
        'homeroomClassId': professor['homeroomClassId'],               // NOUVEAU: ID de sa classe titulaire
        'homeroomClassName': professor['homeroomClassName'],           // NOUVEAU: nom de sa classe titulaire
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(professorData);
      print('✅ Professeur créé dans Firestore: ${docRef.id}');
      if (professorData['isHomeroomTeacher'] == true) {
        print('   🏫 Est titulaire de la classe: ${professorData['homeroomClassName']}');
      }
      return docRef.id;

    } catch (e) {
      print('❌ Erreur création professeur Firestore: $e');
      throw e;
    }
  }

  /// Mettre à jour un professeur dans Firestore
  Future<void> updateProfessor(String firestoreId, Map<String, dynamic> professor) async {
    try {
      final updateData = {
        'fullName': professor['fullName'],
        'email': professor['email'],
        'phone': professor['phone'],
        'specialty': professor['specialty'],
        'status': professor['status'],
        'isHomeroomTeacher': professor['isHomeroomTeacher'] ?? false,  // NOUVEAU
        'homeroomClassId': professor['homeroomClassId'],               // NOUVEAU
        'homeroomClassName': professor['homeroomClassName'],           // NOUVEAU
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('professors').doc(firestoreId).update(updateData);
      print('✅ Professeur mis à jour dans Firestore: $firestoreId');
      if (updateData['isHomeroomTeacher'] == true) {
        print('   🏫 Maintenant titulaire de la classe: ${updateData['homeroomClassName']}');
      }

    } catch (e) {
      print('❌ Erreur mise à jour professeur Firestore: $e');
      throw e;
    }
  }

  /// NOUVEAU: Définir un professeur comme titulaire d'une classe
  Future<void> setAsHomeroomTeacher(String firestoreId, String classFirestoreId, String className) async {
    try {
      await _firestore.collection('professors').doc(firestoreId).update({
        'isHomeroomTeacher': true,
        'homeroomClassId': classFirestoreId,
        'homeroomClassName': className,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Donner automatiquement les permissions complètes pour cette classe
      await _grantFullPermission(firestoreId, classFirestoreId, className);
      
      print('✅ Professeur $firestoreId est maintenant titulaire de $className');
    } catch (e) {
      print('❌ Erreur setAsHomeroomTeacher: $e');
      throw e;
    }
  }

  /// NOUVEAU: Retirer le statut de titulaire
  Future<void> removeHomeroomTeacher(String firestoreId) async {
    try {
      await _firestore.collection('professors').doc(firestoreId).update({
        'isHomeroomTeacher': false,
        'homeroomClassId': null,
        'homeroomClassName': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Professeur $firestoreId n\'est plus titulaire');
    } catch (e) {
      print('❌ Erreur removeHomeroomTeacher: $e');
      throw e;
    }
  }

  /// NOUVEAU: Donner une permission complète pour une classe
  Future<void> _grantFullPermission(String professorFirestoreId, String classFirestoreId, String className) async {
    try {
      // Vérifier si la permission existe déjà
      final existing = await _firestore
          .collection('professor_permissions')
          .where('professorFirestoreId', isEqualTo: professorFirestoreId)
          .where('classFirestoreId', isEqualTo: classFirestoreId)
          .get();
      
      if (existing.docs.isEmpty) {
        await _firestore.collection('professor_permissions').add({
          'professorFirestoreId': professorFirestoreId,
          'classFirestoreId': classFirestoreId,
          'className': className,
          'permissionType': 'full',  // Permission complète
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('   🔐 Permission complète accordée pour $className');
      } else {
        // Mettre à jour la permission existante
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

  /// NOUVEAU: Récupérer un professeur par son ID Firestore
  Future<Map<String, dynamic>?> getProfessorById(String firestoreId) async {
    try {
      final doc = await _firestore.collection('professors').doc(firestoreId).get();
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

  /// NOUVEAU: Récupérer le professeur titulaire d'une classe
  Future<Map<String, dynamic>?> getHomeroomTeacherByClass(String classFirestoreId) async {
    try {
      final snapshot = await _firestore
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

  /// NOUVEAU: Vérifier si un professeur a accès complet à une classe
  Future<bool> hasFullAccessToClass(String professorFirestoreId, String classFirestoreId) async {
    try {
      final snapshot = await _firestore
          .collection('professor_permissions')
          .where('professorFirestoreId', isEqualTo: professorFirestoreId)
          .where('classFirestoreId', isEqualTo: classFirestoreId)
          .where('permissionType', isEqualTo: 'full')
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Erreur hasFullAccessToClass: $e');
      return false;
    }
  }

  /// Supprimer un professeur de Firestore
  Future<void> deleteProfessor(String firestoreId) async {
    try {
      // Supprimer aussi ses permissions
      final permissions = await _firestore
          .collection('professor_permissions')
          .where('professorFirestoreId', isEqualTo: firestoreId)
          .get();
      
      for (var perm in permissions.docs) {
        await perm.reference.delete();
      }
      
      await _firestore.collection('professors').doc(firestoreId).delete();
      print('🗑️ Professeur supprimé de Firestore: $firestoreId');
      print('   📋 ${permissions.docs.length} permissions supprimées');
    } catch (e) {
      print('❌ Erreur suppression professeur Firestore: $e');
      throw e;
    }
  }

  /// Synchroniser tous les professeurs locaux vers Firestore
  Future<void> syncAllProfessorsToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des professeurs vers Firestore...');
      final localProfessors = await _dbHelper.getAllProfessors();
      
      for (var professor in localProfessors) {
        final existing = await _firestore
            .collection('professors')
            .where('localId', isEqualTo: professor['id'])
            .get();

        if (existing.docs.isEmpty) {
          await createProfessor(professor, schoolId);
        } else {
          final firestoreId = existing.docs.first.id;
          await updateProfessor(firestoreId, professor);
        }
      }

      print('✅ Synchronisation des professeurs terminée: ${localProfessors.length}');

    } catch (e) {
      print('❌ Erreur synchronisation professeurs: $e');
      throw e;
    }
  }
}
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
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(professorData);
      print('✅ Professeur créé dans Firestore: ${docRef.id}');
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
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('professors').doc(firestoreId).update(updateData);
      print('✅ Professeur mis à jour dans Firestore: $firestoreId');

    } catch (e) {
      print('❌ Erreur mise à jour professeur Firestore: $e');
      throw e;
    }
  }

  /// Supprimer un professeur de Firestore
  Future<void> deleteProfessor(String firestoreId) async {
    try {
      await _firestore.collection('professors').doc(firestoreId).delete();
      print('🗑️ Professeur supprimé de Firestore: $firestoreId');
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
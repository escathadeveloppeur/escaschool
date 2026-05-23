// lib/services/class_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/class_model.dart';
import 'db_helper.dart';

class ClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  /// Créer une classe dans Firestore
  Future<String> createClass(ClassModel classModel, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final docRef = _firestore.collection('classes').doc();
      final classData = {
        'className': classModel.className,
        'level': classModel.level,
        'year': classModel.year,
        'subjects': classModel.subjects,
        'schoolId': schoolId,
        'localId': classModel.hiveKey,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(classData);
      print('✅ Classe créée dans Firestore: ${docRef.id}');
      return docRef.id;

    } catch (e) {
      print('❌ Erreur création classe Firestore: $e');
      throw e;
    }
  }

  /// Mettre à jour une classe dans Firestore
  Future<void> updateClass(String firestoreId, ClassModel classModel) async {
    try {
      final updateData = {
        'className': classModel.className,
        'level': classModel.level,
        'year': classModel.year,
        'subjects': classModel.subjects,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('classes').doc(firestoreId).update(updateData);
      print('✅ Classe mise à jour dans Firestore: $firestoreId');

    } catch (e) {
      print('❌ Erreur mise à jour classe Firestore: $e');
      throw e;
    }
  }

  /// Supprimer une classe de Firestore
  Future<void> deleteClass(String firestoreId) async {
    try {
      await _firestore.collection('classes').doc(firestoreId).delete();
      print('🗑️ Classe supprimée de Firestore: $firestoreId');
    } catch (e) {
      print('❌ Erreur suppression classe Firestore: $e');
      throw e;
    }
  }

  /// Récupérer toutes les classes d'une école depuis Firestore
  Future<List<Map<String, dynamic>>> getClassesFromFirestore(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('classes')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      final classes = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'firestoreId': doc.id,
          'className': data['className'],
          'level': data['level'],
          'year': data['year'],
          'subjects': data['subjects'],
          'localId': data['localId'],
        };
      }).toList();

      print('📥 Classes récupérées depuis Firestore: ${classes.length}');
      return classes;

    } catch (e) {
      print('❌ Erreur récupération classes Firestore: $e');
      return [];
    }
  }

  /// Synchroniser toutes les classes locales vers Firestore
  Future<void> syncAllClassesToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des classes vers Firestore...');
      final localClasses = await _dbHelper.getAllClasses();
      
      for (var classModel in localClasses) {
        final existing = await _firestore
            .collection('classes')
            .where('localId', isEqualTo: classModel.hiveKey)
            .get();

        if (existing.docs.isEmpty) {
          await createClass(classModel, schoolId);
        } else {
          final firestoreId = existing.docs.first.id;
          await updateClass(firestoreId, classModel);
        }
      }

      print('✅ Synchronisation des classes terminée: ${localClasses.length} classes');

    } catch (e) {
      print('❌ Erreur synchronisation classes: $e');
      throw e;
    }
  }
}
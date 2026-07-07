// lib/services/class_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/class_model.dart';
import 'db_helper.dart';

class ClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  /// ✅ MODIFIÉ : Créer une classe DANS une école (sous-collection)
  Future<String> createClass(ClassModel classModel, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 🔥 Changement ici : on utilise une sous-collection
      final docRef = _firestore
          .collection('schools')      // ← Collection écoles
          .doc(schoolId)              // ← Document de l'école
          .collection('classes')      // ← Sous-collection "classes"
          .doc();                     // ← ID auto-généré

      final classData = {
        'className': classModel.className,
        'level': classModel.level,
        'year': classModel.year,
        'subjects': classModel.subjects,
        // ❌ On retire schoolId car c'est implicite via le chemin
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

  /// ✅ MODIFIÉ : Mettre à jour une classe
  Future<void> updateClass(String schoolId, String classId, ClassModel classModel) async {
    try {
      final updateData = {
        'className': classModel.className,
        'level': classModel.level,
        'year': classModel.year,
        'subjects': classModel.subjects,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 🔥 Changement ici : chemin vers la sous-collection
      await _firestore
          .collection('schools')
          .doc(schoolId)              // ← École parent
          .collection('classes')      // ← Sous-collection
          .doc(classId)               // ← ID de la classe
          .update(updateData);
          
      print('✅ Classe mise à jour dans Firestore: $classId');

    } catch (e) {
      print('❌ Erreur mise à jour classe Firestore: $e');
      throw e;
    }
  }

  /// ✅ MODIFIÉ : Supprimer une classe
  Future<void> deleteClass(String schoolId, String classId) async {
    try {
      // 🔥 Changement ici
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('classes')
          .doc(classId)
          .delete();
          
      print('🗑️ Classe supprimée de Firestore: $classId');
    } catch (e) {
      print('❌ Erreur suppression classe Firestore: $e');
      throw e;
    }
  }

  /// ✅ MODIFIÉ : Récupérer toutes les classes d'une école
  Future<List<Map<String, dynamic>>> getClassesFromFirestore(String schoolId) async {
    try {
      // 🔥 Changement ici
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('classes')
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
          // ❌ On retire schoolId
        };
      }).toList();

      print('📥 Classes récupérées depuis Firestore: ${classes.length}');
      return classes;

    } catch (e) {
      print('❌ Erreur récupération classes Firestore: $e');
      return [];
    }
  }

  /// ✅ MODIFIÉ : Synchroniser les classes
  Future<void> syncAllClassesToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des classes vers Firestore...');
      final localClasses = await _dbHelper.getAllClasses();
      
      for (var classModel in localClasses) {
        try {
          // 🔥 Vérifier si la classe existe déjà dans la sous-collection
          final existing = await _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('classes')
              .where('localId', isEqualTo: classModel.hiveKey)
              .get();

          if (existing.docs.isEmpty) {
            await createClass(classModel, schoolId);
          } else {
            final firestoreId = existing.docs.first.id;
            await updateClass(schoolId, firestoreId, classModel);
          }
        } catch (e) {
          print('  ⚠️ Erreur synchronisation classe ${classModel.className}: $e');
        }
      }

      print('✅ Synchronisation des classes terminée: ${localClasses.length} classes');

    } catch (e) {
      print('❌ Erreur synchronisation classes: $e');
      throw e;
    }
  }

  // ==================== NOUVELLES MÉTHODES ====================

  /// 🆕 Écouter en temps réel les classes d'une école
  Stream<List<Map<String, dynamic>>> listenToClasses(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('classes')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
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
        });
  }

  /// 🆕 Supprimer toutes les classes d'une école
  Future<void> deleteAllClasses(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('classes')
          .get();
      
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      
      print('🗑️ Toutes les classes supprimées pour l\'école: $schoolId');
    } catch (e) {
      print('❌ Erreur suppression toutes les classes: $e');
      throw e;
    }
  }
}
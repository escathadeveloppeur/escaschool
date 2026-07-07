// lib/services/online_course_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/online_course_model.dart';

class OnlineCourseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  // ==================== CRUD COURS ====================

  /// ✅ Créer un cours dans Firestore (sous-collection de l'école)
  Future<String> createCourse(OnlineCourseModel course, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 🔥 Utiliser une sous-collection de l'école
      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_courses')
          .doc();

      // 🔥 Utiliser toFirestoreMap() du modèle
      final courseData = course.toFirestoreMap();
      
      // Ajouter les champs spécifiques au service
      courseData.addAll({
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isSynced': true,
      });

      await docRef.set(courseData);
      
      // Mettre à jour l'ID Firestore dans le modèle
      course.courseFirestoreId = docRef.id;
      
      print('✅ Cours créé dans Firestore: ${docRef.id}');
      return docRef.id;
      
    } catch (e) {
      print('❌ Erreur création cours Firestore: $e');
      throw e;
    }
  }

  /// ✅ Mettre à jour un cours dans Firestore
  Future<void> updateCourse(String schoolId, String courseId, OnlineCourseModel course) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final updateData = course.toFirestoreMap();
      
      updateData.addAll({
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
      
      // Retirer les champs qui ne doivent pas être mis à jour
      updateData.remove('createdAt');
      updateData.remove('createdBy');

      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_courses')
          .doc(courseId)
          .update(updateData);
          
      print('✅ Cours mis à jour dans Firestore: $courseId');
      
    } catch (e) {
      print('❌ Erreur mise à jour cours Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer un cours de Firestore
  Future<void> deleteCourse(String schoolId, String courseId) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_courses')
          .doc(courseId)
          .delete();
          
      print('🗑️ Cours supprimé de Firestore: $courseId');
      
    } catch (e) {
      print('❌ Erreur suppression cours Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer tous les cours d'une école
  Future<void> deleteAllCourses(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_courses')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Tous les cours supprimés pour l\'école: $schoolId');
      
    } catch (e) {
      print('❌ Erreur suppression tous les cours: $e');
      throw e;
    }
  }

  /// ✅ Supprimer les cours d'une classe
  Future<void> deleteCoursesByClass(String schoolId, String classId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_courses')
          .where('classId', isEqualTo: classId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Cours supprimés pour la classe: $classId');
      
    } catch (e) {
      print('❌ Erreur suppression cours par classe: $e');
      throw e;
    }
  }

  /// ✅ Supprimer les cours par matière
  Future<void> deleteCoursesBySubject(String schoolId, String subject) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_courses')
          .where('subject', isEqualTo: subject)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Cours supprimés pour la matière: $subject');
      
    } catch (e) {
      print('❌ Erreur suppression cours par matière: $e');
      throw e;
    }
  }

  // ==================== RÉCUPÉRATION DES COURS ====================

  /// ✅ Récupérer tous les cours d'une école
  Future<List<OnlineCourseModel>> getCoursesBySchool(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_courses')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return OnlineCourseModel.fromFirestore(data, doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération cours par école: $e');
      return [];
    }
  }

  /// ✅ Récupérer les cours d'une classe
  Future<List<OnlineCourseModel>> getCoursesByClass(String schoolId, String classId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_courses')
          .where('classId', isEqualTo: classId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return OnlineCourseModel.fromFirestore(data, doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération cours par classe: $e');
      return [];
    }
  }

  /// ✅ Récupérer les cours d'une matière
  Future<List<OnlineCourseModel>> getCoursesBySubject(String schoolId, String subject) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_courses')
          .where('subject', isEqualTo: subject)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return OnlineCourseModel.fromFirestore(data, doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération cours par matière: $e');
      return [];
    }
  }

  /// ✅ Récupérer les cours d'un professeur
  Future<List<OnlineCourseModel>> getCoursesByProfessor(String schoolId, String professorId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_courses')
          .where('professorId', isEqualTo: professorId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return OnlineCourseModel.fromFirestore(data, doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération cours par professeur: $e');
      return [];
    }
  }

  /// ✅ Récupérer un cours par son ID local
  Future<OnlineCourseModel?> getCourseById(String schoolId, int courseId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_courses')
          .where('id', isEqualTo: courseId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      
      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      return OnlineCourseModel.fromFirestore(data, doc.id);
      
    } catch (e) {
      print('❌ Erreur récupération cours par ID: $e');
      return null;
    }
  }

  /// ✅ Récupérer un cours par son ID Firestore
  Future<OnlineCourseModel?> getCourseByFirestoreId(String schoolId, String courseFirestoreId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_courses')
          .doc(courseFirestoreId)
          .get();
      
      if (!doc.exists) return null;
      
      final data = doc.data() as Map<String, dynamic>;
      return OnlineCourseModel.fromFirestore(data, doc.id);
      
    } catch (e) {
      print('❌ Erreur récupération cours par Firestore ID: $e');
      return null;
    }
  }

  // ==================== ÉCOUTE EN TEMPS RÉEL ====================

  /// ✅ Écouter tous les cours d'une école en temps réel
  Stream<List<OnlineCourseModel>> listenToCourses(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('online_courses')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return OnlineCourseModel.fromFirestore(data, doc.id);
          }).toList();
        });
  }

  /// ✅ Écouter les cours d'une classe en temps réel
  Stream<List<OnlineCourseModel>> listenToCoursesByClass(String schoolId, String classId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('online_courses')
        .where('classId', isEqualTo: classId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return OnlineCourseModel.fromFirestore(data, doc.id);
          }).toList();
        });
  }

  /// ✅ Écouter les cours d'une matière en temps réel
  Stream<List<OnlineCourseModel>> listenToCoursesBySubject(String schoolId, String subject) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('online_courses')
        .where('subject', isEqualTo: subject)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return OnlineCourseModel.fromFirestore(data, doc.id);
          }).toList();
        });
  }

  // ==================== SYNCHRONISATION ====================

  /// ✅ Synchroniser tous les cours locaux vers Firestore
  Future<void> syncAllCoursesToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des cours vers Firestore...');
      final courses = await _dbHelper.getAllOnlineCourses();
      
      if (courses.isEmpty) {
        print('📭 Aucun cours à synchroniser');
        return;
      }
      
      int syncedCount = 0;
      
      for (var course in courses) {
        try {
          final existing = await _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('online_courses')
              .where('id', isEqualTo: course.id)
              .get();

          if (existing.docs.isEmpty) {
            await createCourse(course, schoolId);
            syncedCount++;
          } else {
            final docId = existing.docs.first.id;
            course.courseFirestoreId = docId;
            await updateCourse(schoolId, docId, course);
            syncedCount++;
          }
        } catch (e) {
          print('❌ Erreur synchronisation cours ${course.id}: $e');
        }
      }

      print('✅ Synchronisation terminée: $syncedCount/${courses.length} cours');

    } catch (e) {
      print('❌ Erreur synchronisation cours: $e');
      throw e;
    }
  }

  /// ✅ Synchroniser les cours depuis Firestore vers local
  Future<void> syncCoursesFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des cours depuis Firestore...');
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_courses')
          .get();

      if (snapshot.docs.isEmpty) {
        print('📭 Aucun cours à synchroniser depuis Firestore');
        return;
      }

      int addedCount = 0;
      int updatedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final course = OnlineCourseModel.fromFirestore(data, doc.id);
          
          final existing = await _dbHelper.getOnlineCourseById(course.id);
          
          if (existing == null) {
            await _dbHelper.addOnlineCourse(course);
            addedCount++;
          } else if (course.updatedAt.isAfter(existing.updatedAt)) {
            await _dbHelper.updateOnlineCourse(course);
            updatedCount++;
          }
        } catch (e) {
          print('  ⚠️ Erreur traitement cours ${doc.id}: $e');
        }
      }

      print('✅ Synchronisation terminée: +$addedCount ajoutés, $updatedCount mis à jour');

    } catch (e) {
      print('❌ Erreur synchronisation cours depuis Firestore: $e');
      throw e;
    }
  }

  /// ✅ Synchronisation complète (bidirectionnelle)
  Future<void> syncAllCourseData(String schoolId) async {
    try {
      print('🔄 Synchronisation complète des cours...');
      await syncAllCoursesToFirestore(schoolId);
      await syncCoursesFromFirestore(schoolId);
      print('✅ Synchronisation complète des cours terminée');
    } catch (e) {
      print('❌ Erreur synchronisation complète: $e');
      throw e;
    }
  }

  // ==================== STATISTIQUES ====================

  /// ✅ Compter les cours par matière
  Future<Map<String, int>> countCoursesBySubject(String schoolId) async {
    try {
      final Map<String, int> counts = {};
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_courses')
          .get();
      
      for (var doc in snapshot.docs) {
        final subject = doc['subject'] ?? 'other';
        counts[subject] = (counts[subject] ?? 0) + 1;
      }
      
      return counts;
      
    } catch (e) {
      print('❌ Erreur comptage cours par matière: $e');
      return {};
    }
  }

  /// ✅ Compter les cours par classe
  Future<Map<String, int>> countCoursesByClass(String schoolId) async {
    try {
      final Map<String, int> counts = {};
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_courses')
          .get();
      
      for (var doc in snapshot.docs) {
        final classId = doc['classId'] ?? 'unknown';
        counts[classId] = (counts[classId] ?? 0) + 1;
      }
      
      return counts;
      
    } catch (e) {
      print('❌ Erreur comptage cours par classe: $e');
      return {};
    }
  }

  /// ✅ Obtenir les statistiques complètes
  Future<Map<String, dynamic>> getCourseStats(String schoolId) async {
    try {
      final bySubject = await countCoursesBySubject(schoolId);
      final byClass = await countCoursesByClass(schoolId);
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_courses')
          .get();
      
      return {
        'totalCourses': snapshot.docs.length,
        'bySubject': bySubject,
        'byClass': byClass,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      print('❌ Erreur statistiques cours: $e');
      return {};
    }
  }

  /// ✅ Écouter les statistiques en temps réel
  Stream<Map<String, dynamic>> listenToCourseStats(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('online_courses')
        .snapshots()
        .map((snapshot) {
          final Map<String, int> bySubject = {};
          final Map<String, int> byClass = {};
          
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final subject = data['subject'] ?? 'other';
            bySubject[subject] = (bySubject[subject] ?? 0) + 1;
            
            final classId = data['classId'] ?? 'unknown';
            byClass[classId] = (byClass[classId] ?? 0) + 1;
          }
          
          return {
            'totalCourses': snapshot.docs.length,
            'bySubject': bySubject,
            'byClass': byClass,
            'lastUpdated': DateTime.now().toIso8601String(),
          };
        });
  }

  // ==================== RECHERCHE ====================

  /// ✅ Rechercher des cours par titre
  Future<List<OnlineCourseModel>> searchCoursesByTitle(String schoolId, String query) async {
    try {
      if (query.isEmpty) return [];
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_courses')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: query + '\uf8ff')
          .orderBy('title')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return OnlineCourseModel.fromFirestore(data, doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur recherche cours par titre: $e');
      return [];
    }
  }

  /// ✅ Rechercher des cours par description
  Future<List<OnlineCourseModel>> searchCoursesByDescription(String schoolId, String query) async {
    try {
      if (query.isEmpty) return [];
      
      // Note: Firestore ne supporte pas la recherche full-text
      // On récupère tous les cours et on filtre côté client
      final allCourses = await getCoursesBySchool(schoolId);
      
      return allCourses.where((course) =>
        course.description.toLowerCase().contains(query.toLowerCase())
      ).toList();

    } catch (e) {
      print('❌ Erreur recherche cours par description: $e');
      return [];
    }
  }
}
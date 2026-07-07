// lib/services/online_exam_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/online_exam_model.dart';
import '../models/exam_result_model.dart';

class OnlineExamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  // ==================== CRUD EXAMENS ====================

  /// ✅ Créer un examen dans Firestore (sous-collection de l'école)
  Future<String> createExam(OnlineExamModel exam, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 🔥 Utiliser une sous-collection de l'école
      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_exams')
          .doc();

      final examData = exam.toFirestoreMap();
      
      examData.addAll({
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isSynced': true,
      });

      await docRef.set(examData);
      
      exam.examFirestoreId = docRef.id;
      
      print('✅ Examen créé dans Firestore: ${docRef.id}');
      return docRef.id;
      
    } catch (e) {
      print('❌ Erreur création examen Firestore: $e');
      throw e;
    }
  }

  /// ✅ Mettre à jour un examen dans Firestore
  Future<void> updateExam(String schoolId, String examFirestoreId, OnlineExamModel exam) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final updateData = exam.toFirestoreMap();
      
      updateData.addAll({
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
      
      updateData.remove('createdAt');
      updateData.remove('createdBy');

      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_exams')
          .doc(examFirestoreId)
          .update(updateData);
          
      print('✅ Examen mis à jour dans Firestore: $examFirestoreId');
      
    } catch (e) {
      print('❌ Erreur mise à jour examen Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer un examen de Firestore
  Future<void> deleteExam(String schoolId, String examFirestoreId) async {
    try {
      // Supprimer aussi les résultats associés
      final results = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('exam_results')
          .where('examFirestoreId', isEqualTo: examFirestoreId)
          .get();
      
      final batch = _firestore.batch();
      for (var result in results.docs) {
        batch.delete(result.reference);
      }
      
      final examRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_exams')
          .doc(examFirestoreId);
      batch.delete(examRef);
      
      await batch.commit();
      
      print('🗑️ Examen et ses résultats supprimés de Firestore: $examFirestoreId');
      
    } catch (e) {
      print('❌ Erreur suppression examen Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer tous les examens d'une école
  Future<void> deleteAllExams(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_exams')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Tous les examens supprimés pour l\'école: $schoolId');
      
    } catch (e) {
      print('❌ Erreur suppression tous les examens: $e');
      throw e;
    }
  }

  /// ✅ Supprimer les examens d'une classe
  Future<void> deleteExamsByClass(String schoolId, String classFirestoreId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_exams')
          .where('classFirestoreId', isEqualTo: classFirestoreId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Examens supprimés pour la classe: $classFirestoreId');
      
    } catch (e) {
      print('❌ Erreur suppression examens par classe: $e');
      throw e;
    }
  }

  // ==================== RÉCUPÉRATION DES EXAMENS ====================

  /// ✅ Récupérer tous les examens d'une école
  Future<List<OnlineExamModel>> getExamsBySchool(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_exams')
          .orderBy('startDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return OnlineExamModel.fromFirestore(data, doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération examens par école: $e');
      return [];
    }
  }

  /// ✅ Récupérer les examens d'une classe
  Future<List<OnlineExamModel>> getExamsByClass(String schoolId, String classFirestoreId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_exams')
          .where('classFirestoreId', isEqualTo: classFirestoreId)
          .orderBy('startDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return OnlineExamModel.fromFirestore(data, doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération examens par classe: $e');
      return [];
    }
  }

  /// ✅ Récupérer les examens par matière
  Future<List<OnlineExamModel>> getExamsBySubject(String schoolId, String subject) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_exams')
          .where('subject', isEqualTo: subject)
          .orderBy('startDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return OnlineExamModel.fromFirestore(data, doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération examens par matière: $e');
      return [];
    }
  }

  /// ✅ Récupérer les examens par statut
  Future<List<OnlineExamModel>> getExamsByStatus(String schoolId, String status) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_exams')
          .where('status', isEqualTo: status)
          .orderBy('startDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return OnlineExamModel.fromFirestore(data, doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération examens par statut: $e');
      return [];
    }
  }

  /// ✅ Récupérer un examen par ID local
  Future<OnlineExamModel?> getExamById(String schoolId, int examId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_exams')
          .where('id', isEqualTo: examId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      
      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      return OnlineExamModel.fromFirestore(data, doc.id);
      
    } catch (e) {
      print('❌ Erreur récupération examen par ID: $e');
      return null;
    }
  }

  /// ✅ Récupérer un examen par ID Firestore
  Future<OnlineExamModel?> getExamByFirestoreId(String schoolId, String examFirestoreId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_exams')
          .doc(examFirestoreId)
          .get();
      
      if (!doc.exists) return null;
      
      final data = doc.data() as Map<String, dynamic>;
      return OnlineExamModel.fromFirestore(data, doc.id);
      
    } catch (e) {
      print('❌ Erreur récupération examen par Firestore ID: $e');
      return null;
    }
  }

  // ==================== ÉCOUTE EN TEMPS RÉEL ====================

  /// ✅ Écouter tous les examens d'une école en temps réel
  Stream<List<OnlineExamModel>> listenToExams(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('online_exams')
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return OnlineExamModel.fromFirestore(data, doc.id);
          }).toList();
        });
  }

  /// ✅ Écouter les examens d'une classe en temps réel
  Stream<List<OnlineExamModel>> listenToExamsByClass(String schoolId, String classFirestoreId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('online_exams')
        .where('classFirestoreId', isEqualTo: classFirestoreId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return OnlineExamModel.fromFirestore(data, doc.id);
          }).toList();
        });
  }

  // ==================== SYNCHRONISATION ====================

  /// ✅ Synchroniser tous les examens locaux vers Firestore
  Future<void> syncAllExamsToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des examens vers Firestore...');
      final exams = await _dbHelper.getAllOnlineExams();
      
      if (exams.isEmpty) {
        print('📭 Aucun examen à synchroniser');
        return;
      }
      
      int syncedCount = 0;
      
      for (var exam in exams) {
        try {
          final existing = await _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('online_exams')
              .where('id', isEqualTo: exam.id)
              .get();

          if (existing.docs.isEmpty) {
            await createExam(exam, schoolId);
            syncedCount++;
          } else {
            final docId = existing.docs.first.id;
            exam.examFirestoreId = docId;
            await updateExam(schoolId, docId, exam);
            syncedCount++;
          }
        } catch (e) {
          print('❌ Erreur synchronisation examen ${exam.id}: $e');
        }
      }

      print('✅ Synchronisation terminée: $syncedCount/${exams.length} examens');

    } catch (e) {
      print('❌ Erreur synchronisation examens: $e');
      throw e;
    }
  }

  /// ✅ Synchroniser les examens depuis Firestore vers local
  Future<void> syncExamsFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des examens depuis Firestore...');
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_exams')
          .get();

      if (snapshot.docs.isEmpty) {
        print('📭 Aucun examen à synchroniser depuis Firestore');
        return;
      }

      int addedCount = 0;
      int updatedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final exam = OnlineExamModel.fromFirestore(data, doc.id);
          
          final existing = await _dbHelper.getOnlineExamById(exam.id);
          
          if (existing == null) {
            await _dbHelper.addOnlineExam(exam);
            addedCount++;
          } else if (exam.updatedAt.isAfter(existing.updatedAt)) {
            await _dbHelper.updateOnlineExam(exam);
            updatedCount++;
          }
        } catch (e) {
          print('  ⚠️ Erreur traitement examen ${doc.id}: $e');
        }
      }

      print('✅ Synchronisation terminée: +$addedCount ajoutés, $updatedCount mis à jour');

    } catch (e) {
      print('❌ Erreur synchronisation examens depuis Firestore: $e');
      throw e;
    }
  }

  /// ✅ Synchronisation complète (bidirectionnelle)
  Future<void> syncAllExamData(String schoolId) async {
    try {
      print('🔄 Synchronisation complète des examens...');
      await syncAllExamsToFirestore(schoolId);
      await syncExamsFromFirestore(schoolId);
      print('✅ Synchronisation complète des examens terminée');
    } catch (e) {
      print('❌ Erreur synchronisation complète: $e');
      throw e;
    }
  }

  // ==================== CRUD RÉSULTATS D'EXAMEN ====================

  /// ✅ Créer un résultat d'examen dans Firestore (sous-collection de l'école)
  Future<String> createExamResult(ExamResultModel result, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('exam_results')
          .doc();

      final resultData = result.toFirestoreMap();
      
      resultData.addAll({
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isSynced': true,
      });

      await docRef.set(resultData);
      
      result.resultFirestoreId = docRef.id;
      
      print('✅ Résultat d\'examen créé dans Firestore: ${docRef.id}');
      return docRef.id;
      
    } catch (e) {
      print('❌ Erreur création résultat examen Firestore: $e');
      throw e;
    }
  }

  /// ✅ Récupérer les résultats d'un examen
  Future<List<ExamResultModel>> getExamResults(String schoolId, int examId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('exam_results')
          .where('examId', isEqualTo: examId)
          .orderBy('score', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ExamResultModel.fromFirestore(data, doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération résultats d\'examen: $e');
      return [];
    }
  }

  /// ✅ Récupérer le résultat d'un étudiant pour un examen
  Future<ExamResultModel?> getStudentExamResult(
    String schoolId, 
    int examId, 
    int studentId
  ) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('exam_results')
          .where('examId', isEqualTo: examId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      
      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      return ExamResultModel.fromFirestore(data, doc.id);
      
    } catch (e) {
      print('❌ Erreur récupération résultat étudiant: $e');
      return null;
    }
  }

  /// ✅ Récupérer tous les résultats d'un étudiant
  Future<List<ExamResultModel>> getStudentResults(String schoolId, int studentId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('exam_results')
          .where('studentId', isEqualTo: studentId)
          .orderBy('submittedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ExamResultModel.fromFirestore(data, doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération résultats étudiant: $e');
      return [];
    }
  }

  /// ✅ Supprimer un résultat d'examen
  Future<void> deleteExamResult(String schoolId, String resultId) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('exam_results')
          .doc(resultId)
          .delete();
          
      print('🗑️ Résultat d\'examen supprimé: $resultId');
      
    } catch (e) {
      print('❌ Erreur suppression résultat examen: $e');
      throw e;
    }
  }

  /// ✅ Supprimer tous les résultats d'un examen
  Future<void> deleteExamResultsByExam(String schoolId, int examId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('exam_results')
          .where('examId', isEqualTo: examId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Résultats supprimés pour l\'examen: $examId');
      
    } catch (e) {
      print('❌ Erreur suppression résultats par examen: $e');
      throw e;
    }
  }

  // ==================== SYNCHRONISATION DES RÉSULTATS ====================

  /// ✅ Synchroniser les résultats d'examen vers Firestore
  Future<void> syncExamResultToFirestore(ExamResultModel result, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 🔥 Utiliser les Firestore IDs pour les requêtes
      final examFirestoreId = result.examFirestoreId ?? '';
      final studentFirestoreId = result.studentFirestoreId ?? '';

      Query query = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('exam_results');

      if (examFirestoreId.isNotEmpty) {
        query = query.where('examFirestoreId', isEqualTo: examFirestoreId);
      } else {
        query = query.where('examId', isEqualTo: result.examId);
      }

      if (studentFirestoreId.isNotEmpty) {
        query = query.where('studentFirestoreId', isEqualTo: studentFirestoreId);
      } else {
        query = query.where('studentId', isEqualTo: result.studentId);
      }

      final existing = await query.get();

      if (existing.docs.isNotEmpty) {
        final docId = existing.docs.first.id;
        final updateData = result.toFirestoreMap();
        updateData.addAll({
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': user.uid,
        });
        await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('exam_results')
            .doc(docId)
            .update(updateData);
        print('✅ Résultat d\'examen mis à jour dans Firestore: $docId');
      } else {
        await createExamResult(result, schoolId);
      }
    } catch (e) {
      print('❌ Erreur synchronisation résultat examen Firestore: $e');
      throw e;
    }
  }

  /// ✅ Synchroniser tous les résultats d'examen vers Firestore
  Future<void> syncAllExamResultsToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des résultats d\'examen vers Firestore...');
      final results = await _dbHelper.getAllExamResults();
      
      if (results.isEmpty) {
        print('📭 Aucun résultat à synchroniser');
        return;
      }
      
      int syncedCount = 0;
      
      for (var result in results) {
        try {
          // 🔥 Utiliser les Firestore IDs si disponibles
          final examFirestoreId = result.examFirestoreId ?? '';
          final studentFirestoreId = result.studentFirestoreId ?? '';

          Query query = _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('exam_results');

          if (examFirestoreId.isNotEmpty) {
            query = query.where('examFirestoreId', isEqualTo: examFirestoreId);
          } else {
            query = query.where('examId', isEqualTo: result.examId);
          }

          if (studentFirestoreId.isNotEmpty) {
            query = query.where('studentFirestoreId', isEqualTo: studentFirestoreId);
          } else {
            query = query.where('studentId', isEqualTo: result.studentId);
          }

          final existing = await query.get();

          if (existing.docs.isEmpty) {
            await createExamResult(result, schoolId);
            syncedCount++;
          } else {
            final docId = existing.docs.first.id;
            result.resultFirestoreId = docId;
            final updateData = result.toFirestoreMap();
            updateData.addAll({
              'updatedAt': FieldValue.serverTimestamp(),
            });
            await _firestore
                .collection('schools')
                .doc(schoolId)
                .collection('exam_results')
                .doc(docId)
                .update(updateData);
            syncedCount++;
          }
        } catch (e) {
          print('❌ Erreur synchronisation résultat ${result.examId}_${result.studentId}: $e');
        }
      }

      print('✅ Synchronisation terminée: $syncedCount/${results.length} résultats');

    } catch (e) {
      print('❌ Erreur synchronisation résultats: $e');
      throw e;
    }
  }

  /// ✅ Synchroniser les résultats depuis Firestore vers local
  Future<void> syncExamResultsFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des résultats depuis Firestore...');
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('exam_results')
          .get();

      if (snapshot.docs.isEmpty) {
        print('📭 Aucun résultat à synchroniser depuis Firestore');
        return;
      }

      int addedCount = 0;
      int updatedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final result = ExamResultModel.fromFirestore(data, doc.id);
          
          final existing = await _dbHelper.getExamResultByKeys(
            result.examId, 
            result.studentId
          );
          
          if (existing == null) {
            await _dbHelper.addExamResult(result);
            addedCount++;
          } else {
            await _dbHelper.updateExamResult(result);
            updatedCount++;
          }
        } catch (e) {
          print('  ⚠️ Erreur traitement résultat ${doc.id}: $e');
        }
      }

      print('✅ Synchronisation terminée: +$addedCount ajoutés, $updatedCount mis à jour');

    } catch (e) {
      print('❌ Erreur synchronisation résultats depuis Firestore: $e');
      throw e;
    }
  }

  /// ✅ Synchronisation complète des résultats
  Future<void> syncAllExamResultData(String schoolId) async {
    try {
      print('🔄 Synchronisation complète des résultats d\'examen...');
      await syncAllExamResultsToFirestore(schoolId);
      await syncExamResultsFromFirestore(schoolId);
      print('✅ Synchronisation complète des résultats terminée');
    } catch (e) {
      print('❌ Erreur synchronisation complète: $e');
      throw e;
    }
  }

  // ==================== STATISTIQUES ====================

  /// ✅ Compter les examens par statut
  Future<Map<String, int>> countExamsByStatus(String schoolId) async {
    try {
      final Map<String, int> counts = {
        'upcoming': 0,
        'ongoing': 0,
        'completed': 0,
        'cancelled': 0,
      };
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_exams')
          .get();
      
      for (var doc in snapshot.docs) {
        final status = doc['status'] ?? 'upcoming';
        counts[status] = (counts[status] ?? 0) + 1;
      }
      
      return counts;
      
    } catch (e) {
      print('❌ Erreur comptage examens par statut: $e');
      return {};
    }
  }

  /// ✅ Obtenir les statistiques complètes des examens
  Future<Map<String, dynamic>> getExamStats(String schoolId) async {
    try {
      final byStatus = await countExamsByStatus(schoolId);
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_exams')
          .get();
      
      return {
        'totalExams': snapshot.docs.length,
        'byStatus': byStatus,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      print('❌ Erreur statistiques examens: $e');
      return {};
    }
  }

  /// ✅ Écouter les statistiques en temps réel
  Stream<Map<String, dynamic>> listenToExamStats(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('online_exams')
        .snapshots()
        .map((snapshot) {
          final Map<String, int> byStatus = {
            'upcoming': 0,
            'ongoing': 0,
            'completed': 0,
            'cancelled': 0,
          };
          
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final status = data['status'] ?? 'upcoming';
            byStatus[status] = (byStatus[status] ?? 0) + 1;
          }
          
          return {
            'totalExams': snapshot.docs.length,
            'byStatus': byStatus,
            'lastUpdated': DateTime.now().toIso8601String(),
          };
        });
  }

  // ==================== RECHERCHE ====================

  /// ✅ Rechercher des examens par titre
  Future<List<OnlineExamModel>> searchExamsByTitle(String schoolId, String query) async {
    try {
      if (query.isEmpty) return [];
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('online_exams')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: query + '\uf8ff')
          .orderBy('title')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return OnlineExamModel.fromFirestore(data, doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur recherche examens par titre: $e');
      return [];
    }
  }
}
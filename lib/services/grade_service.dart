// lib/services/grade_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/grade_model.dart';

class GradeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  // ==================== CRUD NOTES ====================

  /// ✅ Créer une note dans Firestore (sous-collection de l'école)
  Future<String> createGrade(GradeModel grade, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 🔥 Utiliser une sous-collection de l'école
      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .doc();

      // 🔥 Utiliser toFirestoreMap() du modèle
      final gradeData = grade.toFirestoreMap();
      
      // Ajouter les champs spécifiques au service
      gradeData.addAll({
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isSynced': true,
      });

      await docRef.set(gradeData);
      
      // Mettre à jour l'ID Firestore dans le modèle
      grade.firestoreId = docRef.id;
      
      print('✅ Note créée dans Firestore: ${docRef.id}');
      return docRef.id;
      
    } catch (e) {
      print('❌ Erreur création note Firestore: $e');
      throw e;
    }
  }

  /// ✅ Mettre à jour une note dans Firestore
  Future<void> updateGrade(String schoolId, String gradeId, GradeModel grade) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 🔥 Utiliser toFirestoreMap() du modèle
      final updateData = grade.toFirestoreMap();
      
      // Ajouter les champs de mise à jour
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
          .collection('grades')
          .doc(gradeId)
          .update(updateData);
          
      print('✅ Note mise à jour dans Firestore: $gradeId');
      
    } catch (e) {
      print('❌ Erreur mise à jour note Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer une note de Firestore
  Future<void> deleteGrade(String schoolId, String gradeId) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .doc(gradeId)
          .delete();
          
      print('🗑️ Note supprimée de Firestore: $gradeId');
      
    } catch (e) {
      print('❌ Erreur suppression note Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer toutes les notes d'une école
  Future<void> deleteAllGrades(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Toutes les notes supprimées pour l\'école: $schoolId');
      
    } catch (e) {
      print('❌ Erreur suppression toutes les notes: $e');
      throw e;
    }
  }

  /// ✅ Supprimer les notes d'un étudiant
  Future<void> deleteGradesByStudent(String schoolId, int studentKeyHive) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .where('studentKeyHive', isEqualTo: studentKeyHive)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Notes supprimées pour l\'étudiant: $studentKeyHive');
      
    } catch (e) {
      print('❌ Erreur suppression notes par étudiant: $e');
      throw e;
    }
  }

  /// ✅ Supprimer les notes d'une classe
  Future<void> deleteGradesByClass(String schoolId, String classId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .where('classId', isEqualTo: classId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Notes supprimées pour la classe: $classId');
      
    } catch (e) {
      print('❌ Erreur suppression notes par classe: $e');
      throw e;
    }
  }

  // ==================== RÉCUPÉRATION DES NOTES ====================

  /// ✅ Récupérer toutes les notes d'une école
  Future<List<GradeModel>> getGradesBySchool(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return GradeModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération notes par école: $e');
      return [];
    }
  }

  /// ✅ Récupérer les notes d'un étudiant
  Future<List<GradeModel>> getGradesByStudent(String schoolId, int studentKeyHive) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .where('studentKeyHive', isEqualTo: studentKeyHive)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return GradeModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération notes par étudiant: $e');
      return [];
    }
  }

  /// ✅ Récupérer les notes d'une classe
  Future<List<GradeModel>> getGradesByClass(String schoolId, String classId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .where('classId', isEqualTo: classId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return GradeModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération notes par classe: $e');
      return [];
    }
  }

  /// ✅ Récupérer les notes par matière
  Future<List<GradeModel>> getGradesBySubject(String schoolId, String subject) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .where('subject', isEqualTo: subject)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return GradeModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération notes par matière: $e');
      return [];
    }
  }

  /// ✅ Récupérer les notes par type d'évaluation
  Future<List<GradeModel>> getGradesByEvaluationType(String schoolId, String evaluationType) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .where('evaluationType', isEqualTo: evaluationType)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return GradeModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération notes par type: $e');
      return [];
    }
  }

  /// ✅ Récupérer les notes par période (date)
  Future<List<GradeModel>> getGradesByPeriod(String schoolId, DateTime startDate, DateTime endDate) async {
    try {
      final startTimestamp = Timestamp.fromDate(startDate);
      final endTimestamp = Timestamp.fromDate(endDate);
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .where('date', isGreaterThanOrEqualTo: startTimestamp)
          .where('date', isLessThanOrEqualTo: endTimestamp)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return GradeModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération notes par période: $e');
      return [];
    }
  }

  /// ✅ Récupérer une note par ID
  Future<GradeModel?> getGradeById(String schoolId, String gradeId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .doc(gradeId)
          .get();
      
      if (!doc.exists) return null;
      
      return GradeModel.fromFirestore(doc.data()!, doc.id);
      
    } catch (e) {
      print('❌ Erreur récupération note par ID: $e');
      return null;
    }
  }

  // ==================== ÉCOUTE EN TEMPS RÉEL ====================

  /// ✅ Écouter toutes les notes d'une école en temps réel
  Stream<List<GradeModel>> listenToGrades(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('grades')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return GradeModel.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  /// ✅ Écouter les notes d'un étudiant en temps réel
  Stream<List<GradeModel>> listenToGradesByStudent(String schoolId, int studentKeyHive) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('grades')
        .where('studentKeyHive', isEqualTo: studentKeyHive)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return GradeModel.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  /// ✅ Écouter les notes d'une classe en temps réel
  Stream<List<GradeModel>> listenToGradesByClass(String schoolId, String classId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('grades')
        .where('classId', isEqualTo: classId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return GradeModel.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  // ==================== SYNCHRONISATION ====================

  /// ✅ Synchroniser toutes les notes locales vers Firestore
  Future<void> syncAllGradesToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des notes vers Firestore...');
      final grades = await _dbHelper.getAllGrades();
      
      if (grades.isEmpty) {
        print('📭 Aucune note à synchroniser');
        return;
      }
      
      int syncedCount = 0;
      
      for (var grade in grades) {
        try {
          final existing = await _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('grades')
              .where('localKey', isEqualTo: grade.key)
              .get();

          if (existing.docs.isEmpty) {
            await createGrade(grade, schoolId);
            syncedCount++;
          } else {
            // Mettre à jour si nécessaire
            final docId = existing.docs.first.id;
            grade.firestoreId = docId;
            await updateGrade(schoolId, docId, grade);
            syncedCount++;
          }
        } catch (e) {
          print('❌ Erreur synchronisation note ${grade.key}: $e');
        }
      }

      print('✅ Synchronisation terminée: $syncedCount/${grades.length} notes');

    } catch (e) {
      print('❌ Erreur synchronisation notes: $e');
      throw e;
    }
  }

  /// ✅ Synchroniser les notes depuis Firestore vers local
  Future<void> syncGradesFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des notes depuis Firestore...');
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .get();

      if (snapshot.docs.isEmpty) {
        print('📭 Aucune note à synchroniser depuis Firestore');
        return;
      }

      int addedCount = 0;
      int updatedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final grade = GradeModel.fromFirestore(doc.data(), doc.id);
          
          final existing = await _dbHelper.getGradeByKey(grade.key);
          
          if (existing == null) {
            await _dbHelper.addGrade(grade);
            addedCount++;
          } else {
            // Mettre à jour : supprimer l'ancien et ajouter le nouveau
            await _dbHelper.deleteGradeByKey(grade.key);
            await _dbHelper.addGrade(grade);
            updatedCount++;
          }
        } catch (e) {
          print('  ⚠️ Erreur traitement note ${doc.id}: $e');
        }
      }

      print('✅ Synchronisation terminée: +$addedCount ajoutés, $updatedCount mis à jour');

    } catch (e) {
      print('❌ Erreur synchronisation notes depuis Firestore: $e');
      throw e;
    }
  }

  /// ✅ Synchronisation complète (bidirectionnelle)
  Future<void> syncAllGradeData(String schoolId) async {
    try {
      print('🔄 Synchronisation complète des notes...');
      await syncAllGradesToFirestore(schoolId);
      await syncGradesFromFirestore(schoolId);
      print('✅ Synchronisation complète des notes terminée');
    } catch (e) {
      print('❌ Erreur synchronisation complète: $e');
      throw e;
    }
  }

  // ==================== STATISTIQUES ====================

  /// ✅ Calculer la moyenne d'un étudiant
  Future<double> getStudentAverage(String schoolId, int studentKeyHive) async {
    try {
      final grades = await getGradesByStudent(schoolId, studentKeyHive);
      
      if (grades.isEmpty) return 0.0;
      
      double totalWeightedScore = 0;
      double totalCoefficient = 0;
      
      for (var grade in grades) {
        final percentage = (grade.score / grade.maxScore) * 20; // Ramené sur 20
        totalWeightedScore += percentage * grade.coefficient;
        totalCoefficient += grade.coefficient;
      }
      
      return totalCoefficient > 0 ? totalWeightedScore / totalCoefficient : 0.0;
      
    } catch (e) {
      print('❌ Erreur calcul moyenne étudiant: $e');
      return 0.0;
    }
  }

  /// ✅ Calculer la moyenne d'une classe par matière
  Future<Map<String, double>> getClassAverageBySubject(String schoolId, String classId) async {
    try {
      final grades = await getGradesByClass(schoolId, classId);
      
      if (grades.isEmpty) return {};
      
      final Map<String, List<double>> subjectScores = {};
      
      for (var grade in grades) {
        final percentage = (grade.score / grade.maxScore) * 20;
        if (!subjectScores.containsKey(grade.subject)) {
          subjectScores[grade.subject] = [];
        }
        subjectScores[grade.subject]!.add(percentage);
      }
      
      final Map<String, double> averages = {};
      subjectScores.forEach((subject, scores) {
        averages[subject] = scores.reduce((a, b) => a + b) / scores.length;
      });
      
      return averages;
      
    } catch (e) {
      print('❌ Erreur calcul moyenne classe: $e');
      return {};
    }
  }

  /// ✅ Compter les notes par type d'évaluation
  Future<Map<String, int>> countGradesByEvaluationType(String schoolId) async {
    try {
      final Map<String, int> counts = {};
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .get();
      
      for (var doc in snapshot.docs) {
        final type = doc['evaluationType'] ?? 'other';
        counts[type] = (counts[type] ?? 0) + 1;
      }
      
      return counts;
      
    } catch (e) {
      print('❌ Erreur comptage notes par type: $e');
      return {};
    }
  }

  /// ✅ Obtenir les statistiques complètes
  Future<Map<String, dynamic>> getGradeStats(String schoolId) async {
    try {
      final byType = await countGradesByEvaluationType(schoolId);
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .get();
      
      // Calculer la moyenne générale
      double totalScore = 0;
      int count = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final score = (data['score'] ?? 0).toDouble();
        final maxScore = (data['maxScore'] ?? 20).toDouble();
        if (maxScore > 0) {
          totalScore += (score / maxScore) * 20;
          count++;
        }
      }
      
      final overallAverage = count > 0 ? totalScore / count : 0.0;
      
      return {
        'totalGrades': snapshot.docs.length,
        'byEvaluationType': byType,
        'overallAverage': overallAverage,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      print('❌ Erreur statistiques notes: $e');
      return {};
    }
  }

  /// ✅ Écouter les statistiques en temps réel
  Stream<Map<String, dynamic>> listenToGradeStats(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('grades')
        .snapshots()
        .map((snapshot) {
          final Map<String, int> byType = {};
          double totalScore = 0;
          int count = 0;
          
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final type = data['evaluationType'] ?? 'other';
            byType[type] = (byType[type] ?? 0) + 1;
            
            final score = (data['score'] ?? 0).toDouble();
            final maxScore = (data['maxScore'] ?? 20).toDouble();
            if (maxScore > 0) {
              totalScore += (score / maxScore) * 20;
              count++;
            }
          }
          
          return {
            'totalGrades': snapshot.docs.length,
            'byEvaluationType': byType,
            'overallAverage': count > 0 ? totalScore / count : 0.0,
            'lastUpdated': DateTime.now().toIso8601String(),
          };
        });
  }

  // ==================== RECHERCHE ====================

  /// ✅ Rechercher des notes par nom d'étudiant
  Future<List<GradeModel>> searchGradesByStudentName(String schoolId, String query) async {
    try {
      if (query.isEmpty) return [];
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .where('studentName', isGreaterThanOrEqualTo: query)
          .where('studentName', isLessThanOrEqualTo: query + '\uf8ff')
          .orderBy('studentName')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return GradeModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur recherche notes: $e');
      return [];
    }
  }

  /// ✅ Vérifier si une note existe pour un étudiant
  Future<bool> gradeExistsForStudent(String schoolId, int studentKeyHive, String subject) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .where('studentKeyHive', isEqualTo: studentKeyHive)
          .where('subject', isEqualTo: subject)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;

    } catch (e) {
      print('❌ Erreur vérification note: $e');
      return false;
    }
  }

  /// ✅ Récupérer les meilleures notes d'un étudiant
  Future<List<GradeModel>> getBestGrades(String schoolId, int studentKeyHive, {int limit = 5}) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .where('studentKeyHive', isEqualTo: studentKeyHive)
          .orderBy('score', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        return GradeModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération meilleures notes: $e');
      return [];
    }
  }
}
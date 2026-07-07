// lib/services/attendance_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/attendance_model.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  // ==================== CRUD PRÉSENCES ====================

  /// ✅ Créer une présence dans Firestore (sous-collection de l'école)
  Future<String> createAttendance(AttendanceModel attendance, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // Utiliser une sous-collection de l'école
      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .doc();

      // 🔥 Utiliser toFirestoreMap() du modèle
      final attendanceData = attendance.toFirestoreMap();
      
      // Ajouter les champs spécifiques au service
      attendanceData.addAll({
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isSynced': true,
      });

      await docRef.set(attendanceData);
      
      // Mettre à jour l'ID Firestore dans le modèle
      attendance.attendanceFirestoreId = docRef.id;
      
      print('✅ Présence créée dans Firestore: ${docRef.id}');
      return docRef.id;
      
    } catch (e) {
      print('❌ Erreur création présence Firestore: $e');
      throw e;
    }
  }

  /// ✅ Mettre à jour une présence dans Firestore
  Future<void> updateAttendance(String schoolId, String attendanceId, AttendanceModel attendance) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 🔥 Utiliser toFirestoreMap() du modèle
      final updateData = attendance.toFirestoreMap();
      
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
          .collection('attendances')
          .doc(attendanceId)
          .update(updateData);
          
      print('✅ Présence mise à jour dans Firestore: $attendanceId');
      
    } catch (e) {
      print('❌ Erreur mise à jour présence Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer une présence de Firestore
  Future<void> deleteAttendance(String schoolId, String attendanceId) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .doc(attendanceId)
          .delete();
          
      print('🗑️ Présence supprimée de Firestore: $attendanceId');
      
    } catch (e) {
      print('❌ Erreur suppression présence Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer toutes les présences d'une école
  Future<void> deleteAllAttendances(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Toutes les présences supprimées pour l\'école: $schoolId');
      
    } catch (e) {
      print('❌ Erreur suppression toutes les présences: $e');
      throw e;
    }
  }

  /// ✅ Supprimer les présences d'une classe
  Future<void> deleteAttendancesByClass(String schoolId, String classId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .where('classId', isEqualTo: classId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Présences supprimées pour la classe: $classId');
      
    } catch (e) {
      print('❌ Erreur suppression présences par classe: $e');
      throw e;
    }
  }

  /// ✅ Supprimer les présences d'un étudiant
  Future<void> deleteAttendancesByStudent(String schoolId, String studentId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .where('studentId', isEqualTo: studentId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Présences supprimées pour l\'étudiant: $studentId');
      
    } catch (e) {
      print('❌ Erreur suppression présences par étudiant: $e');
      throw e;
    }
  }

  // ==================== RÉCUPÉRATION DES PRÉSENCES ====================

  /// ✅ Récupérer toutes les présences d'une école
  Future<List<AttendanceModel>> getAttendancesBySchool(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .orderBy('date', descending: true)
          .get();

      // 🔥 Utiliser fromFirestore() du modèle
      return snapshot.docs.map((doc) {
        return AttendanceModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération présences par école: $e');
      return [];
    }
  }

  /// ✅ Récupérer les présences d'une classe
  Future<List<AttendanceModel>> getAttendancesByClass(String schoolId, String classId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .where('classId', isEqualTo: classId)
          .orderBy('date', descending: true)
          .get();

      // 🔥 Utiliser fromFirestore() du modèle
      return snapshot.docs.map((doc) {
        return AttendanceModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération présences par classe: $e');
      return [];
    }
  }

  /// ✅ Récupérer les présences d'un étudiant
  Future<List<AttendanceModel>> getAttendancesByStudent(String schoolId, String studentId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .where('studentId', isEqualTo: studentId)
          .orderBy('date', descending: true)
          .get();

      // 🔥 Utiliser fromFirestore() du modèle
      return snapshot.docs.map((doc) {
        return AttendanceModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération présences par étudiant: $e');
      return [];
    }
  }

  /// ✅ Récupérer les présences par date
  Future<List<AttendanceModel>> getAttendancesByDate(String schoolId, DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .where('date', isGreaterThanOrEqualTo: '$dateStr 00:00:00')
          .where('date', isLessThanOrEqualTo: '$dateStr 23:59:59')
          .get();

      // 🔥 Utiliser fromFirestore() du modèle
      return snapshot.docs.map((doc) {
        return AttendanceModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération présences par date: $e');
      return [];
    }
  }

  /// ✅ Récupérer les présences par statut
  Future<List<AttendanceModel>> getAttendancesByStatus(
    String schoolId, 
    String status
  ) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .where('status', isEqualTo: status)
          .orderBy('date', descending: true)
          .get();

      // 🔥 Utiliser fromFirestore() du modèle
      return snapshot.docs.map((doc) {
        return AttendanceModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération présences par statut: $e');
      return [];
    }
  }

  /// ✅ Récupérer les présences par cycle
  Future<List<AttendanceModel>> getAttendancesByCycle(
    String schoolId, 
    String cycleType
  ) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .where('classCycleType', isEqualTo: cycleType)
          .orderBy('date', descending: true)
          .get();

      // 🔥 Utiliser fromFirestore() du modèle
      return snapshot.docs.map((doc) {
        return AttendanceModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération présences par cycle: $e');
      return [];
    }
  }

  /// ✅ Récupérer les présences par section
  Future<List<AttendanceModel>> getAttendancesBySection(
    String schoolId, 
    String sectionId
  ) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .where('sectionId', isEqualTo: sectionId)
          .orderBy('date', descending: true)
          .get();

      // 🔥 Utiliser fromFirestore() du modèle
      return snapshot.docs.map((doc) {
        return AttendanceModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération présences par section: $e');
      return [];
    }
  }

  /// ✅ Récupérer une présence par ID
  Future<AttendanceModel?> getAttendanceById(String schoolId, String attendanceId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .doc(attendanceId)
          .get();
      
      if (!doc.exists) return null;
      
      // 🔥 Utiliser fromFirestore() du modèle
      return AttendanceModel.fromFirestore(doc.data()!, doc.id);
      
    } catch (e) {
      print('❌ Erreur récupération présence par ID: $e');
      return null;
    }
  }

  // ==================== ÉCOUTE EN TEMPS RÉEL ====================

  /// ✅ Écouter les présences d'une classe en temps réel
  Stream<List<AttendanceModel>> listenToAttendancesByClass(
    String schoolId, 
    String classId
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('attendances')
        .where('classId', isEqualTo: classId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          // 🔥 Utiliser fromFirestore() du modèle
          return snapshot.docs.map((doc) {
            return AttendanceModel.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  /// ✅ Écouter les présences d'un étudiant en temps réel
  Stream<List<AttendanceModel>> listenToAttendancesByStudent(
    String schoolId, 
    String studentId
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('attendances')
        .where('studentId', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          // 🔥 Utiliser fromFirestore() du modèle
          return snapshot.docs.map((doc) {
            return AttendanceModel.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  /// ✅ Écouter toutes les présences d'une école en temps réel
  Stream<List<AttendanceModel>> listenToAllAttendances(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('attendances')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          // 🔥 Utiliser fromFirestore() du modèle
          return snapshot.docs.map((doc) {
            return AttendanceModel.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  /// ✅ Écouter les présences par cycle en temps réel
  Stream<List<AttendanceModel>> listenToAttendancesByCycle(
    String schoolId, 
    String cycleType
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('attendances')
        .where('classCycleType', isEqualTo: cycleType)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return AttendanceModel.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  // ==================== SYNCHRONISATION ====================

  /// ✅ Synchroniser toutes les présences locales vers Firestore
  Future<void> syncAllAttendancesToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des présences vers Firestore...');
      final attendances = await _dbHelper.getAllAttendances();
      
      if (attendances.isEmpty) {
        print('📭 Aucune présence à synchroniser');
        return;
      }
      
      int syncedCount = 0;
      
      for (var attendance in attendances) {
        try {
          // Vérifier si la présence existe déjà
          final existing = await _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('attendances')
              .where('localKey', isEqualTo: attendance.key)
              .get();

          if (existing.docs.isEmpty) {
            await createAttendance(attendance, schoolId);
            syncedCount++;
          } else {
            // Mettre à jour si nécessaire
            final docId = existing.docs.first.id;
            attendance.attendanceFirestoreId = docId;
            await updateAttendance(schoolId, docId, attendance);
            syncedCount++;
          }
        } catch (e) {
          print('❌ Erreur synchronisation présence ${attendance.key}: $e');
        }
      }

      print('✅ Synchronisation terminée: $syncedCount/${attendances.length} présences');

    } catch (e) {
      print('❌ Erreur synchronisation présences: $e');
      throw e;
    }
  }

  /// ✅ Synchroniser les présences depuis Firestore vers local
  Future<void> syncAttendancesFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des présences depuis Firestore...');
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .get();

      int addedCount = 0;
      int updatedCount = 0;

      for (var doc in snapshot.docs) {
        // 🔥 Utiliser fromFirestore() du modèle
        final attendance = AttendanceModel.fromFirestore(doc.data(), doc.id);
        
        final existing = await _dbHelper.getAttendanceByKey(attendance.key);
        
        if (existing == null) {
          await _dbHelper.addAttendance(attendance);
          addedCount++;
        } else {
          // Mettre à jour l'ID Firestore
          attendance.attendanceFirestoreId = doc.id;
          await _dbHelper.updateAttendance(attendance);
          updatedCount++;
        }
      }

      print('✅ Synchronisation terminée: +$addedCount ajoutées, $updatedCount mises à jour');

    } catch (e) {
      print('❌ Erreur synchronisation présences depuis Firestore: $e');
      throw e;
    }
  }

  /// ✅ Synchronisation complète (bidirectionnelle)
  Future<void> syncAllAttendanceData(String schoolId) async {
    try {
      print('🔄 Synchronisation complète des présences...');
      await syncAllAttendancesToFirestore(schoolId);
      await syncAttendancesFromFirestore(schoolId);
      print('✅ Synchronisation complète des présences terminée');
    } catch (e) {
      print('❌ Erreur synchronisation complète: $e');
      throw e;
    }
  }

  // ==================== STATISTIQUES ====================

  /// ✅ Compter les présences par statut
  Future<Map<String, int>> countAttendancesByStatus(String schoolId) async {
    try {
      final Map<String, int> counts = {
        'present': 0,
        'absent': 0,
        'late': 0,
        'excused': 0,
        'all': 0,
      };
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .get();
      
      for (var doc in snapshot.docs) {
        final status = doc['status'] ?? 'present';
        counts[status] = (counts[status] ?? 0) + 1;
        counts['all'] = (counts['all'] ?? 0) + 1;
      }
      
      return counts;
      
    } catch (e) {
      print('❌ Erreur comptage présences par statut: $e');
      return {};
    }
  }

  /// ✅ Compter les présences par cycle
  Future<Map<String, int>> countAttendancesByCycle(String schoolId) async {
    try {
      final Map<String, int> counts = {
        'primaire': 0,
        'secondaire': 0,
      };
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .get();
      
      for (var doc in snapshot.docs) {
        final cycle = doc['classCycleType'] ?? 'primaire';
        counts[cycle] = (counts[cycle] ?? 0) + 1;
      }
      
      return counts;
      
    } catch (e) {
      print('❌ Erreur comptage présences par cycle: $e');
      return {};
    }
  }

  /// ✅ Calculer le taux de présence d'un étudiant
  Future<double> getStudentAttendanceRate(String schoolId, String studentId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .where('studentId', isEqualTo: studentId)
          .get();
      
      if (snapshot.docs.isEmpty) return 0.0;
      
      int total = snapshot.docs.length;
      int present = snapshot.docs.where((doc) => doc['status'] == 'present').length;
      
      return total > 0 ? (present / total) * 100 : 0.0;
      
    } catch (e) {
      print('❌ Erreur calcul taux présence: $e');
      return 0.0;
    }
  }

  /// ✅ Calculer le taux de présence d'une classe
  Future<double> getClassAttendanceRate(String schoolId, String classId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .where('classId', isEqualTo: classId)
          .get();
      
      if (snapshot.docs.isEmpty) return 0.0;
      
      int total = snapshot.docs.length;
      int present = snapshot.docs.where((doc) => doc['status'] == 'present').length;
      
      return total > 0 ? (present / total) * 100 : 0.0;
      
    } catch (e) {
      print('❌ Erreur calcul taux présence classe: $e');
      return 0.0;
    }
  }

  /// ✅ Obtenir les statistiques complètes
  Future<Map<String, dynamic>> getAttendanceStats(String schoolId) async {
    try {
      final byStatus = await countAttendancesByStatus(schoolId);
      final byCycle = await countAttendancesByCycle(schoolId);
      
      // Compter par classe
      final classesSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .get();
      
      final Map<String, int> byClass = {};
      final Map<String, int> byDay = {};
      
      for (var doc in classesSnapshot.docs) {
        final className = doc['className'] ?? 'Inconnu';
        byClass[className] = (byClass[className] ?? 0) + 1;
        
        final date = doc['date'] ?? '';
        final day = date.split(' ').first;
        byDay[day] = (byDay[day] ?? 0) + 1;
      }
      
      return {
        'byStatus': byStatus,
        'byCycle': byCycle,
        'byClass': byClass,
        'byDay': byDay,
        'total': classesSnapshot.docs.length,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      print('❌ Erreur statistiques présences: $e');
      return {};
    }
  }

  /// ✅ Écouter les statistiques en temps réel
  Stream<Map<String, dynamic>> listenToAttendanceStats(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('attendances')
        .snapshots()
        .map((snapshot) {
          final Map<String, int> byStatus = {
            'present': 0,
            'absent': 0,
            'late': 0,
            'excused': 0,
          };
          
          final Map<String, int> byCycle = {
            'primaire': 0,
            'secondaire': 0,
          };
          
          final Map<String, int> byClass = {};
          final Map<String, int> byDay = {};
          
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final status = data['status'] ?? 'present';
            byStatus[status] = (byStatus[status] ?? 0) + 1;
            
            final cycle = data['classCycleType'] ?? 'primaire';
            byCycle[cycle] = (byCycle[cycle] ?? 0) + 1;
            
            final className = data['className'] ?? 'Inconnu';
            byClass[className] = (byClass[className] ?? 0) + 1;
            
            final date = data['date'] ?? '';
            final day = date.split(' ').first;
            byDay[day] = (byDay[day] ?? 0) + 1;
          }
          
          return {
            'byStatus': byStatus,
            'byCycle': byCycle,
            'byClass': byClass,
            'byDay': byDay,
            'total': snapshot.docs.length,
            'lastUpdated': DateTime.now().toIso8601String(),
          };
        });
  }

  // ==================== MÉTHODES SUPPLÉMENTAIRES ====================

  /// ✅ Récupérer les présences d'une période
  Future<List<AttendanceModel>> getAttendancesByPeriod(
    String schoolId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final startStr = startDate.toIso8601String().split('T').first;
      final endStr = endDate.toIso8601String().split('T').first;
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .where('date', isGreaterThanOrEqualTo: '$startStr 00:00:00')
          .where('date', isLessThanOrEqualTo: '$endStr 23:59:59')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return AttendanceModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération présences par période: $e');
      return [];
    }
  }

  /// ✅ Récupérer les présences par étudiant et par date
  Future<List<AttendanceModel>> getAttendancesByStudentAndDate(
    String schoolId,
    String studentId,
    DateTime date,
  ) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .where('studentId', isEqualTo: studentId)
          .where('date', isGreaterThanOrEqualTo: '$dateStr 00:00:00')
          .where('date', isLessThanOrEqualTo: '$dateStr 23:59:59')
          .get();

      return snapshot.docs.map((doc) {
        return AttendanceModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération présences: $e');
      return [];
    }
  }

  /// ✅ Vérifier si une présence existe
  Future<bool> attendanceExists(String schoolId, String studentId, DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('attendances')
          .where('studentId', isEqualTo: studentId)
          .where('date', isGreaterThanOrEqualTo: '$dateStr 00:00:00')
          .where('date', isLessThanOrEqualTo: '$dateStr 23:59:59')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;

    } catch (e) {
      print('❌ Erreur vérification présence: $e');
      return false;
    }
  }
}
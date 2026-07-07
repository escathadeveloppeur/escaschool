// lib/services/schedule_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/schedule_model.dart';

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  // ==================== CRUD HORAIRES ====================

  /// ✅ Créer un horaire dans Firestore (sous-collection de l'école)
  Future<String> createSchedule(Map<String, dynamic> schedule, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 🔥 Utiliser une sous-collection de l'école
      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .doc();

      final scheduleData = {
        'professorId': schedule['professorId'],
        'professorFirestoreId': schedule['professorFirestoreId'],
        'classId': schedule['classId'],
        'classFirestoreId': schedule['classFirestoreId'],
        'className': schedule['className'],
        'dayOfWeek': schedule['dayOfWeek'],
        'startTime': schedule['startTime'],
        'endTime': schedule['endTime'],
        'subject': schedule['subject'],
        'room': schedule['room'],
        'localId': schedule['id'],
        'localKey': schedule['id']?.toString(),
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isSynced': true,
      };

      await docRef.set(scheduleData);
      
      // Mettre à jour l'ID Firestore dans le document local
      schedule['firestoreId'] = docRef.id;
      
      print('✅ Horaire créé dans Firestore: ${docRef.id}');
      return docRef.id;

    } catch (e) {
      print('❌ Erreur création horaire Firestore: $e');
      throw e;
    }
  }

  /// ✅ Mettre à jour un horaire dans Firestore
  Future<void> updateSchedule(String schoolId, String scheduleId, Map<String, dynamic> schedule) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final updateData = {
        'professorId': schedule['professorId'],
        'professorFirestoreId': schedule['professorFirestoreId'],
        'classId': schedule['classId'],
        'classFirestoreId': schedule['classFirestoreId'],
        'className': schedule['className'],
        'dayOfWeek': schedule['dayOfWeek'],
        'startTime': schedule['startTime'],
        'endTime': schedule['endTime'],
        'subject': schedule['subject'],
        'room': schedule['room'],
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      };

      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .doc(scheduleId)
          .update(updateData);
          
      print('✅ Horaire mis à jour dans Firestore: $scheduleId');

    } catch (e) {
      print('❌ Erreur mise à jour horaire Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer un horaire de Firestore
  Future<void> deleteSchedule(String schoolId, String scheduleId) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .doc(scheduleId)
          .delete();
          
      print('🗑️ Horaire supprimé de Firestore: $scheduleId');

    } catch (e) {
      print('❌ Erreur suppression horaire Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer tous les horaires d'une école
  Future<void> deleteAllSchedules(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Tous les horaires supprimés pour l\'école: $schoolId');

    } catch (e) {
      print('❌ Erreur suppression tous les horaires: $e');
      throw e;
    }
  }

  /// ✅ Supprimer les horaires d'une classe
  Future<void> deleteSchedulesByClass(String schoolId, String classFirestoreId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .where('classFirestoreId', isEqualTo: classFirestoreId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Horaires supprimés pour la classe: $classFirestoreId');

    } catch (e) {
      print('❌ Erreur suppression horaires par classe: $e');
      throw e;
    }
  }

  /// ✅ Supprimer les horaires d'un professeur
  Future<void> deleteSchedulesByProfessor(String schoolId, String professorFirestoreId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .where('professorFirestoreId', isEqualTo: professorFirestoreId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Horaires supprimés pour le professeur: $professorFirestoreId');

    } catch (e) {
      print('❌ Erreur suppression horaires par professeur: $e');
      throw e;
    }
  }

  // ==================== RÉCUPÉRATION DES HORAIRES ====================

  /// ✅ Récupérer tous les horaires d'une école
  Future<List<Map<String, dynamic>>> getSchedulesBySchool(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .orderBy('dayOfWeek')
          .orderBy('startTime')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'firestoreId': doc.id,
          ...data,
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération horaires par école: $e');
      return [];
    }
  }

  /// ✅ Récupérer les horaires d'une classe
  Future<List<Map<String, dynamic>>> getSchedulesByClass(String schoolId, String classFirestoreId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .where('classFirestoreId', isEqualTo: classFirestoreId)
          .orderBy('dayOfWeek')
          .orderBy('startTime')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'firestoreId': doc.id,
          ...data,
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération horaires par classe: $e');
      return [];
    }
  }

  /// ✅ Récupérer les horaires d'un professeur
  Future<List<Map<String, dynamic>>> getSchedulesByProfessor(String schoolId, String professorFirestoreId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .where('professorFirestoreId', isEqualTo: professorFirestoreId)
          .orderBy('dayOfWeek')
          .orderBy('startTime')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'firestoreId': doc.id,
          ...data,
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération horaires par professeur: $e');
      return [];
    }
  }

  /// ✅ Récupérer les horaires par jour
  Future<List<Map<String, dynamic>>> getSchedulesByDay(String schoolId, int dayOfWeek) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .where('dayOfWeek', isEqualTo: dayOfWeek)
          .orderBy('startTime')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'firestoreId': doc.id,
          ...data,
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération horaires par jour: $e');
      return [];
    }
  }

  /// ✅ Récupérer un horaire par ID
  Future<Map<String, dynamic>?> getScheduleById(String schoolId, String scheduleId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .doc(scheduleId)
          .get();
      
      if (!doc.exists) return null;
      
      final data = doc.data();
      return {
        'firestoreId': doc.id,
        ...data!,
      };

    } catch (e) {
      print('❌ Erreur récupération horaire par ID: $e');
      return null;
    }
  }

  // ==================== ÉCOUTE EN TEMPS RÉEL ====================

  /// ✅ Écouter les horaires d'une école en temps réel
  Stream<List<Map<String, dynamic>>> listenToSchedules(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('schedules')
        .orderBy('dayOfWeek')
        .orderBy('startTime')
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

  /// ✅ Écouter les horaires d'une classe en temps réel
  Stream<List<Map<String, dynamic>>> listenToSchedulesByClass(String schoolId, String classFirestoreId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('schedules')
        .where('classFirestoreId', isEqualTo: classFirestoreId)
        .orderBy('dayOfWeek')
        .orderBy('startTime')
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

  /// ✅ Écouter les horaires d'un professeur en temps réel
  Stream<List<Map<String, dynamic>>> listenToSchedulesByProfessor(String schoolId, String professorFirestoreId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('schedules')
        .where('professorFirestoreId', isEqualTo: professorFirestoreId)
        .orderBy('dayOfWeek')
        .orderBy('startTime')
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

  /// ✅ Synchroniser tous les horaires locaux vers Firestore
  Future<void> syncAllSchedulesToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des horaires vers Firestore...');
      final schedules = await _dbHelper.getAllSchedules();
      
      if (schedules.isEmpty) {
        print('📭 Aucun horaire à synchroniser');
        return;
      }
      
      int syncedCount = 0;
      
      for (var schedule in schedules) {
        try {
          final existing = await _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('schedules')
              .where('localId', isEqualTo: schedule['id'])
              .get();

          if (existing.docs.isEmpty) {
            await createSchedule(schedule, schoolId);
            syncedCount++;
          } else {
            final firestoreId = existing.docs.first.id;
            schedule['firestoreId'] = firestoreId;
            await updateSchedule(schoolId, firestoreId, schedule);
            syncedCount++;
          }
        } catch (e) {
          print('❌ Erreur synchronisation horaire ${schedule['id']}: $e');
        }
      }

      print('✅ Synchronisation terminée: $syncedCount/${schedules.length} horaires');

    } catch (e) {
      print('❌ Erreur synchronisation horaires: $e');
      throw e;
    }
  }

  /// ✅ Synchroniser les horaires depuis Firestore vers local
  Future<void> syncSchedulesFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des horaires depuis Firestore...');
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .get();

      if (snapshot.docs.isEmpty) {
        print('📭 Aucun horaire à synchroniser depuis Firestore');
        return;
      }

      int addedCount = 0;
      int updatedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          
          final schedule = {
            'id': data['localId'],
            'firestoreId': doc.id,
            'professorId': data['professorId'] ?? 0,
            'professorFirestoreId': data['professorFirestoreId'],
            'classId': data['classId'] ?? 0,
            'classFirestoreId': data['classFirestoreId'],
            'className': data['className'] ?? '',
            'dayOfWeek': data['dayOfWeek'] ?? 0,
            'startTime': data['startTime'] ?? '',
            'endTime': data['endTime'] ?? '',
            'subject': data['subject'] ?? '',
            'room': data['room'] ?? '',
          };
          
          final existing = await _dbHelper.getScheduleByKey(schedule['id']);
          
          if (existing == null) {
            await _dbHelper.addSchedule(schedule);
            addedCount++;
          } else {
            await _dbHelper.updateScheduleByKey(schedule['id'], schedule);
            updatedCount++;
          }
        } catch (e) {
          print('  ⚠️ Erreur traitement horaire ${doc.id}: $e');
        }
      }

      print('✅ Synchronisation terminée: +$addedCount ajoutés, $updatedCount mis à jour');

    } catch (e) {
      print('❌ Erreur synchronisation horaires depuis Firestore: $e');
      throw e;
    }
  }

  /// ✅ Synchronisation complète (bidirectionnelle)
  Future<void> syncAllScheduleData(String schoolId) async {
    try {
      print('🔄 Synchronisation complète des horaires...');
      await syncAllSchedulesToFirestore(schoolId);
      await syncSchedulesFromFirestore(schoolId);
      print('✅ Synchronisation complète des horaires terminée');
    } catch (e) {
      print('❌ Erreur synchronisation complète: $e');
      throw e;
    }
  }

  // ==================== STATISTIQUES ====================

  /// ✅ Compter les horaires par jour
  Future<Map<int, int>> countSchedulesByDay(String schoolId) async {
    try {
      final Map<int, int> counts = {};
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .get();
      
      for (var doc in snapshot.docs) {
        final day = doc['dayOfWeek'] ?? 0;
        counts[day] = (counts[day] ?? 0) + 1;
      }
      
      return counts;

    } catch (e) {
      print('❌ Erreur comptage horaires par jour: $e');
      return {};
    }
  }

  /// ✅ Compter les horaires par classe
  Future<Map<String, int>> countSchedulesByClass(String schoolId) async {
    try {
      final Map<String, int> counts = {};
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .get();
      
      for (var doc in snapshot.docs) {
        final className = doc['className'] ?? 'unknown';
        counts[className] = (counts[className] ?? 0) + 1;
      }
      
      return counts;

    } catch (e) {
      print('❌ Erreur comptage horaires par classe: $e');
      return {};
    }
  }

  /// ✅ Obtenir les statistiques complètes
  Future<Map<String, dynamic>> getScheduleStats(String schoolId) async {
    try {
      final byDay = await countSchedulesByDay(schoolId);
      final byClass = await countSchedulesByClass(schoolId);
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .get();
      
      return {
        'totalSchedules': snapshot.docs.length,
        'byDay': byDay,
        'byClass': byClass,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

    } catch (e) {
      print('❌ Erreur statistiques horaires: $e');
      return {};
    }
  }

  /// ✅ Écouter les statistiques en temps réel
  Stream<Map<String, dynamic>> listenToScheduleStats(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('schedules')
        .snapshots()
        .map((snapshot) {
          final Map<int, int> byDay = {};
          final Map<String, int> byClass = {};
          
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final day = data['dayOfWeek'] ?? 0;
            byDay[day] = (byDay[day] ?? 0) + 1;
            
            final className = data['className'] ?? 'unknown';
            byClass[className] = (byClass[className] ?? 0) + 1;
          }
          
          return {
            'totalSchedules': snapshot.docs.length,
            'byDay': byDay,
            'byClass': byClass,
            'lastUpdated': DateTime.now().toIso8601String(),
          };
        });
  }

  // ==================== RECHERCHE ====================

  /// ✅ Rechercher des horaires par matière
  Future<List<Map<String, dynamic>>> searchSchedulesBySubject(String schoolId, String query) async {
    try {
      if (query.isEmpty) return [];
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .where('subject', isGreaterThanOrEqualTo: query)
          .where('subject', isLessThanOrEqualTo: query + '\uf8ff')
          .orderBy('subject')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'firestoreId': doc.id,
          ...data,
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur recherche horaires par matière: $e');
      return [];
    }
  }

  /// ✅ Rechercher des horaires par professeur
  Future<List<Map<String, dynamic>>> searchSchedulesByProfessorName(
    String schoolId, 
    String professorId
  ) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .where('professorId', isEqualTo: professorId)
          .orderBy('dayOfWeek')
          .orderBy('startTime')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'firestoreId': doc.id,
          ...data,
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur recherche horaires par professeur: $e');
      return [];
    }
  }

  /// ✅ Vérifier si un horaire existe déjà
  Future<bool> scheduleExists(
    String schoolId, 
    String classFirestoreId, 
    int dayOfWeek, 
    String startTime
  ) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('schedules')
          .where('classFirestoreId', isEqualTo: classFirestoreId)
          .where('dayOfWeek', isEqualTo: dayOfWeek)
          .where('startTime', isEqualTo: startTime)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;

    } catch (e) {
      print('❌ Erreur vérification horaire: $e');
      return false;
    }
  }
}
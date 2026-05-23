// lib/services/schedule_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/schedule_model.dart';

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  /// Créer un horaire dans Firestore
  Future<String> createSchedule(Map<String, dynamic> schedule, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final docRef = _firestore.collection('schedules').doc();
      final scheduleData = {
        'professorId': schedule['professorId'],
        'classId': schedule['classId'],
        'className': schedule['className'],
        'dayOfWeek': schedule['dayOfWeek'],
        'startTime': schedule['startTime'],
        'endTime': schedule['endTime'],
        'subject': schedule['subject'],
        'room': schedule['room'],
        'schoolId': schoolId,
        'localId': schedule['id'],
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(scheduleData);
      print('✅ Horaire créé dans Firestore: ${docRef.id}');
      return docRef.id;

    } catch (e) {
      print('❌ Erreur création horaire Firestore: $e');
      throw e;
    }
  }

  /// Synchroniser tous les horaires locaux vers Firestore
  Future<void> syncAllSchedulesToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des horaires vers Firestore...');
      final schedules = await _dbHelper.getAllSchedules();
      
      for (var schedule in schedules) {
        final existing = await _firestore
            .collection('schedules')
            .where('localId', isEqualTo: schedule['id'])
            .get();

        if (existing.docs.isEmpty) {
          await createSchedule(schedule, schoolId);
        }
      }

      print('✅ Synchronisation des horaires terminée: ${schedules.length}');

    } catch (e) {
      print('❌ Erreur synchronisation horaires: $e');
      throw e;
    }
  }

  /// Synchroniser les horaires depuis Firestore vers Hive
  Future<void> syncSchedulesFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des horaires depuis Firestore...');
      
      final snapshot = await _firestore
          .collection('schedules')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        final schedule = {
          'id': data['localId'],
          'professorId': data['professorId'] ?? 0,
          'classId': data['classId'] ?? 0,
          'className': data['className'] ?? '',
          'dayOfWeek': data['dayOfWeek'] ?? 0,
          'startTime': data['startTime'] ?? '',
          'endTime': data['endTime'] ?? '',
          'subject': data['subject'] ?? '',
          'room': data['room'] ?? '',
        };
        
        // Vérifier si l'horaire existe déjà localement
        final existing = await _dbHelper.getScheduleByKey(schedule['id']);
        if (existing == null) {
          await _dbHelper.addSchedule(schedule);
          print('  ✅ Horaire ajouté localement: ${schedule['subject']} - ${schedule['className']}');
        }
      }

      print('✅ Synchronisation des horaires depuis Firestore terminée: ${snapshot.docs.length} documents');
    } catch (e) {
      print('❌ Erreur synchronisation horaires depuis Firestore: $e');
      throw e;
    }
  }
}
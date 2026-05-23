// lib/services/attendance_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/attendance_model.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  Future<String> createAttendance(AttendanceModel attendance, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final docRef = _firestore.collection('attendances').doc();
      final attendanceData = {
        'studentName': attendance.studentName,
        'studentId': attendance.studentId,
        'className': attendance.className,
        'date': attendance.date.toIso8601String(),
        'status': attendance.status,
        'subject': attendance.subject,
        'justification': attendance.reason,
        'schoolId': schoolId,
        'localKey': attendance.key,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(attendanceData);
      print('✅ Présence créée dans Firestore: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Erreur création présence Firestore: $e');
      throw e;
    }
  }

  Future<void> syncAllAttendancesToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des présences vers Firestore...');
      final attendances = await _dbHelper.getAllAttendances();
      
      for (var attendance in attendances) {
        final existing = await _firestore
            .collection('attendances')
            .where('localKey', isEqualTo: attendance.key)
            .get();

        if (existing.docs.isEmpty) {
          await createAttendance(attendance, schoolId);
        }
      }

      print('✅ Synchronisation des présences terminée: ${attendances.length}');
    } catch (e) {
      print('❌ Erreur synchronisation présences: $e');
      throw e;
    }
  }

  Future<void> syncAttendancesFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des présences depuis Firestore...');
      final snapshot = await _firestore
          .collection('attendances')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final attendance = AttendanceModel(
          studentName: data['studentName'] ?? '',
          studentId: data['studentId'],
          className: data['className'] ?? '',
          date: data['date'] != null ? DateTime.parse(data['date']) : DateTime.now(),
          status: data['status'] ?? 'present',
          subject: data['subject'] ?? '',
          reason: data['justification'],
          studentKeyHive: data [''],
          
        );
        
        final existing = await _dbHelper.getAttendanceByKey(attendance.key);
        if (existing == null) {
          await _dbHelper.addAttendance(attendance);
        }
      }

      print('✅ Synchronisation des présences depuis Firestore terminée: ${snapshot.docs.length}');
    } catch (e) {
      print('❌ Erreur synchronisation présences depuis Firestore: $e');
    }
  }
}
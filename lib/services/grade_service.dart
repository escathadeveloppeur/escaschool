// lib/services/grade_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/grade_model.dart';

class GradeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  Future<String> createGrade(GradeModel grade, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final docRef = _firestore.collection('grades').doc();
      final gradeData = {
        'studentKeyHive': grade.studentKeyHive,
        'studentName': grade.studentName,
        'className': grade.className,
        'subject': grade.subject,
        'evaluationType': grade.evaluationType,
        'score': grade.score,
        'maxScore': grade.maxScore,
        'date': grade.date.toIso8601String(),
        'coefficient': grade.coefficient,
        'comments': grade.comments,
        'schoolId': schoolId,
        'localKey': grade.key,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(gradeData);
      print('✅ Note créée dans Firestore: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Erreur création note Firestore: $e');
      throw e;
    }
  }

  Future<void> syncAllGradesToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des notes vers Firestore...');
      final grades = await _dbHelper.getAllGrades();
      
      for (var grade in grades) {
        final existing = await _firestore
            .collection('grades')
            .where('localKey', isEqualTo: grade.key)
            .get();

        if (existing.docs.isEmpty) {
          await createGrade(grade, schoolId);
        }
      }

      print('✅ Synchronisation des notes terminée: ${grades.length}');
    } catch (e) {
      print('❌ Erreur synchronisation notes: $e');
      throw e;
    }
  }

  Future<void> syncGradesFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des notes depuis Firestore...');
      final snapshot = await _firestore
          .collection('grades')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        final grade = GradeModel(
          studentKeyHive: data['studentKeyHive'] ?? 0,
          studentName: data['studentName'] ?? '',
          className: data['className'] ?? '',
          subject: data['subject'] ?? '',
          evaluationType: data['evaluationType'] ?? 'Devoir',
          score: (data['score'] ?? 0).toDouble(),
          maxScore: (data['maxScore'] ?? 20).toDouble(),
          date: data['date'] != null ? DateTime.parse(data['date']) : DateTime.now(),
          coefficient: (data['coefficient'] ?? 1).toDouble(),
          comments: data['comments'],
        );
        
        final existing = await _dbHelper.getGradeByKey(data['localKey']);
        if (existing == null) {
          await _dbHelper.addGrade(grade);
        }
      }

      print('✅ Synchronisation des notes depuis Firestore terminée: ${snapshot.docs.length}');
    } catch (e) {
      print('❌ Erreur synchronisation notes depuis Firestore: $e');
    }
  }
}
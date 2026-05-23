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

  Future<String> createExam(OnlineExamModel exam, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final docRef = _firestore.collection('online_exams').doc();
      final examData = {
        'id': exam.id,
        'title': exam.title,
        'description': exam.description,
        'subject': exam.subject,
        'className': exam.className,
        'classId': exam.classId,
        'professorId': exam.professorId,
        'startDate': exam.startDate.toIso8601String(),
        'endDate': exam.endDate.toIso8601String(),
        'duration': exam.duration,
        'totalPoints': exam.totalPoints,
        'questions': exam.questions,
        'status': exam.status,
        'createdAt': exam.createdAt.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'schoolId': schoolId,
        'createdBy': user.uid,
        'firestoreCreatedAt': FieldValue.serverTimestamp(),
        'firestoreUpdatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(examData);
      print('✅ Examen créé dans Firestore: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Erreur création examen Firestore: $e');
      throw e;
    }
  }

  Future<void> updateExam(OnlineExamModel exam, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final existing = await _firestore
          .collection('online_exams')
          .where('id', isEqualTo: exam.id)
          .where('schoolId', isEqualTo: schoolId)
          .get();

      if (existing.docs.isNotEmpty) {
        final docId = existing.docs.first.id;
        final updateData = {
          'title': exam.title,
          'description': exam.description,
          'subject': exam.subject,
          'className': exam.className,
          'classId': exam.classId,
          'startDate': exam.startDate.toIso8601String(),
          'endDate': exam.endDate.toIso8601String(),
          'duration': exam.duration,
          'totalPoints': exam.totalPoints,
          'questions': exam.questions,
          'status': exam.status,
          'updatedAt': DateTime.now().toIso8601String(),
          'firestoreUpdatedAt': FieldValue.serverTimestamp(),
        };
        await _firestore.collection('online_exams').doc(docId).update(updateData);
        print('✅ Examen mis à jour dans Firestore: $docId');
      } else {
        await createExam(exam, schoolId);
      }
    } catch (e) {
      print('❌ Erreur mise à jour examen Firestore: $e');
      throw e;
    }
  }

  Future<void> deleteExam(int examId, String schoolId) async {
    try {
      final existing = await _firestore
          .collection('online_exams')
          .where('id', isEqualTo: examId)
          .where('schoolId', isEqualTo: schoolId)
          .get();

      for (var doc in existing.docs) {
        await _firestore.collection('online_exams').doc(doc.id).delete();
        print('🗑️ Examen supprimé de Firestore: ${doc.id}');
      }
    } catch (e) {
      print('❌ Erreur suppression examen Firestore: $e');
      throw e;
    }
  }

  Future<List<OnlineExamModel>> getExamsFromFirestore(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('online_exams')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      final exams = snapshot.docs.map((doc) {
        final data = doc.data();
        return OnlineExamModel(
          id: data['id'] ?? 0,
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          subject: data['subject'] ?? '',
          className: data['className'] ?? '',
          classId: data['classId'] ?? 0,
          professorId: data['professorId'] ?? 0,
          startDate: data['startDate'] != null ? DateTime.parse(data['startDate']) : DateTime.now(),
          endDate: data['endDate'] != null ? DateTime.parse(data['endDate']) : DateTime.now(),
          duration: data['duration'] ?? 60,
          totalPoints: data['totalPoints'] ?? 0,
          questions: List<Map<String, dynamic>>.from(data['questions'] ?? []),
          status: data['status'] ?? 'upcoming',
          createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt']) : DateTime.now(),
        );
      }).toList();

      print('📥 Examens récupérés depuis Firestore: ${exams.length}');
      return exams;
    } catch (e) {
      print('❌ Erreur récupération examens Firestore: $e');
      return [];
    }
  }

  Future<void> syncAllExamsToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des examens vers Firestore...');
      final exams = await _dbHelper.getAllOnlineExams();
      
      for (var exam in exams) {
        final existing = await _firestore
            .collection('online_exams')
            .where('id', isEqualTo: exam.id)
            .where('schoolId', isEqualTo: schoolId)
            .get();

        if (existing.docs.isEmpty) {
          await createExam(exam, schoolId);
        } else {
          await updateExam(exam, schoolId);
        }
      }

      print('✅ Synchronisation des examens terminée: ${exams.length}');
    } catch (e) {
      print('❌ Erreur synchronisation examens: $e');
      throw e;
    }
  }

  Future<void> syncExamsFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des examens depuis Firestore...');
      final firestoreExams = await getExamsFromFirestore(schoolId);
      
      for (var exam in firestoreExams) {
        final existing = await _dbHelper.getOnlineExamById(exam.id);
        if (existing == null) {
          await _dbHelper.addOnlineExam(exam);
          print('  ✅ Examen ajouté localement: ${exam.title}');
        } else if (exam.startDate != existing.startDate || exam.endDate != existing.endDate) {
          await _dbHelper.updateOnlineExam(exam);
          print('  🔄 Examen mis à jour localement: ${exam.title}');
        }
      }

      print('✅ Synchronisation des examens depuis Firestore terminée: ${firestoreExams.length}');
    } catch (e) {
      print('❌ Erreur synchronisation examens depuis Firestore: $e');
    }
  }



// Dans lib/services/online_exam_service.dart, ajoutez cette méthode :

Future<void> syncExamResultToFirestore(ExamResultModel result, String schoolId) async {
  try {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final docRef = _firestore.collection('exam_results').doc();
    final resultData = {
      'examId': result.examId,
      'studentId': result.studentId,
      'studentName': result.studentName,
      'score': result.score,
      'totalPoints': result.totalPoints,
      'answers': result.answers,
      'submittedAt': result.submittedAt.toIso8601String(),
      'isGraded': result.isGraded,
      'percentage': result.percentage,
      'schoolId': schoolId,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
    };

    await docRef.set(resultData);
    print('✅ Résultat d\'examen synchronisé dans Firestore: ${docRef.id}');
  } catch (e) {
    print('❌ Erreur synchronisation résultat examen Firestore: $e');
    throw e;
  }
}

Future<void> syncAllExamResultsToFirestore(String schoolId) async {
  try {
    print('🔄 Synchronisation des résultats d\'examen vers Firestore...');
    final results = await _dbHelper.getAllExamResults();
    
    for (var result in results) {
      final existing = await _firestore
          .collection('exam_results')
          .where('examId', isEqualTo: result.examId)
          .where('studentId', isEqualTo: result.studentId)
          .get();

      if (existing.docs.isEmpty) {
        await syncExamResultToFirestore(result, schoolId);
      }
    }

    print('✅ Synchronisation des résultats d\'examen terminée: ${results.length}');
  } catch (e) {
    print('❌ Erreur synchronisation résultats examen: $e');
    throw e;
  }
}}

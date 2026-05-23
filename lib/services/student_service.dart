// lib/services/student_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/student_model.dart';

class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  Future<String> createStudent(StudentModel student, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final docRef = _firestore.collection('students').doc();
      final studentData = {
        'fullName': student.fullName,
        'className': student.className,
        'birthDate': student.birthDate,
        'birthPlace': student.birthPlace,
        'fatherName': student.fatherName,
        'motherName': student.motherName,
        'parentPhone': student.parentPhone,
        'address': student.address,
        'documentsVerified': student.documentsVerified,
        'userId': student.userId,
        'parentUserId': student.parentUserId,
        'parentRelation': student.parentRelation,
        'schoolId': schoolId,
        'localKey': student.key,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(studentData);
      print('✅ Étudiant créé dans Firestore: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Erreur création étudiant Firestore: $e');
      throw e;
    }
  }

  Future<void> syncAllStudentsToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des étudiants vers Firestore...');
      final students = await _dbHelper.getAllStudents();
      
      for (var student in students) {
        final existing = await _firestore
            .collection('students')
            .where('localKey', isEqualTo: student.key)
            .get();

        if (existing.docs.isEmpty) {
          await createStudent(student, schoolId);
        }
      }

      print('✅ Synchronisation des étudiants terminée: ${students.length}');
    } catch (e) {
      print('❌ Erreur synchronisation étudiants: $e');
      throw e;
    }
  }

  Future<void> syncStudentsFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des étudiants depuis Firestore...');
      final snapshot = await _firestore
          .collection('students')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final student = StudentModel(
          fullName: data['fullName'] ?? '',
          className: data['className'] ?? '',
          birthDate: data['birthDate'] ?? '',
          birthPlace: data['birthPlace'] ?? '',
          fatherName: data['fatherName'] ?? '',
          motherName: data['motherName'] ?? '',
          parentPhone: data['parentPhone'] ?? '',
          address: data['address'] ?? '',
          documentsVerified: data['documentsVerified'] ?? 0,
          userId: data['userId'],
          parentUserId: data['parentUserId'],
          parentRelation: data['parentRelation'],
          schoolId: data['schoolId'],
        );
        
        final existing = await _dbHelper.getStudentByKey(data['localKey']);
        if (existing == null) {
          await _dbHelper.addStudent(student);
        }
      }

      print('✅ Synchronisation des étudiants depuis Firestore terminée: ${snapshot.docs.length}');
    } catch (e) {
      print('❌ Erreur synchronisation étudiants depuis Firestore: $e');
    }
  }
}
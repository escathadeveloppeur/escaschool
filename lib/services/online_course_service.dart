// lib/services/online_course_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/online_course_model.dart';

class OnlineCourseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  Future<String> createCourse(OnlineCourseModel course, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final docRef = _firestore.collection('online_courses').doc();
      final courseData = {
        'id': course.id,
        'title': course.title,
        'description': course.description,
        'subject': course.subject,
        'className': course.className,
        'classId': course.classId,
        'professorId': course.professorId,
        'chapters': course.chapters,
        'resources': course.resources,
        'createdAt': course.createdAt.toIso8601String(),
        'updatedAt': course.updatedAt.toIso8601String(),
        'schoolId': schoolId,
        'createdBy': user.uid,
        'firestoreCreatedAt': FieldValue.serverTimestamp(),
        'firestoreUpdatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(courseData);
      print('✅ Cours créé dans Firestore: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Erreur création cours Firestore: $e');
      throw e;
    }
  }

  Future<void> updateCourse(OnlineCourseModel course, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final existing = await _firestore
          .collection('online_courses')
          .where('id', isEqualTo: course.id)
          .where('schoolId', isEqualTo: schoolId)
          .get();

      if (existing.docs.isNotEmpty) {
        final docId = existing.docs.first.id;
        final updateData = {
          'title': course.title,
          'description': course.description,
          'subject': course.subject,
          'className': course.className,
          'classId': course.classId,
          'chapters': course.chapters,
          'resources': course.resources,
          'updatedAt': course.updatedAt.toIso8601String(),
          'firestoreUpdatedAt': FieldValue.serverTimestamp(),
        };
        await _firestore.collection('online_courses').doc(docId).update(updateData);
        print('✅ Cours mis à jour dans Firestore: $docId');
      } else {
        await createCourse(course, schoolId);
      }
    } catch (e) {
      print('❌ Erreur mise à jour cours Firestore: $e');
      throw e;
    }
  }

  Future<void> deleteCourse(int courseId, String schoolId) async {
    try {
      final existing = await _firestore
          .collection('online_courses')
          .where('id', isEqualTo: courseId)
          .where('schoolId', isEqualTo: schoolId)
          .get();

      for (var doc in existing.docs) {
        await _firestore.collection('online_courses').doc(doc.id).delete();
        print('🗑️ Cours supprimé de Firestore: ${doc.id}');
      }
    } catch (e) {
      print('❌ Erreur suppression cours Firestore: $e');
      throw e;
    }
  }

  Future<List<OnlineCourseModel>> getCoursesFromFirestore(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('online_courses')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      final courses = snapshot.docs.map((doc) {
        final data = doc.data();
        return OnlineCourseModel(
          id: data['id'] ?? 0,
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          subject: data['subject'] ?? '',
          className: data['className'] ?? '',
          classId: data['classId'] ?? 0,
          professorId: data['professorId'] ?? 0,
          chapters: List<Map<String, dynamic>>.from(data['chapters'] ?? []),
          resources: List<Map<String, dynamic>>.from(data['resources'] ?? []),
          createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt']) : DateTime.now(),
          updatedAt: data['updatedAt'] != null ? DateTime.parse(data['updatedAt']) : DateTime.now(),
        );
      }).toList();

      print('📥 Cours récupérés depuis Firestore: ${courses.length}');
      return courses;
    } catch (e) {
      print('❌ Erreur récupération cours Firestore: $e');
      return [];
    }
  }

  Future<void> syncAllCoursesToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des cours vers Firestore...');
      final courses = await _dbHelper.getAllOnlineCourses();
      
      for (var course in courses) {
        final existing = await _firestore
            .collection('online_courses')
            .where('id', isEqualTo: course.id)
            .where('schoolId', isEqualTo: schoolId)
            .get();

        if (existing.docs.isEmpty) {
          await createCourse(course, schoolId);
        } else {
          await updateCourse(course, schoolId);
        }
      }

      print('✅ Synchronisation des cours terminée: ${courses.length}');
    } catch (e) {
      print('❌ Erreur synchronisation cours: $e');
      throw e;
    }
  }

  Future<void> syncCoursesFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des cours depuis Firestore...');
      final firestoreCourses = await getCoursesFromFirestore(schoolId);
      
      for (var course in firestoreCourses) {
        final existing = await _dbHelper.getOnlineCourseById(course.id);
        if (existing == null) {
          await _dbHelper.addOnlineCourse(course);
          print('  ✅ Cours ajouté localement: ${course.title}');
        } else if (course.updatedAt.isAfter(existing.updatedAt)) {
          await _dbHelper.updateOnlineCourse(course);
          print('  🔄 Cours mis à jour localement: ${course.title}');
        }
      }

      print('✅ Synchronisation des cours depuis Firestore terminée: ${firestoreCourses.length}');
    } catch (e) {
      print('❌ Erreur synchronisation cours depuis Firestore: $e');
    }
  }
}
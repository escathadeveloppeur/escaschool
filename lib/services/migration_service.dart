// lib/services/migration_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
class MigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> migrateStudentsToClasses() async {
    int total = 0;
    int migrated = 0;
    String error = '';

    try {
      final studentsSnapshot = await _firestore.collection('students').get();
      total = studentsSnapshot.docs.length;
      
      if (total == 0) {
        return {'success': true, 'total': 0, 'migrated': 0, 'message': 'Aucun étudiant à migrer'};
      }

      final Map<String, List<Map<String, dynamic>>> studentsByClass = {};

      for (var doc in studentsSnapshot.docs) {
        final data = doc.data();
        final classId = data['classFirestoreId'];
        
        if (classId != null && classId.isNotEmpty) {
          if (!studentsByClass.containsKey(classId)) {
            studentsByClass[classId] = [];
          }
          
          studentsByClass[classId]!.add({
            'studentId': doc.id,
            'fullName': data['fullName'] ?? '',
            'className': data['className'] ?? '',
            'gender': data['gender'] ?? 'Masculin',
            'birthDate': data['birthDate'] ?? '',
            'birthPlace': data['birthPlace'] ?? '',
            'fatherName': data['fatherName'] ?? '',
            'motherName': data['motherName'] ?? '',
            'parentPhone': data['parentPhone'] ?? '',
            'address': data['address'] ?? '',
            'documentsVerified': data['documentsVerified'] ?? false,
            'userId': data['userId'],
            'userEmail': data['userEmail'],
            'parentUserId': data['parentUserId'],
            'parentEmail': data['parentEmail'],
            'parentRelation': data['parentRelation'],
            'schoolId': data['schoolId'],
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      for (var entry in studentsByClass.entries) {
        final classRef = _firestore.collection('classes').doc(entry.key);
        await classRef.update({
          'students': FieldValue.arrayUnion(entry.value)
        });
        migrated += entry.value.length;
      }

      return {'success': true, 'total': total, 'migrated': migrated, 'message': 'Migration réussie'};
    } catch (e) {
      return {'success': false, 'total': total, 'migrated': migrated, 'message': 'Erreur: $e'};
    }
  }

  Future<Map<String, dynamic>> checkMigrationStatus() async {
    final snapshot = await _firestore.collection('students').limit(1).get();
    final hasStudents = snapshot.docs.isNotEmpty;
    
    if (!hasStudents) {
      return {'needsMigration': false, 'count': 0, 'message': 'Aucun étudiant à migrer'};
    }
    
    final allSnapshot = await _firestore.collection('students').get();
    return {'needsMigration': true, 'count': allSnapshot.docs.length, 'message': '${allSnapshot.docs.length} étudiants à migrer'};
  }
  Future<Map<String, dynamic>> runOnce() async {
  final prefs = await SharedPreferences.getInstance();
  final hasRun = prefs.getBool('migration_done') ?? false;
  
  if (hasRun) {
    return {'success': true, 'migrated': 0, 'message': 'Migration déjà effectuée'};
  }

  final result = await migrateStudentsToClasses();
  
  if (result['success']) {
    await prefs.setBool('migration_done', true);
  }
  
  return result;
}
}
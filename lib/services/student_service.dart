// lib/services/student_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/student_model.dart';

class StudentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  // ==================== CRUD ÉTUDIANTS ====================

  /// ✅ Créer un étudiant dans Firestore (sous-collection de l'école)
  Future<String> createStudent(StudentModel student, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 🔥 Utiliser une sous-collection de l'école
      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc();

      final studentData = student.toFirestoreMap();
      
      studentData.addAll({
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isSynced': true,
      });

      await docRef.set(studentData);
      
      student.studentFirestoreId = docRef.id;
      
      print('✅ Étudiant créé dans Firestore: ${docRef.id}');
      return docRef.id;
      
    } catch (e) {
      print('❌ Erreur création étudiant Firestore: $e');
      throw e;
    }
  }

  /// ✅ Mettre à jour un étudiant dans Firestore
  Future<void> updateStudent(String schoolId, String studentId, StudentModel student) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final updateData = student.toFirestoreMap();
      
      updateData.addAll({
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
      
      updateData.remove('createdAt');
      updateData.remove('createdBy');

      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc(studentId)
          .update(updateData);
          
      print('✅ Étudiant mis à jour dans Firestore: $studentId');
      
    } catch (e) {
      print('❌ Erreur mise à jour étudiant Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer un étudiant de Firestore
  Future<void> deleteStudent(String schoolId, String studentId) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc(studentId)
          .delete();
          
      print('🗑️ Étudiant supprimé de Firestore: $studentId');
      
    } catch (e) {
      print('❌ Erreur suppression étudiant Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer tous les étudiants d'une école
  Future<void> deleteAllStudents(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Tous les étudiants supprimés pour l\'école: $schoolId');
      
    } catch (e) {
      print('❌ Erreur suppression tous les étudiants: $e');
      throw e;
    }
  }

  /// ✅ Supprimer les étudiants d'une classe
  Future<void> deleteStudentsByClass(String schoolId, String classFirestoreId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .where('classFirestoreId', isEqualTo: classFirestoreId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Étudiants supprimés pour la classe: $classFirestoreId');
      
    } catch (e) {
      print('❌ Erreur suppression étudiants par classe: $e');
      throw e;
    }
  }

  // ==================== RÉCUPÉRATION DES ÉTUDIANTS ====================

  /// ✅ Récupérer tous les étudiants d'une école
  Future<List<StudentModel>> getStudentsBySchool(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .orderBy('fullName')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StudentModel.fromFirestore(data, doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération étudiants par école: $e');
      return [];
    }
  }

  /// ✅ Récupérer les étudiants d'une classe
  Future<List<StudentModel>> getStudentsByClass(String schoolId, String classFirestoreId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .where('classFirestoreId', isEqualTo: classFirestoreId)
          .orderBy('fullName')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StudentModel.fromFirestore(data, doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération étudiants par classe: $e');
      return [];
    }
  }

  /// ✅ Récupérer un étudiant par son ID local
  Future<StudentModel?> getStudentById(String schoolId, int studentId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .where('localId', isEqualTo: studentId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      
      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      return StudentModel.fromFirestore(data, doc.id);
      
    } catch (e) {
      print('❌ Erreur récupération étudiant par ID: $e');
      return null;
    }
  }

  /// ✅ Récupérer un étudiant par son ID Firestore
  Future<StudentModel?> getStudentByFirestoreId(String schoolId, String studentFirestoreId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .doc(studentFirestoreId)
          .get();
      
      if (!doc.exists) return null;
      
      final data = doc.data() as Map<String, dynamic>;
      return StudentModel.fromFirestore(data, doc.id);
      
    } catch (e) {
      print('❌ Erreur récupération étudiant par Firestore ID: $e');
      return null;
    }
  }

  /// ✅ Récupérer un étudiant par son userId
  Future<StudentModel?> getStudentByUserId(String schoolId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      
      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      return StudentModel.fromFirestore(data, doc.id);
      
    } catch (e) {
      print('❌ Erreur récupération étudiant par userId: $e');
      return null;
    }
  }

  // ==================== ÉCOUTE EN TEMPS RÉEL ====================

  /// ✅ Écouter tous les étudiants d'une école en temps réel
  Stream<List<StudentModel>> listenToStudents(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .orderBy('fullName')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return StudentModel.fromFirestore(data, doc.id);
          }).toList();
        });
  }

  /// ✅ Écouter les étudiants d'une classe en temps réel
  Stream<List<StudentModel>> listenToStudentsByClass(String schoolId, String classFirestoreId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('classFirestoreId', isEqualTo: classFirestoreId)
        .orderBy('fullName')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return StudentModel.fromFirestore(data, doc.id);
          }).toList();
        });
  }

  // ==================== SYNCHRONISATION ====================

  /// ✅ Synchroniser tous les étudiants locaux vers Firestore
  Future<void> syncAllStudentsToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des étudiants vers Firestore...');
      final students = await _dbHelper.getAllStudents();
      
      if (students.isEmpty) {
        print('📭 Aucun étudiant à synchroniser');
        return;
      }
      
      int syncedCount = 0;
      
      for (var student in students) {
        try {
          final existing = await _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('students')
              .where('localKey', isEqualTo: student.key)
              .get();

          if (existing.docs.isEmpty) {
            await createStudent(student, schoolId);
            syncedCount++;
          } else {
            final docId = existing.docs.first.id;
            student.studentFirestoreId = docId;
            await updateStudent(schoolId, docId, student);
            syncedCount++;
          }
        } catch (e) {
          print('❌ Erreur synchronisation étudiant ${student.fullName}: $e');
        }
      }

      print('✅ Synchronisation terminée: $syncedCount/${students.length} étudiants');

    } catch (e) {
      print('❌ Erreur synchronisation étudiants: $e');
      throw e;
    }
  }

  /// ✅ Synchroniser les étudiants depuis Firestore vers local
  Future<void> syncStudentsFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des étudiants depuis Firestore...');
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .get();

      if (snapshot.docs.isEmpty) {
        print('📭 Aucun étudiant à synchroniser depuis Firestore');
        return;
      }

      int addedCount = 0;
      int updatedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final student = StudentModel.fromFirestore(data, doc.id);
          
          final existing = await _dbHelper.getStudentByKey(student.key);
          
          if (existing == null) {
            await _dbHelper.addStudent(student);
            addedCount++;
          } else {
            // Mettre à jour : supprimer l'ancien et ajouter le nouveau
            await _dbHelper.deleteStudentByKey(student.key);
            await _dbHelper.addStudent(student);
            updatedCount++;
          }
        } catch (e) {
          print('  ⚠️ Erreur traitement étudiant ${doc.id}: $e');
        }
      }

      print('✅ Synchronisation terminée: +$addedCount ajoutés, $updatedCount mis à jour');

    } catch (e) {
      print('❌ Erreur synchronisation étudiants depuis Firestore: $e');
      throw e;
    }
  }

  /// ✅ Synchronisation complète (bidirectionnelle)
  Future<void> syncAllStudentData(String schoolId) async {
    try {
      print('🔄 Synchronisation complète des étudiants...');
      await syncAllStudentsToFirestore(schoolId);
      await syncStudentsFromFirestore(schoolId);
      print('✅ Synchronisation complète des étudiants terminée');
    } catch (e) {
      print('❌ Erreur synchronisation complète: $e');
      throw e;
    }
  }

  // ==================== STATISTIQUES ====================

  /// ✅ Compter les étudiants par classe
  Future<Map<String, int>> countStudentsByClass(String schoolId) async {
    try {
      final Map<String, int> counts = {};
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .get();
      
      for (var doc in snapshot.docs) {
        final classId = doc['classFirestoreId'] ?? 'unknown';
        counts[classId] = (counts[classId] ?? 0) + 1;
      }
      
      return counts;

    } catch (e) {
      print('❌ Erreur comptage étudiants par classe: $e');
      return {};
    }
  }

  /// ✅ Compter les étudiants par statut de vérification
  Future<Map<String, int>> countStudentsByVerification(String schoolId) async {
    try {
      int verified = 0;
      int unverified = 0;
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .get();
      
      for (var doc in snapshot.docs) {
        final isVerified = doc['documentsVerified'] ?? false;
        if (isVerified) {
          verified++;
        } else {
          unverified++;
        }
      }
      
      return {
        'verified': verified,
        'unverified': unverified,
        'total': verified + unverified,
      };

    } catch (e) {
      print('❌ Erreur comptage étudiants par vérification: $e');
      return {};
    }
  }

  /// ✅ Obtenir les statistiques complètes
  Future<Map<String, dynamic>> getStudentStats(String schoolId) async {
    try {
      final byClass = await countStudentsByClass(schoolId);
      final byVerification = await countStudentsByVerification(schoolId);
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .get();
      
      return {
        'totalStudents': snapshot.docs.length,
        'byClass': byClass,
        'byVerification': byVerification,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

    } catch (e) {
      print('❌ Erreur statistiques étudiants: $e');
      return {};
    }
  }

  /// ✅ Écouter les statistiques en temps réel
  Stream<Map<String, dynamic>> listenToStudentStats(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .snapshots()
        .map((snapshot) {
          final Map<String, int> byClass = {};
          int verified = 0;
          int unverified = 0;
          
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final classId = data['classFirestoreId'] ?? 'unknown';
            byClass[classId] = (byClass[classId] ?? 0) + 1;
            
            final isVerified = data['documentsVerified'] ?? false;
            if (isVerified) {
              verified++;
            } else {
              unverified++;
            }
          }
          
          return {
            'totalStudents': snapshot.docs.length,
            'byClass': byClass,
            'verified': verified,
            'unverified': unverified,
            'lastUpdated': DateTime.now().toIso8601String(),
          };
        });
  }

  // ==================== RECHERCHE ====================

  /// ✅ Rechercher des étudiants par nom
  Future<List<StudentModel>> searchStudentsByName(String schoolId, String query) async {
    try {
      if (query.isEmpty) return [];
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .where('fullName', isGreaterThanOrEqualTo: query)
          .where('fullName', isLessThanOrEqualTo: query + '\uf8ff')
          .orderBy('fullName')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StudentModel.fromFirestore(data, doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur recherche étudiants par nom: $e');
      return [];
    }
  }

  /// ✅ Vérifier si un étudiant existe déjà
  Future<bool> studentExists(String schoolId, String fullName, String className) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .where('fullName', isEqualTo: fullName)
          .where('className', isEqualTo: className)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;

    } catch (e) {
      print('❌ Erreur vérification étudiant: $e');
      return false;
    }
  }

  /// ✅ Récupérer les étudiants par parent
  Future<List<StudentModel>> getStudentsByParent(String schoolId, String parentUserId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('students')
          .where('parentUserId', isEqualTo: parentUserId)
          .orderBy('fullName')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StudentModel.fromFirestore(data, doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération étudiants par parent: $e');
      return [];
    }
  }
}
// lib/services/course_material_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'drive_storage_service.dart';
import '../utils/drive_url_utils.dart';

class CourseMaterialService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DriveStorageService _driveService = DriveStorageService();

  /// 📤 Ajouter un matériel de cours (professeur)
  Future<String> addCourseMaterial({
    required String schoolId,
    required String title,
    required String description,
    required String fileId,
    required String fileName,
    required String fileType,
    required String courseId,
    required String professorId,
    required String professorName,
    String? classId,
  }) async {
    try {
      final fileUrl = DriveUrlUtils.getImageUrl(fileId);
      
      final docRef = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('course_materials')
          .add({
        'title': title,
        'description': description,
        'fileUrl': fileUrl,
        'fileId': fileId,
        'fileName': fileName,
        'fileType': fileType,
        'courseId': courseId,
        'classId': classId,
        'professorId': professorId,
        'professorName': professorName,
        'uploadedAt': FieldValue.serverTimestamp(),
        'downloads': 0,
        'isPublished': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Matériel ajouté: $title');
      return docRef.id;
    } catch (e) {
      print('❌ Erreur ajout matériel: $e');
      throw e;
    }
  }

  /// 📥 Récupérer les matériels d'un cours
  Future<List<Map<String, dynamic>>> getCourseMaterials(
    String schoolId,
    String courseId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('course_materials')
          .where('courseId', isEqualTo: courseId)
          .where('isPublished', isEqualTo: true)
          .orderBy('uploadedAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'fileUrl': data['fileUrl'] ?? '',
          'fileId': data['fileId'] ?? '',
          'fileName': data['fileName'] ?? '',
          'fileType': data['fileType'] ?? '',
          'professorName': data['professorName'] ?? '',
          'uploadedAt': data['uploadedAt'],
          'downloads': data['downloads'] ?? 0,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération matériels: $e');
      return [];
    }
  }

  /// 📥 Récupérer les matériels d'une classe
  Future<List<Map<String, dynamic>>> getClassMaterials(
    String schoolId,
    String classId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('course_materials')
          .where('classId', isEqualTo: classId)
          .where('isPublished', isEqualTo: true)
          .orderBy('uploadedAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'fileUrl': data['fileUrl'] ?? '',
          'fileId': data['fileId'] ?? '',
          'fileName': data['fileName'] ?? '',
          'fileType': data['fileType'] ?? '',
          'professorName': data['professorName'] ?? '',
          'uploadedAt': data['uploadedAt'],
          'downloads': data['downloads'] ?? 0,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération matériels: $e');
      return [];
    }
  }

  /// 📥 Récupérer les matériels d'un professeur
  Future<List<Map<String, dynamic>>> getProfessorMaterials(
    String schoolId,
    String professorId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('course_materials')
          .where('professorId', isEqualTo: professorId)
          .orderBy('uploadedAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'fileUrl': data['fileUrl'] ?? '',
          'fileId': data['fileId'] ?? '',
          'fileName': data['fileName'] ?? '',
          'fileType': data['fileType'] ?? '',
          'uploadedAt': data['uploadedAt'],
          'downloads': data['downloads'] ?? 0,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération matériels: $e');
      return [];
    }
  }

  /// 📥 Récupérer un matériel par ID
  Future<Map<String, dynamic>?> getMaterialById(
    String schoolId,
    String materialId,
  ) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('course_materials')
          .doc(materialId)
          .get();
      
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      return {
        'id': doc.id,
        'title': data['title'] ?? '',
        'description': data['description'] ?? '',
        'fileUrl': data['fileUrl'] ?? '',
        'fileId': data['fileId'] ?? '',
        'fileName': data['fileName'] ?? '',
        'fileType': data['fileType'] ?? '',
        'professorName': data['professorName'] ?? '',
        'uploadedAt': data['uploadedAt'],
        'downloads': data['downloads'] ?? 0,
        ...data,
      };
    } catch (e) {
      print('❌ Erreur récupération matériel: $e');
      return null;
    }
  }

  /// 📊 Incrémenter le compteur de téléchargements
  Future<void> incrementDownloads(
    String schoolId,
    String materialId,
  ) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('course_materials')
          .doc(materialId)
          .update({
        'downloads': FieldValue.increment(1),
      });
    } catch (e) {
      print('❌ Erreur incrément téléchargements: $e');
    }
  }

  /// 📝 Enregistrer un téléchargement par un étudiant
  Future<void> recordStudentDownload({
    required String schoolId,
    required String materialId,
    required String studentId,
    required String studentName,
  }) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('student_downloads')
          .add({
        'materialId': materialId,
        'studentId': studentId,
        'studentName': studentName,
        'downloadedAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      });
      
      await incrementDownloads(schoolId, materialId);
    } catch (e) {
      print('❌ Erreur enregistrement téléchargement: $e');
    }
  }

  /// 📊 Vérifier si un étudiant a déjà téléchargé
  Future<bool> hasStudentDownloaded(
    String schoolId,
    String materialId,
    String studentId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('student_downloads')
          .where('materialId', isEqualTo: materialId)
          .where('studentId', isEqualTo: studentId)
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Erreur vérification téléchargement: $e');
      return false;
    }
  }

  /// 🗑️ Supprimer un matériel (professeur)
  Future<void> deleteMaterial(
    String schoolId,
    String materialId,
  ) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('course_materials')
          .doc(materialId)
          .delete();
      
      print('🗑️ Matériel supprimé: $materialId');
    } catch (e) {
      print('❌ Erreur suppression matériel: $e');
      throw e;
    }
  }

  /// 📝 Mettre à jour un matériel
  Future<void> updateMaterial({
    required String schoolId,
    required String materialId,
    String? title,
    String? description,
    bool? isPublished,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};
      if (title != null) updateData['title'] = title;
      if (description != null) updateData['description'] = description;
      if (isPublished != null) updateData['isPublished'] = isPublished;
      updateData['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('course_materials')
          .doc(materialId)
          .update(updateData);
      
      print('✅ Matériel mis à jour: $materialId');
    } catch (e) {
      print('❌ Erreur mise à jour matériel: $e');
      throw e;
    }
  }
}
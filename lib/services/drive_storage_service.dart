// lib/services/drive_storage_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'drive_config.dart';

class DriveStorageService {
  // 🔥 Utiliser les constantes depuis DriveConfig
  static const String DRIVE_API_KEY = DriveConfig.apiKey;
  static const String FOLDER_ID = DriveConfig.folderId;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ================================================================
  // 📤 GESTION DES RÉFÉRENCES DE FICHIERS
  // ================================================================

  /// 📤 Enregistrer une référence de fichier dans Firestore
  Future<String> saveFileReference({
    required String fileName,
    required String fileUrl,
    required String schoolId,
    required String type, // 'image', 'pdf', 'document'
    String? studentId,
    String? classId,
    String? description,
  }) async {
    try {
      final docRef = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('drive_files')
          .add({
        'fileName': fileName,
        'fileUrl': fileUrl,
        'type': type,
        'schoolId': schoolId,
        'studentId': studentId,
        'classId': classId,
        'description': description,
        'uploadedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Fichier enregistré: $fileName (ID: ${docRef.id})');
      return docRef.id;
    } catch (e) {
      print('❌ Erreur enregistrement fichier: $e');
      throw e;
    }
  }

  /// 📤 Enregistrer un fichier avec son ID Drive
  Future<String> saveDriveFile({
    required String fileName,
    required String fileId,
    required String schoolId,
    required String type,
    String? studentId,
    String? classId,
    String? description,
  }) async {
    // 🔥 Construire l'URL à partir de l'ID du fichier Drive
    final fileUrl = _getDriveUrlFromId(fileId, type);
    
    return await saveFileReference(
      fileName: fileName,
      fileUrl: fileUrl,
      schoolId: schoolId,
      type: type,
      studentId: studentId,
      classId: classId,
      description: description,
    );
  }

  // ================================================================
  // 📥 RÉCUPÉRATION DES FICHIERS
  // ================================================================

  /// 📥 Récupérer tous les fichiers d'une école
  Future<List<Map<String, dynamic>>> getSchoolFiles(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('drive_files')
          .orderBy('uploadedAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'fileName': data['fileName'] ?? '',
          'fileUrl': data['fileUrl'] ?? '',
          'type': data['type'] ?? 'document',
          'studentId': data['studentId'],
          'classId': data['classId'],
          'description': data['description'],
          'uploadedAt': data['uploadedAt'],
        };
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération fichiers: $e');
      return [];
    }
  }

  /// 📥 Récupérer les fichiers d'un étudiant
  Future<List<Map<String, dynamic>>> getStudentFiles(
    String schoolId, 
    String studentId
  ) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('drive_files')
          .where('studentId', isEqualTo: studentId)
          .orderBy('uploadedAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'fileName': data['fileName'] ?? '',
          'fileUrl': data['fileUrl'] ?? '',
          'type': data['type'] ?? 'document',
          'description': data['description'],
          'uploadedAt': data['uploadedAt'],
        };
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération fichiers étudiant: $e');
      return [];
    }
  }

  /// 📥 Récupérer les fichiers d'une classe
  Future<List<Map<String, dynamic>>> getClassFiles(
    String schoolId, 
    String classId
  ) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('drive_files')
          .where('classId', isEqualTo: classId)
          .orderBy('uploadedAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'fileName': data['fileName'] ?? '',
          'fileUrl': data['fileUrl'] ?? '',
          'type': data['type'] ?? 'document',
          'studentId': data['studentId'],
          'description': data['description'],
          'uploadedAt': data['uploadedAt'],
        };
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération fichiers classe: $e');
      return [];
    }
  }

  /// 📥 Récupérer les fichiers par type
  Future<List<Map<String, dynamic>>> getFilesByType(
    String schoolId, 
    String type
  ) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('drive_files')
          .where('type', isEqualTo: type)
          .orderBy('uploadedAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'fileName': data['fileName'] ?? '',
          'fileUrl': data['fileUrl'] ?? '',
          'type': data['type'] ?? 'document',
          'studentId': data['studentId'],
          'classId': data['classId'],
          'description': data['description'],
          'uploadedAt': data['uploadedAt'],
        };
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération fichiers par type: $e');
      return [];
    }
  }

  /// 🖼️ Récupérer les images d'une école
  Future<List<Map<String, dynamic>>> getSchoolImages(String schoolId) async {
    return await getFilesByType(schoolId, 'image');
  }

  /// 📄 Récupérer les PDF d'une école
  Future<List<Map<String, dynamic>>> getSchoolPDFs(String schoolId) async {
    return await getFilesByType(schoolId, 'pdf');
  }

  /// 📥 Récupérer un fichier par son ID
  Future<Map<String, dynamic>?> getFileById(String fileId) async {
    try {
      final doc = await _firestore.collection('drive_files').doc(fileId).get();
      
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      return {
        'id': doc.id,
        'fileName': data['fileName'] ?? '',
        'fileUrl': data['fileUrl'] ?? '',
        'type': data['type'] ?? 'document',
        'studentId': data['studentId'],
        'classId': data['classId'],
        'description': data['description'],
        'uploadedAt': data['uploadedAt'],
      };
    } catch (e) {
      print('❌ Erreur récupération fichier par ID: $e');
      return null;
    }
  }

  // ================================================================
  // 🔍 RECHERCHE DEPUIS DRIVE VIA L'API
  // ================================================================

  /// 🔍 Récupérer la liste des fichiers depuis Drive via l'API
  Future<List<Map<String, dynamic>>> getDriveFilesList() async {
    try {
      final url = Uri.parse(DriveConfig.getListFilesUrl());
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final files = data['files'] ?? [];
        
        return files.map((file) => {
          'id': file['id'],
          'name': file['name'] ?? '',
          'mimeType': file['mimeType'] ?? '',
          'webContentLink': file['webContentLink'],
          'webViewLink': file['webViewLink'],
          'size': file['size'],
          'createdTime': file['createdTime'],
        }).toList();
      } else {
        print('❌ Erreur API Drive: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Erreur récupération fichiers Drive: $e');
      return [];
    }
  }

  /// 🔍 Récupérer les images depuis Drive
  Future<List<Map<String, dynamic>>> getDriveImages() async {
    final files = await getDriveFilesList();
    return files.where((file) =>
      file['mimeType']?.startsWith('image/') == true
    ).toList();
  }

  /// 🔍 Récupérer les PDF depuis Drive
  Future<List<Map<String, dynamic>>> getDrivePDFs() async {
    final files = await getDriveFilesList();
    return files.where((file) =>
      file['mimeType'] == 'application/pdf'
    ).toList();
  }

  // ================================================================
  // 🗑️ SUPPRESSION
  // ================================================================

  /// 🗑️ Supprimer un fichier (seulement la référence)
  Future<void> deleteFileReference(String fileId) async {
    try {
      await _firestore.collection('drive_files').doc(fileId).delete();
      print('🗑️ Référence fichier supprimée: $fileId');
    } catch (e) {
      print('❌ Erreur suppression référence: $e');
      throw e;
    }
  }

  /// 🗑️ Supprimer tous les fichiers d'une école
  Future<void> deleteAllSchoolFiles(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('drive_files')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Tous les fichiers supprimés pour l\'école: $schoolId');
    } catch (e) {
      print('❌ Erreur suppression fichiers école: $e');
      throw e;
    }
  }

  /// 🗑️ Supprimer les fichiers d'un étudiant
  Future<void> deleteStudentFiles(String schoolId, String studentId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('drive_files')
          .where('studentId', isEqualTo: studentId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Fichiers supprimés pour l\'étudiant: $studentId');
    } catch (e) {
      print('❌ Erreur suppression fichiers étudiant: $e');
      throw e;
    }
  }

  // ================================================================
  // 🔧 MÉTHODES UTILITAIRES
  // ================================================================

  /// 🔗 Construire l'URL Drive à partir de l'ID du fichier
  String _getDriveUrlFromId(String fileId, String type) {
    if (type == 'image') {
      return DriveConfig.getImageUrl(fileId);
    } else if (type == 'pdf') {
      return DriveConfig.getPdfPreviewUrl(fileId);
    } else {
      return DriveConfig.getDownloadUrl(fileId);
    }
  }

  /// 🔗 Extraire l'ID du fichier depuis une URL Drive
  String? extractFileId(String driveUrl) {
    // Exemple: https://drive.google.com/file/d/1ABC123DEF456/view
    final match = RegExp(r'/d/([^/]+)/').firstMatch(driveUrl);
    return match?.group(1);
  }

  /// 📊 Compter les fichiers d'une école
  Future<int> countSchoolFiles(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('drive_files')
          .count()
          .get();
      
      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ Erreur comptage fichiers: $e');
      return 0;
    }
  }

  /// 📊 Compter les fichiers par type
  Future<Map<String, int>> countFilesByType(String schoolId) async {
    try {
      final Map<String, int> counts = {};
      final types = ['image', 'pdf', 'document'];
      
      for (var type in types) {
        final snapshot = await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('drive_files')
            .where('type', isEqualTo: type)
            .count()
            .get();
        
        counts[type] = snapshot.count ?? 0;
      }
      
      return counts;
    } catch (e) {
      print('❌ Erreur comptage fichiers par type: $e');
      return {};
    }
  }
}
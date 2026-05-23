// lib/services/document_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/document_model.dart';

class DocumentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  Future<String> createDocument(DocumentModel document, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final docRef = _firestore.collection('documents').doc();
      final documentData = {
        'fullName': document.fullName,
        'className': document.className,
        'docType': document.docType,
        'isValidated': document.isValidated,
        'keyHive': document.keyHive,
        'schoolId': schoolId,
        'localKey': document.key,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(documentData);
      print('✅ Document créé dans Firestore: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Erreur création document Firestore: $e');
      throw e;
    }
  }

  Future<void> syncAllDocumentsToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des documents vers Firestore...');
      final documents = await _dbHelper.getAllDocuments();
      
      for (var document in documents) {
        final existing = await _firestore
            .collection('documents')
            .where('localKey', isEqualTo: document.key)
            .get();

        if (existing.docs.isEmpty) {
          await createDocument(document, schoolId);
        }
      }

      print('✅ Synchronisation des documents terminée: ${documents.length}');
    } catch (e) {
      print('❌ Erreur synchronisation documents: $e');
      throw e;
    }
  }

  Future<void> syncDocumentsFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des documents depuis Firestore...');
      final snapshot = await _firestore
          .collection('documents')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        final document = DocumentModel(
          fullName: data['fullName'] ?? '',
          className: data['className'] ?? '',
          docType: data['docType'] ?? '',
          keyHive: data['keyHive'] ?? 0,
          isValidated: data['isValidated'] ?? false,
          schoolId: data['schoolId'] ?? 0,
        );
        
        // Vérifier si le document existe déjà
        final existing = await _dbHelper.getDocumentByKey(data['localKey']);
        if (existing == null) {
          await _dbHelper.addDocument(document);
        }
      }

      print('✅ Synchronisation des documents depuis Firestore terminée: ${snapshot.docs.length}');
    } catch (e) {
      print('❌ Erreur synchronisation documents depuis Firestore: $e');
    }
  }
}
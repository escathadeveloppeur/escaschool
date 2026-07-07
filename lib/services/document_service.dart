// lib/services/document_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/document_model.dart';

class DocumentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  // ==================== CRUD DOCUMENTS ====================

  /// ✅ Créer un document dans Firestore (sous-collection de l'école)
  Future<String> createDocument(DocumentModel document, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 🔥 Utiliser une sous-collection de l'école
      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .doc();

      // 🔥 Utiliser toFirestoreMap() du modèle
      final documentData = document.toFirestoreMap();
      
      // Ajouter les champs spécifiques au service
      documentData.addAll({
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isSynced': true,
      });

      await docRef.set(documentData);
      
      // Mettre à jour l'ID Firestore dans le modèle
      document.documentFirestoreId = docRef.id;
      
      print('✅ Document créé dans Firestore: ${docRef.id}');
      return docRef.id;
      
    } catch (e) {
      print('❌ Erreur création document Firestore: $e');
      throw e;
    }
  }

  /// ✅ Mettre à jour un document dans Firestore
  Future<void> updateDocument(String schoolId, String documentId, DocumentModel document) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 🔥 Utiliser toFirestoreMap() du modèle
      final updateData = document.toFirestoreMap();
      
      // Ajouter les champs de mise à jour
      updateData.addAll({
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
      
      // Retirer les champs qui ne doivent pas être mis à jour
      updateData.remove('createdAt');
      updateData.remove('createdBy');

      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .doc(documentId)
          .update(updateData);
          
      print('✅ Document mis à jour dans Firestore: $documentId');
      
    } catch (e) {
      print('❌ Erreur mise à jour document Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer un document de Firestore
  Future<void> deleteDocument(String schoolId, String documentId) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .doc(documentId)
          .delete();
          
      print('🗑️ Document supprimé de Firestore: $documentId');
      
    } catch (e) {
      print('❌ Erreur suppression document Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer tous les documents d'une école
  Future<void> deleteAllDocuments(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Tous les documents supprimés pour l\'école: $schoolId');
      
    } catch (e) {
      print('❌ Erreur suppression tous les documents: $e');
      throw e;
    }
  }

  /// ✅ Supprimer les documents d'une classe
  Future<void> deleteDocumentsByClass(String schoolId, String classId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .where('classId', isEqualTo: classId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Documents supprimés pour la classe: $classId');
      
    } catch (e) {
      print('❌ Erreur suppression documents par classe: $e');
      throw e;
    }
  }

  /// ✅ Supprimer les documents par type
  Future<void> deleteDocumentsByType(String schoolId, String docType) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .where('docType', isEqualTo: docType)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Documents supprimés pour le type: $docType');
      
    } catch (e) {
      print('❌ Erreur suppression documents par type: $e');
      throw e;
    }
  }

  /// ✅ Valider/Dévalider un document
  Future<void> toggleDocumentValidation(String schoolId, String documentId, bool isValidated) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .doc(documentId)
          .update({
        'isValidated': isValidated,
        'validatedAt': isValidated ? FieldValue.serverTimestamp() : null,
        'validatedBy': isValidated ? user.uid : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
          
      print('📄 Document ${isValidated ? 'validé' : 'dévalidé'}: $documentId');

    } catch (e) {
      print('❌ Erreur validation document Firestore: $e');
      throw e;
    }
  }

  // ==================== RÉCUPÉRATION DES DOCUMENTS ====================

  /// ✅ Récupérer tous les documents d'une école
  Future<List<DocumentModel>> getDocumentsBySchool(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return DocumentModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération documents par école: $e');
      return [];
    }
  }

  /// ✅ Récupérer les documents d'une classe
  Future<List<DocumentModel>> getDocumentsByClass(String schoolId, String classId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .where('classId', isEqualTo: classId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return DocumentModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération documents par classe: $e');
      return [];
    }
  }

  /// ✅ Récupérer les documents d'un étudiant
  Future<List<DocumentModel>> getDocumentsByStudent(String schoolId, String studentId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .where('studentId', isEqualTo: studentId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return DocumentModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération documents par étudiant: $e');
      return [];
    }
  }

  /// ✅ Récupérer les documents par type
  Future<List<DocumentModel>> getDocumentsByType(String schoolId, String docType) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .where('docType', isEqualTo: docType)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return DocumentModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération documents par type: $e');
      return [];
    }
  }

  /// ✅ Récupérer les documents validés
  Future<List<DocumentModel>> getValidatedDocuments(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .where('isValidated', isEqualTo: true)
          .orderBy('validatedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return DocumentModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération documents validés: $e');
      return [];
    }
  }

  /// ✅ Récupérer les documents non validés
  Future<List<DocumentModel>> getUnvalidatedDocuments(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .where('isValidated', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return DocumentModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération documents non validés: $e');
      return [];
    }
  }

  /// ✅ Récupérer un document par ID
  Future<DocumentModel?> getDocumentById(String schoolId, String documentId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .doc(documentId)
          .get();
      
      if (!doc.exists) return null;
      
      return DocumentModel.fromFirestore(doc.data()!, doc.id);
      
    } catch (e) {
      print('❌ Erreur récupération document par ID: $e');
      return null;
    }
  }

  // ==================== ÉCOUTE EN TEMPS RÉEL ====================

  /// ✅ Écouter tous les documents d'une école en temps réel
  Stream<List<DocumentModel>> listenToDocuments(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('documents')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return DocumentModel.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  /// ✅ Écouter les documents d'une classe en temps réel
  Stream<List<DocumentModel>> listenToDocumentsByClass(String schoolId, String classId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('documents')
        .where('classId', isEqualTo: classId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return DocumentModel.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  /// ✅ Écouter les documents par type en temps réel
  Stream<List<DocumentModel>> listenToDocumentsByType(String schoolId, String docType) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('documents')
        .where('docType', isEqualTo: docType)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return DocumentModel.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  /// ✅ Écouter les documents validés en temps réel
  Stream<List<DocumentModel>> listenToValidatedDocuments(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('documents')
        .where('isValidated', isEqualTo: true)
        .orderBy('validatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return DocumentModel.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  // ==================== SYNCHRONISATION ====================

  /// ✅ Synchroniser tous les documents locaux vers Firestore
  Future<void> syncAllDocumentsToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des documents vers Firestore...');
      final documents = await _dbHelper.getAllDocuments();
      
      if (documents.isEmpty) {
        print('📭 Aucun document à synchroniser');
        return;
      }
      
      int syncedCount = 0;
      
      for (var document in documents) {
        try {
          final existing = await _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('documents')
              .where('localKey', isEqualTo: document.key)
              .get();

          if (existing.docs.isEmpty) {
            await createDocument(document, schoolId);
            syncedCount++;
          } else {
            // Mettre à jour si nécessaire
            final docId = existing.docs.first.id;
            document.documentFirestoreId = docId;
            await updateDocument(schoolId, docId, document);
            syncedCount++;
          }
        } catch (e) {
          print('❌ Erreur synchronisation document ${document.key}: $e');
        }
      }

      print('✅ Synchronisation terminée: $syncedCount/${documents.length} documents');

    } catch (e) {
      print('❌ Erreur synchronisation documents: $e');
      throw e;
    }
  }

  /// ✅ Synchroniser les documents depuis Firestore vers local
  Future<void> syncDocumentsFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des documents depuis Firestore...');
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .get();

      if (snapshot.docs.isEmpty) {
        print('📭 Aucun document à synchroniser depuis Firestore');
        return;
      }

      int addedCount = 0;
      int updatedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final document = DocumentModel.fromFirestore(doc.data(), doc.id);
          
          final existing = await _dbHelper.getDocumentByKey(document.key);
          
          if (existing == null) {
            await _dbHelper.addDocument(document);
            addedCount++;
          } else {
            // Mettre à jour : supprimer l'ancien et ajouter le nouveau
            await _dbHelper.deleteDocumentByKey(document.key);
            await _dbHelper.addDocument(document);
            updatedCount++;
          }
        } catch (e) {
          print('  ⚠️ Erreur traitement document ${doc.id}: $e');
        }
      }

      print('✅ Synchronisation terminée: +$addedCount ajoutés, $updatedCount mis à jour');

    } catch (e) {
      print('❌ Erreur synchronisation documents depuis Firestore: $e');
      throw e;
    }
  }

  /// ✅ Synchronisation complète (bidirectionnelle)
  Future<void> syncAllDocumentData(String schoolId) async {
    try {
      print('🔄 Synchronisation complète des documents...');
      await syncAllDocumentsToFirestore(schoolId);
      await syncDocumentsFromFirestore(schoolId);
      print('✅ Synchronisation complète des documents terminée');
    } catch (e) {
      print('❌ Erreur synchronisation complète: $e');
      throw e;
    }
  }

  // ==================== STATISTIQUES ====================

  /// ✅ Compter les documents par type
  Future<Map<String, int>> countDocumentsByType(String schoolId) async {
    try {
      final Map<String, int> counts = {};
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .get();
      
      for (var doc in snapshot.docs) {
        final docType = doc['docType'] ?? 'other';
        counts[docType] = (counts[docType] ?? 0) + 1;
      }
      
      return counts;
      
    } catch (e) {
      print('❌ Erreur comptage documents par type: $e');
      return {};
    }
  }

  /// ✅ Compter les documents par statut de validation
  Future<Map<String, int>> countDocumentsByValidation(String schoolId) async {
    try {
      int validated = 0;
      int unvalidated = 0;
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .get();
      
      for (var doc in snapshot.docs) {
        final isValidated = doc['isValidated'] ?? false;
        if (isValidated) {
          validated++;
        } else {
          unvalidated++;
        }
      }
      
      return {
        'validated': validated,
        'unvalidated': unvalidated,
        'total': validated + unvalidated,
      };
      
    } catch (e) {
      print('❌ Erreur comptage documents par validation: $e');
      return {};
    }
  }

  /// ✅ Obtenir les statistiques complètes
  Future<Map<String, dynamic>> getDocumentStats(String schoolId) async {
    try {
      final byType = await countDocumentsByType(schoolId);
      final byValidation = await countDocumentsByValidation(schoolId);
      
      return {
        'byType': byType,
        'byValidation': byValidation,
        'total': byValidation['total'] ?? 0,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      print('❌ Erreur statistiques documents: $e');
      return {};
    }
  }

  /// ✅ Écouter les statistiques en temps réel
  Stream<Map<String, dynamic>> listenToDocumentStats(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('documents')
        .snapshots()
        .map((snapshot) {
          final Map<String, int> byType = {};
          int validated = 0;
          int unvalidated = 0;
          
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final docType = data['docType'] ?? 'other';
            byType[docType] = (byType[docType] ?? 0) + 1;
            
            final isValidated = data['isValidated'] ?? false;
            if (isValidated) {
              validated++;
            } else {
              unvalidated++;
            }
          }
          
          return {
            'byType': byType,
            'validated': validated,
            'unvalidated': unvalidated,
            'total': snapshot.docs.length,
            'lastUpdated': DateTime.now().toIso8601String(),
          };
        });
  }

  // ==================== RECHERCHE ====================

  /// ✅ Rechercher des documents par nom d'étudiant
  Future<List<DocumentModel>> searchDocumentsByStudentName(String schoolId, String query) async {
    try {
      if (query.isEmpty) return [];
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .where('fullName', isGreaterThanOrEqualTo: query)
          .where('fullName', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      return snapshot.docs.map((doc) {
        return DocumentModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur recherche documents: $e');
      return [];
    }
  }

  /// ✅ Rechercher des documents par type
  Future<List<DocumentModel>> searchDocumentsByType(String schoolId, String docType) async {
    try {
      if (docType.isEmpty) return [];
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('documents')
          .where('docType', isEqualTo: docType)
          .get();

      return snapshot.docs.map((doc) {
        return DocumentModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur recherche documents par type: $e');
      return [];
    }
  }
}
// lib/services/school_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/university/etablissement_model.dart';
import 'db_helper.dart';

class SchoolService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  // ==================== MÉTHODES UTILITAIRES ====================
  
  int _getIntValue(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _getStringValue(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return '';
    return value.toString();
  }

  bool _getBoolValue(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  // ==================== CRUD ÉCOLES ====================

  /// Créer une école dans Firestore
  Future<String> createSchool(EtablissementModel school) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');
      
      final docRef = _firestore.collection('schools').doc();
      final schoolData = {
        'name': school.nom,
        'type': school.type,
        'address': school.adresse,
        'phone': school.telephone,
        'email': school.email,
        'website': school.siteWeb,
        'localId': school.id,
        'isActive': school.isActive,
        'schoolCode': school.schoolCode,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await docRef.set(schoolData);
      print('✅ École créée dans Firestore: ${docRef.id} - ${school.nom} (Code: ${school.schoolCode})');
      return docRef.id;
      
    } catch (e) {
      print('❌ Erreur création école Firestore: $e');
      throw e;
    }
  }

  /// Mettre à jour une école dans Firestore
  Future<void> updateSchool(String firestoreId, EtablissementModel school) async {
    try {
      final updateData = {
        'name': school.nom,
        'type': school.type,
        'address': school.adresse,
        'phone': school.telephone,
        'email': school.email,
        'website': school.siteWeb,
        'isActive': school.isActive,
        'schoolCode': school.schoolCode,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore.collection('schools').doc(firestoreId).update(updateData);
      print('✅ École mise à jour dans Firestore: $firestoreId');
      
    } catch (e) {
      print('❌ Erreur mise à jour école Firestore: $e');
      throw e;
    }
  }

  /// Mettre à jour le statut d'une école (Actif/Suspendu)
  Future<void> updateSchoolStatus(String firestoreId, bool isActive) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      await _firestore.collection('schools').doc(firestoreId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
      
      print('✅ Statut de l\'école mis à jour dans Firestore: $firestoreId -> ${isActive ? "Actif" : "Suspendu"}');
    } catch (e) {
      print('❌ Erreur mise à jour statut école Firestore: $e');
      throw e;
    }
  }

  /// Récupérer toutes les écoles depuis Firestore
  Future<List<EtablissementModel>> getAllSchoolsFromFirestore() async {
    try {
      final snapshot = await _firestore.collection('schools').get();
      
      final schools = snapshot.docs.map((doc) {
        final data = doc.data();
        final localId = _getIntValue(data, 'localId');
        final name = _getStringValue(data, 'name');
        final type = _getStringValue(data, 'type');
        final address = _getStringValue(data, 'address');
        final phone = _getStringValue(data, 'phone');
        final email = _getStringValue(data, 'email');
        final website = _getStringValue(data, 'website');
        final isActive = _getBoolValue(data, 'isActive');
        final schoolCode = _getStringValue(data, 'schoolCode');
        
        return EtablissementModel(
          id: localId,
          nom: name.isEmpty ? 'École sans nom' : name,
          type: type.isEmpty ? 'École' : type,
          adresse: address,
          telephone: phone,
          email: email,
          siteWeb: website,
          firestoreId: doc.id,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          isActive: isActive,
          schoolCode: schoolCode,
        );
      }).toList();
      
      print('📥 Écoles récupérées depuis Firestore: ${schools.length}');
      return schools;
      
    } catch (e) {
      print('❌ Erreur récupération écoles Firestore: $e');
      return [];
    }
  }

  /// Synchroniser toutes les écoles locales vers Firestore
  Future<void> syncAllSchoolsToFirestore() async {
    try {
      print('🔄 Début synchronisation des écoles vers Firestore...');
      final localSchools = await _dbHelper.getAllEtablissements();
      
      for (var school in localSchools) {
        try {
          final existing = await _firestore
              .collection('schools')
              .where('localId', isEqualTo: school.id)
              .get();
          
          if (existing.docs.isEmpty) {
            await createSchool(school);
            print('  ✅ École synchronisée: ${school.nom}');
          } else {
            final firestoreId = existing.docs.first.id;
            final firestoreData = existing.docs.first.data();
            
            if (firestoreData['name'] != school.nom ||
                firestoreData['address'] != school.adresse ||
                firestoreData['isActive'] != school.isActive) {
              await updateSchool(firestoreId, school);
              print('  🔄 École mise à jour: ${school.nom}');
            }
          }
        } catch (e) {
          print('  ⚠️ Erreur synchronisation école ${school.nom}: $e');
        }
      }
      
      print('✅ Synchronisation des écoles terminée: ${localSchools.length} écoles');
      
    } catch (e) {
      print('❌ Erreur synchronisation écoles: $e');
      throw e;
    }
  }

  /// Synchroniser depuis Firestore vers local
  Future<void> syncSchoolsFromFirestoreToLocal() async {
    try {
      print('🔄 Synchronisation des écoles depuis Firestore...');
      final firestoreSchools = await getAllSchoolsFromFirestore();
      
      for (var school in firestoreSchools) {
        try {
          final existingLocal = await _dbHelper.getEtablissementById(school.id ?? 0);
          
          if (existingLocal == null) {
            await _dbHelper.addEtablissement(school);
            print('  ✅ École ajoutée localement: ${school.nom} (Code: ${school.schoolCode})');
          } else if (existingLocal.nom != school.nom || 
                     existingLocal.isActive != school.isActive ||
                     existingLocal.schoolCode != school.schoolCode) {
            await _dbHelper.updateEtablissement(school.id!, school);
            print('  🔄 École mise à jour localement: ${school.nom}');
          }
        } catch (e) {
          print('  ⚠️ Erreur traitement école ${school.nom}: $e');
        }
      }
      
      print('✅ Synchronisation depuis Firestore terminée: ${firestoreSchools.length} écoles');
      
    } catch (e) {
      print('❌ Erreur synchronisation depuis Firestore: $e');
    }
  }

  /// Supprimer une école de Firestore
  Future<void> deleteSchool(String firestoreId) async {
    try {
      await _firestore.collection('schools').doc(firestoreId).delete();
      print('🗑️ École supprimée de Firestore: $firestoreId');
    } catch (e) {
      print('❌ Erreur suppression école Firestore: $e');
      throw e;
    }
  }
}
// lib/services/school_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/university/etablissement_model.dart';
import 'db_helper.dart';
import 'class_service.dart'; // ← Ajouté pour les sous-collections

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

  /// Récupérer une école par son ID Firestore
  Future<EtablissementModel?> getSchoolById(String firestoreId) async {
    try {
      final doc = await _firestore.collection('schools').doc(firestoreId).get();
      
      if (!doc.exists) {
        print('⚠️ École non trouvée: $firestoreId');
        return null;
      }
      
      final data = doc.data()!;
      return EtablissementModel(
        id: _getIntValue(data, 'localId'),
        nom: _getStringValue(data, 'name'),
        type: _getStringValue(data, 'type'),
        adresse: _getStringValue(data, 'address'),
        telephone: _getStringValue(data, 'phone'),
        email: _getStringValue(data, 'email'),
        siteWeb: _getStringValue(data, 'website'),
        firestoreId: doc.id,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        isActive: _getBoolValue(data, 'isActive'),
        schoolCode: _getStringValue(data, 'schoolCode'),
      );
      
    } catch (e) {
      print('❌ Erreur récupération école: $e');
      return null;
    }
  }

  /// Écouter les écoles en temps réel
  Stream<List<EtablissementModel>> listenToSchools() {
    return _firestore
        .collection('schools')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return EtablissementModel(
              id: _getIntValue(data, 'localId'),
              nom: _getStringValue(data, 'name'),
              type: _getStringValue(data, 'type'),
              adresse: _getStringValue(data, 'address'),
              telephone: _getStringValue(data, 'phone'),
              email: _getStringValue(data, 'email'),
              siteWeb: _getStringValue(data, 'website'),
              firestoreId: doc.id,
              createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
              isActive: _getBoolValue(data, 'isActive'),
              schoolCode: _getStringValue(data, 'schoolCode'),
            );
          }).toList();
        });
  }

  /// Écouter les écoles actives uniquement
  Stream<List<EtablissementModel>> listenToActiveSchools() {
    return _firestore
        .collection('schools')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return EtablissementModel(
              id: _getIntValue(data, 'localId'),
              nom: _getStringValue(data, 'name'),
              type: _getStringValue(data, 'type'),
              adresse: _getStringValue(data, 'address'),
              telephone: _getStringValue(data, 'phone'),
              email: _getStringValue(data, 'email'),
              siteWeb: _getStringValue(data, 'website'),
              firestoreId: doc.id,
              createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
              isActive: _getBoolValue(data, 'isActive'),
              schoolCode: _getStringValue(data, 'schoolCode'),
            );
          }).toList();
        });
  }

  // ==================== SYNCHRONISATION ====================

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
                firestoreData['isActive'] != school.isActive ||
                firestoreData['schoolCode'] != school.schoolCode) {
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

  /// Synchronisation complète (bidirectionnelle)
  Future<void> syncAllData() async {
    try {
      print('🔄 Synchronisation complète des données...');
      await syncAllSchoolsToFirestore();
      await syncSchoolsFromFirestoreToLocal();
      print('✅ Synchronisation complète terminée');
    } catch (e) {
      print('❌ Erreur synchronisation complète: $e');
      throw e;
    }
  }

  // ==================== GESTION DES SOUS-COLLECTIONS ====================

  /// 🆕 Supprimer une école et TOUTES ses sous-collections (classes, étudiants, etc.)
  Future<void> deleteSchoolWithAllData(String schoolId) async {
    try {
      print('🗑️ Suppression de l\'école avec toutes ses données: $schoolId');
      
      // 1. Supprimer toutes les classes (et leurs sous-collections)
      final classService = ClassService();
      await classService.deleteAllClasses(schoolId);
      
      // 2. Supprimer toutes les sous-collections (professeurs, etc.)
      await _deleteAllSubcollections(schoolId);
      
      // 3. Supprimer le document de l'école
      await _firestore.collection('schools').doc(schoolId).delete();
      
      print('✅ École et toutes ses données supprimées: $schoolId');
      
    } catch (e) {
      print('❌ Erreur suppression école avec données: $e');
      throw e;
    }
  }

  /// Supprimer toutes les sous-collections d'une école
  Future<void> _deleteAllSubcollections(String schoolId) async {
    try {
      // Liste des sous-collections à supprimer
      final subcollections = ['classes', 'professeurs', 'matieres', 'events'];
      
      for (var subcol in subcollections) {
        try {
          final snapshot = await _firestore
              .collection('schools')
              .doc(schoolId)
              .collection(subcol)
              .get();
          
          for (var doc in snapshot.docs) {
            await doc.reference.delete();
          }
          
          if (snapshot.docs.isNotEmpty) {
            print('  ✅ Sous-collection $subcol supprimée (${snapshot.docs.length} documents)');
          }
        } catch (e) {
          // Ignorer si la sous-collection n'existe pas
          print('  ⚠️ Sous-collection $subcol non trouvée ou déjà supprimée');
        }
      }
      
    } catch (e) {
      print('❌ Erreur suppression sous-collections: $e');
      throw e;
    }
  }

  /// 🆕 Compter le nombre de classes dans une école
  Future<int> getClassCount(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('classes')
          .count()
          .get();
      
      return snapshot.count ?? 0;
      
    } catch (e) {
      print('❌ Erreur comptage classes: $e');
      return 0;
    }
  }

  /// 🆕 Compter le nombre total d'étudiants dans une école (toutes classes confondues)
  Future<int> getTotalStudentsCount(String schoolId) async {
    try {
      int total = 0;
      
      // Récupérer toutes les classes
      final classesSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('classes')
          .get();
      
      // Compter les étudiants dans chaque classe
      for (var classDoc in classesSnapshot.docs) {
        final studentsCount = await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('classes')
            .doc(classDoc.id)
            .collection('students')
            .count()
            .get();
        
        total += studentsCount.count ?? 0;
      }
      
      return total;
      
    } catch (e) {
      print('❌ Erreur comptage étudiants: $e');
      return 0;
    }
  }

  /// 🆕 Vérifier si une école existe
  Future<bool> schoolExists(String firestoreId) async {
    try {
      final doc = await _firestore.collection('schools').doc(firestoreId).get();
      return doc.exists;
    } catch (e) {
      print('❌ Erreur vérification école: $e');
      return false;
    }
  }

  /// 🆕 Récupérer les statistiques d'une école
  Future<Map<String, dynamic>> getSchoolStats(String schoolId) async {
    try {
      final classCount = await getClassCount(schoolId);
      final studentCount = await getTotalStudentsCount(schoolId);
      final school = await getSchoolById(schoolId);
      
      return {
        'schoolId': schoolId,
        'schoolName': school?.nom ?? 'Inconnu',
        'classCount': classCount,
        'studentCount': studentCount,
        'isActive': school?.isActive ?? false,
        'createdAt': school?.createdAt,
      };
      
    } catch (e) {
      print('❌ Erreur récupération statistiques: $e');
      return {};
    }
  }

  /// 🆕 Écouter les statistiques d'une école en temps réel
  Stream<Map<String, dynamic>> listenToSchoolStats(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .snapshots()
        .asyncMap((doc) async {
          if (!doc.exists) return {};
          
          final data = doc.data()!;
          final classCount = await getClassCount(schoolId);
          final studentCount = await getTotalStudentsCount(schoolId);
          
          return {
            'schoolId': schoolId,
            'schoolName': data['name'] ?? 'Inconnu',
            'classCount': classCount,
            'studentCount': studentCount,
            'isActive': data['isActive'] ?? false,
            'createdAt': data['createdAt'],
          };
        });
  }

  // ==================== MÉTHODES DE RECHERCHE ====================

  /// Rechercher des écoles par nom
  Future<List<EtablissementModel>> searchSchools(String query) async {
    try {
      if (query.isEmpty) return [];
      
      final snapshot = await _firestore
          .collection('schools')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: query + '\uf8ff')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return EtablissementModel(
          id: _getIntValue(data, 'localId'),
          nom: _getStringValue(data, 'name'),
          type: _getStringValue(data, 'type'),
          adresse: _getStringValue(data, 'address'),
          telephone: _getStringValue(data, 'phone'),
          email: _getStringValue(data, 'email'),
          siteWeb: _getStringValue(data, 'website'),
          firestoreId: doc.id,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          isActive: _getBoolValue(data, 'isActive'),
          schoolCode: _getStringValue(data, 'schoolCode'),
        );
      }).toList();
      
    } catch (e) {
      print('❌ Erreur recherche écoles: $e');
      return [];
    }
  }

  /// Rechercher une école par code
  Future<EtablissementModel?> getSchoolByCode(String code) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .where('schoolCode', isEqualTo: code)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      
      final doc = snapshot.docs.first;
      final data = doc.data();
      
      return EtablissementModel(
        id: _getIntValue(data, 'localId'),
        nom: _getStringValue(data, 'name'),
        type: _getStringValue(data, 'type'),
        adresse: _getStringValue(data, 'address'),
        telephone: _getStringValue(data, 'phone'),
        email: _getStringValue(data, 'email'),
        siteWeb: _getStringValue(data, 'website'),
        firestoreId: doc.id,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        isActive: _getBoolValue(data, 'isActive'),
        schoolCode: _getStringValue(data, 'schoolCode'),
      );
      
    } catch (e) {
      print('❌ Erreur recherche école par code: $e');
      return null;
    }
  }

  // ==================== SUPPRESSION ====================

  /// Supprimer une école de Firestore
  /// Supprimer une école et TOUTES ses sous-collections (version robuste)
Future<void> deleteSchoolWithAllDataV2(String schoolId) async {
  try {
    print('🗑️ Suppression complète de l\'école: $schoolId');
    
    // 1. Supprimer les classes et leurs étudiants
    final classesSnapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('classes')
        .get();
    
    for (var classDoc in classesSnapshot.docs) {
      // Supprimer les étudiants
      final studentsSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('classes')
          .doc(classDoc.id)
          .collection('students')
          .get();
      
      for (var studentDoc in studentsSnapshot.docs) {
        await studentDoc.reference.delete();
      }
      
      // Supprimer la classe
      await classDoc.reference.delete();
      print('  ✅ Classe supprimée: ${classDoc.id}');
    }
    
    // 2. Supprimer les professeurs
    final profsSnapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('professeurs')
        .get();
    
    for (var profDoc in profsSnapshot.docs) {
      await profDoc.reference.delete();
    }
    print('  ✅ Professeurs supprimés: ${profsSnapshot.docs.length}');
    
    // 3. Supprimer les matières
    final matieresSnapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('matieres')
        .get();
    
    for (var matiereDoc in matieresSnapshot.docs) {
      await matiereDoc.reference.delete();
    }
    print('  ✅ Matières supprimées: ${matieresSnapshot.docs.length}');
    
    // 4. Supprimer les événements
    final eventsSnapshot = await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('events')
        .get();
    
    for (var eventDoc in eventsSnapshot.docs) {
      await eventDoc.reference.delete();
    }
    print('  ✅ Événements supprimés: ${eventsSnapshot.docs.length}');
    
    // 5. Supprimer le document de l'école
    await _firestore.collection('schools').doc(schoolId).delete();
    
    print('✅ École supprimée avec toutes ses données: $schoolId');
    
  } catch (e) {
    print('❌ Erreur suppression école: $e');
    throw e;
  }
}
}
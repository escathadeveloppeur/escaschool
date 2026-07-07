// lib/services/staff_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/staff_model.dart';
import 'stats_service.dart';

class StaffService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();
  final StatsService _statsService = StatsService();

  // ==================== GESTION DU PERSONNEL ====================

  /// Ajouter un membre du personnel
  Future<int> addStaff(StaffModel staff, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // Créer une copie du staff avec le schoolId
      final staffWithSchoolId = staff.copyWith(
        schoolId: schoolId,
        firestoreId: schoolId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final id = await _dbHelper.addStaff(staffWithSchoolId);
      staffWithSchoolId.id = id;
      
      await _statsService.addSystemLog(
        action: 'staff_add',
        description: 'Ajout du personnel: ${staffWithSchoolId.fullName} (${staffWithSchoolId.position})',
        level: 'info',
        schoolId: schoolId,
      );
      
      // Synchronisation Firebase
      await syncStaffToFirestore(staffWithSchoolId, schoolId);
      
      return id;
    } catch (e) {
      print('❌ Erreur ajout personnel: $e');
      throw e;
    }
  }

  /// Mettre à jour un membre du personnel
  Future<void> updateStaff(int id, StaffModel staff, String schoolId) async {
    try {
      final updatedStaff = staff.copyWith(
        updatedAt: DateTime.now(),
      );
      
      await _dbHelper.updateStaff(id, updatedStaff);
      
      await _statsService.addSystemLog(
        action: 'staff_update',
        description: 'Modification du personnel: ${updatedStaff.fullName}',
        level: 'info',
        schoolId: schoolId,
      );
      
      // Synchronisation Firebase
      if (updatedStaff.firestoreId != null && updatedStaff.firestoreId!.isNotEmpty) {
        await updateStaffInFirestore(schoolId, updatedStaff.firestoreId!, updatedStaff);
      } else {
        await syncStaffToFirestore(updatedStaff, schoolId);
      }
    } catch (e) {
      print('❌ Erreur modification personnel: $e');
      throw e;
    }
  }

  /// Supprimer un membre du personnel
  Future<void> deleteStaff(int id, String name, String schoolId) async {
    try {
      final staff = await _dbHelper.getStaffById(id);
      if (staff != null && staff.firestoreId != null && staff.firestoreId!.isNotEmpty) {
        await deleteStaffFromFirestore(schoolId, staff.firestoreId!);
      }
      
      await _dbHelper.deleteStaff(id);
      
      await _statsService.addSystemLog(
        action: 'staff_delete',
        description: 'Suppression du personnel: $name',
        level: 'warning',
        schoolId: schoolId,
      );
      
      print('✅ Personnel supprimé: $name');
    } catch (e) {
      print('❌ Erreur suppression personnel: $e');
      throw e;
    }
  }

  /// Récupérer tout le personnel d'une école
  Future<List<StaffModel>> getStaffBySchool(String schoolId) async {
    try {
      return await _dbHelper.getStaffBySchool(schoolId);
    } catch (e) {
      print('❌ Erreur récupération personnel par école: $e');
      return [];
    }
  }

  /// Récupérer tout le personnel (Super Admin)
  Future<List<StaffModel>> getAllStaff() async {
    try {
      return await _dbHelper.getAllStaff();
    } catch (e) {
      print('❌ Erreur récupération tout le personnel: $e');
      return [];
    }
  }

  /// Récupérer un personnel par son ID
  Future<StaffModel?> getStaffById(int id) async {
    try {
      return await _dbHelper.getStaffById(id);
    } catch (e) {
      print('❌ Erreur récupération personnel par ID: $e');
      return null;
    }
  }

  // ==================== SYNCHRONISATION FIREBASE ====================

  /// ✅ Synchroniser un personnel vers Firestore (sous-collection de l'école)
  Future<void> syncStaffToFirestore(StaffModel staff, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 🔥 Utiliser une sous-collection de l'école
      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .doc();

      final staffData = {
        'fullName': staff.fullName,
        'position': staff.position,
        'phone': staff.phone,
        'email': staff.email,
        'address': staff.address,
        'hireDate': staff.hireDate.toIso8601String(),
        'salary': staff.salary,
        'photoUrl': staff.photoUrl,
        'isActive': staff.isActive,
        'localId': staff.id,
        'localKey': staff.id?.toString(),
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isSynced': true,
      };

      await docRef.set(staffData);
      await _dbHelper.updateStaffFirestoreId(staff.id!, docRef.id);
      print('✅ Personnel synchronisé dans Firestore: ${docRef.id}');
    } catch (e) {
      print('❌ Erreur synchronisation personnel: $e');
      throw e;
    }
  }

  /// ✅ Mettre à jour un personnel dans Firestore
  Future<void> updateStaffInFirestore(String schoolId, String firestoreId, StaffModel staff) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .doc(firestoreId)
          .update({
        'fullName': staff.fullName,
        'position': staff.position,
        'phone': staff.phone,
        'email': staff.email,
        'address': staff.address,
        'salary': staff.salary,
        'isActive': staff.isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Personnel mis à jour dans Firestore: $firestoreId');
    } catch (e) {
      print('❌ Erreur mise à jour personnel Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer un personnel de Firestore
  Future<void> deleteStaffFromFirestore(String schoolId, String firestoreId) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .doc(firestoreId)
          .delete();
      print('🗑️ Personnel supprimé de Firestore: $firestoreId');
    } catch (e) {
      print('❌ Erreur suppression personnel Firestore: $e');
      throw e;
    }
  }

  /// ✅ Synchroniser tout le personnel local vers Firestore
  Future<void> syncAllStaffToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation du personnel vers Firestore...');
      
      if (schoolId.isEmpty) {
        print('⚠️ School ID est vide, synchronisation ignorée');
        return;
      }
      
      final staffList = await getStaffBySchool(schoolId);
      
      if (staffList.isEmpty) {
        print('📋 Aucun personnel à synchroniser');
        return;
      }
      
      int syncedCount = 0;
      for (var staff in staffList) {
        try {
          if (staff.firestoreId == null || staff.firestoreId!.isEmpty) {
            await syncStaffToFirestore(staff, schoolId);
          } else {
            await updateStaffInFirestore(schoolId, staff.firestoreId!, staff);
          }
          syncedCount++;
        } catch (e) {
          print('❌ Erreur synchronisation pour ${staff.fullName}: $e');
        }
      }

      print('✅ Synchronisation terminée: $syncedCount/${staffList.length} employés');
    } catch (e) {
      print('❌ Erreur synchronisation personnel: $e');
      throw e;
    }
  }

  /// ✅ Synchroniser le personnel depuis Firestore vers local
  Future<void> syncStaffFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation du personnel depuis Firestore...');
      
      if (schoolId.isEmpty) {
        print('⚠️ School ID est vide, synchronisation ignorée');
        return;
      }
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .get();

      if (snapshot.docs.isEmpty) {
        print('📭 Aucun personnel à synchroniser depuis Firestore');
        return;
      }

      int addedCount = 0;
      int updatedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          
          if (data['localId'] == null) {
            print('⚠️ Personnel sans localId ignoré: ${doc.id}');
            continue;
          }
          
          final staff = StaffModel(
            id: data['localId'],
            fullName: data['fullName'] ?? '',
            position: data['position'] ?? '',
            phone: data['phone'],
            email: data['email'],
            address: data['address'],
            hireDate: data['hireDate'] != null 
                ? DateTime.parse(data['hireDate']) 
                : DateTime.now(),
            salary: (data['salary'] ?? 0.0).toDouble(),
            photoUrl: data['photoUrl'],
            isActive: data['isActive'] ?? true,
            schoolId: data['schoolId'] ?? schoolId,
            firestoreId: schoolId,
            createdAt: data['createdAt'] != null 
                ? (data['createdAt'] as Timestamp).toDate() 
                : null,
            updatedAt: data['updatedAt'] != null 
                ? (data['updatedAt'] as Timestamp).toDate() 
                : null,
          );
          
          final existing = await _dbHelper.getStaffById(staff.id!);
          if (existing == null) {
            await _dbHelper.addStaff(staff);
            addedCount++;
            print('  ✅ Personnel ajouté localement: ${staff.fullName}');
          } else {
            await _dbHelper.updateStaff(staff.id!, staff);
            updatedCount++;
            print('  🔄 Personnel mis à jour localement: ${staff.fullName}');
          }
        } catch (e) {
          print('❌ Erreur traitement document ${doc.id}: $e');
        }
      }

      print('✅ Synchronisation terminée: +$addedCount ajoutés, $updatedCount mis à jour (total: ${snapshot.docs.length})');
    } catch (e) {
      print('❌ Erreur synchronisation personnel depuis Firestore: $e');
      throw e;
    }
  }

  /// ✅ Synchronisation complète (bidirectionnelle)
  Future<void> syncAllStaffData(String schoolId) async {
    try {
      print('🔄 Synchronisation complète du personnel...');
      await syncAllStaffToFirestore(schoolId);
      await syncStaffFromFirestore(schoolId);
      print('✅ Synchronisation complète du personnel terminée');
    } catch (e) {
      print('❌ Erreur synchronisation complète: $e');
      throw e;
    }
  }

  /// ✅ Supprimer tout le personnel d'une école
  Future<void> deleteAllStaffForSchool(String schoolId) async {
    try {
      final staffList = await getStaffBySchool(schoolId);
      
      for (var staff in staffList) {
        if (staff.firestoreId != null && staff.firestoreId!.isNotEmpty) {
          await deleteStaffFromFirestore(schoolId, staff.firestoreId!);
        }
        await _dbHelper.deleteStaff(staff.id!);
      }
      
      print('🗑️ Tous les personnels supprimés pour l\'école: $schoolId (${staffList.length})');
    } catch (e) {
      print('❌ Erreur suppression masse personnel: $e');
      throw e;
    }
  }

  // ==================== RÉCUPÉRATION DÉTAILLÉE ====================

  /// ✅ Récupérer le personnel depuis Firestore
  Future<List<StaffModel>> getStaffFromFirestore(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .orderBy('fullName')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return StaffModel(
          id: data['localId'],
          fullName: data['fullName'] ?? '',
          position: data['position'] ?? '',
          phone: data['phone'],
          email: data['email'],
          address: data['address'],
          hireDate: data['hireDate'] != null 
              ? DateTime.parse(data['hireDate']) 
              : DateTime.now(),
          salary: (data['salary'] ?? 0.0).toDouble(),
          photoUrl: data['photoUrl'],
          isActive: data['isActive'] ?? true,
          schoolId: data['schoolId'] ?? schoolId,
          firestoreId: schoolId,
          createdAt: data['createdAt'] != null 
              ? (data['createdAt'] as Timestamp).toDate() 
              : null,
          updatedAt: data['updatedAt'] != null 
              ? (data['updatedAt'] as Timestamp).toDate() 
              : null,
        );
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération personnel depuis Firestore: $e');
      return [];
    }
  }

  /// ✅ Récupérer un personnel par Firestore ID
  Future<StaffModel?> getStaffByFirestoreId(String schoolId, String firestoreId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('staff')
          .doc(firestoreId)
          .get();
      
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      return StaffModel(
        id: data['localId'],
        fullName: data['fullName'] ?? '',
        position: data['position'] ?? '',
        phone: data['phone'],
        email: data['email'],
        address: data['address'],
        hireDate: data['hireDate'] != null 
            ? DateTime.parse(data['hireDate']) 
            : DateTime.now(),
        salary: (data['salary'] ?? 0.0).toDouble(),
        photoUrl: data['photoUrl'],
        isActive: data['isActive'] ?? true,
        schoolId: data['schoolId'] ?? schoolId,
        firestoreId: schoolId,
        createdAt: data['createdAt'] != null 
            ? (data['createdAt'] as Timestamp).toDate() 
            : null,
        updatedAt: data['updatedAt'] != null 
            ? (data['updatedAt'] as Timestamp).toDate() 
            : null,
      );

    } catch (e) {
      print('❌ Erreur récupération personnel par Firestore ID: $e');
      return null;
    }
  }

  // ==================== STATISTIQUES ====================

  /// Vérifier si un personnel existe déjà
  Future<bool> staffExists(String fullName, String position, String schoolId) async {
    try {
      final staffList = await getStaffBySchool(schoolId);
      return staffList.any((staff) => 
        staff.fullName.toLowerCase() == fullName.toLowerCase() && 
        staff.position == position
      );
    } catch (e) {
      print('❌ Erreur vérification existence personnel: $e');
      return false;
    }
  }

  /// Compter le nombre de personnel par école
  Future<int> countStaffBySchool(String schoolId) async {
    try {
      final staffList = await getStaffBySchool(schoolId);
      return staffList.length;
    } catch (e) {
      print('❌ Erreur comptage personnel: $e');
      return 0;
    }
  }

  /// Compter le nombre de personnel actif par école
  Future<int> countActiveStaffBySchool(String schoolId) async {
    try {
      final staffList = await getStaffBySchool(schoolId);
      return staffList.where((staff) => staff.isActive).length;
    } catch (e) {
      print('❌ Erreur comptage personnel actif: $e');
      return 0;
    }
  }

  /// Récupérer le personnel par poste
  Future<List<StaffModel>> getStaffByPosition(String position, String schoolId) async {
    try {
      final staffList = await getStaffBySchool(schoolId);
      return staffList.where((staff) => staff.position == position).toList();
    } catch (e) {
      print('❌ Erreur récupération personnel par poste: $e');
      return [];
    }
  }

  /// Rechercher du personnel par nom
  Future<List<StaffModel>> searchStaff(String query, String schoolId) async {
    try {
      final staffList = await getStaffBySchool(schoolId);
      return staffList.where((staff) => 
        staff.fullName.toLowerCase().contains(query.toLowerCase()) ||
        staff.position.toLowerCase().contains(query.toLowerCase()) ||
        (staff.phone?.contains(query) ?? false)
      ).toList();
    } catch (e) {
      print('❌ Erreur recherche personnel: $e');
      return [];
    }
  }

  /// ✅ Écouter le personnel en temps réel
  Stream<List<StaffModel>> listenToStaff(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('staff')
        .orderBy('fullName')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return StaffModel(
              id: data['localId'],
              fullName: data['fullName'] ?? '',
              position: data['position'] ?? '',
              phone: data['phone'],
              email: data['email'],
              address: data['address'],
              hireDate: data['hireDate'] != null 
                  ? DateTime.parse(data['hireDate']) 
                  : DateTime.now(),
              salary: (data['salary'] ?? 0.0).toDouble(),
              photoUrl: data['photoUrl'],
              isActive: data['isActive'] ?? true,
              schoolId: data['schoolId'] ?? schoolId,
              firestoreId: schoolId,
              createdAt: data['createdAt'] != null 
                  ? (data['createdAt'] as Timestamp).toDate() 
                  : null,
              updatedAt: data['updatedAt'] != null 
                  ? (data['updatedAt'] as Timestamp).toDate() 
                  : null,
            );
          }).toList();
        });
  }

  /// ✅ Écouter le personnel actif en temps réel
  Stream<List<StaffModel>> listenToActiveStaff(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('staff')
        .where('isActive', isEqualTo: true)
        .orderBy('fullName')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return StaffModel(
              id: data['localId'],
              fullName: data['fullName'] ?? '',
              position: data['position'] ?? '',
              phone: data['phone'],
              email: data['email'],
              address: data['address'],
              hireDate: data['hireDate'] != null 
                  ? DateTime.parse(data['hireDate']) 
                  : DateTime.now(),
              salary: (data['salary'] ?? 0.0).toDouble(),
              photoUrl: data['photoUrl'],
              isActive: data['isActive'] ?? true,
              schoolId: data['schoolId'] ?? schoolId,
              firestoreId: schoolId,
              
              createdAt: data['createdAt'] != null 
                  ? (data['createdAt'] as Timestamp).toDate() 
                  : null,
              updatedAt: data['updatedAt'] != null 
                  ? (data['updatedAt'] as Timestamp).toDate() 
                  : null,
            );
          }).toList();
        });
  }
}
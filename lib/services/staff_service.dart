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
  Future<int> addStaff(StaffModel staff, int schoolId) async {
    try {
      final id = await _dbHelper.addStaff(staff);
      staff.id = id;
      
      await _statsService.addSystemLog(
        action: 'staff_add',
        description: 'Ajout du personnel: ${staff.fullName} (${staff.position})',
        level: 'info',
        schoolId: schoolId,
      );
      
      // Synchronisation Firebase
      await syncStaffToFirestore(staff, schoolId.toString());
      
      return id;
    } catch (e) {
      print('Erreur ajout personnel: $e');
      throw e;
    }
  }

  /// Mettre à jour un membre du personnel
  Future<void> updateStaff(int id, StaffModel staff, int schoolId) async {
    try {
      await _dbHelper.updateStaff(id, staff);
      
      await _statsService.addSystemLog(
        action: 'staff_update',
        description: 'Modification du personnel: ${staff.fullName}',
        level: 'info',
        schoolId: schoolId,
      );
      
      // Synchronisation Firebase
      if (staff.firestoreId != null) {
        await updateStaffInFirestore(staff.firestoreId!, staff);
      } else {
        await syncStaffToFirestore(staff, schoolId.toString());
      }
    } catch (e) {
      print('Erreur modification personnel: $e');
      throw e;
    }
  }

  /// Supprimer un membre du personnel
  Future<void> deleteStaff(int id, String name, int schoolId) async {
    try {
      final staff = await _dbHelper.getStaffById(id);
      if (staff != null && staff.firestoreId != null) {
        await deleteStaffFromFirestore(staff.firestoreId!);
      }
      
      await _dbHelper.deleteStaff(id);
      
      await _statsService.addSystemLog(
        action: 'staff_delete',
        description: 'Suppression du personnel: $name',
        level: 'warning',
        schoolId: schoolId,
      );
    } catch (e) {
      print('Erreur suppression personnel: $e');
      throw e;
    }
  }

  /// Récupérer tout le personnel d'une école
  Future<List<StaffModel>> getStaffBySchool(int schoolId) async {
    return await _dbHelper.getStaffBySchool(schoolId);
  }

  /// Récupérer tout le personnel (Super Admin)
  Future<List<StaffModel>> getAllStaff() async {
    return await _dbHelper.getAllStaff();
  }

  // ==================== SYNCHRONISATION FIREBASE ====================

  /// Synchroniser un personnel vers Firestore
  Future<void> syncStaffToFirestore(StaffModel staff, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final docRef = _firestore.collection('staff').doc();
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
        'schoolId': schoolId,
        'localId': staff.id,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(staffData);
      await _dbHelper.updateStaffFirestoreId(staff.id!, docRef.id);
      print('✅ Personnel synchronisé dans Firestore: ${docRef.id}');
    } catch (e) {
      print('❌ Erreur synchronisation personnel: $e');
      throw e;
    }
  }

  /// Mettre à jour un personnel dans Firestore
  Future<void> updateStaffInFirestore(String firestoreId, StaffModel staff) async {
    try {
      await _firestore.collection('staff').doc(firestoreId).update({
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

  /// Supprimer un personnel de Firestore
  Future<void> deleteStaffFromFirestore(String firestoreId) async {
    try {
      await _firestore.collection('staff').doc(firestoreId).delete();
      print('🗑️ Personnel supprimé de Firestore: $firestoreId');
    } catch (e) {
      print('❌ Erreur suppression personnel Firestore: $e');
      throw e;
    }
  }

  /// Synchroniser tout le personnel local vers Firestore
  Future<void> syncAllStaffToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation du personnel vers Firestore...');
      final staffList = await getStaffBySchool(int.parse(schoolId));
      
      for (var staff in staffList) {
        if (staff.firestoreId == null) {
          await syncStaffToFirestore(staff, schoolId);
        } else {
          await updateStaffInFirestore(staff.firestoreId!, staff);
        }
      }

      print('✅ Synchronisation du personnel terminée: ${staffList.length}');
    } catch (e) {
      print('❌ Erreur synchronisation personnel: $e');
      throw e;
    }
  }

  /// Synchroniser le personnel depuis Firestore vers local
  Future<void> syncStaffFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation du personnel depuis Firestore...');
      final snapshot = await _firestore
          .collection('staff')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final staff = StaffModel(
          id: data['localId'],
          fullName: data['fullName'] ?? '',
          position: data['position'] ?? '',
          phone: data['phone'],
          email: data['email'],
          address: data['address'],
          hireDate: data['hireDate'] != null ? DateTime.parse(data['hireDate']) : DateTime.now(),
          salary: data['salary'] ?? 0.0,
          photoUrl: data['photoUrl'],
          isActive: data['isActive'] ?? true,
          schoolId: data['schoolId'] ?? 0,
          firestoreId: doc.id,
        );
        
        final existing = await _dbHelper.getStaffById(staff.id!);
        if (existing == null) {
          await _dbHelper.addStaff(staff);
          print('  ✅ Personnel ajouté localement: ${staff.fullName}');
        } else {
          await _dbHelper.updateStaff(staff.id!, staff);
          print('  🔄 Personnel mis à jour localement: ${staff.fullName}');
        }
      }

      print('✅ Synchronisation du personnel depuis Firestore terminée: ${snapshot.docs.length}');
    } catch (e) {
      print('❌ Erreur synchronisation personnel depuis Firestore: $e');
      throw e;
    }
  }
}
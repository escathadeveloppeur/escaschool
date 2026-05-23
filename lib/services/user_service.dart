// lib/services/user_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  Future<String> createUser(Map<String, dynamic> user, String schoolId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('Utilisateur non connecté');

      final docRef = _firestore.collection('users').doc();
      final userData = {
        'name': user['name'],
        'email': user['email'],
        'role': user['role'],
        'schoolId': schoolId,
        'localId': user['id'],
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(userData);
      print('✅ Utilisateur créé dans Firestore: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Erreur création utilisateur Firestore: $e');
      throw e;
    }
  }

  Future<void> syncAllUsersToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des utilisateurs vers Firestore...');
      final users = await _dbHelper.getAllUsers();
      
      for (var user in users) {
        final existing = await _firestore
            .collection('users')
            .where('localId', isEqualTo: user['id'])
            .get();

        if (existing.docs.isEmpty) {
          await createUser(user, schoolId);
        }
      }

      print('✅ Synchronisation des utilisateurs terminée: ${users.length}');
    } catch (e) {
      print('❌ Erreur synchronisation utilisateurs: $e');
      throw e;
    }
  }

  Future<void> syncUsersFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des utilisateurs depuis Firestore...');
      final snapshot = await _firestore
          .collection('users')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final user = {
          'id': data['localId'],
          'name': data['name'],
          'email': data['email'],
          'role': data['role'],
          'schoolId': data['schoolId'],
        };
        
        final existing = await _dbHelper.getUserById(user['id']);
        if (existing == null) {
          await _dbHelper.insertUser(user);
        }
      }

      print('✅ Synchronisation des utilisateurs depuis Firestore terminée: ${snapshot.docs.length}');
    } catch (e) {
      print('❌ Erreur synchronisation utilisateurs depuis Firestore: $e');
    }
  }
}
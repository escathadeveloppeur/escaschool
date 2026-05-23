// lib/services/announcement_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';

class AnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  /// Créer une annonce dans Firestore
  Future<String> createAnnouncement(Map<String, dynamic> announcement, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final docRef = _firestore.collection('announcements').doc();
      final announcementData = {
        'title': announcement['title'],
        'content': announcement['content'],
        'date': announcement['date'],
        'schoolId': schoolId,
        'localId': announcement['id'],
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(announcementData);
      print('✅ Annonce créée dans Firestore: ${docRef.id}');
      return docRef.id;

    } catch (e) {
      print('❌ Erreur création annonce Firestore: $e');
      throw e;
    }
  }

  /// Synchroniser toutes les annonces locales vers Firestore
  Future<void> syncAllAnnouncementsToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des annonces vers Firestore...');
      final announcements = await _dbHelper.getAllAnnouncements();
      
      for (var announcement in announcements) {
        final existing = await _firestore
            .collection('announcements')
            .where('localId', isEqualTo: announcement['id'])
            .get();

        if (existing.docs.isEmpty) {
          await createAnnouncement(announcement, schoolId);
        }
      }

      print('✅ Synchronisation des annonces terminée: ${announcements.length}');

    } catch (e) {
      print('❌ Erreur synchronisation annonces: $e');
      throw e;
    }
  }
}
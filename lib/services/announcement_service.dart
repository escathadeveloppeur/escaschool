// lib/services/announcement_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';

class AnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  // ==================== CRUD ANNONCES ====================

  /// ✅ Créer une annonce dans Firestore (dans une sous-collection de l'école)
  Future<String> createAnnouncement(Map<String, dynamic> announcement, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 🔥 Changement: utiliser une sous-collection de l'école
      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('announcements')
          .doc();
      
      final audience = announcement['audience'] ?? 'all';
      final targetedRoles = announcement['targetedRoles'] ?? _getTargetedRoles(audience);
      final classId = announcement['classId'];
      final className = announcement['className'];
      final audienceLabel = announcement['audienceLabel'] ?? _getAudienceLabel(audience);
      
      final announcementData = {
        'title': announcement['title'],
        'content': announcement['content'],
        'date': announcement['date'] ?? FieldValue.serverTimestamp(),
        // ❌ On retire schoolId car c'est implicite via le chemin
        'localId': announcement['id'],
        'createdBy': user.uid,
        'createdByName': announcement['createdByName'] ?? user.displayName ?? 'Admin',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'audience': audience,
        'targetedRoles': targetedRoles,
        'classId': classId,
        'className': className,
        'audienceLabel': audienceLabel,
        'audienceDescription': _getAudienceDescription(audience),
        'isPinned': announcement['isPinned'] ?? false,
        'status': announcement['status'] ?? 'active',
        'expiresAt': announcement['expiresAt'],
        'viewCount': 0,
      };

      await docRef.set(announcementData);
      print('✅ Annonce créée dans Firestore: ${docRef.id}');
      return docRef.id;

    } catch (e) {
      print('❌ Erreur création annonce Firestore: $e');
      throw e;
    }
  }

  /// ✅ Mettre à jour une annonce dans Firestore
  Future<void> updateAnnouncement(String schoolId, String announcementId, Map<String, dynamic> announcement) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final audience = announcement['audience'] ?? 'all';
      final targetedRoles = announcement['targetedRoles'] ?? _getTargetedRoles(audience);
      
      final updateData = {
        'title': announcement['title'],
        'content': announcement['content'],
        'audience': audience,
        'targetedRoles': targetedRoles,
        'classId': announcement['classId'],
        'className': announcement['className'],
        'audienceLabel': _getAudienceLabel(audience),
        'audienceDescription': _getAudienceDescription(audience),
        'isPinned': announcement['isPinned'] ?? false,
        'status': announcement['status'] ?? 'active',
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      };

      // 🔥 Changement: utiliser la sous-collection
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('announcements')
          .doc(announcementId)
          .update(updateData);
          
      print('✅ Annonce mise à jour dans Firestore: $announcementId');

    } catch (e) {
      print('❌ Erreur mise à jour annonce Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer une annonce de Firestore
  Future<void> deleteAnnouncement(String schoolId, String announcementId) async {
    try {
      // 🔥 Changement: utiliser la sous-collection
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('announcements')
          .doc(announcementId)
          .delete();
          
      print('🗑️ Annonce supprimée de Firestore: $announcementId');

    } catch (e) {
      print('❌ Erreur suppression annonce Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer toutes les annonces d'une école
  Future<void> deleteAllAnnouncements(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('announcements')
          .get();
      
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      
      print('🗑️ Toutes les annonces supprimées pour l\'école: $schoolId');
      
    } catch (e) {
      print('❌ Erreur suppression toutes les annonces: $e');
      throw e;
    }
  }

  /// ✅ Épingler/Désépingler une annonce
  Future<void> togglePinAnnouncement(String schoolId, String announcementId, bool isPinned) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('announcements')
          .doc(announcementId)
          .update({
        'isPinned': isPinned,
        'pinnedAt': isPinned ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
          
      print('📌 Annonce ${isPinned ? 'épinglée' : 'désépinglée'}: $announcementId');

    } catch (e) {
      print('❌ Erreur épinglage annonce Firestore: $e');
      throw e;
    }
  }

  /// ✅ Incrémenter le compteur de vues
  Future<void> incrementViewCount(String schoolId, String announcementId) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('announcements')
          .doc(announcementId)
          .update({
        'viewCount': FieldValue.increment(1),
      });

    } catch (e) {
      print('❌ Erreur incrément vues: $e');
    }
  }

  // ==================== RÉCUPÉRATION DES ANNONCES ====================

  /// ✅ Récupérer les annonces pour un utilisateur
  Future<List<Map<String, dynamic>>> getAnnouncementsForUser(
    String schoolId, 
    String userId, 
    String userRole, {
    String? classId,
  }) async {
    try {
      // 🔥 Changement: utiliser la sous-collection
      Query query = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('announcements')
          .where('status', isEqualTo: 'active')
          .orderBy('isPinned', descending: true)
          .orderBy('createdAt', descending: true);

      final snapshot = await query.get();
      
      final List<Map<String, dynamic>> visibleAnnouncements = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final audience = data['audience'] ?? 'all';
        final targetedRoles = List<String>.from(data['targetedRoles'] ?? []);
        final announcementClassId = data['classId'];
        
        // Vérifier si l'utilisateur peut voir cette annonce
        bool canSee = false;
        
        if (userRole == 'admin' || userRole == 'super_admin') {
          canSee = true;
        } else {
          switch (audience) {
            case 'all':
              canSee = true;
              break;
            case 'students':
              canSee = userRole == 'student';
              if (canSee && classId != null && announcementClassId != null) {
                canSee = classId == announcementClassId;
              }
              break;
            case 'teachers':
              canSee = userRole == 'teacher';
              break;
            case 'parents':
              canSee = userRole == 'parent';
              break;
            case 'staff':
              canSee = userRole == 'staff' || userRole == 'admin';
              break;
            case 'admins':
              canSee = userRole == 'admin' || userRole == 'super_admin';
              break;
            case 'specific_class':
              canSee = userRole == 'student' && classId == announcementClassId;
              break;
            default:
              canSee = false;
          }
        }
        
        if (canSee) {
          final announcement = {
            'id': doc.id,
            'firestoreId': doc.id,
            ...data,
          };
          visibleAnnouncements.add(announcement);
        }
      }
      
      return visibleAnnouncements;

    } catch (e) {
      print('❌ Erreur récupération annonces: $e');
      return [];
    }
  }

  /// ✅ Récupérer les annonces épinglées
  Future<List<Map<String, dynamic>>> getPinnedAnnouncements(String schoolId) async {
    try {
      // 🔥 Changement: utiliser la sous-collection
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('announcements')
          .where('isPinned', isEqualTo: true)
          .where('status', isEqualTo: 'active')
          .orderBy('pinnedAt', descending: true)
          .limit(3)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'firestoreId': doc.id,
          ...data,
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération annonces épinglées: $e');
      return [];
    }
  }

  /// ✅ Récupérer les annonces par audience
  Future<List<Map<String, dynamic>>> getAnnouncementsByAudience(String schoolId, String audience) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('announcements')
          .where('audience', isEqualTo: audience)
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'firestoreId': doc.id,
          ...data,
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération annonces par audience: $e');
      return [];
    }
  }

  /// ✅ Écouter les annonces en temps réel
  Stream<List<Map<String, dynamic>>> listenToAnnouncements(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('announcements')
        .where('status', isEqualTo: 'active')
        .orderBy('isPinned', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'firestoreId': doc.id,
              ...data,
            };
          }).toList();
        });
  }

  /// ✅ Écouter les annonces épinglées en temps réel
  Stream<List<Map<String, dynamic>>> listenToPinnedAnnouncements(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('announcements')
        .where('isPinned', isEqualTo: true)
        .where('status', isEqualTo: 'active')
        .orderBy('pinnedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'id': doc.id,
              'firestoreId': doc.id,
              ...data,
            };
          }).toList();
        });
  }

  // ==================== SYNCHRONISATION ====================

  /// ✅ Synchroniser toutes les annonces locales vers Firestore
  Future<void> syncAllAnnouncementsToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des annonces vers Firestore...');
      final announcements = await _dbHelper.getAllAnnouncements();
      
      if (announcements.isEmpty) {
        print('📭 Aucune annonce à synchroniser');
        return;
      }
      
      int syncedCount = 0;
      
      for (var announcement in announcements) {
        try {
          final existing = await _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('announcements')
              .where('localId', isEqualTo: announcement['id'])
              .get();

          if (existing.docs.isEmpty) {
            await createAnnouncement(announcement, schoolId);
            syncedCount++;
          }
        } catch (e) {
          print('❌ Erreur synchronisation annonce ${announcement['id']}: $e');
        }
      }

      print('✅ Synchronisation terminée: $syncedCount/${announcements.length} annonces');

    } catch (e) {
      print('❌ Erreur synchronisation annonces: $e');
      throw e;
    }
  }

  /// ✅ Récupérer les annonces depuis Firestore vers local
  Future<void> syncAnnouncementsFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des annonces depuis Firestore...');
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('announcements')
          .get();

      int addedCount = 0;
      int updatedCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        final announcement = {
          'id': data['localId'],
          'firestoreId': doc.id,
          'title': data['title'] ?? '',
          'content': data['content'] ?? '',
          'date': data['date'] != null 
              ? (data['date'] as Timestamp).toDate().toIso8601String()
              : DateTime.now().toIso8601String(),
          'schoolId': schoolId,
          'audience': data['audience'] ?? 'all',
          'targetedRoles': data['targetedRoles'] ?? [],
          'classId': data['classId'],
          'className': data['className'],
          'isPinned': data['isPinned'] ?? false,
          'createdByName': data['createdByName'] ?? 'Admin',
        };
        
        final existing = await _dbHelper.getAnnouncementByLocalId(announcement['id']);
        
        if (existing == null) {
          await _dbHelper.addAnnouncement(announcement);
          addedCount++;
        } else {
          await _dbHelper.updateAnnouncementByLocalId(announcement['id'], announcement);
          updatedCount++;
        }
      }

      print('✅ Synchronisation terminée: +$addedCount ajoutées, $updatedCount mises à jour');

    } catch (e) {
      print('❌ Erreur synchronisation annonces depuis Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer les annonces expirées
  Future<void> deleteExpiredAnnouncements(String schoolId) async {
    try {
      final now = Timestamp.now();
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('announcements')
          .where('expiresAt', isLessThan: now)
          .get();

      final batch = _firestore.batch();
      
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      if (snapshot.docs.isNotEmpty) {
        print('🗑️ ${snapshot.docs.length} annonces expirées supprimées');
      }

    } catch (e) {
      print('❌ Erreur suppression annonces expirées: $e');
    }
  }

  // ==================== MÉTHODES UTILITAIRES ====================

  /// ✅ Obtenir les rôles ciblés en fonction de l'audience
  List<String> _getTargetedRoles(String audience) {
    switch (audience) {
      case 'students':
        return ['student'];
      case 'teachers':
        return ['teacher'];
      case 'parents':
        return ['parent'];
      case 'staff':
        return ['staff'];
      case 'admins':
        return ['admin', 'super_admin'];
      case 'all':
      default:
        return ['student', 'teacher', 'parent', 'staff', 'admin', 'super_admin'];
    }
  }

  /// ✅ Obtenir le libellé de l'audience
  String _getAudienceLabel(String audience) {
    final labels = {
      'all': '📢 Tout le monde',
      'students': '👨‍🎓 Étudiants',
      'teachers': '👨‍🏫 Enseignants',
      'parents': '👨‍👩‍👦 Parents',
      'staff': '👔 Personnel',
      'admins': '👨‍💼 Admins',
      'specific_class': '🏫 Classe spécifique',
    };
    return labels[audience] ?? 'Tout le monde';
  }

  /// ✅ Obtenir la description de l'audience
  String _getAudienceDescription(String audience) {
    final descriptions = {
      'all': 'Visible par tous les utilisateurs de l\'école',
      'students': 'Visible uniquement par les étudiants',
      'teachers': 'Visible uniquement par les enseignants',
      'parents': 'Visible uniquement par les parents',
      'staff': 'Visible uniquement par le personnel',
      'admins': 'Visible uniquement par les administrateurs',
      'specific_class': 'Visible uniquement par les étudiants d\'une classe spécifique',
    };
    return descriptions[audience] ?? 'Visible par tous';
  }

  // ==================== MÉTHODES STATISTIQUES ====================

  /// ✅ Compter les annonces par école
  Future<int> countAnnouncementsBySchool(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('announcements')
          .count()
          .get();
          
      return snapshot.count ?? 0;
      
    } catch (e) {
      print('❌ Erreur comptage annonces: $e');
      return 0;
    }
  }

  /// ✅ Compter les annonces par audience
  Future<Map<String, int>> countAnnouncementsByAudience(String schoolId) async {
    try {
      final Map<String, int> counts = {};
      final audiences = ['all', 'students', 'teachers', 'parents', 'staff', 'admins', 'specific_class'];
      
      for (var audience in audiences) {
        final snapshot = await _firestore
            .collection('schools')
            .doc(schoolId)
            .collection('announcements')
            .where('audience', isEqualTo: audience)
            .count()
            .get();
            
        counts[audience] = snapshot.count ?? 0;
      }
      
      return counts;
      
    } catch (e) {
      print('❌ Erreur comptage annonces par audience: $e');
      return {};
    }
  }

  /// ✅ Récupérer les annonces récentes (limitées)
  Future<List<Map<String, dynamic>>> getRecentAnnouncements(
    String schoolId, {
    int limit = 5,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('announcements')
          .where('status', isEqualTo: 'active')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'firestoreId': doc.id,
          ...data,
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération annonces récentes: $e');
      return [];
    }
  }

  /// ✅ Obtenir les statistiques des annonces
  Future<Map<String, dynamic>> getAnnouncementStats(String schoolId) async {
    try {
      final total = await countAnnouncementsBySchool(schoolId);
      final byAudience = await countAnnouncementsByAudience(schoolId);
      
      // Annonces épinglées
      final pinnedSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('announcements')
          .where('isPinned', isEqualTo: true)
          .count()
          .get();
      
      // Annonces actives
      final activeSnapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('announcements')
          .where('status', isEqualTo: 'active')
          .count()
          .get();
      
      return {
        'total': total,
        'pinned': pinnedSnapshot.count ?? 0,
        'active': activeSnapshot.count ?? 0,
        'byAudience': byAudience,
      };
      
    } catch (e) {
      print('❌ Erreur statistiques annonces: $e');
      return {};
    }
  }

  /// ✅ Écouter les statistiques des annonces en temps réel
  Stream<Map<String, dynamic>> listenToAnnouncementStats(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('announcements')
        .snapshots()
        .asyncMap((snapshot) async {
          final total = snapshot.docs.length;
          final pinned = snapshot.docs.where((doc) => doc['isPinned'] == true).length;
          final active = snapshot.docs.where((doc) => doc['status'] == 'active').length;
          
          // Compter par audience
          final Map<String, int> byAudience = {};
          for (var doc in snapshot.docs) {
            final audience = doc['audience'] ?? 'all';
            byAudience[audience] = (byAudience[audience] ?? 0) + 1;
          }
          
          return {
            'total': total,
            'pinned': pinned,
            'active': active,
            'byAudience': byAudience,
          };
        });
  }

  /// ✅ Récupérer une annonce par son ID
  Future<Map<String, dynamic>?> getAnnouncementById(String schoolId, String announcementId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('announcements')
          .doc(announcementId)
          .get();
      
      if (!doc.exists) return null;
      
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'firestoreId': doc.id,
        ...data,
      };
      
    } catch (e) {
      print('❌ Erreur récupération annonce: $e');
      return null;
    }
  }

  /// ✅ Rechercher des annonces par titre
  Future<List<Map<String, dynamic>>> searchAnnouncements(String schoolId, String query) async {
    try {
      if (query.isEmpty) return [];
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('announcements')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'firestoreId': doc.id,
          ...data,
        };
      }).toList();

    } catch (e) {
      print('❌ Erreur recherche annonces: $e');
      return [];
    }
  }
}
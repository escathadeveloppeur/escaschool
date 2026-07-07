// lib/services/message_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/message_model.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  // ==================== CRUD MESSAGES ====================

  /// ✅ Créer un message dans Firestore (sous-collection de l'école)
  Future<String> createMessage(MessageModel message, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      // 🔥 Utiliser une sous-collection de l'école
      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('messages')
          .doc();

      // 🔥 Utiliser toFirestoreMap() du modèle
      final messageData = message.toFirestoreMap();
      
      // Ajouter les champs spécifiques au service
      messageData.addAll({
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isSynced': true,
      });

      await docRef.set(messageData);
      
      // Mettre à jour l'ID Firestore dans le modèle
      message.messageFirestoreId = docRef.id;
      
      print('✅ Message créé dans Firestore: ${docRef.id}');
      return docRef.id;
      
    } catch (e) {
      print('❌ Erreur création message Firestore: $e');
      throw e;
    }
  }

  /// ✅ Mettre à jour un message dans Firestore
  Future<void> updateMessage(String schoolId, String messageId, MessageModel message) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final updateData = message.toFirestoreMap();
      
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
          .collection('messages')
          .doc(messageId)
          .update(updateData);
          
      print('✅ Message mis à jour dans Firestore: $messageId');
      
    } catch (e) {
      print('❌ Erreur mise à jour message Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer un message de Firestore
  Future<void> deleteMessage(String schoolId, String messageId) async {
    try {
      await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('messages')
          .doc(messageId)
          .delete();
          
      print('🗑️ Message supprimé de Firestore: $messageId');
      
    } catch (e) {
      print('❌ Erreur suppression message Firestore: $e');
      throw e;
    }
  }

  /// ✅ Supprimer tous les messages d'une école
  Future<void> deleteAllMessages(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('messages')
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Tous les messages supprimés pour l\'école: $schoolId');
      
    } catch (e) {
      print('❌ Erreur suppression tous les messages: $e');
      throw e;
    }
  }

  /// ✅ Supprimer les messages d'un destinataire
  Future<void> deleteMessagesByRecipient(String schoolId, String recipientName) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('messages')
          .where('recipientName', isEqualTo: recipientName)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('🗑️ Messages supprimés pour le destinataire: $recipientName');
      
    } catch (e) {
      print('❌ Erreur suppression messages par destinataire: $e');
      throw e;
    }
  }

  // ==================== RÉCUPÉRATION DES MESSAGES ====================

  /// ✅ Récupérer tous les messages d'une école
  Future<List<MessageModel>> getMessagesBySchool(String schoolId) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('messages')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return MessageModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération messages par école: $e');
      return [];
    }
  }

/// ✅ Récupérer les messages d'un utilisateur
Future<List<MessageModel>> getMessagesForUser({
  required String schoolId,
  required String userName,
  required String userRole,
  String? studentName,
}) async {
  try {
    Query query = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('messages')
        .where('recipientName', isEqualTo: userName)
        .where('recipientRole', isEqualTo: userRole)
        .orderBy('date', descending: true);

    final snapshot = await query.get();

    // 🔥 CORRECTION: Caster doc.data() en Map<String, dynamic>
    var messages = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return MessageModel.fromFirestore(data, doc.id);
    }).toList();

    // Filtrer par nom d'étudiant si spécifié
    if (studentName != null && studentName.isNotEmpty) {
      messages = messages.where((m) => m.studentName == studentName).toList();
    }

    return messages;

  } catch (e) {
    print('❌ Erreur récupération messages pour utilisateur: $e');
    return [];
  }
}

  /// ✅ Récupérer les messages envoyés par un utilisateur
  Future<List<MessageModel>> getMessagesBySender({
    required String schoolId,
    required String senderName,
    required String senderRole,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('messages')
          .where('senderName', isEqualTo: senderName)
          .where('senderRole', isEqualTo: senderRole)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return MessageModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération messages envoyés: $e');
      return [];
    }
  }

  /// ✅ Récupérer les messages non lus d'un utilisateur
  Future<List<MessageModel>> getUnreadMessages({
    required String schoolId,
    required String userName,
    required String userRole,
    String? studentName,
  }) async {
    try {
      final allMessages = await getMessagesForUser(
        schoolId: schoolId,
        userName: userName,
        userRole: userRole,
        studentName: studentName,
      );
      
      return allMessages.where((m) => !m.read).toList();
      
    } catch (e) {
      print('❌ Erreur récupération messages non lus: $e');
      return [];
    }
  }

  /// ✅ Récupérer les messages importants
  Future<List<MessageModel>> getImportantMessages({
    required String schoolId,
    required String userName,
    required String userRole,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('messages')
          .where('recipientName', isEqualTo: userName)
          .where('recipientRole', isEqualTo: userRole)
          .where('important', isEqualTo: true)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return MessageModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur récupération messages importants: $e');
      return [];
    }
  }

  /// ✅ Récupérer un message par ID
  Future<MessageModel?> getMessageById(String schoolId, String messageId) async {
    try {
      final doc = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('messages')
          .doc(messageId)
          .get();
      
      if (!doc.exists) return null;
      
      return MessageModel.fromFirestore(doc.data()!, doc.id);
      
    } catch (e) {
      print('❌ Erreur récupération message par ID: $e');
      return null;
    }
  }

  // ==================== ÉCOUTE EN TEMPS RÉEL ====================

  /// ✅ Écouter les messages d'un utilisateur en temps réel
  Stream<List<MessageModel>> listenToMessagesForUser({
    required String schoolId,
    required String userName,
    required String userRole,
    String? studentName,
  }) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('messages')
        .where('recipientName', isEqualTo: userName)
        .where('recipientRole', isEqualTo: userRole)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          var messages = snapshot.docs.map((doc) {
            return MessageModel.fromFirestore(doc.data(), doc.id);
          }).toList();
          
          if (studentName != null && studentName.isNotEmpty) {
            messages = messages.where((m) => m.studentName == studentName).toList();
          }
          
          return messages;
        });
  }

  /// ✅ Écouter les messages non lus en temps réel
  Stream<int> listenToUnreadCount({
    required String schoolId,
    required String userName,
    required String userRole,
    String? studentName,
  }) {
    return listenToMessagesForUser(
      schoolId: schoolId,
      userName: userName,
      userRole: userRole,
      studentName: studentName,
    ).map((messages) => messages.where((m) => !m.read).length);
  }

  // ==================== SYNCHRONISATION ====================

  /// ✅ Synchroniser tous les messages locaux vers Firestore
  Future<void> syncAllMessagesToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des messages vers Firestore...');
      final messages = await _dbHelper.getAllMessages();
      
      if (messages.isEmpty) {
        print('📭 Aucun message à synchroniser');
        return;
      }
      
      int syncedCount = 0;
      
      for (var message in messages) {
        try {
          final existing = await _firestore
              .collection('schools')
              .doc(schoolId)
              .collection('messages')
              .where('localKey', isEqualTo: message.key)
              .get();

          if (existing.docs.isEmpty) {
            await createMessage(message, schoolId);
            syncedCount++;
          } else {
            // Mettre à jour si nécessaire
            final docId = existing.docs.first.id;
            message.messageFirestoreId = docId;
            await updateMessage(schoolId, docId, message);
            syncedCount++;
          }
        } catch (e) {
          print('❌ Erreur synchronisation message ${message.key}: $e');
        }
      }

      print('✅ Synchronisation terminée: $syncedCount/${messages.length} messages');

    } catch (e) {
      print('❌ Erreur synchronisation messages: $e');
      throw e;
    }
  }

  /// ✅ Synchroniser les messages depuis Firestore vers local
  Future<void> syncMessagesFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des messages depuis Firestore...');
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('messages')
          .get();

      if (snapshot.docs.isEmpty) {
        print('📭 Aucun message à synchroniser depuis Firestore');
        return;
      }

      int addedCount = 0;
      int updatedCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final message = MessageModel.fromFirestore(doc.data(), doc.id);
          
          final existing = await _dbHelper.getMessageByKey(message.key);
          
          if (existing == null) {
            await _dbHelper.addMessage(message);
            addedCount++;
          } else {
            // Mettre à jour : supprimer l'ancien et ajouter le nouveau
            await _dbHelper.deleteMessageByKey(message.key);
            await _dbHelper.addMessage(message);
            updatedCount++;
          }
        } catch (e) {
          print('  ⚠️ Erreur traitement message ${doc.id}: $e');
        }
      }

      print('✅ Synchronisation terminée: +$addedCount ajoutés, $updatedCount mis à jour');

    } catch (e) {
      print('❌ Erreur synchronisation messages depuis Firestore: $e');
      throw e;
    }
  }

  /// ✅ Synchronisation complète (bidirectionnelle)
  Future<void> syncAllMessageData(String schoolId) async {
    try {
      print('🔄 Synchronisation complète des messages...');
      await syncAllMessagesToFirestore(schoolId);
      await syncMessagesFromFirestore(schoolId);
      print('✅ Synchronisation complète des messages terminée');
    } catch (e) {
      print('❌ Erreur synchronisation complète: $e');
      throw e;
    }
  }

  // ==================== ACTIONS SUR LES MESSAGES ====================

  /// ✅ Marquer un message comme lu
  Future<void> markAsRead(String schoolId, String messageKey) async {
    try {
      // Mettre à jour localement
      await _dbHelper.updateMessageReadStatus(messageKey, true);
      
      // Mettre à jour dans Firestore
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('messages')
          .where('localKey', isEqualTo: messageKey)
          .get();
      
      for (var doc in snapshot.docs) {
        await doc.reference.update({
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      print('✅ Message marqué comme lu: $messageKey');
      
    } catch (e) {
      print('❌ Erreur marquage message: $e');
    }
  }

  /// ✅ Marquer un message comme important
  Future<void> toggleImportant(String schoolId, String messageKey, bool important) async {
    try {
      // Mettre à jour localement
      await _dbHelper.updateMessageImportantStatus(messageKey, important);
      
      // Mettre à jour dans Firestore
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('messages')
          .where('localKey', isEqualTo: messageKey)
          .get();
      
      for (var doc in snapshot.docs) {
        await doc.reference.update({
          'important': important,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      print('📌 Message ${important ? 'marqué comme important' : 'retiré des importants'}: $messageKey');
      
    } catch (e) {
      print('❌ Erreur marquage important: $e');
    }
  }

  /// ✅ Supprimer un message (local + Firestore)
  Future<void> deleteMessageByKey(String schoolId, String messageKey) async {
    try {
      // Supprimer localement
      await _dbHelper.deleteMessage(messageKey);
      
      // Supprimer dans Firestore
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('messages')
          .where('localKey', isEqualTo: messageKey)
          .get();
      
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      
      print('✅ Message supprimé: $messageKey');
      
    } catch (e) {
      print('❌ Erreur suppression message: $e');
    }
  }

  /// ✅ Envoyer un message (version simplifiée)
  Future<void> sendMessage({
    required String senderName,
    required String senderRole,
    required String recipientName,
    required String recipientRole,
    String? studentName,
    required String subject,
    required String content,
    required String schoolId,
    bool important = false,
  }) async {
    try {
      final message = MessageModel(
        senderName: senderName,
        senderRole: senderRole,
        recipientName: recipientName,
        recipientRole: recipientRole,
        studentName: studentName ?? '',
        subject: subject,
        content: content,
        date: DateTime.now(),
        read: false,
        important: important,
        schoolId: int.tryParse(schoolId) ?? 0,
        schoolFirestoreId: schoolId,
      );
      
      // Sauvegarder localement
      await _dbHelper.addMessage(message);
      
      // Synchroniser vers Firestore
      await createMessage(message, schoolId);
      
      print('✅ Message envoyé avec succès');
      
    } catch (e) {
      print('❌ Erreur envoi message: $e');
      throw e;
    }
  }

  // ==================== STATISTIQUES ====================

  /// ✅ Compter les messages par destinataire
  Future<Map<String, int>> countMessagesByRecipient(String schoolId) async {
    try {
      final Map<String, int> counts = {};
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('messages')
          .get();
      
      for (var doc in snapshot.docs) {
        final recipient = doc['recipientName'] ?? 'unknown';
        counts[recipient] = (counts[recipient] ?? 0) + 1;
      }
      
      return counts;
      
    } catch (e) {
      print('❌ Erreur comptage messages par destinataire: $e');
      return {};
    }
  }

  /// ✅ Compter les messages non lus par destinataire
  Future<Map<String, int>> countUnreadMessages(String schoolId) async {
    try {
      final Map<String, int> counts = {};
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('messages')
          .where('read', isEqualTo: false)
          .get();
      
      for (var doc in snapshot.docs) {
        final recipient = doc['recipientName'] ?? 'unknown';
        counts[recipient] = (counts[recipient] ?? 0) + 1;
      }
      
      return counts;
      
    } catch (e) {
      print('❌ Erreur comptage messages non lus: $e');
      return {};
    }
  }

  /// ✅ Obtenir les statistiques complètes
  Future<Map<String, dynamic>> getMessageStats(String schoolId) async {
    try {
      final byRecipient = await countMessagesByRecipient(schoolId);
      final unread = await countUnreadMessages(schoolId);
      
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('messages')
          .get();
      
      return {
        'totalMessages': snapshot.docs.length,
        'byRecipient': byRecipient,
        'unread': unread,
        'totalUnread': unread.values.fold(0, (sum, count) => sum + count),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
    } catch (e) {
      print('❌ Erreur statistiques messages: $e');
      return {};
    }
  }

  /// ✅ Écouter les statistiques en temps réel
  Stream<Map<String, dynamic>> listenToMessageStats(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('messages')
        .snapshots()
        .map((snapshot) {
          final Map<String, int> byRecipient = {};
          final Map<String, int> unread = {};
          
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final recipient = data['recipientName'] ?? 'unknown';
            byRecipient[recipient] = (byRecipient[recipient] ?? 0) + 1;
            
            if (data['read'] == false) {
              unread[recipient] = (unread[recipient] ?? 0) + 1;
            }
          }
          
          return {
            'totalMessages': snapshot.docs.length,
            'byRecipient': byRecipient,
            'unread': unread,
            'totalUnread': unread.values.fold(0, (sum, count) => sum + count),
            'lastUpdated': DateTime.now().toIso8601String(),
          };
        });
  }

  // ==================== RECHERCHE ====================

  /// ✅ Rechercher des messages par sujet
/// ✅ Rechercher des messages par sujet
Future<List<MessageModel>> searchMessagesBySubject(
  String schoolId, 
  String query, {
  String? recipientName,
}) async {
  try {
    if (query.isEmpty) return [];
    
    Query queryRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('messages')
        .where('subject', isGreaterThanOrEqualTo: query)
        .where('subject', isLessThanOrEqualTo: query + '\uf8ff');
    
    if (recipientName != null && recipientName.isNotEmpty) {
      queryRef = queryRef.where('recipientName', isEqualTo: recipientName);
    }
    
    final snapshot = await queryRef.orderBy('date', descending: true).get();

    // 🔥 CORRECTION: Caster doc.data() en Map<String, dynamic>
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return MessageModel.fromFirestore(data, doc.id);
    }).toList();

  } catch (e) {
    print('❌ Erreur recherche messages: $e');
    return [];
  }
}

  /// ✅ Rechercher des messages par expéditeur
  Future<List<MessageModel>> searchMessagesBySender(
    String schoolId, 
    String senderName
  ) async {
    try {
      final snapshot = await _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('messages')
          .where('senderName', isGreaterThanOrEqualTo: senderName)
          .where('senderName', isLessThanOrEqualTo: senderName + '\uf8ff')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return MessageModel.fromFirestore(doc.data(), doc.id);
      }).toList();

    } catch (e) {
      print('❌ Erreur recherche messages par expéditeur: $e');
      return [];
    }
  }

  /// ✅ Récupérer le nombre de messages non lus pour un utilisateur
  Future<int> getUnreadCount({
    required String schoolId,
    required String userName,
    required String userRole,
    String? studentName,
  }) async {
    try {
      final messages = await getMessagesForUser(
        schoolId: schoolId,
        userName: userName,
        userRole: userRole,
        studentName: studentName,
      );
      
      return messages.where((m) => !m.read).length;
      
    } catch (e) {
      print('❌ Erreur comptage messages non lus: $e');
      return 0;
    }
  }

  // ==================== MÉTHODES DE LOG ====================

  /// Ajouter un log système pour les messages
  Future<void> _addLog(String action, String description, String schoolId) async {
    try {
      await _firestore.collection('system_logs').add({
        'action': action,
        'actionType': 'message',
        'description': description,
        'level': 'info',
        'timestamp': FieldValue.serverTimestamp(),
        'schoolId': schoolId,
      });
    } catch (e) {
      print('⚠️ Erreur ajout log: $e');
    }
  }
}
// lib/services/message_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/message_model.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  /// Créer un message dans Firestore
  Future<String> createMessage(MessageModel message, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final docRef = _firestore.collection('messages').doc();
      final messageData = {
        'key': message.key,
        'senderName': message.senderName,
        'senderRole': message.senderRole,
        'recipientName': message.recipientName,
        'recipientRole': message.recipientRole,
        'studentName': message.studentName,
        'subject': message.subject,
        'content': message.content,
        'date': message.date.toIso8601String(),
        'read': message.read,
        'important': message.important,
        'schoolId': schoolId,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(messageData);
      print('✅ Message créé dans Firestore: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Erreur création message Firestore: $e');
      throw e;
    }
  }

  /// Synchroniser tous les messages locaux vers Firestore
  Future<void> syncAllMessagesToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des messages vers Firestore...');
      final messages = await _dbHelper.getAllMessages();
      
      int syncedCount = 0;
      for (var message in messages) {
        // Vérifier si le message existe déjà dans Firestore
        final existing = await _firestore
            .collection('messages')
            .where('key', isEqualTo: message.key)
            .get();

        if (existing.docs.isEmpty) {
          await createMessage(message, schoolId);
          syncedCount++;
        }
      }

      print('✅ Synchronisation des messages terminée: $syncedCount/${messages.length} nouveaux messages');
    } catch (e) {
      print('❌ Erreur synchronisation messages: $e');
      throw e;
    }
  }

  /// Synchroniser les messages depuis Firestore vers la base locale
  Future<void> syncMessagesFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des messages depuis Firestore...');
      final snapshot = await _firestore
          .collection('messages')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      int syncedCount = 0;
      for (var doc in snapshot.docs) {
        final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        final message = MessageModel(
          senderName: data['senderName'] as String? ?? '',
          senderRole: data['senderRole'] as String? ?? '',
          recipientName: data['recipientName'] as String? ?? '',
          recipientRole: data['recipientRole'] as String? ?? '',
          studentName: data['studentName'] as String? ?? '',
          subject: data['subject'] as String? ?? '',
          content: data['content'] as String? ?? '',
          date: data['date'] != null 
              ? DateTime.parse(data['date'] as String) 
              : DateTime.now(),
          read: data['read'] as bool? ?? false,
          important: data['important'] as bool? ?? false,
        );
        
        final existing = await _dbHelper.getMessageByKey(message.key);
        if (existing == null) {
          await _dbHelper.addMessage(message);
          syncedCount++;
        }
      }

      print('✅ Synchronisation des messages depuis Firestore terminée: $syncedCount nouveaux messages');
    } catch (e) {
      print('❌ Erreur synchronisation messages depuis Firestore: $e');
    }
  }

  /// Envoyer un message (version simplifiée)
  Future<void> sendMessage({
    required String senderName,
    required String senderRole,
    required String recipientName,
    required String recipientRole,
    String? studentName,
    required String subject,
    required String content,
    required String schoolId,
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
        important: false,
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

  /// Récupérer les messages d'un utilisateur
  Future<List<MessageModel>> getMessagesForUser({
    required String userName,
    required String userRole,
    String? studentName,
  }) async {
    try {
      final messages = await _dbHelper.getAllMessages();
      
      return messages.where((message) {
        // Si c'est un parent avec un élève spécifique
        if (studentName != null && studentName.isNotEmpty) {
          return message.recipientName == userName && 
                 message.recipientRole == userRole &&
                 message.studentName == studentName;
        }
        // Pour les autres rôles
        return message.recipientName == userName && 
               message.recipientRole == userRole;
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération messages: $e');
      return [];
    }
  }

  /// Marquer un message comme lu
  Future<void> markAsRead(String messageKey) async {
    try {
      // Mettre à jour localement
      await _dbHelper.updateMessageReadStatus(messageKey, true);
      
      // Mettre à jour dans Firestore
      final snapshot = await _firestore
          .collection('messages')
          .where('key', isEqualTo: messageKey)
          .get();
      
      for (var doc in snapshot.docs) {
        await doc.reference.update({
          'read': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      print('✅ Message marqué comme lu: $messageKey');
    } catch (e) {
      print('❌ Erreur marquage message: $e');
    }
  }

  /// Supprimer un message
  Future<void> deleteMessage(String messageKey) async {
    try {
      // Supprimer localement
      await _dbHelper.deleteMessage(messageKey);
      
      // Supprimer dans Firestore
      final snapshot = await _firestore
          .collection('messages')
          .where('key', isEqualTo: messageKey)
          .get();
      
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      
      print('✅ Message supprimé: $messageKey');
    } catch (e) {
      print('❌ Erreur suppression message: $e');
    }
  }

  /// Récupérer le nombre de messages non lus
  Future<int> getUnreadCount({
    required String userName,
    required String userRole,
    String? studentName,
  }) async {
    try {
      final messages = await getMessagesForUser(
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
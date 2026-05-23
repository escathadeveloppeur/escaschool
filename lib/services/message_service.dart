// lib/services/message_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'db_helper.dart';
import '../models/message_model.dart';

class MessageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DBHelper _dbHelper = DBHelper();

  Future<String> createMessage(MessageModel message, String schoolId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final docRef = _firestore.collection('messages').doc();
      final messageData = {
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
        'localKey': message.key,
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

  Future<void> syncAllMessagesToFirestore(String schoolId) async {
    try {
      print('🔄 Synchronisation des messages vers Firestore...');
      final messages = await _dbHelper.getAllMessages();
      
      for (var message in messages) {
        final existing = await _firestore
            .collection('messages')
            .where('localKey', isEqualTo: message.key)
            .get();

        if (existing.docs.isEmpty) {
          await createMessage(message, schoolId);
        }
      }

      print('✅ Synchronisation des messages terminée: ${messages.length}');
    } catch (e) {
      print('❌ Erreur synchronisation messages: $e');
      throw e;
    }
  }

  Future<void> syncMessagesFromFirestore(String schoolId) async {
    try {
      print('📥 Synchronisation des messages depuis Firestore...');
      final snapshot = await _firestore
          .collection('messages')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final message = MessageModel(
          senderName: data['senderName'] ?? '',
          senderRole: data['senderRole'] ?? '',
          recipientName: data['recipientName'] ?? '',
          recipientRole: data['recipientRole'] ?? '',
          studentName: data['studentName'] ?? '',
          subject: data['subject'] ?? '',
          content: data['content'] ?? '',
          date: data['date'] != null ? DateTime.parse(data['date']) : DateTime.now(),
          read: data['read'] ?? false,
          important: data['important'] ?? false,
          
        );
        
        final existing = await _dbHelper.getMessageByKey(message.key);
        if (existing == null) {
          await _dbHelper.addMessage(message);
        }
      }

      print('✅ Synchronisation des messages depuis Firestore terminée: ${snapshot.docs.length}');
    } catch (e) {
      print('❌ Erreur synchronisation messages depuis Firestore: $e');
    }
  }
}
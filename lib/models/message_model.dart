// lib/models/message_model.dart

import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'message_model.g.dart';

@HiveType(typeId: 10)
class MessageModel extends HiveObject {
  @HiveField(0)
  final String senderName;

  @HiveField(1)
  final String senderRole;

  @HiveField(2)
  final String recipientName;

  @HiveField(3)
  final String recipientRole;

  @HiveField(4)
  final String studentName;

  @HiveField(5)
  final String subject;

  @HiveField(6)
  final String content;

  @HiveField(7)
  final DateTime date;

  @HiveField(8)
  bool read;

  @HiveField(9)
  final bool important;

  @HiveField(10)
  String? firestoreId;

  @HiveField(11)
  String? replyTo;

  MessageModel({
    required this.senderName,
    required this.senderRole,
    required this.recipientName,
    required this.recipientRole,
    required this.studentName,
    required this.subject,
    required this.content,
    required this.date,
    this.read = false,
    this.important = false,
    this.firestoreId,
    this.replyTo,
  });

  // Constructeur depuis Firestore
  factory MessageModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return MessageModel(
      senderName: data['senderName'] ?? '',
      senderRole: data['senderRole'] ?? '',
      recipientName: data['recipientName'] ?? '',
      recipientRole: data['recipientRole'] ?? '',
      studentName: data['studentName'] ?? '',
      subject: data['subject'] ?? '',
      content: data['content'] ?? '',
      date: data['date'] != null ? (data['date'] as Timestamp).toDate() : DateTime.now(),
      read: data['read'] ?? false,
      important: data['important'] ?? false,
      firestoreId: docId,
      replyTo: data['replyTo'],
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'senderName': senderName,
      'senderRole': senderRole,
      'recipientName': recipientName,
      'recipientRole': recipientRole,
      'studentName': studentName,
      'subject': subject,
      'content': content,
      'date': FieldValue.serverTimestamp(),
      'read': read,
      'important': important,
      'replyTo': replyTo,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Convertir en Map pour affichage
  Map<String, dynamic> toMap() {
    return {
      'id': key,
      'senderName': senderName,
      'senderRole': senderRole,
      'recipientName': recipientName,
      'recipientRole': recipientRole,
      'studentName': studentName,
      'subject': subject,
      'content': content,
      'date': date,
      'read': read,
      'important': important,
      'firestoreId': firestoreId,
      'replyTo': replyTo,
    };
  }

  // Constructeur depuis Map
  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      senderName: map['senderName'] ?? '',
      senderRole: map['senderRole'] ?? '',
      recipientName: map['recipientName'] ?? '',
      recipientRole: map['recipientRole'] ?? '',
      studentName: map['studentName'] ?? '',
      subject: map['subject'] ?? '',
      content: map['content'] ?? '',
      date: map['date'] ?? DateTime.now(),
      read: map['read'] ?? false,
      important: map['important'] ?? false,
      firestoreId: map['firestoreId'],
      replyTo: map['replyTo'],
    );
  }
}
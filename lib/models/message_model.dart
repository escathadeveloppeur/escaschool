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

  // ===============================================================
  // NOUVEAUX CHAMPS POUR LA STRUCTURE HIÉRARCHIQUE
  // ===============================================================
  
  @HiveField(12)
  String? schoolFirestoreId; // ID Firestore de l'école
  
  @HiveField(13)
  String? studentId; // ID Firestore de l'étudiant
  
  @HiveField(14)
  String? messageFirestoreId; // ID Firestore du message (alias)
  
  @HiveField(15)
  String? localKey; // Clé locale pour la synchronisation
  
  @HiveField(16)
  int? schoolId; // ID local de l'école
  
  @HiveField(17)
  DateTime? readAt; // Date de lecture
  
  @HiveField(18)
  String? senderId; // ID Firestore de l'expéditeur
  
  @HiveField(19)
  String? recipientId; // ID Firestore du destinataire

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
    this.schoolFirestoreId,
    this.studentId,
    this.messageFirestoreId,
    this.localKey,
    this.schoolId,
    this.readAt,
    this.senderId,
    this.recipientId,
  });

  // ===============================================================
  // PROPRIÉTÉS CALCULÉES
  // ===============================================================
  
  bool get isRead => read;
  
  bool get isUnread => !read;
  
  bool get isImportant => important;
  
  String get key => localKey ?? '${senderName}_${date.millisecondsSinceEpoch}';
  
  bool get hasFirestoreId => messageFirestoreId != null && messageFirestoreId!.isNotEmpty;

  // ===============================================================
  // CONSTRUCTEUR DEPUIS FIRESTORE
  // ===============================================================
  
  /// Créer une instance depuis Firestore
  factory MessageModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return MessageModel(
      senderName: data['senderName'] ?? '',
      senderRole: data['senderRole'] ?? '',
      recipientName: data['recipientName'] ?? '',
      recipientRole: data['recipientRole'] ?? '',
      studentName: data['studentName'] ?? '',
      studentId: data['studentId'],
      subject: data['subject'] ?? '',
      content: data['content'] ?? '',
      date: data['date'] != null 
          ? (data['date'] as Timestamp).toDate() 
          : DateTime.now(),
      read: data['read'] ?? false,
      important: data['important'] ?? false,
      firestoreId: docId,
      replyTo: data['replyTo'],
      schoolFirestoreId: data['schoolFirestoreId'],
      messageFirestoreId: docId,
      localKey: data['localKey'] ?? '${data['senderName']}_${DateTime.now().millisecondsSinceEpoch}',
      schoolId: data['schoolId'],
      readAt: data['readAt'] != null 
          ? (data['readAt'] as Timestamp).toDate() 
          : null,
      senderId: data['senderId'],
      recipientId: data['recipientId'],
    );
  }

  // ===============================================================
  // CONVERSION POUR FIRESTORE
  // ===============================================================
  
  /// Convertir en Map pour Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'senderName': senderName,
      'senderRole': senderRole,
      'recipientName': recipientName,
      'recipientRole': recipientRole,
      'studentName': studentName,
      'studentId': studentId,
      'subject': subject,
      'content': content,
      'date': Timestamp.fromDate(date),
      'read': read,
      'important': important,
      'replyTo': replyTo,
      'schoolId': schoolId,
      'schoolFirestoreId': schoolFirestoreId,
      'senderId': senderId,
      'recipientId': recipientId,
      'localKey': localKey ?? key,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ===============================================================
  // CONVERSION POUR HIVE (LOCAL)
  // ===============================================================
  
  /// Convertir en Map pour Hive
  Map<String, dynamic> toMap() {
    return {
      'id': key,
      'senderName': senderName,
      'senderRole': senderRole,
      'recipientName': recipientName,
      'recipientRole': recipientRole,
      'studentName': studentName,
      'studentId': studentId,
      'subject': subject,
      'content': content,
      'date': date,
      'read': read,
      'important': important,
      'firestoreId': firestoreId,
      'replyTo': replyTo,
      'schoolFirestoreId': schoolFirestoreId,
      'messageFirestoreId': messageFirestoreId,
      'localKey': localKey,
      'schoolId': schoolId,
      'readAt': readAt,
      'senderId': senderId,
      'recipientId': recipientId,
    };
  }

  /// Créer une instance depuis Hive
  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      senderName: map['senderName'] ?? '',
      senderRole: map['senderRole'] ?? '',
      recipientName: map['recipientName'] ?? '',
      recipientRole: map['recipientRole'] ?? '',
      studentName: map['studentName'] ?? '',
      studentId: map['studentId'],
      subject: map['subject'] ?? '',
      content: map['content'] ?? '',
      date: map['date'] ?? DateTime.now(),
      read: map['read'] ?? false,
      important: map['important'] ?? false,
      firestoreId: map['firestoreId'],
      replyTo: map['replyTo'],
      schoolFirestoreId: map['schoolFirestoreId'],
      messageFirestoreId: map['messageFirestoreId'],
      localKey: map['localKey'],
      schoolId: map['schoolId'],
      readAt: map['readAt'],
      senderId: map['senderId'],
      recipientId: map['recipientId'],
    );
  }

  // ===============================================================
  // MÉTHODES UTILITAIRES
  // ===============================================================
  
  /// Retourne une copie avec des champs modifiés
  MessageModel copyWith({
    String? senderName,
    String? senderRole,
    String? recipientName,
    String? recipientRole,
    String? studentName,
    String? subject,
    String? content,
    DateTime? date,
    bool? read,
    bool? important,
    String? firestoreId,
    String? replyTo,
    String? schoolFirestoreId,
    String? studentId,
    String? messageFirestoreId,
    String? localKey,
    int? schoolId,
    DateTime? readAt,
    String? senderId,
    String? recipientId,
  }) {
    return MessageModel(
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      recipientName: recipientName ?? this.recipientName,
      recipientRole: recipientRole ?? this.recipientRole,
      studentName: studentName ?? this.studentName,
      subject: subject ?? this.subject,
      content: content ?? this.content,
      date: date ?? this.date,
      read: read ?? this.read,
      important: important ?? this.important,
      firestoreId: firestoreId ?? this.firestoreId,
      replyTo: replyTo ?? this.replyTo,
      schoolFirestoreId: schoolFirestoreId ?? this.schoolFirestoreId,
      studentId: studentId ?? this.studentId,
      messageFirestoreId: messageFirestoreId ?? this.messageFirestoreId,
      localKey: localKey ?? this.localKey,
      schoolId: schoolId ?? this.schoolId,
      readAt: readAt ?? this.readAt,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
    );
  }
}

// ===============================================================
// EXTENSION POUR FACILITER LA MANIPULATION DES MESSAGES
// ===============================================================

extension MessageModelExtension on List<MessageModel> {
  /// Filtre les messages par expéditeur
  List<MessageModel> filterBySender(String senderName) {
    return where((m) => m.senderName == senderName).toList();
  }

  /// Filtre les messages par destinataire
  List<MessageModel> filterByRecipient(String recipientName) {
    return where((m) => m.recipientName == recipientName).toList();
  }

  /// Filtre les messages par rôle de destinataire
  List<MessageModel> filterByRecipientRole(String role) {
    return where((m) => m.recipientRole == role).toList();
  }

  /// Filtre les messages par étudiant
  List<MessageModel> filterByStudent(String studentName) {
    return where((m) => m.studentName == studentName).toList();
  }

  /// Filtre les messages par étudiant ID
  List<MessageModel> filterByStudentId(String studentId) {
    return where((m) => m.studentId == studentId).toList();
  }

  /// Filtre les messages par école
  List<MessageModel> filterBySchool(String schoolFirestoreId) {
    return where((m) => m.schoolFirestoreId == schoolFirestoreId).toList();
  }

  /// Filtre les messages par sujet
  List<MessageModel> filterBySubject(String query) {
    if (query.isEmpty) return this;
    return where((m) => 
      m.subject.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  /// Filtre les messages par contenu
  List<MessageModel> filterByContent(String query) {
    if (query.isEmpty) return this;
    return where((m) => 
      m.content.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  /// Filtre les messages non lus
  List<MessageModel> getUnread() {
    return where((m) => m.isUnread).toList();
  }

  /// Filtre les messages lus
  List<MessageModel> getRead() {
    return where((m) => m.isRead).toList();
  }

  /// Filtre les messages importants
  List<MessageModel> getImportant() {
    return where((m) => m.isImportant).toList();
  }

  /// Filtre les messages par période
  List<MessageModel> filterByPeriod(DateTime startDate, DateTime endDate) {
    return where((m) => 
      m.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
      m.date.isBefore(endDate.add(const Duration(days: 1)))
    ).toList();
  }

  /// Groupe les messages par expéditeur
  Map<String, List<MessageModel>> groupBySender() {
    final Map<String, List<MessageModel>> result = {};
    for (var m in this) {
      if (!result.containsKey(m.senderName)) {
        result[m.senderName] = [];
      }
      result[m.senderName]!.add(m);
    }
    return result;
  }

  /// Groupe les messages par destinataire
  Map<String, List<MessageModel>> groupByRecipient() {
    final Map<String, List<MessageModel>> result = {};
    for (var m in this) {
      if (!result.containsKey(m.recipientName)) {
        result[m.recipientName] = [];
      }
      result[m.recipientName]!.add(m);
    }
    return result;
  }

  /// Groupe les messages par étudiant
  Map<String, List<MessageModel>> groupByStudent() {
    final Map<String, List<MessageModel>> result = {};
    for (var m in this) {
      if (!result.containsKey(m.studentName)) {
        result[m.studentName] = [];
      }
      result[m.studentName]!.add(m);
    }
    return result;
  }

  /// Groupe les messages par statut de lecture
  Map<String, List<MessageModel>> groupByReadStatus() {
    return {
      'read': getRead(),
      'unread': getUnread(),
    };
  }

  /// Récupère les statistiques des messages
  Map<String, dynamic> getStatistics() {
    return {
      'total': length,
      'unread': getUnread().length,
      'read': getRead().length,
      'important': getImportant().length,
      'bySender': groupBySender().map((key, value) => MapEntry(key, value.length)),
      'byRecipient': groupByRecipient().map((key, value) => MapEntry(key, value.length)),
    };
  }

  /// Récupère les messages non synchronisés
  List<MessageModel> getUnsynced() {
    return where((m) => !m.hasFirestoreId).toList();
  }

  /// Trie les messages par date (plus récents en premier)
  List<MessageModel> sortedByDateDesc() {
    final list = [...this];
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Trie les messages par date (plus anciens en premier)
  List<MessageModel> sortedByDateAsc() {
    final list = [...this];
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  /// Trie les messages par expéditeur
  List<MessageModel> sortedBySender() {
    final list = [...this];
    list.sort((a, b) => a.senderName.compareTo(b.senderName));
    return list;
  }

  /// Trie les messages par sujet
  List<MessageModel> sortedBySubject() {
    final list = [...this];
    list.sort((a, b) => a.subject.compareTo(b.subject));
    return list;
  }
}
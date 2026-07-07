// lib/models/online_exam_model.dart

import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // ✅ Pour Colors et Icons

part 'online_exam_model.g.dart';

@HiveType(typeId: 12)
class OnlineExamModel extends HiveObject {
  @HiveField(0)
  final int id;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final String description;
  
  @HiveField(3)
  final String subject;
  
  @HiveField(4)
  final String className;
  
  @HiveField(5)
  final int classId; // ID local (Hive) - conservé pour compatibilité
  
  @HiveField(6)
  final int professorId; // ID local (Hive) - conservé pour compatibilité
  
  @HiveField(7)
  final DateTime startDate;
  
  @HiveField(8)
  final DateTime endDate;
  
  @HiveField(9)
  final int duration; // en minutes
  
  @HiveField(10)
  final int totalPoints;
  
  @HiveField(11)
  final List<Map<String, dynamic>> questions;
  
  @HiveField(12)
  final String status; // 'upcoming', 'ongoing', 'completed', 'cancelled'
  
  @HiveField(13)
  final DateTime createdAt;

  // ===============================================================
  // NOUVEAUX CHAMPS POUR LA STRUCTURE HIÉRARCHIQUE
  // ===============================================================
  
  @HiveField(14)
  String? schoolFirestoreId; // ID Firestore de l'école
  
  @HiveField(15)
  String? examFirestoreId; // ID Firestore de l'examen
  
  @HiveField(16)
  String? classFirestoreId; // ID Firestore de la classe (pour les sous-collections)
  
  @HiveField(17)
  String? professorFirestoreId; // ID Firestore du professeur
  
  @HiveField(18)
  String? localKey; // Clé locale pour la synchronisation
  
  @HiveField(19)
  int? schoolId; // ID local de l'école

  // ===============================================================
  // CHAMPS SUPPLÉMENTAIRES POUR PLUS DE FONCTIONNALITÉS
  // ===============================================================
  
  @HiveField(20)
  int? enrolledStudents; // Nombre d'étudiants inscrits
  
  @HiveField(21)
  double? averageScore; // Score moyen des étudiants
  
  @HiveField(22)
  bool? isPublished; // Statut de publication
  @HiveField(23)
  DateTime updatedAt;

  OnlineExamModel({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.className,
    required this.classId,
    required this.professorId,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.totalPoints,
    required this.questions,
    required this.status,
    required this.createdAt,
    this.schoolFirestoreId,
    this.examFirestoreId,
    this.classFirestoreId,
    this.professorFirestoreId,
    this.localKey,
    this.schoolId,
    this.enrolledStudents,
    this.averageScore,
    this.isPublished,
    required this.updatedAt,
  });

  // ===============================================================
  // PROPRIÉTÉS CALCULÉES
  // ===============================================================
  
  bool get isUpcoming => status == 'upcoming';
  bool get isOngoing => status == 'ongoing';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  
  int get questionCount => questions.length;
  
  bool get hasQuestions => questions.isNotEmpty;
  
  bool get hasFirestoreId => examFirestoreId != null && examFirestoreId!.isNotEmpty;
  
  bool get isPublishedStatus => isPublished ?? false;
  
  int get totalStudents => enrolledStudents ?? 0;
  
  double get averageScoreValue => averageScore ?? 0.0;
  
  String get statusLabel {
    switch (status) {
      case 'upcoming': return '📅 À venir';
      case 'ongoing': return '🔄 En cours';
      case 'completed': return '✅ Terminé';
      case 'cancelled': return '❌ Annulé';
      default: return status;
    }
  }
  
  Color get statusColor {
    switch (status) {
      case 'upcoming': return Colors.blue;
      case 'ongoing': return Colors.orange;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }
  
  String get durationLabel {
    final hours = duration ~/ 60;
    final minutes = duration % 60;
    if (hours > 0) {
      return '$hours h ${minutes > 0 ? '$minutes min' : ''}';
    }
    return '$minutes min';
  }

  // ===============================================================
  // CONSTRUCTEUR DEPUIS FIRESTORE
  // ===============================================================
  
  /// Créer une instance depuis Firestore
  factory OnlineExamModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return OnlineExamModel(
      id: data['id'] ?? 0,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      subject: data['subject'] ?? '',
      className: data['className'] ?? '',
      classId: data['classId'] ?? 0,
      professorId: data['professorId'] ?? 0,
      startDate: data['startDate'] != null 
          ? DateTime.parse(data['startDate']) 
          : DateTime.now(),
      endDate: data['endDate'] != null 
          ? DateTime.parse(data['endDate']) 
          : DateTime.now(),
      duration: data['duration'] ?? 60,
      totalPoints: data['totalPoints'] ?? 0,
      questions: List<Map<String, dynamic>>.from(data['questions'] ?? []),
      status: data['status'] ?? 'upcoming',
      createdAt: data['createdAt'] != null 
          ? DateTime.parse(data['createdAt']) 
          : DateTime.now(),
      schoolFirestoreId: data['schoolFirestoreId'],
      examFirestoreId: docId,
      classFirestoreId: data['classFirestoreId'] ?? data['classId']?.toString(),
      professorFirestoreId: data['professorFirestoreId'] ?? data['professorId']?.toString(),
      localKey: data['localKey'] ?? data['id']?.toString(),
      schoolId: data['schoolId'],
      enrolledStudents: data['enrolledStudents'] ?? 0,
      averageScore: (data['averageScore'] ?? 0.0).toDouble(),
      isPublished: data['isPublished'] ?? false,
      updatedAt: data['updatedAt'] != null 
    ? DateTime.parse(data['updatedAt']) 
    : DateTime.now(),
    );
  }

  // ===============================================================
  // CONVERSION POUR FIRESTORE
  // ===============================================================
  
  /// Convertir en Map pour Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'subject': subject,
      'className': className,
      'classId': classId,
      'classFirestoreId': classFirestoreId,
      'professorId': professorId,
      'professorFirestoreId': professorFirestoreId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'duration': duration,
      'totalPoints': totalPoints,
      'questions': questions,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'schoolId': schoolId,
      'schoolFirestoreId': schoolFirestoreId,
      'localKey': localKey ?? id.toString(),
      'enrolledStudents': enrolledStudents ?? 0,
      'averageScore': averageScore ?? 0.0,
      'isPublished': isPublished ?? false,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // ===============================================================
  // CONVERSION POUR HIVE (LOCAL)
  // ===============================================================
  
  /// Convertir en Map pour Hive
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'subject': subject,
      'className': className,
      'classId': classId,
      'professorId': professorId,
      'startDate': startDate,
      'endDate': endDate,
      'duration': duration,
      'totalPoints': totalPoints,
      'questions': questions,
      'status': status,
      'createdAt': createdAt,
      'schoolFirestoreId': schoolFirestoreId,
      'examFirestoreId': examFirestoreId,
      'classFirestoreId': classFirestoreId,
      'professorFirestoreId': professorFirestoreId,
      'localKey': localKey,
      'schoolId': schoolId,
      'enrolledStudents': enrolledStudents,
      'averageScore': averageScore,
      'isPublished': isPublished,
      'updatedAt':updatedAt,
    };
  }

  /// Créer une instance depuis Hive
  factory OnlineExamModel.fromMap(Map<String, dynamic> map) {
    return OnlineExamModel(
      id: map['id'] ?? 0,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      subject: map['subject'] ?? '',
      className: map['className'] ?? '',
      classId: map['classId'] ?? 0,
      professorId: map['professorId'] ?? 0,
      startDate: map['startDate'] ?? DateTime.now(),
      endDate: map['endDate'] ?? DateTime.now(),
      duration: map['duration'] ?? 60,
      totalPoints: map['totalPoints'] ?? 0,
      questions: List<Map<String, dynamic>>.from(map['questions'] ?? []),
      status: map['status'] ?? 'upcoming',
      createdAt: map['createdAt'] ?? DateTime.now(),
      schoolFirestoreId: map['schoolFirestoreId'],
      examFirestoreId: map['examFirestoreId'],
      classFirestoreId: map['classFirestoreId'],
      professorFirestoreId: map['professorFirestoreId'],
      localKey: map['localKey'],
      schoolId: map['schoolId'],
      enrolledStudents: map['enrolledStudents'],
      averageScore: map['averageScore'],
      isPublished: map['isPublished'],
      updatedAt: map['updatedAt'] ?? DateTime.now(),
    );
  }

  // ===============================================================
  // MÉTHODES UTILITAIRES
  // ===============================================================
  
  /// Retourne une copie avec des champs modifiés
  OnlineExamModel copyWith({
    int? id,
    String? title,
    String? description,
    String? subject,
    String? className,
    int? classId,
    int? professorId,
    DateTime? startDate,
    DateTime? endDate,
    int? duration,
    int? totalPoints,
    List<Map<String, dynamic>>? questions,
    String? status,
    DateTime? createdAt,
    String? schoolFirestoreId,
    String? examFirestoreId,
    String? classFirestoreId,
    String? professorFirestoreId,
    String? localKey,
    int? schoolId,
    int? enrolledStudents,
    double? averageScore,
    bool? isPublished,
    DateTime? updatedAt,
  }) {
    return OnlineExamModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      className: className ?? this.className,
      classId: classId ?? this.classId,
      professorId: professorId ?? this.professorId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      duration: duration ?? this.duration,
      totalPoints: totalPoints ?? this.totalPoints,
      questions: questions ?? this.questions,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      schoolFirestoreId: schoolFirestoreId ?? this.schoolFirestoreId,
      examFirestoreId: examFirestoreId ?? this.examFirestoreId,
      classFirestoreId: classFirestoreId ?? this.classFirestoreId,
      professorFirestoreId: professorFirestoreId ?? this.professorFirestoreId,
      localKey: localKey ?? this.localKey,
      schoolId: schoolId ?? this.schoolId,
      enrolledStudents: enrolledStudents ?? this.enrolledStudents,
      averageScore: averageScore ?? this.averageScore,
      isPublished: isPublished ?? this.isPublished,
      updatedAt:updatedAt ?? this.updatedAt,
      
    );
  }
}

// ===============================================================
// EXTENSION POUR FACILITER LA MANIPULATION DES EXAMENS
// ===============================================================

extension OnlineExamModelExtension on List<OnlineExamModel> {
  /// Filtre les examens par classe (local ID)
  List<OnlineExamModel> filterByClass(int classId) {
    return where((e) => e.classId == classId).toList();
  }

  /// Filtre les examens par classe Firestore ID
  List<OnlineExamModel> filterByClassFirestore(String classFirestoreId) {
    return where((e) => e.classFirestoreId == classFirestoreId).toList();
  }

  /// Filtre les examens par matière
  List<OnlineExamModel> filterBySubject(String subject) {
    return where((e) => e.subject == subject).toList();
  }

  /// Filtre les examens par statut
  List<OnlineExamModel> filterByStatus(String status) {
    return where((e) => e.status == status).toList();
  }

  /// Filtre les examens à venir
  List<OnlineExamModel> getUpcoming() {
    return where((e) => e.isUpcoming).toList();
  }

  /// Filtre les examens en cours
  List<OnlineExamModel> getOngoing() {
    return where((e) => e.isOngoing).toList();
  }

  /// Filtre les examens terminés
  List<OnlineExamModel> getCompleted() {
    return where((e) => e.isCompleted).toList();
  }

  /// Filtre les examens annulés
  List<OnlineExamModel> getCancelled() {
    return where((e) => e.isCancelled).toList();
  }

  /// Filtre les examens publiés
  List<OnlineExamModel> getPublished() {
    return where((e) => e.isPublishedStatus).toList();
  }

  /// Filtre les examens par école
  List<OnlineExamModel> filterBySchool(String schoolFirestoreId) {
    return where((e) => e.schoolFirestoreId == schoolFirestoreId).toList();
  }

  /// Filtre les examens par période
  List<OnlineExamModel> filterByPeriod(DateTime startDate, DateTime endDate) {
    return where((e) => 
      e.startDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
      e.startDate.isBefore(endDate.add(const Duration(days: 1)))
    ).toList();
  }

  /// Filtre les examens par date de début
  List<OnlineExamModel> filterByStartDate(DateTime date) {
    return where((e) => 
      e.startDate.year == date.year &&
      e.startDate.month == date.month &&
      e.startDate.day == date.day
    ).toList();
  }

  /// Groupe les examens par statut
  Map<String, List<OnlineExamModel>> groupByStatus() {
    final Map<String, List<OnlineExamModel>> result = {};
    for (var e in this) {
      if (!result.containsKey(e.status)) {
        result[e.status] = [];
      }
      result[e.status]!.add(e);
    }
    return result;
  }

  /// Groupe les examens par matière
  Map<String, List<OnlineExamModel>> groupBySubject() {
    final Map<String, List<OnlineExamModel>> result = {};
    for (var e in this) {
      if (!result.containsKey(e.subject)) {
        result[e.subject] = [];
      }
      result[e.subject]!.add(e);
    }
    return result;
  }

  /// Groupe les examens par classe
  Map<String, List<OnlineExamModel>> groupByClass() {
    final Map<String, List<OnlineExamModel>> result = {};
    for (var e in this) {
      final key = e.classFirestoreId ?? e.classId.toString();
      if (!result.containsKey(key)) {
        result[key] = [];
      }
      result[key]!.add(e);
    }
    return result;
  }

  /// Calcule le score moyen des examens
  double getAverageScore() {
    if (isEmpty) return 0.0;
    final total = fold(0.0, (sum, e) => sum + (e.averageScore ?? 0.0));
    return total / length;
  }

  /// Récupère les statistiques
  Map<String, dynamic> getStatistics() {
    return {
      'total': length,
      'upcoming': getUpcoming().length,
      'ongoing': getOngoing().length,
      'completed': getCompleted().length,
      'cancelled': getCancelled().length,
      'published': getPublished().length,
      'bySubject': groupBySubject().map((key, value) => MapEntry(key, value.length)),
      'byStatus': groupByStatus().map((key, value) => MapEntry(key, value.length)),
      'totalQuestions': fold(0, (sum, e) => sum + e.questionCount),
      'averageScore': getAverageScore(),
    };
  }

  /// Récupère les examens non synchronisés
  List<OnlineExamModel> getUnsynced() {
    return where((e) => !e.hasFirestoreId).toList();
  }

  /// Trie les examens par date de début (plus récents en premier)
  List<OnlineExamModel> sortedByStartDateDesc() {
    final list = [...this];
    list.sort((a, b) => b.startDate.compareTo(a.startDate));
    return list;
  }

  /// Trie les examens par date de début (plus anciens en premier)
  List<OnlineExamModel> sortedByStartDateAsc() {
    final list = [...this];
    list.sort((a, b) => a.startDate.compareTo(b.startDate));
    return list;
  }

  /// Trie les examens par titre
  List<OnlineExamModel> sortedByTitle() {
    final list = [...this];
    list.sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  /// Trie les examens par nombre de questions
  List<OnlineExamModel> sortedByQuestionCount() {
    final list = [...this];
    list.sort((a, b) => b.questionCount.compareTo(a.questionCount));
    return list;
  }

  /// Trie les examens par statut (upcoming -> ongoing -> completed -> cancelled)
  List<OnlineExamModel> sortedByStatus() {
    final statusOrder = {
      'upcoming': 0,
      'ongoing': 1,
      'completed': 2,
      'cancelled': 3,
    };
    final list = [...this];
    list.sort((a, b) => (statusOrder[a.status] ?? 99).compareTo(statusOrder[b.status] ?? 99));
    return list;
  }
}
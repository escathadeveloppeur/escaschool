// lib/models/exam_result_model.dart

import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // ✅ Pour Colors et Icons

part 'exam_result_model.g.dart';

@HiveType(typeId: 13)
class ExamResultModel extends HiveObject {
  @HiveField(0)
  final int examId; // ID local - conservé pour compatibilité
  
  @HiveField(1)
  final int studentId; // ID local - conservé pour compatibilité
  
  @HiveField(2)
  final String studentName;
  
  @HiveField(3)
  final int score;
  
  @HiveField(4)
  final int totalPoints;
  
  @HiveField(5)
  final List<Map<String, dynamic>> answers;
  
  @HiveField(6)
  final DateTime submittedAt;
  
  @HiveField(7)
  final bool isGraded;

  // ===============================================================
  // NOUVEAUX CHAMPS POUR LA STRUCTURE HIÉRARCHIQUE
  // ===============================================================
  
  @HiveField(8)
  String? examFirestoreId; // ID Firestore de l'examen
  
  @HiveField(9)
  String? studentFirestoreId; // ID Firestore de l'étudiant
  
  @HiveField(10)
  String? resultFirestoreId; // ID Firestore du résultat
  
  @HiveField(11)
  String? localKey; // Clé locale pour la synchronisation
  
  @HiveField(12)
  String? schoolId; // ID de l'école
  
  @HiveField(13)
  String? schoolFirestoreId; // ID Firestore de l'école
  
  @HiveField(14)
  double? percentage; // Pourcentage calculé

  ExamResultModel({
    required this.examId,
    required this.studentId,
    required this.studentName,
    required this.score,
    required this.totalPoints,
    required this.answers,
    required this.submittedAt,
    this.isGraded = false,
    this.examFirestoreId,
    this.studentFirestoreId,
    this.resultFirestoreId,
    this.localKey,
    this.schoolId,
    this.schoolFirestoreId,
    this.percentage,
  });

  // ===============================================================
  // PROPRIÉTÉS CALCULÉES
  // ===============================================================
  
  double get percentageValue => totalPoints > 0 ? (score / totalPoints) * 100 : 0.0;
  
  bool get hasFirestoreId => resultFirestoreId != null && resultFirestoreId!.isNotEmpty;
  
  bool get isPassing => percentageValue >= 60;
  
  bool get isExcellent => percentageValue >= 90;
  
  bool get isGood => percentageValue >= 75 && percentageValue < 90;
  
  bool get isAverage => percentageValue >= 50 && percentageValue < 75;
  
  bool get isFail => percentageValue < 50;
  
  String get gradeLabel {
    if (isExcellent) return '🏆 Excellent';
    if (isGood) return '👍 Très bien';
    if (isAverage) return '📊 Moyen';
    if (isFail) return '❌ Insuffisant';
    return '📖 En cours';
  }
  
  Color get gradeColor {
    if (isExcellent) return Colors.green;
    if (isGood) return Colors.lightGreen;
    if (isAverage) return Colors.orange;
    if (isFail) return Colors.red;
    return Colors.grey;
  }
  
  String get scoreLabel => '$score / $totalPoints';

  // ===============================================================
  // CONSTRUCTEUR DEPUIS FIRESTORE
  // ===============================================================
  
  /// Créer une instance depuis Firestore
  factory ExamResultModel.fromFirestore(Map<String, dynamic> data, String docId) {
    final score = (data['score'] ?? 0).toInt();
    final totalPoints = data['totalPoints'] ?? 0;
    final percentage = totalPoints > 0 ? (score / totalPoints) * 100 : 0.0;
    
    return ExamResultModel(
      examId: data['examId'] ?? 0,
      studentId: data['studentId'] ?? 0,
      studentName: data['studentName'] ?? '',
      score: score,
      totalPoints: totalPoints,
      answers: List<Map<String, dynamic>>.from(data['answers'] ?? []),
      submittedAt: data['submittedAt'] != null 
          ? (data['submittedAt'] as Timestamp).toDate()
          : DateTime.now(),
      isGraded: data['isGraded'] ?? false,
      examFirestoreId: data['examFirestoreId'],
      studentFirestoreId: data['studentFirestoreId'],
      resultFirestoreId: docId,
      localKey: data['localKey'] ?? '${data['examId']}_${data['studentId']}',
      schoolId: data['schoolId']?.toString(),
      schoolFirestoreId: data['schoolFirestoreId'],
      percentage: percentage,
    );
  }

  // ===============================================================
  // CONVERSION POUR FIRESTORE
  // ===============================================================
  
  /// Convertir en Map pour Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'examId': examId,
      'examFirestoreId': examFirestoreId,
      'studentId': studentId,
      'studentFirestoreId': studentFirestoreId,
      'studentName': studentName,
      'score': score,
      'totalPoints': totalPoints,
      'answers': answers,
      'submittedAt': submittedAt.toIso8601String(),
      'isGraded': isGraded,
      'percentage': percentageValue,
      'schoolId': schoolId,
      'schoolFirestoreId': schoolFirestoreId,
      'localKey': localKey ?? '${examId}_${studentId}',
    };
  }

  // ===============================================================
  // CONVERSION POUR HIVE (LOCAL)
  // ===============================================================
  
  /// Convertir en Map pour Hive
  Map<String, dynamic> toMap() {
    return {
      'examId': examId,
      'examFirestoreId': examFirestoreId,
      'studentId': studentId,
      'studentFirestoreId': studentFirestoreId,
      'studentName': studentName,
      'score': score,
      'totalPoints': totalPoints,
      'answers': answers,
      'submittedAt': submittedAt,
      'isGraded': isGraded,
      'resultFirestoreId': resultFirestoreId,
      'localKey': localKey,
      'schoolId': schoolId,
      'schoolFirestoreId': schoolFirestoreId,
      'percentage': percentage,
    };
  }

  /// Créer une instance depuis Hive
  factory ExamResultModel.fromMap(Map<String, dynamic> map) {
    final score = (map['score'] ?? 0).toInt();
    final totalPoints = map['totalPoints'] ?? 0;
    final percentage = totalPoints > 0 ? (score / totalPoints) * 100 : 0.0;
    
    return ExamResultModel(
      examId: map['examId'] ?? 0,
      studentId: map['studentId'] ?? 0,
      studentName: map['studentName'] ?? '',
      score: score,
      totalPoints: totalPoints,
      answers: List<Map<String, dynamic>>.from(map['answers'] ?? []),
      submittedAt: map['submittedAt'] ?? DateTime.now(),
      isGraded: map['isGraded'] ?? false,
      examFirestoreId: map['examFirestoreId'],
      studentFirestoreId: map['studentFirestoreId'],
      resultFirestoreId: map['resultFirestoreId'],
      localKey: map['localKey'],
      schoolId: map['schoolId']?.toString(),
      schoolFirestoreId: map['schoolFirestoreId'],
      percentage: map['percentage'] ?? percentage,
    );
  }

  // ===============================================================
  // MÉTHODES UTILITAIRES
  // ===============================================================
  
  /// Retourne une copie avec des champs modifiés
  ExamResultModel copyWith({
    int? examId,
    int? studentId,
    String? studentName,
    int? score,
    int? totalPoints,
    List<Map<String, dynamic>>? answers,
    DateTime? submittedAt,
    bool? isGraded,
    String? examFirestoreId,
    String? studentFirestoreId,
    String? resultFirestoreId,
    String? localKey,
    String? schoolId,
    String? schoolFirestoreId,
    double? percentage,
  }) {
    return ExamResultModel(
      examId: examId ?? this.examId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      score: score ?? this.score,
      totalPoints: totalPoints ?? this.totalPoints,
      answers: answers ?? this.answers,
      submittedAt: submittedAt ?? this.submittedAt,
      isGraded: isGraded ?? this.isGraded,
      examFirestoreId: examFirestoreId ?? this.examFirestoreId,
      studentFirestoreId: studentFirestoreId ?? this.studentFirestoreId,
      resultFirestoreId: resultFirestoreId ?? this.resultFirestoreId,
      localKey: localKey ?? this.localKey,
      schoolId: schoolId ?? this.schoolId,
      schoolFirestoreId: schoolFirestoreId ?? this.schoolFirestoreId,
      percentage: percentage ?? this.percentage,
    );
  }
}

// ===============================================================
// EXTENSION POUR FACILITER LA MANIPULATION DES RÉSULTATS
// ===============================================================

extension ExamResultModelExtension on List<ExamResultModel> {
  /// Filtre les résultats par examen
  List<ExamResultModel> filterByExam(int examId) {
    return where((r) => r.examId == examId).toList();
  }

  /// Filtre les résultats par examen Firestore ID
  List<ExamResultModel> filterByExamFirestore(String examFirestoreId) {
    return where((r) => r.examFirestoreId == examFirestoreId).toList();
  }

  /// Filtre les résultats par étudiant
  List<ExamResultModel> filterByStudent(int studentId) {
    return where((r) => r.studentId == studentId).toList();
  }

  /// Filtre les résultats par étudiant Firestore ID
  List<ExamResultModel> filterByStudentFirestore(String studentFirestoreId) {
    return where((r) => r.studentFirestoreId == studentFirestoreId).toList();
  }

  /// Filtre les résultats réussis
  List<ExamResultModel> getPassing() {
    return where((r) => r.isPassing).toList();
  }

  /// Filtre les résultats échoués
  List<ExamResultModel> getFailing() {
    return where((r) => r.isFail).toList();
  }

  /// Filtre les résultats excellents
  List<ExamResultModel> getExcellent() {
    return where((r) => r.isExcellent).toList();
  }

  /// Filtre les résultats par école
  List<ExamResultModel> filterBySchool(String schoolFirestoreId) {
    return where((r) => r.schoolFirestoreId == schoolFirestoreId).toList();
  }

  /// Groupe les résultats par examen
  Map<int, List<ExamResultModel>> groupByExam() {
    final Map<int, List<ExamResultModel>> result = {};
    for (var r in this) {
      if (!result.containsKey(r.examId)) {
        result[r.examId] = [];
      }
      result[r.examId]!.add(r);
    }
    return result;
  }

  /// Groupe les résultats par étudiant
  Map<int, List<ExamResultModel>> groupByStudent() {
    final Map<int, List<ExamResultModel>> result = {};
    for (var r in this) {
      if (!result.containsKey(r.studentId)) {
        result[r.studentId] = [];
      }
      result[r.studentId]!.add(r);
    }
    return result;
  }

  /// Calcule le score moyen
  double getAverageScore() {
    if (isEmpty) return 0.0;
    final total = fold(0.0, (sum, r) => sum + r.percentageValue);
    return total / length;
  }

  /// Calcule le score maximum
  double getMaxScore() {
    if (isEmpty) return 0.0;
    return map((r) => r.percentageValue).reduce((a, b) => a > b ? a : b);
  }

  /// Calcule le score minimum
  double getMinScore() {
    if (isEmpty) return 0.0;
    return map((r) => r.percentageValue).reduce((a, b) => a < b ? a : b);
  }

  /// Récupère les statistiques
  Map<String, dynamic> getStatistics() {
    return {
      'total': length,
      'passing': getPassing().length,
      'failing': getFailing().length,
      'excellent': getExcellent().length,
      'average': getAverageScore(),
      'max': getMaxScore(),
      'min': getMinScore(),
      'byExam': groupByExam().map((key, value) => MapEntry(key, value.length)),
    };
  }

  /// Récupère les résultats non synchronisés
  List<ExamResultModel> getUnsynced() {
    return where((r) => !r.hasFirestoreId).toList();
  }

  /// Trie les résultats par note (plus élevé en premier)
  List<ExamResultModel> sortedByScoreDesc() {
    final list = [...this];
    list.sort((a, b) => b.percentageValue.compareTo(a.percentageValue));
    return list;
  }

  /// Trie les résultats par date de soumission (plus récent en premier)
  List<ExamResultModel> sortedByDateDesc() {
    final list = [...this];
    list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return list;
  }
}
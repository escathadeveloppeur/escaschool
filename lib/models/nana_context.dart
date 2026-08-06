// lib/models/nana_context.dart
import 'package:flutter/material.dart';

class NanaContext {
  // Informations utilisateur
  final String userId;
  final String role;
  final String userName;
  final String? className;
  
  // Données scolaires
  final double? average;
  final List<Map<String, dynamic>>? grades;
  final List<Map<String, dynamic>>? attendances;
  final List<Map<String, dynamic>>? exams;
  final Map<String, double>? subjectAverages;
  final int? classRank;
  final int? totalStudents;
  
  // Informations supplémentaires
  final String? teacherFeedback;
  final List<String>? strengths;
  final List<String>? weaknesses;
  
  NanaContext({
    required this.userId,
    required this.role,
    required this.userName,
    this.className,
    this.average,
    this.grades,
    this.attendances,
    this.exams,
    this.subjectAverages,
    this.classRank,
    this.totalStudents,
    this.teacherFeedback,
    this.strengths,
    this.weaknesses,
  });

  // 📝 Créer un résumé des données
  String getSummary() {
    String summary = '''
📊 **Résumé de ${userName}**
👤 Rôle : $role
🏫 Classe : ${className ?? 'Non définie'}
''';
    
    if (average != null) {
      summary += '\n📈 Moyenne : ${average!.toStringAsFixed(2)}/20';
    }
    
    if (classRank != null && totalStudents != null) {
      summary += '\n🏆 Classement : $classRank/${totalStudents} élèves';
    }
    
    if (strengths != null && strengths!.isNotEmpty) {
      summary += '\n💪 Points forts : ${strengths!.join(', ')}';
    }
    
    if (weaknesses != null && weaknesses!.isNotEmpty) {
      summary += '\n⚠️ Points à améliorer : ${weaknesses!.join(', ')}';
    }
    
    if (subjectAverages != null && subjectAverages!.isNotEmpty) {
      summary += '\n\n📚 Détail par matière :';
      subjectAverages!.forEach((subject, avg) {
        final emoji = avg >= 14 ? '✅' : (avg >= 10 ? '📖' : '⚠️');
        summary += '\n  $emoji $subject : ${avg.toStringAsFixed(2)}/20';
      });
    }
    
    return summary;
  }

  // 🎨 Convertir en Map pour l'API
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'role': role,
      'userName': userName,
      'className': className,
      'average': average,
      'grades': grades,
      'attendances': attendances,
      'exams': exams,
      'subjectAverages': subjectAverages,
      'classRank': classRank,
      'totalStudents': totalStudents,
      'teacherFeedback': teacherFeedback,
      'strengths': strengths,
      'weaknesses': weaknesses,
    };
  }

  // 🔄 Créer depuis un Map
  factory NanaContext.fromJson(Map<String, dynamic> json) {
    return NanaContext(
      userId: json['userId'] ?? '',
      role: json['role'] ?? 'student',
      userName: json['userName'] ?? 'Utilisateur',
      className: json['className'],
      average: json['average']?.toDouble(),
      grades: json['grades'] != null 
          ? List<Map<String, dynamic>>.from(json['grades']) 
          : null,
      attendances: json['attendances'] != null 
          ? List<Map<String, dynamic>>.from(json['attendances']) 
          : null,
      exams: json['exams'] != null 
          ? List<Map<String, dynamic>>.from(json['exams']) 
          : null,
      subjectAverages: json['subjectAverages'] != null 
          ? Map<String, double>.from(json['subjectAverages']) 
          : null,
      classRank: json['classRank'],
      totalStudents: json['totalStudents'],
      teacherFeedback: json['teacherFeedback'],
      strengths: json['strengths'] != null 
          ? List<String>.from(json['strengths']) 
          : null,
      weaknesses: json['weaknesses'] != null 
          ? List<String>.from(json['weaknesses']) 
          : null,
    );
  }
}
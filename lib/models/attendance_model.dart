// lib/models/attendance_model.dart

import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ IMPORT AJOUTÉ
import 'package:flutter/material.dart'; // ✅ Pour Colors et Icons

part 'attendance_model.g.dart';

@HiveType(typeId: 55)
class AttendanceModel extends HiveObject {
  @HiveField(0)
  int studentKeyHive;
  
  @HiveField(1)
  String studentName;
  
  @HiveField(2)
  String className;
  
  @HiveField(3)
  DateTime date;
  
  @HiveField(4)
  String status; // 'present', 'absent', 'late', 'excused'
  
  @HiveField(5)
  String? reason;
  
  @HiveField(6)
  String subject;
  
  @HiveField(7)
  int? studentId; // ID du compte utilisateur (pour élève)
  
  // ===============================================================
  // CHAMPS POUR LE CYCLE ET LA SECTION
  // ===============================================================
  
  @HiveField(8)
  String? classCycleType; // 'primaire' ou 'secondaire'
  
  @HiveField(9)
  String? sectionId; // ID de la section (pour le secondaire)
  
  @HiveField(10)
  String? sectionName; // Nom de la section (pour le secondaire)
  
  @HiveField(11)
  String? classFirestoreId; // ID Firestore de la classe
  
  @HiveField(12)
  String? studentFirestoreId; // ID Firestore de l'étudiant

  // ===============================================================
  // CHAMPS POUR LA STRUCTURE HIÉRARCHIQUE
  // ===============================================================
  
  @HiveField(13)
  String? schoolId; // ID Firestore de l'école
  
  @HiveField(14)
  String? attendanceFirestoreId; // ID Firestore de la présence
  
  @HiveField(15)
  String? classId; // ID de la classe (alias pour classFirestoreId)
  
  @HiveField(16)
  String? studentIdFirestore; // ID Firestore de l'étudiant (alias)

  AttendanceModel({
    required this.studentKeyHive,
    required this.studentName,
    required this.className,
    required this.date,
    required this.status,
    this.reason,
    required this.subject,
    this.studentId,
    this.classCycleType,
    this.sectionId,
    this.sectionName,
    this.classFirestoreId,
    this.studentFirestoreId,
    this.schoolId,
    this.attendanceFirestoreId,
    this.classId,
    this.studentIdFirestore,
  });

  // ===============================================================
  // CONVERSION POUR FIRESTORE
  // ===============================================================

  /// Convertir en Map pour Firestore
  Map<String, dynamic> toFirestoreMap() {
    return {
      'studentKeyHive': studentKeyHive,
      'studentName': studentName,
      'className': className,
      'classId': classId ?? classFirestoreId,
      'date': date.toIso8601String(),
      'status': status,
      'reason': reason,
      'subject': subject,
      'studentId': studentId,
      'studentFirestoreId': studentFirestoreId ?? studentIdFirestore,
      'classCycleType': classCycleType,
      'sectionId': sectionId,
      'sectionName': sectionName,
      'classFirestoreId': classFirestoreId,
      'localKey': key, // Pour la synchronisation
      'createdAt': FieldValue.serverTimestamp(), // ✅ FieldValue disponible
      'updatedAt': FieldValue.serverTimestamp(), // ✅ FieldValue disponible
    };
  }

  /// Convertir en Map pour Hive (local)
  Map<String, dynamic> toMap() {
    return {
      'studentKeyHive': studentKeyHive,
      'studentName': studentName,
      'className': className,
      'date': date.toIso8601String(),
      'status': status,
      'reason': reason,
      'subject': subject,
      'studentId': studentId,
      'classCycleType': classCycleType,
      'sectionId': sectionId,
      'sectionName': sectionName,
      'classFirestoreId': classFirestoreId,
      'studentFirestoreId': studentFirestoreId,
      'schoolId': schoolId,
      'attendanceFirestoreId': attendanceFirestoreId,
      'classId': classId,
      'studentIdFirestore': studentIdFirestore,
    };
  }

  // ===============================================================
  // FACTORY DEPUIS FIRESTORE
  // ===============================================================

  /// Créer une instance depuis Firestore
  factory AttendanceModel.fromFirestore(
    Map<String, dynamic> map,
    String docId,
  ) {
    return AttendanceModel(
      studentKeyHive: map['studentKeyHive'] ?? 0,
      studentName: map['studentName'] ?? '',
      className: map['className'] ?? '',
      classId: map['classId'] ?? map['classFirestoreId'] ?? '',
      date: map['date'] != null 
          ? (map['date'] is DateTime 
              ? map['date'] 
              : DateTime.parse(map['date']))
          : DateTime.now(),
      status: map['status'] ?? 'present',
      reason: map['reason'],
      subject: map['subject'] ?? '',
      studentId: map['studentId'],
      classCycleType: map['classCycleType'],
      sectionId: map['sectionId'],
      sectionName: map['sectionName'],
      classFirestoreId: map['classFirestoreId'] ?? map['classId'] ?? '',
      studentFirestoreId: map['studentFirestoreId'] ?? map['studentIdFirestore'] ?? '',
      schoolId: map['schoolId'],
      attendanceFirestoreId: docId,
      studentIdFirestore: map['studentFirestoreId'] ?? map['studentIdFirestore'] ?? '',
    );
  }

  /// Créer une instance depuis Hive
  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      studentKeyHive: map['studentKeyHive'] ?? 0,
      studentName: map['studentName'] ?? '',
      className: map['className'] ?? '',
      date: map['date'] != null 
          ? (map['date'] is DateTime 
              ? map['date'] 
              : DateTime.parse(map['date']))
          : DateTime.now(),
      status: map['status'] ?? 'present',
      reason: map['reason'],
      subject: map['subject'] ?? '',
      studentId: map['studentId'],
      classCycleType: map['classCycleType'],
      sectionId: map['sectionId'],
      sectionName: map['sectionName'],
      classFirestoreId: map['classFirestoreId'],
      studentFirestoreId: map['studentFirestoreId'],
      schoolId: map['schoolId'],
      attendanceFirestoreId: map['attendanceFirestoreId'],
      classId: map['classId'],
      studentIdFirestore: map['studentIdFirestore'],
    );
  }

  // ===============================================================
  // MÉTHODES UTILITAIRES
  // ===============================================================
  
  /// Vérifie si l'étudiant est au primaire
  bool get isPrimary => classCycleType == 'primaire';
  
  /// Vérifie si l'étudiant est au secondaire
  bool get isSecondary => classCycleType == 'secondaire';
  
  /// Vérifie si l'étudiant a une section
  bool get hasSection => sectionId != null && sectionId!.isNotEmpty;
  
  /// Vérifie si la présence a un ID Firestore
  bool get hasFirestoreId => attendanceFirestoreId != null && attendanceFirestoreId!.isNotEmpty;
  
  /// Retourne le libellé du statut en français
  String get statusLabel {
    switch (status) {
      case 'present': return 'Présent';
      case 'absent': return 'Absent';
      case 'late': return 'Retard';
      case 'excused': return 'Excusé';
      default: return status;
    }
  }
  
  /// Retourne la couleur du statut
  Color get statusColor {
    switch (status) {
      case 'present': return Colors.green;
      case 'absent': return Colors.red;
      case 'late': return Colors.orange;
      case 'excused': return Colors.blue;
      default: return Colors.grey;
    }
  }
  
  /// Retourne l'icône du statut
  IconData get statusIcon {
    switch (status) {
      case 'present': return Icons.check_circle;
      case 'absent': return Icons.cancel;
      case 'late': return Icons.access_time;
      case 'excused': return Icons.assignment_turned_in;
      default: return Icons.help;
    }
  }

  /// Retourne une copie de l'instance avec des champs mis à jour
  AttendanceModel copyWith({
    int? studentKeyHive,
    String? studentName,
    String? className,
    DateTime? date,
    String? status,
    String? reason,
    String? subject,
    int? studentId,
    String? classCycleType,
    String? sectionId,
    String? sectionName,
    String? classFirestoreId,
    String? studentFirestoreId,
    String? schoolId,
    String? attendanceFirestoreId,
    String? classId,
    String? studentIdFirestore,
  }) {
    return AttendanceModel(
      studentKeyHive: studentKeyHive ?? this.studentKeyHive,
      studentName: studentName ?? this.studentName,
      className: className ?? this.className,
      date: date ?? this.date,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      subject: subject ?? this.subject,
      studentId: studentId ?? this.studentId,
      classCycleType: classCycleType ?? this.classCycleType,
      sectionId: sectionId ?? this.sectionId,
      sectionName: sectionName ?? this.sectionName,
      classFirestoreId: classFirestoreId ?? this.classFirestoreId,
      studentFirestoreId: studentFirestoreId ?? this.studentFirestoreId,
      schoolId: schoolId ?? this.schoolId,
      attendanceFirestoreId: attendanceFirestoreId ?? this.attendanceFirestoreId,
      classId: classId ?? this.classId,
      studentIdFirestore: studentIdFirestore ?? this.studentIdFirestore,
    );
  }
}

// ===============================================================
// EXTENSION POUR FACILITER LA MANIPULATION DES PRÉSENCES
// ===============================================================

extension AttendanceModelExtension on List<AttendanceModel> {
  /// Filtre les présences par classe
  List<AttendanceModel> filterByClass(String className) {
    return where((a) => a.className == className).toList();
  }
  
  /// Filtre les présences par classe Firestore ID
  List<AttendanceModel> filterByClassId(String classFirestoreId) {
    return where((a) => a.classFirestoreId == classFirestoreId || a.classId == classFirestoreId).toList();
  }
  
  /// Filtre les présences par cycle
  List<AttendanceModel> filterByCycle(String cycleType) {
    if (cycleType == 'all') return this;
    return where((a) => a.classCycleType == cycleType).toList();
  }
  
  /// Filtre les présences par section
  List<AttendanceModel> filterBySection(String? sectionId) {
    if (sectionId == null || sectionId.isEmpty) return this;
    return where((a) => a.sectionId == sectionId).toList();
  }
  
  /// Filtre les présences par étudiant
  List<AttendanceModel> filterByStudent(String studentName) {
    return where((a) => a.studentName == studentName).toList();
  }
  
  /// Filtre les présences par étudiant Firestore ID
  List<AttendanceModel> filterByStudentId(String studentFirestoreId) {
    return where((a) => a.studentFirestoreId == studentFirestoreId || a.studentIdFirestore == studentFirestoreId).toList();
  }
  
  /// Filtre les présences par date
  List<AttendanceModel> filterByDate(DateTime date) {
    return where((a) => 
      a.date.year == date.year && 
      a.date.month == date.month && 
      a.date.day == date.day
    ).toList();
  }
  
  /// Filtre les présences par mois/année
  List<AttendanceModel> filterByMonth(int year, int month) {
    return where((a) => 
      a.date.year == year && 
      a.date.month == month
    ).toList();
  }
  
  /// Filtre les présences par statut
  List<AttendanceModel> filterByStatus(String status) {
    return where((a) => a.status == status).toList();
  }
  
  /// Filtre les présences par école
  List<AttendanceModel> filterBySchool(String schoolId) {
    return where((a) => a.schoolId == schoolId).toList();
  }
  
  /// Calcule le taux de présence pour un étudiant
  double getAttendanceRate(String studentName) {
    final studentAttendances = filterByStudent(studentName);
    if (studentAttendances.isEmpty) return 0;
    
    final presentCount = studentAttendances.where((a) => 
      a.status == 'present'
    ).length;
    
    return (presentCount / studentAttendances.length) * 100;
  }
  
  /// Calcule le taux de présence pour un étudiant par ID
  double getAttendanceRateByStudentId(String studentFirestoreId) {
    final studentAttendances = filterByStudentId(studentFirestoreId);
    if (studentAttendances.isEmpty) return 0;
    
    final presentCount = studentAttendances.where((a) => 
      a.status == 'present'
    ).length;
    
    return (presentCount / studentAttendances.length) * 100;
  }
  
  /// Récupère les statistiques des présences
  Map<String, int> getStatistics() {
    return {
      'total': length,
      'present': where((a) => a.status == 'present').length,
      'absent': where((a) => a.status == 'absent').length,
      'late': where((a) => a.status == 'late').length,
      'excused': where((a) => a.status == 'excused').length,
    };
  }
  
  /// Récupère les présences par statut
  Map<String, List<AttendanceModel>> groupByStatus() {
    return {
      'present': where((a) => a.status == 'present').toList(),
      'absent': where((a) => a.status == 'absent').toList(),
      'late': where((a) => a.status == 'late').toList(),
      'excused': where((a) => a.status == 'excused').toList(),
    };
  }
  
  /// Récupère les présences par date
  Map<DateTime, List<AttendanceModel>> groupByDate() {
    final Map<DateTime, List<AttendanceModel>> result = {};
    for (var attendance in this) {
      final dateKey = DateTime(attendance.date.year, attendance.date.month, attendance.date.day);
      if (!result.containsKey(dateKey)) {
        result[dateKey] = [];
      }
      result[dateKey]!.add(attendance);
    }
    return result;
  }
  
  /// Récupère les présences par étudiant
  Map<String, List<AttendanceModel>> groupByStudent() {
    final Map<String, List<AttendanceModel>> result = {};
    for (var attendance in this) {
      if (!result.containsKey(attendance.studentName)) {
        result[attendance.studentName] = [];
      }
      result[attendance.studentName]!.add(attendance);
    }
    return result;
  }
  
  /// Récupère les présences par classe
  Map<String, List<AttendanceModel>> groupByClass() {
    final Map<String, List<AttendanceModel>> result = {};
    for (var attendance in this) {
      final key = attendance.className;
      if (!result.containsKey(key)) {
        result[key] = [];
      }
      result[key]!.add(attendance);
    }
    return result;
  }
  
  /// Récupère les présences par cycle
  Map<String, List<AttendanceModel>> groupByCycle() {
    final Map<String, List<AttendanceModel>> result = {
      'primaire': [],
      'secondaire': [],
    };
    for (var attendance in this) {
      if (attendance.isPrimary) {
        result['primaire']!.add(attendance);
      } else if (attendance.isSecondary) {
        result['secondaire']!.add(attendance);
      }
    }
    return result;
  }
  
  /// Récupère les présences triées par date (plus récentes en premier)
  List<AttendanceModel> sortedByDateDesc() {
    final list = [...this];
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
  
  /// Récupère les présences triées par date (plus anciennes en premier)
  List<AttendanceModel> sortedByDateAsc() {
    final list = [...this];
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }
  
  /// Récupère les présences d'un jour spécifique
  List<AttendanceModel> getByDay(DateTime date) {
    return filterByDate(date);
  }
  
  /// Récupère les présences de la semaine
  List<AttendanceModel> getByWeek(DateTime date) {
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return where((a) => 
      a.date.isAfter(startOfWeek.subtract(const Duration(days: 1))) && 
      a.date.isBefore(endOfWeek.add(const Duration(days: 1)))
    ).toList();
  }
  
  /// Récupère les présences du mois
  List<AttendanceModel> getByMonth(int year, int month) {
    return filterByMonth(year, month);
  }
  
  /// Récupère les présences non synchronisées (sans Firestore ID)
  List<AttendanceModel> getUnsynced() {
    return where((a) => !a.hasFirestoreId).toList();
  }
}
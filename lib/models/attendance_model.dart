// lib/models/attendance_model.dart

import 'package:hive/hive.dart';

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
  int? studentId;  // ID du compte utilisateur (pour élève)
  
  // ===============================================================
  // NOUVEAUX CHAMPS POUR LE CYCLE ET LA SECTION
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
  });

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
    };
  }

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
  
  
  /// Retourne l'icône du statut
 
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
    return where((a) => a.classFirestoreId == classFirestoreId).toList();
  }
  
  /// Filtre les présences par cycle
  List<AttendanceModel> filterByCycle(String cycleType) {
    if (cycleType == 'all') return this;
    return where((a) => a.classCycleType == cycleType).toList();
  }
  
  /// Filtre les présences par section
  List<AttendanceModel> filterBySection(String? sectionId) {
    if (sectionId == null) return this;
    return where((a) => a.sectionId == sectionId).toList();
  }
  
  /// Filtre les présences par étudiant
  List<AttendanceModel> filterByStudent(String studentName) {
    return where((a) => a.studentName == studentName).toList();
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
  
  /// Calcule le taux de présence pour un étudiant
  double getAttendanceRate(String studentName) {
    final studentAttendances = filterByStudent(studentName);
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
}
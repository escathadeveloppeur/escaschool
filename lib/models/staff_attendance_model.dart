// lib/models/staff_attendance_model.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Ajout de l'import

class StaffAttendanceModel {
  final String id;
  final String staffId;
  final String staffName;
  final String position;
  final String schoolId;
  final DateTime date;
  final DateTime checkIn;
  final DateTime? checkOut;
  final String status; // 'present', 'absent', 'late', 'half_day'
  final String? note;
  final double? workedHours;

  StaffAttendanceModel({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.position,
    required this.schoolId,
    required this.date,
    required this.checkIn,
    this.checkOut,
    this.status = 'present',
    this.note,
    this.workedHours,
  });

  Map<String, dynamic> toFirestore() => {
    'staffId': staffId,
    'staffName': staffName,
    'position': position,
    'schoolId': schoolId,
    'date': date.toIso8601String(),
    'checkIn': checkIn.toIso8601String(),
    'checkOut': checkOut?.toIso8601String(),
    'status': status,
    'note': note,
    'workedHours': workedHours,
    'createdAt': FieldValue.serverTimestamp(),
  };

  factory StaffAttendanceModel.fromFirestore(Map<String, dynamic> data, String docId) {
    return StaffAttendanceModel(
      id: docId,
      staffId: data['staffId'] ?? '',
      staffName: data['staffName'] ?? '',
      position: data['position'] ?? '',
      schoolId: data['schoolId'] ?? '',
      date: DateTime.parse(data['date']),
      checkIn: DateTime.parse(data['checkIn']),
      checkOut: data['checkOut'] != null ? DateTime.parse(data['checkOut']) : null,
      status: data['status'] ?? 'present',
      note: data['note'],
      workedHours: data['workedHours'],
    );
  }
}
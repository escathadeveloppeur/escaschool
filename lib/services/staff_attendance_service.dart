// lib/services/staff_attendance_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/staff_attendance_model.dart';

class StaffAttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Enregistrer une présence (check-in)
  Future<String> checkIn({
    required String staffId,
    required String staffName,
    required String position,
    required String schoolId,
    String? note,
  }) async {
    try {
      final now = DateTime.now();
      final date = DateTime(now.year, now.month, now.day);

      // Vérifier si déjà présent aujourd'hui
      final existing = await _firestore
          .collection('staff_attendance')
          .where('staffId', isEqualTo: staffId)
          .where('date', isEqualTo: date.toIso8601String())
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception('Présence déjà enregistrée pour aujourd\'hui');
      }

      final attendance = StaffAttendanceModel(
        id: '',
        staffId: staffId,
        staffName: staffName,
        position: position,
        schoolId: schoolId,
        date: date,
        checkIn: now,
        status: 'present',
        note: note,
      );

      final docRef = await _firestore
          .collection('staff_attendance')
          .add(attendance.toFirestore());

      return docRef.id;
    } catch (e) {
      print('❌ Erreur check-in: $e');
      throw e;
    }
  }

  /// ✅ Enregistrer le check-out
  Future<void> checkOut(String attendanceId) async {
    try {
      final now = DateTime.now();
      final doc = await _firestore
          .collection('staff_attendance')
          .doc(attendanceId)
          .get();

      if (!doc.exists) {
        throw Exception('Présence non trouvée');
      }

      // ✅ Correction : utiliser data() as Map<String, dynamic>
      final data = doc.data() as Map<String, dynamic>;
      final checkIn = DateTime.parse(data['checkIn']);
      final workedHours = now.difference(checkIn).inHours.toDouble();

      await _firestore
          .collection('staff_attendance')
          .doc(attendanceId)
          .update({
        'checkOut': now.toIso8601String(),
        'workedHours': workedHours,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Erreur check-out: $e');
      throw e;
    }
  }

  /// ✅ Récupérer les présences d'un staff
  Future<List<StaffAttendanceModel>> getStaffAttendances(
    String staffId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection('staff_attendance')
          .where('staffId', isEqualTo: staffId)
          .orderBy('date', descending: true);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: endDate.toIso8601String());
      }

      final snapshot = await query.get();

      // ✅ Correction : utiliser data() as Map<String, dynamic>
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StaffAttendanceModel.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération présences: $e');
      throw e;
    }
  }

  /// ✅ Récupérer les présences du jour pour une école
  Future<List<StaffAttendanceModel>> getTodayAttendances(String schoolId) async {
    try {
      final now = DateTime.now();
      final date = DateTime(now.year, now.month, now.day);

      final snapshot = await _firestore
          .collection('staff_attendance')
          .where('schoolId', isEqualTo: schoolId)
          .where('date', isEqualTo: date.toIso8601String())
          .orderBy('checkIn', descending: true)
          .get();

      // ✅ Correction : utiliser data() as Map<String, dynamic>
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StaffAttendanceModel.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération présences du jour: $e');
      throw e;
    }
  }

  /// ✅ Récupérer les présences d'une période
  Future<List<StaffAttendanceModel>> getAttendancesByPeriod(
    String schoolId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('staff_attendance')
          .where('schoolId', isEqualTo: schoolId)
          .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('date', isLessThanOrEqualTo: endDate.toIso8601String())
          .orderBy('date', descending: true)
          .get();

      // ✅ Correction : utiliser data() as Map<String, dynamic>
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StaffAttendanceModel.fromFirestore(data, doc.id);
      }).toList();
    } catch (e) {
      print('❌ Erreur récupération présences par période: $e');
      throw e;
    }
  }

  /// ✅ Statistiques de présence
  Future<Map<String, dynamic>> getAttendanceStats(
    String staffId,
    DateTime month,
  ) async {
    try {
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 1).subtract(const Duration(days: 1));

      final attendances = await getStaffAttendances(
        staffId,
        startDate: startDate,
        endDate: endDate,
      );

      final totalDays = attendances.length;
      final presentDays = attendances.where((a) => a.status == 'present').length;
      final absentDays = attendances.where((a) => a.status == 'absent').length;
      final lateDays = attendances.where((a) => a.status == 'late').length;

      return {
        'totalDays': totalDays,
        'presentDays': presentDays,
        'absentDays': absentDays,
        'lateDays': lateDays,
        'attendanceRate': totalDays > 0 ? (presentDays / totalDays * 100) : 0,
      };
    } catch (e) {
      print('❌ Erreur statistiques: $e');
      throw e;
    }
  }
}
// lib/services/qr_service.dart

import 'dart:convert';
import '../models/student_model.dart';

class QRService {
  // Générer un QR code pour un étudiant
  static String generateStudentQR(StudentModel student) {
    final data = {
      'type': 'student_attendance',
      'studentId': student.key,
      'studentName': student.fullName,
      'className': student.className,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  // Vérifier si le QR code est valide
  static Map<String, dynamic>? validateQRCode(String qrData) {
    try {
      final data = jsonDecode(qrData);
      if (data['type'] == 'student_attendance' && data['studentId'] != null) {
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
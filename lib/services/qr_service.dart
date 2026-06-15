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

  // Générer un QR simple (juste l'ID)
  static String generateSimpleQR(String studentId) {
    return studentId;
  }

  // Vérifier si le QR code est valide (support multi-formats)
  static Map<String, dynamic>? validateQRCode(String qrData) {
    print('🔍 Validation QR: $qrData');
    
    // Essayer de parser comme JSON
    try {
      final data = jsonDecode(qrData);
      if (data is Map<String, dynamic>) {
        if (data['type'] == 'student_attendance' && data['studentId'] != null) {
          print('✅ Format JSON valide');
          return data;
        }
      }
    } catch (e) {
      print('⚠️ Pas du JSON: $e');
    }
    
    // Si ce n'est pas du JSON, c'est peut-être juste l'ID
    if (qrData.length > 10 && qrData.length < 50) {
      print('✅ Format ID simple (${qrData.length} caractères)');
      return {
        'type': 'student_attendance',
        'studentId': qrData,
        'studentName': '',
        'className': '',
      };
    }
    
    print('❌ Format non reconnu');
    return null;
  }
}
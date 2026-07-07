// lib/services/qr_service.dart

import 'dart:convert';
import '../models/student_model.dart';

class QRService {
  // ================================================================
  // 📤 GÉNÉRATION DE DONNÉES QR
  // ================================================================

  /// 🔥 Générer les données QR pour un étudiant
  static String generateStudentQRData(StudentModel student) {
    final data = {
      'type': 'student_attendance',
      'studentId': student.HiveKey?.toString() ?? student.key,
      'studentName': student.fullName,
      'className': student.className,
      'classCycleType': student.classCycleType,
      'sectionName': student.sectionName,
      'gender': student.gender,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  /// 🔥 Générer un QR code pour un étudiant (alias)
  static String generateStudentQR(StudentModel student) {
    return generateStudentQRData(student);
  }

  /// 🔥 Générer les données QR pour une carte d'élève
  static String generateCardQRData({
    required String studentId,
    required String studentName,
    required String className,
    required String classCycleType,
    String? sectionName,
    String? schoolId,
  }) {
    final data = {
      'type': 'student_attendance',
      'studentId': studentId,
      'studentName': studentName,
      'className': className,
      'classCycleType': classCycleType,
      'sectionName': sectionName,
      'schoolId': schoolId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(data);
  }

  /// 🔥 Générer un QR simple (juste l'ID)
  static String generateSimpleQR(String studentId) {
    return studentId;
  }

  // ================================================================
  // 🔍 VALIDATION QR CODE
  // ================================================================

  /// 🔥 Vérifier si le QR code est valide
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

  /// 🔥 Extraire les informations du QR Code
  static Map<String, dynamic>? extractQRInfo(String qrData) {
    return validateQRCode(qrData);
  }

  /// 🔥 Vérifier si le QR est valide pour un étudiant
  static bool isValidForStudent(String qrData, String studentId) {
    final data = validateQRCode(qrData);
    if (data == null) return false;
    return data['studentId'] == studentId;
  }

  /// 🔥 Vérifier si le QR est valide pour une classe
  static bool isValidForClass(String qrData, String className) {
    final data = validateQRCode(qrData);
    if (data == null) return false;
    return data['className'] == className;
  }

  // ================================================================
  // 🔧 MÉTHODES UTILITAIRES
  // ================================================================

  /// 🔥 Vérifier si le QR est un format JSON
  static bool isJSONFormat(String qrData) {
    try {
      final data = jsonDecode(qrData);
      return data is Map<String, dynamic>;
    } catch (e) {
      return false;
    }
  }

  /// 🔥 Vérifier si le QR est un format simple (ID)
  static bool isSimpleFormat(String qrData) {
    return qrData.length > 10 && qrData.length < 50 && !qrData.contains('{');
  }

  /// 🔥 Formater les données QR pour l'impression
  static String formatQRForPrint(String qrData) {
    final data = validateQRCode(qrData);
    if (data != null && data['studentName'] != null) {
      return 'Élève: ${data['studentName']}\n'
             'Classe: ${data['className']}\n'
             'ID: ${data['studentId']}\n'
             '${DateTime.now().toIso8601String()}';
    }
    return qrData;
  }

  /// 🔥 Obtenir l'ID de l'étudiant depuis le QR
  static String? getStudentIdFromQR(String qrData) {
    final data = validateQRCode(qrData);
    return data?['studentId'];
  }

  /// 🔥 Obtenir le nom de l'étudiant depuis le QR
  static String? getStudentNameFromQR(String qrData) {
    final data = validateQRCode(qrData);
    return data?['studentName'];
  }

  /// 🔥 Obtenir la classe depuis le QR
  static String? getClassNameFromQR(String qrData) {
    final data = validateQRCode(qrData);
    return data?['className'];
  }

  /// 🔥 Vérifier si le QR est expiré (timestamp > 1 heure)
  static bool isQRExpired(String qrData) {
    final data = validateQRCode(qrData);
    if (data == null) return true;
    
    final timestamp = data['timestamp'];
    if (timestamp == null) return false;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - timestamp;
    
    // Expire après 1 heure (3600000 ms)
    return diff > 3600000;
  }

  /// 🔥 Régénérer un QR avec un nouveau timestamp
  static String refreshQR(String qrData) {
    final data = validateQRCode(qrData);
    if (data == null) return qrData;
    
    data['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    return jsonEncode(data);
  }
}
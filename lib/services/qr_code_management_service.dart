// lib/services/qr_code_management_service.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/qr_code_model.dart';
import '../models/student_card_model.dart';
import '../services/student_card_service.dart';

class QRCodeManagementService {
  static const String _qrCodesDirectory = 'qr_codes';

  /// 📁 Sauvegarder les QR codes d'une classe
  static Future<String> saveClassQRCodes(ClassQRCodeGroup classGroup) async {
    try {
      final directory = await _getQRCodeDirectory();
      final fileName = 'qrcodes_${classGroup.className.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.json';
      final filePath = '${directory.path}/$fileName';
      
      final file = File(filePath);
      await file.writeAsString(jsonEncode(classGroup.toJson()));
      
      print('✅ QR codes sauvegardés: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde: $e');
      throw e;
    }
  }

  /// 📂 Récupérer tous les groupes de QR codes
  static Future<List<ClassQRCodeGroup>> getAllQRCodeGroups() async {
    try {
      final directory = await _getQRCodeDirectory();
      final files = directory.listSync();
      final groups = <ClassQRCodeGroup>[];
      
      for (var file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final content = await file.readAsString();
            final jsonData = jsonDecode(content);
            final group = ClassQRCodeGroup.fromJson(jsonData);
            groups.add(group);
          } catch (e) {
            print('Erreur lors de la lecture du fichier: $e');
          }
        }
      }
      
      return groups;
    } catch (e) {
      print('❌ Erreur lors de la récupération: $e');
      return [];
    }
  }

  /// 🔍 Récupérer les QR codes d'une classe spécifique
  static Future<ClassQRCodeGroup?> getQRCodeGroupByClass(String className) async {
    try {
      final groups = await getAllQRCodeGroups();
      return groups.firstWhere(
        (g) => g.className == className,
        orElse: () => throw Exception('Classe non trouvée'),
      );
    } catch (e) {
      print('❌ Classe non trouvée: $e');
      return null;
    }
  }

  /// 🔄 Régénérer un QR code pour un élève
  static Future<QRCodeData> regenerateStudentQRCode({
    required QRCodeData oldQRCode,
    required String schoolName,
  }) async {
    final newQRCode = QRCodeData(
      id: oldQRCode.id,
      studentId: oldQRCode.studentId,
      studentName: oldQRCode.studentName,
      className: oldQRCode.className,
      schoolId: oldQRCode.schoolId,
      schoolName: schoolName,
      classCycleType: oldQRCode.classCycleType,
      sectionName: oldQRCode.sectionName,
      generatedAt: DateTime.now(),
      isActive: true,
      version: oldQRCode.version + 1,
    );
    
    // Générer les données du QR code
    final qrData = _generateQRCodeData(newQRCode);
    newQRCode.qrCodeData = qrData;
    
    return newQRCode;
  }

  /// 📋 Générer les données du QR code
  static String _generateQRCodeData(QRCodeData data) {
    final qrData = {
      'type': 'student_attendance',
      'studentId': data.studentId,
      'studentName': data.studentName,
      'className': data.className,
      'classCycleType': data.classCycleType,
      'sectionName': data.sectionName,
      'schoolId': data.schoolId,
      'schoolName': data.schoolName,
      'version': data.version,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(qrData);
  }

  /// 🖼️ Générer l'image du QR code pour un élève
  static Future<Uint8List> generateQRCodeImage(QRCodeData data) async {
    final qrData = data.qrCodeData.isEmpty ? _generateQRCodeData(data) : data.qrCodeData;
    
    // Utiliser le service de carte pour générer un QR code
    final studentCardData = StudentCardData(
      studentId: data.studentId,
      fullName: data.studentName,
      className: data.className,
      classCycleType: data.classCycleType,
      schoolId: data.schoolId,
      schoolName: data.schoolName,
      sectionName: data.sectionName,
    );
    
    // Ici, vous pouvez générer soit la carte complète, soit juste le QR code
    return await StudentCardService.generateStudentCard(
      data: studentCardData,
      width: 400,
      height: 300,
      pixelRatio: 2.0,
    );
  }

  /// 📤 Exporter tous les QR codes d'une classe
  static Future<void> exportClassQRCodes(ClassQRCodeGroup classGroup) async {
    try {
      // Sauvegarder d'abord le fichier JSON
      final jsonPath = await saveClassQRCodes(classGroup);
      
      // Partager le fichier
      await Share.shareXFiles(
        [XFile(jsonPath)],
        text: '📇 QR Codes de la classe ${classGroup.className}',
      );
      
      print('✅ QR codes exportés');
    } catch (e) {
      print('❌ Erreur lors de l\'export: $e');
      throw e;
    }
  }

  /// 📁 Récupérer le répertoire des QR codes
  static Future<Directory> _getQRCodeDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final qrDir = Directory('${directory.path}/$_qrCodesDirectory');
    
    if (!await qrDir.exists()) {
      await qrDir.create(recursive: true);
    }
    
    return qrDir;
  }

  /// 🗑️ Supprimer un QR code
  static Future<void> deleteQRCode(String qrCodeId) async {
    try {
      // Trouver et supprimer de tous les groupes
      final groups = await getAllQRCodeGroups();
      for (var group in groups) {
        group.students.removeWhere((s) => s.id == qrCodeId);
        if (group.students.isEmpty) {
          // Supprimer le fichier si la classe est vide
          final directory = await _getQRCodeDirectory();
          final files = directory.listSync();
          for (var file in files) {
            if (file is File && file.path.contains(group.className)) {
              await file.delete();
            }
          }
        } else {
          // Mettre à jour le fichier
          await saveClassQRCodes(group);
        }
      }
      print('✅ QR code supprimé');
    } catch (e) {
      print('❌ Erreur lors de la suppression: $e');
      throw e;
    }
  }
}
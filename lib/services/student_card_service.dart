// lib/services/student_card_service.dart

import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screenshot/screenshot.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_card_model.dart';

class StudentCardService {
  static final ScreenshotController _controller = ScreenshotController();

  /// ✅ Récupérer les informations de l'école depuis Firestore (collection 'schools')
  static Future<Map<String, dynamic>?> _getSchoolInfo(String schoolId) async {
    try {
      if (schoolId.isEmpty) return null;
      
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ Erreur récupération école: $e');
      return null;
    }
  }

  /// 📇 Générer une carte d'élève en image
  static Future<Uint8List> generateStudentCard({
    required StudentCardData data,
    int width = 600,
    int height = 400,
    double pixelRatio = 2.0,
  }) async {
    try {
      // ✅ Récupérer les informations de l'école
      Map<String, dynamic>? schoolInfo;
      if (data.schoolId.isNotEmpty) {
        schoolInfo = await _getSchoolInfo(data.schoolId);
      }
      
      final widget = _buildCardWidget(data, width, height, schoolInfo);

      final Uint8List? image = await _controller.captureFromWidget(
        widget,
        pixelRatio: pixelRatio,
        delay: const Duration(milliseconds: 100),
      );

      if (image == null) {
        throw Exception('Impossible de capturer l\'image');
      }

      return image;
    } catch (e) {
      print('❌ Erreur génération carte: $e');
      throw e;
    }
  }

  /// 📇 Générer une carte d'élève en format PDF (pour impression)
  static Future<Uint8List> generateStudentCardForPrint({
    required StudentCardData data,
    int width = 800,
    int height = 550,
  }) async {
    return await generateStudentCard(
      data: data,
      width: width,
      height: height,
      pixelRatio: 3.0,
    );
  }

  /// 💾 Sauvegarder la carte localement
  static Future<String> saveCardToDevice(Uint8List imageBytes, String studentName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'carte_${studentName.replaceAll(' ', '_')}_$timestamp.png';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      print('✅ Carte sauvegardée: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde: $e');
      throw e;
    }
  }

  /// 📤 Partager la carte
  static Future<void> shareCard(Uint8List imageBytes, String studentName) async {
    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'carte_${studentName.replaceAll(' ', '_')}_$timestamp.png';
      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Carte de présence - ${studentName.toUpperCase()}',
      );

      print('✅ Carte partagée');
    } catch (e) {
      print('❌ Erreur lors du partage: $e');
      throw e;
    }
  }

  /// 🏗️ Construire le widget de la carte - VERSION AMÉLIORÉE
  static Widget _buildCardWidget(
    StudentCardData data, 
    int width, 
    int height,
    Map<String, dynamic>? schoolInfo,
  ) {
    // ✅ Utiliser les informations de l'école si disponibles
    final schoolName = schoolInfo?['name'] ?? data.schoolName;
    final schoolType = schoolInfo?['type'] ?? '';
    final schoolPhone = schoolInfo?['phone'] ?? '';
    final schoolEmail = schoolInfo?['email'] ?? '';
    final schoolWebsite = schoolInfo?['website'] ?? '';
    final schoolCode = schoolInfo?['schoolCode'] ?? '';
    
    return Container(
      width: width.toDouble(),
      height: height.toDouble(),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            data.primaryColor,
            data.primaryColor.withOpacity(0.8),
            data.primaryColor.withOpacity(0.6),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 40,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Fond décoratif amélioré
          _buildBackgroundDecorations(data.primaryColor),

          // Bandes décoratives
          _buildDecorativeBands(),

          // Logo en haut à gauche (avec les infos école)
          Positioned(
            top: 20,
            left: 24,
            child: _buildSchoolLogo(
              schoolName: schoolName,
              schoolType: schoolType,
              schoolPhone: schoolPhone,
              schoolEmail: schoolEmail,
              schoolWebsite: schoolWebsite,
              schoolCode: schoolCode,
            ),
          ),

          // Contenu principal
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildQRCodeSection(data),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildInfoSection(data),
                ),
              ],
            ),
          ),

          // Pied de carte
          Positioned(
            bottom: 14,
            left: 24,
            right: 24,
            child: _buildFooter(data),
          ),
        ],
      ),
    );
  }

  /// 🎨 Fond décoratif amélioré
  static Widget _buildBackgroundDecorations(Color primaryColor) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          left: -40,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          top: 120,
          right: 60,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          right: 30,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  /// 🎨 Bandes décoratives
  static Widget _buildDecorativeBands() {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          child: Container(
            width: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.3),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.2, 0.8, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 🏫 Logo de l'école amélioré avec toutes les infos
  static Widget _buildSchoolLogo({
    required String schoolName,
    String schoolType = '',
    String schoolPhone = '',
    String schoolEmail = '',
    String schoolWebsite = '',
    String schoolCode = '',
  }) {
    final initial = schoolName.trim().isNotEmpty
        ? schoolName.trim()[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                schoolName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
              if (schoolType.isNotEmpty)
                Text(
                  schoolType,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              Text(
                'CARTE DE PRÉSENCE',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 7,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 📱 Section QR Code - améliorée
  static Widget _buildQRCodeSection(StudentCardData data) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: QrImageView(
          data: _generateQRData(data),
          version: QrVersions.auto,
          size: 126,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),
    );
  }

  /// 📋 Section Informations - améliorée
  static Widget _buildInfoSection(StudentCardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          data.fullName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            shadows: [
              Shadow(
                color: Colors.black26,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 4),

        Container(
          height: 3,
          width: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [data.secondaryColor, data.accentColor],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        const SizedBox(height: 10),

        _buildInfoRow('Classe', data.className, isBold: true),
        if (data.sectionName != null && data.sectionName!.isNotEmpty)
          _buildInfoRow('Section', data.sectionName!),
        if (data.birthDate != null && data.birthDate!.isNotEmpty)
          _buildInfoRow('Naissance', data.birthDate!),
        if (data.gender != null && data.gender!.isNotEmpty)
          _buildInfoRow('Sexe', data.gender!),
        if (data.parentPhone != null && data.parentPhone!.isNotEmpty)
          _buildInfoRow('Parent', data.parentPhone!),

        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [data.secondaryColor, data.secondaryColor.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: data.secondaryColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            'Présence - ${data.classCycleType.toUpperCase()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  /// 📝 Ligne d'information
  static Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(
            '$label :',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: isBold ? 13 : 11,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
                shadows: [
                  Shadow(
                    color: Colors.black12,
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 📅 Pied de carte
  static Widget _buildFooter(StudentCardData data) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Carte de présence',
            style: TextStyle(
              fontSize: 8,
              color: Colors.white.withOpacity(0.3),
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
          ),
          Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Généré le ${_formatDate(data.generationDate)}',
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.white.withOpacity(0.3),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 🔗 Générer les données du QR Code
  static String _generateQRData(StudentCardData data) {
    final qrData = {
      'type': 'student_attendance',
      'studentId': data.studentId,
      'studentName': data.fullName,
      'className': data.className,
      'classCycleType': data.classCycleType,
      'sectionName': data.sectionName,
      'parentPhone': data.parentPhone,
      'schoolId': data.schoolId,
      'schoolName': data.schoolName,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(qrData);
  }

  /// 📅 Formater la date
  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
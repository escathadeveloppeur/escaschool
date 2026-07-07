// lib/services/staff_card_service.dart

import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/staff_card_model.dart';

class StaffCardService {
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

  /// 📇 Générer une carte de service pour le personnel (image PNG)
  static Future<Uint8List> generateStaffCard({
    required StaffCardData data,
    int width = 600,
    int height = 400,
    double pixelRatio = 2.0,
  }) async {
    try {
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

  /// 📇 Générer une carte pour impression (image haute qualité)
  static Future<Uint8List> generateStaffCardForPrint({
    required StaffCardData data,
    int width = 800,
    int height = 550,
  }) async {
    return await generateStaffCard(
      data: data,
      width: width,
      height: height,
      pixelRatio: 3.0,
    );
  }

  /// 🖨️ Générer un PDF avec 9 cartes de service par page
  static Future<Uint8List> generateStaffCardsPDF(
    List<StaffCardData> staffList,
    String schoolName,
  ) async {
    final pdf = pw.Document();

    final pageFormat = PdfPageFormat.a4;
    const int cardsPerRow = 3;
    const int cardsPerColumn = 3;
    const int cardsPerPage = cardsPerRow * cardsPerColumn;

    // Calcul des tailles
    final double margin = 15;
    final double headerHeight = 35;
    final double footerHeight = 20;
    final double availableWidth = pageFormat.width - (margin * 2);
    final double availableHeight = pageFormat.height - (margin * 2) - headerHeight - footerHeight;
    
    final double cardWidth = (availableWidth - (cardsPerRow - 1) * 8) / cardsPerRow;
    final double cardHeight = (availableHeight - (cardsPerColumn - 1) * 8) / cardsPerColumn;

    for (var i = 0; i < staffList.length; i += cardsPerPage) {
      final pageStaff = staffList.sublist(
        i,
        (i + cardsPerPage < staffList.length) ? i + cardsPerPage : staffList.length,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(margin), // ✅ Retirer 'const'
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ✅ En-tête
                pw.Container(
                  height: headerHeight,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            schoolName.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.Text(
                            'Cartes de service',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue100,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          '${pageStaff.length} cartes',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ Grille 3x3 des cartes
                pw.Expanded(
                  child: pw.Column(
                    children: List.generate(
                      _calculateRows(pageStaff.length, cardsPerRow),
                      (rowIndex) {
                        final startIndex = rowIndex * cardsPerRow;
                        final endIndex = (startIndex + cardsPerRow) > pageStaff.length
                            ? pageStaff.length
                            : startIndex + cardsPerRow;
                        final rowStaff = pageStaff.sublist(startIndex, endIndex);

                        return pw.Expanded(
                          child: pw.Row(
                            children: List.generate(cardsPerRow, (colIndex) {
                              if (colIndex < rowStaff.length) {
                                final staff = rowStaff[colIndex];
                                return pw.Expanded(
                                  child: pw.Padding(
                                    padding: const pw.EdgeInsets.all(3),
                                    child: _buildStaffCardPDF(staff, cardWidth, cardHeight),
                                  ),
                                );
                              } else {
                                return pw.Expanded(
                                  child: pw.Container(),
                                );
                              }
                            }),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ✅ Pied de page
                pw.Container(
                  height: footerHeight,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Généré le ${_formatDate(DateTime.now())}',
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey500,
                        ),
                      ),
                      pw.Text(
                        'Page ${(i / cardsPerPage).floor() + 1}',
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return await pdf.save();
  }

  /// 🏗️ Construire une carte de service en PDF pur
  static pw.Widget _buildStaffCardPDF(StaffCardData data, double width, double height) {
    return pw.Container(
      width: width,
      height: height,
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
          colors: const [
            PdfColors.teal800,
            PdfColors.teal600,
          ],
        ),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Stack(
        children: [
          // Fond décoratif
          pw.Positioned(
            top: -20,
            right: -20,
            child: pw.Container(
              width: 50,
              height: 50,
              decoration: pw.BoxDecoration(
                color: PdfColor(1, 1, 1, 0.05),
                shape: pw.BoxShape.circle,
              ),
            ),
          ),
          pw.Positioned(
            bottom: -15,
            left: -15,
            child: pw.Container(
              width: 40,
              height: 40,
              decoration: pw.BoxDecoration(
                color: PdfColor(1, 1, 1, 0.05),
                shape: pw.BoxShape.circle,
              ),
            ),
          ),
          
          // Contenu
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // En-tête avec poste
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: PdfColor(1, 1, 1, 0.15),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Icon(
                        pw.IconData(0xe7fd),
                        size: 8,
                        color: PdfColors.white,
                      ),
                      pw.SizedBox(width: 4),
                      pw.Text(
                        data.position.toUpperCase(),
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 6,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                
                pw.SizedBox(height: 4),
                
                // Corps
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // QR Code
                      pw.Container(
                        width: 45,
                        height: 45,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: _generateQRData(data),
                            drawText: false,
                            width: 37,
                            height: 37,
                          ),
                        ),
                      ),
                      
                      pw.SizedBox(width: 6),
                      
                      // Informations
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text(
                              data.fullName,
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                              maxLines: 2,
                            ),
                            pw.SizedBox(height: 2),
                            if (data.phone != null && data.phone!.isNotEmpty)
                              pw.Text(
                                '📞 ${data.phone}',
                                style: pw.TextStyle(
                                  fontSize: 6,
                                ),
                              ),
                            if (data.email != null && data.email!.isNotEmpty)
                              pw.Text(
                                '✉️ ${data.email}',
                                style: pw.TextStyle(
                                  fontSize: 6,
                                ),
                              ),
                            pw.SizedBox(height: 2),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: pw.BoxDecoration(
                                gradient: pw.LinearGradient(
                                  colors: data.isActive 
                                      ? [PdfColors.green400, PdfColors.green600]
                                      : [PdfColors.grey400, PdfColors.grey600],
                                ),
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Text(
                                data.isActive ? 'ACTIF' : 'INACTIF',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Pied de carte
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Carte service',
                        style: pw.TextStyle(
                          fontSize: 5,
                          color: PdfColor(1, 1, 1, 0.3),
                        ),
                      ),
                      pw.Text(
                        _formatDate(data.generationDate),
                        style: pw.TextStyle(
                          fontSize: 5,
                          color: PdfColor(1, 1, 1, 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 🏗️ Construire le widget de la carte (image)
  static Widget _buildCardWidget(
    StaffCardData data,
    int width,
    int height,
    Map<String, dynamic>? schoolInfo,
  ) {
    final schoolName = schoolInfo?['name'] ?? data.schoolName;
    final schoolType = schoolInfo?['type'] ?? '';
    
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
          _buildBackgroundDecorations(data.primaryColor),
          _buildDecorativeBands(),
          
          Positioned(
            top: 20,
            left: 24,
            child: _buildSchoolLogoWidget(schoolName, schoolType),
          ),
          
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
          
          Positioned(
            bottom: 14,
            left: 24,
            right: 24,
            child: _buildFooterWidget(data),
          ),
        ],
      ),
    );
  }

  /// 🎨 Fond décoratif
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

  /// 🏫 Logo de l'école (widget)
  static Widget _buildSchoolLogoWidget(String schoolName, String schoolType) {
    final initial = schoolName.trim().isNotEmpty ? schoolName.trim()[0].toUpperCase() : '?';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
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
                'CARTE DE SERVICE',
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

  /// 📱 Section QR Code
  static Widget _buildQRCodeSection(StaffCardData data) {
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

  /// 📋 Section Informations
  static Widget _buildInfoSection(StaffCardData data) {
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
        _buildInfoRowWidget('Poste', data.position, isBold: true),
        if (data.phone != null && data.phone!.isNotEmpty)
          _buildInfoRowWidget('📞', data.phone!),
        if (data.email != null && data.email!.isNotEmpty)
          _buildInfoRowWidget('✉️', data.email!),
        _buildInfoRowWidget('📅', 'Embauché le ${_formatDate(data.hireDate)}'),
        _buildInfoRowWidget('💰', '${data.salary.toStringAsFixed(0)} FCFA/mois'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                data.isActive ? data.secondaryColor : Colors.grey,
                data.isActive ? data.secondaryColor.withOpacity(0.8) : Colors.grey.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (data.isActive ? data.secondaryColor : Colors.grey).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            data.isActive ? '✅ ACTIF' : '❌ INACTIF',
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

  /// 📝 Ligne d'information (widget)
  static Widget _buildInfoRowWidget(String label, String value, {bool isBold = false}) {
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

  /// 📅 Pied de carte (widget)
  static Widget _buildFooterWidget(StaffCardData data) {
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
            'Carte de service',
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

  /// 📤 Partager le PDF des cartes de service
  static Future<void> shareStaffCardsPDF(List<StaffCardData> staffList, String schoolName) async {
    try {
      final pdfBytes = await generateStaffCardsPDF(staffList, schoolName);
      
      final tempDir = await getTemporaryDirectory();
      final fileName = 'Cartes_Service_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '🆔 Cartes de service - $schoolName',
      );
      
      print('✅ PDF partagé');
    } catch (e) {
      print('❌ Erreur lors du partage: $e');
      throw e;
    }
  }

  /// 💾 Sauvegarder le PDF des cartes de service
  static Future<String> saveStaffCardsPDF(List<StaffCardData> staffList, String schoolName) async {
    try {
      final pdfBytes = await generateStaffCardsPDF(staffList, schoolName);
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'Cartes_Service_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';
      
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);
      
      print('✅ PDF sauvegardé: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Erreur lors de la sauvegarde du PDF: $e');
      throw e;
    }
  }

  /// 🖨️ Imprimer les cartes de service
  static Future<void> printStaffCardsPDF(List<StaffCardData> staffList, String schoolName) async {
    try {
      final pdfBytes = await generateStaffCardsPDF(staffList, schoolName);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Cartes_Service_${DateTime.now().millisecondsSinceEpoch}',
      );
      print('✅ Impression lancée');
    } catch (e) {
      print('❌ Erreur d\'impression: $e');
      throw Exception('Impossible d\'imprimer: $e');
    }
  }

  static String _generateQRData(StaffCardData data) {
    // ✅ Format pour le scan: staffId|staffName|position|schoolId
    return '${data.staffId}|${data.fullName}|${data.position}|${data.schoolId}';
  }

  static int _calculateRows(int totalItems, int itemsPerRow) {
    return (totalItems / itemsPerRow).ceil();
  }

  /// 📅 Formater la date
  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // 🔄 Méthodes existantes pour la sauvegarde individuelle
  static Future<void> shareCard(Uint8List imageBytes, String staffName) async {
    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'carte_${staffName.replaceAll(' ', '_')}_$timestamp.png';
      final filePath = '${directory.path}/$fileName';
      
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '🆔 Carte de service - ${staffName.toUpperCase()}',
      );
      
      print('✅ Carte partagée');
    } catch (e) {
      print('❌ Erreur lors du partage: $e');
      throw e;
    }
  }

  static Future<String> saveCardToDevice(Uint8List imageBytes, String staffName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'carte_${staffName.replaceAll(' ', '_')}_$timestamp.png';
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
}
// lib/services/qr_code_print_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/qr_code_model.dart';

class QRCodePrintService {
  /// 🖨️ Générer un PDF avec tous les QR codes d'une classe
  static Future<Uint8List> generateQRCodePDF(ClassQRCodeGroup classGroup) async {
    final pdf = pw.Document();

    // Créer une grille de QR codes
    final pageFormat = PdfPageFormat.a4;
    final pageWidth = pageFormat.width;
    final pageHeight = pageFormat.height;
    
    const int qrPerRow = 4;
    const int qrPerColumn = 3;
    const int totalQRPerPage = qrPerRow * qrPerColumn;
    
    final qrSize = (pageWidth / qrPerRow) * 0.8;
    final horizontalSpacing = (pageWidth - (qrPerRow * qrSize)) / (qrPerRow + 1);
    final verticalSpacing = (pageHeight - (qrPerColumn * qrSize)) / (qrPerColumn + 1);

    // Diviser les étudiants en pages
    for (var i = 0; i < classGroup.students.length; i += totalQRPerPage) {
      final pageStudents = classGroup.students.sublist(
        i,
        (i + totalQRPerPage < classGroup.students.length) ? i + totalQRPerPage : classGroup.students.length,
      );

      pdf.addPage(
        pw.Page(
          build: (context) {
            return pw.Stack(
              children: [
                // En-tête
                pw.Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: pw.Center(
                    child: pw.Text(
                      'QR Codes - ${classGroup.className}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                pw.Positioned(
                  top: 45,
                  left: 0,
                  right: 0,
                  child: pw.Center(
                    child: pw.Text(
                      'École: ${classGroup.schoolName}',
                      style: pw.TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                // Grille de QR codes
                pw.Positioned(
                  top: 80,
                  left: horizontalSpacing / 2,
                  right: horizontalSpacing / 2,
                  bottom: 40,
                  child: pw.Wrap(
                    spacing: horizontalSpacing,
                    runSpacing: verticalSpacing,
                    children: pageStudents.map((student) {
                      return pw.Container(
                        width: qrSize,
                        height: qrSize + 50,
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.start,
                          children: [
                            // QR Code - Utilisation de BarcodeWidget
                            pw.Container(
                              width: qrSize,
                              height: qrSize,
                              child: pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: student.qrCodeData,
                                drawText: false,
                              ),
                            ),
                            // Nom de l'élève
                            pw.SizedBox(height: 5),
                            pw.Text(
                              student.studentName,
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                            pw.Text(
                              student.id,
                              style: pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Pied de page
                pw.Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: pw.Center(
                    child: pw.Text(
                      'Généré le ${DateTime.now().toLocal().toString().split(' ')[0]}',
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey,
                      ),
                    ),
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

  /// 🖨️ Imprimer les QR codes
  static Future<void> printQRCodes(ClassQRCodeGroup classGroup) async {
    try {
      final pdfBytes = await generateQRCodePDF(classGroup);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
      print('✅ Impression lancée');
    } catch (e) {
      print('❌ Erreur d\'impression: $e');
      throw e;
    }
  }

  /// 💾 Sauvegarder le PDF des QR codes
  static Future<String> saveQRCodePDF(ClassQRCodeGroup classGroup) async {
    try {
      final pdfBytes = await generateQRCodePDF(classGroup);
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'qrcodes_${classGroup.className.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
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
}
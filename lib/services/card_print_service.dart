// lib/services/card_print_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/student_card_model.dart';
import 'student_card_service.dart';

class CardPrintService {
  /// Ratio largeur/hauteur des cartes générées par
  /// StudentCardService.generateStudentCardForPrint (800 x 550 par défaut).
  /// Garder ce ratio ici évite toute déformation de l'image dans le PDF.
  static const double _cardAspectRatio = 800 / 550;

  /// 🖨️ Générer un PDF avec toutes les cartes d'une classe
  ///
  /// ✅ Chaque carte est désormais générée par StudentCardService
  /// (la même source que l'aperçu à l'écran), puis simplement insérée
  /// comme image dans le PDF. Il n'y a donc plus de deuxième version
  /// du design de carte à maintenir ici : le PDF affiche exactement
  /// ce que l'utilisateur voit dans l'aperçu.
  static Future<Uint8List> generateClassCardsPDF(
    List<StudentCardData> students,
    String className,
    String schoolName,
  ) async {
    final pdf = pw.Document();

    final pageFormat = PdfPageFormat.a4;
    
    // ✅ 9 cartes par page (3x3)
    const int cardsPerRow = 3;
    const int cardsPerColumn = 3;
    const int cardsPerPage = cardsPerRow * cardsPerColumn; // 9

    // ✅ Calculer la taille des cartes pour une grille 3x3
    final double margin = 25;
    final double availableWidth = pageFormat.width - (margin * 2);
    final double availableHeight = pageFormat.height - (margin * 2) - 60; // 60px pour l'en-tête
    
    final double cardWidth = (availableWidth - (cardsPerRow - 1) * 15) / cardsPerRow;
    final double cardHeight = cardWidth / _cardAspectRatio;
    
    // ✅ Vérifier que les cartes tiennent dans la hauteur
    final double totalHeight = (cardHeight * cardsPerColumn) + ((cardsPerColumn - 1) * 15);
    final double finalCardHeight = totalHeight > availableHeight 
        ? (availableHeight - ((cardsPerColumn - 1) * 15)) / cardsPerColumn
        : cardHeight;
    final double finalCardWidth = finalCardHeight * _cardAspectRatio;

    // ✅ On génère d'abord toutes les images de cartes (une seule fois
    // chacune), puis on les place dans les pages.
    final Map<String, Uint8List> cardImages = {};
    for (final student in students) {
      cardImages[student.studentId] =
          await StudentCardService.generateStudentCardForPrint(data: student);
    }

    for (var i = 0; i < students.length; i += cardsPerPage) {
      final pageStudents = students.sublist(
        i,
        (i + cardsPerPage < students.length) ? i + cardsPerPage : students.length,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(20),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ✅ En-tête avec école et classe
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            schoolName.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.Text(
                            'Classe: $className',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.normal,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue100,
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(
                          '${pageStudents.length} élèves',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                pw.Divider(thickness: 1.5),
                pw.SizedBox(height: 10),

                // ✅ Grille 3x3 des cartes
                pw.Column(
                  children: List.generate(
                    _calculateRows(pageStudents.length, cardsPerRow),
                    (rowIndex) {
                      final startIndex = rowIndex * cardsPerRow;
                      final endIndex = (startIndex + cardsPerRow) > pageStudents.length
                          ? pageStudents.length
                          : startIndex + cardsPerRow;
                      final rowStudents = pageStudents.sublist(startIndex, endIndex);

                      return pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.start,
                        children: List.generate(cardsPerRow, (colIndex) {
                          if (colIndex < rowStudents.length) {
                            final student = rowStudents[colIndex];
                            final imageBytes = cardImages[student.studentId]!;
                            return pw.Container(
                              width: finalCardWidth,
                              height: finalCardHeight,
                              margin: const pw.EdgeInsets.all(4),
                              child: pw.ClipRRect(
                                horizontalRadius: 8,
                                verticalRadius: 8,
                                child: pw.Image(
                                  pw.MemoryImage(imageBytes),
                                  width: finalCardWidth,
                                  height: finalCardHeight,
                                  fit: pw.BoxFit.contain,
                                ),
                              ),
                            );
                          } else {
                            // ✅ Cellule vide pour compléter la grille
                            return pw.Container(
                              width: finalCardWidth,
                              height: finalCardHeight,
                              margin: const pw.EdgeInsets.all(4),
                            );
                          }
                        }),
                      );
                    },
                  ),
                ),

                // ✅ Pied de page
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 10),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Généré le ${_formatDate(DateTime.now())}',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey500,
                        ),
                      ),
                      pw.Text(
                        'Page ${(i / cardsPerPage).floor() + 1}',
                        style: pw.TextStyle(
                          fontSize: 8,
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

  /// ✅ Calculer le nombre de lignes nécessaires
  static int _calculateRows(int totalItems, int itemsPerRow) {
    return (totalItems / itemsPerRow).ceil();
  }

  static String _formatDate(DateTime date) {
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static Future<void> printClassCards(
    List<StudentCardData> students,
    String className,
    String schoolName,
  ) async {
    try {
      final pdfBytes = await generateClassCardsPDF(students, className, schoolName);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Cartes_${className}_${DateTime.now().millisecondsSinceEpoch}',
      );
      print('✅ Impression des cartes lancée');
    } catch (e) {
      print('❌ Erreur d\'impression: $e');
      throw Exception('Impossible d\'imprimer: $e');
    }
  }

  static Future<String> saveClassCardsPDF(
    List<StudentCardData> students,
    String className,
    String schoolName,
  ) async {
    try {
      final pdfBytes = await generateClassCardsPDF(students, className, schoolName);
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'Cartes_${className.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
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

  static Future<void> shareClassCardsPDF(
    List<StudentCardData> students,
    String className,
    String schoolName,
  ) async {
    try {
      final filePath = await saveClassCardsPDF(students, className, schoolName);
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Cartes de présence - Classe $className',
      );
      print('✅ PDF partagé');
    } catch (e) {
      print('❌ Erreur lors du partage: $e');
      throw e;
    }
  }
}
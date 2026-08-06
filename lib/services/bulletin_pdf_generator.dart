// lib/services/bulletin_pdf_generator.dart
// Version adaptée fidèlement au modèle HTML (structure, texte, design identiques)

import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';

class BulletinPdfGenerator {
  static Uint8List? _drapeauBytes;
  static Uint8List? _emblemeBytes;
  static pw.Font? _unicodeFont;

  // Couleurs reprises du CSS (.dark-sep = #666, .grey-cell = #888)
  static final PdfColor _sepColor = PdfColor.fromHex('#666666');
  static final PdfColor _blockColor = PdfColor.fromHex('#888888');
  static final PdfColor _maximaBg = PdfColor.fromHex('#f0f0f0'); // .bg-maxima
  static final PdfColor _provinceBg = PdfColor.fromHex('#f9f9f9'); // .info-row (province)

  static Future<void> loadImages() async {
    try {
      final flagData = await rootBundle.load('assets/images/drapeau.png');
      _drapeauBytes = flagData.buffer.asUint8List();
      final emblemData = await rootBundle.load('assets/images/embleme.png');
      _emblemeBytes = emblemData.buffer.asUint8List();
    } catch (e) {
      _drapeauBytes = null;
      _emblemeBytes = null;
    }
  }

  static Future<void> loadFonts() async {
    try {
      final fontData = await rootBundle.load('assets/images/OpenSans-VariableFont_wdth,wght.ttf');
      _unicodeFont = pw.Font.ttf(fontData.buffer.asByteData());
    } catch (e) {
      _unicodeFont = null;
    }
  }

  static String _cleanText(String text) {
    return text
        .replaceAll('⚠️', '')
        .replaceAll('✅', '')
        .replaceAll('🌟', '')
        .replaceAll('🎓', '')
        .replaceAll('📊', '')
        .replaceAll('📚', '')
        .replaceAll('💪', '')
        .replaceAll('🎯', '')
        .replaceAll('👨‍🎓', '')
        .replaceAll('👨‍🏫', '')
        .replaceAll('👪', '')
        .replaceAll('💡', '')
        .replaceAll('📝', '')
        .replaceAll('📋', '')
        .replaceAll('📈', '')
        .replaceAll('📉', '')
        .replaceAll('💰', '')
        .replaceAll('💳', '')
        .replaceAll('🔑', '')
        .replaceAll('⚙️', '')
        .replaceAll('🏛️', '')
        .replaceAll('👥', '')
        .replaceAll('👤', '')
        .replaceAll('📧', '')
        .replaceAll('📱', '')
        .replaceAll('🏆', '')
        .replaceAll('✨', '')
        .replaceAll('🔥', '')
        .replaceAll('🌈', '')
        .replaceAll('⭐', '')
        .replaceAll('🎉', '')
        .replaceAll('🤖', '')
        .replaceAll('😊', '')
        .replaceAll('😅', '')
        .replaceAll('🙏', '')
        .replaceAll('🏫', '')
        .replaceAll('👩‍🏫', '')
        .replaceAll('📅', '')
        .replaceAll('⏰', '')
        .replaceAll('📌', '')
        .replaceAll('🔔', '')
        .replaceAll('📢', '')
        .replaceAll('💬', '')
        .replaceAll('📞', '')
        .replaceAll('📨', '')
        .replaceAll('📁', '')
        .replaceAll('📂', '')
        .replaceAll('📄', '')
        .replaceAll('📃', '')
        .replaceAll('📑', '')
        .replaceAll('🔍', '')
        .replaceAll('🔎', '')
        .replaceAll('📖', '')
        .replaceAll('📕', '')
        .replaceAll('📗', '')
        .replaceAll('📘', '')
        .replaceAll('📙', '')
        .replaceAll('📔', '')
        .replaceAll('📓', '')
        .replaceAll('📒', '')
        .replaceAll('📰', '')
        .replaceAll('🎖️', '')
        .replaceAll('🥇', '')
        .replaceAll('🥈', '')
        .replaceAll('🥉', '')
        .replaceAll('💯', '')
        .replaceAll('🔟', '')
        .replaceAll('➕', '+')
        .replaceAll('➖', '-')
        .replaceAll('✖️', 'x')
        .replaceAll('➗', '/')
        .replaceAll('✔️', '✓')
        .replaceAll('❌', '✗')
        .replaceAll('❎', '✗')
        .replaceAll('⭕', 'O')
        .replaceAll('🔴', '')
        .replaceAll('🟠', '')
        .replaceAll('🟡', '')
        .replaceAll('🟢', '')
        .replaceAll('🔵', '')
        .replaceAll('🟣', '')
        .replaceAll('⚫', '')
        .replaceAll('⚪', '')
        .replaceAll('🟤', '');
  }

  static pw.Widget _text(String text, {
    bool bold = false,
    double fontSize = 6.5,
    PdfColor color = PdfColors.black,
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    final cleanText = _cleanText(text);
    return pw.Text(
      cleanText,
      style: pw.TextStyle(
        font: _unicodeFont,
        fontSize: fontSize,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color,
      ),
      textAlign: align,
    );
  }

  static pw.Widget _cell(String text, {bool bold = false, double fontSize = 8}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 2),
      child: _text(text, bold: bold, fontSize: fontSize),
    );
  }

  static pw.Widget _blackSepCell() {
    return pw.Container(color: PdfColors.black);
  }

  static pw.Widget _greyCell() {
    return pw.Container(color: _blockColor);
  }

  static Future<void> generateBulletin({
    required Map<String, dynamic> studentData,
    required String className,
    required String teacherName,
    required List<Map<String, dynamic>> allGrades,
    required List<Map<String, dynamic>> examResults,
    required List<Map<String, dynamic>> attendances,
    required Map<String, String> schoolInfo,
    required int totalStudents,
    required List<Map<String, dynamic>> classSubjects,
  }) async {
    await loadImages();
    await loadFonts();

    final pdf = pw.Document();

    final courses = _convertGradesToCourses(studentData, allGrades, classSubjects);
    final stats = _calculateStatistics(courses);
    final student = studentData['student'] as Map<String, dynamic>;
    final ranking = studentData['ranking'] as int? ?? 1;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(2),
        build: (context) {
          return [
            _buildBulletin(
              student: student,
              className: className,
              courses: courses,
              stats: stats,
              schoolInfo: schoolInfo,
              totalStudents: totalStudents,
              teacherName: teacherName,
              ranking: ranking,
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static pw.Widget _buildBulletin({
    required Map<String, dynamic> student,
    required String className,
    required List<_CourseData> courses,
    required _Statistics stats,
    required Map<String, String> schoolInfo,
    required int totalStudents,
    required String teacherName,
    required int ranking,
  }) {
    final dob = student['dateOfBirth'] ?? student['dob'] ?? '__/__/____';
    final id = (student['idNumber'] ?? student['matricule'] ?? '').toString();

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 1.5, color: PdfColors.black),
      ),
      padding: const pw.EdgeInsets.all(3),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // ===== EN-TÊTE =====
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 65,
                height: 42,
                child: _drapeauBytes != null
                    ? pw.Image(pw.MemoryImage(_drapeauBytes!), fit: pw.BoxFit.cover)
                    : pw.Center(child: _text("RDC", bold: true, fontSize: 10)),
              ),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _text("REPUBLIQUE DEMOCRATIQUE DU CONGO", bold: true, fontSize: 8.5),
                    _text("MINISTERE DE L'ENSEIGNEMENT PRIMAIRE SECONDAIRE ET", fontSize: 7),
                    _text("INITIATION A LA NOUVELLE CITOYENNETE", fontSize: 7),
                  ],
                ),
              ),
              pw.Container(
                width: 42,
                height: 42,
                child: _emblemeBytes != null
                    ? pw.Image(pw.MemoryImage(_emblemeBytes!), fit: pw.BoxFit.contain)
                    : pw.Center(child: _text("RDC", bold: true, fontSize: 10)),
              ),
            ],
          ),

          pw.SizedBox(height: 1.5),

          pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.5, color: PdfColors.black),
              ),
              child: _text("BULLETIN SCOLAIRE", bold: true, fontSize: 10),
            ),
          ),

          pw.SizedBox(height: 1.5),

          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(width: 0.5, color: PdfColors.black),
                bottom: pw.BorderSide(width: 0.5, color: PdfColors.black),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(
              children: [
                _text("N° ID.", bold: true, fontSize: 8, align: pw.TextAlign.left),
                pw.SizedBox(width: 5),
                ...List.generate(27, (i) =>
                  pw.Container(
                    width: 11,
                    height: 13,
                    margin: const pw.EdgeInsets.only(right: 1),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 0.5, color: PdfColors.black),
                    ),
                    child: i < id.length
                        ? pw.Center(child: _text(id[i], fontSize: 7))
                        : null,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 1.5),

          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.black),
            columnWidths: const {
              0: pw.FlexColumnWidth(35),
              1: pw.FlexColumnWidth(65),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _provinceBg),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    child: _text(
                      "PROVINCE DE ${(schoolInfo['province'] ?? '_______________').toUpperCase()}",
                      bold: true,
                      fontSize: 8.5,
                      align: pw.TextAlign.left,
                    ),
                  ),
                  pw.Container(),
                ],
              ),
              pw.TableRow(children: [
                _cell("VILLE : ${schoolInfo['city'] ?? '______________'}", fontSize: 7.5),
                _cell("ELEVE : ${student['fullName'] ?? '..................................'}   SEXE : ${student['sexe'] ?? '__'}", fontSize: 7.5),
              ]),
              pw.TableRow(children: [
                _cell("COMMUNE : ${schoolInfo['commune'] ?? '______________'}", fontSize: 7.5),
                _cell("NE(E) A : ${student['birthPlace'] ?? '....................'}   LE $dob", fontSize: 7.5),
              ]),
              pw.TableRow(children: [
                _cell("ECOLE : ${schoolInfo['schoolName'] ?? '______________'}", fontSize: 7.5),
                _cell("CLASSE : $className", fontSize: 7.5),
              ]),
              pw.TableRow(children: [
                _cell("CODE : ${schoolInfo['schoolCode'] ?? '______________'}", fontSize: 7.5),
                pw.Row(
                  children: [
                    _cell("N° PERM", fontSize: 7.5),
                    ...List.generate(12, (_) =>
                      pw.Container(
                        width: 14,
                        height: 16,
                        margin: const pw.EdgeInsets.only(right: 1),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 0.5, color: PdfColors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ]),
            ],
          ),

          pw.SizedBox(height: 1.5),

          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 0.5, color: PdfColors.black),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _text("BULLETIN DE LA $className (1)", bold: true, fontSize: 8, align: pw.TextAlign.left),
                _text("ANNEE SCOLAIRE ${DateTime.now().year - 1} - ${DateTime.now().year}", bold: true, fontSize: 8),
              ],
            ),
          ),

          pw.SizedBox(height: 1.5),

          // ===== TABLEAU PRINCIPAL =====
          _buildMainTable(courses, stats, totalStudents, ranking),

          pw.SizedBox(height: 2),

          _text(
            "- L'élève est autorisé à passer dans la classe supérieure s'il a subi avec succès un examen de repêchage en ................................................ (1)",
            fontSize: 5.5,
            align: pw.TextAlign.left,
          ),
          _text("- L'élève passe dans la classe supérieure (1)", fontSize: 5.5, align: pw.TextAlign.left),
          _text("- L'élève double sa classe (1)", fontSize: 5.5, align: pw.TextAlign.left),
          _text("- L'élève a échoué et orientation vers .................... (1)", fontSize: 5.5, align: pw.TextAlign.left),

          pw.SizedBox(height: 3),

          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: _text(
              "Fait à ${schoolInfo['city'] ?? '.....................'}, le ..... / ..... / ${DateTime.now().year}",
              bold: true,
              fontSize: 7.5,
              align: pw.TextAlign.right,
            ),
          ),

          pw.SizedBox(height: 3),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _signatureCol("Signature de l'élève"),
              _signatureCol("Sceau de l'École"),
              _signatureCol("Le Chef d'Établissement,\nNom et signature"),
            ],
          ),

          pw.SizedBox(height: 3),

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 2,
                child: _text(
                  "(1) Biffer la mention inutile\nNote importante : Le bulletin n'est pas valable s'il n'est pas signé ou surchargé",
                  fontSize: 6,
                  align: pw.TextAlign.left,
                ),
              ),
              pw.Expanded(
                child: pw.Align(
                  alignment: pw.Alignment.bottomRight,
                  child: _text("IGE/P.S/094", bold: true, fontSize: 6, align: pw.TextAlign.right),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _signatureCol(String text) {
    return pw.Column(
      children: [
        _text(text, bold: true, fontSize: 7),
        pw.SizedBox(height: 12),
        pw.Container(width: 80, height: 0.5, color: PdfColors.black),
      ],
    );
  }

  // Largeurs de colonnes communes aux deux tableaux (0-10) pour un alignement parfait
  static Map<int, pw.TableColumnWidth> get _colWidths0to10 => const {
        0: pw.FlexColumnWidth(18), // BRANCHES
        1: pw.FlexColumnWidth(4),  // 1ere P
        2: pw.FlexColumnWidth(4),  // 2eme P
        3: pw.FlexColumnWidth(5),  // EXAM
        4: pw.FlexColumnWidth(5),  // TOT.
        5: pw.FlexColumnWidth(4),  // 3eme P
        6: pw.FlexColumnWidth(4),  // 4eme P
        7: pw.FlexColumnWidth(5),  // EXAM
        8: pw.FlexColumnWidth(5),  // TOT.
        9: pw.FlexColumnWidth(4),  // T.G.
        10: pw.FlexColumnWidth(2), // séparateur foncé
      };

  static Map<int, pw.TableColumnWidth> get _colWidthsFull13 => {
        ..._colWidths0to10,
        11: const pw.FlexColumnWidth(3.5),  // %
        12: const pw.FlexColumnWidth(8), // SIGN. PROF
      };

  // Somme des flex 0-10 = 73 ; somme des flex 11-12 = 17 (utilisé pour aligner
  // le tableau du bas (0-10) + le bloc décision (11-12 fusionné) sous forme de Row).
  static const int _flexLeft = 73;
  static const int _flexRight = 17;

  static pw.Widget _headerCell(String text, {int colspan = 1, int rowspan = 1}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(1),
      child: pw.Center(
        child: _text(text, bold: true, fontSize: 6.5),
      ),
    );
  }

  // ===== TABLEAU PRINCIPAL =====
  static pw.Widget _buildMainTable(
    List<_CourseData> courses,
    _Statistics stats,
    int totalStudents,
    int ranking,
  ) {
    final rows = <pw.TableRow>[];

    // ===== TITRE AU-DESSUS DU TABLEAU =====
    final headerTitle = pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5, color: PdfColors.black),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 18,
            child: pw.Center(
              child: _text("BRANCHES", bold: true, fontSize: 6.5),
            ),
          ),
          pw.Expanded(
            flex: 18, // 4+4+5+5 = 18
            child: pw.Center(
              child: _text("PREMIER SEMESTRE", bold: true, fontSize: 6.5),
            ),
          ),
          pw.Expanded(
            flex: 18, // 4+4+5+5 = 18
            child: pw.Center(
              child: _text("SECOND SEMESTRE", bold: true, fontSize: 6.5),
            ),
          ),
          pw.Expanded(
            flex: 4,
            child: pw.Center(
              child: _text("T.G.", bold: true, fontSize: 6.5),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Container(color: PdfColors.black),
          ),
          pw.Expanded(
            flex: 12, // 4+8 = 12
            child: pw.Center(
              child: _text("EXAMEN DE REPECHAGE", bold: true, fontSize: 6.5),
            ),
          ),
        ],
      ),
    );

    // ===== LIGNE DES SOUS-TITRES =====
    final subHeaderRow = pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 0.5, color: PdfColors.black),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 18, child: pw.Container()), // Col 0: vide
          pw.Expanded(flex: 4, child: pw.Center(child: _text("1ere P", bold: true, fontSize: 6))),
          pw.Expanded(flex: 4, child: pw.Center(child: _text("2eme P", bold: true, fontSize: 6))),
          pw.Expanded(flex: 5, child: pw.Center(child: _text("EXAM", bold: true, fontSize: 6))),
          pw.Expanded(flex: 5, child: pw.Center(child: _text("TOT.", bold: true, fontSize: 6))),
          pw.Expanded(flex: 4, child: pw.Center(child: _text("3eme P", bold: true, fontSize: 6))),
          pw.Expanded(flex: 4, child: pw.Center(child: _text("4eme P", bold: true, fontSize: 6))),
          pw.Expanded(flex: 5, child: pw.Center(child: _text("EXAM", bold: true, fontSize: 6))),
          pw.Expanded(flex: 5, child: pw.Center(child: _text("TOT.", bold: true, fontSize: 6))),
          pw.Expanded(flex: 4, child: pw.Container()), // Col 9: vide
          pw.Expanded(flex: 2, child: pw.Container(color: PdfColors.black)), // Col 10
          pw.Expanded(flex: 4, child: pw.Center(child: _text("%", bold: true, fontSize: 6))),
          pw.Expanded(flex: 8, child: pw.Center(child: _text("SIGN. PROF", bold: true, fontSize: 6))),
        ],
      ),
    );

    // ===== DÉFINITION DES CATÉGORIES AVEC LEURS MAXIMA =====
    final List<Map<String, dynamic>> categories = [
      {'id': 'premiere', 'p1': 10, 'p2': 10, 'ex1': 20, 'p3': 10, 'p4': 10, 'ex2': 20},
      {'id': 'deuxieme', 'p1': 20, 'p2': 20, 'ex1': 40, 'p3': 20, 'p4': 20, 'ex2': 40},
      {'id': 'troisieme', 'p1': 40, 'p2': 40, 'ex1': 80, 'p3': 40, 'p4': 40, 'ex2': 80},
      {'id': 'quatrieme', 'p1': 50, 'p2': 50, 'ex1': 100, 'p3': 50, 'p4': 50, 'ex2': 100},
      {'id': 'cinquieme', 'p1': 100, 'p2': 100, 'ex1': 0, 'p3': 100, 'p4': 100, 'ex2': 0},
    ];

    // ===== REGROUPER LES COURS PAR CATÉGORIE =====
    final Map<String, List<_CourseData>> coursesByCategory = {};
    
    for (var cat in categories) {
      coursesByCategory[cat['id']] = [];
    }
    
    for (var course in courses) {
      String catId = 'premiere';
      if (course.p1Max == 10) catId = 'premiere';
      else if (course.p1Max == 20) catId = 'deuxieme';
      else if (course.p1Max == 40) catId = 'troisieme';
      else if (course.p1Max == 50) catId = 'quatrieme';
      else if (course.p1Max == 100) catId = 'cinquieme';
      
      coursesByCategory[catId]?.add(course);
    }

    // ===== PARCOURIR LES CATÉGORIES DANS L'ORDRE =====
    for (var cat in categories) {
      final catId = cat['id'];
      final categoryCourses = coursesByCategory[catId] ?? [];
      
      if (categoryCourses.isEmpty) continue;
      
      final int p1Max = cat['p1'];
      final int p2Max = cat['p2'];
      final int ex1Max = cat['ex1'];
      final int p3Max = cat['p3'];
      final int p4Max = cat['p4'];
      final int ex2Max = cat['ex2'];
      final int totalMax = p1Max + p2Max + ex1Max + p3Max + p4Max + ex2Max;

      // ===== LIGNE MAXIMA =====
      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _maximaBg),
          children: [
            _dataCell("MAXIMA", bold: true, align: pw.TextAlign.left),
            _dataCell(p1Max == 0 ? "" : "$p1Max"),
            _dataCell(p2Max == 0 ? "" : "$p2Max"),
            ex1Max == 0 ? _greyCell() : _dataCell("$ex1Max"),
            _dataCell("${p1Max + p2Max + ex1Max}", bold: true),
            _dataCell(p3Max == 0 ? "" : "$p3Max"),
            _dataCell(p4Max == 0 ? "" : "$p4Max"),
            ex2Max == 0 ? _greyCell() : _dataCell("$ex2Max"),
            _dataCell("${p3Max + p4Max + ex2Max}", bold: true),
            _dataCell("$totalMax", bold: true),
            _blackSepCell(),
            _dataCell(""),
            _dataCell(""),
          ],
        ),
      );

      // ===== LIGNES DES MATIÈRES =====
      for (var c in categoryCourses) {
        rows.add(
          pw.TableRow(
            children: [
              _dataCell(c.nom.toUpperCase(), align: pw.TextAlign.left, fontSize: 7),
              _dataCell(c.p1.toStringAsFixed(1)),
              _dataCell(c.p2.toStringAsFixed(1)),
              ex1Max == 0 ? _greyCell() : _dataCell(c.ex1.toStringAsFixed(1)),
              _dataCell(c.total1.toStringAsFixed(1), bold: true),
              _dataCell(c.p3.toStringAsFixed(1)),
              _dataCell(c.p4.toStringAsFixed(1)),
              ex2Max == 0 ? _greyCell() : _dataCell(c.ex2.toStringAsFixed(1)),
              _dataCell(c.total2.toStringAsFixed(1), bold: true),
              _dataCell(c.totalGeneral.toStringAsFixed(1), bold: true),
              _blackSepCell(),
              _dataCell(""),
              _dataCell(""),
            ],
          ),
        );
      }
    }

    // ===== MAXIMA GENERAUX =====
    double totalMaxAll = 0;
    for (var c in courses) {
      totalMaxAll += c.totalMax;
    }

    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: _maximaBg),
        children: [
          _dataCell("MAXIMA GENERAUX", bold: true, align: pw.TextAlign.left, fontSize: 6.5),
          _dataCell(stats.maxP1.toStringAsFixed(0)),
          _dataCell(stats.maxP2.toStringAsFixed(0)),
          _dataCell(stats.maxEx1.toStringAsFixed(0)),
          _dataCell(""),
          _dataCell(stats.maxP3.toStringAsFixed(0)),
          _dataCell(stats.maxP4.toStringAsFixed(0)),
          _dataCell(stats.maxEx2.toStringAsFixed(0)),
          _dataCell(""),
          _dataCell(totalMaxAll.toStringAsFixed(0), bold: true),
          _blackSepCell(),
          _dataCell(""),
          _dataCell(""),
        ],
      ),
    );

    // ===== TOTAUX =====
    rows.add(
      pw.TableRow(
        children: [
          _dataCell("TOTAUX", bold: true, align: pw.TextAlign.left, fontSize: 6.5),
          _dataCell(stats.totalP1.toStringAsFixed(1)),
          _dataCell(stats.totalP2.toStringAsFixed(1)),
          _dataCell(stats.totalEx1.toStringAsFixed(1)),
          _dataCell(""),
          _dataCell(stats.totalP3.toStringAsFixed(1)),
          _dataCell(stats.totalP4.toStringAsFixed(1)),
          _dataCell(stats.totalEx2.toStringAsFixed(1)),
          _dataCell(""),
          stats.canCalculateTG 
              ? _dataCell(stats.totalGeneral.toStringAsFixed(1), bold: true)
              : _dataCell("NON CALC.", bold: true),
          _blackSepCell(),
          _dataCell(""),
          _dataCell(""),
        ],
      ),
    );

    // ===== POURCENTAGE =====
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          _dataCell("POURCENTAGE", bold: true, align: pw.TextAlign.left, fontSize: 6.5),
          _dataCell("${stats.pourcentageP1.toStringAsFixed(1)}%"),
          _dataCell("${stats.pourcentageP2.toStringAsFixed(1)}%"),
          _dataCell("${stats.pourcentageEx1.toStringAsFixed(1)}%"),
          _dataCell(""),
          _dataCell("${stats.pourcentageP3.toStringAsFixed(1)}%"),
          _dataCell("${stats.pourcentageP4.toStringAsFixed(1)}%"),
          _dataCell("${stats.pourcentageEx2.toStringAsFixed(1)}%"),
          _dataCell(""),
          stats.canCalculateTG 
              ? _dataCell("${stats.pourcentage.toStringAsFixed(1)}%", bold: true)
              : _dataCell("NON CALC.", bold: true),
          _blackSepCell(),
          _dataCell(""),
          _dataCell(""),
        ],
      ),
    );

    // ===== PLACE =====
    rows.add(
      pw.TableRow(
        children: [
          _dataCell("PLACE/\nNBRE ELEVES", bold: true, align: pw.TextAlign.left, fontSize: 6.5),
          _dataCell("$ranking / $totalStudents"),
          _dataCell("$ranking / $totalStudents"),
          _dataCell("$ranking / $totalStudents"),
          _dataCell(""),
          _dataCell("$ranking / $totalStudents"),
          _dataCell("$ranking / $totalStudents"),
          _dataCell("$ranking / $totalStudents"),
          _dataCell(""),
          _dataCell("$ranking / $totalStudents", bold: true),
          _blackSepCell(),
          _dataCell(""),
          _dataCell(""),
        ],
      ),
    );

    // ===== APPLICATION, CONDUITE, SIGN. RESPONSABLE =====
    rows.add(_behaviorRow11("APPLICATION"));
    rows.add(_behaviorRow11("CONDUITE"));
    rows.add(_summaryRow11("SIGN. RESPONSABLE", ""));

    // ===== TABLEAU =====
    final table = pw.Table(
      border: pw.TableBorder.all(width: 0.5, color: PdfColors.black),
      columnWidths: _colWidthsFull13,
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
      children: rows,
    );

    // ===== ASSEMBLER =====
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        headerTitle,
        subHeaderRow,
        table,
      ],
    );
  }

  // Ligne de résumé sur les colonnes 0-10 (label + 8 cases + valeur T.G. + séparateur)
  static pw.TableRow _summaryRow11(String label, String value) {
    return pw.TableRow(
      children: [
        _dataCell(label, bold: true, align: pw.TextAlign.left, fontSize: 6.5),
        for (int i = 0; i < 8; i++) _dataCell(""),
        _dataCell(value, bold: true, fontSize: 6.5), // Col 9
        _blackSepCell(), // Col 10 - NOIR
        _dataCell(""),
        _dataCell(""),
      ],
    );
  }

  // Ligne "comportement" (APPLICATION / CONDUITE) avec cases bloquées grisées
  static pw.TableRow _behaviorRow11(String label) {
    return pw.TableRow(
      children: [
        _dataCell(label, bold: true, align: pw.TextAlign.left, fontSize: 6.5),
        _dataCell(""),
        _dataCell(""),
        _greyCell(),
        _greyCell(),
        _dataCell(""),
        _dataCell(""),
        _greyCell(),
        _greyCell(),
        _greyCell(),
        _blackSepCell(),
        _dataCell(""),
        _dataCell(""),
      ],
    );
  }

  static pw.Widget _dataCell(String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.center,
    double fontSize = 6.5,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 1),
      child: _text(text, bold: bold, fontSize: fontSize, align: align),
    );
  }

  // ===== CONVERSION DES DONNÉES =====
  static List<_CourseData> _convertGradesToCourses(
    Map<String, dynamic> studentData,
    List<Map<String, dynamic>> allGrades,
    List<Map<String, dynamic>> classSubjects,
  ) {
    final grades = studentData['grades'] as List<Map<String, dynamic>>;
    final Map<String, List<Map<String, dynamic>>> gradesBySubject = {};
    for (var grade in grades) {
      final subject = grade['subject'] as String;
      gradesBySubject.putIfAbsent(subject, () => []).add(grade);
    }

    final List<_CourseData> courses = [];
    for (var entry in gradesBySubject.entries) {
      final subjectName = entry.key;
      final subjectGrades = entry.value;
      final subjectInfo = classSubjects.firstWhere(
        (s) => s['name'] == subjectName,
        orElse: () => {},
      );
      final maxValues = subjectInfo['maxValues'];

      int p1Max = 10, p2Max = 10, ex1Max = 20;
      int p3Max = 10, p4Max = 10, ex2Max = 20;

      if (maxValues != null) {
        p1Max = maxValues['p1'] ?? 10;
        p2Max = maxValues['p2'] ?? 10;
        ex1Max = maxValues['ex1'] ?? 20;
        p3Max = maxValues['p3'] ?? 10;
        p4Max = maxValues['p4'] ?? 10;
        ex2Max = maxValues['ex2'] ?? 20;
      }

      final sem1Grades = subjectGrades.where((g) => (g['semester'] as String? ?? 'S1') == 'S1').toList();
      final sem2Grades = subjectGrades.where((g) => (g['semester'] as String? ?? 'S1') == 'S2').toList();

      final p1 = _calculatePeriodAverage(sem1Grades.where((g) => _isDevoir1(g['evaluationType'])).toList(), p1Max);
      final p2 = _calculatePeriodAverage(sem1Grades.where((g) => _isDevoir2(g['evaluationType'])).toList(), p2Max);
      final ex1 = _calculatePeriodAverage(sem1Grades.where((g) => _isExamen(g['evaluationType'])).toList(), ex1Max);
      final p3 = _calculatePeriodAverage(sem2Grades.where((g) => _isDevoir1(g['evaluationType'])).toList(), p3Max);
      final p4 = _calculatePeriodAverage(sem2Grades.where((g) => _isDevoir2(g['evaluationType'])).toList(), p4Max);
      final ex2 = _calculatePeriodAverage(sem2Grades.where((g) => _isExamen(g['evaluationType'])).toList(), ex2Max);

      courses.add(_CourseData(
        nom: subjectName,
        p1: p1, p2: p2, ex1: ex1,
        p3: p3, p4: p4, ex2: ex2,
        p1Max: p1Max, p2Max: p2Max, ex1Max: ex1Max,
        p3Max: p3Max, p4Max: p4Max, ex2Max: ex2Max,
      ));
    }
    return courses;
  }

  static bool _isDevoir1(String evaluationType) {
    final cleanType = evaluationType.replaceAll(' S2', '').trim();
    return cleanType == 'Devoir 1';
  }

  static bool _isDevoir2(String evaluationType) {
    final cleanType = evaluationType.replaceAll(' S2', '').trim();
    return cleanType == 'Devoir 2';
  }

  static bool _isExamen(String evaluationType) {
    final cleanType = evaluationType.replaceAll(' S2', '').trim();
    return cleanType == 'Examen';
  }

  static double _calculatePeriodAverage(List<Map<String, dynamic>> grades, int periodMax) {
    if (grades.isEmpty || periodMax == 0) return 0;
    double totalWeightedMax = 0;
    for (var grade in grades) {
      totalWeightedMax += (grade['maxScore'] as double) * (grade['coefficient'] as double);
    }
    if (totalWeightedMax == 0) return 0;
    final conversionFactor = periodMax / totalWeightedMax;
    double totalObtained = 0;
    for (var grade in grades) {
      final score = grade['score'] as double;
      final maxScore = grade['maxScore'] as double;
      final coefficient = grade['coefficient'] as double;
      final partPeriodMax = maxScore * coefficient * conversionFactor;
      totalObtained += (score / maxScore) * partPeriodMax;
    }
    return totalObtained;
  }

  static _Statistics _calculateStatistics(List<_CourseData> courses) {
    double totalP1 = 0, totalP2 = 0, totalEx1 = 0, totalP3 = 0, totalP4 = 0, totalEx2 = 0;
    double maxP1 = 0, maxP2 = 0, maxEx1 = 0, maxP3 = 0, maxP4 = 0, maxEx2 = 0;
    int countP1 = 0, countP2 = 0, countEx1 = 0;
    int countP3 = 0, countP4 = 0, countEx2 = 0;
    int totalSubjects = courses.length;

    for (var c in courses) {
      if (c.p1Max > 0) { totalP1 += c.p1; maxP1 += c.p1Max.toDouble(); countP1++; }
      if (c.p2Max > 0) { totalP2 += c.p2; maxP2 += c.p2Max.toDouble(); countP2++; }
      if (c.ex1Max > 0) { totalEx1 += c.ex1; maxEx1 += c.ex1Max.toDouble(); countEx1++; }
      if (c.p3Max > 0) { totalP3 += c.p3; maxP3 += c.p3Max.toDouble(); countP3++; }
      if (c.p4Max > 0) { totalP4 += c.p4; maxP4 += c.p4Max.toDouble(); countP4++; }
      if (c.ex2Max > 0) { totalEx2 += c.ex2; maxEx2 += c.ex2Max.toDouble(); countEx2++; }
    }

    bool allPeriodsFilled = (countP1 == totalSubjects && countP2 == totalSubjects && countEx1 == totalSubjects &&
                             countP3 == totalSubjects && countP4 == totalSubjects && countEx2 == totalSubjects);

    final pourcentageP1 = maxP1 > 0 ? (totalP1 / maxP1) * 100 : 0.0;
    final pourcentageP2 = maxP2 > 0 ? (totalP2 / maxP2) * 100 : 0.0;
    final pourcentageEx1 = maxEx1 > 0 ? (totalEx1 / maxEx1) * 100 : 0.0;
    final pourcentageP3 = maxP3 > 0 ? (totalP3 / maxP3) * 100 : 0.0;
    final pourcentageP4 = maxP4 > 0 ? (totalP4 / maxP4) * 100 : 0.0;
    final pourcentageEx2 = maxEx2 > 0 ? (totalEx2 / maxEx2) * 100 : 0.0;

    final totalP1P2Ex1 = totalP1 + totalP2 + totalEx1;
    final maxP1P2Ex1 = maxP1 + maxP2 + maxEx1;
    final pourcentageSem1 = maxP1P2Ex1 > 0 ? (totalP1P2Ex1 / maxP1P2Ex1) * 100 : 0.0;

    final totalP3P4Ex2 = totalP3 + totalP4 + totalEx2;
    final maxP3P4Ex2 = maxP3 + maxP4 + maxEx2;
    final pourcentageSem2 = maxP3P4Ex2 > 0 ? (totalP3P4Ex2 / maxP3P4Ex2) * 100 : 0.0;

    double totalGeneral = 0, maximumGeneral = 0, pourcentageGeneral = 0;
    bool canCalculateTG = false;
    if (allPeriodsFilled) {
      totalGeneral = totalP1P2Ex1 + totalP3P4Ex2;
      maximumGeneral = maxP1P2Ex1 + maxP3P4Ex2;
      pourcentageGeneral = maximumGeneral > 0 ? (totalGeneral / maximumGeneral) * 100 : 0.0;
      canCalculateTG = true;
    }

    return _Statistics(
      totalGeneral: totalGeneral,
      maximumGeneral: maximumGeneral,
      pourcentage: pourcentageGeneral,
      decision: "NON CALCULABLE",
      canCalculateTG: canCalculateTG,
      totalP1: totalP1, maxP1: maxP1,
      totalP2: totalP2, maxP2: maxP2,
      totalEx1: totalEx1, maxEx1: maxEx1,
      totalP3: totalP3, maxP3: maxP3,
      totalP4: totalP4, maxP4: maxP4,
      totalEx2: totalEx2, maxEx2: maxEx2,
      pourcentageP1: pourcentageP1,
      pourcentageP2: pourcentageP2,
      pourcentageEx1: pourcentageEx1,
      pourcentageP3: pourcentageP3,
      pourcentageP4: pourcentageP4,
      pourcentageEx2: pourcentageEx2,
      pourcentageSem1: pourcentageSem1,
      pourcentageSem2: pourcentageSem2,
    );
  }
}

// ===== MODÈLES =====
class _CourseData {
  final String nom;
  final double p1, p2, ex1, p3, p4, ex2;
  final int p1Max, p2Max, ex1Max, p3Max, p4Max, ex2Max;
  _CourseData({
    required this.nom,
    required this.p1, required this.p2, required this.ex1,
    required this.p3, required this.p4, required this.ex2,
    required this.p1Max, required this.p2Max, required this.ex1Max,
    required this.p3Max, required this.p4Max, required this.ex2Max,
  });
  double get total1 => p1 + p2 + ex1;
  double get total2 => p3 + p4 + ex2;
  double get totalGeneral => total1 + total2;
  int get totalMax => p1Max + p2Max + ex1Max + p3Max + p4Max + ex2Max;
}

class _Statistics {
  final double totalGeneral, maximumGeneral, pourcentage;
  final String decision;
  final bool canCalculateTG;
  final double totalP1, maxP1, totalP2, maxP2, totalEx1, maxEx1;
  final double totalP3, maxP3, totalP4, maxP4, totalEx2, maxEx2;
  final double pourcentageP1, pourcentageP2, pourcentageEx1;
  final double pourcentageP3, pourcentageP4, pourcentageEx2;
  final double pourcentageSem1, pourcentageSem2;
  _Statistics({
    required this.totalGeneral, required this.maximumGeneral,
    required this.pourcentage, required this.decision,
    required this.canCalculateTG,
    required this.totalP1, required this.maxP1,
    required this.totalP2, required this.maxP2,
    required this.totalEx1, required this.maxEx1,
    required this.totalP3, required this.maxP3,
    required this.totalP4, required this.maxP4,
    required this.totalEx2, required this.maxEx2,
    required this.pourcentageP1, required this.pourcentageP2,
    required this.pourcentageEx1, required this.pourcentageP3,
    required this.pourcentageP4, required this.pourcentageEx2,
    required this.pourcentageSem1, required this.pourcentageSem2,
  });
}
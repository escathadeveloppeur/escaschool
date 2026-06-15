// lib/services/bulletin_pdf_generator.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class BulletinPdfGenerator {
  // ===============================================================
  // GÉNÉRATION DU BULLETIN POUR UN ÉLÈVE
  // ===============================================================

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
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║     GÉNÉRATION DU BULLETIN                                 ║');
    print('╚════════════════════════════════════════════════════════════╝');
    print('📌 Classe: $className');
    print('📌 Matières de la classe (${classSubjects.length}):');
    for (var s in classSubjects) {
      print('   - ${s['name']}: maxValues=${s['maxValues']}');
    }
    
    final pdf = pw.Document();
    
    final courses = _convertGradesToCourses(studentData, allGrades, classSubjects);
    final stats = _calculateStatistics(courses);
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(10),
        build: (context) {
          return [
            _buildBulletinContainer(
              studentData: studentData,
              className: className,
              courses: courses,
              stats: stats,
              schoolInfo: schoolInfo,
              totalStudents: totalStudents,
              teacherName: teacherName,
            ),
          ];
        },
      ),
    );
    
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    print('✅ PDF généré avec succès\n');
  }

  // ===============================================================
  // GÉNÉRATION DES BULLETINS POUR TOUTE UNE CLASSE
  // ===============================================================

  static Future<void> generateAllBulletins({
    required List<Map<String, dynamic>> studentReports,
    required String className,
    required String teacherName,
    required List<Map<String, dynamic>> allGrades,
    required List<Map<String, dynamic>> examResults,
    required List<Map<String, dynamic>> attendances,
    required Map<String, String> schoolInfo,
    required List<Map<String, dynamic>> classSubjects,
  }) async {
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║     GÉNÉRATION DES BULLETINS (CLASSE COMPLÈTE)            ║');
    print('╚════════════════════════════════════════════════════════════╝');
    print('📌 Classe: $className');
    print('📌 ${studentReports.length} élèves');
    print('📌 ${classSubjects.length} matières');
    
    final pdf = pw.Document();
    
    for (var report in studentReports) {
      final courses = _convertGradesToCourses(report, allGrades, classSubjects);
      final stats = _calculateStatistics(courses);
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(10),
          build: (context) {
            return [
              _buildBulletinContainer(
                studentData: report,
                className: className,
                courses: courses,
                stats: stats,
                schoolInfo: schoolInfo,
                totalStudents: studentReports.length,
                teacherName: teacherName,
              ),
            ];
          },
        ),
      );
    }
    
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    print('✅ ${studentReports.length} bulletins générés avec succès\n');
  }

  // ===============================================================
  // CONVERSION DES NOTES EN COURS AVEC CALCUL PROP
  // ===============================================================

  static List<_CourseData> _convertGradesToCourses(
    Map<String, dynamic> studentData,
    List<Map<String, dynamic>> allGrades,
    List<Map<String, dynamic>> classSubjects,
  ) {
    print('\n📊 CONVERSION DES NOTES EN COURS');
    print('   Étudiant: ${studentData['student']['fullName']}');
    
    final grades = studentData['grades'] as List<Map<String, dynamic>>;
    print('   Nombre de notes: ${grades.length}');
    
    final Map<String, List<Map<String, dynamic>>> gradesBySubject = {};
    
    for (var grade in grades) {
      final subject = grade['subject'] as String;
      if (!gradesBySubject.containsKey(subject)) {
        gradesBySubject[subject] = [];
      }
      gradesBySubject[subject]!.add(grade);
    }
    
    print('   Matières trouvées dans les notes: ${gradesBySubject.keys.join(", ")}');
    
    final List<_CourseData> courses = [];
    
    for (var entry in gradesBySubject.entries) {
      final subjectName = entry.key;
      final subjectGrades = entry.value;
      
      print('\n   📖 Traitement de la matière: "$subjectName"');
      print('      Nombre de notes: ${subjectGrades.length}');
      
      // Récupérer les maxValues depuis la matière de la classe
      final subjectInfo = classSubjects.firstWhere(
        (s) => s['name'] == subjectName,
        orElse: () {
          print('      ⚠️ Matière non trouvée dans classSubjects !');
          return {};
        },
      );
      
      print('      SubjectInfo trouvé: ${subjectInfo.isNotEmpty ? "OUI" : "NON"}');
      
      final maxValues = subjectInfo['maxValues'];
      print('      maxValues: $maxValues');
      
      // Valeurs par défaut (1ère catégorie)
      int p1Max = 10, p2Max = 10, ex1Max = 20;
      int p3Max = 10, p4Max = 10, ex2Max = 20;
      
      // Appliquer les maxima selon la catégorie de la matière
      if (maxValues != null) {
        p1Max = maxValues['p1'] ?? 10;
        p2Max = maxValues['p2'] ?? 10;
        ex1Max = maxValues['ex1'] ?? 20;
        p3Max = maxValues['p3'] ?? 10;
        p4Max = maxValues['p4'] ?? 10;
        ex2Max = maxValues['ex2'] ?? 20;
        print('      Maxima: P1=$p1Max, P2=$p2Max, EX1=$ex1Max, P3=$p3Max, P4=$p4Max, EX2=$ex2Max');
      } else {
        print('      ⚠️ Utilisation des valeurs par défaut');
      }
      
      // Séparer les notes par semestre (utiliser le champ semester)
 final sem1Grades = subjectGrades.where((g) {
  final date = g['date'] as DateTime;
  return date.month <= 6; // Janvier à Juin = Semestre 1
}).toList();

final sem2Grades = subjectGrades.where((g) {
  final date = g['date'] as DateTime;
  return date.month > 6; // Juillet à Décembre = Semestre 2
}).toList();
      print('      Semestre 1: ${sem1Grades.length} notes');
      print('      Semestre 2: ${sem2Grades.length} notes');
      
      // Calculer les moyennes sur le barème de la période (pas sur 20)
      final p1 = _calculatePeriodAverage(
        sem1Grades.where((g) => _isDevoir1(g['evaluationType'])).toList(), 
        p1Max
      );
      final p2 = _calculatePeriodAverage(
        sem1Grades.where((g) => _isDevoir2(g['evaluationType'])).toList(), 
        p2Max
      );
      final ex1 = _calculatePeriodAverage(
        sem1Grades.where((g) => _isExamen(g['evaluationType'])).toList(), 
        ex1Max
      );
      
      final p3 = _calculatePeriodAverage(
        sem2Grades.where((g) => _isDevoir1(g['evaluationType'])).toList(), 
        p3Max
      );
      final p4 = _calculatePeriodAverage(
        sem2Grades.where((g) => _isDevoir2(g['evaluationType'])).toList(), 
        p4Max
      );
      final ex2 = _calculatePeriodAverage(
        sem2Grades.where((g) => _isExamen(g['evaluationType'])).toList(), 
        ex2Max
      );
      
      print('      Moyennes calculées: P1=$p1/$p1Max, P2=$p2/$p2Max, EX1=$ex1/$ex1Max');
      print('                          P3=$p3/$p3Max, P4=$p4/$p4Max, EX2=$ex2/$ex2Max');
      
      courses.add(_CourseData(
        nom: subjectName,
        p1: p1,
        p2: p2,
        ex1: ex1,
        p3: p3,
        p4: p4,
        ex2: ex2,
        p1Max: p1Max,
        p2Max: p2Max,
        ex1Max: ex1Max,
        p3Max: p3Max,
        p4Max: p4Max,
        ex2Max: ex2Max,
      ));
    }
    
    print('\n   ✅ ${courses.length} cours convertis\n');
    return courses;
  }

  /// Vérifie si le type d'évaluation correspond à Devoir 1
  static bool _isDevoir1(String evaluationType) {
    final cleanType = evaluationType.replaceAll(' S2', '').trim();
    return cleanType == 'Devoir 1';
  }

  /// Vérifie si le type d'évaluation correspond à Devoir 2
  static bool _isDevoir2(String evaluationType) {
    final cleanType = evaluationType.replaceAll(' S2', '').trim();
    return cleanType == 'Devoir 2';
  }

  /// Vérifie si le type d'évaluation correspond à Examen
  static bool _isExamen(String evaluationType) {
    final cleanType = evaluationType.replaceAll(' S2', '').trim();
    return cleanType == 'Examen';
  }

  /// Calcule la moyenne sur l'échelle de la période (periodMax)
  /// Formule: (Note obtenue / Max individuel) × part proportionnelle du periodMax
  /// Résultat: total des points obtenus sur periodMax
  static double _calculatePeriodAverage(List<Map<String, dynamic>> grades, int periodMax) {
    if (grades.isEmpty) return 0;
    if (periodMax == 0) return 0;
    
    // 1. Calculer la somme pondérée des max individuels
    double totalWeightedMax = 0;
    for (var grade in grades) {
      totalWeightedMax += (grade['maxScore'] as double) * (grade['coefficient'] as double);
    }
    
    if (totalWeightedMax == 0) return 0;
    
    // 2. Facteur de conversion pour ramener au periodMax
    final conversionFactor = periodMax / totalWeightedMax;
    
    double totalObtained = 0;
    
    for (var grade in grades) {
      final score = grade['score'] as double;
      final maxScore = grade['maxScore'] as double;
      final coefficient = grade['coefficient'] as double;
      
      // 3. Part de cette évaluation dans le periodMax
      final partPeriodMax = maxScore * coefficient * conversionFactor;
      
      // 4. Points obtenus sur cette part
      final pointsObtained = (score / maxScore) * partPeriodMax;
      
      totalObtained += pointsObtained;
    }
    
    // Retourner le total obtenu (sur periodMax)
    return totalObtained;
  }

  // ===============================================================
  // CALCUL DES STATISTIQUES
  // ===============================================================

  static _Statistics _calculateStatistics(List<_CourseData> courses) {
    print('\n📊 STATISTIQUES');
    double totalGeneral = 0;
    double maximumGeneral = 0;
    
    for (var c in courses) {
      print('   ${c.nom}: total=${c.totalGeneral}/${c.totalMax}');
      totalGeneral += c.totalGeneral;
      maximumGeneral += c.totalMax;
    }
    
    final double pourcentage = maximumGeneral > 0 ? (totalGeneral / maximumGeneral) * 100 : 0;
    
    String decision;
    if (pourcentage >= 80) decision = "EXCELLENT";
    else if (pourcentage >= 70) decision = "TRES BIEN";
    else if (pourcentage >= 60) decision = "BIEN";
    else if (pourcentage >= 50) decision = "SATISFAISANT";
    else decision = "ECHEC";
    
    print('   Total général: $totalGeneral');
    print('   Maximum général: $maximumGeneral');
    print('   Pourcentage: ${pourcentage.toStringAsFixed(2)}%');
    print('   Décision: $decision\n');
    
    return _Statistics(
      totalGeneral: totalGeneral,
      maximumGeneral: maximumGeneral,
      pourcentage: pourcentage,
      decision: decision,
    );
  }

  // ===============================================================
  // CONSTRUCTION DU BULLETIN COMPLET
  // ===============================================================

  static pw.Widget _buildBulletinContainer({
    required Map<String, dynamic> studentData,
    required String className,
    required List<_CourseData> courses,
    required _Statistics stats,
    required Map<String, String> schoolInfo,
    required int totalStudents,
    required String teacherName,
  }) {
    final student = studentData['student'] as Map<String, dynamic>;
    
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(8),
        child: pw.Column(
          children: [
            _buildHeader(schoolInfo),
            pw.SizedBox(height: 10),
            _buildStudentInfoTable(student, className, studentData),
            pw.SizedBox(height: 10),
            _buildMainTable(courses),
            pw.SizedBox(height: 12),
            _buildStatistics(stats, totalStudents, studentData),
            pw.SizedBox(height: 15),
            _buildObservation(studentData),
            pw.SizedBox(height: 20),
            _buildSignatures(schoolInfo, teacherName),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // HEADER
  // ===============================================================

  static pw.Widget _buildHeader(Map<String, String> schoolInfo) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Container(
          width: 55,
          height: 35,
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          child: pw.Center(
            child: pw.Text(
              "RDC",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        pw.Column(
          children: [
            pw.Text(
              "REPUBLIQUE DEMOCRATIQUE DU CONGO",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            ),
            pw.Text(
              schoolInfo['province'] ?? "MINISTERE DE L'ENSEIGNEMENT",
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              "BULLETIN SCOLAIRE",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
          ],
        ),
        pw.Container(
          width: 55,
          height: 35,
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          child: pw.Center(
            child: pw.Text(
              schoolInfo['schoolCode']?.substring(0, 3) ?? "ECO",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ===============================================================
  // INFOS ÉLÈVE
  // ===============================================================

  static pw.Widget _buildStudentInfoTable(
    Map<String, dynamic> student,
    String className,
    Map<String, dynamic> studentData,
  ) {
    final annee = "${DateTime.now().year - 1} - ${DateTime.now().year}";
    
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(3),
      },
      children: [
        _infoRow("ELEVE", student['fullName'] ?? '_______________', "SEXE", student['sexe'] ?? 'M'),
        _infoRow("CLASSE", className, "MATRICULE", student['matricule'] ?? '_______________'),
        _infoRow("ECOLE", student['schoolName'] ?? 'INSTITUT BONDYI', "ANNEE", annee),
      ],
    );
  }

  static pw.TableRow _infoRow(String a, String b, String c, String d) {
    return pw.TableRow(
      children: [
        _infoCell(a),
        _infoCell(b),
        _infoCell(c),
        _infoCell(d),
      ],
    );
  }

  static pw.Widget _infoCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  // ===============================================================
  // TABLEAU PRINCIPAL DES NOTES (DYNAMIQUE SELON CATÉGORIES)
  // ===============================================================

  static pw.Widget _buildMainTable(List<_CourseData> courses) {
    print('\n📊 CONSTRUCTION DU TABLEAU');
    
    // Grouper les cours par catégorie (basé sur totalMax)
    final Map<int, List<_CourseData>> coursesByMax = {};
    for (var c in courses) {
      final maxTotal = c.totalMax;
      if (!coursesByMax.containsKey(maxTotal)) {
        coursesByMax[maxTotal] = [];
      }
      coursesByMax[maxTotal]!.add(c);
      print('   ${c.nom}: totalMax=$maxTotal');
    }
    
    // Trier les catégories par ordre croissant
    final sortedMaxTotals = coursesByMax.keys.toList()..sort();
    print('   Catégories trouvées: $sortedMaxTotals');
    
    final List<pw.TableRow> allRows = [];
    
    // En-tête principal
    allRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _headerCell("BRANCHES"),
          _headerCell("P1"),
          _headerCell("P2"),
          _headerCell("EX1"),
          _headerCell("TOT1"),
          _headerCell("P3"),
          _headerCell("P4"),
          _headerCell("EX2"),
          _headerCell("TOT2"),
          _headerCell("T.G"),
        ],
      ),
    );
    
    // Pour chaque catégorie, afficher les cours et leurs maxima
    for (var maxTotal in sortedMaxTotals) {
      final categoryCourses = coursesByMax[maxTotal]!;
      if (categoryCourses.isEmpty) continue;
      
      final sampleCourse = categoryCourses.first;
      print('   Catégorie MAX=$maxTotal: ${categoryCourses.length} cours');
      
      // Ligne des maxima de la catégorie
      allRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _headerCell("MAXIMA"),
            _textCell(sampleCourse.p1Max == 0 ? "//" : sampleCourse.p1Max.toString()),
            _textCell(sampleCourse.p2Max == 0 ? "//" : sampleCourse.p2Max.toString()),
            _textCell(sampleCourse.ex1Max == 0 ? "//" : sampleCourse.ex1Max.toString()),
            _textCell((sampleCourse.p1Max + sampleCourse.p2Max + sampleCourse.ex1Max).toString()),
            _textCell(sampleCourse.p3Max == 0 ? "//" : sampleCourse.p3Max.toString()),
            _textCell(sampleCourse.p4Max == 0 ? "//" : sampleCourse.p4Max.toString()),
            _textCell(sampleCourse.ex2Max == 0 ? "//" : sampleCourse.ex2Max.toString()),
            _textCell((sampleCourse.p3Max + sampleCourse.p4Max + sampleCourse.ex2Max).toString()),
            _textCell(sampleCourse.totalMax.toString()),
          ],
        ),
      );
      
      // Lignes des cours de cette catégorie
      for (var c in categoryCourses) {
        allRows.add(
          pw.TableRow(
            children: [
              _textCell(c.nom),
              _textCell(c.p1.toStringAsFixed(1)),
              _textCell(c.p2.toStringAsFixed(1)),
              _textCell(c.ex1.toStringAsFixed(1)),
              _textCell(c.total1.toStringAsFixed(1)),
              _textCell(c.p3.toStringAsFixed(1)),
              _textCell(c.p4.toStringAsFixed(1)),
              _textCell(c.ex2.toStringAsFixed(1)),
              _textCell(c.total2.toStringAsFixed(1)),
              _textCell(c.totalGeneral.toStringAsFixed(1)),
            ],
          ),
        );
      }
    }
    
    return pw.Table(
      border: pw.TableBorder.all(width: 0.6),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        for (int i = 1; i <= 9; i++) i: const pw.FlexColumnWidth(1),
      },
      children: allRows,
    );
  }

  static pw.Widget _textCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Center(
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
      ),
    );
  }

  static pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        ),
      ),
    );
  }

  // ===============================================================
  // STATISTIQUES
  // ===============================================================

  static pw.Widget _buildStatistics(_Statistics stats, int totalStudents, Map<String, dynamic> studentData) {
    final ranking = studentData['ranking'] as int? ?? 0;
    final absences = studentData['absences'] as int? ?? 0;
    
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _statBox("TOTAL GENERAL", stats.totalGeneral.toStringAsFixed(0)),
        _statBox("MAXIMUM GENERAL", stats.maximumGeneral.toStringAsFixed(0)),
        _statBox("POURCENTAGE", "${stats.pourcentage.toStringAsFixed(2)} %"),
        _statBox("PLACE", "$ranking/${totalStudents > 0 ? totalStudents : 1}"),
        _statBox("ABSENCES", absences.toString()),
        _statBox("DECISION", stats.decision),
      ],
    );
  }

  static pw.Widget _statBox(String title, String value) {
    return pw.Container(
      width: 90,
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // OBSERVATION
  // ===============================================================

  static pw.Widget _buildObservation(Map<String, dynamic> studentData) {
    final overallAverage = studentData['overallAverage'] as double? ?? 0;
    final appreciation = _getAppreciation(overallAverage);
    
    return pw.Container(
      width: double.infinity,
      height: 70,
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          "OBSERVATIONS :\n$appreciation",
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
    );
  }

  // ===============================================================
  // SIGNATURES
  // ===============================================================

  static pw.Widget _buildSignatures(Map<String, String> schoolInfo, String teacherName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _signature(teacherName),
        _signature(schoolInfo['signaturePrefet'] ?? "PREFET DES ETUDES"),
        _signature(schoolInfo['signatureChef'] ?? "CHEF D'ETABLISSEMENT"),
      ],
    );
  }

  static pw.Widget _signature(String title) {
    return pw.Column(
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 35),
        pw.Container(width: 100, height: 1, color: PdfColors.black),
      ],
    );
  }

  // ===============================================================
  // UTILITAIRES
  // ===============================================================

  static String _getAppreciation(double average) {
    if (average >= 16) {
      return "- Excellent travail !\n- Félicitations du conseil de classe\n- Encouragements";
    } else if (average >= 14) {
      return "- Très bon travail\n- Elève discipliné\n- Encouragements";
    } else if (average >= 12) {
      return "- Travail satisfaisant\n- Progrès à maintenir\n- Encouragements";
    } else if (average >= 10) {
      return "- Travail passable\n- Efforts supplémentaires nécessaires\n- À suivre";
    } else {
      return "- Résultats insuffisants\n- Travail de remédiation requis\n- Soutien parental nécessaire";
    }
  }
}

// ===============================================================
// MODÈLE DE COURS (AVEC MAXIMA PAR CATÉGORIE)
// ===============================================================

class _CourseData {
  final String nom;
  final double p1;
  final double p2;
  final double ex1;
  final double p3;
  final double p4;
  final double ex2;
  final int p1Max;
  final int p2Max;
  final int ex1Max;
  final int p3Max;
  final int p4Max;
  final int ex2Max;

  _CourseData({
    required this.nom,
    required this.p1,
    required this.p2,
    required this.ex1,
    required this.p3,
    required this.p4,
    required this.ex2,
    required this.p1Max,
    required this.p2Max,
    required this.ex1Max,
    required this.p3Max,
    required this.p4Max,
    required this.ex2Max,
  });

  double get total1 => p1 + p2 + ex1;
  double get total2 => p3 + p4 + ex2;
  double get totalGeneral => total1 + total2;
  int get totalMax => p1Max + p2Max + ex1Max + p3Max + p4Max + ex2Max;
}

// ===============================================================
// MODÈLE DE STATISTIQUES
// ===============================================================

class _Statistics {
  final double totalGeneral;
  final double maximumGeneral;
  final double pourcentage;
  final String decision;

  _Statistics({
    required this.totalGeneral,
    required this.maximumGeneral,
    required this.pourcentage,
    required this.decision,
  });
}
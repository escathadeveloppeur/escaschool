// lib/services/detailed_grades_report_generator.dart

import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

class DetailedGradesReportGenerator {
  
  /// Générer le rapport détaillé des notes
  static Future<void> generateReport({
    required List<Map<String, dynamic>> classFilteredGrades,
    required List<Map<String, dynamic>> classExams,
    required List<Map<String, dynamic>> examResults,
    required List<Map<String, dynamic>> classAttendances,
    required Map<String, List<Map<String, dynamic>>> studentGradesMap,
    required Map<String, List<Map<String, dynamic>>> studentExamsMap,
    required Map<String, List<Map<String, dynamic>>> studentAttendancesMap,
    required List<String> allStudentNames,
    required String selectedClass,
    required String selectedSubject,
    required String dateRange,
    required String teacherName,
    required List<Map<String, dynamic>> onlineExams,
    required Map<String, dynamic> Function(List<Map<String, dynamic>>) calculateAverage,
    required pw.Widget Function(String) pdfHeaderCell,
    required pw.Widget Function(String, {pw.TextStyle? textStyle}) pdfCell,
    required pw.Widget Function(String label, String value) pdfStatRow,
    required pw.Widget Function(String label, String value, PdfColor color) buildStatCard,
    required pw.Widget Function(List<String>, Map<String, List<Map<String, dynamic>>>, Map<String, List<Map<String, dynamic>>>, Map<String, List<Map<String, dynamic>>>) buildCompleteSummaryTable,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(15),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, text: 'RAPPORT COMPLET DES PERFORMANCES',
              textStyle: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            
            // En-tête
            pw.Container(
              padding: pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Classe: $selectedClass',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  if (selectedSubject.isNotEmpty) 
                    pw.Text('Matiere: $selectedSubject',
                      style: pw.TextStyle(fontSize: 14)),
                  pw.Text('Periode: $dateRange',
                    style: pw.TextStyle(fontSize: 14)),
                  pw.Text('Professeur: $teacherName',
                    style: pw.TextStyle(fontSize: 14)),
                  pw.Text("Date d'edition: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}",
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Cartes statistiques
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                buildStatCard('Notes', '${classFilteredGrades.length}', PdfColors.blue),
                buildStatCard('Examens', '${classExams.length}', PdfColors.purple),
                buildStatCard('Presences', '${classAttendances.length}', PdfColors.green),
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            // SECTION 1: NOTES DES EVALUATIONS
            pw.Text('1. NOTES DES EVALUATIONS',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            
            ...allStudentNames.map((studentName) {
              final notes = studentGradesMap[studentName] ?? [];
              if (notes.isEmpty) return pw.SizedBox();
              
              // Grouper les notes par période (P1, P2, EX1, P3, P4, EX2)
              final notesByPeriod = _groupNotesByPeriod(notes);
              
              final result = calculateAverage(notes);
              final totalObtained = result['totalObtained'] ?? 0;
              final totalMaxPoints = result['totalMaxPoints'] ?? 0;
              final percentage = totalMaxPoints > 0 ? (totalObtained / totalMaxPoints) * 100 : 0;
              final avgColor = percentage >= 50 ? PdfColors.green : PdfColors.red;
              
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 15),
                  pw.Container(
                    padding: pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey300,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Text(studentName,
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Text('Total: ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('${totalObtained.toStringAsFixed(1)}/${totalMaxPoints.toStringAsFixed(0)}',
                          style: pw.TextStyle(color: avgColor, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(width: 20),
                        pw.Text('(${percentage.toStringAsFixed(1)}%)',
                          style: pw.TextStyle(color: avgColor)),
                        pw.SizedBox(width: 20),
                        pw.Text('Nb notes: ${notes.length}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text('Detail des evaluations par periode',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  
                  // Affichage par période
                  ...notesByPeriod.entries.map((periodEntry) {
                    final period = periodEntry.key;
                    final periodNotes = periodEntry.value;
                    
                    // Récupérer le periodMax (barème officiel de la période)
                    final periodMax = periodNotes.first['periodMax'] as int;
                    
                    // Calculer les totaux de la période avec répartition proportionnelle
                    final periodResult = _calculatePeriodTotal(periodNotes, periodMax);
                    final periodTotalObtained = periodResult['totalObtained'];
                    
                    // Convertir le total sur 20 pour l'affichage
                    final periodTotalOn20 = (periodTotalObtained / periodMax) * 20;
                    final periodPercentage = periodMax > 0 ? (periodTotalObtained / periodMax) * 100 : 0;
                    final periodColor = periodPercentage >= 50 ? PdfColors.green : PdfColors.red;
                    
                    return pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(height: 8),
                        pw.Container(
                          padding: pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey200,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Row(
                            children: [
                              pw.Text('Periode $period (max: $periodMax)',
                                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                              pw.Spacer(),
                              pw.Text('Total: ${periodTotalObtained.toStringAsFixed(1)}/$periodMax → ${periodTotalOn20.toStringAsFixed(1)}/20',
                                style: pw.TextStyle(fontSize: 10, color: periodColor, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(width: 8),
                              pw.Text('(${periodPercentage.toStringAsFixed(1)}%)',
                                style: pw.TextStyle(fontSize: 10, color: periodColor)),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Table(
                          border: pw.TableBorder.all(),
                          columnWidths: {
                            0: pw.FixedColumnWidth(25),
                            1: pw.FixedColumnWidth(55),
                            2: pw.FixedColumnWidth(45),
                            3: pw.FixedColumnWidth(35),
                            4: pw.FixedColumnWidth(55),
                            5: pw.FixedColumnWidth(50),
                          },
                          children: [
                            pw.TableRow(
                              decoration: pw.BoxDecoration(color: PdfColors.grey100),
                              children: [
                                pdfHeaderCell('N°'),
                                pdfHeaderCell('Type'),
                                pdfHeaderCell('Note'),
                                pdfHeaderCell('Coef'),
                                pdfHeaderCell('Date'),
                                pdfHeaderCell('Normalisee'),
                              ],
                            ),
                            ...periodNotes.asMap().entries.map((entry) {
                              final index = entry.key;
                              final grade = periodNotes[index];
                              final score = grade['score'] as double;
                              final maxScore = grade['maxScore'] as double;
                              final coefficient = grade['coefficient'] as double;
                              final date = grade['date'] as DateTime;
                              final evaluationType = grade['evaluationType'] ?? 'Devoir';
                              final semester = grade['semester'] ?? 'S1';
                              
                              // Calcul de la note normalisée proportionnelle
                              final normalizedNote = _calculateProportionalNote(
                                score, maxScore, periodMax.toDouble(), coefficient, periodNotes
                              );
                              // Convertir sur 20 pour l'affichage
                              final normalizedOn20 = (normalizedNote / periodMax) * 20;
                              final scoreOver20 = (score / maxScore) * 20;
                              final color = scoreOver20 >= 10 ? PdfColors.green : PdfColors.red;
                              
                              // Afficher le type avec le semestre
                              String displayType = evaluationType;
                              if (semester == 'S2' && evaluationType != 'Examen') {
                                displayType = '$evaluationType (S2)';
                              }
                              if (semester == 'S2' && evaluationType == 'Examen') {
                                displayType = 'Examen S2';
                              }
                              
                              return pw.TableRow(
                                children: [
                                  pdfCell((index + 1).toString()),
                                  pdfCell(displayType),
                                  pdfCell('${score.toStringAsFixed(1)}/${maxScore.toStringAsFixed(0)}'),
                                  pdfCell(coefficient.toString()),
                                  pdfCell(DateFormat('dd/MM/yy').format(date)),
                                  pdfCell('${normalizedOn20.toStringAsFixed(1)}',
                                    textStyle: pw.TextStyle(color: color, fontWeight: pw.FontWeight.bold)),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ],
                    );
                  }).toList(),
                  
                  pw.SizedBox(height: 6),
                  pw.Text('Legende: P1/P2 = Devoirs 1er semestre | EX1 = Examen 1er semestre (EX1 = P1 + P2) | P3/P4 = Devoirs 2eme semestre | EX2 = Examen 2eme semestre (EX2 = P3 + P4)',
                    style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
                  pw.Text('Les notes sont normalisees sur 20. La somme des notes d\'une periode = Barème periode.',
                    style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500, fontStyle: pw.FontStyle.italic)),
                ],
              );
            }).toList(),
            
            // SECTION 2: EXAMENS EN LIGNE
            if (classExams.isNotEmpty) ...[
              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.SizedBox(height: 20),
              pw.Text('2. EXAMENS EN LIGNE',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FixedColumnWidth(60),
                  3: pw.FixedColumnWidth(80),
                  4: pw.FixedColumnWidth(80),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pdfHeaderCell('Examen'),
                      pdfHeaderCell('Matiere'),
                      pdfHeaderCell('Points'),
                      pdfHeaderCell('Participants'),
                      pdfHeaderCell('Moyenne'),
                    ],
                  ),
                  ...classExams.map((exam) {
                    final examResultsList = examResults.where((r) => r['examId'] == exam['id']).toList();
                    final avgScore = examResultsList.isNotEmpty
                        ? examResultsList.fold<double>(0, (s, r) => s + (r['score'] as double)) / examResultsList.length
                        : 0.0;
                    return pw.TableRow(children: [
                      pdfCell(exam['title']),
                      pdfCell(exam['subject']),
                      pdfCell(exam['totalPoints'].toString()),
                      pdfCell(examResultsList.length.toString()),
                      pdfCell('${(avgScore / (exam['totalPoints'] as int) * 20).toStringAsFixed(1)}'),
                    ]);
                  }).toList(),
                ],
              ),
            ],
            
            // SECTION 3: RAPPORT DE PRÉSENCES
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 20),
            pw.Text('3. RAPPORT DE PRESENCES',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FixedColumnWidth(70),
                2: pw.FixedColumnWidth(70),
                3: pw.FixedColumnWidth(80),
                4: pw.FixedColumnWidth(70),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pdfHeaderCell('Eleve'),
                    pdfHeaderCell('Presents'),
                    pdfHeaderCell('Absents'),
                    pdfHeaderCell('Retards'),
                    pdfHeaderCell('Taux'),
                  ],
                ),
                ...allStudentNames.map((studentName) {
                  final attendancesForStudent = classAttendances.where((a) => a['studentName'] == studentName).toList();
                  final presents = attendancesForStudent.where((a) => a['status'] == 'present').length;
                  final absents = attendancesForStudent.where((a) => a['status'] == 'absent').length;
                  final lates = attendancesForStudent.where((a) => a['status'] == 'late').length;
                  final total = attendancesForStudent.length;
                  final rate = total > 0 ? (presents / total * 100) : 0;
                  
                  return pw.TableRow(children: [
                    pdfCell(studentName),
                    pdfCell(presents.toString(),
                      textStyle: pw.TextStyle(color: PdfColors.green)),
                    pdfCell(absents.toString(),
                      textStyle: pw.TextStyle(color: PdfColors.red)),
                    pdfCell(lates.toString(),
                      textStyle: pw.TextStyle(color: PdfColors.orange)),
                    pdfCell('${rate.toStringAsFixed(1)}%',
                      textStyle: pw.TextStyle(color: rate >= 75 ? PdfColors.green : PdfColors.red, fontWeight: pw.FontWeight.bold)),
                  ]);
                }).toList(),
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            // SECTION 4: RÉSUMÉ GÉNÉRAL
            pw.Text('4. RESUME GENERAL',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            
            buildCompleteSummaryTable(
              allStudentNames, 
              studentGradesMap, 
              studentExamsMap, 
              studentAttendancesMap
            ),
            
            pw.SizedBox(height: 30),
            
            // Pied de page
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Rapport genere par Smart School',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
              ),
            ),
          ];
        },
      ),
    );
    
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
  
  /// Grouper les notes par période (P1, P2, EX1, P3, P4, EX2)
  static Map<String, List<Map<String, dynamic>>> _groupNotesByPeriod(List<Map<String, dynamic>> notes) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    
    for (var note in notes) {
      // Utiliser periodLabel déjà calculé ou le recalculer
      String period;
      if (note['periodLabel'] != null) {
        period = note['periodLabel'] as String;
      } else {
        period = _getPeriodLabel(note['evaluationType'], note['date'], note['semester']);
      }
      
      if (!grouped.containsKey(period)) {
        grouped[period] = [];
      }
      grouped[period]!.add(note);
    }
    
    return grouped;
  }
  
  /// Calculer le total d'une période avec répartition proportionnelle
  /// La somme des notes normalisées de la période = periodMax
  static Map<String, dynamic> _calculatePeriodTotal(List<Map<String, dynamic>> periodNotes, int periodMax) {
    if (periodNotes.isEmpty) {
      return {'totalObtained': 0.0, 'totalMax': periodMax.toDouble()};
    }
    
    // Calculer la somme pondérée des max individuels de la période
    double totalWeightedMax = 0;
    for (var note in periodNotes) {
      totalWeightedMax += (note['maxScore'] as double) * (note['coefficient'] as double);
    }
    
    if (totalWeightedMax == 0) {
      return {'totalObtained': 0.0, 'totalMax': periodMax.toDouble()};
    }
    
    double totalObtained = 0;
    
    for (var note in periodNotes) {
      final score = note['score'] as double;
      final maxScore = note['maxScore'] as double;
      final coefficient = note['coefficient'] as double;
      
      // Part de cette évaluation dans le periodMax (proportionnelle)
      // Formule: (maxScore × coefficient) / somme( maxScore × coefficient ) × periodMax
      final partPeriodMax = (maxScore * coefficient) / totalWeightedMax * periodMax;
      
      // Points obtenus sur cette part
      // Formule: (score / maxScore) × partPeriodMax
      final pointsObtained = (score / maxScore) * partPeriodMax;
      
      totalObtained += pointsObtained;
    }
    
    return {
      'totalObtained': totalObtained,
      'totalMax': periodMax.toDouble(),
    };
  }
  
  /// Calculer la note normalisée proportionnelle pour une évaluation
  /// Retourne le nombre de points sur le periodMax
  static double _calculateProportionalNote(
    double score,
    double maxScore,
    double periodMax,
    double coefficient,
    List<Map<String, dynamic>> periodNotes,
  ) {
    if (periodNotes.isEmpty) return 0;
    
    // Calculer la somme pondérée des max individuels de la période
    double totalWeightedMax = 0;
    for (var note in periodNotes) {
      totalWeightedMax += (note['maxScore'] as double) * (note['coefficient'] as double);
    }
    
    if (totalWeightedMax == 0) return 0;
    
    // Part de cette évaluation dans le periodMax
    final partPeriodMax = (maxScore * coefficient) / totalWeightedMax * periodMax;
    
    // Points obtenus sur cette part
    final pointsObtained = (score / maxScore) * partPeriodMax;
    
    return pointsObtained;
  }
  
  /// Obtenir le libellé de la période en fonction du type d'évaluation et du semestre
  /// 
  /// Mapping des évaluations vers les périodes:
  /// - Semestre 1:
  ///   - Devoir 1 → P1
  ///   - Devoir 2 → P2
  ///   - Interrogation → Interrogation (dans P1 ou P2 selon la date)
  ///   - Examen → EX1
  /// - Semestre 2:
  ///   - Devoir 1 → P3
  ///   - Devoir 2 → P4
  ///   - Interrogation → Interrogation (dans P3 ou P4 selon la date)
  ///   - Examen → EX2
  static String _getPeriodLabel(String evaluationType, DateTime date, String? semester) {
    // Déterminer le semestre si non fourni
    String actualSemester = semester ?? (date.month <= 6 ? 'S1' : 'S2');
    
    // Nettoyer le type d'évaluation (enlever les suffixes S2)
    String cleanType = evaluationType.replaceAll(' S2', '').trim();
    
    switch (cleanType) {
      case 'Devoir 1':
        return actualSemester == 'S1' ? 'P1' : 'P3';
      case 'Devoir 2':
        return actualSemester == 'S1' ? 'P2' : 'P4';
      case 'Examen':
        return actualSemester == 'S1' ? 'EX1' : 'EX2';
      case 'Interrogation':
        // L'interrogation peut être dans n'importe quelle période
        // On utilise le mois pour déterminer
        if (actualSemester == 'S1') {
          return date.day <= 15 ? 'P1' : 'P2';
        } else {
          return date.day <= 15 ? 'P3' : 'P4';
        }
      default:
        return evaluationType;
    }
  }
}
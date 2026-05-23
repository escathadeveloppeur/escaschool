// lib/screens/teacher/teacher_reports_screen.dart
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class TeacherReportsScreen extends StatefulWidget {
  final String teacherName;
  final List<String> assignedClasses;
  final List<String> assignedSubjects;
  
  const TeacherReportsScreen({
    super.key,
    required this.teacherName,
    required this.assignedClasses,
    required this.assignedSubjects,
  });

  @override
  _TeacherReportsScreenState createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends State<TeacherReportsScreen> with SingleTickerProviderStateMixin {
  String selectedClass = '';
  String selectedSubject = '';
  String reportType = 'bulletin';
  DateTimeRange? dateRange;
  
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> grades = [];
  List<Map<String, dynamic>> examResults = [];
  List<Map<String, dynamic>> onlineExams = [];
  
  Map<String, List<Map<String, dynamic>>> studentGrades = {};
  Map<String, List<Map<String, dynamic>>> studentExamResults = {};
  Map<String, Map<String, dynamic>> studentReports = {};
  
  bool _isLoading = true;
  bool _isGenerating = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    if (widget.assignedClasses.isNotEmpty) {
      selectedClass = widget.assignedClasses.first;
    }
    if (widget.assignedSubjects.isNotEmpty) {
      selectedSubject = widget.assignedSubjects.first;
    }
    
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    dateRange = DateTimeRange(start: firstDay, end: lastDay);
    
    _loadAllData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║     CHARGEMENT DES DONNÉES - RAPPORTS                      ║');
    print('╚════════════════════════════════════════════════════════════╝\n');
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      // 1. Charger les étudiants
      print('🔍 [1/4] Chargement des étudiants...');
      Query studentQuery = FirebaseFirestore.instance.collection('students');
      if (schoolId != null && !auth.isSuperAdmin) {
        studentQuery = studentQuery.where('schoolId', isEqualTo: schoolId);
      }
      final studentsSnapshot = await studentQuery.get();
      
      students = [];
      for (var doc in studentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final className = data['className'] ?? '';
        if (widget.assignedClasses.contains(className)) {
          students.add({
            'firestoreId': doc.id,
            'fullName': data['fullName'] ?? 'Sans nom',
            'className': className,
            'birthDate': data['birthDate'] ?? '',
            'parentPhone': data['parentPhone'] ?? '',
          });
        }
      }
      print('   📊 ${students.length} étudiant(s) trouvé(s)');
      
      // 2. Charger les notes des devoirs
      print('🔍 [2/4] Chargement des notes des devoirs...');
      final gradesSnapshot = await FirebaseFirestore.instance
          .collection('grades')
          .get();
      
      grades = [];
      for (var doc in gradesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final className = data['className'] ?? '';
        if (widget.assignedClasses.contains(className)) {
          grades.add({
            'id': doc.id,
            'studentName': data['studentName'] ?? '',
            'subject': data['subject'] ?? '',
            'className': className,
            'score': (data['score'] as num?)?.toDouble() ?? 0.0,
            'maxScore': (data['maxScore'] as num?)?.toDouble() ?? 20.0,
            'coefficient': (data['coefficient'] as num?)?.toDouble() ?? 1.0,
            'evaluationType': data['evaluationType'] ?? 'Devoir',
            'date': data['date'] != null ? (data['date'] as Timestamp).toDate() : DateTime.now(),
          });
        }
      }
      print('   📊 ${grades.length} note(s) de devoirs trouvée(s)');
      
      // 3. Charger les examens en ligne
      print('🔍 [3/4] Chargement des examens en ligne...');
      final examsSnapshot = await FirebaseFirestore.instance
          .collection('online_exams')
          .get();
      
      onlineExams = [];
      for (var doc in examsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final className = data['className'] ?? '';
        if (widget.assignedClasses.contains(className)) {
          onlineExams.add({
            'id': doc.id,
            'title': data['title'] ?? '',
            'subject': data['subject'] ?? '',
            'className': className,
            'totalPoints': data['totalPoints'] ?? 0,
          });
        }
      }
      print('   📊 ${onlineExams.length} examen(s) en ligne trouvé(s)');
      
      // 4. Charger les résultats des examens
      print('🔍 [4/4] Chargement des résultats des examens...');
      final resultsSnapshot = await FirebaseFirestore.instance
          .collection('exam_results')
          .get();
      
      examResults = [];
      for (var doc in resultsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        examResults.add({
          'id': doc.id,
          'examId': data['examId'] ?? '',
          'studentName': data['studentName'] ?? '',
          'score': (data['score'] as num?)?.toDouble() ?? 0.0,
          'totalPoints': (data['totalPoints'] as num?)?.toDouble() ?? 0.0,
          'submittedAt': data['submittedAt'] != null ? (data['submittedAt'] as Timestamp).toDate() : null,
        });
      }
      print('   📊 ${examResults.length} résultat(s) d\'examens trouvé(s)');
      
      // Organiser les données
      _organizeData();
      
      print('\n✅ Chargement terminé\n');
      _animationController.forward();
      
    } catch (e) {
      print('❌ Erreur: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _organizeData() {
    // Organiser les notes par étudiant
    studentGrades.clear();
    for (var grade in grades) {
      final studentName = grade['studentName'] as String;
      if (!studentGrades.containsKey(studentName)) {
        studentGrades[studentName] = [];
      }
      studentGrades[studentName]!.add(grade);
    }
    
    // Organiser les résultats d'examens par étudiant
    studentExamResults.clear();
    for (var result in examResults) {
      final studentName = result['studentName'] as String;
      if (!studentExamResults.containsKey(studentName)) {
        studentExamResults[studentName] = [];
      }
      studentExamResults[studentName]!.add(result);
    }
    
    // Filtrer les étudiants par classe
    final filteredStudents = students.where((s) => 
      selectedClass.isEmpty || s['className'] == selectedClass).toList();
    
    // Calculer les rapports
    studentReports.clear();
    for (var student in filteredStudents) {
      final studentName = student['fullName'] as String;
      final classGrades = studentGrades[studentName] ?? [];
      final classExamResults = studentExamResults[studentName] ?? [];
      
      // Filtrer par matière
      final filteredGrades = selectedSubject.isEmpty
          ? classGrades
          : classGrades.where((g) => g['subject'] == selectedSubject).toList();
      
      // Calculer la moyenne des devoirs
      double totalWeighted = 0;
      double totalCoefficient = 0;
      for (var grade in filteredGrades) {
        final score = grade['score'] as double;
        final maxScore = grade['maxScore'] as double;
        final coefficient = grade['coefficient'] as double;
        totalWeighted += (score / maxScore * 20) * coefficient;
        totalCoefficient += coefficient;
      }
      final classAverage = totalCoefficient > 0 ? totalWeighted / totalCoefficient : 0.0;
      
      // Calculer la moyenne des examens
      double examTotal = 0;
      for (var result in classExamResults) {
        final score = result['score'] as double;
        final totalPoints = result['totalPoints'] as double;
        if (totalPoints > 0) {
          examTotal += (score / totalPoints) * 20;
        }
      }
      final examAverage = classExamResults.isNotEmpty ? examTotal / classExamResults.length : 0.0;
      
      // Moyenne générale (70% devoirs, 30% examens)
      final overallAverage = (classAverage * 0.7) + (examAverage * 0.3);
      
      // Compter les absences
      final absences = 0; // À implémenter avec la collection attendances
      
      studentReports[studentName] = {
        'student': student,
        'classAverage': classAverage,
        'examAverage': examAverage,
        'overallAverage': overallAverage,
        'absences': absences,
        'gradesCount': filteredGrades.length,
        'examsCount': classExamResults.length,
        'ranking': 0,
      };
    }
    
    // Calculer le classement
    final sortedReports = studentReports.entries.toList()
      ..sort((a, b) => (b.value['overallAverage'] as double).compareTo(a.value['overallAverage'] as double));
    
    for (int i = 0; i < sortedReports.length; i++) {
      studentReports[sortedReports[i].key]!['ranking'] = i + 1;
    }
  }

  Future<void> _generateReport() async {
    if (selectedClass.isEmpty) {
      _showSnackBar('Veuillez sélectionner une classe', Colors.orange);
      return;
    }
    
    setState(() => _isGenerating = true);
    
    try {
      if (reportType == 'bulletin') {
        await _generateClassBulletinPDF();
      } else if (reportType == 'grades') {
        await _generateGradesReportPDF();
      } else if (reportType == 'exam') {
        await _generateExamReportPDF();
      } else if (reportType == 'attendance') {
        await _generateAttendanceReportPDF();
      }
    } catch (e) {
      _showSnackBar('Erreur: $e', Colors.red);
    } finally {
      setState(() => _isGenerating = false);
    }
  }
  
  Future<void> _generateClassBulletinPDF() async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, text: 'BULLETIN DE CLASSE',
              textStyle: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Classe: $selectedClass',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            if (selectedSubject.isNotEmpty) 
              pw.Text('Matière: $selectedSubject'),
            pw.Text('Période: ${_formatDateRange()}'),
            pw.Text('Professeur: ${widget.teacherName}'),
            pw.Text('Date d\'édition: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
            pw.Divider(),
            pw.SizedBox(height: 20),
            
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: pw.FixedColumnWidth(40),
                1: pw.FlexColumnWidth(3),
                2: pw.FixedColumnWidth(70),
                3: pw.FixedColumnWidth(70),
                4: pw.FixedColumnWidth(70),
                5: pw.FixedColumnWidth(60),
                6: pw.FixedColumnWidth(80),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _pdfHeaderCell('Rg'),
                    _pdfHeaderCell('Élève'),
                    _pdfHeaderCell('Devoirs'),
                    _pdfHeaderCell('Examens'),
                    _pdfHeaderCell('Moyenne'),
                    _pdfHeaderCell('Abs'),
                    _pdfHeaderCell('Appréciation'),
                  ],
                ),
                ...studentReports.entries.map((entry) {
                  final data = entry.value;
                  final avgColor = (data['overallAverage'] as double) >= 10 
                      ? PdfColors.green 
                      : PdfColors.red;
                  return pw.TableRow(
                    children: [
                      _pdfCell((data['ranking'] as int).toString()),
                      _pdfCell(entry.key),
                      _pdfCell((data['classAverage'] as double).toStringAsFixed(2)),
                      _pdfCell((data['examAverage'] as double).toStringAsFixed(2)),
                      _pdfCell((data['overallAverage'] as double).toStringAsFixed(2),
                        textStyle: pw.TextStyle(color: avgColor, fontWeight: pw.FontWeight.bold)),
                      _pdfCell((data['absences'] as int).toString()),
                      _pdfCell(_getAppreciation(data['overallAverage'] as double)),
                    ],
                  );
                }).toList(),
              ],
            ),
            
            pw.SizedBox(height: 30),
            pw.Text('STATISTIQUES DE LA CLASSE',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 10),
            _pdfStatRow('Effectif total:', '${studentReports.length} élèves'),
            _pdfStatRow('Moyenne des devoirs:', '${_calculateClassAverage("classAverage").toStringAsFixed(2)}/20'),
            _pdfStatRow('Moyenne des examens:', '${_calculateClassAverage("examAverage").toStringAsFixed(2)}/20'),
            _pdfStatRow('Moyenne générale:', '${_calculateClassAverage("overallAverage").toStringAsFixed(2)}/20'),
            _pdfStatRow('Meilleure moyenne:', '${_getBestAverage().toStringAsFixed(2)}/20'),
            _pdfStatRow('Taux de réussite:', '${_calculateSuccessRate().toStringAsFixed(1)}%'),
          ];
        },
      ),
    );
    
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
  
  Future<void> _generateGradesReportPDF() async {
    final pdf = pw.Document();
    final gradeDistribution = _getGradeDistribution();
    final totalDays = 20;
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, text: 'RAPPORT DES NOTES',
              textStyle: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Classe: $selectedClass'),
            if (selectedSubject.isNotEmpty) pw.Text('Matière: $selectedSubject'),
            pw.Text('Période: ${_formatDateRange()}'),
            pw.Text('Professeur: ${widget.teacherName}'),
            pw.Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
            pw.SizedBox(height: 20),
            
            pw.Text('DISTRIBUTION DES NOTES',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 10),
            
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildGradeBar('0-5', gradeDistribution['0-5'] ?? 0, PdfColors.red),
                _buildGradeBar('6-10', gradeDistribution['6-10'] ?? 0, PdfColors.orange),
                _buildGradeBar('11-15', gradeDistribution['11-15'] ?? 0, PdfColors.yellow),
                _buildGradeBar('16-20', gradeDistribution['16-20'] ?? 0, PdfColors.green),
              ],
            ),
            
            pw.SizedBox(height: 30),
            pw.Text('CLASSEMENT DES ÉLÈVES',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 10),
            
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: pw.FixedColumnWidth(40),
                1: pw.FlexColumnWidth(4),
                2: pw.FixedColumnWidth(80),
                3: pw.FixedColumnWidth(80),
                4: pw.FixedColumnWidth(80),
                5: pw.FixedColumnWidth(60),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _pdfHeaderCell('Rg'),
                    _pdfHeaderCell('Élève'),
                    _pdfHeaderCell('Devoirs'),
                    _pdfHeaderCell('Examens'),
                    _pdfHeaderCell('Moyenne'),
                    _pdfHeaderCell('Nb notes'),
                  ],
                ),
                ...studentReports.entries.map((entry) {
                  final data = entry.value;
                  return pw.TableRow(
                    children: [
                      _pdfCell((data['ranking'] as int).toString()),
                      _pdfCell(entry.key),
                      _pdfCell((data['classAverage'] as double).toStringAsFixed(2)),
                      _pdfCell((data['examAverage'] as double).toStringAsFixed(2)),
                      _pdfCell((data['overallAverage'] as double).toStringAsFixed(2)),
                      _pdfCell('${data['gradesCount']}/${data['examsCount']}'),
                    ],
                  );
                }).toList(),
              ],
            ),
            
            pw.SizedBox(height: 20),
            pw.Text('Résumé des présences (période)',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _pdfStatRow('Taux de présence moyen:', '${_calculateAverageAttendanceRate(totalDays).toStringAsFixed(1)}%'),
            _pdfStatRow('Total absences:', '${_getTotalAbsences()}'),
          ];
        },
      ),
    );
    
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
  
  Future<void> _generateExamReportPDF() async {
    final classExams = onlineExams.where((e) => e['className'] == selectedClass).toList();
    
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        
        margin: pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, text: 'RAPPORT DES EXAMENS EN LIGNE',
              textStyle: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Classe: $selectedClass'),
            pw.Text('Professeur: ${widget.teacherName}'),
            pw.Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
            pw.SizedBox(height: 20),
            
            pw.Text('LISTE DES EXAMENS',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
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
                    _pdfHeaderCell('Examen'),
                    _pdfHeaderCell('Matière'),
                    _pdfHeaderCell('Points'),
                    _pdfHeaderCell('Participants'),
                    _pdfHeaderCell('Moyenne'),
                  ],
                ),
                ...classExams.map((exam) {
                  final examResultsList = examResults.where((r) => r['examId'] == exam['id']).toList();
                  final avgScore = examResultsList.isNotEmpty
                      ? examResultsList.fold<double>(0, (s, r) => s + (r['score'] as double)) / examResultsList.length
                      : 0.0;
                  return pw.TableRow(children: [
                    _pdfCell(exam['title']),
                    _pdfCell(exam['subject']),
                    _pdfCell(exam['totalPoints'].toString()),
                    _pdfCell(examResultsList.length.toString()),
                    _pdfCell('${(avgScore / exam['totalPoints'] * 20).toStringAsFixed(1)}/20'),
                  ]);
                }).toList(),
              ],
            ),
            
            pw.SizedBox(height: 30),
            pw.Text('RÉSULTATS PAR ÉLÈVE',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 10),
            
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                  for (int i = 0; i < classExams.length; i++) (i + 1): pw.FixedColumnWidth(80),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _pdfHeaderCell('Élève'),
                    ...classExams.map((e) => _pdfHeaderCell(
                      e['title'].length > 12 ? '${e['title'].substring(0, 10)}...' : e['title'])),
                  ],
                ),
                ...studentReports.keys.map((studentName) {
                  final studentResults = examResults.where((r) => r['studentName'] == studentName).toList();
                  return pw.TableRow(children: [
                    _pdfCell(studentName),
                    ...classExams.map((exam) {
                      final result = studentResults.firstWhere(
                        (r) => r['examId'] == exam['id'],
                        orElse: () => {'score': 0.0, 'totalPoints': exam['totalPoints']},
                      );
                      final score = result['score'] as double;
                      final total = (result['totalPoints'] ?? exam['totalPoints']).toDouble();
                      final grade = total > 0 ? (score / total * 20).toStringAsFixed(1) : '-';
return _pdfCell(grade, textStyle: pw.TextStyle(color: (double.tryParse(grade) ?? 0) >= 10 ? PdfColors.green : PdfColors.red));                    }).toList(),
                  ]);
                }).toList(),
              ],
            ),
          ];
        },
      ),
    );
    
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
  
  Future<void> _generateAttendanceReportPDF() async {
    final pdf = pw.Document();
    final totalDays = 20;
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, text: 'RAPPORT DE PRÉSENCES',
              textStyle: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Classe: $selectedClass'),
            pw.Text('Période: ${_formatDateRange()}'),
            pw.Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
            pw.SizedBox(height: 20),
            
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FixedColumnWidth(70),
                2: pw.FixedColumnWidth(70),
                3: pw.FixedColumnWidth(80),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _pdfHeaderCell('Élève'),
                    _pdfHeaderCell('Absences'),
                    _pdfHeaderCell('Présences'),
                    _pdfHeaderCell('Taux présence'),
                  ],
                ),
                ...studentReports.entries.map((entry) {
                  final absences = entry.value['absences'] as int;
                  final presences = totalDays - absences;
                  final rate = ((presences / totalDays) * 100).clamp(0, 100);
                  return pw.TableRow(children: [
                    _pdfCell(entry.key),
                    _pdfCell(absences.toString()),
                    _pdfCell(presences.toString()),
                    _pdfCell('${rate.toStringAsFixed(1)}%'),
                  ]);
                }).toList(),
              ],
            ),
            
            pw.SizedBox(height: 30),
            pw.Text('RÉSUMÉ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 10),
            _pdfStatRow('Taux de présence moyen:', '${_calculateAverageAttendanceRate(totalDays).toStringAsFixed(1)}%'),
            _pdfStatRow('Élève le plus assidu:', _getMostAssiduousStudent()),
            _pdfStatRow('Nombre total d\'absences:', _getTotalAbsences().toString()),
          ];
        },
      ),
    );
    
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
  
  pw.Widget _pdfHeaderCell(String text) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    );
  }
  
  pw.Widget _pdfCell(String text, {pw.TextStyle? textStyle}) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(text, style: textStyle),
    );
  }
  
  pw.Widget _pdfStatRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(children: [
        pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(width: 10),
        pw.Text(value),
      ]),
    );
  }
  
  pw.Widget _buildGradeBar(String label, int count, PdfColor color) {
    final height = (count * 15).clamp(0, 150).toDouble();
    return pw.Column(children: [
      pw.Container(width: 50, height: height, color: color),
      pw.SizedBox(height: 5),
      pw.Text(label),
      pw.Text(count.toString()),
    ]);
  }
  
  double _calculateClassAverage(String type) {
    if (studentReports.isEmpty) return 0;
    double total = 0;
    for (var data in studentReports.values) {
      total += data[type] as double;
    }
    return total / studentReports.length;
  }
  
  double _getBestAverage() {
    if (studentReports.isEmpty) return 0;
    double best = 0;
    for (var data in studentReports.values) {
      final avg = data['overallAverage'] as double;
      if (avg > best) best = avg;
    }
    return best;
  }
  
  double _calculateSuccessRate() {
    if (studentReports.isEmpty) return 0;
    int success = 0;
    for (var data in studentReports.values) {
      if ((data['overallAverage'] as double) >= 10) success++;
    }
    return (success / studentReports.length) * 100;
  }
  
  double _calculateAverageAttendanceRate(int totalDays) {
    if (studentReports.isEmpty) return 0;
    double total = 0;
    for (var data in studentReports.values) {
      final rate = ((totalDays - (data['absences'] as int)) / totalDays) * 100;
      total += rate;
    }
    return total / studentReports.length;
  }
  
  String _getMostAssiduousStudent() {
    if (studentReports.isEmpty) return 'Aucun';
    String best = '';
    int minAbsences = 999;
    for (var entry in studentReports.entries) {
      final absences = entry.value['absences'] as int;
      if (absences < minAbsences) {
        minAbsences = absences;
        best = entry.key;
      }
    }
    return best.isEmpty ? 'Aucun' : best;
  }
  
  int _getTotalAbsences() {
    int total = 0;
    for (var data in studentReports.values) {
      total += data['absences'] as int;
    }
    return total;
  }
  
  Map<String, int> _getGradeDistribution() {
    final dist = {'0-5': 0, '6-10': 0, '11-15': 0, '16-20': 0};
    for (var data in studentReports.values) {
      final avg = data['overallAverage'] as double;
      if (avg <= 5) dist['0-5'] = (dist['0-5'] ?? 0) + 1;
      else if (avg <= 10) dist['6-10'] = (dist['6-10'] ?? 0) + 1;
      else if (avg <= 15) dist['11-15'] = (dist['11-15'] ?? 0) + 1;
      else dist['16-20'] = (dist['16-20'] ?? 0) + 1;
    }
    return dist;
  }
  
  String _formatDateRange() => dateRange == null ? '' : '${DateFormat('dd/MM/yyyy').format(dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange!.end)}';
  
  String _getAppreciation(double avg) {
    if (avg >= 16) return 'Excellent';
    if (avg >= 14) return 'Très bien';
    if (avg >= 12) return 'Bien';
    if (avg >= 10) return 'Passable';
    return 'Insuffisant';
  }
  
  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }
  
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final classFilteredStudents = students.where((s) => selectedClass.isEmpty || s['className'] == selectedClass).toList();
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Rapports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData, tooltip: 'Actualiser'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (auth.currentSchoolId != null && !auth.isSuperAdmin)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(Icons.business, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text('École : ${auth.schoolName ?? auth.currentSchoolId}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.blue)),
                      ]),
                    ),
                  
                  // Carte des filtres
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(children: [
                            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.filter_alt, color: Colors.blue, size: 20)),
                            const SizedBox(width: 12),
                            const Text('Filtres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 20),
                          Row(children: [
                            Expanded(child: _buildClassDropdown()),
                            const SizedBox(width: 12),
                            Expanded(child: _buildSubjectDropdown()),
                          ]),
                          const SizedBox(height: 16),
                          _buildReportTypeDropdown(),
                          const SizedBox(height: 16),
                          _buildDateRangePicker(),
                          const SizedBox(height: 20),
                          _buildGenerateButton(),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Aperçu des résultats
                  if (studentReports.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.analytics, color: Colors.purple, size: 20)),
                              const SizedBox(width: 12),
                              const Text('Aperçu des résultats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ]),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 16,
                                dividerThickness: 1,
                                columns: const [
                                  DataColumn(label: Text('Élève', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Devoirs', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Examens', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Moyenne', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Rang', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: studentReports.entries.map((entry) {
                                  final data = entry.value;
                                  final avgColor = (data['overallAverage'] as double) >= 10 ? Colors.green : Colors.red;
                                  return DataRow(cells: [
                                    DataCell(Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500))),
                                    DataCell(Text((data['classAverage'] as double).toStringAsFixed(2))),
                                    DataCell(Text((data['examAverage'] as double).toStringAsFixed(2))),
                                    DataCell(Text((data['overallAverage'] as double).toStringAsFixed(2), style: TextStyle(color: avgColor, fontWeight: FontWeight.bold))),
                                    DataCell(Text(data['ranking'].toString())),
                                  ]);
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                _statCard("Moyenne classe", _calculateClassAverage("overallAverage").toStringAsFixed(2), Colors.blue),
                                _statCard("Taux réussite", "${_calculateSuccessRate().toStringAsFixed(1)}%", Colors.green),
                                _statCard("Meilleure note", _getBestAverage().toStringAsFixed(2), Colors.orange),
                                _statCard("Élèves", classFilteredStudents.length.toString(), Colors.purple),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  if (selectedClass.isNotEmpty && classFilteredStudents.isEmpty && !_isLoading)
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: Column(children: [
                        Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('Aucun élève dans cette classe', style: TextStyle(color: Colors.grey[600])),
                      ]),
                    ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildClassDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedClass.isNotEmpty ? selectedClass : null,
      hint: const Text('Classe'),
      items: widget.assignedClasses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: (value) => setState(() { selectedClass = value!; _organizeData(); }),
      decoration: InputDecoration(
        labelText: "Classe",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.class_, color: Colors.blue),
        filled: true, fillColor: Colors.white,
      ),
    );
  }
  
  Widget _buildSubjectDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedSubject,
      items: [
        const DropdownMenuItem(value: '', child: Text('Toutes les matières')),
        ...widget.assignedSubjects.map((s) => DropdownMenuItem(value: s, child: Text(s))),
      ],
      onChanged: (value) => setState(() { selectedSubject = value!; _organizeData(); }),
      decoration: InputDecoration(
        labelText: "Matière",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.book, color: Colors.orange),
        filled: true, fillColor: Colors.white,
      ),
    );
  }
  
  Widget _buildReportTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: reportType,
      items: const [
        DropdownMenuItem(value: 'bulletin', child: Text('📊 Bulletin de classe')),
        DropdownMenuItem(value: 'grades', child: Text('📝 Rapport des notes')),
        DropdownMenuItem(value: 'exam', child: Text('💻 Examens en ligne')),
        DropdownMenuItem(value: 'attendance', child: Text('📅 Présences')),
      ],
      onChanged: (value) => setState(() => reportType = value!),
      decoration: InputDecoration(
        labelText: "Type de rapport",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        prefixIcon: const Icon(Icons.picture_as_pdf, color: Colors.red),
        filled: true, fillColor: Colors.white,
      ),
    );
  }
  
  Widget _buildDateRangePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime(2026), initialDateRange: dateRange);
        if (picked != null) setState(() => dateRange = picked);
      },
      child: AbsorbPointer(
        child: TextFormField(
          decoration: InputDecoration(
            labelText: "Période",
            suffixIcon: const Icon(Icons.calendar_today),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true, fillColor: Colors.white,
          ),
          controller: TextEditingController(text: _formatDateRange()),
        ),
      ),
    );
  }
  
  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isGenerating ? null : _generateReport,
        icon: _isGenerating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.picture_as_pdf),
        label: Text(_isGenerating ? 'Génération en cours...' : 'Générer le rapport PDF'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: Colors.red[700],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
  
  Widget _statCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ]),
    );
  }
}
// lib/screens/admin/attendance_report.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../providers/auth_provider.dart';

class AttendanceReportScreen extends StatefulWidget {
  final Function? onChanged;
  
  const AttendanceReportScreen({super.key, this.onChanged});

  @override
  _AttendanceReportScreenState createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> sections = [];
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> attendances = [];
  List<Map<String, dynamic>> subjects = [];
  
  String selectedClassId = '';
  String selectedClassName = '';
  String selectedSubject = '';
  String reportType = 'attendance';
  DateTime startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime endDate = DateTime.now();
  
  String _selectedCycle = 'all';
  String? _selectedSectionId;
  
  bool _isLoading = true;
  bool _isGeneratingPDF = false;

  final List<String> _reportTypes = [
    'Présences', 
    'Liste des élèves'
  ];

  final List<Map<String, dynamic>> _cycles = [
    {'id': 'all', 'name': 'Tous', 'icon': Icons.all_inclusive, 'color': Color(0xFF6366F1)},
    {'id': 'primaire', 'name': 'Primaire', 'icon': Icons.abc, 'color': Color(0xFF10B981)},
    {'id': 'secondaire', 'name': 'Secondaire', 'icon': Icons.school, 'color': Color(0xFF8B5CF6)},
  ];

  @override
  void initState() {
    super.initState();
    _loadDataFromFirestore();
  }

  Future<void> _loadDataFromFirestore() async {
    setState(() => _isLoading = true);
    
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║     CHARGEMENT DES DONNÉES - ATTENDANCE REPORT            ║');
    print('╚════════════════════════════════════════════════════════════╝\n');
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      print('📱 Informations utilisateur:');
      print('   → schoolId: $schoolId');
      print('   → isSuperAdmin: ${auth.isSuperAdmin}');
      print('   → role: ${auth.user?.role}\n');
      
      // 1. Charger les classes
      print('📚 [1/5] Chargement des classes...');
      Query classQuery = FirebaseFirestore.instance.collection('classes');
      if (schoolId != null && !auth.isSuperAdmin) {
        classQuery = classQuery.where('schoolId', isEqualTo: schoolId);
        print('   → Filtre appliqué: where schoolId == $schoolId');
      } else {
        print('   → Aucun filtre schoolId (schoolId null ou super admin)');
      }
      
      final classesSnapshot = await classQuery.get();
      print('   → Nombre total de documents: ${classesSnapshot.docs.length}');
      
      classes = [];
      for (var doc in classesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final className = data['className'] ?? 'Sans nom';
        final docSchoolId = data['schoolId'];
        final cycleType = data['cycleType'] ?? 'primaire';
        
        print('      📖 Classe: "$className"');
        print('         - ID: ${doc.id}');
        print('         - schoolId dans doc: $docSchoolId (type: ${docSchoolId.runtimeType})');
        print('         - cycleType: $cycleType');
        print('         - hasSections: ${data['hasSections']}');
        
        classes.add({
          'firestoreId': doc.id,
          'className': className,
          'level': data['level'] ?? '',
          'year': data['year'] ?? '',
          'cycleType': cycleType,
          'hasSections': data['hasSections'] ?? false,
        });
      }
      print('   ✅ ${classes.length} classes chargées\n');
      
      // 2. Charger les sections
      print('📚 [2/5] Chargement des sections...');
      final sectionsSnapshot = await FirebaseFirestore.instance
          .collection('sections')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      
      print('   → Nombre de sections: ${sectionsSnapshot.docs.length}');
      sections = sectionsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'description': data['description'] ?? '',
        };
      }).toList();
      print('   ✅ ${sections.length} sections chargées\n');
      
      // 3. Charger les étudiants
      print('👨‍🎓 [3/5] Chargement des étudiants...');
      Query studentQuery = FirebaseFirestore.instance.collection('students');
      if (schoolId != null && !auth.isSuperAdmin) {
        studentQuery = studentQuery.where('schoolId', isEqualTo: schoolId);
        print('   → Filtre étudiants: schoolId == $schoolId');
      }
      
      final studentsSnapshot = await studentQuery.get();
      print('   → Nombre total d\'étudiants: ${studentsSnapshot.docs.length}');
      
      students = [];
      int studentsWithClass = 0;
      for (var doc in studentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final className = data['className'] ?? 'Sans classe';
        if (className != 'Sans classe') studentsWithClass++;
        students.add({
          'firestoreId': doc.id,
          'fullName': data['fullName'] ?? '',
          'className': className,
          'classFirestoreId': data['classFirestoreId'] ?? '',
          'classCycleType': data['classCycleType'] ?? 'primaire',
          'sectionId': data['sectionId'],
          'sectionName': data['sectionName'],
          'gender': data['gender'] ?? 'Masculin',
          'birthDate': data['birthDate'] ?? '',
          'birthPlace': data['birthPlace'] ?? '',
          'fatherName': data['fatherName'] ?? '',
          'motherName': data['motherName'] ?? '',
          'parentPhone': data['parentPhone'] ?? '',
          'address': data['address'] ?? '',
          'schoolId': data['schoolId']?.toString(),
        });
      }
      print('   → Étudiants avec classe assignée: $studentsWithClass/${students.length}');
      print('   ✅ ${students.length} étudiants chargés\n');
      
      // 4. Charger les présences
      print('📅 [4/5] Chargement des présences...');
      Query attendanceQuery = FirebaseFirestore.instance.collection('attendances');
      if (schoolId != null && !auth.isSuperAdmin) {
        attendanceQuery = attendanceQuery.where('schoolId', isEqualTo: schoolId);
      }
      
      final attendancesSnapshot = await attendanceQuery.get();
      print('   → Nombre total de présences: ${attendancesSnapshot.docs.length}');
      
      attendances = attendancesSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'studentName': data['studentName'] ?? '',
          'className': data['className'] ?? '',
          'classFirestoreId': data['classFirestoreId'] ?? '',
          'status': data['status'] ?? '',
          'subject': data['subject'] ?? '',
          'date': data['date'] != null 
    ? (data['date'] is Timestamp 
        ? (data['date'] as Timestamp).toDate() 
        : DateTime.tryParse(data['date']?.toString() ?? '') ?? DateTime.now())
    : DateTime.now(),
          'schoolId': data['schoolId']?.toString(),
        };
      }).toList();
      print('   ✅ ${attendances.length} présences chargées\n');
      
      // 5. Charger les matières
      print('📖 [5/5] Chargement des matières...');
      final subjectsSet = <String>{};
      for (var classItem in classes) {
        final classDoc = await FirebaseFirestore.instance
            .collection('classes')
            .doc(classItem['firestoreId'])
            .get();
        final classData = classDoc.data() as Map<String, dynamic>?;
        if (classData != null && classData['subjects'] != null) {
          final subjectsList = classData['subjects'] as List<dynamic>? ?? [];
          for (var subject in subjectsList) {
            final subjectMap = subject as Map<String, dynamic>;
            subjectsSet.add(subjectMap['name'] ?? '');
          }
        }
      }
      subjects = subjectsSet.map((s) => {'name': s}).toList();
      print('   ✅ ${subjects.length} matières chargées\n');
      
      // Sélectionner la première classe
      if (classes.isNotEmpty && selectedClassId.isEmpty) {
        final filtered = _filteredClasses;
        if (filtered.isNotEmpty) {
          selectedClassId = filtered.first['firestoreId'];
          selectedClassName = filtered.first['className'];
          print('🎯 Classe sélectionnée par défaut: $selectedClassName (ID: $selectedClassId)');
        } else {
          print('⚠️ _filteredClasses est vide!');
        }
      } else if (classes.isEmpty) {
        print('⚠️ Aucune classe trouvée dans Firestore!');
      }
      
      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║                    RÉSUMÉ FINAL                            ║');
      print('╠════════════════════════════════════════════════════════════╣');
      print('║   Classes: ${classes.length}');
      print('║   Sections: ${sections.length}');
      print('║   Étudiants: ${students.length}');
      print('║   Présences: ${attendances.length}');
      print('║   Matières: ${subjects.length}');
      print('║   selectedClassId: $selectedClassId');
      print('║   selectedClassName: $selectedClassName');
      print('╚════════════════════════════════════════════════════════════╝\n');
      
    } catch (e, stackTrace) {
      print('❌ ERREUR: $e');
      print('   Stack trace: $stackTrace');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredClasses {
    print('\n🔍 _filteredClasses appelé');
    print('   → _selectedCycle: $_selectedCycle');
    print('   → classes.length: ${classes.length}');
    
    if (_selectedCycle == 'all') {
      print('   → Retourne toutes les classes: ${classes.length}');
      return classes;
    } else {
      final filtered = classes.where((c) => c['cycleType'] == _selectedCycle).toList();
      print('   → Filtré par "$_selectedCycle": ${filtered.length} classes');
      for (var c in filtered) {
        print('      - ${c['className']} (${c['cycleType']})');
      }
      return filtered;
    }
  }

  String get _currentSelectedClassName {
    try {
      final classObj = _filteredClasses.firstWhere((c) => c['firestoreId'] == selectedClassId);
      print('🔍 _currentSelectedClassName: ${classObj['className']}');
      return classObj['className'] ?? '';
    } catch (e) {
      print('⚠️ Classe non trouvée pour selectedClassId: $selectedClassId');
      return '';
    }
  }

  List<Map<String, dynamic>> _getFilteredStudents() {
    print('\n🔍 _getFilteredStudents appelé');
    print('   → selectedClassId: $selectedClassId');
    
    if (selectedClassId.isEmpty) {
      print('   → selectedClassId vide, retourne []');
      return [];
    }
    
    final className = _currentSelectedClassName;
    if (className.isEmpty) {
      print('   → className vide, retourne []');
      return [];
    }
    
    print('   → Recherche étudiants avec className: "$className"');
    var filtered = students.where((s) => s['className'] == className).toList();
    print('   → ${filtered.length} étudiants trouvés dans cette classe');
    
    if (_selectedSectionId != null) {
      print('   → Filtrage par section: $_selectedSectionId');
      filtered = filtered.where((s) => s['sectionId'] == _selectedSectionId).toList();
      print('   → Après filtrage section: ${filtered.length} étudiants');
    }
    
    return filtered;
  }

  Map<String, dynamic> _generateReport() {
    final classStudents = _getFilteredStudents();
    final className = _currentSelectedClassName;
    
    print('\n📊 Génération du rapport pour: $className');
    print('   → Nombre étudiants: ${classStudents.length}');
    print('   → reportType: $reportType');
    
    if (reportType == 'students_list') {
      classStudents.sort((a, b) => (a['fullName'] as String).compareTo(b['fullName'] as String));
      
      int boys = classStudents.where((s) => s['gender'] == 'Masculin').length;
      int girls = classStudents.where((s) => s['gender'] == 'Féminin').length;
      
      return {
        'class': className,
        'classId': selectedClassId,
        'section': _selectedSectionId != null ? sections.firstWhere((s) => s['id'] == _selectedSectionId, orElse: () => {})['name'] : null,
        'generatedAt': DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
        'students': classStudents.map((student) {
          return {
            'name': student['fullName'],
            'gender': student['gender'],
            'birthDate': student['birthDate'] ?? 'Non renseignée',
            'birthPlace': student['birthPlace'] ?? 'Non renseigné',
            'fatherName': student['fatherName'] ?? 'Non renseigné',
            'motherName': student['motherName'] ?? 'Non renseigné',
            'parentPhone': student['parentPhone'] ?? 'Non renseigné',
            'address': student['address'] ?? 'Non renseignée',
            'sectionName': student['sectionName'],
          };
        }).toList(),
        'statistics': {
          'totalStudents': classStudents.length,
          'boys': boys,
          'girls': girls,
        },
      };
    }
    
    // Rapport de présence
    final classAttendances = attendances.where((a) => 
      a['className'] == className && 
      (selectedSubject.isEmpty || a['subject'] == selectedSubject) &&
      (a['date'] as DateTime).isAfter(startDate.subtract(const Duration(days: 1))) &&
      (a['date'] as DateTime).isBefore(endDate.add(const Duration(days: 1)))
    ).toList();
    
    print('   → Présences trouvées pour cette classe/matière: ${classAttendances.length}');
    
    final uniqueDates = classAttendances.map((a) => (a['date'] as DateTime).toIso8601String().split('T')[0]).toSet();
    
    int totalPresent = 0;
    int totalAbsent = 0;
    int totalLate = 0;
    
    Map<String, dynamic> report = {
      'class': className,
      'classId': selectedClassId,
      'section': _selectedSectionId != null ? sections.firstWhere((s) => s['id'] == _selectedSectionId, orElse: () => {})['name'] : null,
      'period': '${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
      'totalDays': uniqueDates.length,
      'subject': selectedSubject,
      'students': [],
      'statistics': {},
    };
    
    for (var student in classStudents) {
      final studentAttendances = classAttendances.where((a) => a['studentName'] == student['fullName']).toList();
      final presentCount = studentAttendances.where((a) => a['status'] == 'present').length;
      final absentCount = studentAttendances.where((a) => a['status'] == 'absent').length;
      final lateCount = studentAttendances.where((a) => a['status'] == 'late').length;
      
      totalPresent += presentCount;
      totalAbsent += absentCount;
      totalLate += lateCount;
      
      double rate = 0.0;
      if (studentAttendances.isNotEmpty) {
        rate = (presentCount / studentAttendances.length) * 100.0;
      }
      
      report['students'].add({
        'name': student['fullName'],
        'gender': student['gender'],
        'present': presentCount,
        'absent': absentCount,
        'late': lateCount,
        'total': studentAttendances.length,
        'rate': rate,
        'sectionName': student['sectionName'],
      });
    }
    
    (report['students'] as List).sort((a, b) => (b['rate'] as num).compareTo(a['rate'] as num));
    
    final totalAttendance = totalPresent + totalAbsent + totalLate;
    report['statistics'] = {
      'totalStudents': classStudents.length,
      'totalPresent': totalPresent,
      'totalAbsent': totalAbsent,
      'totalLate': totalLate,
      'globalRate': totalAttendance > 0 ? (totalPresent / totalAttendance) * 100 : 0,
      'bestClass': _getBestStudent(report['students']),
      'worstClass': _getWorstStudent(report['students']),
    };
    
    return report;
  }
  
  String _getBestStudent(List<dynamic> students) {
    if (students.isEmpty) return 'Aucun';
    var best = students.reduce((a, b) => (a['rate'] > b['rate']) ? a : b);
    return best['name'];
  }
  
  String _getWorstStudent(List<dynamic> students) {
    if (students.isEmpty) return 'Aucun';
    var worst = students.reduce((a, b) => (a['rate'] < b['rate']) ? a : b);
    return worst['name'];
  }

  Future<void> _generatePDF() async {
    if (selectedClassId.isEmpty) {
      _showSnackBar('Veuillez sélectionner une classe', Colors.orange);
      return;
    }
    
    setState(() => _isGeneratingPDF = true);
    
    try {
      final report = _generateReport();
      final pdf = pw.Document();
      
      if (reportType == 'students_list') {
        pdf.addPage(_buildStudentsListPDF(report));
      } else {
        pdf.addPage(_buildAttendancePDF(report));
      }
      
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
      _showSnackBar('PDF généré avec succès', Colors.green);
      
    } catch (e) {
      print('❌ Erreur génération PDF: $e');
      _showSnackBar('Erreur: $e', Colors.red);
    } finally {
      setState(() => _isGeneratingPDF = false);
    }
  }
  
  pw.Page _buildStudentsListPDF(Map<String, dynamic> report) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(20),
      build: (pw.Context context) {
        return [
          pw.Header(
            level: 0,
            text: 'LISTE DES ÉLÈVES',
            textStyle: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          
          pw.Container(
            padding: pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Classe: ${report['class']}',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                if (report['section'] != null)
                  pw.Text('Section: ${report['section']}',
                    style: pw.TextStyle(fontSize: 14)),
                pw.Text('Date d\'édition: ${report['generatedAt']}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard('Total', '${report['statistics']['totalStudents']}', PdfColors.blue),
              _buildStatCard('Garçons', '${report['statistics']['boys']}', PdfColors.green),
              _buildStatCard('Filles', '${report['statistics']['girls']}', PdfColors.purple),
            ],
          ),
          
          pw.SizedBox(height: 20),
          
          pw.Text('DÉTAIL DES ÉLÈVES',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: {
              0: pw.FixedColumnWidth(30),
              1: pw.FlexColumnWidth(3),
              2: pw.FixedColumnWidth(50),
              3: pw.FixedColumnWidth(60),
              4: pw.FixedColumnWidth(60),
              5: pw.FixedColumnWidth(80),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _pdfHeaderCell('N°'),
                  _pdfHeaderCell('Nom complet'),
                  _pdfHeaderCell('Sexe'),
                  _pdfHeaderCell('Section'),
                  _pdfHeaderCell('Date naiss.'),
                  _pdfHeaderCell('Téléphone'),
                ],
              ),
              ...(report['students'] as List).asMap().entries.map((entry) {
                final index = entry.key;
                final student = entry.value;
                return pw.TableRow(
                  children: [
                    _pdfCell('${index + 1}'),
                    _pdfCell(student['name']),
                    _pdfCell(student['gender']),
                    _pdfCell(student['sectionName'] ?? ''),
                    _pdfCell(student['birthDate']),
                    _pdfCell(student['parentPhone']),
                  ],
                );
              }).toList(),
            ],
          ),
          
          pw.SizedBox(height: 30),
          
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Rapport généré par l\'application Smart School',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
            ),
          ),
        ];
      },
    );
  }
  
  pw.Page _buildAttendancePDF(Map<String, dynamic> report) {
    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(20),
      build: (pw.Context context) {
        return [
          pw.Header(
            level: 0,
            text: 'RAPPORT DE PRÉSENCE',
            textStyle: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          
          pw.Container(
            padding: pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Classe: ${report['class']}',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                if (report['section'] != null)
                  pw.Text('Section: ${report['section']}',
                    style: pw.TextStyle(fontSize: 14)),
                if (report['subject'].isNotEmpty)
                  pw.Text('Matière: ${report['subject']}',
                    style: pw.TextStyle(fontSize: 14)),
                pw.Text('Période: ${report['period']}',
                  style: pw.TextStyle(fontSize: 14)),
                pw.Text('Date d\'édition: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard('Jours', '${report['totalDays']}', PdfColors.blue),
              _buildStatCard('Élèves', '${report['statistics']['totalStudents']}', PdfColors.green),
              _buildStatCard('Taux global', '${(report['statistics']['globalRate']).toStringAsFixed(1)}%', PdfColors.orange),
            ],
          ),
          
          pw.SizedBox(height: 20),
          
          pw.Container(
            padding: pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text('RÉSUMÉ DES PRÉSENCES',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('Présents', '${report['statistics']['totalPresent']}', PdfColors.green),
                    _buildSummaryItem('Absents', '${report['statistics']['totalAbsent']}', PdfColors.red),
                    _buildSummaryItem('Retards', '${report['statistics']['totalLate']}', PdfColors.orange),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    pw.Text('Meilleur élève: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(report['statistics']['bestClass']),
                    pw.SizedBox(width: 20),
                    pw.Text('Élève à améliorer: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(report['statistics']['worstClass']),
                  ],
                ),
              ],
            ),
          ),
          
          pw.SizedBox(height: 20),
          
          pw.Text('DÉTAIL PAR ÉLÈVE',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: {
              0: pw.FlexColumnWidth(3),
              1: pw.FixedColumnWidth(50),
              2: pw.FixedColumnWidth(60),
              3: pw.FixedColumnWidth(60),
              4: pw.FixedColumnWidth(60),
              5: pw.FixedColumnWidth(80),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _pdfHeaderCell('Élève'),
                  _pdfHeaderCell('Sexe'),
                  _pdfHeaderCell('Présent'),
                  _pdfHeaderCell('Absent'),
                  _pdfHeaderCell('Retard'),
                  _pdfHeaderCell('Taux'),
                ],
              ),
              ...(report['students'] as List).map((student) {
                final rate = (student['rate'] as num).toDouble();
                final color = rate >= 80 ? PdfColors.green :
                              rate >= 60 ? PdfColors.orange : PdfColors.red;
                return pw.TableRow(
                  children: [
                    _pdfCell(student['name']),
                    _pdfCell(student['gender']),
                    _pdfCell('${student['present']}',
                      textStyle: pw.TextStyle(color: PdfColors.green)),
                    _pdfCell('${student['absent']}',
                      textStyle: pw.TextStyle(color: PdfColors.red)),
                    _pdfCell('${student['late']}',
                      textStyle: pw.TextStyle(color: PdfColors.orange)),
                    _pdfCell('${rate.toStringAsFixed(1)}%',
                      textStyle: pw.TextStyle(color: color, fontWeight: pw.FontWeight.bold)),
                  ],
                );
              }).toList(),
            ],
          ),
          
          pw.SizedBox(height: 30),
          
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Rapport généré par l\'application Smart School',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
            ),
          ),
        ];
      },
    );
  }
  
  pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 100,
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(value,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: color)),
          pw.Text(label,
            style: pw.TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
  
  pw.Widget _buildSummaryItem(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(value,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color)),
        pw.Text(label,
          style: pw.TextStyle(fontSize: 12)),
      ],
    );
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
  
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3)),
    );
  }
  
  Future<void> _exportCSV() async {
    if (selectedClassId.isEmpty) {
      _showSnackBar('Veuillez sélectionner une classe', Colors.orange);
      return;
    }
    
    final report = _generateReport();
    
    if (reportType == 'students_list') {
      final students = report['students'] as List;
      String csv = "N°;Nom complet;Sexe;Section;Date naissance;Lieu naissance;Père;Mère;Téléphone;Adresse\n";
      for (int i = 0; i < students.length; i++) {
        final student = students[i];
        csv += "${i+1};${student['name']};${student['gender']};${student['sectionName'] ?? ''};${student['birthDate']};${student['birthPlace']};${student['fatherName']};${student['motherName']};${student['parentPhone']};${student['address']}\n";
      }
      _showSnackBar('CSV exporté (${students.length} élèves)', Colors.green);
    } else {
      final students = report['students'] as List;
      String csv = "Élève;Sexe;Section;Présent;Absent;Retard;Total;Taux\n";
      for (var student in students) {
        csv += "${student['name']};${student['gender']};${student['sectionName'] ?? ''};${student['present']};${student['absent']};${student['late']};${student['total']};${student['rate'].toStringAsFixed(1)}%\n";
      }
      csv += "\n;;;STATISTIQUES;;;\n";
      csv += "Total Présents;${report['statistics']['totalPresent']};;;\n";
      csv += "Total Absents;${report['statistics']['totalAbsent']};;;\n";
      csv += "Total Retards;${report['statistics']['totalLate']};;;\n";
      csv += "Taux Global;${(report['statistics']['globalRate']).toStringAsFixed(1)}%;;;\n";
      _showSnackBar('CSV exporté', Colors.green);
    }
  }

  Widget _buildCycleSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: _cycles.map((cycle) {
          final isSelected = _selectedCycle == cycle['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCycle = cycle['id'];
                  _selectedSectionId = null;
                  _updateSelectedClassAfterCycleChange();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected ? cycle['color'] : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(cycle['icon'], color: isSelected ? Colors.white : cycle['color'], size: 18),
                    const SizedBox(width: 8),
                    Text(cycle['name'], style: TextStyle(color: isSelected ? Colors.white : cycle['color'])),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _updateSelectedClassAfterCycleChange() {
    final filtered = _filteredClasses;
    if (filtered.isNotEmpty) {
      selectedClassId = filtered.first['firestoreId'];
      selectedClassName = filtered.first['className'];
    } else {
      selectedClassId = '';
      selectedClassName = '';
    }
    selectedSubject = '';
  }

  Widget _buildSectionSelector() {
    final availableSections = sections;
    
    if (availableSections.isEmpty) {
      return const SizedBox();
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: availableSections.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedSectionId == null;
            return GestureDetector(
              onTap: () => setState(() => _selectedSectionId = null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF59E0B) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Center(
                  child: Text(
                    'Toutes',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }
          
          final section = availableSections[index - 1];
          final isSelected = _selectedSectionId == section['id'];
          return GestureDetector(
            onTap: () => setState(() => _selectedSectionId = section['id']),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey[200],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: Text(
                  section['name'],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredClasses = _filteredClasses;
    final classStudents = _getFilteredStudents();
    final isSecondary = _selectedCycle == 'secondaire';
    
    print('\n🏗️ BUILD - État actuel:');
    print('   → classes.length: ${classes.length}');
    print('   → filteredClasses.length: ${filteredClasses.length}');
    print('   → classStudents.length: ${classStudents.length}');
    print('   → selectedClassId: $selectedClassId');
    print('   → selectedClassName: $selectedClassName');
    print('   → reportType: $reportType\n');
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Rapports'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDataFromFirestore,
            tooltip: 'Actualiser',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            onSelected: (value) {
              if (value == 'pdf') _generatePDF();
              else if (value == 'csv') _exportCSV();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, color: Colors.red), SizedBox(width: 8), Text('Exporter PDF')])),
              const PopupMenuItem(value: 'csv', child: Row(children: [Icon(Icons.table_chart, color: Colors.green), SizedBox(width: 8), Text('Exporter CSV')])),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (auth.currentSchoolId != null && !auth.isSuperAdmin)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, size: 18, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    Text('École : ${auth.schoolName ?? auth.currentSchoolId}'),
                  ],
                ),
              ),
            
            _buildCycleSelector(),
            
            const SizedBox(height: 12),
            
            if (isSecondary && sections.isNotEmpty)
              _buildSectionSelector(),
            
            const SizedBox(height: 12),
            
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: selectedClassId.isNotEmpty && filteredClasses.any((c) => c['firestoreId'] == selectedClassId) 
                            ? selectedClassId 
                            : null,
                        hint: Text(filteredClasses.isEmpty ? 'Aucune classe disponible' : 'Sélectionner une classe *'),
                        isExpanded: true,
                        items: filteredClasses.map<DropdownMenuItem<String>>((c) {
                          final isSec = c['cycleType'] == 'secondaire';
                          print('   📌 Dropdown item: ${c['className']} (${c['cycleType']})');
                          return DropdownMenuItem<String>(
                            value: c['firestoreId'],
                            child: Text('${c['className']} ${isSec ? "(Secondaire)" : "(Primaire)"}'),
                          );
                        }).toList(),
                        onChanged: filteredClasses.isEmpty ? null : (value) {
                          print('🔄 Changement classe: $value');
                          setState(() {
                            selectedClassId = value!;
                            final selected = classes.firstWhere((c) => c['firestoreId'] == selectedClassId);
                            selectedClassName = selected['className'];
                            selectedSubject = '';
                          });
                        },
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          prefixIcon: Icon(Icons.class_, color: Color(0xFF10B981)),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: reportType == 'attendance' ? 'Présences' : 'Liste des élèves',
                        items: _reportTypes.map((type) {
                          return DropdownMenuItem(value: type, child: Text(type));
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            if (value == 'Présences') reportType = 'attendance';
                            else reportType = 'students_list';
                          });
                        },
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          prefixIcon: Icon(Icons.report, color: Color(0xFF8B5CF6)),
                        ),
                      ),
                    ),
                    
                    if (reportType == 'attendance') ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: selectedSubject.isEmpty ? null : selectedSubject,
                          hint: const Text('Toutes les matières'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(value: '', child: Text('Toutes les matières')),
                            ...subjects.map<DropdownMenuItem<String>>((s) {
                              return DropdownMenuItem<String>(
                                value: s['name'] as String,
                                child: Text(s['name'] as String),
                              );
                            }),
                          ],
                          onChanged: (value) => setState(() => selectedSubject = value ?? ''),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            prefixIcon: Icon(Icons.book, color: Color(0xFFF59E0B)),
                          ),
                        ),
                      ),
                    ],
                    
                    if (reportType == 'attendance') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: TextFormField(
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: "Date début",
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF3B82F6)),
                                ),
                                controller: TextEditingController(text: DateFormat('dd/MM/yyyy').format(startDate)),
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: startDate,
                                    firstDate: DateTime(2023),
                                    lastDate: DateTime.now(),
                                  );
                                  if (date != null) setState(() => startDate = date);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: TextFormField(
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: "Date fin",
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  prefixIcon: Icon(Icons.calendar_today, color: Color(0xFF3B82F6)),
                                ),
                                controller: TextEditingController(text: DateFormat('dd/MM/yyyy').format(endDate)),
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: endDate,
                                    firstDate: startDate,
                                    lastDate: DateTime.now(),
                                  );
                                  if (date != null) setState(() => endDate = date);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Générer le rapport'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            if (reportType == 'attendance')
              _buildAttendanceSummaryCard(_generateReport())
            else
              _buildStudentsListSummaryCard(_generateReport(), classStudents),
            
            const SizedBox(height: 16),
            
            _buildStudentsList(classStudents),
            
            const SizedBox(height: 16),
            
            if (reportType == 'attendance')
              _buildAttendanceTable(_generateReport()),
            
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGeneratingPDF ? null : _generatePDF,
                icon: _isGeneratingPDF
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_isGeneratingPDF ? 'Génération en cours...' : 'Télécharger le rapport PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAttendanceSummaryCard(Map<String, dynamic> report) {
    return Card(
      elevation: 0,
      color: const Color(0xFF0F766E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('RAPPORT DE PRÉSENCE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(report['class'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70)),
            if (report['section'] != null)
              Text('Section: ${report['section']}', style: const TextStyle(fontSize: 14, color: Colors.white54)),
            if (report['subject'].isNotEmpty)
              Text(report['subject'], style: const TextStyle(fontSize: 14, color: Colors.white54)),
            Text(report['period'], style: const TextStyle(fontSize: 14, color: Colors.white54)),
            const SizedBox(height: 8),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildReportStat('Jours', report['totalDays'].toString(), Icons.calendar_today, Colors.white),
                _buildReportStat('Élèves', report['students'].length.toString(), Icons.people, Colors.white),
                _buildReportStat('Taux global', '${(report['statistics']['globalRate']).toStringAsFixed(1)}%', Icons.analytics, Colors.white),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildReportStat('Présents', report['statistics']['totalPresent'].toString(), Icons.check_circle, Colors.green),
                _buildReportStat('Absents', report['statistics']['totalAbsent'].toString(), Icons.cancel, Colors.red),
                _buildReportStat('Retards', report['statistics']['totalLate'].toString(), Icons.access_time, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStudentsListSummaryCard(Map<String, dynamic> report, List<Map<String, dynamic>> classStudents) {
    int boys = classStudents.where((s) => s['gender'] == 'Masculin').length;
    int girls = classStudents.where((s) => s['gender'] == 'Féminin').length;
    
    return Card(
      elevation: 0,
      color: const Color(0xFF8B5CF6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('LISTE DES ÉLÈVES', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(report['class'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70)),
            if (report['section'] != null)
              Text('Section: ${report['section']}', style: const TextStyle(fontSize: 14, color: Colors.white54)),
            Text('Total: ${report['statistics']['totalStudents']} élèves', style: const TextStyle(fontSize: 14, color: Colors.white54)),
            const SizedBox(height: 8),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildReportStat('Total', '${report['statistics']['totalStudents']}', Icons.people, Colors.white),
                _buildReportStat('Garçons', '$boys', Icons.man, Colors.blue),
                _buildReportStat('Filles', '$girls', Icons.woman, Colors.pink),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStudentsList(List<Map<String, dynamic>> classStudents) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.people, color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Liste des élèves', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${classStudents.length} élèves', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: classStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('Aucun élève dans cette classe', style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: classStudents.length,
                      itemBuilder: (context, index) {
                        final student = classStudents[index];
                        final isSecondary = student['classCycleType'] == 'secondaire';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                            child: Text(student['fullName'][0].toUpperCase(), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                          ),
                          title: Text(student['fullName'], style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${student['gender']} • ${student['birthDate'] ?? 'Date non renseignée'}'),
                              if (isSecondary && student['sectionName'] != null && student['sectionName'].isNotEmpty)
                                Text('Section: ${student['sectionName']}', style: TextStyle(fontSize: 11, color: Colors.purple[600])),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('ID: ${student['firestoreId'].substring(0, 6)}...', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAttendanceTable(Map<String, dynamic> report) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.table_chart, color: Color(0xFF3B82F6), size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Détail des présences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if ((report['students'] as List).isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('Aucune donnée de présence pour cette période', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  dividerThickness: 1,
                  columns: const [
                    DataColumn(label: Text('Élève', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Sexe', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Section', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Présent', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Absent', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Retard', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Taux', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: (report['students'] as List).map<DataRow>((student) {
                    final rate = (student['rate'] as num).toDouble();
                    return DataRow(
                      cells: [
                        DataCell(Text(student['name'], style: const TextStyle(fontWeight: FontWeight.w500))),
                        DataCell(Text(student['gender'])),
                        DataCell(Text(student['sectionName'] ?? '')),
                        DataCell(Text('${student['present']}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w500))),
                        DataCell(Text('${student['absent']}', style: const TextStyle(color: Color(0xFFEF4444)))),
                        DataCell(Text('${student['late']}', style: const TextStyle(color: Color(0xFFF59E0B)))),
                        DataCell(Text('${student['total']}')),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: rate >= 80 ? const Color(0xFF10B981) : rate >= 60 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('${rate.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
      ],
    );
  }
}
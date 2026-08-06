// lib/screens/teacher/teacher_reports_screen.dart

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/bulletin_pdf_generator.dart';
import '../../services/DetailedGradesReportGenerator.dart';

class TeacherReportsScreen extends StatefulWidget {
  final String teacherName;
  final String professorFirestoreId;
  final List<String> assignedClasses;
  final List<String> assignedSubjects;
  
  final bool isHomeroomTeacher;
  final String? homeroomClassId;
  final String? homeroomClassName;
  
  const TeacherReportsScreen({
    super.key,
    required this.teacherName,
    required this.professorFirestoreId,
    required this.assignedClasses,
    required this.assignedSubjects,
    this.isHomeroomTeacher = false,
    this.homeroomClassId,
    this.homeroomClassName,
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
  List<Map<String, dynamic>> allGrades = [];
  List<Map<String, dynamic>> examResults = [];
  List<Map<String, dynamic>> onlineExams = [];
  List<Map<String, dynamic>> attendances = [];
  
  Map<String, List<Map<String, dynamic>>> studentGrades = {};
  Map<String, List<Map<String, dynamic>>> studentExamResults = {};
  Map<String, Map<String, dynamic>> studentReports = {};
  
  final Map<String, List<Map<String, dynamic>>> _subjectsFromClasses = {};
  List<String> _currentSubjectsForClass = [];
  
  final Map<String, Map<String, int>> _subjectPeriodMaxMap = {};
  
  bool _isLoading = true;
  bool _isGenerating = false;
  late AnimationController _animationController;

  final List<Map<String, dynamic>> _reportOptions = [
    {'value': 'grades', 'label': 'Rapport détaillé des notes', 'icon': Icons.assignment, 'color': const Color(0xFF10B981)},
    {'value': 'bulletin', 'label': 'Bulletin officiel RDC', 'icon': Icons.school, 'color': const Color(0xFF3B82F6)},
    {'value': 'exam', 'label': 'Examens en ligne', 'icon': Icons.quiz, 'color': const Color(0xFFF59E0B)},
    {'value': 'attendance', 'label': 'Présences', 'icon': Icons.calendar_month, 'color': const Color(0xFF8B5CF6)},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    if (widget.isHomeroomTeacher && widget.homeroomClassName != null) {
      selectedClass = widget.homeroomClassName!;
    } else if (widget.assignedClasses.isNotEmpty) {
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
    
    try {
      if (widget.isHomeroomTeacher && widget.homeroomClassId != null && widget.homeroomClassName != null) {
        await _loadHomeroomData();
      } else {
        await _loadNormalData();
      }
      
      await _loadSubjectPeriodMaxMap();
      await _organizeData();
      _animationController.forward();
      
    } catch (e) {
      print('❌ Erreur: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadSubjectPeriodMaxMap() async {
    _subjectPeriodMaxMap.clear();
    
    try {
      final classQuery = await FirebaseFirestore.instance
          .collection('classes')
          .where('className', isEqualTo: selectedClass)
          .limit(1)
          .get();
      
      if (classQuery.docs.isNotEmpty) {
        final classData = classQuery.docs.first.data();
        final subjects = classData['subjects'] as List<dynamic>? ?? [];
        
        for (var subject in subjects) {
          final subjectMap = subject as Map<String, dynamic>;
          final subjectName = subjectMap['name'] as String;
          final maxValues = subjectMap['maxValues'] as Map<String, dynamic>?;
          
          if (maxValues != null) {
            _subjectPeriodMaxMap[subjectName] = {
              'p1': (maxValues['p1'] as num?)?.toInt() ?? 20,
              'p2': (maxValues['p2'] as num?)?.toInt() ?? 20,
              'ex1': (maxValues['ex1'] as num?)?.toInt() ?? 40,
              'p3': (maxValues['p3'] as num?)?.toInt() ?? 20,
              'p4': (maxValues['p4'] as num?)?.toInt() ?? 20,
              'ex2': (maxValues['ex2'] as num?)?.toInt() ?? 40,
            };
          } else {
            _subjectPeriodMaxMap[subjectName] = {
              'p1': 20, 'p2': 20, 'ex1': 40,
              'p3': 20, 'p4': 20, 'ex2': 40,
            };
          }
        }
      }
      
      print('📊 Max par période chargés pour ${_subjectPeriodMaxMap.length} matières');
      
    } catch (e) {
      print('❌ Erreur chargement max par période: $e');
    }
  }
  
  int _getPeriodMaxForGrade(Map<String, dynamic> grade) {
    final subject = grade['subject'] as String;
    final evaluationType = grade['evaluationType'] as String;
    final date = grade['date'] as DateTime;
    final semester = date.month <= 6 ? 1 : 2;
    
    final periodMaxMap = _subjectPeriodMaxMap[subject];
    if (periodMaxMap == null) return 20;
    
    switch (evaluationType) {
      case 'Devoir 1':
        return semester == 1 ? (periodMaxMap['p1'] ?? 20) : (periodMaxMap['p3'] ?? 20);
      case 'Devoir 2':
        return semester == 1 ? (periodMaxMap['p2'] ?? 20) : (periodMaxMap['p4'] ?? 20);
      case 'Examen':
        return semester == 1 ? (periodMaxMap['ex1'] ?? 40) : (periodMaxMap['ex2'] ?? 40);
      default:
        return 20;
    }
  }
  
  String _getPeriodLabel(String evaluationType, DateTime date) {
    final semester = date.month <= 6 ? 1 : 2;
    
    switch (evaluationType) {
      case 'Devoir 1':
        return semester == 1 ? 'P1' : 'P3';
      case 'Devoir 2':
        return semester == 1 ? 'P2' : 'P4';
      case 'Examen':
        return semester == 1 ? 'EX1' : 'EX2';
      default:
        return evaluationType;
    }
  }
  
  Future<void> _loadHomeroomData() async {
    print('\n🏫 CHARGEMENT RAPPORTS - PROFESSEUR TITULAIRE');
    print('   Classe: ${widget.homeroomClassName}');
    
    selectedClass = widget.homeroomClassName!;
    
    final classDoc = await FirebaseFirestore.instance
        .collection('classes')
        .doc(widget.homeroomClassId)
        .get();
    
    if (classDoc.exists) {
      final classData = classDoc.data() as Map<String, dynamic>;
      final subjects = classData['subjects'] as List<dynamic>? ?? [];
      
      final allSubjects = subjects.map((s) => (s as Map<String, dynamic>)['name'] as String).toList();
      _currentSubjectsForClass = allSubjects;
      
      if (_currentSubjectsForClass.isNotEmpty && selectedSubject.isEmpty) {
        selectedSubject = _currentSubjectsForClass.first;
      }
    }
    
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('students')
        .where('className', isEqualTo: widget.homeroomClassName)
        .get();
    
    students = [];
    for (var doc in studentsSnapshot.docs) {
      final data = doc.data();
      students.add({
        'firestoreId': doc.id,
        'fullName': data['fullName'] ?? 'Sans nom',
        'className': widget.homeroomClassName,
        'birthDate': data['birthDate'] ?? '',
        'parentPhone': data['parentPhone'] ?? '',
      });
    }
    
    final gradesSnapshot = await FirebaseFirestore.instance
        .collection('grades')
        .where('className', isEqualTo: widget.homeroomClassName)
        .get();
    
    allGrades = [];
    for (var doc in gradesSnapshot.docs) {
      final data = doc.data();
      allGrades.add({
        'id': doc.id,
        'studentFirestoreId': data['studentFirestoreId'] ?? '',
        'studentName': data['studentName'] ?? '',
        'subject': data['subject'] ?? '',
        'className': widget.homeroomClassName,
        'evaluationType': data['evaluationType'] ?? 'Devoir',
        'score': (data['score'] as num?)?.toDouble() ?? 0.0,
        'maxScore': (data['maxScore'] as num?)?.toDouble() ?? 20.0,
        'coefficient': (data['coefficient'] as num?)?.toDouble() ?? 1.0,
        'comments': data['comments'] ?? '',
        'date': data['date'] != null ? (data['date'] as Timestamp).toDate() : DateTime.now(),
      });
    }
    
    final examsSnapshot = await FirebaseFirestore.instance
        .collection('online_exams')
        .where('className', isEqualTo: widget.homeroomClassName)
        .get();
    
    onlineExams = [];
    for (var doc in examsSnapshot.docs) {
      final data = doc.data();
      onlineExams.add({
        'id': doc.id,
        'title': data['title'] ?? '',
        'subject': data['subject'] ?? '',
        'className': widget.homeroomClassName,
        'totalPoints': data['totalPoints'] ?? 0,
      });
    }
    
    final resultsSnapshot = await FirebaseFirestore.instance
        .collection('exam_results')
        .get();
    
    examResults = [];
    for (var doc in resultsSnapshot.docs) {
      final data = doc.data();
      examResults.add({
        'id': doc.id,
        'examId': data['examId'] ?? '',
        'studentName': data['studentName'] ?? '',
        'score': (data['score'] as num?)?.toDouble() ?? 0.0,
        'totalPoints': (data['totalPoints'] as num?)?.toDouble() ?? 0.0,
        'submittedAt': data['submittedAt'] != null ? (data['submittedAt'] as Timestamp).toDate() : null,
      });
    }
    
    final attendancesSnapshot = await FirebaseFirestore.instance
        .collection('attendances')
        .where('className', isEqualTo: widget.homeroomClassName)
        .get();
    
    attendances = [];
    for (var doc in attendancesSnapshot.docs) {
      final data = doc.data();
      attendances.add({
        'id': doc.id,
        'studentName': data['studentName'] ?? '',
        'className': widget.homeroomClassName,
        'status': data['status'] ?? 'present',
        'date': data['date'] != null ? (data['date'] as Timestamp).toDate() : DateTime.now(),
      });
    }
  }

  Future<void> _loadNormalData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;
    
    final classesSnapshot = await FirebaseFirestore.instance
        .collection('classes')
        .get();
    
    _subjectsFromClasses.clear();
    for (var doc in classesSnapshot.docs) {
      final data = doc.data();
      final className = data['className'] ?? '';
      final subjects = data['subjects'] as List<dynamic>? ?? [];
      
      if (className.isNotEmpty && subjects.isNotEmpty) {
        _subjectsFromClasses[className] = [];
        for (var subject in subjects) {
          final subjectMap = subject as Map<String, dynamic>;
          final subjectName = subjectMap['name'] ?? '';
          final professorId = subjectMap['professorFirestoreId'] ?? '';
          
          if (professorId == widget.professorFirestoreId) {
            _subjectsFromClasses[className]!.add({
              'name': subjectName,
              'professorFirestoreId': professorId,
              'coefficient': subjectMap['coefficient'] ?? 1.0,
            });
          }
        }
      }
    }
    
    if (selectedClass.isNotEmpty && _subjectsFromClasses.containsKey(selectedClass)) {
      _currentSubjectsForClass = _subjectsFromClasses[selectedClass]!
          .map((s) => s['name'] as String)
          .toList();
      
      if (_currentSubjectsForClass.isNotEmpty && selectedSubject.isEmpty) {
        selectedSubject = _currentSubjectsForClass.first;
      }
    }
    
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
    
    final gradesSnapshot = await FirebaseFirestore.instance
        .collection('grades')
        .get();
    
    allGrades = [];
    for (var doc in gradesSnapshot.docs) {
      final data = doc.data();
      final className = data['className'] ?? '';
      final subject = data['subject'] ?? '';
      
      if (widget.assignedClasses.contains(className)) {
        final classSubjects = _subjectsFromClasses[className] ?? [];
        final isAuthorizedSubject = classSubjects.any((s) => s['name'] == subject);
        
        if (isAuthorizedSubject) {
          allGrades.add({
            'id': doc.id,
            'studentFirestoreId': data['studentFirestoreId'] ?? '',
            'studentName': data['studentName'] ?? '',
            'subject': subject,
            'className': className,
            'evaluationType': data['evaluationType'] ?? 'Devoir',
            'score': (data['score'] as num?)?.toDouble() ?? 0.0,
            'maxScore': (data['maxScore'] as num?)?.toDouble() ?? 20.0,
            'coefficient': (data['coefficient'] as num?)?.toDouble() ?? 1.0,
            'comments': data['comments'] ?? '',
            'date': data['date'] != null ? (data['date'] as Timestamp).toDate() : DateTime.now(),
          });
        }
      }
    }
    
    final examsSnapshot = await FirebaseFirestore.instance
        .collection('online_exams')
        .get();
    
    onlineExams = [];
    for (var doc in examsSnapshot.docs) {
      final data = doc.data();
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
    
    final resultsSnapshot = await FirebaseFirestore.instance
        .collection('exam_results')
        .get();
    
    examResults = [];
    for (var doc in resultsSnapshot.docs) {
      final data = doc.data();
      examResults.add({
        'id': doc.id,
        'examId': data['examId'] ?? '',
        'studentName': data['studentName'] ?? '',
        'score': (data['score'] as num?)?.toDouble() ?? 0.0,
        'totalPoints': (data['totalPoints'] as num?)?.toDouble() ?? 0.0,
        'submittedAt': data['submittedAt'] != null ? (data['submittedAt'] as Timestamp).toDate() : null,
      });
    }
    
    final attendancesSnapshot = await FirebaseFirestore.instance
        .collection('attendances')
        .get();
    
    attendances = [];
    for (var doc in attendancesSnapshot.docs) {
      final data = doc.data();
      final className = data['className'] ?? '';
      if (widget.assignedClasses.contains(className)) {
        attendances.add({
          'id': doc.id,
          'studentName': data['studentName'] ?? '',
          'className': className,
          'status': data['status'] ?? 'present',
          'date': data['date'] != null ? (data['date'] as Timestamp).toDate() : DateTime.now(),
        });
      }
    }
  }
  
  Future<void> _organizeData() async {
    final filteredGrades = selectedSubject.isEmpty
        ? allGrades
        : allGrades.where((g) => g['subject'] == selectedSubject).toList();
    
    for (var grade in filteredGrades) {
      grade['periodMax'] = _getPeriodMaxForGrade(grade);
      grade['periodLabel'] = _getPeriodLabel(grade['evaluationType'], grade['date']);
    }
    
    studentGrades.clear();
    for (var grade in filteredGrades) {
      final studentId = grade['studentFirestoreId'] as String;
      if (!studentGrades.containsKey(studentId)) {
        studentGrades[studentId] = [];
      }
      studentGrades[studentId]!.add(grade);
    }
    
    studentExamResults.clear();
    for (var result in examResults) {
      final studentName = result['studentName'] as String;
      if (!studentExamResults.containsKey(studentName)) {
        studentExamResults[studentName] = [];
      }
      studentExamResults[studentName]!.add(result);
    }
    
    final filteredStudents = students.where((s) => 
      selectedClass.isEmpty || s['className'] == selectedClass).toList();
    
    studentReports.clear();
    for (var student in filteredStudents) {
      final studentId = student['firestoreId'] as String;
      final studentName = student['fullName'] as String;
      final classGrades = studentGrades[studentId] ?? [];
      final classExamResults = studentExamResults[studentName] ?? [];
      
      final calcResult = _calculateStudentWeightedAverage(classGrades);
      
      final totalObtained = calcResult['totalObtained'];
      final totalMaxPoints = calcResult['totalMaxPoints'];
      final percentage = calcResult['percentage'];
      final classAverage = totalMaxPoints > 0 ? (totalObtained / totalMaxPoints) * 20 : 0;
      
      double examTotal = 0;
      for (var result in classExamResults) {
        final score = result['score'] as double;
        final totalPoints = result['totalPoints'] as double;
        if (totalPoints > 0) {
          examTotal += (score / totalPoints) * 20;
        }
      }
      final examAverage = classExamResults.isNotEmpty ? examTotal / classExamResults.length : 0.0;
      
      int absences = 0;
      if (dateRange != null) {
        final studentAttendances = attendances.where((a) => 
          a['studentName'] == studentName && 
          a['status'] == 'absent' &&
          (a['date'] as DateTime).isAfter(dateRange!.start) &&
          (a['date'] as DateTime).isBefore(dateRange!.end.add(const Duration(days: 1)))
        ).toList();
        absences = studentAttendances.length;
      }
      
      studentReports[studentName] = {
        'student': student,
        'studentId': studentId,
        'grades': classGrades,
        'totalObtained': totalObtained,
        'totalMaxPoints': totalMaxPoints,
        'percentage': percentage,
        'classAverage': classAverage,
        'examAverage': examAverage,
        'absences': absences,
        'gradesCount': classGrades.length,
        'examsCount': classExamResults.length,
        'ranking': 0,
      };
    }
    
    final sortedReports = studentReports.entries.toList()
      ..sort((a, b) => (b.value['percentage'] as double).compareTo(a.value['percentage'] as double));
    
    for (int i = 0; i < sortedReports.length; i++) {
      studentReports[sortedReports[i].key]!['ranking'] = i + 1;
    }
  }

  Map<String, dynamic> _calculateStudentWeightedAverage(List<Map<String, dynamic>> grades) {
    if (grades.isEmpty) {
      return {
        'totalObtained': 0.0,
        'totalMaxPoints': 0.0,
        'percentage': 0.0,
      };
    }
    
    final Map<String, List<Map<String, dynamic>>> notesByPeriod = {};
    
    for (var grade in grades) {
      final period = grade['periodLabel'] ?? _getPeriodLabel(grade['evaluationType'], grade['date']);
      grade['periodLabel'] = period;
      
      if (!notesByPeriod.containsKey(period)) {
        notesByPeriod[period] = [];
      }
      notesByPeriod[period]!.add(grade);
    }
    
    double totalObtained = 0;
    double totalMaxPoints = 0;
    
    for (var periodNotes in notesByPeriod.values) {
      final periodMax = (periodNotes.first['periodMax'] as int?)?.toDouble() ?? 20.0;
      
      double totalWeightedMax = 0;
      for (var note in periodNotes) {
        totalWeightedMax += (note['maxScore'] as double) * (note['coefficient'] as double);
      }
      
      final conversionFactor = totalWeightedMax > 0 ? periodMax / totalWeightedMax : 0;
      
      double periodObtained = 0;
      double periodMaxPoints = 0;
      
      for (var note in periodNotes) {
        final score = note['score'] as double;
        final maxScore = note['maxScore'] as double;
        final coefficient = note['coefficient'] as double;
        
        final partPeriodMax = maxScore * coefficient * conversionFactor;
        final pointsObtained = (score / maxScore) * partPeriodMax;
        
        periodObtained += pointsObtained;
        periodMaxPoints += partPeriodMax;
      }
      
      totalObtained += periodObtained;
      totalMaxPoints += periodMaxPoints;
    }
    
    final percentage = totalMaxPoints > 0 ? (totalObtained / totalMaxPoints) * 100 : 0.0;
    
    return {
      'totalObtained': totalObtained,
      'totalMaxPoints': totalMaxPoints,
      'percentage': percentage,
    };
  }

  Future<void> _generateReport() async {
    if (selectedClass.isEmpty) {
      _showSnackBar('Veuillez sélectionner une classe', Colors.orange);
      return;
    }
    
    setState(() => _isGenerating = true);
    
    try {
      if (reportType == 'grades') {
        await _generateDetailedGradesReportPDF();
      } else if (reportType == 'bulletin') {
        await _generateClassBulletinPDF();
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

  Future<void> _generateDetailedGradesReportPDF() async {
    final classFilteredGrades = allGrades.where((g) => 
      g['className'] == selectedClass &&
      (selectedSubject.isEmpty || g['subject'] == selectedSubject)
    ).toList();
    
    for (var grade in classFilteredGrades) {
      grade['periodMax'] = _getPeriodMaxForGrade(grade);
      grade['periodLabel'] = _getPeriodLabel(grade['evaluationType'], grade['date']);
    }
    
    final classExams = onlineExams.where((e) => 
      e['className'] == selectedClass &&
      (selectedSubject.isEmpty || e['subject'] == selectedSubject)
    ).toList();
    
    final classExamResults = examResults.where((r) {
      final exam = onlineExams.firstWhere(
        (e) => e['id'] == r['examId'],
        orElse: () => {},
      );
      final examSubject = exam['subject'] ?? '';
      return exam['className'] == selectedClass &&
          (selectedSubject.isEmpty || examSubject == selectedSubject);
    }).toList();
    
    final classAttendances = attendances.where((a) =>
      a['className'] == selectedClass &&
      (dateRange == null || (
        (a['date'] as DateTime).isAfter(dateRange!.start) &&
        (a['date'] as DateTime).isBefore(dateRange!.end.add(const Duration(days: 1)))
      ))
    ).toList();
    
    final Map<String, List<Map<String, dynamic>>> studentGradesMap = {};
    for (var grade in classFilteredGrades) {
      final studentName = grade['studentName'] as String;
      if (!studentGradesMap.containsKey(studentName)) {
        studentGradesMap[studentName] = [];
      }
      studentGradesMap[studentName]!.add(grade);
    }
    
    final Map<String, List<Map<String, dynamic>>> studentExamsMap = {};
    for (var result in classExamResults) {
      final studentName = result['studentName'] as String;
      if (!studentExamsMap.containsKey(studentName)) {
        studentExamsMap[studentName] = [];
      }
      studentExamsMap[studentName]!.add(result);
    }
    
    final Map<String, List<Map<String, dynamic>>> studentAttendancesMap = {};
    for (var attendance in classAttendances) {
      final studentName = attendance['studentName'] as String;
      if (!studentAttendancesMap.containsKey(studentName)) {
        studentAttendancesMap[studentName] = [];
      }
      studentAttendancesMap[studentName]!.add(attendance);
    }
    
    final allStudentNames = {...studentGradesMap.keys, ...studentExamsMap.keys}.toList()..sort();
    
    await DetailedGradesReportGenerator.generateReport(
      classFilteredGrades: classFilteredGrades,
      classExams: classExams,
      examResults: examResults,
      classAttendances: classAttendances,
      studentGradesMap: studentGradesMap,
      studentExamsMap: studentExamsMap,
      studentAttendancesMap: studentAttendancesMap,
      allStudentNames: allStudentNames,
      selectedClass: selectedClass,
      selectedSubject: selectedSubject,
      dateRange: _formatDateRange(),
      teacherName: widget.teacherName,
      onlineExams: onlineExams,
      calculateAverage: (notes) => _calculateStudentWeightedAverage(notes),
      pdfHeaderCell: (text) => _pdfHeaderCell(text),
      pdfCell: (text, {textStyle}) => _pdfCell(text, textStyle: textStyle),
      pdfStatRow: (label, value) => _pdfStatRow(label, value),
      buildStatCard: (label, value, color) => _buildStatCard(label, value, color),
      buildCompleteSummaryTable: (names, gradesMap, examsMap, attMap) => 
        _buildCompleteSummaryTable(names, gradesMap, examsMap, attMap),
    );
    
    _showSnackBar('Rapport complet généré avec succès', Colors.green);
  }

  pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 100,
      padding: const pw.EdgeInsets.all(10),
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

  pw.Widget _buildCompleteSummaryTable(
    List<String> studentNames,
    Map<String, List<Map<String, dynamic>>> studentGradesMap,
    Map<String, List<Map<String, dynamic>>> studentExamsMap,
    Map<String, List<Map<String, dynamic>>> studentAttendancesMap,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FixedColumnWidth(90),
        2: pw.FixedColumnWidth(70),
        3: pw.FixedColumnWidth(70),
        4: pw.FixedColumnWidth(100),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _pdfHeaderCell('Eleve'),
            _pdfHeaderCell('Total Devoirs'),
            _pdfHeaderCell('Moyenne Examens'),
            _pdfHeaderCell('Taux Presence'),
            _pdfHeaderCell('Appreciation'),
          ],
        ),
        ...studentNames.map((studentName) {
          final notes = studentGradesMap[studentName] ?? [];
          final weightedAvg = _calculateStudentWeightedAverage(notes);
          final totalObtained = weightedAvg['totalObtained'];
          final totalMaxPoints = weightedAvg['totalMaxPoints'];
          
          final exams = studentExamsMap[studentName] ?? [];
          double examTotal = 0;
          for (var exam in exams) {
            final examObj = onlineExams.firstWhere((e) => e['id'] == exam['examId'], orElse: () => {});
            if (examObj.isNotEmpty) {
              final totalPoints = (examObj['totalPoints'] ?? 1).toDouble();
              final score = exam['score'] as double;
              examTotal += (score / totalPoints) * 20;
            }
          }
          final examAverage = exams.isNotEmpty ? examTotal / exams.length : 0;
          
          final studentAtt = studentAttendancesMap[studentName] ?? [];
          final presents = studentAtt.where((a) => a['status'] == 'present').length;
          final totalAttendance = studentAtt.length;
          final attendanceRate = totalAttendance > 0 ? (presents / totalAttendance * 100) : 0;
          
          final percentage = weightedAvg['percentage'];
          final appreciation = _getGradeLetter(percentage);
          final avgColor = percentage >= 50 ? PdfColors.green : PdfColors.red;
          
          return pw.TableRow(
            children: [
              _pdfCell(studentName),
              _pdfCell('${totalObtained?.toStringAsFixed(1) ?? "0"}/${totalMaxPoints?.toStringAsFixed(0) ?? "0"}'),
              _pdfCell('${examAverage.toStringAsFixed(2)}/20'),
              _pdfCell('${attendanceRate.toStringAsFixed(1)}%',
                textStyle: pw.TextStyle(color: attendanceRate >= 75 ? PdfColors.green : PdfColors.red)),
              _pdfCell(appreciation,
                textStyle: pw.TextStyle(color: avgColor, fontWeight: pw.FontWeight.bold)),
            ],
          );
        }),
      ],
    );
  }

  String _getGradeLetter(double percentage) {
    if (percentage >= 80) return "Excellent";
    if (percentage >= 70) return "Très bien";
    if (percentage >= 60) return "Bien";
    if (percentage >= 50) return "Passable";
    return "Insuffisant";
  }

  /// ✅ GÉNÉRATION DES BULLETINS
  Future<void> _generateClassBulletinPDF() async {
    if (selectedClass.isEmpty) {
      _showSnackBar('Veuillez sélectionner une classe', Colors.orange);
      return;
    }
    
    setState(() => _isGenerating = true);
    
    try {
      final schoolInfo = await _getSchoolInfo();
      
      final reportsList = studentReports.entries.map((entry) {
        final data = entry.value;
        data['student'] = data['student'];
        return data;
      }).toList();
      
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .where('className', isEqualTo: selectedClass)
          .limit(1)
          .get();

      List<Map<String, dynamic>> classSubjects = [];

      if (classDoc.docs.isNotEmpty) {
        final classData = classDoc.docs.first.data();
        classSubjects = List<Map<String, dynamic>>.from(classData['subjects'] ?? []);
        print('📚 Matières de la classe ${classSubjects.length}:');
        for (var s in classSubjects) {
          print('   - ${s['name']}: maxValues=${s['maxValues']}');
        }
      }
      
      // ✅ Générer chaque bulletin
      for (final report in reportsList) {
        final studentId = report['studentId'] as String;
        report['grades'] = studentGrades[studentId] ?? [];
        report['student'] = report['student'];
        report['ranking'] = report['ranking'];
        
        await BulletinPdfGenerator.generateBulletin(
          studentData: report,
          className: selectedClass,
          teacherName: widget.teacherName,
          allGrades: allGrades,
          examResults: examResults,
          attendances: attendances,
          classSubjects: classSubjects,
          schoolInfo: schoolInfo,
          totalStudents: reportsList.length,
        );
      }
      
      _showSnackBar('✅ ${reportsList.length} bulletin(s) généré(s) avec succès', Colors.green);
    } catch (e) {
      _showSnackBar('❌ Erreur: $e', Colors.red);
    } finally {
      setState(() => _isGenerating = false);
    }
  }
  
  Future<void> _generateExamReportPDF() async {
    final classExams = onlineExams.where((e) => e['className'] == selectedClass).toList();
    
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, text: 'RAPPORT DES EXAMENS EN LIGNE',
              textStyle: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
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
                  pw.Text('Classe: $selectedClass',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Professeur: ${widget.teacherName}'),
                  pw.Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
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
                    _pdfHeaderCell('Matiere'),
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
  
  Future<void> _generateAttendanceReportPDF() async {
    final pdf = pw.Document();
    final totalDays = 20;
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Header(level: 0, text: 'RAPPORT DE PRESENCES',
              textStyle: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
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
                  pw.Text('Classe: $selectedClass',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Periode: ${_formatDateRange()}'),
                  pw.Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                ],
              ),
            ),
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
                    _pdfHeaderCell('Eleve'),
                    _pdfHeaderCell('Absences'),
                    _pdfHeaderCell('Presences'),
                    _pdfHeaderCell('Taux presence'),
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
  
  Future<Map<String, String>> _getSchoolInfo() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId?.toString();
    
    Map<String, String> info = {
      'province': 'LOMAMI',
      'city': 'MWENE-DITU',
      'commune': 'BONDYI',
      'schoolName': 'INSTITUT BONDYI',
      'schoolCode': '9006613',
      'signaturePrefet': 'Le Préfet des Etudes',
      'signatureChef': 'Le Chef d\'Etablissement',
    };
    
    if (schoolId != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('school_settings')
            .doc(schoolId)
            .get();
        
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          info = {
            'province': data['province'] ?? info['province'],
            'city': data['city'] ?? info['city'],
            'commune': data['commune'] ?? info['commune'],
            'schoolName': data['schoolName'] ?? info['schoolName'],
            'schoolCode': data['schoolCode'] ?? info['schoolCode'],
            'signaturePrefet': data['signaturePrefet'] ?? info['signaturePrefet'],
            'signatureChef': data['signatureChef'] ?? info['signatureChef'],
          };
        }
      } catch (e) {
        print('Erreur chargement paramètres école: $e');
      }
    }
    
    return info;
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
  
  String _formatDateRange() => dateRange == null ? '' : '${DateFormat('dd/MM/yyyy').format(dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(dateRange!.end)}';
  
  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Rapports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF10B981)),
            onPressed: _loadAllData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))),
                  SizedBox(height: 16),
                  Text('Chargement des données...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Sélecteur de Classe
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildClassDropdown(),
                          const SizedBox(height: 16),
                          _buildSubjectDropdown(),
                          const SizedBox(height: 16),
                          _buildReportTypeDropdown(),
                          const SizedBox(height: 16),
                          _buildGenerateButton(),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Stats de la classe
                  if (selectedClass.isNotEmpty && !_isLoading)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.people, color: Color(0xFF3B82F6), size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Classe : $selectedClass',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1C2B45),
                                  ),
                                ),
                                Text(
                                  '👨‍🎓 ${studentReports.length} élève(s) • ${allGrades.where((g) => g['className'] == selectedClass).length} note(s)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
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
            ),
    );
  }
  
  Widget _buildClassDropdown() {
    final List<String> availableClasses = widget.isHomeroomTeacher && widget.homeroomClassName != null
        ? [widget.homeroomClassName!]
        : widget.assignedClasses;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonFormField<String>(
        value: selectedClass.isNotEmpty ? selectedClass : null,
        hint: const Text('Sélectionner une classe'),
        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF10B981)),
        items: availableClasses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (value) => setState(() { 
          selectedClass = value!; 
          _loadAllData();
        }),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.class_, color: Color(0xFF10B981)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
  
  Widget _buildSubjectDropdown() {
    final availableSubjects = widget.isHomeroomTeacher && widget.homeroomClassName != null
        ? _currentSubjectsForClass
        : (_subjectsFromClasses[selectedClass]?.map((s) => s['name'] as String).toList() ?? []);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonFormField<String>(
        value: selectedSubject.isNotEmpty && availableSubjects.contains(selectedSubject) ? selectedSubject : null,
        hint: const Text('Toutes les matières'),
        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFF59E0B)),
        items: [
          const DropdownMenuItem(value: '', child: Text('Toutes les matières')),
          ...availableSubjects.map((s) => DropdownMenuItem(value: s, child: Text(s))),
        ],
        onChanged: (value) => setState(() { 
          selectedSubject = value!; 
          _organizeData();
        }),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.book, color: Color(0xFFF59E0B)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
  
  Widget _buildReportTypeDropdown() {
    final selectedOption = _reportOptions.firstWhere((opt) => opt['value'] == reportType);
    
    return Container(
      decoration: BoxDecoration(
        color: (selectedOption['color'] as Color).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (selectedOption['color'] as Color).withOpacity(0.3)),
      ),
      child: DropdownButtonFormField<String>(
        value: reportType,
        items: _reportOptions.map<DropdownMenuItem<String>>((opt) {
          return DropdownMenuItem<String>(
            value: opt['value'] as String,
            child: Row(
              children: [
                Icon(opt['icon'] as IconData, color: opt['color'] as Color, size: 20),
                const SizedBox(width: 10),
                Text(opt['label'] as String, style: TextStyle(color: opt['color'] as Color)),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) => setState(() => reportType = value!),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
  
  Widget _buildGenerateButton() {
    final selectedOption = _reportOptions.firstWhere((opt) => opt['value'] == reportType);
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isGenerating ? null : _generateReport,
        icon: _isGenerating 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
            : const Icon(Icons.picture_as_pdf, color: Colors.white),
        label: Text(_isGenerating ? 'Génération en cours...' : 'Générer le rapport PDF'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: selectedOption['color'],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }
}
// lib/screens/admin/attendance_report.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class AttendanceReportScreen extends StatefulWidget {
  final Function? onChanged;
  
  const AttendanceReportScreen({super.key, this.onChanged});

  @override
  _AttendanceReportScreenState createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> attendances = [];
  
  String selectedClass = '';
  String selectedClassFirestoreId = '';
  DateTime startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime endDate = DateTime.now();
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDataFromFirestore();
  }

  /// 🔥 Charger les classes, étudiants et présences depuis Firestore
  Future<void> _loadDataFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      // 1. Charger les classes
      Query classQuery = FirebaseFirestore.instance.collection('classes');
      if (schoolId != null && !auth.isSuperAdmin) {
        classQuery = classQuery.where('schoolId', isEqualTo: schoolId);
      }
      
      final classesSnapshot = await classQuery.get();
      classes = classesSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'className': data['className'] ?? '',
          'level': data['level'] ?? '',
          'year': data['year'] ?? '',
        };
      }).toList();
      
      // 2. Charger les étudiants
      Query studentQuery = FirebaseFirestore.instance.collection('students');
      if (schoolId != null && !auth.isSuperAdmin) {
        studentQuery = studentQuery.where('schoolId', isEqualTo: schoolId);
      }
      
      final studentsSnapshot = await studentQuery.get();
      students = studentsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'fullName': data['fullName'] ?? '',
          'className': data['className'] ?? '',
          'schoolId': data['schoolId'],
        };
      }).toList();
      
      // 3. Charger les présences
      Query attendanceQuery = FirebaseFirestore.instance.collection('attendances');
      if (schoolId != null && !auth.isSuperAdmin) {
        attendanceQuery = attendanceQuery.where('schoolId', isEqualTo: schoolId);
      }
      
      final attendancesSnapshot = await attendanceQuery.get();
      attendances = attendancesSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'studentName': data['studentName'] ?? '',
          'className': data['className'] ?? '',
          'status': data['status'] ?? '',
          'subject': data['subject'] ?? '',
          'date': data['date'] != null ? (data['date'] as Timestamp).toDate() : DateTime.now(),
          'schoolId': data['schoolId'],
        };
      }).toList();
      
      if (classes.isNotEmpty && selectedClass.isEmpty) {
        selectedClass = classes.first['className'];
        selectedClassFirestoreId = classes.first['firestoreId'];
      }
      
      print('✅ ${classes.length} classes, ${students.length} étudiants, ${attendances.length} présences chargés');
    } catch (e) {
      print('❌ Erreur chargement: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _generateReport() {
    final classStudents = students.where((s) => s['className'] == selectedClass).toList();
    final classAttendances = attendances.where((a) => 
      a['className'] == selectedClass && 
      (a['date'] as DateTime).isAfter(startDate.subtract(const Duration(days: 1))) &&
      (a['date'] as DateTime).isBefore(endDate.add(const Duration(days: 1)))
    ).toList();
    
    final uniqueDates = classAttendances.map((a) => (a['date'] as DateTime).toIso8601String().split('T')[0]).toSet();
    
    Map<String, dynamic> report = {
      'class': selectedClass,
      'period': '${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
      'totalDays': uniqueDates.length,
      'students': [],
    };
    
    for (var student in classStudents) {
      final studentAttendances = classAttendances.where((a) => a['studentName'] == student['fullName']).toList();
      final presentCount = studentAttendances.where((a) => a['status'] == 'present').length;
      final absentCount = studentAttendances.where((a) => a['status'] == 'absent').length;
      final lateCount = studentAttendances.where((a) => a['status'] == 'late').length;
      
      double rate = 0.0;
      if (studentAttendances.isNotEmpty) {
        rate = (presentCount / studentAttendances.length) * 100.0;
      }
      
      report['students'].add({
        'name': student['fullName'],
        'present': presentCount,
        'absent': absentCount,
        'late': lateCount,
        'total': studentAttendances.length,
        'rate': rate,
      });
    }
    
    (report['students'] as List).sort((a, b) => (b['rate'] as num).compareTo(a['rate'] as num));
    
    return report;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))));
    }

    final report = _generateReport();
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Rapport de présence'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDataFromFirestore,
            tooltip: 'Actualiser',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export CSV en cours...'), backgroundColor: Color(0xFF10B981)),
              );
            },
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
                    Text(
                      'École : ${auth.schoolName ?? auth.currentSchoolId}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ),
            
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedClass,
                      items: classes.map<DropdownMenuItem<String>>((c) {
                        return DropdownMenuItem<String>(
                          value: c['className'] as String,
                          child: Text(c['className'] as String),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedClass = value!;
                          final selected = classes.firstWhere((c) => c['className'] == selectedClass);
                          selectedClassFirestoreId = selected['firestoreId'];
                        });
                      },
                      decoration: InputDecoration(
                        labelText: "Classe",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.class_),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: "Date début",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.calendar_today),
                            ),
                            controller: TextEditingController(
                              text: DateFormat('dd/MM/yyyy').format(startDate)
                            ),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(2023),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => startDate = date);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: "Date fin",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.calendar_today),
                            ),
                            controller: TextEditingController(
                              text: DateFormat('dd/MM/yyyy').format(endDate)
                            ),
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: startDate,
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => endDate = date);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Générer le rapport'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Card(
              elevation: 0,
              color: const Color(0xFF0F766E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'RAPPORT DE PRÉSENCE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report['class'],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70),
                    ),
                    Text(
                      report['period'],
                      style: TextStyle(fontSize: 14, color: Colors.white54),
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildReportStat('Jours', report['totalDays'].toString(), Icons.calendar_today, Colors.white),
                        _buildReportStat('Élèves', report['students'].length.toString(), Icons.people, Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Détail par élève',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 16,
                        columns: const [
                          DataColumn(label: Text('Élève', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Présent', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Absent', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Retard', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Taux', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: report['students'].map<DataRow>((student) {
                          final rate = (student['rate'] as num).toDouble();
                          return DataRow(
                            cells: [
                              DataCell(Text(student['name'])),
                              DataCell(Text('${student['present']}', style: const TextStyle(color: Color(0xFF10B981)))),
                              DataCell(Text('${student['absent']}', style: const TextStyle(color: Color(0xFFEF4444)))),
                              DataCell(Text('${student['late']}', style: const TextStyle(color: Color(0xFFF59E0B)))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: rate >= 80 ? const Color(0xFF10B981) : 
                                            rate >= 60 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${rate.toStringAsFixed(1)}%',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
      ],
    );
  }
}
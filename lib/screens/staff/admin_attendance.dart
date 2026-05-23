// lib/screens/admin/admin_attendance.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/db_helper.dart';
import '../../services/attendance_service.dart';
import '../../models/attendance_model.dart';
import '../../models/student_model.dart';
import '../../models/class_model.dart';
import '../../providers/auth_provider.dart';

class AdminAttendance extends StatefulWidget {
  final Function? onChanged;
  
  const AdminAttendance({super.key, this.onChanged});

  @override
  _AdminAttendanceState createState() => _AdminAttendanceState();
}

class _AdminAttendanceState extends State<AdminAttendance> {
  final DBHelper db = DBHelper();
  final AttendanceService _attendanceService = AttendanceService();
  List<ClassModel> classes = [];
  List<StudentModel> students = [];
  List<AttendanceModel> attendances = [];
  
  String selectedClass = '';
  DateTime selectedDate = DateTime.now();
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  
  bool _isLoading = true;
  String _viewMode = 'daily'; // 'daily', 'monthly', 'student'
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      classes = await db.getAllClasses();
      students = await db.getAllStudents();
      attendances = await db.getAllAttendances();
      
      // Synchronisation Firebase
      if (schoolId != null) {
        await _attendanceService.syncAllAttendancesToFirestore(schoolId.toString());
        await _attendanceService.syncAttendancesFromFirestore(schoolId.toString());
        // Recharger après sync
        attendances = await db.getAllAttendances();
      }
      
      if (classes.isNotEmpty && selectedClass.isEmpty) {
        selectedClass = classes.first.className;
      }
    } catch (e) {
      print('Erreur chargement: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<AttendanceModel> get _filteredAttendances {
    if (_viewMode == 'daily') {
      return attendances.where((a) => 
        a.className == selectedClass && 
        _isSameDay(a.date, selectedDate)
      ).toList();
    } else if (_viewMode == 'monthly') {
      return attendances.where((a) => 
        a.className == selectedClass && 
        a.date.year == selectedYear && 
        a.date.month == selectedMonth
      ).toList();
    } else {
      return attendances;
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  double _getAttendanceRate(String studentName) {
    final studentAttendances = attendances.where((a) => 
      a.studentName == studentName && 
      a.className == selectedClass
    ).toList();
    
    if (studentAttendances.isEmpty) return 0;
    
    final presentCount = studentAttendances.where((a) => 
      a.status == 'present'
    ).length;
    
    return (presentCount / studentAttendances.length) * 100;
  }

  Map<String, int> _getClassStats() {
    final classAttendances = attendances.where((a) => 
      a.className == selectedClass
    ).toList();
    
    return {
      'total': classAttendances.length,
      'present': classAttendances.where((a) => a.status == 'present').length,
      'absent': classAttendances.where((a) => a.status == 'absent').length,
      'late': classAttendances.where((a) => a.status == 'late').length,
      'excused': classAttendances.where((a) => a.status == 'excused').length,
    };
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Column(
        children: [
          if (auth.currentSchoolId != null && !auth.isSuperAdmin)
            Container(
              margin: const EdgeInsets.all(16),
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
            
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: selectedClass,
                  items: classes.map((c) {
                    return DropdownMenuItem(
                      value: c.className,
                      child: Text(c.className),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedClass = value!);
                  },
                  decoration: InputDecoration(
                    labelText: "Classe",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.class_),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'daily', label: Text('Journalier')),
                          ButtonSegment(value: 'monthly', label: Text('Mensuel')),
                          ButtonSegment(value: 'student', label: Text('Par élève')),
                        ],
                        selected: {_viewMode},
                        onSelectionChanged: (Set<String> selection) {
                          setState(() => _viewMode = selection.first);
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                
                if (_viewMode == 'daily')
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "Date",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: Icon(Icons.calendar_today),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          controller: TextEditingController(
                            text: DateFormat('dd/MM/yyyy').format(selectedDate)
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2023),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              setState(() => selectedDate = date);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                
                if (_viewMode == 'monthly')
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedMonth,
                          items: List.generate(12, (i) => i + 1).map((month) {
                            return DropdownMenuItem(
                              value: month,
                              child: Text(DateFormat('MMMM').format(DateTime(2024, month))),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => selectedMonth = value!);
                          },
                          decoration: InputDecoration(
                            labelText: "Mois",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedYear,
                          items: [2023, 2024, 2025].map((year) {
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => selectedYear = value!);
                          },
                          decoration: InputDecoration(
                            labelText: "Année",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Total', '${_getClassStats()['total']}', Icons.people, Colors.blue),
                _buildStatCard('Présents', '${_getClassStats()['present']}', Icons.check_circle, Colors.green),
                _buildStatCard('Absents', '${_getClassStats()['absent']}', Icons.cancel, Colors.red),
                _buildStatCard('Retards', '${_getClassStats()['late']}', Icons.access_time, Colors.orange),
              ],
            ),
          ),
          
          Expanded(
            child: _buildAttendanceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    if (_viewMode == 'student') {
      return _buildStudentList();
    }
    
    final attendances = _filteredAttendances;
    
    if (attendances.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Aucune présence enregistrée',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: attendances.length,
      itemBuilder: (context, index) {
        final att = attendances[index];
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(att.status),
              child: Icon(_getStatusIcon(att.status), color: Colors.white, size: 20),
            ),
            title: Text(
              att.studentName,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Matière: ${att.subject}'),
                if (att.reason != null && att.reason!.isNotEmpty)
                  Text('Justif: ${att.reason}', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _getStatusText(att.status),
                  style: TextStyle(
                    color: _getStatusColor(att.status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(att.date),
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentList() {
    final classStudents = students.where((s) => s.className == selectedClass).toList();
    
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: classStudents.length,
      itemBuilder: (context, index) {
        final student = classStudents[index];
        final rate = _getAttendanceRate(student.fullName);
        
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: rate >= 80 ? Colors.green : rate >= 60 ? Colors.orange : Colors.red,
              child: Text(
                student.fullName[0].toUpperCase(),
                style: TextStyle(color: Colors.white),
              ),
            ),
            title: Text(student.fullName, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Taux de présence: ${rate.toStringAsFixed(1)}%'),
                LinearProgressIndicator(
                  value: rate / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    rate >= 80 ? Colors.green : rate >= 60 ? Colors.orange : Colors.red,
                  ),
                ),
              ],
            ),
            children: [
              ...attendances
                  .where((a) => a.studentName == student.fullName && a.className == selectedClass)
                  .map((att) {
                return ListTile(
                  leading: Icon(_getStatusIcon(att.status), size: 16, color: _getStatusColor(att.status)),
                  title: Text(att.subject),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(att.date)),
                  trailing: Text(
                    _getStatusText(att.status),
                    style: TextStyle(color: _getStatusColor(att.status)),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'present': return 'Présent';
      case 'absent': return 'Absent';
      case 'late': return 'Retard';
      case 'excused': return 'Excusé';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present': return Colors.green;
      case 'absent': return Colors.red;
      case 'late': return Colors.orange;
      case 'excused': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'present': return Icons.check_circle;
      case 'absent': return Icons.cancel;
      case 'late': return Icons.access_time;
      case 'excused': return Icons.assignment_turned_in;
      default: return Icons.help;
    }
  }
}
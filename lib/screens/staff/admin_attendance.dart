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
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAttendance extends StatefulWidget {
  final Function? onChanged;
  
  const AdminAttendance({super.key, this.onChanged});

  @override
  _AdminAttendanceState createState() => _AdminAttendanceState();
}

class _AdminAttendanceState extends State<AdminAttendance> {
  final DBHelper db = DBHelper();
  final AttendanceService _attendanceService = AttendanceService();
  List<ClassModel> allClasses = [];
  List<ClassModel> filteredClasses = [];
  List<StudentModel> students = [];
  List<Map<String, dynamic>> attendances = [];
  List<Map<String, dynamic>> sections = [];
  
  String selectedClassId = '';
  String selectedClassName = '';
  DateTime selectedDate = DateTime.now();
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;
  
  String _selectedCycle = 'all';
  String? _selectedSectionId;
  
  bool _isLoading = true;
  String _viewMode = 'daily';

  final List<Map<String, dynamic>> _cycles = [
    {'id': 'all', 'name': 'Tous', 'icon': Icons.all_inclusive, 'color': const Color(0xFF6366F1)},
    {'id': 'primaire', 'name': 'Primaire', 'icon': Icons.abc, 'color': const Color(0xFF10B981)},
    {'id': 'secondaire', 'name': 'Secondaire', 'icon': Icons.school, 'color': const Color(0xFF8B5CF6)},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║     CHARGEMENT DES DONNÉES - ADMIN ATTENDANCE              ║');
    print('╚════════════════════════════════════════════════════════════╝\n');
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      print('📱 schoolId: $schoolId');
      
      // 1. Charger les classes depuis Firestore
      print('📚 [1/4] Chargement des classes...');
      Query classQuery = FirebaseFirestore.instance.collection('classes');
      if (schoolId != null && !auth.isSuperAdmin) {
        classQuery = classQuery.where('schoolId', isEqualTo: schoolId);
        print('   → Filtre: schoolId == $schoolId');
      }
      
      final classesSnapshot = await classQuery.get();
      print('   → ${classesSnapshot.docs.length} classes trouvées');
      
      allClasses = classesSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        print('      - ${data['className']} (schoolId: ${data['schoolId']})');
        return ClassModel(
          firestoreId: doc.id,
          className: data['className'] ?? '',
          level: data['level'] ?? '',
          year: data['year'] ?? '',
          cycleType: data['cycleType'] ?? 'primaire',
          subjects: data['subjects'] != null 
              ? List<Map<String, dynamic>>.from(data['subjects']) 
              : [],
          schoolId: data['schoolId']?.toString() ?? '',
          sectionId: data['sectionId'] as String?,
          section: data['section'] as String?,
        );
      }).toList();
      allClasses.sort((a, b) => a.className.compareTo(b.className));
      
      // 2. Charger les sections
      if (schoolId != null) {
        print('📚 [2/4] Chargement des sections...');
        final sectionsSnapshot = await FirebaseFirestore.instance
            .collection('sections')
            .where('schoolId', isEqualTo: schoolId)
            .get();
        
        sections = sectionsSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'] ?? '',
            'description': data['description'] ?? '',
          };
        }).toList();
        print('   → ${sections.length} sections chargées');
      }
      
      _filterClasses();
      
      // 3. Charger les étudiants depuis Firestore
      print('👨‍🎓 [3/4] Chargement des étudiants...');
      Query studentQuery = FirebaseFirestore.instance.collection('students');
      if (schoolId != null && !auth.isSuperAdmin) {
        studentQuery = studentQuery.where('schoolId', isEqualTo: schoolId);
      }
      
      final studentsSnapshot = await studentQuery.get();
      print('   → ${studentsSnapshot.docs.length} étudiants trouvés');
      
      students = studentsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StudentModel(
          fullName: data['fullName'] ?? '',
          className: data['className'] ?? '',
          birthDate: data['birthDate'] ?? '',
          birthPlace: data['birthPlace'] ?? '',
          fatherName: data['fatherName'] ?? '',
          motherName: data['motherName'] ?? '',
          parentPhone: data['parentPhone'] ?? '',
          address: data['address'] ?? '',
          documentsVerified: data['documentsVerified'] ?? false,
          userId: data['userId'] as int?,
          classHiveKey: data['classHiveKey'] as int?,
          HiveKey: data['HiveKey'] as int?,
          parentUserId: data['parentUserId'] as int?,
          parentRelation: data['parentRelation'],
          schoolId: data['schoolId']?.toString(),
          classCycleType: data['classCycleType'] ?? 'primaire',
          sectionId: data['sectionId'],
          sectionName: data['sectionName'],
          classFirestoreId: data['classFirestoreId'],
          classLevel: data['classLevel'],
          classYear: data['classYear'],
        );
      }).toList();
      
      // 4. Charger les présences
      print('📅 [4/4] Chargement des présences...');
      await _loadAttendancesFromFirestore(schoolId);
      
      // Sélectionner la première classe si disponible
      if (filteredClasses.isNotEmpty && selectedClassId.isEmpty) {
        selectedClassId = filteredClasses.first.firestoreId ?? '';
        selectedClassName = filteredClasses.first.className;
        print('🎯 Classe sélectionnée: $selectedClassName');
      }
      
      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║                    RÉSUMÉ FINAL                            ║');
      print('╠════════════════════════════════════════════════════════════╣');
      print('║   Classes: ${allClasses.length}');
      print('║   Sections: ${sections.length}');
      print('║   Étudiants: ${students.length}');
      print('║   Présences: ${attendances.length}');
      print('╚════════════════════════════════════════════════════════════╝\n');
      
    } catch (e) {
      print('❌ ERREUR: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 🔥 Charger les présences directement depuis Firestore
  Future<void> _loadAttendancesFromFirestore(String? schoolId) async {
    try {
      print('📥 Chargement des présences...');
      Query query = FirebaseFirestore.instance.collection('attendances');
      
      if (schoolId != null && schoolId.isNotEmpty) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.get();
      print('   → ${snapshot.docs.length} présences trouvées');
      
      attendances = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final dateValue = data['date'];
        DateTime date;
        
        if (dateValue is Timestamp) {
          date = dateValue.toDate();
        } else if (dateValue is String) {
          date = DateTime.tryParse(dateValue) ?? DateTime.now();
        } else {
          date = DateTime.now();
        }
        
        return {
          'firestoreId': doc.id,
          'studentName': data['studentName'] ?? '',
          'className': data['className'] ?? '',
          'subject': data['subject'] ?? '',
          'status': data['status'] ?? 'present',
          'reason': data['reason'],
          'date': date,
          'studentFirestoreId': data['studentFirestoreId'],
          'recordedBy': data['recordedBy'],
          'recordedAt': data['recordedAt'] != null 
              ? (data['recordedAt'] as Timestamp).toDate() 
              : null,
        };
      }).toList();
      
      attendances.sort((a, b) => b['date'].compareTo(a['date']));
      print('   ✅ ${attendances.length} présences chargées');
    } catch (e) {
      print('❌ Erreur chargement présences: $e');
      attendances = [];
    }
  }

  void _filterClasses() {
    setState(() {
      if (_selectedCycle == 'all') {
        filteredClasses = List.from(allClasses);
      } else {
        filteredClasses = allClasses.where((c) => 
          (c.cycleType ?? 'primaire') == _selectedCycle
        ).toList();
      }
      
      print('🔍 Filtrage classes: ${filteredClasses.length}/${allClasses.length} (cycle: $_selectedCycle)');
      
      if (selectedClassId.isNotEmpty && !filteredClasses.any((c) => c.firestoreId == selectedClassId)) {
        selectedClassId = filteredClasses.isNotEmpty ? (filteredClasses.first.firestoreId ?? '') : '';
        selectedClassName = filteredClasses.isNotEmpty ? filteredClasses.first.className : '';
      }
    });
  }

  String get _currentSelectedClassName {
    try {
      final classObj = filteredClasses.firstWhere((c) => c.firestoreId == selectedClassId);
      return classObj.className;
    } catch (e) {
      return '';
    }
  }

  List<StudentModel> get _filteredStudents {
    if (selectedClassId.isEmpty) return [];
    
    final className = _currentSelectedClassName;
    if (className.isEmpty) return [];
    
    print('🔍 Filtrage étudiants par classe: $className');
    var filtered = students.where((s) => s.className == className).toList();
    print('   → ${filtered.length} étudiants trouvés');
    
    if (_selectedSectionId != null) {
      filtered = filtered.where((s) => s.sectionId == _selectedSectionId).toList();
      print('   → Après filtre section: ${filtered.length} étudiants');
    }
    
    return filtered;
  }

  List<Map<String, dynamic>> get _filteredAttendances {
    if (selectedClassId.isEmpty) return [];
    
    final className = _currentSelectedClassName;
    if (className.isEmpty) return [];
    
    print('🔍 Filtrage présences par classe: $className');
    
    List<Map<String, dynamic>> filtered;
    if (_viewMode == 'daily') {
      filtered = attendances.where((a) => 
        a['className'] == className && 
        _isSameDay(a['date'], selectedDate)
      ).toList();
      print('   → ${filtered.length} présences pour le ${DateFormat('dd/MM/yyyy').format(selectedDate)}');
    } else if (_viewMode == 'monthly') {
      filtered = attendances.where((a) => 
        a['className'] == className && 
        a['date'].year == selectedYear && 
        a['date'].month == selectedMonth
      ).toList();
      print('   → ${filtered.length} présences pour ${DateFormat('MMMM yyyy').format(DateTime(selectedYear, selectedMonth))}');
    } else {
      filtered = attendances.where((a) => a['className'] == className).toList();
      print('   → ${filtered.length} présences totales');
    }
    
    return filtered;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }

  double _getAttendanceRate(String studentName) {
    final className = _currentSelectedClassName;
    if (className.isEmpty) return 0;
    
    final studentAttendances = attendances.where((a) => 
      a['studentName'] == studentName && a['className'] == className
    ).toList();
    if (studentAttendances.isEmpty) return 0;
    final presentCount = studentAttendances.where((a) => a['status'] == 'present').length;
    return (presentCount / studentAttendances.length) * 100;
  }

  Map<String, int> _getClassStats() {
    if (selectedClassId.isEmpty) {
      return {'total': 0, 'present': 0, 'absent': 0, 'late': 0, 'excused': 0};
    }
    
    final className = _currentSelectedClassName;
    if (className.isEmpty) return {'total': 0, 'present': 0, 'absent': 0, 'late': 0, 'excused': 0};
    
    final classAttendances = attendances.where((a) => a['className'] == className).toList();
    return {
      'total': classAttendances.length,
      'present': classAttendances.where((a) => a['status'] == 'present').length,
      'absent': classAttendances.where((a) => a['status'] == 'absent').length,
      'late': classAttendances.where((a) => a['status'] == 'late').length,
      'excused': classAttendances.where((a) => a['status'] == 'excused').length,
    };
  }

  String _getSectionName(String? sectionId) {
    if (sectionId == null) return '';
    final section = sections.firstWhere((s) => s['id'] == sectionId, orElse: () => {});
    return section['name'] ?? '';
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
                  _filterClasses();
                  _loadAttendancesFromFirestore(
                    Provider.of<AuthProvider>(context, listen: false).currentSchoolId
                  );
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

  Widget _buildSectionSelector() {
    if (_selectedCycle != 'secondaire') return const SizedBox();
    if (sections.isEmpty) return const SizedBox();
    
    return Container(
      margin: const EdgeInsets.only(top: 12),
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sections.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedSectionId == null;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedSectionId = null);
              },
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
          
          final section = sections[index - 1];
          final isSelected = _selectedSectionId == section['id'];
          return GestureDetector(
            onTap: () {
              setState(() => _selectedSectionId = section['id']);
            },
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
    final isSecondary = _selectedCycle == 'secondaire';
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
                  Text('École : ${auth.schoolName ?? auth.currentSchoolId}'),
                ],
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCycleSelector(),
          ),
          
          if (isSecondary) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSectionSelector(),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Filtres
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: selectedClassId.isNotEmpty && filteredClasses.any((c) => c.firestoreId == selectedClassId) 
                        ? selectedClassId 
                        : null,
                    hint: const Text('Sélectionner une classe'),
                    isExpanded: true,
                    items: filteredClasses.map((c) {
                      final isSec = (c.cycleType ?? 'primaire') == 'secondaire';
                      return DropdownMenuItem<String>(
                        value: c.firestoreId,
                        child: Text('${c.className} ${isSec ? "(Secondaire)" : "(Primaire)"}'),
                      );
                    }).toList(),
                    onChanged: filteredClasses.isEmpty ? null : (value) {
                      setState(() {
                        selectedClassId = value!;
                        final selected = filteredClasses.firstWhere((c) => c.firestoreId == selectedClassId);
                        selectedClassName = selected.className;
                        _loadAttendancesFromFirestore(auth.currentSchoolId);
                      });
                    },
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      prefixIcon: Icon(Icons.class_),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
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
                ),
                
                if (_viewMode == 'daily') ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextFormField(
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Date",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        prefixIcon: Icon(Icons.calendar_today),
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
                          setState(() {
                            selectedDate = date;
                            _loadAttendancesFromFirestore(auth.currentSchoolId);
                          });
                        }
                      },
                    ),
                  ),
                ],
                
                if (_viewMode == 'monthly') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonFormField<int>(
                            value: selectedMonth,
                            isExpanded: true,
                            items: List.generate(12, (i) => i + 1).map((month) {
                              return DropdownMenuItem(
                                value: month,
                                child: Text(DateFormat('MMMM').format(DateTime(2024, month))),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedMonth = value!;
                                _loadAttendancesFromFirestore(auth.currentSchoolId);
                              });
                            },
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              prefixIcon: Icon(Icons.calendar_month),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonFormField<int>(
                            value: selectedYear,
                            isExpanded: true,
                            items: [2023, 2024, 2025, 2026].map((year) {
                              return DropdownMenuItem(
                                value: year,
                                child: Text(year.toString()),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedYear = value!;
                                _loadAttendancesFromFirestore(auth.currentSchoolId);
                              });
                            },
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Stats
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildStatCard('Total', '${_getClassStats()['total']}', Icons.people, Colors.blue),
                  const SizedBox(width: 12),
                  _buildStatCard('Présents', '${_getClassStats()['present']}', Icons.check_circle, Colors.green),
                  const SizedBox(width: 12),
                  _buildStatCard('Absents', '${_getClassStats()['absent']}', Icons.cancel, Colors.red),
                  const SizedBox(width: 12),
                  _buildStatCard('Retards', '${_getClassStats()['late']}', Icons.access_time, Colors.orange),
                ],
              ),
            ),
          ),
          
          // Liste
          Expanded(
            child: _viewMode == 'student' 
                ? _buildStudentList() 
                : _buildAttendanceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    final attendancesList = _filteredAttendances;
    
    if (attendancesList.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Aucune présence enregistrée'),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: attendancesList.length,
      itemBuilder: (context, index) {
        final att = attendancesList[index];
        final student = students.firstWhere(
          (s) => s.fullName == att['studentName'],
          orElse: () => StudentModel(
            fullName: '',
            className: '',
            birthDate: '',
            birthPlace: '',
            fatherName: '',
            motherName: '',
            parentPhone: '',
            address: '',
            documentsVerified: false,
            userId: null,
            classHiveKey: null,
            HiveKey: null,
            parentUserId: null,
            parentRelation: null,
            schoolId: null,
            classCycleType: 'primaire',
            sectionId: null,
            sectionName: null,
            classFirestoreId: null,
            classLevel: null,
            classYear: null,
          ),
        );
        final isSecondary = (student.classCycleType ?? 'primaire') == 'secondaire';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(att['status']),
              child: Icon(_getStatusIcon(att['status']), color: Colors.white, size: 20),
            ),
            title: Text(att['studentName'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Matière: ${att['subject']}'),
                if (isSecondary && student.sectionName != null && student.sectionName!.isNotEmpty)
                  Text('Section: ${student.sectionName}', style: const TextStyle(fontSize: 12, color: Colors.purple)),
                if (att['reason'] != null && att['reason'].isNotEmpty)
                  Text('Justif: ${att['reason']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_getStatusText(att['status']), style: TextStyle(color: _getStatusColor(att['status']), fontWeight: FontWeight.bold)),
                Text(DateFormat('dd/MM/yyyy HH:mm').format(att['date']), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentList() {
    final classStudents = _filteredStudents;
    final isSecondary = _selectedCycle == 'secondaire';
    
    if (classStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Aucun étudiant dans cette classe', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: classStudents.length,
      itemBuilder: (context, index) {
        final student = classStudents[index];
        final rate = _getAttendanceRate(student.fullName);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: rate >= 80 ? Colors.green : rate >= 60 ? Colors.orange : Colors.red,
              child: Text(student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
            ),
            title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Taux de présence: ${rate.toStringAsFixed(1)}%'),
                LinearProgressIndicator(
                  value: rate / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(rate >= 80 ? Colors.green : rate >= 60 ? Colors.orange : Colors.red),
                ),
                if (isSecondary && student.sectionName != null && student.sectionName!.isNotEmpty)
                  Text('Section: ${student.sectionName}', style: const TextStyle(fontSize: 12, color: Colors.purple)),
              ],
            ),
            children: [
              ...attendances
                  .where((a) => a['studentName'] == student.fullName && a['className'] == _currentSelectedClassName)
                  .map((att) => ListTile(
                    leading: Icon(_getStatusIcon(att['status']), size: 16, color: _getStatusColor(att['status'])),
                    title: Text(att['subject']),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(att['date'])),
                    trailing: Text(_getStatusText(att['status']), style: TextStyle(color: _getStatusColor(att['status']))),
                  )),
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
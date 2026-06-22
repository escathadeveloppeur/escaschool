// lib/screens/teacher/teacher_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../providers/auth_provider.dart';
import 'teacher_attendance.dart';
import 'teacher_grades.dart';
import 'teacher_students.dart';
import 'teacher_schedule.dart';
import 'teacher_reports.dart';
import 'create_exam_screen.dart';
import 'manage_exams_screen.dart';
import 'create_course_screen.dart';
import 'manage_courses_screen.dart';
import 'teacher_messages_screen.dart';
import 'teacher_announcements.dart'; // ✅ NOUVEAU : Page des annonces

// ===================== PALETTE / THEME HELPERS =====================
class _AppColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B5BDB);
  static const Color background = Color(0xFFF4F6FB);
  static const Color cardBorder = Color(0xFFE6E9F2);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF8B5CF6);
}

class TeacherDashboard extends StatefulWidget {
  final String professorFirestoreId;
  final String professorName;
  
  const TeacherDashboard({
    super.key,
    required this.professorFirestoreId,
    required this.professorName,
  });

  @override
  _TeacherDashboardState createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> with SingleTickerProviderStateMixin {
  int selectedIndex = 0;
  
  List<Map<String, dynamic>> _assignedClasses = [];
  List<Map<String, dynamic>> _schedules = [];
  List<String> _assignedSubjects = [];
  
  bool _isHomeroomTeacher = false;
  String? _homeroomClassId;
  String? _homeroomClassName;
  List<Map<String, dynamic>> _allSubjectsForClass = [];
  
  int totalStudents = 0;
  int nextClassCount = 0;
  String _status = 'Actif';
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedClass = '';
  int totalUnreadMessages = 0;
  
  late AnimationController _animationController;
  
  // ✅ Liste des pages avec Annonces
  final List<String> titles = [
    "Tableau de Bord",
    "Présences",
    "Notes & Évaluations",
    "Mes Élèves",
    "Emploi du Temps",
    "Rapports & Bulletins",
    "Annonces", // ✅ NOUVEAU
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadDashboardData();
    _loadUnreadMessagesCount();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadMessagesCount() async {
    try {
      final unreadMessages = await FirebaseFirestore.instance
          .collection('messages')
          .where('recipientId', isEqualTo: widget.professorFirestoreId)
          .where('recipientRole', isEqualTo: 'teacher')
          .where('read', isEqualTo: false)
          .get();
      
      setState(() {
        totalUnreadMessages = unreadMessages.docs.length;
      });
    } catch (e) {
      print('❌ Erreur chargement messages non lus: $e');
    }
  }
  
  Future<void> _checkIfHomeroomTeacher() async {
    try {
      final professorDoc = await FirebaseFirestore.instance
          .collection('professors')
          .doc(widget.professorFirestoreId)
          .get();
      
      if (professorDoc.exists) {
        final data = professorDoc.data();
        _isHomeroomTeacher = data?['isHomeroomTeacher'] ?? false;
        _homeroomClassId = data?['homeroomClassId'];
        _homeroomClassName = data?['homeroomClassName'];
      }
    } catch (e) {
      print('❌ Erreur vérification titulaire: $e');
    }
  }
  
  Future<void> _loadHomeroomData() async {
    final classDoc = await FirebaseFirestore.instance
        .collection('classes')
        .doc(_homeroomClassId)
        .get();
    
    if (classDoc.exists) {
      final classData = classDoc.data() as Map<String, dynamic>;
      final subjects = classData['subjects'] as List<dynamic>? ?? [];
      
      _allSubjectsForClass = [];
      
      for (var subject in subjects) {
        final subjectMap = subject as Map<String, dynamic>;
        _allSubjectsForClass.add({
          'name': subjectMap['name'] ?? '',
          'coefficient': subjectMap['coefficient'] ?? 1.0,
          'professorId': subjectMap['professorFirestoreId'] ?? '',
          'professorName': subjectMap['professorName'] ?? 'Non assigné',
        });
      }
      
      _assignedSubjects = _allSubjectsForClass.map((s) => s['name'] as String).toList();
    }
    
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('students')
        .where('className', isEqualTo: _homeroomClassName)
        .get();
    
    totalStudents = studentsSnapshot.docs.length;
  }
  
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _checkIfHomeroomTeacher();
      
      if (_isHomeroomTeacher && _homeroomClassId != null) {
        await _loadHomeroomData();
        
        _assignedClasses = [{
          'classFirestoreId': _homeroomClassId,
          'className': _homeroomClassName,
          'permissionType': 'full',
        }];
        
        if (_homeroomClassName != null) {
          _selectedClass = _homeroomClassName!;
        }
      } else {
        await _loadNormalData();
      }
      
      await _loadSchedules();
      await _loadProfessorStatus();
      
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
      _animationController.forward();
    }
  }
  
  Future<void> _loadNormalData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;
    
    final classesSnapshot = await FirebaseFirestore.instance
        .collection('classes')
        .get();
    
    final List<Map<String, dynamic>> tempClasses = [];
    final List<String> tempSubjects = [];
    
    for (var doc in classesSnapshot.docs) {
      final data = doc.data();
      final className = data['className'] ?? '';
      final subjects = data['subjects'] as List<dynamic>? ?? [];
      final classId = doc.id;
      
      if (className.isNotEmpty && subjects.isNotEmpty) {
        List<String> classSubjects = [];
        
        for (var subject in subjects) {
          final subjectMap = subject as Map<String, dynamic>;
          final subjectName = subjectMap['name'] ?? '';
          final professorId = subjectMap['professorFirestoreId'] ?? '';
          
          if (professorId == widget.professorFirestoreId && subjectName.isNotEmpty) {
            classSubjects.add(subjectName);
            if (!tempSubjects.contains(subjectName)) {
              tempSubjects.add(subjectName);
            }
          }
        }
        
        if (classSubjects.isNotEmpty) {
          tempClasses.add({
            'classFirestoreId': classId,
            'className': className,
            'subjects': classSubjects,
            'permissionType': 'full',
          });
        }
      }
    }
    
    _assignedClasses = tempClasses.map((c) => ({
      'classFirestoreId': c['classFirestoreId'],
      'className': c['className'],
      'permissionType': c['permissionType'],
    })).toList();
    
    _assignedSubjects = tempSubjects;
    
    totalStudents = 0;
    for (var cls in _assignedClasses) {
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('className', isEqualTo: cls['className'])
          .get();
      totalStudents += studentsSnapshot.docs.length;
    }
  }
  
  Future<void> _loadSchedules() async {
    final schedulesSnapshot = await FirebaseFirestore.instance
        .collection('schedules')
        .where('professorFirestoreId', isEqualTo: widget.professorFirestoreId)
        .get();
    
    _schedules = [];
    for (var doc in schedulesSnapshot.docs) {
      final data = doc.data();
      if (data == null) continue;
      
      _schedules.add({
        'id': doc.id,
        'className': data['className'] ?? '',
        'subject': data['subject'] ?? '',
        'dayOfWeek': data['dayOfWeek'] ?? '',
        'startTime': data['startTime'] ?? '',
        'endTime': data['endTime'] ?? '',
        'room': data['room'] ?? '',
      });
    }
    
    final now = DateTime.now();
    final today = _getDayOfWeek(now.weekday);
    nextClassCount = _schedules.where((s) => s['dayOfWeek'] == today).length;
  }
  
  Future<void> _loadProfessorStatus() async {
    final professorDoc = await FirebaseFirestore.instance
        .collection('professors')
        .doc(widget.professorFirestoreId)
        .get();
    
    if (professorDoc.exists) {
      final data = professorDoc.data();
      _status = data?['status'] == 'active' ? 'Actif' : 'Inactif';
    }
  }
  
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: _AppColors.textMuted),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
        await firebase_auth.FirebaseAuth.instance.signOut();
        if (mounted) Navigator.pop(context);
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      } catch (e) {
        if (mounted) Navigator.pop(context);
        _showSnackBar('Erreur: $e', _AppColors.danger);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  String _getDayOfWeek(int weekday) {
    const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    return days[weekday - 1];
  }
  
  List<String> _getClassNames() {
    return _assignedClasses.map((c) => c['className'] as String).toList();
  }
  
  List<Map<String, dynamic>> _getUpcomingSchedules() {
    final now = DateTime.now();
    final currentHour = now.hour + now.minute / 60;
    final today = _getDayOfWeek(now.weekday);
    
    final todaySchedules = _schedules.where((s) {
      if (s['dayOfWeek'] != today) return false;
      final startHour = _timeToDouble(s['startTime']);
      return startHour >= currentHour;
    }).toList();
    
    todaySchedules.sort((a, b) => _timeToDouble(a['startTime']).compareTo(_timeToDouble(b['startTime'])));
    return todaySchedules;
  }
  
  double _timeToDouble(String time) {
    if (time.isEmpty) return 0;
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return hour + minute / 60;
    } catch (e) {
      return 0;
    }
  }
  
  String _formatTime(String time) {
    if (time.isEmpty) return '--:--';
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts[1];
      return '${hour.toString().padLeft(2, '0')}:$minute';
    } catch (e) {
      return time;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _dashboardHome(),
      TeacherAttendanceScreen(
        teacherName: widget.professorName,
        professorFirestoreId: widget.professorFirestoreId,
        assignedClasses: _getClassNames(),
        assignedSubjects: _assignedSubjects,
      ),
      TeacherGradesScreen(
        teacherName: widget.professorName,
        professorFirestoreId: widget.professorFirestoreId,
        assignedClasses: _getClassNames(),
        assignedSubjects: _assignedSubjects,
      ),
      TeacherStudentsScreen(
        assignedClasses: _getClassNames(),
      ),
      TeacherScheduleScreen(
        teacherName: widget.professorName,
        professorFirestoreId: widget.professorFirestoreId,
        assignedClasses: _getClassNames(),
      ),
      TeacherReportsScreen(
        teacherName: widget.professorName,
        professorFirestoreId: widget.professorFirestoreId,
        assignedClasses: _getClassNames(),
        assignedSubjects: _assignedSubjects,
        isHomeroomTeacher: _isHomeroomTeacher,
        homeroomClassId: _homeroomClassId,
        homeroomClassName: _homeroomClassName,
      ),
      const TeacherAnnouncementsScreen(), // ✅ NOUVEAU : Page des annonces
    ];

    final primaryColor = _isHomeroomTeacher ? _AppColors.purple : _AppColors.success;

    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          titles[selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19, letterSpacing: 0.2),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.message_rounded),
                tooltip: "Messages",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TeacherMessagesScreen(
                      professorFirestoreId: widget.professorFirestoreId,
                      professorName: widget.professorName,
                      assignedClasses: _getClassNames(),
                      assignedSubjects: _assignedSubjects,
                    )),
                  ).then((_) => _loadUnreadMessagesCount());
                },
              ),
              if (totalUnreadMessages > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: _AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                    child: Text(
                      totalUnreadMessages > 9 ? '9+' : '$totalUnreadMessages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Actualiser",
            onPressed: () async {
              await _loadDashboardData();
              await _loadUnreadMessagesCount();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: "Déconnexion",
            onPressed: _logout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_AppColors.primary),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _AppColors.danger.withOpacity(0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.error_outline_rounded, size: 56, color: _AppColors.danger.withOpacity(0.4)),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 14, color: _AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadDashboardData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : FadeTransition(
                  opacity: _animationController,
                  child: pages[selectedIndex],
                ),
    );
  }
  
  Widget _buildDrawer() {
    final primaryColor = _isHomeroomTeacher ? _AppColors.purple : _AppColors.success;
    
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: DrawerHeader(
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.transparent))),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.professorName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _status == 'Actif' ? "Professeur • Actif" : "Professeur • Inactif",
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_isHomeroomTeacher && _homeroomClassName != null)
                    const SizedBox(height: 6),
                  if (_isHomeroomTeacher && _homeroomClassName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text("Titulaire - $_homeroomClassName", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _drawerItem(Icons.dashboard_rounded, "Dashboard", 0, primaryColor),
          _drawerItem(Icons.check_circle_rounded, "Présences", 1, primaryColor),
          _drawerItem(Icons.grade_rounded, "Notes", 2, primaryColor),
          _drawerItem(Icons.school_rounded, "Mes Élèves", 3, primaryColor),
          _drawerItem(Icons.calendar_today_rounded, "Emploi du temps", 4, primaryColor),
          _drawerItem(Icons.description_rounded, "Rapports", 5, primaryColor),
          _drawerItem(Icons.campaign_rounded, "Annonces", 6, primaryColor), // ✅ NOUVEAU
          const Divider(height: 24, thickness: 1),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text("GESTION", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _AppColors.textMuted)),
          ),
          _drawerItem(Icons.quiz_rounded, "Créer épreuve", -2, primaryColor),
          _drawerItem(Icons.assignment_rounded, "Mes examens", -4, primaryColor),
          _drawerItem(Icons.menu_book_rounded, "Gérer les cours", -3, primaryColor),
          _buildMessagesDrawerItem(primaryColor),
          const Divider(height: 24, thickness: 1),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.logout_rounded, color: _AppColors.danger),
              title: const Text("Déconnexion", style: TextStyle(color: _AppColors.danger, fontWeight: FontWeight.w600)),
              onTap: _logout,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMessagesDrawerItem(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.message_rounded, color: Colors.grey[700], size: 22),
            if (totalUnreadMessages > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: _AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                  child: Text(
                    totalUnreadMessages > 9 ? '9+' : '$totalUnreadMessages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: const Text("Messages", style: TextStyle(fontWeight: FontWeight.w500)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TeacherMessagesScreen(
              professorFirestoreId: widget.professorFirestoreId,
              professorName: widget.professorName,
              assignedClasses: _getClassNames(),
              assignedSubjects: _assignedSubjects,
            )),
          ).then((_) => _loadUnreadMessagesCount());
          Navigator.pop(context);
        },
      ),
    );
  }
  
  Widget _drawerItem(IconData icon, String title, int index, Color primaryColor) {
    final bool isSelected = selectedIndex == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? primaryColor.withOpacity(0.08) : Colors.transparent,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: isSelected ? primaryColor : Colors.grey[700], size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? primaryColor : _AppColors.textDark,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        selected: isSelected,
        selectedTileColor: primaryColor.withOpacity(0.08),
        onTap: () {
          // Fermer le drawer d'abord
          Navigator.pop(context);
          
          // Puis naviguer ou changer d'index
          if (index == -2) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => CreateExamScreen(
              professorFirestoreId: widget.professorFirestoreId,
              professorName: widget.professorName,
            )));
          } else if (index == -3) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ManageCoursesScreen(
              professorFirestoreId: widget.professorFirestoreId,
              professorName: widget.professorName,
            )));
          } else if (index == -4) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ManageExamsScreen(
              professorFirestoreId: widget.professorFirestoreId,
              professorName: widget.professorName,
            )));
          } else if (index >= 0) {
            setState(() => selectedIndex = index);
          }
        },
      ),
    );
  }

  Widget _dashboardHome() {
    final upcomingSchedules = _getUpcomingSchedules();
    final primaryColor = _isHomeroomTeacher ? _AppColors.purple : _AppColors.success;
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bandeau de bienvenue
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bonjour, ${widget.professorName}",
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _status,
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ),
                          if (_isHomeroomTeacher && _homeroomClassName != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text("Titulaire - $_homeroomClassName", style: const TextStyle(color: Colors.white, fontSize: 11)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Titre section statistiques
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Statistiques",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _AppColors.textDark),
              ),
            ],
          ),
          const SizedBox(height: 16),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _statCard("Élèves", totalStudents, Icons.people_alt_rounded, primaryColor),
              _statCard("Classes", _assignedClasses.length, Icons.class_rounded, primaryColor),
              _statCard("Matières", _assignedSubjects.length, Icons.book_rounded, primaryColor),
              _statCard("Cours aujourd'hui", nextClassCount, Icons.schedule_rounded, primaryColor),
            ],
          ),
          const SizedBox(height: 24),

          // Titre section cours à venir
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Cours à venir",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _AppColors.textDark),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _AppColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: upcomingSchedules.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.event_busy_rounded, size: 48, color: _AppColors.textMuted.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text(
                          "Aucun cours prévu aujourd'hui",
                          style: TextStyle(fontSize: 14, color: _AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      ...upcomingSchedules.take(3).map((schedule) => _buildScheduleCard(schedule, primaryColor)),
                      if (upcomingSchedules.length > 3)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: TextButton.icon(
                            onPressed: () => setState(() => selectedIndex = 4),
                            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                            label: Text("+ ${upcomingSchedules.length - 3} autres cours"),
                            style: TextButton.styleFrom(foregroundColor: primaryColor),
                          ),
                        ),
                    ],
                  ),
          ),

          const SizedBox(height: 24),

          // Titre section accès rapides
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Accès rapides",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _AppColors.textDark),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _quickAccessCard(
            icon: Icons.check_circle_rounded,
            iconColor: primaryColor,
            title: "Présences",
            subtitle: "Gérer les présences des élèves",
            onTap: () => setState(() => selectedIndex = 1),
          ),
          const SizedBox(height: 12),

          _quickAccessCard(
            icon: Icons.grade_rounded,
            iconColor: primaryColor,
            title: "Notes & Évaluations",
            subtitle: "Saisir et consulter les notes",
            onTap: () => setState(() => selectedIndex = 2),
          ),
          const SizedBox(height: 12),

          _quickAccessCard(
            icon: Icons.school_rounded,
            iconColor: primaryColor,
            title: "Mes Élèves",
            subtitle: "Consulter la liste des élèves",
            onTap: () => setState(() => selectedIndex = 3),
          ),
          const SizedBox(height: 12),

          _quickAccessCard(
            icon: Icons.calendar_today_rounded,
            iconColor: primaryColor,
            title: "Emploi du temps",
            subtitle: "Voir mon planning",
            onTap: () => setState(() => selectedIndex = 4),
          ),
          const SizedBox(height: 12),

          _quickAccessCard(
            icon: Icons.description_rounded,
            iconColor: primaryColor,
            title: "Rapports & Bulletins",
            subtitle: "Générer les rapports",
            onTap: () => setState(() => selectedIndex = 5),
          ),
          const SizedBox(height: 12),

          // ✅ NOUVEAU : Accès rapide aux annonces
          _quickAccessCard(
            icon: Icons.campaign_rounded,
            iconColor: primaryColor,
            title: "Annonces",
            subtitle: "Consulter les annonces de l'école",
            onTap: () => setState(() => selectedIndex = 6),
          ),
        ],
      ),
    );
  }

  Widget _quickAccessCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _AppColors.textDark),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12.5, color: _AppColors.textMuted, height: 1.3),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primaryColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.class_rounded, color: primaryColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule['subject'],
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _AppColors.textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  schedule['className'],
                  style: TextStyle(fontSize: 11, color: _AppColors.textMuted),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 12, color: _AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatTime(schedule['startTime'])} - ${_formatTime(schedule['endTime'])}',
                      style: TextStyle(fontSize: 10, color: _AppColors.textMuted),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.location_on_rounded, size: 12, color: _AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      schedule['room'] ?? 'Salle',
                      style: TextStyle(fontSize: 10, color: _AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _statCard(String title, int count, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 26, color: color),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: count.toDouble()),
            duration: const Duration(milliseconds: 600),
            builder: (context, value, child) => Text(
              value.toInt().toString(),
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: _AppColors.textMuted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
// lib/screens/teacher/teacher_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart';
import 'teacher_attendance.dart';
import 'teacher_grades.dart';
import 'teacher_students.dart';
import 'teacher_schedule.dart';
import 'teacher_reports.dart';
import '../admin/professor_permissions.dart';
import 'create_exam_screen.dart';
import 'manage_exams_screen.dart';
import 'create_course_screen.dart';
import 'manage_courses_screen.dart';
import 'teacher_messages_screen.dart';


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
  
  // Données dynamiques
  List<Map<String, dynamic>> _assignedClasses = [];
  List<Map<String, dynamic>> _schedules = [];
  List<String> _assignedSubjects = [];
  
  // Statistiques
  int totalStudents = 0;
  int nextClassCount = 0;
  String _status = 'Actif';
  bool _isLoading = true;
  String? _errorMessage;
  
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadDashboardData();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  /// 🔥 Charger toutes les données depuis Firestore
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║     DÉBUT CHARGEMENT DASHBOARD PROFESSEUR                  ║');
    print('╚════════════════════════════════════════════════════════════╝\n');
    print('📌 ID Professeur: ${widget.professorFirestoreId}');
    print('📌 Nom Professeur: ${widget.professorName}\n');
    
    try {
      // ==================== 1. CHARGER LES CLASSES ET MATIÈRES ====================
      print('🔍 [1/4] Chargement des classes et matières depuis Firestore...');
      
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .get();
      
      print('   📊 ${classesSnapshot.docs.length} classe(s) trouvée(s)\n');
      
      final List<Map<String, dynamic>> tempClasses = [];
      final List<String> tempSubjects = [];
      
      for (var doc in classesSnapshot.docs) {
        final data = doc.data();
        final className = data['className'] ?? '';
        final subjects = data['subjects'] as List<dynamic>? ?? [];
        final classId = doc.id;
        
        print('   📚 Classe: $className');
        print('      - Matières dans la classe: ${subjects.length}');
        
        if (className.isNotEmpty && subjects.isNotEmpty) {
          List<String> classSubjects = [];
          
          for (var subject in subjects) {
            final subjectMap = subject as Map<String, dynamic>;
            final subjectName = subjectMap['name'] ?? '';
            final professorId = subjectMap['professorFirestoreId'] ?? '';
            
            print('         📖 Matière: $subjectName');
            print('            - Professeur assigné: $professorId');
            print('            - Professeur actuel: ${widget.professorFirestoreId}');
            
            if (professorId == widget.professorFirestoreId && subjectName.isNotEmpty) {
              classSubjects.add(subjectName);
              if (!tempSubjects.contains(subjectName)) {
                tempSubjects.add(subjectName);
              }
              print('            ✅ AJOUTÉE');
            } else {
              print('            ⏭️ IGNORÉE');
            }
          }
          
          if (classSubjects.isNotEmpty) {
            tempClasses.add({
              'classFirestoreId': classId,
              'className': className,
              'subjects': classSubjects,
              'permissionType': 'full',
            });
            print('      ✅ ${classSubjects.length} matière(s) autorisée(s)');
          } else {
            print('      ⚠️ Aucune matière assignée à ce professeur');
          }
        }
        print('');
      }
      
      _assignedClasses = tempClasses.map((c) => ({
        'classFirestoreId': c['classFirestoreId'],
        'className': c['className'],
        'permissionType': c['permissionType'],
      })).toList();
      
      _assignedSubjects = tempSubjects;
      
      print('   ✅ Total classes: ${_assignedClasses.length}');
      print('   ✅ Total matières uniques: ${_assignedSubjects.length}\n');
      
      // ==================== 2. HORAIRES ====================
      print('🔍 [2/4] Recherche des horaires...');
      
      final schedulesSnapshot = await FirebaseFirestore.instance
          .collection('schedules')
          .where('professorFirestoreId', isEqualTo: widget.professorFirestoreId)
          .get();
      
      print('   📊 ${schedulesSnapshot.docs.length} horaire(s) trouvé(s)');
      
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
      print('   ✅ Total horaires: ${_schedules.length}\n');
      
      // ==================== 3. ÉTUDIANTS ====================
      print('🔍 [3/4] Comptage des étudiants...');
      totalStudents = 0;
      
      for (var cls in _assignedClasses) {
        final className = cls['className'];
        print('   → Classe: $className');
        
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('students')
            .where('className', isEqualTo: className)
            .get();
        
        print('      📊 ${studentsSnapshot.docs.length} étudiant(s)');
        totalStudents += studentsSnapshot.docs.length;
      }
      print('   ✅ Total étudiants: $totalStudents\n');
      
      // ==================== 4. STATUT ET COURS ====================
      print('🔍 [4/4] Récupération du statut et cours du jour...');
      
      final now = DateTime.now();
      final today = _getDayOfWeek(now.weekday);
      nextClassCount = _schedules.where((s) => s['dayOfWeek'] == today).length;
      print('   📅 Aujourd\'hui: $today - ${nextClassCount} cours');
      
      final professorDoc = await FirebaseFirestore.instance
          .collection('professors')
          .doc(widget.professorFirestoreId)
          .get();
      
      if (professorDoc.exists) {
        final data = professorDoc.data();
        _status = data?['status'] == 'active' ? 'Actif' : 'Inactif';
        print('   ✅ Statut: $_status');
      } else {
        print('   ⚠️ Document professeur non trouvé');
      }
      
      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║                    RÉSUMÉ FINAL                            ║');
      print('╠════════════════════════════════════════════════════════════╣');
      print('║   Classes: ${_assignedClasses.length.toString().padLeft(28)}              ║');
      for (var cls in _assignedClasses) {
        print('║      - ${cls['className']}');
      }
      print('║   Matières: ${_assignedSubjects.length.toString().padLeft(26)}              ║');
      for (var subject in _assignedSubjects) {
        print('║      - $subject');
      }
      print('║   Horaires: ${_schedules.length.toString().padLeft(26)}              ║');
      print('║   Étudiants: $totalStudents'.padRight(46) + '║');
      print('║   Cours aujourd\'hui: $nextClassCount'.padRight(41) + '║');
      print('║   Statut: $_status'.padRight(42) + '║');
      print('╚════════════════════════════════════════════════════════════╝\n');
      
      if (_assignedClasses.isEmpty) {
        print('⚠️⚠️⚠️ ALERTE: Aucune classe/matière assignée !');
      }
      
    } catch (e, stackTrace) {
      print('❌ ERREUR: $e');
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
      _animationController.forward();
    }
  }
  
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
        await FirebaseAuth.instance.signOut();
        if (mounted) Navigator.pop(context);
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      } catch (e) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
  
  final List<String> titles = [
    "Tableau de Bord",
    "Présences",
    "Notes & Évaluations",
    "Mes Élèves",
    "Emploi du Temps",
    "Rapports & Bulletins",
  ];

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
      ),
      TeacherReportsScreen(
        teacherName: widget.professorName,
        assignedClasses: _getClassNames(),
        assignedSubjects: _assignedSubjects,
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          titles[selectedIndex],
          style: const TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))),
                  SizedBox(height: 16),
                  Text('Chargement du tableau de bord...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDashboardData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
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
    return Drawer(
      elevation: 0,
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0F766E),
                    const Color(0xFF14B8A6),
                  ],
                ),
              ),
              child: UserAccountsDrawerHeader(
                accountName: Text(
                  widget.professorName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                accountEmail: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _status == 'Actif' 
                        ? Colors.green[400]?.withOpacity(0.3)
                        : Colors.red[400]?.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Professeur • $_status",
                    style: TextStyle(
                      fontSize: 13,
                      color: _status == 'Actif' ? Colors.green[100] : Colors.red[100],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                currentAccountPicture: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Color(0xFF0F766E), size: 32),
                  ),
                ),
                decoration: const BoxDecoration(color: Colors.transparent),
              ),
            ),
            const SizedBox(height: 8),
            _drawerItem(Icons.dashboard_outlined, "Dashboard", 0),
            _drawerItem(Icons.check_circle_outline, "Présences", 1),
            _drawerItem(Icons.grade_outlined, "Notes", 2),
            _drawerItem(Icons.school_outlined, "Mes Élèves", 3),
            _drawerItem(Icons.calendar_today_outlined, "Emploi du temps", 4),
            _drawerItem(Icons.description_outlined, "Rapports", 5),
            const Divider(height: 24, thickness: 1),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "GESTION",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            _drawerItem(Icons.lock_outline, "Gérer permissions", -1, isManagement: true),
            _drawerItem(Icons.quiz_outlined, "Créer épreuve", -2, isManagement: true),
            _drawerItem(Icons.assignment, "Mes examens", -4, isManagement: true),  // ← NOUVEAU
            _drawerItem(Icons.menu_book_outlined, "Gérer les cours", -3, isManagement: true),
            _drawerItem(Icons.message_outlined, "Messages", -5, isManagement: true),
            const Divider(height: 24, thickness: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.logout, color: Colors.red[400], size: 20),
              ),
              title: const Text(
                "Déconnexion",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _drawerItem(IconData icon, String title, int index, {bool isManagement = false}) {
    final isSelected = selectedIndex == index;
    
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF0F766E).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFF0F766E) : Colors.grey[600],
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFF0F766E) : Colors.grey[800],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFF0F766E).withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () {
        if (index == -1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfessorPermissionsScreen(
                professorFirestoreId: widget.professorFirestoreId,
                professorName: widget.professorName,
              ),
            ),
          );
        } else if (index == -2) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateExamScreen(
                professorFirestoreId: widget.professorFirestoreId,
                professorName: widget.professorName,
              ),
            ),
          );
        } else if (index == -3) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ManageCoursesScreen(
                professorFirestoreId: widget.professorFirestoreId,
                professorName: widget.professorName,
              ),
            ),
          );
        } else if (index == -4) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ManageExamsScreen(
                professorFirestoreId: widget.professorFirestoreId,
                professorName: widget.professorName,
              ),
            ),
          );
        } else if (index == -5) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeacherMessagesScreen(
                professorFirestoreId: widget.professorFirestoreId,
                professorName: widget.professorName,
                assignedClasses: _getClassNames(),     // ← Ajoutez ceci
                assignedSubjects: _assignedSubjects,
              ),
            ),
          );
        } else {
          setState(() => selectedIndex = index);
        }
        Navigator.pop(context);
      },
    );
  }
  
  Widget _dashboardHome() {
    final upcomingSchedules = _getUpcomingSchedules();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeTransition(
            opacity: _animationController,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0F766E),
                    const Color(0xFF14B8A6),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F766E).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 35, color: Color(0xFF0F766E)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Bonjour, ${widget.professorName}",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _status == 'Actif' ? Icons.circle : Icons.circle_outlined,
                                size: 8,
                                color: _status == 'Actif' ? Colors.green[300] : Colors.red[300],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _status,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
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
          ),
          
          const SizedBox(height: 24),
          
          FadeTransition(
            opacity: _animationController,
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _statCard("Élèves", totalStudents, Icons.people_outline, const Color(0xFF3B82F6)),
                _statCard("Classes", _assignedClasses.length, Icons.school, const Color(0xFF10B981)),
                _statCard("Matières", _assignedSubjects.length, Icons.book, const Color(0xFFF59E0B)),
                _statCard("Cours aujourd'hui", nextClassCount, Icons.schedule_outlined, const Color(0xFF8B5CF6)),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          FadeTransition(
            opacity: _animationController,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.schedule, color: Color(0xFF10B981), size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Cours à venir",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        if (upcomingSchedules.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${upcomingSchedules.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  if (upcomingSchedules.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(Icons.event_busy, size: 56, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            "Aucun cours prévu aujourd'hui",
                            style: TextStyle(color: Colors.grey[500], fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  else
                    ...upcomingSchedules.take(3).map((schedule) {
                      return _nextClassItem(
                        schedule['subject'],
                        '${_formatTime(schedule['startTime'])} - ${_formatTime(schedule['endTime'])}',
                        schedule['room'] ?? 'Salle non spécifiée',
                        schedule['className'],
                      );
                    }),
                  
                  if (upcomingSchedules.length > 3)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.grey[200]!)),
                      ),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() => selectedIndex = 4);
                          },
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: Text("+ ${upcomingSchedules.length - 3} autres cours"),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF0F766E),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          FadeTransition(
            opacity: _animationController,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.school, color: Color(0xFF3B82F6), size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Mes classes",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_assignedClasses.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: _assignedClasses.isEmpty
                        ? Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange[600]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Vous n'avez pas encore de classes assignées.\nContactez l'administrateur.",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            ],
                          )
                        : Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _assignedClasses.map((cls) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.class_, size: 16, color: Color(0xFF3B82F6)),
                                    const SizedBox(width: 8),
                                    Text(
                                      cls['className'],
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          FadeTransition(
            opacity: _animationController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    "Actions rapides",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _quickAction("Présences", Icons.check_circle_outline, 1),
                    _quickAction("Notes", Icons.grade_outlined, 2),
                    _quickAction("Élèves", Icons.school, 3),
                    _quickAction("Emploi du temps", Icons.calendar_today_outlined, 4),
                    _quickAction("Rapport", Icons.picture_as_pdf_outlined, 5),
                    _quickAction("Permissions", Icons.lock_outline, -1),
                    _quickAction("Créer examen", Icons.quiz_outlined, -2),
                    _quickAction("Mes examens", Icons.assignment, -4),  // ← NOUVEAU
                    _quickAction("Cours", Icons.menu_book_outlined, -3),
                    _quickAction("Messages", Icons.message_outlined, -5),
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
    return SizedBox(
      width: 160,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: count.toDouble()),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: -0.5,
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _nextClassItem(String subject, String time, String room, String className) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F766E).withOpacity(0.05),
            const Color(0xFF0F766E).withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0F766E).withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.class_, color: Color(0xFF0F766E), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  className,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      room,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF0F766E)),
          ),
        ],
      ),
    );
  }
  
  Widget _quickAction(String title, IconData icon, int pageIndex) {
    return GestureDetector(
      onTap: () {
        if (pageIndex == -1) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfessorPermissionsScreen(
                professorFirestoreId: widget.professorFirestoreId,
                professorName: widget.professorName,
              ),
            ),
          );
        } else if (pageIndex == -2) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateExamScreen(
                professorFirestoreId: widget.professorFirestoreId,
                professorName: widget.professorName,
              ),
            ),
          );
        } else if (pageIndex == -3) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ManageCoursesScreen(
                professorFirestoreId: widget.professorFirestoreId,
                professorName: widget.professorName,
              ),
            ),
          );
        } else if (pageIndex == -4) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ManageExamsScreen(
                professorFirestoreId: widget.professorFirestoreId,
                professorName: widget.professorName,
              ),
            ),
          );
        } else if (pageIndex == -5) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeacherMessagesScreen(
                professorFirestoreId: widget.professorFirestoreId,
                professorName: widget.professorName,
                  assignedClasses: _getClassNames(),     // ← Ajoutez ceci
                assignedSubjects: _assignedSubjects,
              ),
            ),
          );
        } else {
          setState(() => selectedIndex = pageIndex);
        }
      },
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0F766E).withOpacity(0.15),
                    const Color(0xFF0F766E).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: const Color(0xFF0F766E)),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
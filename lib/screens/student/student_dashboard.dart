// lib/screens/student/student_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../login_screen.dart';
import 'student_profile.dart';
import 'student_grades.dart';
import 'student_attendance.dart';
import 'student_schedule.dart';
import 'student_documents.dart';
import 'student_payments.dart';
import 'student_courses.dart';
import 'student_exams.dart';
import 'student_messages_screen.dart';  // ← AJOUTÉ

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _selectedIndex = 0;
  bool _isLoadingStats = true;
  
  // Statistiques réelles
  double _overallAverage = 0;
  double _attendanceRate = 0;
  int _documentsCount = 0;
  int _pendingPaymentsCount = 0;
  String _studentName = '';
  String _studentClassName = '';
  String _studentFirestoreId = '';
  
  late List<Widget> _pages;
  late List<Map<String, dynamic>> _menuItems;

  @override
  void initState() {
    super.initState();
    _menuItems = [
      {'title': 'Accueil', 'icon': Icons.dashboard, 'color': const Color(0xFF3B82F6)},
      {'title': 'Mes notes', 'icon': Icons.grade, 'color': const Color(0xFF10B981)},
      {'title': 'Mes présences', 'icon': Icons.calendar_today, 'color': const Color(0xFFF59E0B)},
      {'title': 'Emploi du temps', 'icon': Icons.schedule, 'color': const Color(0xFF8B5CF6)},
      {'title': 'Documents', 'icon': Icons.folder, 'color': const Color(0xFF14B8A6)},
      {'title': 'Paiements', 'icon': Icons.payment, 'color': const Color(0xFFEF4444)},
      {'title': 'Messages', 'icon': Icons.message, 'color': const Color(0xFF10B981)},  // ← AJOUTÉ
      {'title': 'Mon profil', 'icon': Icons.person, 'color': const Color(0xFF6366F1)},
      {'title': 'Épreuves', 'icon': Icons.quiz, 'color': const Color(0xFFF97316)},
      {'title': 'Cours', 'icon': Icons.menu_book, 'color': const Color(0xFF0F766E)},
    ];
    
    _pages = [
      const SizedBox(),
      const StudentGradesScreen(),
      const StudentAttendanceScreen(),
      const StudentScheduleScreen(),
      const StudentDocumentsScreen(),
      const StudentPaymentsScreen(),
      const StudentMessagesScreen(),  // ← AJOUTÉ
      const StudentProfileScreen(),
      const StudentExamsScreen(),
      const StudentCoursesScreen(),
    ];
    
    _loadRealStatsFromFirestore();
  }

  /// 🔥 Charger les statistiques depuis Firestore
  Future<void> _loadRealStatsFromFirestore() async {
    setState(() => _isLoadingStats = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id;
      final userEmail = authProvider.user?.email;
      
      if (userId != null || userEmail != null) {
        // Récupérer l'étudiant via son compte utilisateur
        Query studentQuery = FirebaseFirestore.instance.collection('students');
        
        if (userEmail != null) {
          studentQuery = studentQuery.where('userEmail', isEqualTo: userEmail);
        } else {
          studentQuery = studentQuery.where('userId', isEqualTo: userId);
        }
        
        final studentSnapshot = await studentQuery.limit(1).get();
        
        if (studentSnapshot.docs.isNotEmpty) {
          final studentData = studentSnapshot.docs.first.data() as Map<String, dynamic>;
          _studentFirestoreId = studentSnapshot.docs.first.id;
          _studentName = studentData['fullName'] ?? '';
          _studentClassName = studentData['className'] ?? '';
          
          print('✅ Étudiant chargé: $_studentName (ID: $_studentFirestoreId)');
          
          // Charger les notes
          final gradesSnapshot = await FirebaseFirestore.instance
              .collection('grades')
              .where('studentName', isEqualTo: _studentName)
              .get();
          
          final grades = gradesSnapshot.docs;
          if (grades.isNotEmpty) {
            double totalWeighted = 0;
            double totalCoef = 0;
            for (var doc in grades) {
              final data = doc.data() as Map<String, dynamic>;
              final score = (data['score'] as num?)?.toDouble() ?? 0;
              final maxScore = (data['maxScore'] as num?)?.toDouble() ?? 20;
              final coefficient = (data['coefficient'] as num?)?.toDouble() ?? 1;
              totalWeighted += (score / maxScore * 20) * coefficient;
              totalCoef += coefficient;
            }
            _overallAverage = totalCoef > 0 ? (totalWeighted / totalCoef).roundToDouble() : 0;
          }
          
          // Charger les présences
          final attendancesSnapshot = await FirebaseFirestore.instance
              .collection('attendances')
              .where('studentName', isEqualTo: _studentName)
              .get();
          
          final attendances = attendancesSnapshot.docs;
          if (attendances.isNotEmpty) {
            final presentCount = attendances.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['status'] == 'present';
            }).length;
            _attendanceRate = (presentCount / attendances.length) * 100;
          }
          
          // Charger les documents
          final documentsSnapshot = await FirebaseFirestore.instance
              .collection('documents')
              .where('fullName', isEqualTo: _studentName)
              .get();
          _documentsCount = documentsSnapshot.docs.length;
          
          // Charger les paiements en attente
          final paymentsSnapshot = await FirebaseFirestore.instance
              .collection('payments')
              .where('fullName', isEqualTo: _studentName)
              .get();
          
          _pendingPaymentsCount = paymentsSnapshot.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final paymentDate = data['paymentDate'];
            return paymentDate == null;
          }).length;
          
          print('✅ Statistiques chargées: $_studentName, $_overallAverage, $_attendanceRate%');
        } else {
          print('⚠️ Aucun étudiant trouvé');
        }
      }
    } catch (e) {
      print('❌ Erreur chargement statistiques: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_menuItems[_selectedIndex]['title']),
        backgroundColor: _menuItems[_selectedIndex]['color'],
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: _selectedIndex == 0 ? _buildHomePage() : _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: _menuItems[_selectedIndex]['color'],
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: _menuItems.map((item) {
          return BottomNavigationBarItem(
            icon: Icon(item['icon']),
            label: item['title'],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHomePage() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return RefreshIndicator(
      
      onRefresh: _loadRealStatsFromFirestore,
      color: const Color(0xFF10B981),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte de bienvenue
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bonjour,',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _studentName.isNotEmpty ? _studentName : (authProvider.user?.name ?? 'Étudiant'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _studentClassName.isNotEmpty ? 'Classe: $_studentClassName' : 'Étudiant',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Aperçu rapide',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            if (_isLoadingStats)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
              )
            else
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildStatCard(
                    'Moyenne générale',
                    _overallAverage > 0 ? '${_overallAverage.toStringAsFixed(1)}/20' : 'N/A',
                    Icons.analytics,
                    const Color(0xFF10B981),
                  ),
                  _buildStatCard(
                    'Présences',
                    '${_attendanceRate.toStringAsFixed(0)}%',
                    Icons.check_circle,
                    const Color(0xFF3B82F6),
                  ),
                  _buildStatCard(
                    'Documents',
                    '$_documentsCount',
                    Icons.description,
                    const Color(0xFFF59E0B),
                  ),
                  _buildStatCard(
                    'Paiements',
                    '$_pendingPaymentsCount en attente',
                    Icons.payment,
                    const Color(0xFFEF4444),
                  ),
                ],
              ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Accès rapide',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _menuItems.length - 1,
              itemBuilder: (context, index) {
                final item = _menuItems[index + 1];
                return _buildMenuItem(
                  item['title'],
                  item['icon'],
                  item['color'],
                  () {
                    setState(() {
                      _selectedIndex = index + 1;
                    });
                  },
                );
              },
            ),
            
            const SizedBox(height: 20),
            
            // Dernières actualités
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      'Espace étudiant',
                      'Consultez vos notes, présences et documents',
                      Icons.school,
                      const Color(0xFF3B82F6),
                    ),
                    const Divider(),
                    _buildInfoItem(
                      'Messagerie',
                      'Échangez avec vos professeurs et vos parents',
                      Icons.message,
                      const Color(0xFF10B981),
                    ),
                    const Divider(),
                    _buildInfoItem(
                      'Ressources',
                      'Accédez aux cours en ligne et aux examens',
                      Icons.book,
                      const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String title, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }
}
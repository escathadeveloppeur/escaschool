// lib/screens/admin/admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../providers/auth_provider.dart';
import 'admin_users.dart';
import 'admin_classes.dart';
import 'admin_announcements.dart';
import 'admin_professors.dart';
import 'admin_schedule.dart';
import 'professor_permissions.dart';
import 'admin_messages_screen.dart';
import 'school_settings_screen.dart';
import 'add_class_screen.dart';
import 'manage_sections_screen.dart';
import 'package:ecole_app/models/class_model.dart';

// ===================== PALETTE / THEME HELPERS =====================
class _AppColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B5BDB);
  static const Color background = Color(0xFFF4F6FB);
  static const Color cardBorder = Color(0xFFE6E9F2);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final DBHelper db = DBHelper();
  int selectedIndex = 0;

  int totalUsers = 0;
  int totalClasses = 0;
  int totalAnnouncements = 0;
  int totalProfessors = 0;
  int totalStudents = 0;
  int totalUnreadMessages = 0;
  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardDataFromFirestore();
    _loadUnreadMessagesCount();
  }

  Future<void> _loadUnreadMessagesCount() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final adminFirestoreId = auth.user?.firestoreId;
    
    if (adminFirestoreId == null) return;
    
    try {
      final unreadMessages = await FirebaseFirestore.instance
          .collection('messages')
          .where('recipientId', isEqualTo: adminFirestoreId)
          .where('recipientRole', isEqualTo: 'admin')
          .where('read', isEqualTo: false)
          .get();
      
      setState(() {
        totalUnreadMessages = unreadMessages.docs.length;
      });
      
      print('📬 Messages non lus (admin): $totalUnreadMessages');
    } catch (e) {
      print('❌ Erreur chargement messages non lus: $e');
    }
  }

  Future<void> _loadDashboardDataFromFirestore() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;

    try {
      Query usersQuery = FirebaseFirestore.instance.collection('users');
      Query classesQuery = FirebaseFirestore.instance.collection('classes');
      Query professorsQuery = FirebaseFirestore.instance.collection('professors');
      
      if (!auth.isSuperAdmin && schoolId != null) {
        usersQuery = usersQuery.where('schoolId', isEqualTo: schoolId);
        classesQuery = classesQuery.where('schoolId', isEqualTo: schoolId);
        professorsQuery = professorsQuery.where('schoolId', isEqualTo: schoolId);
      }
      
      final usersSnapshot = await usersQuery.get();
      final classesSnapshot = await classesQuery.get();
      final professorsSnapshot = await professorsQuery.get();
      final announcementsSnapshot = await FirebaseFirestore.instance.collection('announcements').get();
      
      final students = usersSnapshot.docs.where((doc) => (doc.data() as Map<String, dynamic>)['role'] == 'student').length;
      setState(() {
        totalUsers = usersSnapshot.docs.length;
        totalClasses = classesSnapshot.docs.length;
        totalProfessors = professorsSnapshot.docs.length;
        totalStudents = students;
        totalAnnouncements = announcementsSnapshot.docs.length;
      });
      
      final history = await db.getAllLogs();
      setState(() {
        logs = history.reversed.toList();
      });
      
      print('✅ Dashboard chargé: $totalUsers utilisateurs, $totalClasses classes');
    } catch (e) {
      print('❌ Erreur chargement dashboard: $e');
      final users = await db.getAllUsers();
      final classes = await db.getAllClasses();
      final announcements = await db.getAllAnnouncements();
      final professors = await db.getAllProfessors();
      
      List<Map<String, dynamic>> filteredUsers = users;
      List<ClassModel> filteredClasses = classes;
      List<Map<String, dynamic>> filteredProfessors = professors;
      
      if (!auth.isSuperAdmin && schoolId != null) {
        filteredUsers = users.where((u) => u['schoolId'] == schoolId).toList();
        filteredClasses = classes.where((c) => c.schoolId == schoolId).toList();
        filteredProfessors = professors.where((p) => p['schoolId'] == schoolId).toList();
      }
      
      final students = filteredUsers.where((u) => u['role'] == 'student').length;
      final history = await db.getAllLogs();
      
      setState(() {
        totalUsers = filteredUsers.length;
        totalClasses = filteredClasses.length;
        totalAnnouncements = announcements.length;
        totalProfessors = filteredProfessors.length;
        totalStudents = students;
        logs = history.reversed.toList();
      });
    }
  }

  final List<String> titles = [
    "Dashboard Admin",
    "Utilisateurs",
    "Professeurs",
    "Classes",
    "Annonces",
    "Messages",
    "Paramètres",
    "Historique",
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    final pages = [
      _dashboardHome(),
      AdminUsers(onChanged: _loadDashboardDataFromFirestore),
      AdminProfessors(onChanged: _loadDashboardDataFromFirestore),
      AdminClasses(onChanged: _loadDashboardDataFromFirestore),
      AdminAnnouncements(onChanged: _loadDashboardDataFromFirestore),
      const AdminMessagesScreen(),
      const SchoolSettingsScreen(),
      _historyPage(),
    ];

    return Scaffold(
      backgroundColor: _AppColors.background,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: Text(
          titles[selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 19,
            letterSpacing: 0.2,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_AppColors.primary, _AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // Bouton pour ajouter une classe (accès rapide)
          if (selectedIndex == 3)
            IconButton(
              icon: const Icon(Icons.add_box_rounded),
              tooltip: "Ajouter une classe",
              onPressed: _navigateToAddClass,
            ),
          // Bouton pour gérer les sections
          if (selectedIndex == 3)
            IconButton(
              icon: const Icon(Icons.school_rounded),
              tooltip: "Gérer les sections",
              onPressed: _navigateToManageSections,
            ),
          // L'ID de l'école est SUPPRIMÉ - plus d'affichage
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.mail_outline_rounded),
                tooltip: "Messages",
                onPressed: () {
                  setState(() {
                    selectedIndex = 5;
                  });
                  _loadUnreadMessagesCount();
                },
              ),
              if (totalUnreadMessages > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      shape: BoxShape.circle,
                      border: Border.all(color: _AppColors.primary, width: 1.5),
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
              await _loadDashboardDataFromFirestore();
              await _loadUnreadMessagesCount();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        color: _AppColors.primary,
        onRefresh: () async {
          await _loadDashboardDataFromFirestore();
          await _loadUnreadMessagesCount();
        },
        child: pages[selectedIndex],
      ),
    );
  }

  void _navigateToAddClass() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddClassScreen()),
    ).then((_) {
      _loadDashboardDataFromFirestore();
    });
  }

  void _navigateToManageSections() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageSectionsScreen()),
    ).then((_) {
      _loadDashboardDataFromFirestore();
    });
  }

  Widget _buildDrawer() {
    final auth = Provider.of<AuthProvider>(context);
    
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_AppColors.primary, _AppColors.primaryLight],
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
                    child: const Icon(Icons.admin_panel_settings_rounded, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    auth.user?.name ?? "Admin Menu",
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      auth.isSuperAdmin ? "Super Administrateur" : "Administrateur",
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _drawerItem(Icons.dashboard_rounded, "Dashboard", 0),
          _drawerItem(Icons.people_rounded, "Utilisateurs", 1),
          _drawerItem(Icons.school_rounded, "Professeurs", 2),
          _drawerItem(Icons.class_rounded, "Classes", 3),
          if (selectedIndex == 3) ...[
            Padding(
              padding: const EdgeInsets.only(left: 28, right: 12),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: _AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: Icon(Icons.add_box_rounded, size: 19, color: _AppColors.primaryLight),
                      title: Text("Ajouter une classe", style: TextStyle(fontSize: 13, color: _AppColors.textDark)),
                      onTap: () {
                        Navigator.pop(context);
                        _navigateToAddClass();
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: _AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: Icon(Icons.school_rounded, size: 19, color: _AppColors.primaryLight),
                      title: Text("Gérer les sections", style: TextStyle(fontSize: 13, color: _AppColors.textDark)),
                      onTap: () {
                        Navigator.pop(context);
                        _navigateToManageSections();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
          _drawerItem(Icons.announcement_rounded, "Annonces", 4),
          _buildMessagesDrawerItem(),
          _drawerItem(Icons.settings_rounded, "Paramètres", 6),
          _drawerItem(Icons.history_rounded, "Historique", 7),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 24),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFE53935)),
              title: const Text("Déconnexion", style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pushReplacementNamed(context, '/login'),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMessagesDrawerItem() {
    final bool isSelected = selectedIndex == 5;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? _AppColors.primary.withOpacity(0.08) : Colors.transparent,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.mail_outline_rounded,
              color: isSelected ? _AppColors.primary : Colors.grey[700],
            ),
            if (totalUnreadMessages > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
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
        title: Text(
          "Messages",
          style: TextStyle(
            color: isSelected ? _AppColors.primary : _AppColors.textDark,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        selected: isSelected,
        selectedTileColor: _AppColors.primary.withOpacity(0.08),
        onTap: () {
          setState(() {
            selectedIndex = 5;
          });
          _loadUnreadMessagesCount();
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, int index) {
    final bool isSelected = selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? _AppColors.primary.withOpacity(0.08) : Colors.transparent,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: isSelected ? _AppColors.primary : Colors.grey[700]),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? _AppColors.primary : _AppColors.textDark,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        selected: isSelected,
        selectedTileColor: _AppColors.primary.withOpacity(0.08),
        onTap: () { setState(() => selectedIndex = index); Navigator.pop(context); },
      ),
    );
  }

  Widget _dashboardHome() {
    final auth = Provider.of<AuthProvider>(context);
    
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
                colors: [_AppColors.primary, _AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _AppColors.primary.withOpacity(0.25),
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
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bienvenue, ${auth.user?.name ?? 'Administrateur'}",
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        auth.isSuperAdmin ? "Gestion multi-écoles" : "Gestion de votre école",
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Titre section statistiques
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: _AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Statistiques",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _AppColors.textDark, letterSpacing: 0.2),
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
              _statCard("Utilisateurs", totalUsers, Icons.people_alt_rounded, const Color(0xFFF59E0B)),
              _statCard("Professeurs", totalProfessors, Icons.school_rounded, const Color(0xFF10B981)),
              _statCard("Étudiants", totalStudents, Icons.groups_rounded, const Color(0xFF3B82F6)),
              _statCard("Classes", totalClasses, Icons.class_rounded, const Color(0xFF8B5CF6)),
              _statCard("Annonces", totalAnnouncements, Icons.campaign_rounded, const Color(0xFFEF4444)),
              _statCardWithBadge("Messages", totalUnreadMessages, Icons.mail_rounded, const Color(0xFF14B8A6)),
            ],
          ),
          const SizedBox(height: 28),

          // Titre section accès rapides
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: _AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Accès rapides",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _AppColors.textDark, letterSpacing: 0.2),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _quickAccessCard(
            icon: Icons.class_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: "Gestion des classes",
            subtitle: "$totalClasses classe(s) • Ajouter, modifier ou supprimer",
            onTap: () {
              setState(() {
                selectedIndex = 3;
              });
            },
          ),
          const SizedBox(height: 12),

          _quickAccessCard(
            icon: Icons.school_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: "Sections / Options",
            subtitle: "Créer et gérer les sections (Littéraire, Scientifique, etc.)",
            onTap: _navigateToManageSections,
          ),
          const SizedBox(height: 12),

          _quickAccessCard(
            icon: Icons.settings_rounded,
            iconColor: const Color(0xFF3B82F6),
            title: "Paramètres du bulletin",
            subtitle: "Configurer les informations de l'école pour les bulletins",
            onTap: () {
              setState(() {
                selectedIndex = 6;
              });
            },
          ),
          const SizedBox(height: 12),

          _quickAccessCard(
            icon: Icons.mail_rounded,
            iconColor: const Color(0xFF14B8A6),
            title: "Messagerie",
            subtitle: "Consultez et répondez à vos messages",
            onTap: () {
              setState(() {
                selectedIndex = 5;
              });
              _loadUnreadMessagesCount();
            },
            trailing: totalUnreadMessages > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE53935).withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      "$totalUnreadMessages non lu${totalUnreadMessages > 1 ? 's' : ''}",
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  )
                : null,
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
    Widget? trailing,
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
                const SizedBox(width: 8),
                trailing ?? Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
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
          Text(
            count.toString(),
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _AppColors.textDark, letterSpacing: 0.3),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12.5, color: _AppColors.textMuted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _statCardWithBadge(String title, int badgeCount, IconData icon, Color color) {
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
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              selectedIndex = 5;
            });
            _loadUnreadMessagesCount();
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, size: 26, color: color),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                badgeCount > 0 ? "$badgeCount non lu${badgeCount > 1 ? 's' : ''}" : "0 message",
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: badgeCount > 0 ? const Color(0xFFE53935) : color),
              ),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(fontSize: 12.5, color: _AppColors.textMuted, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyPage() {
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _AppColors.primary.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_rounded, size: 56, color: _AppColors.primary.withOpacity(0.4)),
            ),
            const SizedBox(height: 20),
            Text(
              "Aucune action pour le moment",
              style: TextStyle(fontSize: 16, color: _AppColors.textMuted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.history_rounded, color: _AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Journal des actions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _AppColors.textDark)),
                        const SizedBox(height: 2),
                        Text("Total: ${logs.length} actions", style: TextStyle(color: _AppColors.textMuted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _clearHistory,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: const Text("Effacer"),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE53935),
                      backgroundColor: const Color(0xFFE53935).withOpacity(0.08),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: logs.length,
            itemBuilder: (_, i) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _AppColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getLogColor(logs[i]).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getLogIcon(logs[i]), size: 20, color: _getLogColor(logs[i])),
                  ),
                  title: Text(logs[i], style: TextStyle(fontSize: 13, color: _AppColors.textDark, fontWeight: FontWeight.w500)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text("Action #${logs.length - i}", style: TextStyle(fontSize: 11, color: _AppColors.textMuted)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirmation", style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text("Voulez-vous vraiment effacer tout l'historique ?"),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: _AppColors.textMuted),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Effacer"),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await db.clearLogs();
      await _loadDashboardDataFromFirestore();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Historique effacé"),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  Color _getLogColor(String log) {
    final l = log.toLowerCase();
    if (l.contains('ajout') || l.contains('cré')) return const Color(0xFF10B981);
    if (l.contains('supprim') || l.contains('effac')) return const Color(0xFFE53935);
    if (l.contains('modif') || l.contains('mis à jour')) return const Color(0xFFF59E0B);
    return _AppColors.primaryLight;
  }

  IconData _getLogIcon(String log) {
    final l = log.toLowerCase();
    if (l.contains('professeur')) return Icons.school_rounded;
    if (l.contains('utilisateur')) return Icons.person_rounded;
    if (l.contains('classe')) return Icons.class_rounded;
    if (l.contains('annonce')) return Icons.campaign_rounded;
    if (l.contains('section')) return Icons.school_rounded;
    return Icons.history_rounded;
  }
}
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
import 'admin_messages_screen.dart'; // ✅ Ajout de l'import des messages
import 'package:ecole_app/models/class_model.dart';

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
  int totalUnreadMessages = 0; // ✅ Ajout compteur messages non lus
  List<String> logs = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardDataFromFirestore();
    _loadUnreadMessagesCount(); // ✅ Charger les messages non lus
  }

  /// ✅ Charger le nombre de messages non lus pour l'admin
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

  /// 🔥 Charger les statistiques depuis Firestore
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
      
      // Charger les logs depuis Hive (local)
      final history = await db.getAllLogs();
      setState(() {
        logs = history.reversed.toList();
      });
      
      print('✅ Dashboard chargé: $totalUsers utilisateurs, $totalClasses classes');
    } catch (e) {
      print('❌ Erreur chargement dashboard: $e');
      // Fallback vers Hive
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
    "Messages", // ✅ Changé de "Historique" à "Messages"
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
      const AdminMessagesScreen(), // ✅ Ajout de l'écran des messages
      _historyPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[selectedIndex]),
        backgroundColor: Colors.blue[800],
        actions: [
          if (!auth.isSuperAdmin && auth.hasSchool)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Icon(Icons.business, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('École ID: ${auth.currentSchoolId}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                ],
              ),
            ),
          // ✅ Badge des messages non lus
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.message_outlined),
                tooltip: "Messages",
                onPressed: () {
                  setState(() {
                    selectedIndex = 5; // Aller à l'onglet Messages
                  });
                  _loadUnreadMessagesCount(); // Rafraîchir le compteur
                },
              ),
              if (totalUnreadMessages > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      totalUnreadMessages > 9 ? '9+' : '$totalUnreadMessages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () async {
            await _loadDashboardDataFromFirestore();
            await _loadUnreadMessagesCount();
          }),
        ],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadDashboardDataFromFirestore();
          await _loadUnreadMessagesCount();
        },
        child: pages[selectedIndex],
      ),
    );
  }

  Widget _buildDrawer() {
    final auth = Provider.of<AuthProvider>(context);
    
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue[800]!, Colors.blue[600]!])),
            child: DrawerHeader(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.admin_panel_settings, size: 48, color: Colors.white),
                  const SizedBox(height: 10),
                  Text(auth.user?.name ?? "Admin Menu", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(auth.isSuperAdmin ? "Super Administrateur" : "Administrateur", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
          _drawerItem(Icons.dashboard, "Dashboard", 0),
          _drawerItem(Icons.people, "Utilisateurs", 1),
          _drawerItem(Icons.school, "Professeurs", 2),
          _drawerItem(Icons.class_, "Classes", 3),
          _drawerItem(Icons.announcement, "Annonces", 4),
          _buildMessagesDrawerItem(), // ✅ Élément avec badge pour les messages
          _drawerItem(Icons.history, "Historique", 6),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Déconnexion"),
            onTap: () => Navigator.pushReplacementNamed(context, '/login'),
          ),
        ],
      ),
    );
  }

  /// ✅ Élément de menu pour les messages avec badge
  Widget _buildMessagesDrawerItem() {
    final bool isSelected = selectedIndex == 5;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? Colors.blue[50] : Colors.transparent,
      ),
      child: ListTile(
        leading: Stack(
          children: [
            Icon(
              Icons.message_outlined,
              color: isSelected ? Colors.blue[800] : Colors.grey[700],
            ),
            if (totalUnreadMessages > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
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
            color: isSelected ? Colors.blue[800] : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.blue[50],
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
    return ListTile(
      leading: Icon(icon, color: selectedIndex == index ? Colors.blue[800] : Colors.grey[700]),
      title: Text(title, style: TextStyle(color: selectedIndex == index ? Colors.blue[800] : Colors.black87)),
      selected: selectedIndex == index,
      selectedTileColor: Colors.blue[50],
      onTap: () { setState(() => selectedIndex = index); Navigator.pop(context); },
    );
  }

  Widget _dashboardHome() {
    final auth = Provider.of<AuthProvider>(context);
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(radius: 24, backgroundColor: Colors.blue[100], child: Icon(Icons.admin_panel_settings, color: Colors.blue[800])),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Bienvenue, ${auth.user?.name ?? 'Administrateur'}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                        Text(auth.isSuperAdmin ? "Gestion multi-écoles" : "Gestion de votre école", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text("Statistiques", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _statCard("Utilisateurs", totalUsers, Icons.people, Colors.orange),
              _statCard("Professeurs", totalProfessors, Icons.school, Colors.green),
              _statCard("Étudiants", totalStudents, Icons.people_outline, Colors.blue),
              _statCard("Classes", totalClasses, Icons.class_, Colors.purple),
              _statCard("Annonces", totalAnnouncements, Icons.announcement, Colors.red),
              // ✅ Carte d'accès rapide pour les messages avec badge
              _statCardWithBadge("Messages", totalUnreadMessages, Icons.message_outlined, Colors.teal),
            ],
          ),
          const SizedBox(height: 16),
          // ✅ Section d'accès rapide aux messages
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.teal[50],
            child: InkWell(
              onTap: () {
                setState(() {
                  selectedIndex = 5;
                });
                _loadUnreadMessagesCount();
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.message, color: Colors.teal[700], size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Messagerie",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Consultez et répondez à vos messages",
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    if (totalUnreadMessages > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "$totalUnreadMessages non lu${totalUnreadMessages > 1 ? 's' : ''}",
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, int count, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(colors: [color.withOpacity(0.1), color.withOpacity(0.05)]),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 28, color: color)),
            const SizedBox(height: 12),
            Text(count.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  /// ✅ Carte statistique avec badge pour les messages
  Widget _statCardWithBadge(String title, int badgeCount, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          setState(() {
            selectedIndex = 5;
          });
          _loadUnreadMessagesCount();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(colors: [color.withOpacity(0.1), color.withOpacity(0.05)]),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, size: 28, color: color),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
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
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeCount > 0 ? Colors.red : color),
              ),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("Aucune action pour le moment", style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.history, color: Colors.blue[800]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Journal des actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("Total: ${logs.length} actions", style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _clearHistory,
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text("Effacer"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: logs.length,
            itemBuilder: (_, i) {
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getLogColor(logs[i]).withOpacity(0.1),
                    child: Icon(_getLogIcon(logs[i]), size: 20, color: _getLogColor(logs[i])),
                  ),
                  title: Text(logs[i], style: const TextStyle(fontSize: 13)),
                  subtitle: Text("Action #${logs.length - i}", style: TextStyle(fontSize: 11, color: Colors.grey[600])),
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
        title: const Text("Confirmation"),
        content: const Text("Voulez-vous vraiment effacer tout l'historique ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Effacer")),
        ],
      ),
    );
    
    if (confirm == true) {
      await db.clearLogs();
      await _loadDashboardDataFromFirestore();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Historique effacé"), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
    }
  }

  Color _getLogColor(String log) {
    final l = log.toLowerCase();
    if (l.contains('ajout') || l.contains('cré')) return Colors.green;
    if (l.contains('supprim') || l.contains('effac')) return Colors.red;
    if (l.contains('modif') || l.contains('mis à jour')) return Colors.orange;
    return Colors.blue;
  }

  IconData _getLogIcon(String log) {
    final l = log.toLowerCase();
    if (l.contains('professeur')) return Icons.school;
    if (l.contains('utilisateur')) return Icons.person;
    if (l.contains('classe')) return Icons.class_;
    if (l.contains('annonce')) return Icons.announcement;
    return Icons.history;
  }
}
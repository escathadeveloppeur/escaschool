// lib/screens/staff/admin_staff_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../login_screen.dart';
import 'admin_students.dart';
import 'admin_payments.dart';
import 'admin_documents.dart';
import 'admin_parents.dart';
import 'admin_attendance.dart';
import 'attendance_report.dart';
import 'manage_staff_screen.dart';
import 'staff_payments_screen.dart';
import 'staff_messages_screen.dart'; // ✅ Ajout de l'import du nouveau fichier

class AdminStaffDashboard extends StatefulWidget {
  const AdminStaffDashboard({super.key});

  @override
  _AdminStaffDashboardState createState() => _AdminStaffDashboardState();
}

class _AdminStaffDashboardState extends State<AdminStaffDashboard> {
  int selectedIndex = 0;

  int totalStudents = 0;
  int totalPayments = 0;
  double totalAmount = 0.0;
  int totalDocuments = 0;
  int totalParents = 0;
  int totalStaff = 0;
  int totalUnreadMessages = 0; // ✅ Ajout compteur messages non lus

  final List<String> titles = [
    "Dashboard Personnel",
    "Élèves",
    "Paiements",
    "Documents",
    "Parents",
    "Présences",
    "Rapports",
    "Personnel",
    "Paiements Personnel",
    "Messages", // ✅ Changé de "Historique" à "Messages"
    "Historique",
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardDataFromFirestore();
    _loadUnreadMessagesCount(); // ✅ Charger les messages non lus
  }

  /// 🔥 Charger les données du dashboard depuis Firestore
  Future<void> _loadDashboardDataFromFirestore() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;
    
    try {
      // 1. Compter les étudiants
      Query studentQuery = FirebaseFirestore.instance.collection('students');
      if (schoolId != null && !auth.isSuperAdmin) {
        studentQuery = studentQuery.where('schoolId', isEqualTo: schoolId);
      }
      final studentsSnapshot = await studentQuery.get();
      totalStudents = studentsSnapshot.docs.length;
      
      // 2. Compter les paiements
      Query paymentQuery = FirebaseFirestore.instance.collection('payments');
      if (schoolId != null && !auth.isSuperAdmin) {
        paymentQuery = paymentQuery.where('schoolId', isEqualTo: schoolId);
      }
      final paymentsSnapshot = await paymentQuery.get();
      totalPayments = paymentsSnapshot.docs.length;
      
      // 3. Calculer le montant total
      totalAmount = 0.0;
      for (var doc in paymentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalAmount += (data['amount'] as num?)?.toDouble() ?? 0.0;
      }
      
      // 4. Compter les documents
      Query documentQuery = FirebaseFirestore.instance.collection('documents');
      if (schoolId != null && !auth.isSuperAdmin) {
        documentQuery = documentQuery.where('schoolId', isEqualTo: schoolId);
      }
      final documentsSnapshot = await documentQuery.get();
      totalDocuments = documentsSnapshot.docs.length;
      
      // 5. Compter les parents
      final parentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .get();
      
      int filteredParents = parentsSnapshot.docs.length;
      if (schoolId != null && !auth.isSuperAdmin) {
        filteredParents = parentsSnapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['schoolId'] == schoolId;
        }).length;
      }
      totalParents = filteredParents;
      
      // 6. Compter le personnel
      Query staffQuery = FirebaseFirestore.instance.collection('staff');
      if (schoolId != null && !auth.isSuperAdmin) {
        staffQuery = staffQuery.where('schoolId', isEqualTo: schoolId);
      }
      final staffSnapshot = await staffQuery.get();
      totalStaff = staffSnapshot.docs.length;
      
      print('✅ Dashboard chargé: $totalStudents étudiants, $totalPayments paiements, $totalStaff personnel');
    } catch (e) {
      print('❌ Erreur chargement dashboard: $e');
    }
    setState(() {});
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

  Future<void> _syncAllData() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Synchronisation en cours...'),
        backgroundColor: Color(0xFFF59E0B),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    await _loadDashboardDataFromFirestore();
    await _loadUnreadMessagesCount();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Synchronisation terminée'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    final pages = [
      _dashboardHome(),
      AdminStudents(onChanged: _loadDashboardDataFromFirestore),
      AdminPayments(onChanged: _loadDashboardDataFromFirestore),
      AdminDocuments(onChanged: _loadDashboardDataFromFirestore),
      AdminParents(onChanged: _loadDashboardDataFromFirestore),
      AdminAttendance(onChanged: _loadDashboardDataFromFirestore),
      AttendanceReportScreen(),
      const ManageStaffScreen(),
      StaffPaymentsScreen(staff: null),
      const StaffMessagesScreen(), // ✅ Ajout de l'écran des messages
      _historyPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[selectedIndex],
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // ✅ Badge des messages non lus dans l'app bar
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.message_outlined, size: 22),
                tooltip: "Messages",
                onPressed: () {
                  setState(() {
                    selectedIndex = 9; // Aller à l'onglet Messages
                  });
                  _loadUnreadMessagesCount(); // Rafraîchir le compteur
                },
              ),
              if (totalUnreadMessages > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$totalUnreadMessages',
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
          IconButton(
            icon: const Icon(Icons.sync, size: 22),
            tooltip: "Synchroniser",
            onPressed: _syncAllData,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 24),
            tooltip: "Rafraîchir",
            onPressed: () async {
              await _loadDashboardDataFromFirestore();
              await _loadUnreadMessagesCount();
            },
          )
        ],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadDashboardDataFromFirestore();
          await _loadUnreadMessagesCount();
        },
        color: Colors.blue[700],
        backgroundColor: Colors.white,
        child: Container(
          color: Colors.grey[50],
          child: pages[selectedIndex],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      width: 280,
      child: Column(
        children: [
          Container(
            height: 180,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue[800],
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 36,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Espace Personnel",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Tableau de bord administrateur",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                _drawerItem(Icons.dashboard_outlined, "Dashboard", 0),
                _drawerItem(Icons.school_outlined, "Élèves", 1),
                _drawerItem(Icons.payment_outlined, "Paiements", 2),
                _drawerItem(Icons.folder_open_outlined, "Documents", 3),
                _drawerItem(Icons.family_restroom_outlined, "Parents", 4),
                _drawerItem(Icons.history, "Présences", 5),
                _drawerItem(Icons.bar_chart, "Rapports", 6),
                _drawerItem(Icons.people_outline, "Personnel", 7),
                _drawerItem(Icons.payments, "Paiements Personnel", 8),
                // ✅ Nouvel élément de menu pour les messages avec badge
                _buildMessagesDrawerItem(),
                _drawerItem(Icons.history_outlined, "Historique", 10),
                const Divider(
                  height: 40,
                  indent: 20,
                  endIndent: 20,
                  thickness: 1,
                ),
                ListTile(
                  leading: Icon(
                    Icons.logout,
                    color: Colors.grey[700],
                  ),
                  title: Text(
                    "Déconnexion",
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    auth.logout();
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  minLeadingWidth: 30,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Élément de menu pour les messages avec badge
  Widget _buildMessagesDrawerItem() {
    final bool isSelected = selectedIndex == 9;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? Colors.blue[50] : Colors.transparent,
        border: isSelected
            ? Border.all(color: Colors.blue[200]!, width: 1)
            : null,
      ),
      child: ListTile(
        leading: Stack(
          children: [
            Icon(
              Icons.message_outlined,
              color: isSelected ? Colors.blue[700] : Colors.grey[700],
              size: 24,
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
            color: isSelected ? Colors.blue[700] : Colors.grey[800],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        selected: isSelected,
        onTap: () {
          setState(() => selectedIndex = 9);
          Navigator.pop(context);
          _loadUnreadMessagesCount();
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minLeadingWidth: 30,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, int index) {
    final bool isSelected = selectedIndex == index;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? Colors.blue[50] : Colors.transparent,
        border: isSelected
            ? Border.all(color: Colors.blue[200]!, width: 1)
            : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.blue[700] : Colors.grey[700],
          size: 24,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.blue[700] : Colors.grey[800],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        selected: isSelected,
        onTap: () {
          setState(() => selectedIndex = index);
          Navigator.pop(context);
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minLeadingWidth: 30,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _dashboardHome() {
    final auth = Provider.of<AuthProvider>(context);
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            "Bienvenue dans votre espace",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.blue[900],
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tableau de bord personnel",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          
          if (auth.currentSchoolId != null && !auth.isSuperAdmin)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.business, size: 18, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Text(
                    auth.schoolName ?? 'Tableau de bord',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 32),
          
          const Text(
            "Statistiques Générales",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 20),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.85,
            children: [
              _statCard(
                "Élèves inscrits",
                totalStudents.toString(),
                Icons.school_outlined,
                Colors.orange[700]!,
                Colors.orange[50]!,
              ),
              _statCard(
                "Parents",
                totalParents.toString(),
                Icons.family_restroom_outlined,
                Colors.purple[700]!,
                Colors.purple[50]!,
              ),
              _statCard(
                "Paiements",
                totalPayments.toString(),
                Icons.payment_outlined,
                Colors.green[700]!,
                Colors.green[50]!,
              ),
              _statCard(
                "Documents",
                totalDocuments.toString(),
                Icons.folder_open_outlined,
                Colors.blue[700]!,
                Colors.blue[50]!,
              ),
              _statCard(
                "Personnel",
                totalStaff.toString(),
                Icons.people_outline,
                Colors.teal[700]!,
                Colors.teal[50]!,
              ),
              _statCard(
                "Montant Total",
                "${totalAmount.toStringAsFixed(0)} FCFA",
                Icons.attach_money,
                Colors.amber[700]!,
                Colors.amber[50]!,
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          const Text(
            "Accès Rapide",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _quickActionCard("Élèves", Icons.school, 1),
              _quickActionCard("Paiements", Icons.payment, 2),
              _quickActionCard("Documents", Icons.folder, 3),
              _quickActionCard("Parents", Icons.family_restroom, 4),
              _quickActionCard("Présences", Icons.history, 5),
              _quickActionCard("Rapports", Icons.bar_chart, 6),
              _quickActionCard("Personnel", Icons.people, 7),
              _quickActionCard("Paiements Staff", Icons.payments, 8),
              // ✅ Carte d'accès rapide pour les messages
              _quickActionCardWithBadge("Messages", Icons.message, 9, totalUnreadMessages),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color iconColor, Color bgColor) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.grey[900],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionCard(String title, IconData icon, int index) {
    return GestureDetector(
      onTap: () => setState(() => selectedIndex = index),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blue[50],
                child: Icon(
                  icon,
                  color: Colors.blue[700],
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ Carte d'accès rapide avec badge pour les messages
  Widget _quickActionCardWithBadge(String title, IconData icon, int index, int badgeCount) {
    return GestureDetector(
      onTap: () {
        setState(() => selectedIndex = index);
        _loadUnreadMessagesCount();
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blue[50],
                    child: Icon(
                      icon,
                      color: Colors.blue[700],
                      size: 24,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
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
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            "Historique des actions",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Fonctionnalité à venir",
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
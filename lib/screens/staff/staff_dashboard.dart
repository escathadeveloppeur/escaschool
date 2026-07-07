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
import 'staff_messages_screen.dart';
import 'staff_announcements.dart';
import 'staff_attendance_screen.dart'; // ✅ NOUVEAU : Présences personnel

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
  int totalUnreadMessages = 0;
  int totalAnnouncements = 0;

  final List<String> titles = [
    "Dashboard Personnel",
    "Élèves",
    "Paiements",
    "Documents",
    "Parents",
    "Présences Élèves",
    "Rapports",
    "Personnel",
    "Paiements Personnel",
    "Messages",
    "Annonces",
    "Présences Personnel", // ✅ NOUVEAU
    "Historique",
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardDataFromFirestore();
    _loadUnreadMessagesCount();
  }

  Future<void> _loadDashboardDataFromFirestore() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;
    
    try {
      // Élèves
      Query studentQuery = FirebaseFirestore.instance.collection('students');
      if (schoolId != null && !auth.isSuperAdmin) {
        studentQuery = studentQuery.where('schoolId', isEqualTo: schoolId);
      }
      final studentsSnapshot = await studentQuery.get();
      totalStudents = studentsSnapshot.docs.length;
      
      // Paiements
      Query paymentQuery = FirebaseFirestore.instance.collection('payments');
      if (schoolId != null && !auth.isSuperAdmin) {
        paymentQuery = paymentQuery.where('schoolId', isEqualTo: schoolId);
      }
      final paymentsSnapshot = await paymentQuery.get();
      totalPayments = paymentsSnapshot.docs.length;
      
      totalAmount = 0.0;
      for (var doc in paymentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalAmount += (data['amount'] as num?)?.toDouble() ?? 0.0;
      }
      
      // Documents
      Query documentQuery = FirebaseFirestore.instance.collection('documents');
      if (schoolId != null && !auth.isSuperAdmin) {
        documentQuery = documentQuery.where('schoolId', isEqualTo: schoolId);
      }
      final documentsSnapshot = await documentQuery.get();
      totalDocuments = documentsSnapshot.docs.length;
      
      // Parents
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
      
      // Personnel
      Query staffQuery = FirebaseFirestore.instance.collection('staff');
      if (schoolId != null && !auth.isSuperAdmin) {
        staffQuery = staffQuery.where('schoolId', isEqualTo: schoolId);
      }
      final staffSnapshot = await staffQuery.get();
      totalStaff = staffSnapshot.docs.length;
      
      // Annonces
      Query announcementQuery = FirebaseFirestore.instance.collection('announcements');
      if (schoolId != null && !auth.isSuperAdmin) {
        announcementQuery = announcementQuery.where('schoolId', isEqualTo: schoolId);
      }
      final announcementSnapshot = await announcementQuery.get();
      totalAnnouncements = announcementSnapshot.docs.length;
      
      setState(() {});
      print('✅ Dashboard chargé: $totalStudents étudiants, $totalAnnouncements annonces');
    } catch (e) {
      print('❌ Erreur chargement dashboard: $e');
    }
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
    } catch (e) {
      print('❌ Erreur chargement messages non lus: $e');
    }
  }

  Future<void> _syncAllData() async {
    _showSnackBar('Synchronisation en cours...', _AppColors.warning);
    await _loadDashboardDataFromFirestore();
    await _loadUnreadMessagesCount();
    _showSnackBar('Synchronisation terminée', _AppColors.success);
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
      const AttendanceReportScreen(),
      const ManageStaffScreen(),
      StaffPaymentsScreen(staff: null),
      const StaffMessagesScreen(),
      const StaffAnnouncementsScreen(),
      const StaffAttendanceScreen(), // ✅ NOUVEAU : Présences personnel
      _historyPage(),
    ];

    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        elevation: 0,
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
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.message_rounded),
                tooltip: "Messages",
                onPressed: () {
                  setState(() => selectedIndex = 9);
                  _loadUnreadMessagesCount();
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
            icon: const Icon(Icons.sync_rounded),
            tooltip: "Synchroniser",
            onPressed: _syncAllData,
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
        onRefresh: () async {
          await _loadDashboardDataFromFirestore();
          await _loadUnreadMessagesCount();
        },
        color: _AppColors.primary,
        child: pages[selectedIndex],
      ),
    );
  }

  Widget _buildDrawer() {
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
                    child: const Icon(Icons.person_outline_rounded, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Espace Personnel",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Tableau de bord",
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _drawerItem(Icons.dashboard_rounded, "Dashboard", 0),
          _drawerItem(Icons.school_rounded, "Élèves", 1),
          _drawerItem(Icons.payment_rounded, "Paiements", 2),
          _drawerItem(Icons.folder_open_rounded, "Documents", 3),
          _drawerItem(Icons.family_restroom_rounded, "Parents", 4),
          _drawerItem(Icons.history_rounded, "Présences Élèves", 5),
          _drawerItem(Icons.bar_chart_rounded, "Rapports", 6),
          _drawerItem(Icons.people_rounded, "Personnel", 7),
          _drawerItem(Icons.payments_rounded, "Paiements Personnel", 8),
          _buildMessagesDrawerItem(),
          _drawerItem(Icons.campaign_rounded, "Annonces", 10),
          _drawerItem(Icons.fingerprint, "Présences Personnel", 11, color: const Color(0xFF0F766E)), // ✅ NOUVEAU
          _drawerItem(Icons.history_rounded, "Historique", 12),
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
              leading: const Icon(Icons.logout_rounded, color: _AppColors.danger),
              title: const Text("Déconnexion", style: TextStyle(color: _AppColors.danger, fontWeight: FontWeight.w600)),
              onTap: () {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                auth.logout();
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMessagesDrawerItem() {
    final bool isSelected = selectedIndex == 9;
    
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
              Icons.message_rounded,
              color: isSelected ? _AppColors.primary : Colors.grey[700],
            ),
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
          setState(() => selectedIndex = 9);
          Navigator.pop(context);
          _loadUnreadMessagesCount();
        },
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, int index, {Color? color}) {
    final bool isSelected = selectedIndex == index;
    final iconColor = color ?? (isSelected ? _AppColors.primary : Colors.grey[700]);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? _AppColors.primary.withOpacity(0.08) : Colors.transparent,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? _AppColors.primary : _AppColors.textDark,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        selected: isSelected,
        selectedTileColor: _AppColors.primary.withOpacity(0.08),
        onTap: () {
          setState(() => selectedIndex = index);
          Navigator.pop(context);
        },
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
                  child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bienvenue, ${auth.user?.name ?? 'Personnel'}",
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        auth.schoolName ?? 'Tableau de bord',
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
                "Statistiques Générales",
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
              _statCard("Élèves", totalStudents.toString(), Icons.school_rounded, const Color(0xFFF59E0B)),
              _statCard("Parents", totalParents.toString(), Icons.family_restroom_rounded, const Color(0xFF8B5CF6)),
              _statCard("Paiements", totalPayments.toString(), Icons.payment_rounded, const Color(0xFF10B981)),
              _statCard("Documents", totalDocuments.toString(), Icons.folder_open_rounded, const Color(0xFF3B82F6)),
              _statCard("Personnel", totalStaff.toString(), Icons.people_rounded, const Color(0xFF14B8A6)),
              _statCard("Annonces", totalAnnouncements.toString(), Icons.campaign_rounded, const Color(0xFFEF4444)),
              _statCard("Montant", "${totalAmount.toStringAsFixed(0)} USD", Icons.attach_money_rounded, const Color(0xFFF59E0B)),
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
                "Accès Rapide",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _AppColors.textDark),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _quickAccessCard(
            icon: Icons.school_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: "Gestion des élèves",
            subtitle: "$totalStudents élèves inscrits",
            onTap: () => setState(() => selectedIndex = 1),
          ),
          const SizedBox(height: 12),

          _quickAccessCard(
            icon: Icons.payment_rounded,
            iconColor: const Color(0xFF10B981),
            title: "Gestion des paiements",
            subtitle: "$totalPayments paiements enregistrés",
            onTap: () => setState(() => selectedIndex = 2),
          ),
          const SizedBox(height: 12),

          _quickAccessCard(
            icon: Icons.folder_open_rounded,
            iconColor: const Color(0xFF3B82F6),
            title: "Gestion des documents",
            subtitle: "$totalDocuments documents disponibles",
            onTap: () => setState(() => selectedIndex = 3),
          ),
          const SizedBox(height: 12),

          _quickAccessCard(
            icon: Icons.people_rounded,
            iconColor: const Color(0xFF14B8A6),
            title: "Gestion du personnel",
            subtitle: "$totalStaff membres du personnel",
            onTap: () => setState(() => selectedIndex = 7),
          ),
          const SizedBox(height: 12),

          _quickAccessCard(
            icon: Icons.fingerprint,
            iconColor: const Color(0xFF0F766E),
            title: "Présences du personnel",
            subtitle: "Gérer les pointages",
            onTap: () => setState(() => selectedIndex = 11), // ✅ Nouvel index
          ),
          const SizedBox(height: 12),

          _quickAccessCard(
            icon: Icons.campaign_rounded,
            iconColor: const Color(0xFFEF4444),
            title: "Consulter les annonces",
            subtitle: "$totalAnnouncements annonces disponibles",
            onTap: () => setState(() => selectedIndex = 10),
          ),
          const SizedBox(height: 12),

          _quickAccessCardWithBadge(
            icon: Icons.message_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: "Messagerie",
            subtitle: "Consultez vos messages",
            badgeCount: totalUnreadMessages,
            onTap: () {
              setState(() => selectedIndex = 9);
              _loadUnreadMessagesCount();
            },
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
                        style: TextStyle(fontSize: 12.5, color: _AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                trailing ?? Icon(Icons.arrow_forward_ios_rounded, size: 15, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickAccessCardWithBadge({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required int badgeCount,
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
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: iconColor, size: 26),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: _AppColors.danger,
                            shape: BoxShape.circle,
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
                        style: TextStyle(fontSize: 12.5, color: _AppColors.textMuted),
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

  Widget _statCard(String title, String value, IconData icon, Color color) {
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
            value,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _AppColors.textDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12.5, color: _AppColors.textMuted, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _historyPage() {
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
            "Historique des actions",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _AppColors.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            "Fonctionnalité à venir",
            style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
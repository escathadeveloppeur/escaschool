// lib/screens/super_admin/super_admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../providers/auth_provider.dart';
import '../login_screen.dart';
import '../../../services/db_helper.dart';
import '../../../services/school_service.dart';
import '../../../services/user_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/document_service.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/schools_tab.dart';
import 'tabs/admins_tab.dart';
import 'tabs/pending_requests_tab.dart';
import 'statistics_screen.dart';
import 'system_logs_screen.dart';
import 'school_payments_screen.dart';
import 'settings_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  _SuperAdminDashboardState createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> with SingleTickerProviderStateMixin {
  final DBHelper db = DBHelper();
  int _selectedIndex = 0;
  late AnimationController _animationController;

  final List<String> _titles = [
    'Tableau de bord',
    'Gestion des écoles',
    'Administrateurs',
    'Demandes',
    'Statistiques',
    'Logs système',
    'Paiements écoles',
  ];

  final List<Widget> _tabs = [
    const DashboardTab(),
    const SchoolsTab(),
    const AdminsTab(),
    const PendingRequestsTab(),
    const StatisticsScreen(),
    const SystemLogsScreen(),
    const SchoolPaymentsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            // Logo dans l'AppBar
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.school,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Text(
              _titles[_selectedIndex],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          // Badge pour les demandes en attente
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('registration_requests')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.pending_actions, color: Color(0xFFF59E0B)),
                    onPressed: () {
                      setState(() {
                        _selectedIndex = 3;
                      });
                    },
                    tooltip: 'Demandes en attente',
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          count > 9 ? '9+' : '$count',
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
              );
            },
          ),
          // Bouton de synchronisation globale
          IconButton(
            icon: const Icon(Icons.sync, color: Color(0xFF10B981)),
            onPressed: () {
              _syncAllData(context);
            },
            tooltip: 'Synchroniser tout',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              auth.logout();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            style: IconButton.styleFrom(backgroundColor: Colors.grey[100]),
          ),
        ],
      ),
      drawer: _buildDrawer(user),
      body: FadeTransition(
        opacity: _animationController,
        child: _tabs[_selectedIndex],
      ),
    );
  }

  Future<void> _syncAllData(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Synchronisation en cours...'),
        backgroundColor: Color(0xFFF59E0B),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    try {
      final schoolService = SchoolService();
      final userService = UserService();
      final paymentService = PaymentService();
      final documentService = DocumentService();
      
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      if (schoolId != null) {
        await schoolService.syncAllSchoolsToFirestore();
        await schoolService.syncSchoolsFromFirestoreToLocal();
        await userService.syncAllUsersToFirestore(schoolId.toString());
        await paymentService.syncAllPaymentsToFirestore(schoolId.toString());
        await documentService.syncAllDocumentsToFirestore(schoolId.toString());
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Synchronisation terminée avec succès'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildDrawer(user) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // En-tête du drawer avec logo
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                ),
              ),
              child: DrawerHeader(
                decoration: const BoxDecoration(color: Colors.transparent),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Logo dans le drawer
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.school,
                                    size: 30,
                                    color: Color(0xFF0F766E),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Super Admin',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Super Administrateur",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Onglets principaux
            _drawerItem(Icons.dashboard_outlined, "Tableau de bord", 0),
            _drawerItem(Icons.business_outlined, "Gestion des écoles", 1),
            _drawerItem(Icons.admin_panel_settings_outlined, "Administrateurs", 2),
            _drawerItem(Icons.pending_actions, "Demandes", 3, badge: true),
            _drawerItem(Icons.bar_chart_outlined, "Statistiques", 4),
            _drawerItem(Icons.history_outlined, "Logs système", 5),
            _drawerItem(Icons.payment_outlined, "Paiements écoles", 6),
            
            const Divider(height: 24, thickness: 1),
            
            // Section Paramètres
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.settings, color: Color(0xFF8B5CF6)),
              ),
              title: const Text("Paramètres", style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
            
            // Section synchronisation
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sync, color: Color(0xFF10B981)),
              ),
              title: const Text("Synchroniser", style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () => _syncAllData(context),
            ),
            
            // Déconnexion
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.logout, color: Colors.red[400]),
              ),
              title: const Text("Déconnexion", style: TextStyle(fontWeight: FontWeight.w500)),
              onTap: () {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                auth.logout();
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            ),
            
            const SizedBox(height: 16),
            
            // Version
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'EscaSchool v1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, int index, {bool badge = false}) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F766E).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF0F766E) : Colors.grey[600]),
            if (badge)
              Positioned(
                right: -4,
                top: -4,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('registration_requests')
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFF0F766E) : Colors.grey[800],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        Navigator.pop(context);
      },
    );
  }
}
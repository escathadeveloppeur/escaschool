// lib/screens/super_admin/super_admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'statistics_screen.dart';
import 'system_logs_screen.dart';
import 'school_payments_screen.dart';
import 'settings_screen.dart';  // Ajout de l'écran des paramètres

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
    'Statistiques',
    'Logs système',
    'Paiements écoles',
  ];

  final List<Widget> _tabs = [
    const DashboardTab(),
    const SchoolsTab(),
    const AdminsTab(),
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
        title: Text(
          _titles[_selectedIndex],
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
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
        
        // Recharger l'onglet actuel
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
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]),
              ),
              child: UserAccountsDrawerHeader(
                accountName: Text(user?.name ?? 'Super Admin', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                accountEmail: const Text("Super Administrateur"),
                currentAccountPicture: Container(
                  padding: const EdgeInsets.all(4),
                  decoration:  BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  child: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.admin_panel_settings, color: Color(0xFF0F766E))),
                ),
                decoration: const BoxDecoration(color: Colors.transparent),
              ),
            ),
            // Onglets principaux
            _drawerItem(Icons.dashboard_outlined, "Tableau de bord", 0),
            _drawerItem(Icons.business_outlined, "Gestion des écoles", 1),
            _drawerItem(Icons.admin_panel_settings_outlined, "Administrateurs", 2),
            _drawerItem(Icons.bar_chart_outlined, "Statistiques", 3),
            _drawerItem(Icons.history_outlined, "Logs système", 4),
            _drawerItem(Icons.payment_outlined, "Paiements écoles", 5),
            
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
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, int index) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F766E).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: isSelected ? const Color(0xFF0F766E) : Colors.grey[600]),
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
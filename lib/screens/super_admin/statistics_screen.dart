// lib/screens/super_admin/statistics_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/stats_service.dart';
import '../../providers/auth_provider.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  final StatsService _statsService = StatsService();
  Map<String, dynamic> _globalStats = {};
  bool _isLoading = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadStatsFromFirestore();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les statistiques depuis Firestore
  Future<void> _loadStatsFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      // Compter les écoles
      final schoolsSnapshot = await FirebaseFirestore.instance
          .collection('schools')
          .count()
          .get();
      final totalSchools = schoolsSnapshot.count ?? 0;
      
      // Compter les écoles actives
      final activeSchoolsSnapshot = await FirebaseFirestore.instance
          .collection('schools')
          .where('isActive', isEqualTo: true)
          .count()
          .get();
      final activeSchools = activeSchoolsSnapshot.count ?? 0;
      
      // Compter les utilisateurs par rôle
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .count()
          .get();
      
      final teachersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .count()
          .get();
      
      final adminsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['admin', 'super_admin'])
          .count()
          .get();
      
      final parentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .count()
          .get();
      
      final staffSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'staff')
          .count()
          .get();
      
      // Total utilisateurs
      final totalUsers = (studentsSnapshot.count ?? 0) + (teachersSnapshot.count ?? 0) + 
                         (adminsSnapshot.count ?? 0) + (parentsSnapshot.count ?? 0) + 
                         (staffSnapshot.count ?? 0);
      
      // Compter les paiements
      final paymentsSnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .count()
          .get();
      
      // Compter les documents
      final documentsSnapshot = await FirebaseFirestore.instance
          .collection('documents')
          .count()
          .get();
      
      // Calculer le CA total (à adapter selon votre structure)
      final revenueSnapshot = await FirebaseFirestore.instance
          .collection('payments')
          .get();
      
      double totalRevenue = 0;
      for (var doc in revenueSnapshot.docs) {
        totalRevenue += (doc.data()['amount'] as num?)?.toDouble() ?? 0;
      }
      
      _globalStats = {
        'totalSchools': totalSchools,
        'activeSchools': activeSchools,
        'suspendedSchools': totalSchools - activeSchools,
        'totalUsers': totalUsers,
        'totalStudents': studentsSnapshot.count ?? 0,
        'totalTeachers': teachersSnapshot.count ?? 0,
        'totalAdmins': adminsSnapshot.count ?? 0,
        'totalParents': parentsSnapshot.count ?? 0,
        'totalStaff': staffSnapshot.count ?? 0,
        'totalPayments': paymentsSnapshot.count ?? 0,
        'totalDocuments': documentsSnapshot.count ?? 0,
        'totalRevenue': totalRevenue,
      };
      
      print('✅ Statistiques chargées depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement stats: $e');
      // Fallback vers StatsService
      _globalStats = await _statsService.getGlobalStats();
    } finally {
      setState(() => _isLoading = false);
      _animationController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Statistiques',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatsFromFirestore,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (auth.currentSchoolId != null && !auth.isSuperAdmin)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.business, size: 18, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 8),
                          Text(
                            auth.schoolName ?? 'Statistiques globales',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ],
                      ),
                    ),

                  FadeTransition(
                    opacity: _animationController,
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
                        children: [
                          const Icon(Icons.analytics, color: Colors.white, size: 40),
                          const SizedBox(height: 12),
                          const Text(
                            'Tableau de bord',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Statistiques globales du système',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildStatCard(
                        'Écoles',
                        '${_globalStats['totalSchools'] ?? 0}',
                        Icons.business,
                        const Color(0xFF3B82F6),
                        '${_globalStats['activeSchools'] ?? 0} actives • ${_globalStats['suspendedSchools'] ?? 0} suspendues',
                      ),
                      _buildStatCard(
                        'Utilisateurs',
                        '${_globalStats['totalUsers'] ?? 0}',
                        Icons.people,
                        const Color(0xFF10B981),
                        'Total inscrits',
                      ),
                      _buildStatCard(
                        'Élèves',
                        '${_globalStats['totalStudents'] ?? 0}',
                        Icons.school,
                        const Color(0xFF8B5CF6),
                        'Étudiants inscrits',
                      ),
                      _buildStatCard(
                        'Documents',
                        '${_globalStats['totalDocuments'] ?? 0}',
                        Icons.folder,
                        const Color(0xFFF59E0B),
                        'Documents en ligne',
                      ),
                      _buildStatCard(
                        'Paiements',
                        '${_globalStats['totalPayments'] ?? 0}',
                        Icons.payment,
                        const Color(0xFFEF4444),
                        'Transactions',
                      ),
                      _buildStatCard(
                        'CA Total',
                        '${(_globalStats['totalRevenue'] ?? 0.0).toStringAsFixed(0)} FCFA',
                        Icons.trending_up,
                        const Color(0xFF14B8A6),
                        'Chiffre d\'affaires',
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
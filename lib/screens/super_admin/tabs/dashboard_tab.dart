// lib/screens/super_admin/tabs/dashboard_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/university/etablissement_model.dart';
import '../widgets/stat_card.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  _DashboardTabState createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  List<EtablissementModel> _etablissements = [];
  int _totalAdmins = 0;
  int _totalUsers = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDataFromFirestore();
  }

  /// 🔥 Charger toutes les stats depuis Firestore
  Future<void> _loadDataFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      // Charger les écoles
      final schoolsSnapshot = await FirebaseFirestore.instance
          .collection('schools')
          .get();
      
      _etablissements = schoolsSnapshot.docs.map((doc) {
        final data = doc.data();
        return EtablissementModel(
          id: data['localId'] ?? 0,
          nom: data['name'] ?? data['nom'] ?? 'Sans nom',
          type: data['type'] ?? 'École',
          adresse: data['address'] ?? data['adresse'],
          telephone: data['phone'] ?? data['telephone'],
          email: data['email'],
          siteWeb: data['website'] ?? data['siteWeb'],
          firestoreId: doc.id,
          isActive: data['isActive'] ?? true,
          schoolCode: data['schoolCode'] ?? '',
        );
      }).toList();
      
      // Compter les admins
      final adminsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['admin', 'super_admin'])
          .count()
          .get();
      _totalAdmins = adminsSnapshot.count ?? 0;
      
      // Compter tous les utilisateurs
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .count()
          .get();
      _totalUsers = usersSnapshot.count ?? 0;
      
      print('✅ Dashboard chargé: ${_etablissements.length} écoles, $_totalAdmins admins, $_totalUsers utilisateurs');
    } catch (e) {
      print('❌ Erreur chargement dashboard: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          Wrap(spacing: 16, runSpacing: 16, children: [
            StatCard(title: "Écoles", count: _etablissements.length, icon: Icons.business, color: const Color(0xFF3B82F6)),
            StatCard(title: "Administrateurs", count: _totalAdmins, icon: Icons.admin_panel_settings, color: const Color(0xFF8B5CF6)),
            StatCard(title: "Utilisateurs", count: _totalUsers, icon: Icons.people, color: const Color(0xFF10B981)),
          ]),
          const SizedBox(height: 24),
          _buildRecentSchools(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
            child: const CircleAvatar(radius: 30, backgroundColor: Colors.white, child: Icon(Icons.admin_panel_settings, size: 35, color: Color(0xFF0F766E))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Super Administrateur", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: const Text("Gestion multi-écoles", style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSchools() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))]),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.history, color: Colors.blue)),
                const SizedBox(width: 12),
                const Text("Dernières écoles ajoutées", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          _etablissements.isEmpty
              ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text("Aucune école enregistrée")))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _etablissements.length > 5 ? 5 : _etablissements.length,
                  itemBuilder: (context, index) {
                    final ecole = _etablissements[index];
                    return ListTile(
                      leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.business, color: Colors.blue)),
                      title: Text(ecole.nom, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(ecole.type ?? 'École', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("ID: ${ecole.id}", style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
                          if (ecole.firestoreId != null)
                            Text(ecole.firestoreId!.substring(0, 8) + '...', style: const TextStyle(fontSize: 9, color: Colors.blue, fontFamily: 'monospace')),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}
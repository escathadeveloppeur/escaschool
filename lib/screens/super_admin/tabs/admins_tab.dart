// lib/screens/super_admin/tabs/admins_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/db_helper.dart';
import '../dialogs/add_admin_dialog.dart';
import '../widgets/admin_card.dart';

class AdminsTab extends StatefulWidget {
  const AdminsTab({super.key});

  @override
  _AdminsTabState createState() => _AdminsTabState();
}

class _AdminsTabState extends State<AdminsTab> {
  final DBHelper db = DBHelper();
  List<Map<String, dynamic>> _admins = [];
  List<Map<String, dynamic>> _filteredAdmins = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDataFromFirestore();
  }

  /// 🔥 Charger les admins depuis Firestore avec leurs informations d'école
  Future<void> _loadDataFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['admin', 'super_admin'])
          .get();
      
      _admins = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final schoolIdDynamic = data['schoolId'];
        
        // Convertir schoolId en int si c'est un String
        int? schoolId;
        if (schoolIdDynamic != null) {
          if (schoolIdDynamic is int) {
            schoolId = schoolIdDynamic;
          } else if (schoolIdDynamic is String) {
            schoolId = int.tryParse(schoolIdDynamic);
          }
        }
        
        String schoolName = data['schoolName'] ?? '';
        
        // Si schoolId existe mais pas schoolName, récupérer le nom depuis la collection schools
        if (schoolId != null && schoolName.isEmpty) {
          try {
            final schoolDoc = await FirebaseFirestore.instance
                .collection('schools')
                .doc(schoolId.toString())
                .get();
            if (schoolDoc.exists) {
              final schoolData = schoolDoc.data() as Map<String, dynamic>;
              schoolName = schoolData['name'] ?? 'École inconnue';
            }
          } catch (e) {
            print('⚠️ Erreur récupération nom école: $e');
            schoolName = 'École inconnue';
          }
        }
        
        // Récupérer la date de création
        DateTime? createdAt;
        if (data['createdAt'] != null) {
          if (data['createdAt'] is Timestamp) {
            createdAt = (data['createdAt'] as Timestamp).toDate();
          }
        }
        
        _admins.add({
          'id': doc.id,
          'localId': data['localId'] as int?,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'role': data['role'] ?? 'admin',
          'roleLabel': data['role'] == 'admin' ? 'Administrateur' : 'Super Administrateur',
          'schoolId': schoolId,
          'schoolName': schoolName,
          'status': data['status'] ?? 'approved',
          'firestoreId': doc.id,
          'createdAt': createdAt,
        });
      }
      
      // Trier par date de création (plus récent en premier)
      _admins.sort((a, b) {
        final dateA = a['createdAt'] as DateTime?;
        final dateB = b['createdAt'] as DateTime?;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB!.compareTo(dateA!);
      });
      
      _filteredAdmins = _admins;
      print('✅ ${_admins.length} administrateurs chargés depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement admins: $e');
      // Fallback vers Hive
      final allUsers = await db.getAllUsers();
      _admins = allUsers.where((u) => u['role'] == 'admin' || u['role'] == 'super_admin').map((u) {
        return {
          'id': u['id'].toString(),
          'localId': u['id'] as int?,
          'name': u['name'] ?? '',
          'email': u['email'] ?? '',
          'role': u['role'] ?? 'admin',
          'roleLabel': u['role'] == 'admin' ? 'Administrateur' : 'Super Administrateur',
          'schoolId': u['schoolId'] as int?,
          'schoolName': u['schoolName'] ?? '',
          'status': u['status'] ?? 'approved',
          'firestoreId': u['firestoreId'],
          'createdAt': null,
        };
      }).toList();
      _filteredAdmins = _admins;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterAdmins(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredAdmins = List.from(_admins);
      } else {
        _filteredAdmins = _admins.where((a) => 
          (a['name']?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
          (a['email']?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
          (a['schoolName']?.toLowerCase().contains(query.toLowerCase()) ?? false)
        ).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Compter les admins par statut
    final totalAdmins = _admins.length;
    final superAdmins = _admins.where((a) => a['role'] == 'super_admin').length;
    final schoolAdmins = _admins.where((a) => a['role'] == 'admin').length;
    
    return Column(
      children: [
        _buildStatsBar(totalAdmins, superAdmins, schoolAdmins),
        _buildSearchBar(),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredAdmins.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.admin_panel_settings, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty ? "Aucun administrateur" : "Aucun résultat",
                            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                          ),
                          if (_searchQuery.isEmpty)
                            const SizedBox(height: 8),
                          if (_searchQuery.isEmpty)
                            Text(
                              "Cliquez sur 'Ajouter' pour créer un administrateur",
                              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _filteredAdmins.length,
                      itemBuilder: (context, index) {
                        final admin = _filteredAdmins[index];
                        return AdminCard(
                          admin: admin,
                          onRefresh: _loadDataFromFirestore,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildStatsBar(int total, int superAdmins, int schoolAdmins) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.people,
            'Total',
            total,
            Colors.purple,
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey[200],
          ),
          _buildStatItem(
            Icons.admin_panel_settings,
            'Super Admins',
            superAdmins,
            Colors.red,
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.grey[200],
          ),
          _buildStatItem(
            Icons.business,
            'Admins école',
            schoolAdmins,
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, int value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: _filterAdmins,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, email ou école...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder:  OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AddAdminDialog(
                    onAdminAdded: _loadDataFromFirestore,
                  ),
                );
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Ajouter", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
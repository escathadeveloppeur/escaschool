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

  /// 🔥 Charger les admins depuis Firestore
  Future<void> _loadDataFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['admin', 'super_admin'])
          .get();
      
      _admins = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'role': data['role'] ?? 'admin',
          'schoolId': data['schoolId'],
          'firestoreId': doc.id,
        };
      }).toList();
      
      _filteredAdmins = _admins;
      print('✅ ${_admins.length} administrateurs chargés depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement admins: $e');
      // Fallback vers Hive
      final allUsers = await db.getAllUsers();
      _admins = allUsers.where((u) => u['role'] == 'admin' || u['role'] == 'super_admin').toList();
      _filteredAdmins = _admins;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterAdmins(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredAdmins = _admins;
      } else {
        _filteredAdmins = _admins.where((a) => 
          a['name'].toLowerCase().contains(query.toLowerCase()) ||
          a['email'].toLowerCase().contains(query.toLowerCase())
        ).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                hintText: 'Rechercher un administrateur...',
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
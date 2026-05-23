// lib/screens/admin/admin_users.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../providers/auth_provider.dart';
import 'add_user.dart';

class AdminUsers extends StatefulWidget {
  final VoidCallback? onChanged;

  const AdminUsers({super.key, this.onChanged});

  @override
  _AdminUsersState createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> with SingleTickerProviderStateMixin {
  final DBHelper db = DBHelper();
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> filteredUsers = [];
  TextEditingController searchController = TextEditingController();
  late AnimationController _animationController;

  int totalUsers = 0;
  int totalStudents = 0;
  int totalTeachers = 0;
  int totalAdmins = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _loadUsersFromFirestore();
    searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _animationController.dispose();
    searchController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les utilisateurs depuis Firestore
  Future<void> _loadUsersFromFirestore() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;
    final isSuperAdmin = auth.isSuperAdmin;

    try {
      Query query = FirebaseFirestore.instance.collection('users');
      
      if (!isSuperAdmin && schoolId != null) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.get();
      
      final List<Map<String, dynamic>> usersList = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        usersList.add({
          'firestoreId': doc.id,
          'id': data['localId'] ?? 0,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'role': data['role'] ?? 'student',
          'schoolId': data['schoolId'],
        });
      }

      setState(() {
        users = usersList;
        filteredUsers = usersList;
        _updateStats();
      });
      _animationController.forward(from: 0);
      
      print('✅ ${usersList.length} utilisateurs chargés depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement utilisateurs: $e');
      // Fallback vers Hive
      final allUsers = await db.getAllUsers();
      List<Map<String, dynamic>> filteredBySchool = allUsers;
      if (!isSuperAdmin && schoolId != null) {
        filteredBySchool = allUsers.where((user) => user['schoolId'] == schoolId).toList();
      }
      setState(() {
        users = filteredBySchool;
        filteredUsers = filteredBySchool;
        _updateStats();
      });
    }
  }

  void _updateStats() {
    totalUsers = users.length;
    totalStudents = users.where((u) => u['role'] == 'student').length;
    totalTeachers = users.where((u) => u['role'] == 'teacher').length;
    totalAdmins = users.where((u) => u['role'] == 'admin' || u['role'] == 'super_admin').length;
  }

  void _filterUsers() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredUsers = users.where((u) {
        final name = (u['name'] ?? '').toLowerCase();
        final email = (u['email'] ?? '').toLowerCase();
        final role = (u['role'] ?? '').toLowerCase();
        return name.contains(query) || email.contains(query) || role.contains(query);
      }).toList();
    });
  }

  /// 🔥 Supprimer un utilisateur de Firestore
  Future<void> _deleteUser(String firestoreId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Voulez-vous vraiment supprimer cet utilisateur ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)), child: const Text('Supprimer')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(firestoreId).delete();
        await _loadUsersFromFirestore();
        widget.onChanged?.call();
        _showSnackBar('Utilisateur supprimé avec succès', const Color(0xFF10B981));
      } catch (e) {
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
      }
    }
  }

  /// 🔥 Modifier un utilisateur dans Firestore
  Future<void> _updateUser(String firestoreId, Map<String, dynamic> updatedData) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(firestoreId).update(updatedData);
      await _loadUsersFromFirestore();
      widget.onChanged?.call();
      _showSnackBar('Utilisateur modifié avec succès', const Color(0xFF10B981));
    } catch (e) {
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

  void _modifyUser(Map<String, dynamic> user) {
    final TextEditingController nameController = TextEditingController(text: user['name']);
    final TextEditingController emailController = TextEditingController(text: user['email']);
    String role = user['role'];

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person, color: Color(0xFF3B82F6), size: 24)),
                  const SizedBox(width: 12),
                  const Expanded(child: Text("Modifier l'utilisateur", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 20),
              _buildTextField(controller: nameController, label: "Nom complet", icon: Icons.person_outline),
              const SizedBox(height: 12),
              _buildTextField(controller: emailController, label: "Email", icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _buildDropdownForm(
                value: role,
                items: const [
                  {'value': 'student', 'label': 'Étudiant'},
                  {'value': 'teacher', 'label': 'Enseignant'},
                  {'value': 'parent', 'label': 'Parent'},
                  {'value': 'staff', 'label': 'Personnel'},
                  {'value': 'admin', 'label': 'Administrateur'},
                  {'value': 'super_admin', 'label': 'Super Admin'},
                ],
                label: "Rôle",
                icon: Icons.assignment_ind_outlined,
                onChanged: (value) { if (value != null) role = value; },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(onPressed: () => Navigator.pop(context), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Annuler')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await _updateUser(user['firestoreId'], {
                          'name': nameController.text,
                          'email': emailController.text,
                          'role': role,
                        });
                        if (mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Modifier'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'student': return const Color(0xFF10B981);
      case 'teacher': return const Color(0xFF3B82F6);
      case 'parent': return const Color(0xFFF59E0B);
      case 'admin': return const Color(0xFFEF4444);
      case 'super_admin': return const Color(0xFF8B5CF6);
      default: return Colors.grey;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'student': return 'Étudiant';
      case 'teacher': return 'Enseignant';
      case 'parent': return 'Parent';
      case 'staff': return 'Personnel';
      case 'admin': return 'Administrateur';
      case 'super_admin': return 'Super Admin';
      default: return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isSuperAdmin = auth.isSuperAdmin;
    final schoolId = auth.currentSchoolId;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Gestion des utilisateurs', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsersFromFirestore, style: IconButton.styleFrom(backgroundColor: Colors.grey[100])),
        ],
      ),
      body: Column(
        children: [
          if (!isSuperAdmin && schoolId != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [const Icon(Icons.business, size: 18, color: Color(0xFF3B82F6)), const SizedBox(width: 8), Text('Utilisateurs de votre école (${users.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6)))]),
            ),

          FadeTransition(
            opacity: _animationController,
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(Icons.people, "Total", totalUsers, Colors.white),
                  _buildStatItem(Icons.school, "Étudiants", totalStudents, const Color(0xFF10B981)),
                  _buildStatItem(Icons.person, "Enseignants", totalTeachers, const Color(0xFF3B82F6)),
                  _buildStatItem(Icons.admin_panel_settings, "Admins", totalAdmins, const Color(0xFFEF4444)),
                ],
              ),
            ),
          ),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Rechercher...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)),
                suffixIcon: searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { searchController.clear(); _filterUsers(); }) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                filled: true, fillColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text("Liste des utilisateurs", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddUserScreen()));
                    if (result == true) await _loadUsersFromFirestore();
                  },
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: const Text("Ajouter", style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(searchController.text.isEmpty ? "Aucun utilisateur" : "Aucun résultat", style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                        if (searchController.text.isNotEmpty) TextButton(onPressed: () { searchController.clear(); _filterUsers(); }, child: const Text("Effacer la recherche")),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredUsers.length,
                    itemBuilder: (_, i) {
                      final u = filteredUsers[i];
                      final roleColor = _getRoleColor(u['role']);
                      final roleLabel = _getRoleLabel(u['role']);
                      return FadeTransition(
                        opacity: _animationController,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(gradient: LinearGradient(colors: [roleColor, roleColor.withOpacity(0.7)]), shape: BoxShape.circle),
                              child: Center(child: Text(u['name']?.isNotEmpty == true ? u['name'][0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                            ),
                            title: Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(u['email'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: roleColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Text(roleLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: roleColor)),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: IconButton(icon: const Icon(Icons.edit, color: Color(0xFF3B82F6), size: 20), onPressed: () => _modifyUser(u)),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: IconButton(icon: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 20), onPressed: () => _deleteUser(u['firestoreId'])),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, int count, Color color) {
    return Column(
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 6),
        Text(count.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, TextInputType keyboardType = TextInputType.text, bool obscureText = false}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
        prefixIcon: Icon(icon, color: const Color(0xFF10B981)),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdownForm({required String value, required List<Map<String, String>> items, required String label, required IconData icon, required Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((item) => DropdownMenuItem(value: item['value'], child: Text(item['label']!))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
        prefixIcon: Icon(icon, color: const Color(0xFF10B981)),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
// lib/screens/admin/admin_users.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../providers/auth_provider.dart';
import 'add_user.dart';

// ===================== PALETTE / THEME HELPERS =====================
class _AppColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B5BDB);
  static const Color background = Color(0xFFF4F6FB);
  static const Color cardBorder = Color(0xFFE6E9F2);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
}

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
  int totalPending = 0;

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
          'status': data['status'] ?? 'pending',
          'createdAt': data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
        });
      }

      setState(() {
        users = usersList;
        filteredUsers = usersList;
        _updateStats();
      });
      _animationController.forward(from: 0);
      
      print('✅ ${usersList.length} utilisateurs chargés');
    } catch (e) {
      print('❌ Erreur chargement utilisateurs: $e');
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
    totalPending = users.where((u) => u['status'] == 'pending' || u['status'] == 'pending_super_admin').length;
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

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    final isCurrentlyActive = user['status'] == 'approved';
    final newStatus = isCurrentlyActive ? 'suspended' : 'approved';
    final action = isCurrentlyActive ? 'suspendre' : 'activer';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isCurrentlyActive ? 'Suspendre le compte' : 'Activer le compte',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Voulez-vous vraiment $action le compte de ${user['name']} ?\n\n'
          '${isCurrentlyActive ? 'L\'utilisateur ne pourra plus se connecter.' : 'L\'utilisateur pourra à nouveau se connecter.'}',
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: _AppColors.textMuted),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentlyActive ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isCurrentlyActive ? 'Suspendre' : 'Activer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user['firestoreId'])
            .update({
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        await _loadUsersFromFirestore();
        widget.onChanged?.call();
        _showSnackBar(
          'Compte ${isCurrentlyActive ? 'suspendu' : 'activé'} avec succès',
          isCurrentlyActive ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
        );
      } catch (e) {
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
      }
    }
  }

  Future<void> _approveUser(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Approuver le compte', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment approuver le compte de ${user['name']} ?\n\nL\'utilisateur pourra se connecter immédiatement.'),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: _AppColors.textMuted),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Approuver'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user['firestoreId'])
            .update({
          'status': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        await _loadUsersFromFirestore();
        widget.onChanged?.call();
        _showSnackBar('Compte approuvé avec succès', const Color(0xFF10B981));
      } catch (e) {
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
      }
    }
  }

  Future<void> _deleteUser(String firestoreId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Voulez-vous vraiment supprimer cet utilisateur ?'),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: _AppColors.textMuted),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Supprimer'),
          ),
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
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_rounded, color: Color(0xFF3B82F6), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text("Modifier l'utilisateur", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: nameController,
                label: "Nom complet",
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: emailController,
                label: "Email",
                icon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
              ),
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
                icon: Icons.assignment_ind_rounded,
                onChanged: (value) { if (value != null) role = value; },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: _AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Annuler'),
                    ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved': return const Color(0xFF10B981);
      case 'pending': return const Color(0xFFF59E0B);
      case 'pending_super_admin': return const Color(0xFFF59E0B);
      case 'suspended': return const Color(0xFFEF4444);
      case 'rejected': return const Color(0xFFEF4444);
      default: return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'approved': return 'Actif';
      case 'pending': return 'En attente (école)';
      case 'pending_super_admin': return 'En attente (Super Admin)';
      case 'suspended': return 'Suspendu';
      case 'rejected': return 'Rejeté';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isSuperAdmin = auth.isSuperAdmin;
    final schoolId = auth.currentSchoolId;

    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Gestion des utilisateurs',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19, letterSpacing: 0.2),
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
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: "Actualiser",
              onPressed: _loadUsersFromFirestore,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!isSuperAdmin && schoolId != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business_rounded, size: 18, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Text(
                    'Utilisateurs de votre école (${users.length})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6)),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Statistiques
          FadeTransition(
            opacity: _animationController,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(Icons.people_rounded, "Total", totalUsers, Colors.white),
                  _buildStatItem(Icons.school_rounded, "Étudiants", totalStudents, const Color(0xFF10B981)),
                  _buildStatItem(Icons.person_rounded, "Enseignants", totalTeachers, const Color(0xFF3B82F6)),
                  _buildStatItem(Icons.admin_panel_settings_rounded, "Admins", totalAdmins, const Color(0xFFEF4444)),
                  _buildStatItem(Icons.pending_actions_rounded, "En attente", totalPending, const Color(0xFFF59E0B)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Barre de recherche
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Rechercher un utilisateur...",
                hintStyle: TextStyle(color: _AppColors.textMuted),
                prefixIcon: Icon(Icons.search_rounded, color: _AppColors.primaryLight),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: _AppColors.textMuted),
                        onPressed: () {
                          searchController.clear();
                          _filterUsers();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: _AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: _AppColors.primaryLight, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // En-tête liste
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.people_rounded, size: 18, color: _AppColors.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  "Liste des utilisateurs (${filteredUsers.length})",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _AppColors.textDark),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddUserScreen()),
                    );
                    if (result == true) await _loadUsersFromFirestore();
                  },
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  label: const Text("Ajouter", style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Liste des utilisateurs
          Expanded(
            child: filteredUsers.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filteredUsers.length,
                    itemBuilder: (_, i) {
                      final u = filteredUsers[i];
                      return FadeTransition(
                        opacity: _animationController,
                        child: _buildUserCard(u),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    bool hasSearch = searchController.text.isNotEmpty;
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
            child: Icon(
              hasSearch ? Icons.search_off_rounded : Icons.people_outline_rounded,
              size: 56,
              color: _AppColors.primary.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            hasSearch ? "Aucun résultat trouvé" : "Aucun utilisateur",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _AppColors.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch ? "Essayez avec d'autres termes" : "Commencez par ajouter des utilisateurs",
            style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
          ),
          if (hasSearch)
            const SizedBox(height: 16),
          if (hasSearch)
            TextButton(
              onPressed: () {
                searchController.clear();
                _filterUsers();
              },
              style: TextButton.styleFrom(foregroundColor: _AppColors.primary),
              child: const Text('Effacer la recherche'),
            ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final roleColor = _getRoleColor(user['role']);
    final roleLabel = _getRoleLabel(user['role']);
    final statusColor = _getStatusColor(user['status']);
    final statusLabel = _getStatusLabel(user['status']);
    final isPending = user['status'] == 'pending' || user['status'] == 'pending_super_admin';
    final isActive = user['status'] == 'approved';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [roleColor, roleColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user['name']?.isNotEmpty == true ? user['name'][0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 14),
            
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user['name'] ?? '',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _AppColors.textDark),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user['email'] ?? '',
                    style: TextStyle(fontSize: 12, color: _AppColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      roleLabel,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: roleColor),
                    ),
                  ),
                ],
              ),
            ),
            
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPending)
                  _buildActionButton(
                    icon: Icons.check_circle_rounded,
                    color: const Color(0xFF10B981),
                    onPressed: () => _approveUser(user),
                    tooltip: 'Approuver',
                  ),
                _buildActionButton(
                  icon: isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                  color: isActive ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                  onPressed: () => _toggleUserStatus(user),
                  tooltip: isActive ? 'Suspendre' : 'Activer',
                ),
                _buildActionButton(
                  icon: Icons.edit_rounded,
                  color: const Color(0xFF3B82F6),
                  onPressed: () => _modifyUser(user),
                  tooltip: 'Modifier',
                ),
                _buildActionButton(
                  icon: Icons.delete_rounded,
                  color: const Color(0xFFEF4444),
                  onPressed: () => _deleteUser(user['firestoreId']),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onPressed, required String tooltip}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 18),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          count.toString(),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _AppColors.cardBorder),
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF10B981)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdownForm({
    required String value,
    required List<Map<String, String>> items,
    required String label,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((item) => DropdownMenuItem(
        value: item['value'],
        child: Text(item['label']!),
      )).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _AppColors.cardBorder),
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF10B981)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
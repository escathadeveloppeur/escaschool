// lib/screens/admin/admin_professors.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../providers/auth_provider.dart';
import 'admin_schedule.dart';
import 'professor_permissions.dart';

class AdminProfessors extends StatefulWidget {
  final VoidCallback onChanged;
  
  const AdminProfessors({super.key, required this.onChanged});

  @override
  _AdminProfessorsState createState() => _AdminProfessorsState();
}

class _AdminProfessorsState extends State<AdminProfessors> with SingleTickerProviderStateMixin {
  final DBHelper db = DBHelper();
  List<Map<String, dynamic>> _professors = [];
  List<Map<String, dynamic>> _filteredProfessors = [];
  List<Map<String, dynamic>> _availableUsers = [];
  bool _loading = true;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _specialtyController = TextEditingController();
  Map<String, dynamic>? _selectedUser;
  String _selectedStatus = 'active';
  bool _isEditing = false;
  String? _editingFirestoreId;
  
  late AnimationController _animationController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadData();
    _searchController.addListener(_filterProfessors);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _specialtyController.dispose();
    super.dispose();
  }

  void _filterProfessors() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProfessors = List.from(_professors);
      } else {
        _filteredProfessors = _professors.where((prof) {
          final fullName = (prof['fullName'] ?? '').toLowerCase();
          final specialty = (prof['specialty'] ?? '').toLowerCase();
          final email = (prof['userEmail'] ?? '').toLowerCase();
          return fullName.contains(query) || specialty.contains(query) || email.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║     CHARGEMENT DES PROFESSEURS                             ║');
    print('╚════════════════════════════════════════════════════════════╝\n');
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      print('📌 School ID: $schoolId');
      print('📌 Super Admin: ${auth.isSuperAdmin}\n');
      
      Query query = FirebaseFirestore.instance.collection('professors');
      if (!auth.isSuperAdmin && schoolId != null) {
        query = query.where('schoolId', isEqualTo: schoolId);
        print('🔍 Filtre: schoolId == $schoolId');
      }
      
      final professorsSnapshot = await query.get();
      print('📊 ${professorsSnapshot.docs.length} professeur(s) trouvé(s)');
      
      final List<Map<String, dynamic>> professorsList = [];
      for (var doc in professorsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        professorsList.add({
          'firestoreId': doc.id,
          'userId': data['userId'],
          'userEmail': data['userEmail'],
          'fullName': data['fullName'] ?? '',
          'phone': data['phone'] ?? '',
          'specialty': data['specialty'] ?? '',
          'status': data['status'] ?? 'active',
          'schoolId': data['schoolId'],
        });
        print('   ✅ ${data['fullName']} (ID: ${doc.id})');
      }
      
      print('\n🔍 Chargement des comptes utilisateurs disponibles...');
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .get();
      
      final existingUserIds = professorsList.map((p) => p['userId']).toList();
      
      _availableUsers = [];
      for (var doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (!existingUserIds.contains(doc.id)) {
          _availableUsers.add({
            'userId': doc.id,
            'email': data['email'] ?? '',
            'name': data['name'] ?? '',
          });
          print('   📧 Compte disponible: ${data['email']}');
        }
      }
      
      setState(() {
        _professors = professorsList;
        _filteredProfessors = professorsList;
        _loading = false;
      });
      _animationController.forward(from: 0);
      
      print('\n✅ ${professorsList.length} professeurs, ${_availableUsers.length} comptes disponibles\n');
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() => _loading = false);
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

  /// 🔥 Ajouter un professeur - UTILISE L'UID AUTH COMME DOCUMENT ID
  Future<void> _addProfessor() async {
    if (_formKey.currentState!.validate() && _selectedUser != null) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      // CRUCIAL: Utiliser l'UID Auth comme document ID
      final professorId = _selectedUser!['userId'];
      
      print('\n🔐 AJOUT PROFESSEUR');
      print('   → ID Document: $professorId (UID Auth)');
      print('   → Nom: ${_fullNameController.text.trim()}');
      print('   → Email: ${_selectedUser!['email']}');
      
      final professorData = {
        'userId': _selectedUser!['userId'],
        'userEmail': _selectedUser!['email'],
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'specialty': _specialtyController.text.trim(),
        'status': _selectedStatus,
        'schoolId': schoolId,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      try {
        // Utiliser .set() avec l'UID comme ID au lieu de .add()
        await FirebaseFirestore.instance
            .collection('professors')
            .doc(professorId)
            .set(professorData);
        
        await db.addLog("Ajout du professeur: ${_fullNameController.text}");
        
        _clearForm();
        await _loadData();
        widget.onChanged();
        
        _showSnackBar('Professeur ajouté avec succès', const Color(0xFF10B981));
        print('✅ Professeur créé avec ID: $professorId');
      } catch (e) {
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
        print('❌ Erreur création professeur: $e');
      }
    } else if (_selectedUser == null) {
      _showSnackBar('Veuillez sélectionner un compte utilisateur', const Color(0xFFF59E0B));
    }
  }

  /// 🔥 Modifier un professeur
  Future<void> _updateProfessor() async {
    if (_formKey.currentState!.validate() && _editingFirestoreId != null) {
      print('\n✏️ MODIFICATION PROFESSEUR');
      print('   → ID: $_editingFirestoreId');
      print('   → Nouveau nom: ${_fullNameController.text.trim()}');
      
      final professorData = {
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'specialty': _specialtyController.text.trim(),
        'status': _selectedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      try {
        await FirebaseFirestore.instance
            .collection('professors')
            .doc(_editingFirestoreId)
            .update(professorData);
        
        await db.addLog("Modification du professeur: ${_fullNameController.text}");
        
        _clearForm();
        await _loadData();
        widget.onChanged();
        
        _showSnackBar('Professeur modifié avec succès', const Color(0xFF10B981));
        print('✅ Professeur modifié');
      } catch (e) {
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
        print('❌ Erreur modification: $e');
      }
    }
  }

  /// 🔥 Supprimer un professeur
  Future<void> _deleteProfessor(String firestoreId, String name) async {
    print('\n🗑️ SUPPRESSION PROFESSEUR');
    print('   → ID: $firestoreId');
    print('   → Nom: $name');
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Voulez-vous vraiment supprimer le professeur $name ?\n\nLe compte utilisateur reste intact."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('professors')
            .doc(firestoreId)
            .delete();
        
        await db.addLog("Suppression du professeur: $name");
        await _loadData();
        widget.onChanged();
        _showSnackBar('Professeur supprimé', const Color(0xFF10B981));
        print('✅ Professeur supprimé');
      } catch (e) {
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
        print('❌ Erreur suppression: $e');
      }
    }
  }

  void _clearForm() {
    _fullNameController.clear();
    _phoneController.clear();
    _specialtyController.clear();
    _selectedUser = null;
    _selectedStatus = 'active';
    _isEditing = false;
    _editingFirestoreId = null;
    setState(() {});
  }

  void _editProfessor(Map<String, dynamic> professor) {
    print('\n✏️ ÉDITION PROFESSEUR: ${professor['fullName']}');
    _fullNameController.text = professor['fullName'] ?? '';
    _phoneController.text = professor['phone'] ?? '';
    _specialtyController.text = professor['specialty'] ?? '';
    _selectedStatus = professor['status'] ?? 'active';
    _isEditing = true;
    _editingFirestoreId = professor['firestoreId'];
    setState(() {});
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active': return 'Actif';
      case 'inactive': return 'Inactif';
      case 'vacation': return 'Vacances';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active': return const Color(0xFF10B981);
      case 'inactive': return const Color(0xFFEF4444);
      case 'vacation': return const Color(0xFFF59E0B);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Gestion des professeurs', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            style: IconButton.styleFrom(backgroundColor: Colors.grey[100]),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))))
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher un professeur...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); _filterProfessors(); })
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                  
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Icon(_isEditing ? Icons.edit : Icons.person_add, color: const Color(0xFF10B981), size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _isEditing ? 'Modifier le professeur' : 'Ajouter un professeur',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            if (!_isEditing)
                              DropdownButtonFormField<Map<String, dynamic>>(
                                value: _selectedUser,
                                hint: const Text('Sélectionner un compte utilisateur *'),
                                decoration: InputDecoration(
                                  labelText: "Compte utilisateur",
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  prefixIcon: const Icon(Icons.account_circle, color: Color(0xFF10B981)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: _availableUsers.map((user) {
                                  return DropdownMenuItem(
                                    value: user,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(user['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                        Text(user['email'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedUser = value;
                                    if (value != null && _fullNameController.text.isEmpty) {
                                      _fullNameController.text = value['name'];
                                    }
                                  });
                                },
                                validator: (value) => value == null ? 'Compte requis' : null,
                              ),
                            
                            if (!_isEditing && _availableUsers.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning, size: 16, color: Color(0xFFF59E0B)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Aucun compte enseignant disponible",
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            
                            if (!_isEditing) const SizedBox(height: 12),
                            
                            TextFormField(
                              controller: _fullNameController,
                              decoration: InputDecoration(
                                labelText: "Nom complet *",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                prefixIcon: const Icon(Icons.badge, color: Color(0xFF10B981)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (value) => value!.isEmpty ? 'Champ requis' : null,
                            ),
                            const SizedBox(height: 12),
                            
                            TextFormField(
                              controller: _phoneController,
                              decoration: InputDecoration(
                                labelText: "Téléphone",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                prefixIcon: const Icon(Icons.phone, color: Color(0xFF10B981)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            TextFormField(
                              controller: _specialtyController,
                              decoration: InputDecoration(
                                labelText: "Spécialité",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                prefixIcon: const Icon(Icons.science, color: Color(0xFF10B981)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            DropdownButtonFormField<String>(
                              value: _selectedStatus,
                              items: const [
                                DropdownMenuItem(value: 'active', child: Text('Actif')),
                                DropdownMenuItem(value: 'inactive', child: Text('Inactif')),
                                DropdownMenuItem(value: 'vacation', child: Text('Vacances')),
                              ],
                              onChanged: (value) => setState(() => _selectedStatus = value!),
                              decoration: InputDecoration(
                                labelText: "Statut",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                prefixIcon: const Icon(Icons.toggle_on, color: Color(0xFF10B981)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isEditing ? _updateProfessor : _addProfessor,
                                    icon: Icon(_isEditing ? Icons.save : Icons.add),
                                    label: Text(_isEditing ? 'Modifier' : 'Ajouter'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _clearForm,
                                    icon: const Icon(Icons.clear),
                                    label: const Text('Effacer'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: BorderSide(color: Colors.grey[300]!),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.people, color: Color(0xFF3B82F6), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Liste des professeurs (${_filteredProfessors.length})",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: _filteredProfessors.length,
                    itemBuilder: (context, index) {
                      final prof = _filteredProfessors[index];
                      final statusColor = _getStatusColor(prof['status']);
                      final statusLabel = _getStatusLabel(prof['status']);
                      
                      return FadeTransition(
                        opacity: _animationController,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]), shape: BoxShape.circle),
                              child: const Center(child: Icon(Icons.person, color: Colors.white, size: 28)),
                            ),
                            title: Text(prof['fullName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (prof['specialty']?.isNotEmpty ?? false)
                                  Text('📚 ${prof['specialty']}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                if (prof['userEmail']?.isNotEmpty ?? false)
                                  Text('🔑 ${prof['userEmail']}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: statusColor)),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildActionButton(icon: Icons.schedule, color: const Color(0xFF3B82F6), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AdminSchedule(professorFirestoreId: prof['firestoreId'], professorName: prof['fullName']))), tooltip: 'Gérer horaires'),
                                _buildActionButton(icon: Icons.security, color: const Color(0xFF8B5CF6), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfessorPermissionsScreen(professorFirestoreId: prof['firestoreId'], professorName: prof['fullName']))), tooltip: 'Gérer permissions'),
                                _buildActionButton(icon: Icons.edit, color: const Color(0xFFF59E0B), onPressed: () => _editProfessor(prof), tooltip: 'Modifier'),
                                _buildActionButton(icon: Icons.delete, color: const Color(0xFFEF4444), onPressed: () => _deleteProfessor(prof['firestoreId'], prof['fullName']), tooltip: 'Supprimer'),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onPressed, required String tooltip}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: IconButton(icon: Icon(icon, color: color, size: 20), onPressed: onPressed, tooltip: tooltip),
    );
  }
}
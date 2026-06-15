// lib/screens/admin/admin_professors.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../providers/auth_provider.dart';
import 'admin_schedule.dart';
import 'professor_permissions.dart';

// ===================== PALETTE / THEME HELPERS =====================
class _AppColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B5BDB);
  static const Color background = Color(0xFFF4F6FB);
  static const Color cardBorder = Color(0xFFE6E9F2);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
}

// ===================== WIDGET CARTE PROFESSEUR =====================
class _ProfessorCard extends StatelessWidget {
  final Map<String, dynamic> professor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSchedule;
  final VoidCallback onPermissions;
  final VoidCallback? onSetHomeroom;
  final VoidCallback? onRemoveHomeroom;
  final Animation<double> animation;

  const _ProfessorCard({
    required this.professor,
    required this.onEdit,
    required this.onDelete,
    required this.onSchedule,
    required this.onPermissions,
    this.onSetHomeroom,
    this.onRemoveHomeroom,
    required this.animation,
  });

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

  @override
  Widget build(BuildContext context) {
    final isHomeroom = professor['isHomeroomTeacher'] == true;
    final statusColor = _getStatusColor(professor['status']);
    final statusLabel = _getStatusLabel(professor['status']);

    return FadeTransition(
      opacity: animation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isHomeroom 
              ? Border.all(color: const Color(0xFF8B5CF6), width: 1.5)
              : Border.all(color: _AppColors.cardBorder),
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
                  gradient: isHomeroom 
                      ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)])
                      : const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.person_rounded, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 14),

              // Informations
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            professor['fullName'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _AppColors.textDark),
                          ),
                        ),
                        if (isHomeroom)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, size: 10, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Titulaire', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (professor['specialty']?.isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            Icon(Icons.science_rounded, size: 12, color: _AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(professor['specialty'], style: const TextStyle(fontSize: 11, color: _AppColors.textMuted)),
                          ],
                        ),
                      ),
                    if (professor['userEmail']?.isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            Icon(Icons.email_rounded, size: 12, color: _AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(professor['userEmail'], style: const TextStyle(fontSize: 10, color: _AppColors.textMuted)),
                          ],
                        ),
                      ),
                    if (isHomeroom && professor['homeroomClassName'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.school_rounded, size: 12, color: const Color(0xFF8B5CF6)),
                            const SizedBox(width: 4),
                            Text(
                              'Titulaire: ${professor['homeroomClassName']}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF8B5CF6), fontWeight: FontWeight.w500),
                            ),
                          ],
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
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                      ),
                    ),
                  ],
                ),
              ),

              // Boutons d'action
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isHomeroom && onSetHomeroom != null)
                    _buildActionButton(
                      icon: Icons.star_rounded,
                      color: const Color(0xFF8B5CF6),
                      onPressed: onSetHomeroom!,
                      tooltip: 'Nommer titulaire',
                    ),
                  if (isHomeroom && onRemoveHomeroom != null)
                    _buildActionButton(
                      icon: Icons.star_border_rounded,
                      color: const Color(0xFFF59E0B),
                      onPressed: onRemoveHomeroom!,
                      tooltip: 'Retirer titulaire',
                    ),
                  _buildActionButton(
                    icon: Icons.schedule_rounded,
                    color: const Color(0xFF3B82F6),
                    onPressed: onSchedule,
                    tooltip: 'Gérer horaires',
                  ),
                  _buildActionButton(
                    icon: Icons.security_rounded,
                    color: const Color(0xFF8B5CF6),
                    onPressed: onPermissions,
                    tooltip: 'Gérer permissions',
                  ),
                  _buildActionButton(
                    icon: Icons.edit_rounded,
                    color: const Color(0xFFF59E0B),
                    onPressed: onEdit,
                    tooltip: 'Modifier',
                  ),
                  _buildActionButton(
                    icon: Icons.delete_rounded,
                    color: const Color(0xFFEF4444),
                    onPressed: onDelete,
                    tooltip: 'Supprimer',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== WIDGET PRINCIPAL =====================
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
  List<Map<String, dynamic>> _availableClasses = [];
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
    _loadClasses();
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

  Future<void> _loadClasses() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      Query query = FirebaseFirestore.instance.collection('classes');
      if (!auth.isSuperAdmin && schoolId != null) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.get();
      _availableClasses = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'className': data['className'] ?? '',
          'level': data['level'] ?? '',
          'year': data['year'] ?? '',
        };
      }).toList();
      
      print('✅ ${_availableClasses.length} classes disponibles');
    } catch (e) {
      print('❌ Erreur chargement classes: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      Query query = FirebaseFirestore.instance.collection('professors');
      if (!auth.isSuperAdmin && schoolId != null) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final professorsSnapshot = await query.get();
      
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
          'isHomeroomTeacher': data['isHomeroomTeacher'] ?? false,
          'homeroomClassId': data['homeroomClassId'],
          'homeroomClassName': data['homeroomClassName'],
        });
      }
      
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
        }
      }
      
      setState(() {
        _professors = professorsList;
        _filteredProfessors = professorsList;
        _loading = false;
      });
      _animationController.forward(from: 0);
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

  Future<void> _setAsHomeroomTeacher(String professorId, String professorName, String classFirestoreId, String className) async {
    try {
      await FirebaseFirestore.instance
          .collection('professors')
          .doc(professorId)
          .update({
        'isHomeroomTeacher': true,
        'homeroomClassId': classFirestoreId,
        'homeroomClassName': className,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      final existingPerm = await FirebaseFirestore.instance
          .collection('professor_permissions')
          .where('professorFirestoreId', isEqualTo: professorId)
          .where('classFirestoreId', isEqualTo: classFirestoreId)
          .get();
      
      if (existingPerm.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('professor_permissions').add({
          'professorFirestoreId': professorId,
          'classFirestoreId': classFirestoreId,
          'className': className,
          'permissionType': 'full',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await existingPerm.docs.first.reference.update({
          'permissionType': 'full',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await _loadData();
      widget.onChanged();
      _showSnackBar('$professorName est maintenant titulaire de $className', const Color(0xFF8B5CF6));
    } catch (e) {
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    }
  }

  Future<void> _removeHomeroomTeacher(String professorId, String professorName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Retirer le statut de titulaire', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Voulez-vous vraiment retirer le statut de titulaire à $professorName ?"),
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
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('professors')
            .doc(professorId)
            .update({
          'isHomeroomTeacher': false,
          'homeroomClassId': null,
          'homeroomClassName': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        await _loadData();
        widget.onChanged();
        _showSnackBar('$professorName n\'est plus titulaire', const Color(0xFFF59E0B));
      } catch (e) {
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
      }
    }
  }

  void _showHomeroomDialog(Map<String, dynamic> professor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.star_rounded, color: Color(0xFF8B5CF6)),
            ),
            const SizedBox(width: 12),
            const Text('Nommer professeur titulaire', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sélectionnez la classe dont ${professor['fullName']} sera titulaire :'),
            const SizedBox(height: 16),
            ..._availableClasses.map((classItem) {
              return ListTile(
                leading: const Icon(Icons.class_rounded, color: Color(0xFF8B5CF6)),
                title: Text(classItem['className'], style: TextStyle(color: _AppColors.textDark)),
                subtitle: Text('${classItem['level']} - ${classItem['year']}', style: TextStyle(color: _AppColors.textMuted)),
                onTap: () {
                  Navigator.pop(context);
                  _setAsHomeroomTeacher(
                    professor['firestoreId'],
                    professor['fullName'],
                    classItem['firestoreId'],
                    classItem['className'],
                  );
                },
              );
            }).toList(),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _AppColors.textMuted),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Future<void> _addProfessor() async {
    if (_formKey.currentState!.validate() && _selectedUser != null) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      final professorData = {
        'userId': _selectedUser!['userId'],
        'userEmail': _selectedUser!['email'],
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'specialty': _specialtyController.text.trim(),
        'status': _selectedStatus,
        'schoolId': schoolId,
        'isHomeroomTeacher': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      try {
        await FirebaseFirestore.instance
            .collection('professors')
            .doc(_selectedUser!['userId'])
            .set(professorData);
        
        await db.addLog("Ajout du professeur: ${_fullNameController.text}");
        _clearForm();
        await _loadData();
        widget.onChanged();
        _showSnackBar('Professeur ajouté avec succès', const Color(0xFF10B981));
      } catch (e) {
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
      }
    } else if (_selectedUser == null) {
      _showSnackBar('Veuillez sélectionner un compte utilisateur', const Color(0xFFF59E0B));
    }
  }

  Future<void> _updateProfessor() async {
    if (_formKey.currentState!.validate() && _editingFirestoreId != null) {
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
      } catch (e) {
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
      }
    }
  }

  Future<void> _deleteProfessor(String firestoreId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Voulez-vous vraiment supprimer le professeur $name ?\n\nLe compte utilisateur reste intact."),
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
        final permissions = await FirebaseFirestore.instance
            .collection('professor_permissions')
            .where('professorFirestoreId', isEqualTo: firestoreId)
            .get();
        
        for (var perm in permissions.docs) {
          await perm.reference.delete();
        }
        
        await FirebaseFirestore.instance
            .collection('professors')
            .doc(firestoreId)
            .delete();
        
        await db.addLog("Suppression du professeur: $name");
        await _loadData();
        widget.onChanged();
        _showSnackBar('Professeur supprimé', const Color(0xFF10B981));
      } catch (e) {
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
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
    _fullNameController.text = professor['fullName'] ?? '';
    _phoneController.text = professor['phone'] ?? '';
    _specialtyController.text = professor['specialty'] ?? '';
    _selectedStatus = professor['status'] ?? 'active';
    _isEditing = true;
    _editingFirestoreId = professor['firestoreId'];
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Gestion des professeurs',
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
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Actualiser",
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_AppColors.primary),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  
                  // Barre de recherche
                  _buildSearchBar(),
                  
                  const SizedBox(height: 16),
                  
                  // Formulaire
                  _buildForm(),
                  
                  const SizedBox(height: 20),
                  
                  // En-tête liste
                  _buildListHeader(),
                  
                  const SizedBox(height: 12),
                  
                  // Liste des professeurs
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _filteredProfessors.length,
                    itemBuilder: (context, index) {
                      final prof = _filteredProfessors[index];
                      final isHomeroom = prof['isHomeroomTeacher'] == true;
                      
                      return _ProfessorCard(
                        professor: prof,
                        animation: _animationController,
                        onEdit: () => _editProfessor(prof),
                        onDelete: () => _deleteProfessor(prof['firestoreId'], prof['fullName']),
                        onSchedule: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminSchedule(
                              professorFirestoreId: prof['firestoreId'],
                              professorName: prof['fullName'],
                            ),
                          ),
                        ),
                        onPermissions: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfessorPermissionsScreen(
                              professorFirestoreId: prof['firestoreId'],
                              professorName: prof['fullName'],
                            ),
                          ),
                        ),
                        onSetHomeroom: !isHomeroom ? () => _showHomeroomDialog(prof) : null,
                        onRemoveHomeroom: isHomeroom ? () => _removeHomeroomTeacher(prof['firestoreId'], prof['fullName']) : null,
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher un professeur...',
          hintStyle: TextStyle(color: _AppColors.textMuted),
          prefixIcon: Icon(Icons.search_rounded, color: _AppColors.primaryLight),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: _AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    _filterProfessors();
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
    );
  }

  Widget _buildForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                      color: const Color(0xFF10B981),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _isEditing ? 'Modifier le professeur' : 'Ajouter un professeur',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _AppColors.textDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              if (!_isEditing)
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedUser,
                  hint: Text('Sélectionner un compte utilisateur *', style: TextStyle(color: _AppColors.textMuted)),
                  decoration: InputDecoration(
                    labelText: "Compte utilisateur",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    prefixIcon: Icon(Icons.account_circle_rounded, color: const Color(0xFF10B981)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _availableUsers.map((user) {
                    return DropdownMenuItem(
                      value: user,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user['name'], style: TextStyle(fontWeight: FontWeight.w600, color: _AppColors.textDark)),
                          Text(user['email'], style: TextStyle(fontSize: 12, color: _AppColors.textMuted)),
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
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded, size: 18, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Aucun compte enseignant disponible",
                          style: TextStyle(fontSize: 12, color: _AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              
              if (!_isEditing) const SizedBox(height: 12),
              
              TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: "Nom complet *",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: Icon(Icons.badge_rounded, color: const Color(0xFF10B981)),
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
                  prefixIcon: Icon(Icons.phone_rounded, color: const Color(0xFF10B981)),
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
                  prefixIcon: Icon(Icons.science_rounded, color: const Color(0xFF10B981)),
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
                  prefixIcon: Icon(Icons.toggle_on_rounded, color: const Color(0xFF10B981)),
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
                      icon: Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded),
                      label: Text(_isEditing ? 'Modifier' : 'Ajouter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearForm,
                      icon: const Icon(Icons.clear_rounded),
                      label: const Text('Effacer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: _AppColors.cardBorder),
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
    );
  }

  Widget _buildListHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
            "Liste des professeurs (${_filteredProfessors.length})",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _AppColors.textDark),
          ),
        ],
      ),
    );
  }
}
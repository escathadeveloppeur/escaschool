// lib/screens/staff/manage_staff_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../services/staff_service.dart';
import '../../services/payment_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/staff_model.dart';
import 'add_staff_screen.dart';
import 'staff_payments_screen.dart';
import 'staff_card_management_screen.dart';

class ManageStaffScreen extends StatefulWidget {
  const ManageStaffScreen({super.key});

  @override
  _ManageStaffScreenState createState() => _ManageStaffScreenState();
}

class _ManageStaffScreenState extends State<ManageStaffScreen> with SingleTickerProviderStateMixin {
  final DBHelper db = DBHelper();
  final StaffService _staffService = StaffService();
  List<StaffModel> _staffList = [];
  List<StaffModel> _filteredStaff = [];
  List<StaffModel> _teachers = [];
  bool _isLoading = true;
  bool _showTeachers = false;
  String _searchQuery = '';
  String _selectedPosition = 'Tous';
  late AnimationController _animationController;

  final List<String> _positions = [
    'Tous',
    'Professeur',
    'Ménage',
    'Sentinelle / Sécurité',
    'Chauffeur',
    'Cuisinier',
    'Jardinier',
    'Infirmier',
    'Bibliothécaire',
    'Secrétaire',
    'Comptable',
    'Magasinier',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadAllData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    
    try {
      await Future.wait([
        _loadStaffFromFirestore(),
        _loadTeachers(),
      ]);
      
      _filterStaff();
      _animationController.forward(from: 0);
    } catch (e) {
      print('Erreur chargement données: $e');
      _showSnackBar('Erreur de chargement', const Color(0xFFEF4444));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// ✅ Charger tout le personnel directement depuis Firestore
  Future<void> _loadStaffFromFirestore() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final String? schoolId = auth.currentSchoolId;

      if (schoolId == null || schoolId.isEmpty) {
        _staffList = [];
        return;
      }

      // 🔥 Récupérer tous les membres du personnel depuis Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      _staffList = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StaffModel(
          id: data['localId'],
          firestoreId: doc.id,
          fullName: data['fullName'] ?? '',
          position: data['position'] ?? '',
          phone: data['phone'],
          email: data['email'],
          address: data['address'],
          hireDate: data['hireDate'] != null ? DateTime.parse(data['hireDate']) : DateTime.now(),
          salary: (data['salary'] ?? 0.0).toDouble(),
          isActive: data['isActive'] ?? true,
          schoolId: data['schoolId'] ?? schoolId,
          createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
          updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
        );
      }).toList();

      print('✅ ${_staffList.length} personnels chargés depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement personnel: $e');
      throw e;
    }
  }

  /// ✅ Charger les professeurs depuis Firestore
  Future<void> _loadTeachers() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final String? schoolId = auth.currentSchoolId;
      
      if (schoolId == null || schoolId.isEmpty) {
        _teachers = [];
        return;
      }

      final teachersSnapshot = await FirebaseFirestore.instance
          .collection('teachers')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      
      _teachers = teachersSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StaffModel.fromFirestore(data, doc.id);
      }).toList();
      
      print('✅ ${_teachers.length} professeurs chargés');
    } catch (e) {
      print('❌ Erreur chargement professeurs: $e');
      throw e;
    }
  }

  void _filterStaff() {
    setState(() {
      List<StaffModel> combinedList = [];
      
      if (_showTeachers) {
        combinedList = _teachers;
      } else {
        combinedList = _staffList;
      }
      
      _filteredStaff = combinedList.where((staff) {
        final matchesSearch = _searchQuery.isEmpty ||
            staff.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            staff.position.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (staff.phone?.contains(_searchQuery) ?? false);
        
        final matchesPosition = _selectedPosition == 'Tous' ||
            staff.position == _selectedPosition;
        
        return matchesSearch && matchesPosition;
      }).toList();
    });
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

  Future<void> _deleteStaff(StaffModel staff) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment supprimer ${staff.fullName} ?'),
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
        // ✅ Supprimer directement de Firestore
        if (staff.firestoreId != null && staff.firestoreId!.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('staff')
              .doc(staff.firestoreId)
              .delete();
        }
        
        await _loadAllData();
        _showSnackBar('Supprimé avec succès', const Color(0xFF10B981));
      } catch (e) {
        _showSnackBar('Erreur lors de la suppression', const Color(0xFFEF4444));
      }
    }
  }

  void _navigateToCardManagement() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StaffCardManagementScreen(
          schoolId: auth.currentSchoolId ?? '',
          schoolName: auth.schoolName ?? 'ECOLE SCHOOL',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Gestion du personnel',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.credit_card, color: Color(0xFF0F766E)),
            onPressed: _navigateToCardManagement,
            tooltip: 'Cartes de service',
          ),
          IconButton(
            icon: Icon(
              _showTeachers ? Icons.person_off : Icons.person,
              color: _showTeachers ? Colors.purple : const Color(0xFF10B981),
            ),
            onPressed: () {
              setState(() {
                _showTeachers = !_showTeachers;
                _selectedPosition = 'Tous';
                _filterStaff();
              });
            },
            tooltip: _showTeachers ? 'Voir le personnel' : 'Voir les professeurs',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF10B981)),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddStaffScreen()),
              );
              if (result == true) await _loadAllData();
            },
            tooltip: 'Ajouter',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          if (auth.currentSchoolId != null && !auth.isSuperAdmin)
            Container(
              margin: const EdgeInsets.all(16),
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
                    auth.schoolName ?? 'Personnel de l\'école',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _showTeachers ? Colors.purple.withOpacity(0.1) : const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _showTeachers ? '👨‍🏫 Professeurs' : '👤 Personnel',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _showTeachers ? Colors.purple : const Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Filtres
          Container(
            height: 50,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _positions.length,
              itemBuilder: (context, index) {
                final position = _positions[index];
                final isSelected = _selectedPosition == position;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(position),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedPosition = position;
                        _filterStaff();
                      });
                    },
                    backgroundColor: Colors.grey[100],
                    selectedColor: const Color(0xFF10B981).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF10B981) : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: isSelected ? BorderSide.none : BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                );
              },
            ),
          ),

          // Barre de recherche
          Container(
            margin: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                _searchQuery = value;
                _filterStaff();
              },
              decoration: InputDecoration(
                hintText: _showTeachers 
                    ? 'Rechercher un professeur...' 
                    : 'Rechercher par nom, poste ou téléphone...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchQuery = '';
                          _filterStaff();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Statistiques
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _showTeachers ? Icons.school : Icons.people,
                    size: 16,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _showTeachers 
                      ? '${_filteredStaff.length} professeur(s)'
                      : '${_filteredStaff.length} employé(s)',
                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                if (_teachers.isNotEmpty && !_showTeachers)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '+ ${_teachers.length} profs',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.purple[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Liste
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStaff.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _showTeachers ? Icons.school_outlined : Icons.people_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _showTeachers 
                                  ? 'Aucun professeur trouvé'
                                  : 'Aucun employé trouvé',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                            if (!_showTeachers)
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _showTeachers = true;
                                    _selectedPosition = 'Tous';
                                    _filterStaff();
                                  });
                                },
                                icon: const Icon(Icons.school),
                                label: const Text('Voir les professeurs'),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredStaff.length,
                        itemBuilder: (context, index) {
                          final staff = _filteredStaff[index];
                          final isTeacher = staff.position == 'Professeur';
                          return FadeTransition(
                            opacity: _animationController,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border: isTeacher ? Border.all(color: Colors.purple.withOpacity(0.2), width: 1) : null,
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: isTeacher
                                              ? [Colors.purple[700]!, Colors.purple[500]!]
                                              : staff.isActive
                                                  ? [const Color(0xFF0F766E), const Color(0xFF14B8A6)]
                                                  : [Colors.grey[400]!, Colors.grey[500]!],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Center(
                                        child: Text(
                                          staff.fullName.isNotEmpty ? staff.fullName[0].toUpperCase() : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            staff.fullName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        if (isTeacher)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '👨‍🏫 Prof',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.purple[600],
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isTeacher
                                                ? Colors.purple.withOpacity(0.1)
                                                : const Color(0xFF3B82F6).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            staff.position,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isTeacher ? Colors.purple[600] : const Color(0xFF3B82F6),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        if (staff.phone != null && staff.phone!.isNotEmpty)
                                          Row(
                                            children: [
                                              const Icon(Icons.phone, size: 12, color: Colors.grey),
                                              const SizedBox(width: 4),
                                              Text(staff.phone!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                            ],
                                          ),
                                        if (staff.salary > 0)
                                          Text(
                                            'Salaire: ${staff.salary.toStringAsFixed(0)} FCFA/mois',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F766E).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: IconButton(
                                            icon: const Icon(Icons.credit_card, color: Color(0xFF0F766E), size: 20),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => StaffCardManagementScreen(
                                                    schoolId: auth.currentSchoolId ?? '',
                                                    schoolName: auth.schoolName ?? 'ECOLE SCHOOL',
                                                  ),
                                                ),
                                              );
                                            },
                                            tooltip: 'Carte de service',
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: IconButton(
                                            icon: const Icon(Icons.payment, color: Color(0xFF10B981), size: 20),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => StaffPaymentsScreen(staff: {
                                                    'firestoreId': staff.firestoreId,
                                                    'fullName': staff.fullName,
                                                    'position': staff.position,
                                                    'salary': staff.salary,
                                                  }),
                                                ),
                                              );
                                            },
                                            tooltip: 'Gérer les paiements',
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: IconButton(
                                            icon: const Icon(Icons.edit, color: Color(0xFFF59E0B), size: 20),
                                            onPressed: () async {
                                              final result = await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => AddStaffScreen(staff: staff),
                                                ),
                                              );
                                              if (result == true) await _loadAllData();
                                            },
                                            tooltip: 'Modifier',
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEF4444).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: IconButton(
                                            icon: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 20),
                                            onPressed: () => _deleteStaff(staff),
                                            tooltip: 'Supprimer',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
}
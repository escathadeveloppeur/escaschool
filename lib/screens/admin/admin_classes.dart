// lib/screens/admin/admin_classes.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../models/class_model.dart';
import '../../providers/auth_provider.dart';
import 'add_class_screen.dart';

// ===================== PALETTE / THEME HELPERS (identique au dashboard) =====================
class _AppColors {
  static const Color primary = Color(0xFF1E3A8A); // indigo-900
  static const Color primaryLight = Color(0xFF3B5BDB);
  static const Color background = Color(0xFFF4F6FB);
  static const Color cardBorder = Color(0xFFE6E9F2);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
}

class AdminClasses extends StatefulWidget {
  final Function? onChanged;
  
  const AdminClasses({super.key, this.onChanged});

  @override
  _AdminClassesState createState() => _AdminClassesState();
}

class _AdminClassesState extends State<AdminClasses> with SingleTickerProviderStateMixin {
  final DBHelper db = DBHelper();
  List<ClassModel> _classes = [];
  List<ClassModel> _filteredClasses = [];
  bool _isLoading = true;
  
  String _selectedCycle = 'all';
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;

  final List<Map<String, dynamic>> _cycles = [
    {'id': 'all', 'name': 'Tous', 'icon': Icons.all_inclusive, 'color': const Color(0xFF6366F1)},
    {'id': 'primaire', 'name': 'Primaire', 'icon': Icons.abc, 'color': const Color(0xFF10B981)},
    {'id': 'secondaire', 'name': 'Secondaire', 'icon': Icons.school, 'color': const Color(0xFF8B5CF6)},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadClassesFromFirestore();
    _searchController.addListener(_filterClasses);
    _animationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadClassesFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      Query query = FirebaseFirestore.instance.collection('classes');
      
      if (!auth.isSuperAdmin && schoolId != null) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.get();
      
      final List<ClassModel> loadedClasses = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        loadedClasses.add(ClassModel(
          firestoreId: doc.id,
          className: data['className'] ?? '',
          level: data['level'] ?? '',
          year: data['year'] ?? '',
          cycleType: data['cycleType'] ?? 'primaire',
          subjects: List<Map<String, dynamic>>.from(data['subjects'] ?? []),
          schoolId: data['schoolId'] ?? '',
          sectionId: data['sectionId'] as String?,
          section: data['section'] as String?,
        ));
      }
      setState(() {
        _classes = loadedClasses;
        _filterClasses();
        _isLoading = false;
      });
      
      print('✅ ${loadedClasses.length} classes chargées depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement classes: $e');
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      List<ClassModel> classes;
      if (auth.isSuperAdmin) {
        classes = await db.getAllClasses();
      } else if (schoolId != null) {
        classes = await db.getClassesBySchool(schoolId);
      } else {
        classes = [];
      }
      
      setState(() {
        _classes = classes;
        _filterClasses();
        _isLoading = false;
      });
    }
  }

  void _filterClasses() {
    final searchQuery = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredClasses = _classes.where((classModel) {
        if (_selectedCycle != 'all') {
          final classCycle = classModel.cycleType ?? 'primaire';
          if (classCycle != _selectedCycle) return false;
        }
        
        if (searchQuery.isNotEmpty) {
          final className = classModel.className.toLowerCase();
          final level = classModel.level?.toLowerCase() ?? '';
          if (!className.contains(searchQuery) && !level.contains(searchQuery)) {
            return false;
          }
        }
        
        return true;
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

  Future<void> _deleteClass(ClassModel classModel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          'Voulez-vous vraiment supprimer la classe ${classModel.className} ?\n\nToutes les données associées seront également supprimées.',
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
        if (classModel.firestoreId != null) {
          await FirebaseFirestore.instance
              .collection('classes')
              .doc(classModel.firestoreId)
              .delete();
        }
        
        if (classModel.key != null) {
          await db.deleteClass(classModel.key!);
        }
        
        await _loadClassesFromFirestore();
        widget.onChanged?.call();
        _showSnackBar('Classe supprimée avec succès', const Color(0xFF10B981));
      } catch (e) {
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Gestion des classes',
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
              onPressed: _loadClassesFromFirestore,
            ),
          ),
          if (!auth.isSuperAdmin || auth.currentSchoolId != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: "Ajouter une classe",
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddClassScreen()),
                  );
                  if (result == true) await _loadClassesFromFirestore();
                },
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_AppColors.primary),
              ),
            )
          : Column(
              children: [
                const SizedBox(height: 16),
                
                // Sélecteur de cycle
                _buildCycleSelector(),
                
                const SizedBox(height: 16),
                
                // Barre de recherche
                _buildSearchBar(),
                
                // Compteur
                _buildCounter(),
                
                // Liste des classes
                Expanded(
                  child: _filteredClasses.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _filteredClasses.length,
                          itemBuilder: (context, index) {
                            return FadeTransition(
                              opacity: _animationController,
                              child: _buildClassCard(_filteredClasses[index]),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  // ===================== SÉLECTEUR DE CYCLE =====================
  Widget _buildCycleSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: _AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: _cycles.map((cycle) {
          final isSelected = _selectedCycle == cycle['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCycle = cycle['id'];
                  _filterClasses();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected ? cycle['color'] : Colors.transparent,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: (cycle['color'] as Color).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      cycle['icon'],
                      color: isSelected ? Colors.white : cycle['color'],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      cycle['name'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : cycle['color'],
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===================== BARRE DE RECHERCHE =====================
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher une classe...',
          hintStyle: TextStyle(color: _AppColors.textMuted),
          prefixIcon: Icon(Icons.search_rounded, color: _AppColors.primaryLight),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: _AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    _filterClasses();
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

  // ===================== COMPTEUR =====================
  Widget _buildCounter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.class_rounded, size: 18, color: _AppColors.primary),
          ),
          const SizedBox(width: 12),
          Text(
            '${_filteredClasses.length} classe(s) sur ${_classes.length}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _AppColors.textDark,
            ),
          ),
          if (_searchController.text.isNotEmpty)
            Expanded(
              child: Text(
                ' • Filtré par: "${_searchController.text}"',
                style: TextStyle(fontSize: 12, color: _AppColors.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  // ===================== ÉTAT VIDE =====================
  Widget _buildEmptyState() {
    bool hasSearch = _searchController.text.isNotEmpty;
    bool hasFilter = _selectedCycle != 'all';
    
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
  hasSearch ? Icons.search_off_rounded : Icons.class_,
  size: 56,
  color: _AppColors.primary.withOpacity(0.4),
),
          ),
          const SizedBox(height: 20),
          Text(
            hasSearch
                ? 'Aucun résultat trouvé'
                : (hasFilter
                    ? 'Aucune classe en ${_selectedCycle == "primaire" ? "primaire" : "secondaire"}'
                    : 'Aucune classe disponible'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'Essayez avec d\'autres termes'
                : (hasFilter ? 'Changez de filtre ou ajoutez des classes' : 'Commencez par ajouter votre première classe'),
            style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
          ),
          if (hasSearch)
            const SizedBox(height: 16),
          if (hasSearch)
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                _filterClasses();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Effacer la recherche'),
            ),
        ],
      ),
    );
  }

  // ===================== CARTE CLASSE =====================
  Widget _buildClassCard(ClassModel classModel) {
    final isSecondary = classModel.cycleType == 'secondaire';
    final cycleColor = isSecondary ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);
    final cycleIcon = isSecondary ? Icons.school_rounded : Icons.abc_rounded;
    final sectionDisplay = isSecondary && classModel.section != null && classModel.section!.isNotEmpty
        ? ' - Section ${classModel.section}'
        : '';
    
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
      child: ExpansionTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSecondary 
                  ? [const Color(0xFF8B5CF6), const Color(0xFFA855F7)]
                  : [const Color(0xFF10B981), const Color(0xFF059669)],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(cycleIcon, color: Colors.white, size: 24),
          ),
        ),
        title: Text(
          '${classModel.className}$sectionDisplay',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: _AppColors.textDark,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildChip(
                icon: Icons.school_rounded,
                label: classModel.level ?? 'Niveau non défini',
                color: const Color(0xFF3B82F6),
              ),
              _buildChip(
                icon: Icons.calendar_today_rounded,
                label: classModel.year ?? 'Année non définie',
                color: const Color(0xFFF59E0B),
              ),
              _buildChip(
                icon: cycleIcon,
                label: isSecondary ? 'Secondaire' : 'Primaire',
                color: cycleColor,
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActionButton(
              icon: Icons.edit_rounded,
              color: const Color(0xFFF59E0B),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddClassScreen(
                      classToEdit: classModel,
                      classFirestoreId: classModel.firestoreId,
                    ),
                  ),
                );
                if (result == true) await _loadClassesFromFirestore();
              },
            ),
            const SizedBox(width: 4),
            _buildActionButton(
              icon: Icons.delete_rounded,
              color: const Color(0xFFEF4444),
              onPressed: () => _deleteClass(classModel),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(0),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _AppColors.background,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre matières
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.book_rounded, size: 18, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Matières enseignées',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _AppColors.textDark,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${classModel.subjects.length} matière(s)',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                
                // Liste des matières
                if (classModel.subjects.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _AppColors.cardBorder),
                    ),
                    child: Center(
                      child: Text(
                        'Aucune matière assignée',
                        style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
                      ),
                    ),
                  )
                else
                  ...classModel.subjects.map((subject) => _buildSubjectCard(subject)),
                
                // Section (pour le secondaire)
                if (isSecondary && classModel.section != null && classModel.section!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSectionInfo(classModel.section!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================== CHIP STYLISÉ =====================
  Widget _buildChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ===================== BOUTON ACTION =====================
  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  // ===================== CARTE MATIÈRE =====================
  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.book_rounded, size: 18, color: Color(0xFF3B82F6)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject['name'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Coefficient: ${subject['coefficient'] ?? 1}',
                  style: TextStyle(fontSize: 12, color: _AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (subject['professorName']?.isNotEmpty ?? false)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_rounded, size: 12, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text(
                    subject['professorName'],
                    style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ===================== INFO SECTION =====================
  Widget _buildSectionInfo(String section) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school_rounded, size: 18, color: Color(0xFF8B5CF6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Section',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  section,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _AppColors.textDark),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Section ${section}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8B5CF6), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
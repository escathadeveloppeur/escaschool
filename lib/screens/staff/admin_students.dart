// lib/screens/staff/admin_students.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import 'add_student.dart';
import 'student_permissions.dart';

class AdminStudents extends StatefulWidget {
  final VoidCallback? onChanged;
  const AdminStudents({super.key, this.onChanged});

  @override
  _AdminStudentsState createState() => _AdminStudentsState();
}

class _AdminStudentsState extends State<AdminStudents> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> filtered = [];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _sections = [];
  
  TextEditingController searchController = TextEditingController();
  bool loading = true;
  late AnimationController _animationController;
  
  // Filtres
  String _selectedCycle = 'primaire'; // 'primaire', 'secondaire'
  String? _selectedSectionId; // Section sélectionnée (secondaire)
  String? _selectedClassId; // Classe sélectionnée

  final List<Map<String, dynamic>> _cycles = [
    {'id': 'primaire', 'name': 'Primaire', 'icon': Icons.abc, 'color': Color(0xFF10B981)},
    {'id': 'secondaire', 'name': 'Secondaire', 'icon': Icons.school, 'color': Color(0xFF8B5CF6)},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadAllData();
    searchController.addListener(_filterStudents);
  }

  @override
  void dispose() {
    searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => loading = true);
    await Future.wait([
      _loadStudentsFromFirestore(),
      _loadClasses(),
      _loadSections(),
    ]);
    setState(() => loading = false);
    _animationController.forward(from: 0);
  }

  Future<void> _loadClasses() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      Query query = FirebaseFirestore.instance.collection('classes');
      if (schoolId != null && !auth.isSuperAdmin) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.get();
      
      _classes = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'className': data['className'] ?? '',
          'level': data['level'] ?? '',
          'year': data['year'] ?? '',
          'cycleType': data['cycleType'] ?? 'primaire',
          'hasSections': data['hasSections'] ?? false,
          'sectionIds': data['sectionIds'] ?? [],
        };
      }).toList();
      
      print('✅ ${_classes.length} classes chargées');
    } catch (e) {
      print('❌ Erreur chargement classes: $e');
    }
  }

  Future<void> _loadSections() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      if (schoolId == null) return;
      
      final snapshot = await FirebaseFirestore.instance
          .collection('sections')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      
      _sections = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'description': data['description'] ?? '',
        };
      }).toList();
      
      print('✅ ${_sections.length} sections chargées');
    } catch (e) {
      print('❌ Erreur chargement sections: $e');
    }
  }

  Future<void> _loadStudentsFromFirestore() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      Query query = FirebaseFirestore.instance.collection('students');
      
      if (schoolId != null && !auth.isSuperAdmin) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.get();
      
      students = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'fullName': data['fullName'] ?? '',
          'className': data['className'] ?? '',
          'classFirestoreId': data['classFirestoreId'] ?? '',
          'classCycleType': data['classCycleType'] ?? 'primaire',
          'sectionId': data['sectionId'],
          'sectionName': data['sectionName'],
          'birthDate': data['birthDate'] ?? '',
          'birthPlace': data['birthPlace'] ?? '',
          'fatherName': data['fatherName'] ?? '',
          'motherName': data['motherName'] ?? '',
          'parentPhone': data['parentPhone'] ?? '',
          'address': data['address'] ?? '',
          'documentsVerified': data['documentsVerified'] ?? false,
          'userId': data['userId'],
          'parentUserId': data['parentUserId'],
          'parentRelation': data['parentRelation'] ?? '',
          'schoolId': data['schoolId'],
        };
      }).toList();
      
      _filterStudents();
      print('✅ ${students.length} étudiants chargés');
    } catch (e) {
      debugPrint("❌ Erreur chargement étudiants: $e");
      _showSnackBar("Erreur chargement étudiants", const Color(0xFFEF4444));
    }
  }

  void _filterStudents() {
    final searchQuery = searchController.text.trim().toLowerCase();
    
    setState(() {
      filtered = students.where((student) {
        // Filtrer par cycle
        final studentCycle = student['classCycleType'] ?? 'primaire';
        if (studentCycle != _selectedCycle) return false;
        
        // Filtrer par section (secondaire)
        if (_selectedCycle == 'secondaire' && _selectedSectionId != null) {
          if (student['sectionId'] != _selectedSectionId) return false;
        }
        
        // Filtrer par classe
        if (_selectedClassId != null) {
          if (student['classFirestoreId'] != _selectedClassId) return false;
        }
        
        // Filtrer par recherche
        if (searchQuery.isNotEmpty) {
          final name = (student['fullName'] as String).toLowerCase();
          final className = (student['className'] as String).toLowerCase();
          final phone = (student['parentPhone'] as String).toLowerCase();
          if (!name.contains(searchQuery) && 
              !className.contains(searchQuery) && 
              !phone.contains(searchQuery)) {
            return false;
          }
        }
        
        return true;
      }).toList();
    });
  }

  List<Map<String, dynamic>> get _filteredClassesByCycle {
    return _classes.where((c) => c['cycleType'] == _selectedCycle).toList();
  }

  List<Map<String, dynamic>> get _filteredClassesBySection {
    if (_selectedSectionId == null) return [];
    return _classes.where((c) => 
      c['cycleType'] == 'secondaire' && 
      (c['sectionIds'] as List?)?.contains(_selectedSectionId) == true
    ).toList();
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

  Future<void> _deleteStudent(String firestoreId) async {
    try {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(firestoreId)
          .delete();
      
      final linksSnapshot = await FirebaseFirestore.instance
          .collection('parent_student_links')
          .where('studentId', isEqualTo: firestoreId)
          .get();
      
      for (var linkDoc in linksSnapshot.docs) {
        await linkDoc.reference.delete();
      }
      
      await _loadStudentsFromFirestore();
      widget.onChanged?.call();
      _showSnackBar("Étudiant supprimé", const Color(0xFF10B981));
    } catch (e) {
      debugPrint("❌ Erreur suppression: $e");
      _showSnackBar("Erreur lors de la suppression", const Color(0xFFEF4444));
    }
  }

  bool _isVerified(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    return false;
  }

  Widget _buildCycleSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: _cycles.map((cycle) {
          final isSelected = _selectedCycle == cycle['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCycle = cycle['id'];
                  _selectedSectionId = null;
                  _selectedClassId = null;
                  _filterStudents();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected ? cycle['color'] : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(cycle['icon'], color: isSelected ? Colors.white : cycle['color'], size: 18),
                    const SizedBox(width: 8),
                    Text(
                      cycle['name'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : cycle['color'],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildSectionSelector() {
    if (_sections.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Row(
          children: [
            Icon(Icons.info, size: 20, color: Colors.grey),
            SizedBox(width: 8),
            Text('Aucune section disponible pour le secondaire'),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(30),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Option "Toutes les sections"
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSectionId = null;
                  _selectedClassId = null;
                  _filterStudents();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _selectedSectionId == null ? const Color(0xFFF59E0B) : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  'Toutes',
                  style: TextStyle(
                    color: _selectedSectionId == null ? Colors.white : Colors.grey[700],
                    fontWeight: _selectedSectionId == null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
            // Liste des sections
            ..._sections.map((section) {
              final isSelected = _selectedSectionId == section['id'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedSectionId = section['id'];
                    _selectedClassId = null;
                    _filterStudents();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    section['name'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildClassSelector() {
    List<Map<String, dynamic>> availableClasses;
    
    if (_selectedCycle == 'secondaire' && _selectedSectionId != null) {
      availableClasses = _filteredClassesBySection;
    } else {
      availableClasses = _filteredClassesByCycle;
    }
    
    if (availableClasses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.info, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              _selectedCycle == 'secondaire' && _selectedSectionId != null
                  ? 'Aucune classe disponible dans cette section'
                  : 'Aucune classe disponible pour le $_selectedCycle',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(30),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Option "Toutes les classes"
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedClassId = null;
                  _filterStudents();
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _selectedClassId == null ? const Color(0xFF10B981) : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  'Toutes',
                  style: TextStyle(
                    color: _selectedClassId == null ? Colors.white : Colors.grey[700],
                    fontWeight: _selectedClassId == null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
            // Liste des classes
            ...availableClasses.map((classItem) {
              final isSelected = _selectedClassId == classItem['firestoreId'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedClassId = classItem['firestoreId'];
                    _filterStudents();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    classItem['className'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getAvailableClasses() {
    if (_selectedCycle == 'secondaire' && _selectedSectionId != null) {
      return _filteredClassesBySection;
    }
    return _filteredClassesByCycle;
  }

  void _confirmDeleteStudent(String firestoreId) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              "Confirmer la suppression",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text("Voulez-vous vraiment supprimer cet étudiant ?\n\nToutes ses données seront supprimées définitivement."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Annuler"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Supprimer"),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) _deleteStudent(firestoreId);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Indicateur d'école
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
                    'École : ${auth.schoolName ?? auth.currentSchoolId}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6)),
                  ),
                ],
              ),
            ),

          // Sélecteur de cycle (Primaire / Secondaire)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildCycleSelector(),
          ),

          // Filtres dynamiques selon le cycle
          if (_selectedCycle == 'secondaire') ...[
            // Sélecteur de section (Secondaire)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildSectionSelector(),
            ),
          ],

          // Sélecteur de classe
          if (_getAvailableClasses().isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildClassSelector(),
            ),

          // En-tête avec compteur
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school, color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Liste des étudiants (${filtered.length})",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddStudentScreen()),
                    );
                    if (result == true) {
                      await _loadAllData();
                      widget.onChanged?.call();
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Ajouter"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Barre de recherche
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Rechercher par nom, classe ou téléphone...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          searchController.clear();
                          _filterStudents();
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Liste des étudiants
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              "Aucun étudiant",
                              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                            ),
                            const SizedBox(height: 8),
                            if (_selectedClassId != null)
                              Text(
                                "dans cette classe",
                                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                              ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AddStudentScreen()),
                                );
                                if (result == true) {
                                  await _loadAllData();
                                  widget.onChanged?.call();
                                }
                              },
                              icon: const Icon(Icons.add),
                              label: const Text("Ajouter un étudiant"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final s = filtered[i];
                          final isVerified = _isVerified(s['documentsVerified']);
                          final isSecondary = s['classCycleType'] == 'secondaire';
                          
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
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      (s['fullName'] as String).isNotEmpty ? (s['fullName'] as String)[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s['fullName'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSecondary 
                                            ? const Color(0xFF8B5CF6).withOpacity(0.1)
                                            : const Color(0xFF10B981).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSecondary ? Icons.school : Icons.abc,
                                            size: 10,
                                            color: isSecondary ? const Color(0xFF8B5CF6) : const Color(0xFF10B981),
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            isSecondary ? "Secondaire" : "Primaire",
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                              color: isSecondary ? const Color(0xFF8B5CF6) : const Color(0xFF10B981),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          isSecondary ? Icons.school : Icons.abc,
                                          size: 12,
                                          color: isSecondary ? Colors.purple : Colors.green,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Classe: ${s['className']}",
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                    if (isSecondary && s['sectionName'] != null && s['sectionName'].isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.school,
                                              size: 12,
                                              color: Colors.purple[400],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "Section: ${s['sectionName']}",
                                              style: TextStyle(fontSize: 11, color: Colors.purple[600]),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (s['parentPhone'] != null && (s['parentPhone'] as String).isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          "📞 ${s['parentPhone']}",
                                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isVerified
                                            ? const Color(0xFF10B981).withOpacity(0.1)
                                            : const Color(0xFFF59E0B).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isVerified ? Icons.verified : Icons.pending,
                                            size: 12,
                                            color: isVerified
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFF59E0B),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isVerified ? "Documents vérifiés" : "En attente",
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isVerified
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFF59E0B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.security, color: Color(0xFF8B5CF6), size: 20),
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => StudentPermissionsScreen(
                                              studentFirestoreId: s['firestoreId'],
                                              studentName: s['fullName'],
                                            ),
                                          ),
                                        ),
                                        tooltip: 'Permissions',
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
                                              builder: (_) => AddStudentScreen(
                                                student: s,
                                                firestoreId: s['firestoreId'],
                                              ),
                                            ),
                                          );
                                          if (result == true) {
                                            await _loadAllData();
                                            widget.onChanged?.call();
                                          }
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
                                        onPressed: () => _confirmDeleteStudent(s['firestoreId']),
                                        tooltip: 'Supprimer',
                                      ),
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
}
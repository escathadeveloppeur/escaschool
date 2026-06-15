// lib/screens/admin/manage_sections_screen.dart
// lib/screens/admin/manage_sections_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

// ===================== PALETTE / THEME HELPERS =====================
class _AppColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B5BDB);
  static const Color background = Color(0xFFF4F6FB);
  static const Color cardBorder = Color(0xFFE6E9F2);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
}

class ManageSectionsScreen extends StatefulWidget {
  const ManageSectionsScreen({super.key});

  @override
  State<ManageSectionsScreen> createState() => _ManageSectionsScreenState();
}

class _ManageSectionsScreenState extends State<ManageSectionsScreen> {
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadSections(),
      _loadClasses(),
      _loadStudents(),
      _loadTeachers(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadSections() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;
    
    print('🔍 _loadSections - schoolId: $schoolId');
    
    if (schoolId == null) {
      print('⚠️ schoolId est null, chargement de toutes les sections');
      final snapshot = await FirebaseFirestore.instance
          .collection('sections')
          .get();
      
      _sections = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Sans nom',
          'description': data['description'] ?? '',
          'schoolId': data['schoolId'],
          'subjects': data['subjects'] ?? [],
          'createdAt': data['createdAt'],
        };
      }).toList();
    } else {
      final snapshot = await FirebaseFirestore.instance
          .collection('sections')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      
      _sections = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Sans nom',
          'description': data['description'] ?? '',
          'schoolId': data['schoolId'],
          'subjects': data['subjects'] ?? [],
          'createdAt': data['createdAt'],
        };
      }).toList();
    }
    
    print('✅ ${_sections.length} section(s) chargée(s)');
  }

  Future<void> _loadClasses() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;
    
    print('🔍 _loadClasses - schoolId: $schoolId');
    
    if (schoolId == null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .get();
      
      _classes = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['className'] ?? data['name'] ?? 'Sans nom',
          'level': data['level'] ?? '',
          'section': data['section'] ?? '',
          'cycleType': data['cycleType'] ?? 'primaire',
          'capacity': data['capacity'] ?? 0,
          'teacherId': data['teacherId'],
          'teacherName': data['teacherName'],
          'studentsCount': data['studentsCount'] ?? 0,
          'description': data['description'] ?? '',
          'createdAt': data['createdAt'],
        };
      }).toList();
    } else {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      
      _classes = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['className'] ?? data['name'] ?? 'Sans nom',
          'level': data['level'] ?? '',
          'section': data['section'] ?? '',
          'cycleType': data['cycleType'] ?? 'primaire',
          'capacity': data['capacity'] ?? 0,
          'teacherId': data['teacherId'],
          'teacherName': data['teacherName'],
          'studentsCount': data['studentsCount'] ?? 0,
          'description': data['description'] ?? '',
          'createdAt': data['createdAt'],
        };
      }).toList();
    }
    
    print('✅ ${_classes.length} classe(s) chargée(s)');
  }

  Future<void> _loadStudents() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;
    
    if (schoolId == null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .get();
      
      _students = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'fullName': data['fullName'] ?? 'Sans nom',
          'className': data['className'],
          'classId': data['classId'],
        };
      }).toList();
    } else {
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      
      _students = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'fullName': data['fullName'] ?? 'Sans nom',
          'className': data['className'],
          'classId': data['classId'],
        };
      }).toList();
    }
  }

  Future<void> _loadTeachers() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;
    
    if (schoolId == null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('professors')
          .get();
      
      _teachers = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'fullName': data['fullName'] ?? 'Sans nom',
          'subject': data['subject'] ?? '',
        };
      }).toList();
    } else {
      final snapshot = await FirebaseFirestore.instance
          .collection('professors')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      
      _teachers = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'fullName': data['fullName'] ?? 'Sans nom',
          'subject': data['subject'] ?? '',
        };
      }).toList();
    }
  }

  List<Map<String, dynamic>> _getClassesForSection(String sectionName) {
    return _classes.where((c) => c['section'] == sectionName).toList();
  }

  int _getStudentsCountForClass(String classId) {
    return _students.where((s) => s['classId'] == classId).length;
  }

  void _createSection() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Créer une section',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom de la section *',
                hintText: 'Ex: A, B, C, Scientifique, Littéraire...',
                prefixIcon: Icon(Icons.school_rounded),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Ex: Section des sciences exactes',
                prefixIcon: Icon(Icons.description_rounded),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _AppColors.textMuted),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                _showSnackBar('Veuillez entrer un nom de section', const Color(0xFFF59E0B));
                return;
              }
              
              Navigator.pop(context);
              
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final schoolId = auth.currentSchoolId;
              
              // 🔥 VÉRIFICATION
              if (schoolId == null) {
                _showSnackBar('Erreur: ID de l\'école introuvable', const Color(0xFFEF4444));
                return;
              }
              
              print('✅ Création section avec schoolId: $schoolId');
              
              await FirebaseFirestore.instance.collection('sections').add({
                'name': nameController.text.trim().toUpperCase(),
                'description': descriptionController.text.trim(),
                'schoolId': schoolId,
                'subjects': [],
                'createdAt': FieldValue.serverTimestamp(),
              });
              
              _loadSections();
              
              _showSnackBar('Section "${nameController.text.trim().toUpperCase()}" créée avec succès', const Color(0xFF10B981));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _editSection(Map<String, dynamic> section) {
    final nameController = TextEditingController(text: section['name']);
    final descriptionController = TextEditingController(text: section['description'] ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Modifier la section',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom de la section *',
                prefixIcon: Icon(Icons.school_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description_rounded),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _AppColors.textMuted),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                _showSnackBar('Veuillez entrer un nom de section', const Color(0xFFF59E0B));
                return;
              }
              
              Navigator.pop(context);
              
              await FirebaseFirestore.instance
                  .collection('sections')
                  .doc(section['id'])
                  .update({
                'name': nameController.text.trim().toUpperCase(),
                'description': descriptionController.text.trim(),
              });
              
              _loadSections();
              
              _showSnackBar('Section "${nameController.text.trim().toUpperCase()}" modifiée', const Color(0xFFF59E0B));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  void _deleteSection(Map<String, dynamic> section) async {
    final sectionClasses = _getClassesForSection(section['name']);
    
    if (sectionClasses.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Impossible de supprimer'),
          content: Text(
            'La section "${section['name']}" contient ${sectionClasses.length} classe(s).\n\n'
            'Veuillez d\'abord supprimer ou déplacer les classes associées.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment supprimer la section "${section['name']}" ?'),
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
      await FirebaseFirestore.instance
          .collection('sections')
          .doc(section['id'])
          .delete();
      
      _loadSections();
      
      _showSnackBar('Section "${section['name']}" supprimée', const Color(0xFFEF4444));
    }
  }

  void _showSectionDetails(Map<String, dynamic> section) {
    final sectionClasses = _getClassesForSection(section['name']);
    final subjects = section['subjects'] as List? ?? [];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: _AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.school_rounded, color: Color(0xFF8B5CF6), size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section['name'],
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _AppColors.textDark),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                section['description'] ?? 'Aucune description',
                                style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildDetailSectionHeader(Icons.book_rounded, 'Matières de la section', subjects.length, const Color(0xFF10B981)),
                    const SizedBox(height: 8),
                    if (subjects.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _AppColors.cardBorder),
                        ),
                        child: Center(
                          child: Text(
                            'Aucune matière assignée à cette section',
                            style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
                          ),
                        ),
                      )
                    else
                      ...subjects.map((subject) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(child: Icon(Icons.book_rounded, size: 18, color: Color(0xFF10B981))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subject['name'] ?? 'Matière',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _AppColors.textDark),
                                  ),
                                  Text(
                                    'Coef: ${subject['coefficient'] ?? 1}',
                                    style: TextStyle(fontSize: 11, color: _AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            if (subject['professorName'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.person_rounded, size: 12, color: Color(0xFF3B82F6)),
                                    const SizedBox(width: 4),
                                    Text(
                                      subject['professorName'],
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      )),
                    const SizedBox(height: 20),
                    _buildDetailSectionHeader(Icons.class_rounded, 'Classes de cette section', sectionClasses.length, const Color(0xFFF59E0B)),
                    const SizedBox(height: 8),
                    if (sectionClasses.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _AppColors.cardBorder),
                        ),
                        child: Center(
                          child: Text(
                            'Aucune classe associée à cette section',
                            style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
                          ),
                        ),
                      )
                    else
                      ...sectionClasses.map((classItem) {
                        final studentsCount = _getStudentsCountForClass(classItem['id']);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _AppColors.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(child: Icon(Icons.class_rounded, size: 18, color: Color(0xFFF59E0B))),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          classItem['name'],
                                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _AppColors.textDark),
                                        ),
                                        Text(
                                          '${classItem['level']} - ${classItem['section']}',
                                          style: TextStyle(fontSize: 11, color: _AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$studentsCount élèves',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                              if (classItem['teacherName'] != null && classItem['teacherName'].isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Row(
                                    children: [
                                      Icon(Icons.person_rounded, size: 12, color: const Color(0xFF10B981)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Prof: ${classItem['teacherName']}',
                                        style: TextStyle(fontSize: 11, color: const Color(0xFF10B981)),
                                      ),
                                    ],
                                  ),
                                ),
                              if (classItem['capacity'] != null && classItem['capacity'] > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Capacité', style: TextStyle(fontSize: 10, color: _AppColors.textMuted)),
                                          Text('$studentsCount / ${classItem['capacity']}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _AppColors.textMuted)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: studentsCount / classItem['capacity'],
                                          backgroundColor: _AppColors.cardBorder,
                                          color: studentsCount >= classItem['capacity'] ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                          minHeight: 4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSectionHeader(IconData icon, String title, int count, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _AppColors.textDark),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var filteredSections = List.from(_sections);
    
    if (_selectedFilter == 'with_teacher') {
      filteredSections = filteredSections.where((s) {
        final sectionClasses = _getClassesForSection(s['name']);
        return sectionClasses.any((c) => c['teacherId'] != null);
      }).toList();
    } else if (_selectedFilter == 'without_teacher') {
      filteredSections = filteredSections.where((s) {
        final sectionClasses = _getClassesForSection(s['name']);
        return sectionClasses.every((c) => c['teacherId'] == null);
      }).toList();
    }
    
    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Gestion des sections',
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
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: _createSection,
              tooltip: 'Créer une section',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white70),
            onPressed: () {
              _showSnackBar(
                'Les sections permettent de regrouper les classes par filière (A, B, C, Scientifique, Littéraire...)', 
                const Color(0xFF8B5CF6)
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('Toutes les sections', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Avec prof', 'with_teacher'),
                const SizedBox(width: 8),
                _buildFilterChip('Sans prof', 'without_teacher'),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_AppColors.primary)))
                : filteredSections.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withOpacity(0.06),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.school_rounded, size: 56, color: const Color(0xFF8B5CF6).withOpacity(0.4)),
                            ),
                            const SizedBox(height: 20),
                            Text('Aucune section disponible', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _AppColors.textDark)),
                            const SizedBox(height: 8),
                            Text(
                              'Cliquez sur le bouton + pour créer une section', 
                              style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: filteredSections.length,
                        itemBuilder: (context, index) {
                          final section = filteredSections[index];
                          final sectionClasses = _getClassesForSection(section['name']);
                          final subjectsCount = (section['subjects'] as List?)?.length ?? 0;
                          final totalStudents = sectionClasses.fold<int>(0, (sum, c) => sum + _getStudentsCountForClass(c['id']));
                          
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
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showSectionDetails(section),
                                borderRadius: BorderRadius.circular(18),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                section['name'][0].toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  section['name'],
                                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _AppColors.textDark),
                                                ),
                                                if (section['description'] != null && section['description'].isNotEmpty)
                                                  Text(
                                                    section['description'],
                                                    style: TextStyle(fontSize: 12, color: _AppColors.textMuted),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: IconButton(
                                                  icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFFF59E0B)),
                                                  onPressed: () => _editSection(section),
                                                  tooltip: 'Modifier',
                                                  padding: const EdgeInsets.all(8),
                                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEF4444).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: IconButton(
                                                  icon: const Icon(Icons.delete_rounded, size: 18, color: Color(0xFFEF4444)),
                                                  onPressed: () => _deleteSection(section),
                                                  tooltip: 'Supprimer',
                                                  padding: const EdgeInsets.all(8),
                                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.book_rounded, size: 14, color: Color(0xFF10B981)),
                                                const SizedBox(width: 6),
                                                Text('$subjectsCount matière(s)', style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.class_rounded, size: 14, color: Color(0xFFF59E0B)),
                                                const SizedBox(width: 6),
                                                Text('${sectionClasses.length} classe(s)', style: const TextStyle(fontSize: 12, color: Color(0xFFF59E0B), fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.people_rounded, size: 14, color: Color(0xFF3B82F6)),
                                                const SizedBox(width: 6),
                                                Text('$totalStudents élève(s)', style: const TextStyle(fontSize: 12, color: Color(0xFF3B82F6), fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Expanded(
      child: FilterChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700])),
        selected: isSelected,
        onSelected: (selected) => setState(() => _selectedFilter = value),
        backgroundColor: Colors.grey[200],
        selectedColor: value == 'all' ? const Color(0xFF6366F1) : (value == 'with_teacher' ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        side: BorderSide.none,
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
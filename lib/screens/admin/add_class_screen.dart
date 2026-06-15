// lib/screens/admin/add_class_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../models/class_model.dart';
import '../../providers/auth_provider.dart';
import 'manage_sections_screen.dart';

class AddClassScreen extends StatefulWidget {
  final ClassModel? classToEdit;
  final String? classFirestoreId;
  
  const AddClassScreen({super.key, this.classToEdit, this.classFirestoreId});

  @override
  _AddClassScreenState createState() => _AddClassScreenState();
}

class _AddClassScreenState extends State<AddClassScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final DBHelper db = DBHelper();

  String className = '';
  String _selectedLevel = '6ème';
  String year = DateTime.now().year.toString();
  String _cycleType = 'primaire';
  String? _selectedSectionId;
  String? _selectedSectionName;
  
  List<Map<String, dynamic>> _selectedSubjects = [];
  List<Map<String, dynamic>> _professors = [];
  List<Map<String, dynamic>> _availableSections = [];
  
  final TextEditingController _subjectController = TextEditingController();
  String? _selectedProfessorFirestoreId;
  String _selectedProfessorNameForNewSubject = '';
  String _selectedCategory = 'premiere';
  
  bool _isLoading = true;
  late AnimationController _animationController;

  final List<String> _levels = [
    '6ème', '5ème', '4ème', '3ème', '2nde', '1ère', 'Tle'
  ];

  final List<Map<String, dynamic>> _categories = [
    {'id': 'premiere', 'name': '1ère Catégorie', 'p1': 10, 'p2': 10, 'ex1': 20, 'tot1': 40, 'p3': 10, 'p4': 10, 'ex2': 20, 'tot2': 40, 'total': 80, 'color': const Color(0xFF8B5CF6)},
    {'id': 'deuxieme', 'name': '2ème Catégorie', 'p1': 20, 'p2': 20, 'ex1': 40, 'tot1': 80, 'p3': 20, 'p4': 20, 'ex2': 40, 'tot2': 80, 'total': 160, 'color': const Color(0xFF3B82F6)},
    {'id': 'troisieme', 'name': '3ème Catégorie', 'p1': 40, 'p2': 40, 'ex1': 80, 'tot1': 160, 'p3': 40, 'p4': 40, 'ex2': 80, 'tot2': 160, 'total': 320, 'color': const Color(0xFF10B981)},
    {'id': 'quatrieme', 'name': '4ème Catégorie', 'p1': 50, 'p2': 50, 'ex1': 100, 'tot1': 200, 'p3': 50, 'p4': 50, 'ex2': 100, 'tot2': 200, 'total': 400, 'color': const Color(0xFFF59E0B)},
    {'id': 'cinquieme', 'name': '5ème Catégorie', 'p1': 100, 'p2': 100, 'ex1': 0, 'tot1': 200, 'p3': 100, 'p4': 100, 'ex2': 0, 'tot2': 200, 'total': 400, 'color': const Color(0xFFEF4444)},
  ];

  final List<Map<String, dynamic>> _cycleTypes = [
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
    _loadDataFromFirestore();
    _loadAvailableSections();
    
    if (widget.classToEdit != null) {
      className = widget.classToEdit!.className;
      _selectedLevel = widget.classToEdit!.level ?? '6ème';
      year = widget.classToEdit!.year ?? DateTime.now().year.toString();
      _cycleType = widget.classToEdit!.cycleType ?? 'primaire';
      _selectedSectionId = widget.classToEdit!.sectionId;
      _selectedSectionName = widget.classToEdit!.section;      
      
      if (widget.classToEdit!.subjects.isNotEmpty) {
        _selectedSubjects = List<Map<String, dynamic>>.from(widget.classToEdit!.subjects);
        for (var i = 0; i < _selectedSubjects.length; i++) {
          final subject = _selectedSubjects[i];
          if (subject['category'] == null) {
            final defaultCategory = _categories.first;
            subject['category'] = 'premiere';
            subject['categoryName'] = defaultCategory['name'];
            subject['maxValues'] = {
              'p1': defaultCategory['p1'], 'p2': defaultCategory['p2'], 'ex1': defaultCategory['ex1'], 'tot1': defaultCategory['tot1'],
              'p3': defaultCategory['p3'], 'p4': defaultCategory['p4'], 'ex2': defaultCategory['ex2'], 'tot2': defaultCategory['tot2'],
              'total': defaultCategory['total'],
            };
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableSections() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;
    
    print('🔍 schoolId: $schoolId');
    print('🔍 auth.currentSchoolId: ${auth.currentSchoolId}');
    print('🔍 auth.user?.schoolId: ${auth.user?.schoolId}');
    
    if (schoolId == null) {
      print('❌ schoolId est NULL - impossible de charger les sections');
      setState(() {
        _availableSections = [];
      });
      return;
    }
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('sections')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      
      print('📊 Nombre de sections trouvées: ${snapshot.docs.length}');
      
      final sectionsList = snapshot.docs.map((doc) {
        final data = doc.data();
        print('   - Section: ${data['name']} (schoolId: ${data['schoolId']})');
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Sans nom',
          'description': data['description'] ?? '',
          'subjects': data['subjects'] ?? [],
        };
      }).toList();
      
      setState(() {
        _availableSections = sectionsList;
      });
      
      print('✅ _availableSections mise à jour: ${_availableSections.length} sections');
    } catch (e) {
      print('❌ Erreur: $e');
    }
  }
  
  Future<void> _loadDataFromFirestore() async {
    setState(() => _isLoading = true);
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;
    
    try {
      Query query = FirebaseFirestore.instance.collection('professors');
      if (!auth.isSuperAdmin && schoolId != null) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.get();
      
      final List<Map<String, dynamic>> professorsList = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        professorsList.add({
          'firestoreId': doc.id,
          'fullName': data['fullName'] ?? data['name'] ?? 'Sans nom',
          'status': data['status'] ?? 'active',
        });
      }
      professorsList.sort((a, b) => (a['fullName'] ?? '').compareTo(b['fullName'] ?? ''));
      
      setState(() {
        _professors = professorsList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    }
    
    _animationController.forward(from: 0);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToManageSections() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageSectionsScreen()),
    ).then((_) {
      _loadAvailableSections();
      setState(() {});
    });
  }

  void _addSubject() {
    final subjectName = _subjectController.text.trim();
    
    if (subjectName.isEmpty) {
      _showSnackBar('Veuillez entrer un nom de matière', const Color(0xFFF59E0B));
      return;
    }
    
    if (_selectedProfessorFirestoreId == null) {
      _showSnackBar('Veuillez sélectionner un professeur', const Color(0xFFF59E0B));
      return;
    }
    
    if (_selectedSubjects.any((s) => s['name'] == subjectName)) {
      _showSnackBar('Cette matière existe déjà', const Color(0xFFF59E0B));
      return;
    }
    
    final selectedCategory = _categories.firstWhere((c) => c['id'] == _selectedCategory);
    
    setState(() {
      _selectedSubjects.add({
        'name': subjectName,
        'coefficient': 1.0,
        'professorFirestoreId': _selectedProfessorFirestoreId,
        'professorName': _selectedProfessorNameForNewSubject,
        'category': _selectedCategory,
        'categoryName': selectedCategory['name'],
        'maxValues': {
          'p1': selectedCategory['p1'], 'p2': selectedCategory['p2'], 'ex1': selectedCategory['ex1'], 'tot1': selectedCategory['tot1'],
          'p3': selectedCategory['p3'], 'p4': selectedCategory['p4'], 'ex2': selectedCategory['ex2'], 'tot2': selectedCategory['tot2'],
          'total': selectedCategory['total'],
        },
      });
      _subjectController.clear();
      _selectedProfessorFirestoreId = null;
      _selectedProfessorNameForNewSubject = '';
      _selectedCategory = 'premiere';
    });
  }

  void _removeSubject(int index) {
    setState(() {
      _selectedSubjects.removeAt(index);
    });
  }

  void _updateSubjectCoefficient(int index, double value) {
    setState(() {
      _selectedSubjects[index]['coefficient'] = value;
    });
  }

  void _updateSubjectProfessor(int index, String? professorFirestoreId, String professorName) {
    setState(() {
      _selectedSubjects[index]['professorFirestoreId'] = professorFirestoreId;
      _selectedSubjects[index]['professorName'] = professorName;
    });
  }

  void _updateSubjectCategory(int index, String categoryId) {
    final selectedCategory = _categories.firstWhere((c) => c['id'] == categoryId);
    setState(() {
      _selectedSubjects[index]['category'] = categoryId;
      _selectedSubjects[index]['categoryName'] = selectedCategory['name'];
      _selectedSubjects[index]['maxValues'] = {
        'p1': selectedCategory['p1'], 'p2': selectedCategory['p2'], 'ex1': selectedCategory['ex1'], 'tot1': selectedCategory['tot1'],
        'p3': selectedCategory['p3'], 'p4': selectedCategory['p4'], 'ex2': selectedCategory['ex2'], 'tot2': selectedCategory['tot2'],
        'total': selectedCategory['total'],
      };
    });
  }

  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedSubjects.isEmpty) {
      _showSnackBar('Veuillez ajouter au moins une matière', const Color(0xFFF59E0B));
      return;
    }

    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      // 🔥 VÉRIFICATION CRUCIALE - schoolId ne doit pas être null
      if (schoolId == null) {
        _showSnackBar('Erreur: ID de l\'école introuvable. Veuillez vous reconnecter.', const Color(0xFFEF4444));
        setState(() => _isLoading = false);
        return;
      }
      
      print('✅ Sauvegarde de la classe avec schoolId: $schoolId');
      
      final subjectsWithCategories = _selectedSubjects.map((subject) {
        if (subject['category'] == null) {
          final defaultCategory = _categories.first;
          return {
            ...subject,
            'category': 'premiere',
            'categoryName': defaultCategory['name'],
            'maxValues': {
              'p1': defaultCategory['p1'], 'p2': defaultCategory['p2'], 'ex1': defaultCategory['ex1'], 'tot1': defaultCategory['tot1'],
              'p3': defaultCategory['p3'], 'p4': defaultCategory['p4'], 'ex2': defaultCategory['ex2'], 'tot2': defaultCategory['tot2'],
              'total': defaultCategory['total'],
            },
          };
        }
        return subject;
      }).toList();
      
      final classData = {
        'className': className,
        'level': _selectedLevel,
        'year': year,
        'cycleType': _cycleType,
        'subjects': subjectsWithCategories,
        'section': _selectedSectionName,
        'sectionId': _selectedSectionId,
        'schoolId': schoolId,  // 🔥 MAINTENANT schoolId N'EST PAS NULL
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (widget.classToEdit == null) {
        await FirebaseFirestore.instance.collection('classes').add(classData);
        _showSnackBar('Classe ajoutée avec succès', const Color(0xFF10B981));
      } else {
        String? docId = widget.classFirestoreId ?? widget.classToEdit?.firestoreId;
        if (docId != null && docId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('classes').doc(docId).update(classData);
          _showSnackBar('Classe modifiée avec succès', const Color(0xFF10B981));
        } else {
          _showSnackBar('Erreur: Classe introuvable', const Color(0xFFEF4444));
          return;
        }
      }
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.classToEdit == null ? 'Ajouter une classe' : 'Modifier la classe',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.school, color: Color(0xFF8B5CF6)),
            onPressed: _navigateToManageSections,
            tooltip: 'Gérer les sections',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: FadeTransition(
                opacity: _animationController,
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 20),
                      _buildCycleSelector(),
                      const SizedBox(height: 16),
                      if (_cycleType == 'secondaire') _buildSectionSelector(),
                      const SizedBox(height: 16),
                      _buildSubjectsCard(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCycleSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: _cycleTypes.map((cycle) {
          final isSelected = _cycleType == cycle['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _cycleType = cycle['id'];
                  if (_cycleType == 'primaire') {
                    _selectedSectionId = null;
                    _selectedSectionName = null;
                  }
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
                    Text(cycle['name'], style: TextStyle(color: isSelected ? Colors.white : cycle['color'])),
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
    print('🔍 _availableSections.length: ${_availableSections.length}');
    print('🔍 _availableSections: $_availableSections');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school, color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Section (optionnelle)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              TextButton.icon(
                onPressed: _navigateToManageSections,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nouvelle section'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF8B5CF6)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_availableSections.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aucune section disponible. Cliquez sur "Nouvelle section" pour en créer une.',
                      style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                    ),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: _selectedSectionId,
              isExpanded: true,
              hint: const Text('Sélectionner une section (optionnel)'),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.school, color: Color(0xFF8B5CF6)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Aucune section'),
                ),
                ..._availableSections.map<DropdownMenuItem<String>>((section) {
                  return DropdownMenuItem<String>(
                    value: section['id'] as String,
                    child: Text(section['name'] as String),
                  );
                }),
              ],
              onChanged: (value) {
                if (value == null) {
                  setState(() {
                    _selectedSectionId = null;
                    _selectedSectionName = null;
                  });
                } else {
                  final selected = _availableSections.firstWhere((s) => s['id'] == value);
                  setState(() {
                    _selectedSectionId = value;
                    _selectedSectionName = selected['name'] as String;
                  });
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSubjectsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.book, color: Color(0xFF10B981), size: 24),
                ),
                const SizedBox(width: 12),
                const Text('Matières de la classe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_selectedSubjects.length} matière(s)', style: const TextStyle(color: Color(0xFF10B981))),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildAddSubjectForm(),
            const SizedBox(height: 20),
            _buildSubjectsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddSubjectForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _subjectController,
            decoration: const InputDecoration(
              labelText: 'Nom de la matière',
              hintText: 'Ex: Mathématiques',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.book_outlined),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Catégorie',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category),
            ),
            items: _categories.map<DropdownMenuItem<String>>((c) {
              return DropdownMenuItem<String>(
                value: c['id'],
                child: Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: c['color'], shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(c['name']),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedCategory = value!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _selectedProfessorFirestoreId,
            decoration: const InputDecoration(
              labelText: 'Professeur',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            items: _professors.map<DropdownMenuItem<String?>>((p) {
              return DropdownMenuItem<String?>(
                value: p['firestoreId'] as String?,
                child: Text(p['fullName'] as String),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedProfessorFirestoreId = value;
                final prof = _professors.firstWhere((p) => p['firestoreId'] == value);
                _selectedProfessorNameForNewSubject = prof['fullName'] ?? '';
              });
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addSubject,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter la matière'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsList() {
    if (_selectedSubjects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(Icons.book, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Aucune matière ajoutée', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _selectedSubjects.length,
      itemBuilder: (context, index) {
        final subject = _selectedSubjects[index];
        final category = _categories.firstWhere((c) => c['id'] == (subject['category'] ?? 'premiere'));
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: category['color'].withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: category['color'].withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: category['color'], shape: BoxShape.circle),
                    child: Center(child: Text(subject['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subject['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(category['name'], style: TextStyle(fontSize: 11, color: category['color'])),
                        if (subject['professorName'] != null)
                          Text(subject['professorName'], style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _removeSubject(index),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: subject['coefficient']?.toString() ?? '1',
                      decoration: const InputDecoration(labelText: 'Coef', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _updateSubjectCoefficient(index, double.tryParse(value) ?? 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: subject['professorFirestoreId'],
                      decoration: const InputDecoration(labelText: 'Prof', border: OutlineInputBorder()),
                      items: _professors.map<DropdownMenuItem<String?>>((p) {
                        return DropdownMenuItem<String?>(
                          value: p['firestoreId'] as String?,
                          child: Text(p['fullName'] as String),
                        );
                      }).toList(),
                      onChanged: (value) {
                        final prof = _professors.firstWhere((p) => p['firestoreId'] == value);
                        _updateSubjectProfessor(index, value, prof['fullName'] ?? '');
                      },
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showCategoryDialog(index),
                icon: Icon(Icons.edit, size: 16, color: category['color']),
                label: Text('Changer catégorie', style: TextStyle(color: category['color'])),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCategoryDialog(int index) {
    final currentCategory = _selectedSubjects[index]['category'] ?? 'premiere';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer la catégorie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _categories.map<Widget>((c) => RadioListTile<String>(
            title: Text(c['name']),
            value: c['id'],
            groupValue: currentCategory,
            activeColor: c['color'],
            onChanged: (value) {
              Navigator.pop(context);
              _updateSubjectCategory(index, value!);
            },
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.class_, color: Color(0xFF10B981), size: 24),
                ),
                const SizedBox(width: 12),
                const Text('Informations de la classe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              initialValue: className,
              decoration: const InputDecoration(labelText: 'Nom de la classe *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.class_)),
              onSaved: (v) => className = v?.trim() ?? '',
              validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),
            
            DropdownButtonFormField<String>(
              value: _selectedLevel,
              decoration: const InputDecoration(
                labelText: 'Niveau *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.grade),
              ),
              items: _levels.map((level) {
                return DropdownMenuItem<String>(
                  value: level,
                  child: Text(level),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLevel = value!;
                });
              },
              validator: (value) => value == null ? 'Veuillez sélectionner un niveau' : null,
            ),
            
            const SizedBox(height: 12),
            TextFormField(
              initialValue: year,
              decoration: const InputDecoration(labelText: 'Année scolaire', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
              onSaved: (v) => year = v?.trim() ?? '',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saveClass,
            icon: Icon(widget.classToEdit == null ? Icons.add : Icons.save),
            label: Text(widget.classToEdit == null ? 'Créer la classe' : 'Enregistrer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            label: const Text('Annuler'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}
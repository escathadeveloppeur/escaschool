// lib/screens/admin/add_class_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../models/class_model.dart';
import '../../providers/auth_provider.dart';

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
  String level = '';
  String year = DateTime.now().year.toString();
  
  List<Map<String, dynamic>> _selectedSubjects = [];
  List<Map<String, dynamic>> _professors = [];
  
  final TextEditingController _subjectController = TextEditingController();
  String? _selectedProfessorFirestoreId;
  String _selectedProfessorNameForNewSubject = '';
  
  bool _isLoading = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadDataFromFirestore();
    
    if (widget.classToEdit != null) {
      className = widget.classToEdit!.className;
      level = widget.classToEdit!.level ?? '';
      year = widget.classToEdit!.year ?? '';
      
      if (widget.classToEdit!.subjects.isNotEmpty) {
        _selectedSubjects = List<Map<String, dynamic>>.from(widget.classToEdit!.subjects);
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les professeurs depuis Firestore
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
    'id': data['localId'] ?? 0,
    'fullName': data['fullName'] ?? data['name'] ?? 'Sans nom',
    'email': data['email'] ?? '',
    'phone': data['phone'] ?? '',
    'specialty': data['specialty'] ?? '',
    'status': data['status'] ?? 'active',
    'schoolId': data['schoolId'],
  });
}
      professorsList.sort((a, b) => (a['fullName'] ?? '').compareTo(b['fullName'] ?? ''));
      
      setState(() {
        _professors = professorsList;
        _isLoading = false;
      });
      
      print('✅ ${professorsList.length} professeurs chargés depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement professeurs: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Erreur chargement professeurs: $e', const Color(0xFFEF4444));
    }
    
    _animationController.forward(from: 0);
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

  void _addSubject() {
    final subjectName = _subjectController.text.trim();
    if (subjectName.isEmpty) {
      _showSnackBar('Veuillez entrer un nom de matière', const Color(0xFFF59E0B));
      return;
    }
    
    if (_selectedProfessorFirestoreId == null) {
      _showSnackBar('Veuillez sélectionner un professeur pour cette matière', const Color(0xFFF59E0B));
      return;
    }
    
    if (_selectedSubjects.any((s) => s['name'] == subjectName)) {
      _showSnackBar('Cette matière existe déjà', const Color(0xFFF59E0B));
      return;
    }
    
    setState(() {
      _selectedSubjects.add({
        'name': subjectName,
        'coefficient': 1.0,
        'professorFirestoreId': _selectedProfessorFirestoreId,
        'professorName': _selectedProfessorNameForNewSubject,
      });
      _subjectController.clear();
      _selectedProfessorFirestoreId = null;
      _selectedProfessorNameForNewSubject = '';
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

  /// 🔥 Sauvegarder directement dans Firestore
  Future<void> _saveClass() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubjects.isEmpty) {
      _showSnackBar('Veuillez ajouter au moins une matière', const Color(0xFFF59E0B));
      return;
    }

    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      final classData = {
        'className': className,
        'level': level,
        'year': year,
        'subjects': _selectedSubjects,
        'schoolId': schoolId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.classToEdit == null) {
        // 🔥 Ajouter dans Firestore
        await FirebaseFirestore.instance.collection('classes').add(classData);
        _showSnackBar('Classe ajoutée avec succès', const Color(0xFF10B981));
      } else {
        // 🔥 Modifier dans Firestore
        if (widget.classFirestoreId != null) {
          await FirebaseFirestore.instance
              .collection('classes')
              .doc(widget.classFirestoreId)
              .update(classData);
          _showSnackBar('Classe modifiée avec succès', const Color(0xFF10B981));
        }
      }
      
      // Sauvegarder aussi localement pour offline
      final classModel = ClassModel(
        className: className,
        level: level,
        year: year,
        subjects: _selectedSubjects,
        schoolId: schoolId,
      );
      
      if (widget.classToEdit == null) {
        await db.insertClass(classModel);
      } else if (widget.classToEdit != null && widget.classToEdit!.key != null) {
        await db.updateClass(widget.classToEdit!.key!, classModel);
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
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.classToEdit == null ? 'Ajouter une classe' : 'Modifier la classe',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          if (!auth.isSuperAdmin && auth.currentSchoolId != null)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business, size: 16, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(auth.schoolName ?? 'École', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blue)),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))))
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
                      _buildSubjectsCard(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(Icons.class_, 'Informations de la classe', const Color(0xFF10B981)),
            const SizedBox(height: 20),
            _buildTextField(className, 'Nom de la classe', Icons.class_, (v) => className = v.trim()),
            const SizedBox(height: 16),
            _buildTextField(level, 'Niveau', Icons.grade, (v) => level = v.trim()),
            const SizedBox(height: 16),
            _buildTextField(year, 'Année scolaire', Icons.calendar_today, (v) => year = v.trim()),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(Icons.book, 'Matières enseignées', Colors.blue),
            const SizedBox(height: 20),
            _buildAddSubjectForm(),
            const SizedBox(height: 20),
            _buildSubjectsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTextField(String initialValue, String label, IconData icon, Function(String) onSaved) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        prefixIcon: Icon(icon, color: const Color(0xFF10B981)),
        filled: true,
        fillColor: Colors.white,
      ),
      onSaved: (val) => onSaved(val?.trim() ?? ''),
      validator: (val) => val == null || val.isEmpty ? '$label requis' : null,
    );
  }

  Widget _buildAddSubjectForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF10B981).withOpacity(0.05), Colors.white]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _subjectController,
            decoration: InputDecoration(
              labelText: 'Nom de la matière',
              hintText: 'Ex: Mathématiques, Français',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              prefixIcon: const Icon(Icons.book_outlined, color: Color(0xFF10B981)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          _buildProfessorDropdown(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addSubject,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter cette matière'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessorDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
      ),
      child: DropdownButtonFormField<String?>(
        value: _selectedProfessorFirestoreId,
        isExpanded: true,
        hint: _professors.isEmpty ? const Text('Aucun professeur disponible') : const Text('Choisir un professeur'),
        decoration: InputDecoration(
          labelText: 'Professeur responsable',
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF10B981)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: _professors.isEmpty ? [] : _professors.map((prof) {
          return DropdownMenuItem<String?>(
            value: prof['firestoreId'],
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.green.withOpacity(0.1),
                  child: Text(
                    (prof['fullName'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(prof['fullName'] ?? 'Professeur')),
                if ((prof['status'] ?? '') == 'active')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Text('Actif', style: TextStyle(fontSize: 10, color: Colors.green)),
                  ),
              ],
            ),
          );
        }).toList(),
        onChanged: _professors.isEmpty ? null : (value) {
          setState(() {
            _selectedProfessorFirestoreId = value;
            final professor = _professors.firstWhere((p) => p['firestoreId'] == value, orElse: () => {'fullName': ''});
            _selectedProfessorNameForNewSubject = professor['fullName'] ?? '';
          });
        },
        validator: (value) => _professors.isEmpty ? 'Aucun professeur disponible' : (value == null ? 'Professeur requis' : null),
      ),
    );
  }

  Widget _buildSubjectsList() {
    if (_selectedSubjects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
        child: Column(
          children: [
            Icon(Icons.book, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('Aucune matière ajoutée', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 4),
            Text('Ajoutez des matières ci-dessus', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
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
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blue.withOpacity(0.05), Colors.white]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 45, height: 45,
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]), shape: BoxShape.circle),
                      child: Center(child: Text(subject['name']?.isNotEmpty == true ? subject['name'][0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(subject['name'] ?? 'Matière', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          if (subject['professorName']?.isNotEmpty ?? false)
                            Row(children: [Icon(Icons.school, size: 12, color: Colors.green[600]), const SizedBox(width: 4), Text(subject['professorName'], style: TextStyle(fontSize: 11, color: Colors.green[700]))]),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                      onPressed: () => _removeSubject(index),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: subject['coefficient']?.toString() ?? '1',
                        decoration: InputDecoration(
                          labelText: 'Coefficient',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.calculate, size: 18, color: Color(0xFF10B981)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) => _updateSubjectCoefficient(index, double.tryParse(value) ?? 1.0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: subject['professorFirestoreId'],
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Professeur',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person, size: 18, color: Color(0xFF10B981)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: _professors.map((prof) => DropdownMenuItem<String?>(value: prof['firestoreId'], child: Text(prof['fullName'] ?? 'Professeur'))).toList(),
                        onChanged: (value) {
                          final professor = _professors.firstWhere((p) => p['firestoreId'] == value, orElse: () => {'fullName': ''});
                          _updateSubjectProfessor(index, value, professor['fullName'] ?? '');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
              side: BorderSide(color: Colors.grey[300]!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}
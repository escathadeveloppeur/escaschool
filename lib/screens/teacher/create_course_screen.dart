// lib/screens/teacher/create_course_screen.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

const String GOOGLE_SCRIPT_URL = 'https://script.google.com/macros/s/AKfycbxaGYbjC-CVolyVpj3MTliI6fdpSRokZG7CLEuBdAhcJuNPt__6C6UCRMO6y2X9_zEiXA/exec';

class CreateCourseScreen extends StatefulWidget {
  final String professorFirestoreId;
  final String professorName;
  final Map<String, dynamic>? courseToEdit;
  
  const CreateCourseScreen({
    super.key,
    required this.professorFirestoreId,
    required this.professorName,
    this.courseToEdit,
  });

  @override
  _CreateCourseScreenState createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  String title = '';
  String description = '';
  String subject = '';
  String className = '';
  String classFirestoreId = '';
  List<Map<String, dynamic>> chapters = [];
  List<Map<String, dynamic>> resources = [];
  List<Map<String, dynamic>> availableClasses = []; // 🔥 Classes où le prof enseigne
  List<Map<String, dynamic>> availableSubjectsForClass = []; // 🔥 Matières du prof dans la classe
  bool _isLoading = true;
  bool _isSaving = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadProfessorClasses();
    
    if (widget.courseToEdit != null) {
      final course = widget.courseToEdit!;
      title = course['title'] ?? '';
      description = course['description'] ?? '';
      subject = course['subject'] ?? '';
      className = course['className'] ?? '';
      classFirestoreId = course['classFirestoreId'] ?? '';
      chapters = List.from(course['chapters'] ?? []);
      resources = List.from(course['resources'] ?? []);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

  /// 🔥 Charger les classes où le professeur enseigne
  Future<void> _loadProfessorClasses() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      // Récupérer toutes les classes
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      
      availableClasses = [];
      
      for (var doc in classesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final subjects = List<Map<String, dynamic>>.from(data['subjects'] ?? []);
        
        // Vérifier si le professeur enseigne dans cette classe
        final hasProfessorSubjects = subjects.any((subject) {
          return subject['professorFirestoreId'] == widget.professorFirestoreId;
        });
        
        if (hasProfessorSubjects) {
          availableClasses.add({
            'firestoreId': doc.id,
            'className': data['className'] ?? '',
            'level': data['level'] ?? '',
            'section': data['section'] ?? '',
            'cycleType': data['cycleType'] ?? 'primaire',
            'subjects': subjects, // Garder toutes les matières pour filtrer plus tard
          });
        }
      }
      
      // Si en mode édition, sélectionner la classe et charger ses matières
      if (widget.courseToEdit != null && classFirestoreId.isNotEmpty) {
        _loadSubjectsForClass(classFirestoreId);
      }
      
      _animationController.forward(from: 0);
    } catch (e) {
      print('❌ Erreur chargement classes: $e');
      _showSnackBar('Erreur de chargement', const Color(0xFFEF4444));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 🔥 Charger les matières du professeur pour la classe sélectionnée
  void _loadSubjectsForClass(String classId) {
    final selectedClassData = availableClasses.firstWhere(
      (c) => c['firestoreId'] == classId,
      orElse: () => {},
    );
    
    if (selectedClassData.isNotEmpty) {
      final subjects = List<Map<String, dynamic>>.from(selectedClassData['subjects'] ?? []);
      
      // Filtrer les matières enseignées par ce professeur
      availableSubjectsForClass = subjects.where((subject) {
        return subject['professorFirestoreId'] == widget.professorFirestoreId;
      }).toList();
      
      print('✅ Matières disponibles dans cette classe: ${availableSubjectsForClass.length}');
    } else {
      availableSubjectsForClass = [];
    }
    
    setState(() {});
  }

  void _addChapter() {
    showDialog(
      context: context,
      builder: (context) => AddChapterDialog(
        onSave: (chapter) => setState(() => chapters.add(chapter)),
      ),
    );
  }

  void _editChapter(int index) {
    showDialog(
      context: context,
      builder: (context) => AddChapterDialog(
        title: chapters[index]['title'],
        content: chapters[index]['content'],
        videoUrl: chapters[index]['videoUrl'],
        isEditing: true,
        onSave: (updatedChapter) => setState(() => chapters[index] = updatedChapter),
      ),
    );
  }

  void _deleteChapter(int index) {
    _showConfirmDialog(
      title: 'Supprimer le chapitre',
      content: 'Voulez-vous vraiment supprimer ce chapitre ?',
      onConfirm: () {
        setState(() => chapters.removeAt(index));
        _showSnackBar('Chapitre supprimé', const Color(0xFFEF4444));
      },
    );
  }

  void _addResource() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => AddResourceBottomSheet(
        onSave: (resource) async {
          setState(() => resources.add(resource));
          _showSnackBar('Ressource ajoutée', const Color(0xFF10B981));
        },
      ),
    );
  }

  void _editResource(int index) {
    final resource = resources[index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => AddResourceBottomSheet(
        title: resource['title'],
        description: resource['description'],
        type: resource['type'],
        url: resource['url'],
        isEditing: true,
        onSave: (updatedResource) {
          setState(() => resources[index] = updatedResource);
          _showSnackBar('Ressource modifiée', const Color(0xFF3B82F6));
        },
      ),
    );
  }

  void _deleteResource(int index) {
    _showConfirmDialog(
      title: 'Supprimer la ressource',
      content: 'Voulez-vous vraiment supprimer cette ressource ?',
      onConfirm: () {
        setState(() => resources.removeAt(index));
        _showSnackBar('Ressource supprimée', const Color(0xFFEF4444));
      },
    );
  }

  void _showConfirmDialog({required String title, required String content, required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  /// 🔥 Sauvegarder le cours dans Firestore
  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;
    if (chapters.isEmpty) {
      _showSnackBar('Ajoutez au moins un chapitre', const Color(0xFFF59E0B));
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      final courseData = {
        'title': title,
        'description': description,
        'subject': subject,
        'className': className,
        'classFirestoreId': classFirestoreId,
        'professorFirestoreId': widget.professorFirestoreId,
        'professorName': widget.professorName,
        'chapters': chapters,
        'resources': resources,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'schoolId': schoolId,
      };
      
      if (widget.courseToEdit == null) {
        await FirebaseFirestore.instance.collection('online_courses').add(courseData);
        _showSnackBar('Cours créé avec succès', const Color(0xFF10B981));
      } else {
        await FirebaseFirestore.instance
            .collection('online_courses')
            .doc(widget.courseToEdit!['id'])
            .update(courseData);
        _showSnackBar('Cours modifié avec succès', const Color(0xFF10B981));
      }
      
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isEditing = widget.courseToEdit != null;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier le cours' : 'Créer un cours', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfessorClasses,
            style: IconButton.styleFrom(backgroundColor: Colors.grey[100]),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: FadeTransition(
                opacity: _animationController,
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildSchoolBadge(auth),
                      _buildInfoCard(),
                      const SizedBox(height: 20),
                      _buildChaptersCard(),
                      const SizedBox(height: 20),
                      _buildResourcesCard(),
                      const SizedBox(height: 24),
                      _buildActionButtons(isEditing),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSchoolBadge(AuthProvider auth) {
    if (auth.currentSchoolId == null || auth.isSuperAdmin) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.business, size: 18, color: Colors.blue),
          const SizedBox(width: 8),
          Text('École : ${auth.schoolName ?? auth.currentSchoolId}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSectionHeader(Icons.info_outline, 'Informations générales', const Color(0xFF10B981)),
            const SizedBox(height: 20),
            _buildTextField('Titre du cours', 'Ex: Introduction à la programmation', Icons.title, title, (v) => title = v, validator: true),
            const SizedBox(height: 16),
            _buildTextField('Description', 'Décrivez le contenu du cours...', Icons.description, description, (v) => description = v, maxLines: 3),
            const SizedBox(height: 16),
            _buildClassAndSubjectSelector(),
          ],
        ),
      ),
    );
  }

  /// 🔥 Sélecteur de classe et matière (dépendants)
  Widget _buildClassAndSubjectSelector() {
    return Column(
      children: [
        // Sélecteur de classe
        if (availableClasses.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vous n\'êtes assigné à aucune classe. Contactez l\'administration.',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<String>(
            value: classFirestoreId.isNotEmpty ? classFirestoreId : null,
            decoration: InputDecoration(
              labelText: 'Classe *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              prefixIcon: const Icon(Icons.class_, color: Color(0xFF10B981)),
              filled: true,
              fillColor: Colors.white,
            ),
            items: availableClasses.map<DropdownMenuItem<String>>((c) {
              final sectionDisplay = c['section'] != null && c['section'].isNotEmpty
                  ? ' - ${c['section']}'
                  : '';
              return DropdownMenuItem<String>(
                value: c['firestoreId'],
                child: Text('${c['className']}${sectionDisplay} (${c['level']})'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                classFirestoreId = value!;
                final selectedClass = availableClasses.firstWhere(
                  (c) => c['firestoreId'] == value,
                );
                className = selectedClass['className'];
                _loadSubjectsForClass(value);
              });
            },
            validator: (v) => v == null ? 'Veuillez sélectionner une classe' : null,
          ),
        
        const SizedBox(height: 16),
        
        // Sélecteur de matière (chargé après la sélection de la classe)
        if (classFirestoreId.isNotEmpty && availableSubjectsForClass.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vous n\'avez aucune matière dans cette classe',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
          )
        else if (classFirestoreId.isNotEmpty)
          DropdownButtonFormField<String>(
            value: subject.isNotEmpty ? subject : null,
            decoration: InputDecoration(
              labelText: 'Matière *',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              prefixIcon: const Icon(Icons.book, color: Color(0xFF10B981)),
              filled: true,
              fillColor: Colors.white,
            ),
            items: availableSubjectsForClass.map<DropdownMenuItem<String>>((s) {
              return DropdownMenuItem<String>(
                value: s['name'],
                child: Text(s['name']),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                subject = value!;
              });
            },
            validator: (v) => v == null ? 'Veuillez sélectionner une matière' : null,
          ),
      ],
    );
  }

  Widget _buildChaptersCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(Icons.menu_book, 'Chapitres', const Color(0xFF3B82F6)),
                _buildAddButton('Ajouter', _addChapter, const Color(0xFF3B82F6)),
              ],
            ),
            const SizedBox(height: 20),
            chapters.isEmpty ? _buildEmptyState(Icons.menu_book, 'Aucun chapitre ajouté', 'Cliquez sur "Ajouter" pour commencer')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: chapters.length,
                    itemBuilder: (context, index) => _buildChapterItem(index),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildResourcesCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(Icons.attach_file, 'Ressources', const Color(0xFF8B5CF6)),
                _buildAddButton('Ajouter', _addResource, const Color(0xFF8B5CF6)),
              ],
            ),
            const SizedBox(height: 20),
            resources.isEmpty ? _buildEmptyState(Icons.attach_file, 'Aucune ressource ajoutée', 'Ajoutez des fichiers PDF, vidéos, images ou liens')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: resources.length,
                    itemBuilder: (context, index) => _buildResourceItem(index),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAddButton(String label, VoidCallback onPressed, Color color) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(12)),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String hint, IconData icon, String initialValue, Function(String) onChanged, {int maxLines = 1, bool validator = false}) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        prefixIcon: Icon(icon, color: const Color(0xFF10B981)),
        filled: true,
        fillColor: Colors.white,
      ),
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator ? (v) => v!.isEmpty ? '$label requis' : null : null,
    );
  }

  Widget _buildChapterItem(int index) {
    final chapter = chapters[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.withOpacity(0.2))),
      child: ListTile(
        leading: Container(width: 40, height: 40, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]), shape: BoxShape.circle), child: Center(child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
        title: Text(chapter['title'], style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: chapter['content'] != null && chapter['content'].isNotEmpty ? Text(chapter['content'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[600])) : null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.edit, color: Color(0xFFF59E0B), size: 20), onPressed: () => _editChapter(index)),
          IconButton(icon: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 20), onPressed: () => _deleteChapter(index)),
        ]),
      ),
    );
  }

  Widget _buildResourceItem(int index) {
    final resource = resources[index];
    final color = _getResourceColor(resource['type']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
      child: ListTile(
        leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(_getResourceIcon(resource['type']), color: color, size: 24)),
        title: Text(resource['title'], style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: resource['description']?.isNotEmpty == true ? Text(resource['description'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[600])) : Text(resource['url'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.edit, color: Color(0xFFF59E0B), size: 20), onPressed: () => _editResource(index)),
          IconButton(icon: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 20), onPressed: () => _deleteResource(index)),
        ]),
      ),
    );
  }

  Widget _buildActionButtons(bool isEditing) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveCourse,
            icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
            label: Text(isEditing ? 'Modifier le cours' : 'Créer le cours'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            label: const Text('Annuler'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: Colors.grey[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
      ],
    );
  }

  IconData _getResourceIcon(String? type) => switch (type) { 
    'pdf' => Icons.picture_as_pdf, 
    'video' => Icons.video_library, 
    'image' => Icons.image, 
    'link' => Icons.link, 
    _ => Icons.insert_drive_file 
  };
  
  Color _getResourceColor(String? type) => switch (type) { 
    'pdf' => const Color(0xFFEF4444), 
    'video' => const Color(0xFF3B82F6), 
    'image' => const Color(0xFF10B981), 
    'link' => const Color(0xFF8B5CF6), 
    _ => Colors.grey 
  };
}

// Dialog pour ajouter/modifier un chapitre (inchangé)
class AddChapterDialog extends StatefulWidget {
  final String? title;
  final String? content;
  final String? videoUrl;
  final bool isEditing;
  final Function(Map<String, dynamic>) onSave;
  
  const AddChapterDialog({super.key, this.title, this.content, this.videoUrl, this.isEditing = false, required this.onSave});

  @override
  _AddChapterDialogState createState() => _AddChapterDialogState();
}

class _AddChapterDialogState extends State<AddChapterDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _videoUrlController;
  
  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title ?? '');
    _contentController = TextEditingController(text: widget.content ?? '');
    _videoUrlController = TextEditingController(text: widget.videoUrl ?? '');
  }
  
@override
void dispose() {
  _titleController.dispose();
  _contentController.dispose();
  _videoUrlController.dispose();
  super.dispose();
}
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Titre *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.title, color: Color(0xFF10B981)),
                    ),
                    validator: (v) => v!.isEmpty ? 'Titre requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contentController,
                    decoration: InputDecoration(
                      labelText: 'Contenu',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.description, color: Color(0xFF10B981)),
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _videoUrlController,
                    decoration: InputDecoration(
                      labelText: 'URL vidéo (optionnel)',
                      hintText: 'https://youtube.com/...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.videocam, color: Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.onSave({
                          'title': _titleController.text.trim(),
                          'content': _contentController.text.trim(),
                          'videoUrl': _videoUrlController.text.trim().isNotEmpty ? _videoUrlController.text.trim() : null,
                        });
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: Text(widget.isEditing ? 'Modifier' : 'Ajouter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.menu_book, color: Color(0xFF3B82F6), size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.isEditing ? 'Modifier le chapitre' : 'Ajouter un chapitre',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// BottomSheet pour ajouter/modifier une ressource (inchangé)
class AddResourceBottomSheet extends StatefulWidget {
  final String? title;
  final String? description;
  final String? type;
  final String? url;
  final bool isEditing;
  final Function(Map<String, dynamic>) onSave;
  
  const AddResourceBottomSheet({
    super.key,
    this.title,
    this.description,
    this.type,
    this.url,
    this.isEditing = false,
    required this.onSave,
  });

  @override
  _AddResourceBottomSheetState createState() => _AddResourceBottomSheetState();
}

class _AddResourceBottomSheetState extends State<AddResourceBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _urlController;
  String _selectedType = 'pdf';
  String? _selectedFilePath;
  String? _selectedFileName;
  bool _isUploading = false;
  
  final List<Map<String, dynamic>> _types = [
    {'value': 'pdf', 'label': 'PDF', 'icon': Icons.picture_as_pdf, 'color': const Color(0xFFEF4444)},
    {'value': 'video', 'label': 'Vidéo', 'icon': Icons.video_library, 'color': const Color(0xFF3B82F6)},
    {'value': 'image', 'label': 'Image', 'icon': Icons.image, 'color': const Color(0xFF10B981)},
    {'value': 'link', 'label': 'Lien URL', 'icon': Icons.link, 'color': const Color(0xFF8B5CF6)},
  ];
  
  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title ?? '');
    _descriptionController = TextEditingController(text: widget.description ?? '');
    _urlController = TextEditingController(text: widget.url ?? '');
    _selectedType = widget.type ?? 'pdf';
    
    if (widget.isEditing && widget.type != 'link' && widget.url != null && widget.url!.isNotEmpty) {
      _selectedFilePath = widget.url;
      _selectedFileName = widget.url!.split('/').last;
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    super.dispose();
  }
  
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result;
      switch (_selectedType) {
        case 'pdf':
          result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
          break;
        case 'video':
          result = await FilePicker.platform.pickFiles(type: FileType.video);
          break;
        case 'image':
          result = await FilePicker.platform.pickFiles(type: FileType.image);
          break;
        default:
          return;
      }
      if (result != null) {
        final file = result.files.first;
        setState(() {
          _selectedFilePath = file.path;
          _selectedFileName = file.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }
  
  Future<String?> _uploadToGoogleDrive(String filePath, String fileName) async {
    setState(() => _isUploading = true);
    try {
      final bytes = await File(filePath).readAsBytes();
      final base64File = base64Encode(bytes);
      
      String mimeType = 'application/octet-stream';
      if (fileName.endsWith('.pdf')) mimeType = 'application/pdf';
      else if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) mimeType = 'image/jpeg';
      else if (fileName.endsWith('.png')) mimeType = 'image/png';
      else if (fileName.endsWith('.mp4')) mimeType = 'video/mp4';
      
      final response = await http.post(
        Uri.parse(GOOGLE_SCRIPT_URL),
        body: jsonEncode({
          'action': 'upload',
          'fileBase64': base64File,
          'fileName': fileName,
          'mimeType': mimeType,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['url'] != null) {
          return result['url'];
        }
        return null;
      }
      return null;
    } catch (e) {
      return null;
    } finally {
      setState(() => _isUploading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 60, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          _buildHeader(),
          const SizedBox(height: 20),
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))),
                  SizedBox(height: 12),
                  Text('Upload du fichier en cours...'),
                ],
              ),
            )
          else
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTypeSelector(),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Titre *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.title, color: Color(0xFF10B981)),
                    ),
                    validator: (v) => v!.isEmpty ? 'Titre requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.description, color: Color(0xFF10B981)),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _buildFileSelector(),
                ],
              ),
            ),
          const SizedBox(height: 24),
          if (!_isUploading) _buildActionButtons(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.attach_file, color: Color(0xFF8B5CF6), size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.isEditing ? 'Modifier la ressource' : 'Ajouter une ressource',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Type de ressource', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _types.map((type) {
            final isSelected = _selectedType == type['value'];
            return GestureDetector(
              onTap: () => setState(() {
                _selectedType = type['value'];
                if (_selectedType == 'link') {
                  _selectedFilePath = null;
                  _selectedFileName = null;
                }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected ? LinearGradient(colors: [type['color'], type['color'].withOpacity(0.7)]) : null,
                  color: isSelected ? null : Colors.grey[100],
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: isSelected ? type['color'] : Colors.grey[300]!, width: isSelected ? 0 : 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(type['icon'], size: 18, color: isSelected ? Colors.white : type['color']),
                    const SizedBox(width: 8),
                    Text(type['label'], style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFileSelector() {
    if (_selectedType == 'link') {
      return TextFormField(
        controller: _urlController,
        decoration: InputDecoration(
          labelText: 'URL *',
          hintText: 'https://exemple.com/document.pdf',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          prefixIcon: const Icon(Icons.link, color: Color(0xFF10B981)),
        ),
        validator: (v) => v!.isEmpty ? 'URL requise' : null,
      );
    }
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(14),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            Icon(_selectedType == 'pdf' ? Icons.picture_as_pdf : _selectedType == 'video' ? Icons.video_library : Icons.image, color: _getTypeColor(), size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_selectedFileName ?? 'Sélectionner un fichier', style: TextStyle(fontWeight: _selectedFileName != null ? FontWeight.w500 : FontWeight.normal, color: _selectedFileName != null ? Colors.black : Colors.grey[600])),
                  if (_selectedFileName != null) Text('Appuyez pour changer', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.folder_open, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Annuler'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                if (_selectedType != 'link') {
                  if (_selectedFilePath == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Veuillez sélectionner un fichier')),
                    );
                    return;
                  }
                  
                  final downloadUrl = await _uploadToGoogleDrive(_selectedFilePath!, _selectedFileName!);
                  if (downloadUrl == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Erreur upload, réessayez'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  
                  widget.onSave({
                    'title': _titleController.text.trim(),
                    'description': _descriptionController.text.trim(),
                    'type': _selectedType,
                    'url': downloadUrl,
                    'fileName': _selectedFileName,
                  });
                } else {
                  widget.onSave({
                    'title': _titleController.text.trim(),
                    'description': _descriptionController.text.trim(),
                    'type': _selectedType,
                    'url': _urlController.text.trim(),
                    'fileName': null,
                  });
                }
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(widget.isEditing ? 'Modifier' : 'Ajouter'),
          ),
        ),
      ],
    );
  }

  Color _getTypeColor() => switch (_selectedType) { 
    'pdf' => const Color(0xFFEF4444), 
    'video' => const Color(0xFF3B82F6), 
    'image' => const Color(0xFF10B981), 
    _ => const Color(0xFF8B5CF6) 
  };
}
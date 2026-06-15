// lib/screens/teacher/create_exam_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class CreateExamScreen extends StatefulWidget {
  final String professorFirestoreId;
  final String professorName;
  
  const CreateExamScreen({
    super.key,
    required this.professorFirestoreId,
    required this.professorName,
  });

  @override
  _CreateExamScreenState createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String title = '';
  String description = '';
  String subject = '';
  String className = '';
  String classFirestoreId = '';
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 7));
  int duration = 60;
  int totalPoints = 0;
  List<Map<String, dynamic>> questions = [];
  List<Map<String, dynamic>> availableClasses = [];   // Classes où le prof enseigne
  List<Map<String, dynamic>> availableSubjectsForClass = []; // Matières du prof dans la classe sélectionnée
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfessorClasses();
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
      
      print('✅ Classes disponibles: ${availableClasses.length}');
      
      if (availableClasses.isEmpty) {
        _showSnackBar('Vous n\'êtes assigné à aucune classe', const Color(0xFFF59E0B));
      }
      
      setState(() {});
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
    
    // Réinitialiser la matière sélectionnée
    subject = '';
    setState(() {});
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

  void _addQuestion() {
    showDialog(
      context: context,
      builder: (context) => AddQuestionDialog(
        onSave: (question) {
          setState(() {
            questions.add(question);
            totalPoints += (question['points'] as int);
          });
        },
      ),
    );
  }

  void _editQuestion(int index) {
    final question = questions[index];
    showDialog(
      context: context,
      builder: (context) => AddQuestionDialog(
        initialQuestion: question,
        isEditing: true,
        onSave: (updatedQuestion) {
          setState(() {
            final oldPoints = questions[index]['points'] as int;
            final newPoints = updatedQuestion['points'] as int;
            totalPoints = totalPoints - oldPoints + newPoints;
            questions[index] = updatedQuestion;
          });
        },
      ),
    );
  }

  void _deleteQuestion(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmer la suppression', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Voulez-vous vraiment supprimer cette question ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                totalPoints -= (questions[index]['points'] as int);
                questions.removeAt(index);
              });
              Navigator.pop(context);
              _showSnackBar('Question supprimée', const Color(0xFFEF4444));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveExam() async {
    if (!_formKey.currentState!.validate()) return;
    if (questions.isEmpty) {
      _showSnackBar('Ajoutez au moins une question', const Color(0xFFF59E0B));
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      final examData = {
        'title': title,
        'description': description,
        'subject': subject,
        'className': className,
        'classFirestoreId': classFirestoreId,
        'professorFirestoreId': widget.professorFirestoreId,
        'professorName': widget.professorName,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'duration': duration,
        'totalPoints': totalPoints,
        'questions': questions,
        'status': _getStatus(startDate, endDate),
        'createdAt': FieldValue.serverTimestamp(),
        'schoolId': schoolId,
      };
      
      await FirebaseFirestore.instance.collection('online_exams').add(examData);
      
      _showSnackBar('Épreuve créée avec succès', const Color(0xFF10B981));
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  String _getStatus(DateTime start, DateTime end) {
    final now = DateTime.now();
    if (now.isBefore(start)) return 'upcoming';
    if (now.isAfter(end)) return 'completed';
    return 'ongoing';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer une épreuve'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfessorClasses,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (auth.currentSchoolId != null && !auth.isSuperAdmin)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
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

                    // Informations générales
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.info_outline, color: Color(0xFF10B981), size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Informations générales',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Titre *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.title),
                              ),
                              onChanged: (v) => title = v,
                              validator: (v) => v!.isEmpty ? 'Titre requis' : null,
                            ),
                            
                            const SizedBox(height: 12),
                            
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.description),
                              ),
                              maxLines: 3,
                              onChanged: (v) => description = v,
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // 🔥 DROPDOWN CLASSE (uniquement celles où le prof enseigne)
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
                                decoration: const InputDecoration(
                                  labelText: 'Classe *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.class_),
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
                            
                            const SizedBox(height: 12),
                            
                            // 🔥 DROPDOWN MATIÈRE (uniquement celles du prof dans cette classe)
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
                                decoration: const InputDecoration(
                                  labelText: 'Matière *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.book),
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
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Dates
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.calendar_today, color: Color(0xFF3B82F6), size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Période',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Date début *',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.calendar_today),
                                    ),
                                    controller: TextEditingController(
                                      text: _formatDateTime(startDate),
                                    ),
                                    onTap: () => _selectDateTime(true),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    readOnly: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Date fin *',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.calendar_today),
                                    ),
                                    controller: TextEditingController(
                                      text: _formatDateTime(endDate),
                                    ),
                                    onTap: () => _selectDateTime(false),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Durée (minutes) *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.timer),
                              ),
                              keyboardType: TextInputType.number,
                              initialValue: '60',
                              onChanged: (v) => duration = int.tryParse(v) ?? 60,
                              validator: (v) => v == null || v.isEmpty ? 'Durée requise' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Questions
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.quiz, color: Color(0xFF8B5CF6), size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Questions (${questions.length})',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: _addQuestion,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Ajouter'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8B5CF6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            if (questions.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.quiz, size: 48, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text('Aucune question ajoutée', style: TextStyle(color: Colors.grey)),
                                      Text('Cliquez sur "Ajouter" pour commencer', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: questions.length,
                                itemBuilder: (context, index) {
                                  final q = questions[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.2),
                                        child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF8B5CF6))),
                                      ),
                                      title: Text(
                                        q['text'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      subtitle: Text(
                                        'Type: ${_getTypeLabel(q['type'])} • Points: ${q['points']}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Color(0xFFF59E0B)),
                                            onPressed: () => _editQuestion(index),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Color(0xFFEF4444)),
                                            onPressed: () => _deleteQuestion(index),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            
                            const SizedBox(height: 12),
                            
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total des points', style: TextStyle(fontWeight: FontWeight.bold)),
                                  Text(
                                    '$totalPoints pts',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveExam,
                      icon: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: const Text('Créer l\'épreuve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Annuler'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'multiple_choice': return 'QCM';
      case 'true_false': return 'Vrai/Faux';
      case 'open_ended': return 'Question ouverte';
      default: return type;
    }
  }

  Future<void> _selectDateTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? startDate : endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStart ? startDate : endDate),
      );
      if (time != null) {
        setState(() {
          if (isStart) {
            startDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          } else {
            endDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          }
        });
      }
    }
  }
}

// Dialog pour ajouter/modifier une question (inchangé)
class AddQuestionDialog extends StatefulWidget {
  final Map<String, dynamic>? initialQuestion;
  final bool isEditing;
  final Function(Map<String, dynamic>) onSave;
  
  const AddQuestionDialog({
    super.key,
    this.initialQuestion,
    this.isEditing = false,
    required this.onSave,
  });

  @override
  _AddQuestionDialogState createState() => _AddQuestionDialogState();
}

class _AddQuestionDialogState extends State<AddQuestionDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();
  String _type = 'multiple_choice';
  List<String> _options = ['', ''];
  String _correctAnswer = '';
  
  @override
  void initState() {
    super.initState();
    if (widget.initialQuestion != null) {
      _questionController.text = widget.initialQuestion!['text'] ?? '';
      _pointsController.text = widget.initialQuestion!['points'].toString();
      _type = widget.initialQuestion!['type'] ?? 'multiple_choice';
      if (_type == 'multiple_choice' && widget.initialQuestion!['options'] != null) {
        _options = List<String>.from(widget.initialQuestion!['options']);
        if (_options.length < 2) _options = ['', ''];
      }
      _correctAnswer = widget.initialQuestion!['correctAnswer'] ?? '';
    }
  }
  
  @override
  void dispose() {
    _questionController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.quiz, color: Color(0xFF8B5CF6)),
          ),
          const SizedBox(width: 12),
          Text(widget.isEditing ? 'Modifier la question' : 'Ajouter une question'),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _questionController,
                  decoration: const InputDecoration(
                    labelText: 'Question *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (v) => v!.isEmpty ? 'Question requise' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'multiple_choice', child: Text('QCM')),
                    DropdownMenuItem(value: 'true_false', child: Text('Vrai/Faux')),
                    DropdownMenuItem(value: 'open_ended', child: Text('Question ouverte')),
                  ],
                  onChanged: (v) => setState(() => _type = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pointsController,
                  decoration: const InputDecoration(
                    labelText: 'Points *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Points requis' : null,
                ),
                if (_type == 'multiple_choice') ...[
                  const SizedBox(height: 12),
                  const Text('Options', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._options.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: _options[entry.key],
                              decoration: InputDecoration(
                                labelText: 'Option ${entry.key + 1}',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (v) => _options[entry.key] = v,
                            ),
                          ),
                          if (_options.length > 2)
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _options.removeAt(entry.key);
                                });
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _options.add('');
                      });
                    },
                    child: const Text('+ Ajouter une option'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _correctAnswer.isEmpty ? null : _correctAnswer,
                    decoration: const InputDecoration(
                      labelText: 'Réponse correcte *',
                      border: OutlineInputBorder(),
                    ),
                    items: _options.where((opt) => opt.isNotEmpty).map((opt) {
                      return DropdownMenuItem(
                        value: opt,
                        child: Text(opt),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _correctAnswer = value!),
                    validator: (v) => v == null ? 'Réponse correcte requise' : null,
                  ),
                ],
                if (_type == 'true_false') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setState(() => _correctAnswer = 'Vrai'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _correctAnswer == 'Vrai' ? Colors.green : Colors.grey,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Vrai'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => setState(() => _correctAnswer = 'Faux'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _correctAnswer == 'Faux' ? Colors.red : Colors.grey,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Faux'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final points = int.tryParse(_pointsController.text) ?? 1;
              final question = {
                'text': _questionController.text.trim(),
                'type': _type,
                'points': points,
                'options': _type == 'multiple_choice' ? _options.where((o) => o.isNotEmpty).toList() : [],
                'correctAnswer': _correctAnswer,
              };
              widget.onSave(question);
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
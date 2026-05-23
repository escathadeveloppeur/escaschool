// lib/screens/teacher/teacher_online_exams.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import 'create_exam_screen.dart';

class TeacherOnlineExamsScreen extends StatefulWidget {
  final String professorFirestoreId;
  final String professorName;
  final List<String> assignedClasses;
  final List<String> assignedSubjects;
  
  const TeacherOnlineExamsScreen({
    super.key,
    required this.professorFirestoreId,
    required this.professorName,
    required this.assignedClasses,
    required this.assignedSubjects,
  });

  @override
  _TeacherOnlineExamsScreenState createState() => _TeacherOnlineExamsScreenState();
}

class _TeacherOnlineExamsScreenState extends State<TeacherOnlineExamsScreen> {
  List<Map<String, dynamic>> _exams = [];
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _students = [];
  
  String _selectedClass = '';
  String _selectedSubject = '';
  Map<String, dynamic>? _selectedExam;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.assignedClasses.isNotEmpty) {
      _selectedClass = widget.assignedClasses.first;
    }
    if (widget.assignedSubjects.isNotEmpty) {
      _selectedSubject = widget.assignedSubjects.first;
    }
    _loadData();
  }

  /// 🔥 Charger les données depuis Firestore
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      // 1. Charger les étudiants
      Query studentQuery = FirebaseFirestore.instance.collection('students');
      if (schoolId != null && !auth.isSuperAdmin) {
        studentQuery = studentQuery.where('schoolId', isEqualTo: schoolId);
      }
      final studentsSnapshot = await studentQuery.get();
      
      _students = [];
      for (var doc in studentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _students.add({
          'firestoreId': doc.id,
          'fullName': data['fullName'] ?? '',
          'className': data['className'] ?? '',
        });
      }
      
      // 2. Charger les examens
      Query examQuery = FirebaseFirestore.instance.collection('online_exams');
      examQuery = examQuery.where('professorFirestoreId', isEqualTo: widget.professorFirestoreId);
      
      if (_selectedClass.isNotEmpty) {
        examQuery = examQuery.where('className', isEqualTo: _selectedClass);
      }
      if (_selectedSubject.isNotEmpty) {
        examQuery = examQuery.where('subject', isEqualTo: _selectedSubject);
      }
      
      final examsSnapshot = await examQuery.get();
      
      _exams = [];
      for (var doc in examsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _exams.add({
          'id': doc.id,
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'className': data['className'] ?? '',
          'subject': data['subject'] ?? '',
          'duration': data['duration'] ?? 60,
          'totalPoints': data['totalPoints'] ?? 0,
          'status': data['status'] ?? 'upcoming',
          'questions': data['questions'] ?? [],
          'professorFirestoreId': data['professorFirestoreId'] ?? '',
          'createdAt': data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
        });
      }
      
      // 3. Charger les résultats
      final resultsSnapshot = await FirebaseFirestore.instance
          .collection('exam_results')
          .get();
      
      _results = [];
      for (var doc in resultsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _results.add({
          'id': doc.id,
          'examId': data['examId'] ?? '',
          'studentId': data['studentId'] ?? '',
          'studentName': data['studentName'] ?? '',
          'score': (data['score'] as num?)?.toDouble() ?? 0.0,
          'totalPoints': (data['totalPoints'] as num?)?.toDouble() ?? 0.0,
          'percentage': (data['percentage'] as num?)?.toDouble() ?? 0.0,
          'answers': data['answers'] ?? [],
          'submittedAt': data['submittedAt'] != null ? (data['submittedAt'] as Timestamp).toDate() : DateTime.now(),
          'isGraded': data['isGraded'] ?? false,
        });
      }
      
    } catch (e) {
      print('❌ Erreur chargement: $e');
      _showSnackBar('Erreur de chargement', const Color(0xFFEF4444));
    } finally {
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Examens en ligne'),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createExam(),
            tooltip: 'Créer un examen',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                          'École : ${auth.schoolName ?? auth.currentSchoolId}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Filtres
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.deepOrange[50],
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedClass,
                          decoration: const InputDecoration(
                            labelText: 'Classe',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: widget.assignedClasses.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c));
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedClass = value!;
                              _loadData();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedSubject,
                          decoration: const InputDecoration(
                            labelText: 'Matière',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: widget.assignedSubjects.map((s) {
                            return DropdownMenuItem(value: s, child: Text(s));
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedSubject = value!;
                              _loadData();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Liste des examens
                Expanded(
                  child: _exams.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.quiz, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun examen en ligne',
                                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _createExam(),
                                icon: const Icon(Icons.add),
                                label: const Text('Créer un examen'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _exams.length,
                          itemBuilder: (context, index) {
                            final exam = _exams[index];
                            final examResults = _results.where((r) => r['examId'] == exam['id']).toList();
                            final participants = examResults.length;
                            final classStudents = _students.where((s) => s['className'] == _selectedClass).toList();
                            final totalStudents = classStudents.length;
                            final averageScore = examResults.isNotEmpty
                                ? examResults.map((r) => r['score'] as double).reduce((a, b) => a + b) / examResults.length
                                : 0;
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () => _showExamDetails(exam),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(exam['status']).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _getStatusText(exam['status']),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _getStatusColor(exam['status']),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            '${exam['totalPoints']} pts',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        exam['title'],
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        exam['description'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Durée: ${exam['duration']} min',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                          const SizedBox(width: 16),
                                          Icon(Icons.people, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$participants/$totalStudents participants',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                          const SizedBox(width: 16),
                                          Icon(Icons.trending_up, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Moyenne: ${averageScore.toStringAsFixed(1)}/${exam['totalPoints']}',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      LinearProgressIndicator(
                                        value: participants / totalStudents,
                                        backgroundColor: Colors.grey[200],
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          _getStatusColor(exam['status']),
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

  void _createExam() {
    Navigator.push(
      context,
      MaterialPageRoute(
builder: (context) => CreateExamScreen(
  professorFirestoreId: widget.professorFirestoreId,
  professorName: widget.professorName,
),
      ),
    ).then((_) => _loadData());
  }

  void _showExamDetails(Map<String, dynamic> exam) {
    final examResults = _results.where((r) => r['examId'] == exam['id']).toList();
    final classStudents = _students.where((s) => s['className'] == exam['className']).toList();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepOrange[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      exam['title'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exam['description'],
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              // Statistiques
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        'Participants',
                        '${examResults.length}/${classStudents.length}',
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        'Moyenne',
                        '${examResults.isNotEmpty ? (examResults.map((r) => r['score'] as double).reduce((a, b) => a + b) / examResults.length).toStringAsFixed(1) : '0'}/${exam['totalPoints']}',
                        Icons.trending_up,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        'Taux réussite',
                        '${examResults.isNotEmpty ? (examResults.where((r) => (r['percentage'] as double) >= 60).length / examResults.length * 100).toStringAsFixed(0) : '0'}%',
                        Icons.emoji_events,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(),
              
              // Liste des résultats
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: classStudents.length,
                  itemBuilder: (context, index) {
                    final student = classStudents[index];
                    final result = examResults.firstWhere(
                      (r) => r['studentId'] == student['firestoreId'],
                      orElse: () => {
                        'examId': exam['id'],
                        'studentId': student['firestoreId'],
                        'studentName': student['fullName'],
                        'score': 0,
                        'totalPoints': exam['totalPoints'],
                        'answers': [],
                        'submittedAt': DateTime.now(),
                        'isGraded': false,
                      },
                    );
                    final hasTaken = (result['score'] as double) > 0;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: hasTaken ? Colors.green : Colors.orange,
                          child: Text(
                            (student['fullName'] as String)[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(student['fullName']),
                        subtitle: hasTaken
                            ? Text(
                                'Note: ${result['score']}/${result['totalPoints']} (${(result['percentage'] as double).toStringAsFixed(1)}%)',
                                style: TextStyle(
                                  color: (result['percentage'] as double) >= 60 ? Colors.green : Colors.orange,
                                ),
                              )
                            : const Text('Non participé'),
                        trailing: hasTaken
                            ? IconButton(
                                icon: const Icon(Icons.visibility, color: Colors.blue),
                                onPressed: () => _showStudentAnswers(exam, result),
                                tooltip: 'Voir les réponses',
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStudentAnswers(Map<String, dynamic> exam, Map<String, dynamic> result) {
    final studentName = result['studentName'];
    final answers = result['answers'] as List? ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Réponses de $studentName'),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 500),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: answers.length,
            itemBuilder: (context, index) {
              final q = answers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Q${index + 1}: ${q['question']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Réponse: ${q['answer'] ?? 'Non répondue'}'),
                      Row(
                        children: [
                          Icon(
                            q['isCorrect'] == true ? Icons.check_circle : Icons.cancel,
                            color: q['isCorrect'] == true ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            q['isCorrect'] == true ? 'Correct' : 'Incorrect',
                            style: TextStyle(
                              color: q['isCorrect'] == true ? Colors.green : Colors.red,
                            ),
                          ),
                          const Spacer(),
                          Text('${q['points'] ?? 0} pts'),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'upcoming': return 'À venir';
      case 'ongoing': return 'En cours';
      case 'completed': return 'Terminé';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'upcoming': return Colors.orange;
      case 'ongoing': return Colors.green;
      case 'completed': return Colors.blue;
      default: return Colors.grey;
    }
  }
}
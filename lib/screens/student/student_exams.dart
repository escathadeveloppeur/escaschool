// lib/screens/student/student_exams.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import 'exam_question_screen.dart';

class StudentExamsScreen extends StatefulWidget {
  const StudentExamsScreen({super.key});

  @override
  _StudentExamsScreenState createState() => _StudentExamsScreenState();
}

class _StudentExamsScreenState extends State<StudentExamsScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> exams = [];
  List<Map<String, dynamic>> results = [];
  bool _isLoading = true;
  String? _studentId;
  String _studentName = '';
  String _studentClassName = '';
  late AnimationController _animationController;
  
  String _filterStatus = 'all'; // 'all', 'upcoming', 'ongoing', 'completed'

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadDataFromFirestore();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les données depuis Firestore
  Future<void> _loadDataFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id;
      final userEmail = authProvider.user?.email;
      
      if (userId != null || userEmail != null) {
        // 1. Récupérer l'étudiant via son compte utilisateur
        Query studentQuery = FirebaseFirestore.instance.collection('students');
        
        if (userEmail != null) {
          studentQuery = studentQuery.where('userEmail', isEqualTo: userEmail);
        } else {
          studentQuery = studentQuery.where('userId', isEqualTo: userId);
        }
        
        final studentSnapshot = await studentQuery.limit(1).get();
        
        if (studentSnapshot.docs.isNotEmpty) {
          final studentData = studentSnapshot.docs.first.data() as Map<String, dynamic>;
          _studentId = studentSnapshot.docs.first.id;
          _studentName = studentData['fullName'] ?? '';
          _studentClassName = studentData['className'] ?? '';
          
          print('✅ Étudiant trouvé: $_studentName, Classe: $_studentClassName');
          
          // 2. Charger les examens pour cette classe
          final examsSnapshot = await FirebaseFirestore.instance
              .collection('online_exams')
              .where('className', isEqualTo: _studentClassName)
              .get();
          
          exams = [];
          for (var doc in examsSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            exams.add({
              'id': doc.id,
              'title': data['title'] ?? '',
              'description': data['description'] ?? '',
              'subject': data['subject'] ?? '',
              'className': data['className'] ?? '',
              'duration': data['duration'] ?? 60,
              'totalPoints': data['totalPoints'] ?? 0,
              'questions': data['questions'] ?? [],
              'status': _getExamStatus(data['startDate'], data['endDate']),
              'startDate': data['startDate'] != null ? (data['startDate'] as Timestamp).toDate() : DateTime.now(),
              'endDate': data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : DateTime.now(),
            });
          }
          
          // 3. Charger les résultats de l'étudiant
          final resultsSnapshot = await FirebaseFirestore.instance
              .collection('exam_results')
              .where('studentId', isEqualTo: _studentId)
              .get();
          
          results = [];
          for (var doc in resultsSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            results.add({
              'id': doc.id,
              'examId': data['examId'] ?? '',
              'studentId': data['studentId'] ?? '',
              'studentName': data['studentName'] ?? '',
              'score': (data['score'] as num?)?.toDouble() ?? 0.0,
              'totalPoints': (data['totalPoints'] as num?)?.toDouble() ?? 0.0,
              'percentage': (data['percentage'] as num?)?.toDouble() ?? 0.0,
              'answers': data['answers'] ?? [],
              'submittedAt': data['submittedAt'] != null ? (data['submittedAt'] as Timestamp).toDate() : DateTime.now(),
            });
          }
          
          print('✅ ${exams.length} examens, ${results.length} résultats chargés');
        } else {
          print('⚠️ Aucun étudiant trouvé');
        }
      }
      
      _animationController.forward(from: 0);
    } catch (e) {
      print('❌ Erreur chargement: $e');
      _showSnackBar('Erreur de chargement: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getExamStatus(Timestamp? startTimestamp, Timestamp? endTimestamp) {
    final now = DateTime.now();
    final startDate = startTimestamp != null ? startTimestamp.toDate() : DateTime.now();
    final endDate = endTimestamp != null ? endTimestamp.toDate() : DateTime.now();
    
    if (now.isBefore(startDate)) return 'upcoming';
    if (now.isAfter(endDate)) return 'completed';
    return 'ongoing';
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

  List<Map<String, dynamic>> get _filteredExams {
    return exams.where((exam) {
      if (_filterStatus == 'all') return true;
      if (_filterStatus == 'upcoming') return exam['status'] == 'upcoming';
      if (_filterStatus == 'ongoing') return exam['status'] == 'ongoing';
      if (_filterStatus == 'completed') return exam['status'] == 'completed';
      return true;
    }).toList();
  }

  bool _hasTakenExam(String examId) {
    return results.any((r) => r['examId'] == examId);
  }

  Map<String, dynamic>? _getResult(String examId) {
    try {
      return results.firstWhere((r) => r['examId'] == examId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Épreuves en ligne',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDataFromFirestore,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))),
                  SizedBox(height: 16),
                  Text('Chargement des épreuves...'),
                ],
              ),
            )
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
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue[50],
                  child: Row(
                    children: [
                      _filterChip('Tous', 'all'),
                      const SizedBox(width: 8),
                      _filterChip('À venir', 'upcoming'),
                      const SizedBox(width: 8),
                      _filterChip('En cours', 'ongoing'),
                      const SizedBox(width: 8),
                      _filterChip('Terminés', 'completed'),
                    ],
                  ),
                ),
                
                // Statistiques
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.quiz, size: 16, color: Color(0xFF3B82F6)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_filteredExams.length} épreuve(s) • ${results.length} complétée(s)',
                        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                
                Flexible(
                  child: _filteredExams.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.quiz, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Aucune épreuve disponible',
                                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Les épreuves seront affichées ici',
                                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredExams.length,
                          itemBuilder: (context, index) {
                            final exam = _filteredExams[index];
                            final hasTaken = _hasTakenExam(exam['id']);
                            final result = _getResult(exam['id']);
                            
                            return FadeTransition(
                              opacity: _animationController,
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _getStatusColor(exam['status']).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(exam['status']).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                _getStatusText(exam['status']),
                                                style: TextStyle(
                                                  fontSize: 11,
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
                                                color: Colors.grey[500],
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
                                          exam['subject'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
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
                                            Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Durée: ${exam['duration']} min',
                                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                            ),
                                            const SizedBox(width: 16),
                                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                                            const SizedBox(width: 4),
                                            Text(
                                              DateFormat('dd/MM/yyyy HH:mm').format(exam['startDate']),
                                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        const Divider(),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            if (hasTaken && result != null)
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Résultat',
                                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                                  ),
                                                  Text(
                                                    '${(result['score'] as double).toStringAsFixed(1)}/${result['totalPoints']}',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: (result['percentage'] as double) >= 60 ? Colors.green : Colors.orange,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${(result['percentage'] as double).toStringAsFixed(1)}%',
                                                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                                  ),
                                                ],
                                              ),
                                            ElevatedButton.icon(
                                              onPressed: exam['status'] == 'ongoing' && !hasTaken && _studentId != null
                                                  ? () => _startExam(exam)
                                                  : null,
                                              icon: Icon(
                                                exam['status'] == 'ongoing' && !hasTaken 
                                                  ? Icons.play_arrow 
                                                  : Icons.lock,
                                                size: 18,
                                              ),
                                              label: Text(
                                                exam['status'] == 'ongoing' && !hasTaken
                                                  ? 'Commencer'
                                                  : hasTaken
                                                      ? 'Déjà fait'
                                                      : exam['status'] == 'upcoming'
                                                          ? 'À venir'
                                                          : 'Terminé',
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: exam['status'] == 'ongoing' && !hasTaken
                                                  ? const Color(0xFF10B981)
                                                  : Colors.grey[400],
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
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

  Widget _filterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF10B981).withOpacity(0.2),
      checkmarkColor: const Color(0xFF10B981),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF10B981) : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
        side: BorderSide(color: isSelected ? const Color(0xFF10B981) : Colors.grey[300]!),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'upcoming': return 'À venir';
      case 'ongoing': return 'En cours';
      case 'completed': return 'Terminé';
      default: return 'Inconnu';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'upcoming': return const Color(0xFFF59E0B);
      case 'ongoing': return const Color(0xFF10B981);
      case 'completed': return const Color(0xFF3B82F6);
      default: return Colors.grey;
    }
  }

  void _startExam(Map<String, dynamic> exam) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExamQuestionScreen(
          exam: exam,
          studentId: _studentId!,
          studentName: _studentName,
        ),
      ),
    ).then((_) => _loadDataFromFirestore());
  }
}
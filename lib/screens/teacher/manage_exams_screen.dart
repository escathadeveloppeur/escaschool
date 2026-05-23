// lib/screens/teacher/manage_exams_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class ManageExamsScreen extends StatefulWidget {
  final String professorFirestoreId;
  final String professorName;

  const ManageExamsScreen({
    super.key,
    required this.professorFirestoreId,
    required this.professorName,
  });

  @override
  State<ManageExamsScreen> createState() => _ManageExamsScreenState();
}

class _ManageExamsScreenState extends State<ManageExamsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _exams = [];
  List<Map<String, dynamic>> _examResults = [];
  bool _isLoading = true;
  String? _selectedExamId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║     CHARGEMENT DES EXAMENS ET RÉSULTATS                    ║');
    print('╚════════════════════════════════════════════════════════════╝\n');

    try {
      // 1. Charger les examens du professeur
      final examsSnapshot = await FirebaseFirestore.instance
          .collection('online_exams')
          .where('professorFirestoreId', isEqualTo: widget.professorFirestoreId)
          .orderBy('createdAt', descending: true)
          .get();

      _exams = [];
      for (var doc in examsSnapshot.docs) {
        final data = doc.data();
        _exams.add({
          'id': doc.id,
          ...data,
        });
        print('📋 Examen: ${data['title']} - ${data['className']} (${data['status']})');
      }

      // 2. Charger les résultats des examens
      final resultsSnapshot = await FirebaseFirestore.instance
          .collection('exam_results')
          .get();

      _examResults = [];
      for (var doc in resultsSnapshot.docs) {
        final data = doc.data();
        _examResults.add({
          'id': doc.id,
          ...data,
        });
      }
      print('\n✅ ${_exams.length} examen(s), ${_examResults.length} résultat(s)');
      
    } catch (e) {
      print('❌ Erreur: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Afficher les détails de l'examen (questions + réponses des élèves)
  Future<void> _viewExamDetails(Map<String, dynamic> exam) async {
    final examId = exam['id'];
    final resultsForExam = _examResults
        .where((r) => r['examId'] == examId)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.quiz, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exam['title'],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${exam['className']} - ${exam['subject']}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _infoItem('Durée', '${exam['duration']} min', Icons.timer),
                          _infoItem('Points', '${exam['totalPoints']} pts', Icons.star),
                          _infoItem('Participants', '${resultsForExam.length}', Icons.people),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _infoItem('Début', _formatDate(exam['startDate']), Icons.play_arrow),
                          _infoItem('Fin', _formatDate(exam['endDate']), Icons.stop),
                          _infoItem('Statut', _getStatusLabel(exam['status']), Icons.info),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Questions de l\'examen',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: _buildQuestionsList(exam['questions']),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Résultats des élèves',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: resultsForExam.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.analytics, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'Aucun résultat pour cet examen',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: resultsForExam.length,
                          itemBuilder: (context, index) {
                            final result = resultsForExam[index];
                            final score = result['score'] ?? 0;
                            final totalPoints = exam['totalPoints'] ?? 1;
                            final percentage = (score / totalPoints * 100).round();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getScoreColor(percentage),
                                  child: Text(
                                    '${percentage}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(result['studentName'] ?? 'Élève'),
                                subtitle: Text(
                                  'Note: $score/$totalPoints • ${result['submittedAt'] != null ? _formatDate(result['submittedAt']) : 'Non soumis'}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.visibility, color: Color(0xFF3B82F6)),
                                  onPressed: () => _viewStudentAnswers(result, exam),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuestionsList(List<dynamic>? questions) {
    if (questions == null || questions.isEmpty) {
      return const Center(child: Text('Aucune question'));
    }
    
    return ListView.builder(
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final question = questions[index] as Map<String, dynamic>;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              radius: 14,
              child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Colors.white)),
            ),
            title: Text(
              question['text'] ?? 'Question',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Type: ${_getTypeLabel(question['type'])} • Points: ${question['points']} pts',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.remove_red_eye, size: 18, color: Colors.blue),
              onPressed: () => _showQuestionDetail(question, index + 1),
            ),
          ),
        );
      },
    );
  }

  void _showQuestionDetail(Map<String, dynamic> question, int questionNumber) {
    final type = question['type'];
    final options = question['options'] as List? ?? [];
    final correctAnswer = question['correctAnswer'] ?? '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text('$questionNumber', style: const TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Détail de la question', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(question['text'] ?? '', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Type: ${_getTypeLabel(type)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('Points: ${question['points']} pts', style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (type == 'multiple_choice') ...[
                      const SizedBox(height: 8),
                      const Text('Options:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...options.map((opt) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Row(
                          children: [
                            Icon(opt == correctAnswer ? Icons.check_circle : Icons.circle_outlined,
                                size: 16, color: opt == correctAnswer ? Colors.green : Colors.grey),
                            const SizedBox(width: 8),
                            Text(opt),
                          ],
                        ),
                      )),
                    ],
                    if (type == 'true_false') ...[
                      const SizedBox(height: 8),
                      Text('Réponse correcte: $correctAnswer',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                    if (type == 'open_ended') ...[
                      const SizedBox(height: 8),
                      Text('Réponse attendue: ${correctAnswer.isNotEmpty ? correctAnswer : "Réponse libre"}',
                          style: TextStyle(color: Colors.orange)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  /// Voir les réponses détaillées d'un élève (inspiré de exam_question_screen.dart)
  Future<void> _viewStudentAnswers(Map<String, dynamic> result, Map<String, dynamic> exam) async {
    final answers = result['answers'] as List<dynamic>? ?? [];
    final questions = exam['questions'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.assignment_turned_in, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result['studentName'] ?? 'Élève',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            exam['title'] ?? 'Examen',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _infoItem('Score', '${result['score']}/${exam['totalPoints']}', Icons.star),
                      _infoItem('Pourcentage', '${(result['percentage'] as double?)?.toStringAsFixed(1) ?? '0'}%', Icons.percent),
                      _infoItem('Soumis', _formatDateShort(result['submittedAt']), Icons.calendar_today),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Détail des réponses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final question = questions[index] as Map<String, dynamic>;
                      final answer = index < answers.length ? answers[index] as Map<String, dynamic> : null;
                      final isCorrect = answer != null && (answer['isCorrect'] == true);
                      final userAnswer = answer?['answer'] ?? 'Non répondue';
                      final correctAnswer = question['correctAnswer'] ?? '';
                      final points = answer?['points'] ?? 0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: isCorrect ? Colors.green : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        isCorrect ? Icons.check : Icons.close,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Question ${index + 1}: ${question['text']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$points/${question['points']} pts',
                                      style: TextStyle(
                                        color: isCorrect ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('📝 Réponse: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                        Expanded(child: Text(userAnswer)),
                                      ],
                                    ),
                                    if (question['type'] != 'open_ended') ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('✅ Correcte: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                          Expanded(child: Text(correctAnswer, style: const TextStyle(color: Colors.green))),
                                        ],
                                      ),
                                    ],
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
        },
      ),
    );
  }

  Widget _infoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  String _formatDateShort(dynamic timestamp) {
    if (timestamp == null) return 'Non défini';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return timestamp.toString();
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'multiple_choice': return 'QCM';
      case 'true_false': return 'Vrai/Faux';
      case 'open_ended': return 'Question ouverte';
      default: return type;
    }
  }

  Future<void> _deleteExam(Map<String, dynamic> exam) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmation'),
        content: Text('Voulez-vous vraiment supprimer l\'examen "${exam['title']}" ?\n\nLes résultats des élèves seront également supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('online_exams')
            .doc(exam['id'])
            .delete();
        
        final results = _examResults.where((r) => r['examId'] == exam['id']).toList();
        for (var result in results) {
          await FirebaseFirestore.instance
              .collection('exam_results')
              .doc(result['id'])
              .delete();
        }

        await _loadData();
        _showSnackBar('Examen supprimé', const Color(0xFF10B981));
      } catch (e) {
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Non défini';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return timestamp.toString();
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'upcoming': return 'À venir';
      case 'ongoing': return 'En cours';
      case 'completed': return 'Terminé';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'upcoming': return Colors.blue;
      case 'ongoing': return Colors.green;
      case 'completed': return Colors.grey;
      default: return Colors.grey;
    }
  }

  Color _getScoreColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
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

  double _getAverageScore(List<Map<String, dynamic>> results, int totalPoints) {
    if (results.isEmpty) return 0;
    final total = results.fold<double>(0, (sum, r) => sum + (r['score'] ?? 0));
    return (total / results.length / totalPoints * 100).roundToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final examsByStatus = {
      'upcoming': _exams.where((e) => e['status'] == 'upcoming').toList(),
      'ongoing': _exams.where((e) => e['status'] == 'ongoing').toList(),
      'completed': _exams.where((e) => e['status'] == 'completed').toList(),
    };

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Mes examens'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF10B981),
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Mes examens', icon: Icon(Icons.quiz)),
            Tab(text: 'Statistiques', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      const TabBar(
                        indicatorColor: Color(0xFF10B981),
                        labelColor: Color(0xFF10B981),
                        unselectedLabelColor: Colors.grey,
                        tabs: [
                          Tab(text: 'À venir', icon: Icon(Icons.schedule)),
                          Tab(text: 'En cours', icon: Icon(Icons.play_circle)),
                          Tab(text: 'Terminés', icon: Icon(Icons.check_circle)),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildExamList(examsByStatus['upcoming']!, 'upcoming'),
                            _buildExamList(examsByStatus['ongoing']!, 'ongoing'),
                            _buildExamList(examsByStatus['completed']!, 'completed'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatisticsTab(examsByStatus),
              ],
            ),
    );
  }

  Widget _buildExamList(List<Map<String, dynamic>> exams, String status) {
    if (exams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _getEmptyMessage(status),
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: exams.length,
      itemBuilder: (context, index) {
        final exam = exams[index];
        final results = _examResults.where((r) => r['examId'] == exam['id']).toList();
        final totalPoints = exam['totalPoints'] ?? 1;
        final avgScore = _getAverageScore(results, totalPoints);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            onTap: () => _viewExamDetails(exam),
            borderRadius: BorderRadius.circular(16),
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
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          status == 'upcoming' ? Icons.schedule :
                          status == 'ongoing' ? Icons.play_circle : Icons.check_circle,
                          color: _getStatusColor(status),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          exam['title'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text('${results.length} élèves'),
                        backgroundColor: Colors.grey[200],
                        labelStyle: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${exam['className']} - ${exam['subject']}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildInfoChip(Icons.timer, '${exam['duration']} min'),
                      const SizedBox(width: 8),
                      _buildInfoChip(Icons.star, '${exam['totalPoints']} pts'),
                      if (results.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _buildInfoChip(
                          Icons.analytics,
                          'Moy: ${avgScore}%',
                          color: _getScoreColor(avgScore.toInt()),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _viewExamDetails(exam),
                        icon: const Icon(Icons.visibility, size: 18),
                        label: const Text('Voir détails'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _deleteExam(exam),
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Supprimer'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatisticsTab(Map<String, List<Map<String, dynamic>>> examsByStatus) {
    final allExams = _exams;
    final allResults = _examResults;
    final totalExams = allExams.length;
    final totalSubmissions = allResults.length;
    final averageScore = totalSubmissions > 0
        ? allResults.fold<double>(0, (sum, r) => sum + (r['score'] ?? 0)) / totalSubmissions
        : 0.0;
    final totalPoints = allExams.fold<int>(0, (sum, e) => sum + (e['totalPoints'] as int? ?? 0));

    final Map<String, Map<String, dynamic>> subjectStats = {};
    for (var exam in allExams) {
      final subject = exam['subject'] ?? 'Sans matière';
      final examResults = allResults.where((r) => r['examId'] == exam['id']).toList();
      final totalPointsExam = exam['totalPoints'] as int? ?? 1;
      final avgForExam = examResults.isNotEmpty
          ? examResults.fold<double>(0, (sum, r) => sum + (r['score'] ?? 0)) / examResults.length
          : 0.0;
      
      if (!subjectStats.containsKey(subject)) {
        subjectStats[subject] = {
          'totalExams': 0,
          'totalPoints': 0,
          'totalSubmissions': 0,
          'totalScores': 0.0,
        };
      }
      subjectStats[subject]!['totalExams'] = (subjectStats[subject]!['totalExams'] as int) + 1;
      subjectStats[subject]!['totalPoints'] = (subjectStats[subject]!['totalPoints'] as int) + totalPointsExam;
      subjectStats[subject]!['totalSubmissions'] = (subjectStats[subject]!['totalSubmissions'] as int) + examResults.length;
      subjectStats[subject]!['totalScores'] = (subjectStats[subject]!['totalScores'] as double) + (avgForExam * examResults.length);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statCard('Examens', totalExams.toString(), Icons.quiz, Colors.purple),
              const SizedBox(width: 12),
              _statCard('Soumissions', totalSubmissions.toString(), Icons.people, Colors.blue),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statCard('Note moyenne', totalExams > 0 ? '${(averageScore / (totalPoints / totalExams)).toStringAsFixed(1)}%' : '0%', Icons.star, Colors.orange),
              const SizedBox(width: 12),
              _statCard('Taux réussite', _getSuccessRate(allResults).toString(), Icons.flag, Colors.green),
            ],
          ),
          
          const SizedBox(height: 24),
          
          const Text(
            'Performance par matière',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...subjectStats.entries.map((entry) {
            final stats = entry.value;
            final totalSub = stats['totalSubmissions'] as int;
            final totalPts = stats['totalPoints'] as int;
            final totalEx = stats['totalExams'] as int;
            final avgScore = totalSub > 0
                ? ((stats['totalScores'] as double) / totalSub / (totalPts / totalEx) * 100).round()
                : 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '$avgScore%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getScoreColor(avgScore),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 8,
                    child: LinearProgressIndicator(
                      value: avgScore / 100,
                      backgroundColor: Colors.grey[200],
                      color: _getScoreColor(avgScore),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stats['totalExams']} examens • ${stats['totalSubmissions']} soumissions',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }),
          
          const SizedBox(height: 24),
          
          const Text(
            'Derniers résultats',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (allResults.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Aucun résultat pour le moment', style: TextStyle(color: Colors.grey[500])),
              ),
            )
          else
            ...allResults.take(5).map((result) {
              final exam = _exams.firstWhere((e) => e['id'] == result['examId'], orElse: () => {});
              final totalPoints = exam['totalPoints'] ?? 1;
              final percentage = ((result['score'] ?? 0) / totalPoints * 100).round();
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getScoreColor(percentage),
                    radius: 20,
                    child: Text('$percentage%', style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                  title: Text(result['studentName'] ?? 'Élève'),
                  subtitle: Text('${exam['title'] ?? 'Examen'} - ${result['score']}/$totalPoints'),
                  trailing: Text(_formatDateShort(result['submittedAt']), style: const TextStyle(fontSize: 11)),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.grey).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color ?? Colors.grey)),
        ],
      ),
    );
  }

  String _getEmptyMessage(String status) {
    switch (status) {
      case 'upcoming': return 'Aucun examen à venir';
      case 'ongoing': return 'Aucun examen en cours';
      case 'completed': return 'Aucun examen terminé';
      default: return 'Aucun examen';
    }
  }

  int _getSuccessRate(List<Map<String, dynamic>> results) {
    if (results.isEmpty) return 0;
    int passed = 0;
    for (var result in results) {
      final exam = _exams.firstWhere((e) => e['id'] == result['examId'], orElse: () => {});
      final totalPoints = exam['totalPoints'] ?? 1;
      final percentage = (result['score'] / totalPoints * 100);
      if (percentage >= 60) passed++;
    }
    return (passed / results.length * 100).round();
  }
}
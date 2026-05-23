// lib/screens/student/exam_question_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class ExamQuestionScreen extends StatefulWidget {
  final Map<String, dynamic> exam;
  final String studentId;
  final String studentName;
  
  const ExamQuestionScreen({
    super.key,
    required this.exam,
    required this.studentId,
    required this.studentName,
  });

  @override
  _ExamQuestionScreenState createState() => _ExamQuestionScreenState();
}

class _ExamQuestionScreenState extends State<ExamQuestionScreen> {
  final PageController _pageController = PageController();
  final Map<int, dynamic> _answers = {};
  int _currentPage = 0;
  int _remainingTime = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _remainingTime = (widget.exam['duration'] ?? 60) * 60;
    _startTimer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
        _startTimer();
      } else if (_remainingTime <= 0 && mounted) {
        _submitExam();
      }
    });
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 🔥 Soumettre l'examen dans Firestore
  Future<void> _submitExam() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      final questions = widget.exam['questions'] as List? ?? [];
      
      int totalScore = 0;
      List<Map<String, dynamic>> answersList = [];
      
      for (var i = 0; i < questions.length; i++) {
        final question = questions[i] as Map<String, dynamic>;
        final answer = _answers[i];
        final correctAnswer = question['correctAnswer'];
        final isCorrect = answer == correctAnswer;
        final points = isCorrect ? (question['points'] as int? ?? 1) : 0;
        totalScore += points;
        
        answersList.add({
          'questionId': i,
          'question': question['text'],
          'answer': answer,
          'correctAnswer': correctAnswer,
          'isCorrect': isCorrect,
          'points': points,
        });
      }
      
      final percentage = (totalScore / (widget.exam['totalPoints'] ?? 1)) * 100;
      
      final resultData = {
        'examId': widget.exam['id'],
        'examTitle': widget.exam['title'],
        'studentId': widget.studentId,
        'studentName': widget.studentName,
        'score': totalScore,
        'totalPoints': widget.exam['totalPoints'] ?? 0,
        'percentage': percentage,
        'answers': answersList,
        'submittedAt': FieldValue.serverTimestamp(),
        'isGraded': true,
        'schoolId': schoolId,
      };
      
      await FirebaseFirestore.instance.collection('exam_results').add(resultData);
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Épreuve terminée ! Score: $totalScore/${widget.exam['totalPoints']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la soumission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la soumission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final questions = widget.exam['questions'] as List? ?? [];
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exam['title'] ?? 'Examen'),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatTime(_remainingTime),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _remainingTime < 300 ? Colors.red : Colors.blue,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Soumission en cours...'),
                ],
              ),
            )
          : Column(
              children: [
                LinearProgressIndicator(
                  value: (_currentPage + 1) / questions.length,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                Flexible(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (page) {
                      setState(() => _currentPage = page);
                    },
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final question = questions[index] as Map<String, dynamic>;
                      return _buildQuestionCard(index, question);
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentPage > 0)
                        OutlinedButton.icon(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Précédent'),
                        ),
                      if (_currentPage < questions.length - 1)
                        ElevatedButton.icon(
                          onPressed: () {
                            if (_answers[_currentPage] != null) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Suivant'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      if (_currentPage == questions.length - 1)
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitExam,
                          icon: const Icon(Icons.check),
                          label: const Text('Terminer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildQuestionCard(int index, Map<String, dynamic> question) {
    final type = question['type'] ?? 'multiple_choice';
    final options = question['options'] as List? ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Question ${index + 1}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                question['text'] ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              if (type == 'multiple_choice')
                ...options.map((option) => RadioListTile<dynamic>(
                  title: Text(option),
                  value: option,
                  groupValue: _answers[index],
                  onChanged: (value) {
                    setState(() {
                      _answers[index] = value;
                    });
                  },
                  activeColor: Colors.blue,
                )).toList(),
              if (type == 'true_false')
                Row(
                  children: [
                    Flexible(
                      child: _buildTrueFalseButton(index, 'Vrai', Colors.green),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: _buildTrueFalseButton(index, 'Faux', Colors.red),
                    ),
                  ],
                ),
              if (type == 'open_ended')
                TextFormField(
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Écrivez votre réponse...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (value) {
                    _answers[index] = value;
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrueFalseButton(int index, String label, Color color) {
    final isSelected = _answers[index] == label;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _answers[index] = label;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.grey[200],
        foregroundColor: isSelected ? Colors.white : Colors.grey[800],
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 16)),
    );
  }
}
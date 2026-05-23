// lib/screens/student/student_grades.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class StudentGradesScreen extends StatefulWidget {
  const StudentGradesScreen({super.key});

  @override
  _StudentGradesScreenState createState() => _StudentGradesScreenState();
}

class _StudentGradesScreenState extends State<StudentGradesScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> grades = [];
  Map<String, List<Map<String, dynamic>>> gradesBySubject = {};
  Map<String, double> averages = {};
  bool _isLoading = true;
  String? _studentId;
  String? _studentName;
  late AnimationController _animationController;

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
        // Récupérer l'étudiant via son compte utilisateur
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
          _studentName = studentData['fullName'];
          
          print('✅ Étudiant trouvé: $_studentName');
          
          // Charger les notes pour cet étudiant
          final gradesSnapshot = await FirebaseFirestore.instance
              .collection('grades')
              .where('studentName', isEqualTo: _studentName)
              .get();
          
          grades = [];
          for (var doc in gradesSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            grades.add({
              'id': doc.id,
              'studentName': data['studentName'] ?? '',
              'subject': data['subject'] ?? '',
              'evaluationType': data['evaluationType'] ?? '',
              'score': (data['score'] as num?)?.toDouble() ?? 0.0,
              'maxScore': (data['maxScore'] as num?)?.toDouble() ?? 20.0,
              'coefficient': (data['coefficient'] as num?)?.toDouble() ?? 1.0,
              'date': data['date'] != null ? (data['date'] as Timestamp).toDate() : DateTime.now(),
              'comments': data['comments'] ?? '',
            });
          }
          
          // Organiser par matière
          gradesBySubject.clear();
          for (var grade in grades) {
            final subject = grade['subject'] as String;
            if (!gradesBySubject.containsKey(subject)) {
              gradesBySubject[subject] = [];
            }
            gradesBySubject[subject]!.add(grade);
          }
          
          // Calculer les moyennes par matière
          averages.clear();
          for (var subject in gradesBySubject.keys) {
            final subjectGrades = gradesBySubject[subject]!;
            double totalWeighted = 0;
            double totalCoeff = 0;
            for (var grade in subjectGrades) {
              final score = grade['score'] as double;
              final maxScore = grade['maxScore'] as double;
              final normalizedScore = (score / maxScore) * 20;
              final coefficient = grade['coefficient'] as double;
              totalWeighted += normalizedScore * coefficient;
              totalCoeff += coefficient;
            }
            averages[subject] = totalCoeff > 0 ? (totalWeighted / totalCoeff).roundToDouble() : 0;
          }
          
          print('✅ ${grades.length} notes chargées');
        } else {
          print('⚠️ Aucun étudiant trouvé');
          grades = [];
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

  double _calculateOverallAverage() {
    if (averages.isEmpty) return 0;
    
    double total = 0;
    double totalCoef = 0;
    
    for (var subject in averages.keys) {
      final subjectGrades = gradesBySubject[subject] ?? [];
      if (subjectGrades.isNotEmpty) {
        final coef = subjectGrades.first['coefficient'] as double;
        total += averages[subject]! * coef;
        totalCoef += coef;
      }
    }
    
    return totalCoef > 0 ? (total / totalCoef).roundToDouble() : 0;
  }

  Color _getSubjectColor(String subject) {
    switch (subject) {
      case 'Mathématiques': return const Color(0xFFEF4444);
      case 'Français': return const Color(0xFF3B82F6);
      case 'Anglais': return const Color(0xFF10B981);
      case 'Physique': return const Color(0xFFF59E0B);
      case 'Chimie': return const Color(0xFF8B5CF6);
      case 'Histoire': return const Color(0xFF8B5CF6);
      case 'Géographie': return const Color(0xFF14B8A6);
      case 'SVT': return const Color(0xFF6366F1);
      case 'EPS': return const Color(0xFFEC4899);
      default: return const Color(0xFF6366F1);
    }
  }

  Color _getGradeColor(double score, double maxScore) {
    final percentage = (score / maxScore) * 100;
    if (percentage >= 80) return const Color(0xFF10B981);
    if (percentage >= 60) return const Color(0xFF3B82F6);
    if (percentage >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _getGradeLabel(double score, double maxScore) {
    final percentage = (score / maxScore) * 100;
    if (percentage >= 80) return 'Excellent';
    if (percentage >= 60) return 'Très bien';
    if (percentage >= 40) return 'Moyen';
    return 'Insuffisant';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))),
            SizedBox(height: 16),
            Text('Chargement des notes...'),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Mes notes',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
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

            // Carte de moyenne générale
            FadeTransition(
              opacity: _animationController,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Moyenne générale',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_calculateOverallAverage().toStringAsFixed(2)}/20',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${grades.length} note(s)',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Liste des matières
            if (gradesBySubject.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.grade, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune note disponible',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Les notes seront affichées ici',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
              )
            else
              ...gradesBySubject.keys.map((subject) {
                final subjectGrades = gradesBySubject[subject]!;
                final average = averages[subject] ?? 0;
                
                return FadeTransition(
                  opacity: _animationController,
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: ExpansionTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _getSubjectColor(subject),
                              _getSubjectColor(subject).withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            subject.isNotEmpty ? subject[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        subject,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: average >= 10
                                  ? const Color(0xFF10B981).withOpacity(0.1)
                                  : const Color(0xFFF59E0B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Moyenne: ${average.toStringAsFixed(2)}/20',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: average >= 10 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${subjectGrades.length} note(s)',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                      children: [
                        ...subjectGrades.map((grade) {
                          final score = grade['score'] as double;
                          final maxScore = grade['maxScore'] as double;
                          final gradeColor = _getGradeColor(score, maxScore);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: gradeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.assignment, color: gradeColor, size: 20),
                              ),
                              title: Text(
                                grade['evaluationType'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: (grade['comments'] as String).isNotEmpty
                                  ? Text(
                                      grade['comments'],
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    )
                                  : null,
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: gradeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${score.toStringAsFixed(1)}/${maxScore.toStringAsFixed(1)}',
                                      style: TextStyle(
                                        color: gradeColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      _getGradeLabel(score, maxScore),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: gradeColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
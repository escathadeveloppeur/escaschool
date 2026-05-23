// lib/screens/parent/parent_grades.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class ParentGradesScreen extends StatefulWidget {
  const ParentGradesScreen({super.key});

  @override
  _ParentGradesScreenState createState() => _ParentGradesScreenState();
}

class _ParentGradesScreenState extends State<ParentGradesScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> children = [];
  Map<String, dynamic>? selectedChild;
  List<Map<String, dynamic>> grades = [];
  Map<String, List<Map<String, dynamic>>> gradesBySubject = {};
  bool _isLoading = true;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadChildrenAndGrades();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les enfants et notes depuis Firestore
  Future<void> _loadChildrenAndGrades() async {
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?.id;
    final userEmail = auth.user?.email;
    final schoolId = auth.currentSchoolId;

    if (userId != null || userEmail != null) {
      try {
        // Récupérer les enfants via parent_student_links
        Query parentLinksQuery = FirebaseFirestore.instance
            .collection('parent_student_links');
        
        if (userEmail != null) {
          parentLinksQuery = parentLinksQuery.where('parentEmail', isEqualTo: userEmail);
        } else {
          parentLinksQuery = parentLinksQuery.where('parentUserId', isEqualTo: userId);
        }
        
        final linksSnapshot = await parentLinksQuery.get();
        
        final List<String> childNames = [];
        for (var linkDoc in linksSnapshot.docs) {
          final data = linkDoc.data() as Map<String, dynamic>;
          final childName = data['studentName'];
          if (childName != null) {
            childNames.add(childName);
          }
        }
        
        // Récupérer les étudiants
        if (childNames.isNotEmpty) {
          final studentsSnapshot = await FirebaseFirestore.instance
              .collection('students')
              .where('fullName', whereIn: childNames)
              .get();
          
          children = studentsSnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {
              'firestoreId': doc.id,
              'fullName': data['fullName'] ?? '',
              'className': data['className'] ?? '',
              'schoolId': data['schoolId'],
            };
          }).toList();
          
          if (schoolId != null) {
            children = children.where((s) => s['schoolId'] == schoolId).toList();
          }
        }

        if (children.isNotEmpty) {
          selectedChild = children.first;
          await _loadGradesFromFirestore(selectedChild!);
        }
      } catch (e) {
        print('❌ Erreur chargement: $e');
        _showSnackBar('Erreur de chargement', const Color(0xFFEF4444));
      }
    }

    setState(() => _isLoading = false);
    _animationController.forward(from: 0);
  }

  /// 🔥 Charger notes depuis Firestore
  Future<void> _loadGradesFromFirestore(Map<String, dynamic> child) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('grades')
        .where('studentName', isEqualTo: child['fullName'])
        .get();
    
    grades = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'studentName': data['studentName'] ?? '',
        'className': data['className'] ?? '',
        'subject': data['subject'] ?? '',
        'score': (data['score'] as num?)?.toDouble() ?? 0.0,
        'coefficient': (data['coefficient'] as num?)?.toDouble() ?? 1.0,
        'date': data['date'] != null ? (data['date'] as Timestamp).toDate() : DateTime.now(),
        'teacher': data['teacher'] ?? '',
      };
    }).toList();
    
    // Trier par date (plus récent en premier)
    grades.sort((a, b) => b['date'].compareTo(a['date']));
    _organizeGradesBySubject();
  }

  void _organizeGradesBySubject() {
    gradesBySubject.clear();
    for (var grade in grades) {
      final subject = grade['subject'] as String;
      if (!gradesBySubject.containsKey(subject)) {
        gradesBySubject[subject] = [];
      }
      gradesBySubject[subject]!.add(grade);
    }
  }

  double _calculateAverageForSubject(List<Map<String, dynamic>> subjectGrades) {
    double totalWeighted = 0;
    double totalCoefficient = 0;
    for (var grade in subjectGrades) {
      totalWeighted += (grade['score'] as double) * (grade['coefficient'] as double);
      totalCoefficient += grade['coefficient'] as double;
    }
    return totalCoefficient > 0 ? totalWeighted / totalCoefficient : 0;
  }

  double _calculateOverallAverage() {
    double totalWeighted = 0;
    double totalCoefficient = 0;
    for (var grades in gradesBySubject.values) {
      for (var grade in grades) {
        totalWeighted += (grade['score'] as double) * (grade['coefficient'] as double);
        totalCoefficient += grade['coefficient'] as double;
      }
    }
    return totalCoefficient > 0 ? totalWeighted / totalCoefficient : 0;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 16) return const Color(0xFF10B981);
    if (score >= 14) return const Color(0xFF8B5CF6);
    if (score >= 12) return const Color(0xFF3B82F6);
    if (score >= 10) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Notes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)), 
        backgroundColor: Colors.white, 
        foregroundColor: Colors.grey[800], 
        elevation: 0, 
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadChildrenAndGrades)],
      ),
      body: Column(
        children: [
          if (auth.currentSchoolId != null)
            Container(
              margin: const EdgeInsets.all(16), 
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
              decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), 
              child: Row(children: [const Icon(Icons.business, size: 18, color: Color(0xFF3B82F6)), const SizedBox(width: 8), Text(auth.schoolName ?? 'Établissement scolaire', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6)))]),
            ),

          if (children.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    Icon(Icons.child_care, size: 64, color: Colors.grey[300]), 
                    const SizedBox(height: 16), 
                    Text('Aucun enfant associé', style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
            ),
          if (children.isNotEmpty)
            Expanded(
              child: Column(
                children: [
                  if (children.length > 1)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16), 
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]), 
                      child: DropdownButtonFormField<Map<String, dynamic>>(
                        value: selectedChild,
                        decoration: const InputDecoration(border: InputBorder.none, prefixIcon: Icon(Icons.child_care, color: Color(0xFF10B981)), labelText: 'Choisir un enfant'),
                        items: children.map((child) {
                          return DropdownMenuItem(
                            value: child,
                            child: Text(child['fullName']),
                          );
                        }).toList(),
                        onChanged: (value) async { 
                          setState(() => _isLoading = true); 
                          selectedChild = value; 
                          await _loadGradesFromFirestore(value!); 
                          setState(() => _isLoading = false); 
                        },
                      ),
                    ),
                  if (children.length > 1) const SizedBox(height: 8),

                  // Moyenne générale
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]), borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        const Text('Moyenne Générale', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(_calculateOverallAverage().toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(selectedChild?['className'] ?? '', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),

                  Expanded(
                    child: selectedChild == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center, 
                              children: [
                                Icon(Icons.child_care, size: 64, color: Colors.grey[300]), 
                                const SizedBox(height: 16), 
                                Text('Sélectionnez un enfant', style: TextStyle(color: Colors.grey[500])),
                              ],
                            ),
                          )
                        : gradesBySubject.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center, 
                                  children: [
                                    Icon(Icons.grade, size: 64, color: Colors.grey[300]), 
                                    const SizedBox(height: 16), 
                                    Text('Aucune note enregistrée', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: gradesBySubject.keys.length,
                                itemBuilder: (context, index) {
                                  final subject = gradesBySubject.keys.elementAt(index);
                                  final subjectGrades = gradesBySubject[subject]!;
                                  final average = _calculateAverageForSubject(subjectGrades);
                                  final avgColor = _getScoreColor(average);
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
                                    child: ExpansionTile(
                                      leading: Container(
                                        width: 48, height: 48, 
                                        decoration: BoxDecoration(color: avgColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), 
                                        child: Center(child: Text(subject.isNotEmpty ? subject[0].toUpperCase() : '?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: avgColor))),
                                      ),
                                      title: Text(subject, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                      subtitle: Text('${subjectGrades.length} évaluation(s)', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
                                        decoration: BoxDecoration(color: avgColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), 
                                        child: Text(average.toStringAsFixed(2), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: avgColor)),
                                      ),
                                      children: subjectGrades.map((grade) {
                                        final scoreColor = _getScoreColor(grade['score']);
                                        return Container(
                                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                                          child: ListTile(
                                            leading: Container(
                                              width: 40, height: 40, 
                                              decoration: BoxDecoration(color: scoreColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), 
                                              child: Icon(Icons.quiz, color: scoreColor, size: 20),
                                            ),
                                            title: Text('Note : ${(grade['score'] as double).toStringAsFixed(2)} / 20', style: TextStyle(fontWeight: FontWeight.w500)),
                                            subtitle: Text('Coefficient : ${(grade['coefficient'] as double).toStringAsFixed(1)} • ${_formatDate(grade['date'])}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                            trailing: Chip(
                                              label: Text('${(grade['score'] as double).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: scoreColor)), 
                                              backgroundColor: scoreColor.withOpacity(0.1),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
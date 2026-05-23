// lib/screens/parent/parent_children.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../models/student_model.dart';
import '../../providers/auth_provider.dart';
import 'parent_grades.dart';
import 'parent_attendance.dart';
import 'parent_schedule.dart';

class ParentChildrenScreen extends StatefulWidget {
  const ParentChildrenScreen({super.key});

  @override
  _ParentChildrenScreenState createState() => _ParentChildrenScreenState();
}

class _ParentChildrenScreenState extends State<ParentChildrenScreen>
    with SingleTickerProviderStateMixin {
  final DBHelper db = DBHelper();
  List<StudentModel> children = [];
  bool _isLoading = true;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadChildrenFromFirestore();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les enfants du parent depuis Firestore
  Future<void> _loadChildrenFromFirestore() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    final userEmail = authProvider.user?.email;
    final schoolId = authProvider.currentSchoolId;

    if (userId != null || userEmail != null) {
      try {
        // Récupérer les liens parent-enfant
        Query parentLinksQuery = FirebaseFirestore.instance
            .collection('parent_student_links');
        
        if (userEmail != null) {
          parentLinksQuery = parentLinksQuery.where('parentEmail', isEqualTo: userEmail);
        } else {
          parentLinksQuery = parentLinksQuery.where('parentUserId', isEqualTo: userId);
        }
        
        final linksSnapshot = await parentLinksQuery.get();
        
        final List<String> childNames = [];
        final Map<String, String> childRelations = {};
        
        for (var linkDoc in linksSnapshot.docs) {
          final data = linkDoc.data() as Map<String, dynamic>;
          final childName = data['studentName'];
          final relation = data['relation'] ?? 'Parent';
          if (childName != null) {
            childNames.add(childName);
            childRelations[childName] = relation;
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
            return StudentModel(
              fullName: data['fullName'] ?? '',
              className: data['className'] ?? '',
              birthDate: data['birthDate'] ?? '',
              birthPlace: data['birthPlace'] ?? '',
              fatherName: data['fatherName'] ?? '',
              motherName: data['motherName'] ?? '',
              parentPhone: data['parentPhone'] ?? '',
              address: data['address'] ?? '',
              schoolId: schoolId,
              parentRelation: childRelations[data['fullName']] ?? 'Parent',
            );
          }).toList();
          
          children = children.where((s) => s.schoolId == schoolId).toList();
        }
        
        print('✅ ${children.length} enfants chargés depuis Firestore');
      } catch (e) {
        print('❌ Erreur chargement enfants: $e');
        // Fallback vers Hive
        if (userId != null) {
          children = await db.getStudentsForParent(userId);
          children = children.where((s) => s.schoolId == schoolId).toList();
        }
        if (mounted) {
          _showSnackBar('Erreur lors du chargement', const Color(0xFFEF4444));
        }
      }
    }

    setState(() => _isLoading = false);
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

  Color _getChildColor(String className) {
    if (className.contains('6ème') || className.contains('6e')) return const Color(0xFF3B82F6);
    if (className.contains('5ème') || className.contains('5e')) return const Color(0xFF10B981);
    if (className.contains('4ème') || className.contains('4e')) return const Color(0xFFF59E0B);
    if (className.contains('3ème') || className.contains('3e')) return const Color(0xFF8B5CF6);
    if (className.contains('2nde') || className.contains('2nd')) return const Color(0xFF14B8A6);
    if (className.contains('1ère') || className.contains('1e')) return const Color(0xFFEC4899);
    if (className.contains('Term')) return const Color(0xFF6366F1);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Mes enfants', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadChildrenFromFirestore),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (auth.currentSchoolId != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [const Icon(Icons.business, size: 18, color: Color(0xFF3B82F6)), const SizedBox(width: 8), Text('Établissement : ${auth.schoolName ?? 'Votre école'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6)))]),
                    ),

                  FadeTransition(
                    opacity: _animationController,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          const Icon(Icons.family_restroom, color: Colors.white, size: 36),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Mes enfants', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)), Text('${children.length} enfant(s) inscrit(s)', style: const TextStyle(color: Colors.white70, fontSize: 14))])),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  if (children.isEmpty)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 60),
                          Icon(Icons.child_care, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('Aucun enfant associé', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                          const SizedBox(height: 8),
                          Text('Contactez l\'administration pour lier vos enfants', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: children.length,
                      itemBuilder: (context, index) {
                        final child = children[index];
                        final childColor = _getChildColor(child.className);
                        return FadeTransition(
                          opacity: _animationController,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                            child: ExpansionTile(
                              leading: Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(gradient: LinearGradient(colors: [childColor, childColor.withOpacity(0.7)]), shape: BoxShape.circle),
                                child: Center(child: Text(child.fullName.isNotEmpty ? child.fullName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                              ),
                              title: Text(child.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Classe : ${child.className}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                                  if (child.parentRelation != null)
                                    Text('Relation : ${child.parentRelation}', style: TextStyle(fontSize: 12, color: childColor, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  color: Colors.grey[50],
                                  child: Column(
                                    children: [
                                      _buildInfoRow('Date naissance', child.birthDate),
                                      _buildInfoRow('Lieu naissance', child.birthPlace),
                                      _buildInfoRow('Père', child.fatherName),
                                      _buildInfoRow('Mère', child.motherName),
                                      _buildInfoRow('Téléphone', child.parentPhone),
                                      _buildInfoRow('Adresse', child.address),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      _buildActionButton(icon: Icons.grade, label: 'Notes', color: const Color(0xFF10B981), onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const ParentGradesScreen())); }),
                                      const SizedBox(width: 12),
                                      _buildActionButton(icon: Icons.calendar_today, label: 'Présences', color: const Color(0xFF3B82F6), onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const ParentAttendanceScreen())); }),
                                      const SizedBox(width: 12),
                                      _buildActionButton(icon: Icons.schedule, label: 'Emploi du temps', color: const Color(0xFFF59E0B), onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const ParentScheduleScreen())); }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    final displayValue = (value == null || value.isEmpty) ? 'Non renseigné' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700]))),
          Expanded(child: Text(displayValue, style: TextStyle(color: value == null || value.isEmpty ? Colors.grey : Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
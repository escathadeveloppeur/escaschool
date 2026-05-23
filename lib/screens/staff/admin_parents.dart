// lib/screens/staff/admin_parents.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class AdminParents extends StatefulWidget {
  final VoidCallback onChanged;
  
  const AdminParents({super.key, required this.onChanged});

  @override
  _AdminParentsState createState() => _AdminParentsState();
}

class _AdminParentsState extends State<AdminParents> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _parents = [];
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
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

  /// 🔥 Charger les parents et leurs enfants depuis Firestore
  Future<void> _loadDataFromFirestore() async {
    setState(() => _loading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      // 1. Charger les parents (rôle 'parent')
      Query parentQuery = FirebaseFirestore.instance.collection('users');
      parentQuery = parentQuery.where('role', isEqualTo: 'parent');
      
      if (schoolId != null && !auth.isSuperAdmin) {
        parentQuery = parentQuery.where('schoolId', isEqualTo: schoolId);
      }
      
      final parentsSnapshot = await parentQuery.get();
      
      _parents = parentsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'name': data['name'] ?? '',
          'email': data['email'] ?? '',
          'schoolId': data['schoolId'],
        };
      }).toList();
      
      // 2. Charger les étudiants pour lier les parents
      Query studentQuery = FirebaseFirestore.instance.collection('students');
      if (schoolId != null && !auth.isSuperAdmin) {
        studentQuery = studentQuery.where('schoolId', isEqualTo: schoolId);
      }
      
      final studentsSnapshot = await studentQuery.get();
      
      _students = studentsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'fullName': data['fullName'] ?? '',
          'className': data['className'] ?? '',
          'parentUserId': data['parentUserId'],
          'parentEmail': data['parentEmail'],
          'parentRelation': data['parentRelation'],
        };
      }).toList();
      
      _animationController.forward(from: 0);
      
      print('✅ ${_parents.length} parents chargés depuis Firestore');
      print('✅ ${_students.length} étudiants chargés');
    } catch (e) {
      debugPrint("❌ Erreur chargement parents: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Obtenir les enfants d'un parent
  List<Map<String, dynamic>> _getChildrenForParent(String parentFirestoreId, String parentEmail) {
    return _students.where((student) {
      return student['parentUserId'] == parentFirestoreId || 
             student['parentEmail'] == parentEmail;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
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

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.family_restroom, color: Color(0xFF8B5CF6), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Parents (${_parents.length})",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Expanded(
                  child: _parents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.family_restroom, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                "Aucun parent",
                                style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Les parents doivent d'abord s'inscrire via l'application",
                                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _parents.length,
                          itemBuilder: (context, index) {
                            final parent = _parents[index];
                            final children = _getChildrenForParent(parent['firestoreId'], parent['email']);
                            
                            return FadeTransition(
                              opacity: _animationController,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ExpansionTile(
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        (parent['name'] as String).isNotEmpty 
                                            ? (parent['name'] as String)[0].toUpperCase() 
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    parent['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        parent['email'],
                                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${children.length} enfant(s)',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF3B82F6),
                                      ),
                                    ),
                                  ),
                                  children: children.isEmpty
                                      ? [
                                          const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Center(
                                              child: Text("Aucun enfant associé"),
                                            ),
                                          ),
                                        ]
                                      : children.map((child) {
                                          return Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[50],
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: ListTile(
                                              leading: const Icon(Icons.child_care, color: Color(0xFF10B981)),
                                              title: Text(
                                                child['fullName'],
                                                style: const TextStyle(fontWeight: FontWeight.w500),
                                              ),
                                              subtitle: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Classe: ${child['className']}'),
                                                  if (child['parentRelation'] != null && child['parentRelation']!.isNotEmpty)
                                                    Text(
                                                      'Relation: ${child['parentRelation']}',
                                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
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
}
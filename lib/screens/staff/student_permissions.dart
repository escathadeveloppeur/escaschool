// lib/screens/staff/student_permissions.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../models/student_model.dart';
import '../../providers/auth_provider.dart';

class StudentPermissionsScreen extends StatefulWidget {
  final String studentFirestoreId;
  final String studentName;
  
  const StudentPermissionsScreen({
    super.key,
    required this.studentFirestoreId,
    required this.studentName,
  });

  @override
  _StudentPermissionsScreenState createState() => _StudentPermissionsScreenState();
}

class _StudentPermissionsScreenState extends State<StudentPermissionsScreen> {
  final DBHelper db = DBHelper();
  
  List<Map<String, dynamic>> _allClasses = [];
  String? _currentClassName;
  String? _currentClassFirestoreId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDataFromFirestore();
  }

  /// 🔥 Charger les classes et la classe de l'étudiant depuis Firestore
  Future<void> _loadDataFromFirestore() async {
    setState(() => _loading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      // 1. Charger toutes les classes de l'école
      Query classQuery = FirebaseFirestore.instance.collection('classes');
      if (schoolId != null && !auth.isSuperAdmin) {
        classQuery = classQuery.where('schoolId', isEqualTo: schoolId);
      }
      
      final classesSnapshot = await classQuery.get();
      
      _allClasses = classesSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'className': data['className'] ?? '',
          'level': data['level'] ?? '',
          'year': data['year'] ?? '',
        };
      }).toList();
      
      // 2. Charger l'étudiant pour connaître sa classe actuelle
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentFirestoreId)
          .get();
      
      if (studentDoc.exists) {
        final data = studentDoc.data() as Map<String, dynamic>;
        _currentClassName = data['className'];
        _currentClassFirestoreId = data['classFirestoreId'];
      }
      
      print('✅ ${_allClasses.length} classes chargées');
      print('✅ Classe actuelle: $_currentClassName');
    } catch (e) {
      print('❌ Erreur chargement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// 🔥 Assigner l'étudiant à une classe dans Firestore
  Future<void> _assignToClass(String classFirestoreId, String className) async {
    if (className.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: Nom de classe invalide'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      // Mettre à jour l'étudiant dans Firestore
      await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentFirestoreId)
          .update({
        'className': className,
        'classFirestoreId': classFirestoreId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Mettre à jour localement aussi
      final studentsBox = await db.getStudentsBox();
      for (var key in studentsBox.keys) {
        final student = studentsBox.get(key);
        if (student != null && student.userId?.toString() == widget.studentFirestoreId) {
          final updatedStudent = StudentModel(
            fullName: student.fullName,
            className: className,
            birthDate: student.birthDate,
            birthPlace: student.birthPlace,
            fatherName: student.fatherName,
            motherName: student.motherName,
            parentPhone: student.parentPhone,
            address: student.address,
            documentsVerified: student.documentsVerified,
            userId: student.userId,
            schoolId: schoolId,
          );
          await studentsBox.put(key, updatedStudent);
          break;
        }
      }
      
      await _loadDataFromFirestore();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.studentName} assigné à la classe $className'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur assignation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 🔥 Retirer l'étudiant de sa classe dans Firestore
  Future<void> _removeFromClass() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      // Mettre à jour l'étudiant dans Firestore
      await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentFirestoreId)
          .update({
        'className': '',
        'classFirestoreId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Mettre à jour localement aussi
      final studentsBox = await db.getStudentsBox();
      for (var key in studentsBox.keys) {
        final student = studentsBox.get(key);
        if (student != null && student.userId?.toString() == widget.studentFirestoreId) {
          final updatedStudent = StudentModel(
            fullName: student.fullName,
            className: '',
            birthDate: student.birthDate,
            birthPlace: student.birthPlace,
            fatherName: student.fatherName,
            motherName: student.motherName,
            parentPhone: student.parentPhone,
            address: student.address,
            documentsVerified: student.documentsVerified,
            userId: student.userId,
            schoolId: schoolId,
          );
          await studentsBox.put(key, updatedStudent);
          break;
        }
      }
      
      await _loadDataFromFirestore();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.studentName} retiré de sa classe'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur retrait: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Classe de ${widget.studentName}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDataFromFirestore,
          ),
          if (auth.currentSchoolId != null)
            IconButton(
              icon: const Icon(Icons.cloud_sync),
              onPressed: () async {
                await _loadDataFromFirestore();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Synchronisation terminée'), backgroundColor: Colors.green),
                );
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Étudiant',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.studentName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),
                          
                          Text(
                            'Classe actuelle',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          
                          if (_currentClassName != null && _currentClassName!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _currentClassName!,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: _removeFromClass,
                                    tooltip: 'Retirer de la classe',
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning, color: Colors.orange),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Aucune classe assignée',
                                      style: TextStyle(color: Colors.orange),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  const Text(
                    'Classes disponibles',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Expanded(
                    child: _allClasses.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.warning, size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucune classe disponible',
                                  style: TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _allClasses.length,
                            itemBuilder: (context, index) {
                              final cls = _allClasses[index];
                              final className = cls['className'];
                              final classFirestoreId = cls['firestoreId'];
                              final isCurrentClass = _currentClassFirestoreId == classFirestoreId;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                color: isCurrentClass ? Colors.green[50] : null,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isCurrentClass ? Colors.green : Colors.blue,
                                    child: Icon(
                                      Icons.class_,
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text(
                                    className,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text('Niveau: ${cls['level']} • ${cls['year']}'),
                                  trailing: isCurrentClass
                                      ? Chip(
                                          label: Text('Actuelle'),
                                          backgroundColor: Colors.green,
                                          labelStyle: const TextStyle(color: Colors.white),
                                        )
                                      : ElevatedButton(
                                          onPressed: () => _assignToClass(classFirestoreId, className),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: const Text('Assigner'),
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
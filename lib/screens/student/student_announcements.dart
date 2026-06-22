// lib/screens/student/student_announcements.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class StudentAnnouncementsScreen extends StatefulWidget {
  const StudentAnnouncementsScreen({super.key});

  @override
  _StudentAnnouncementsScreenState createState() => _StudentAnnouncementsScreenState();
}

class _StudentAnnouncementsScreenState extends State<StudentAnnouncementsScreen> {
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;
  String? _studentClassId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// ✅ Fonction pour extraire la date de manière sécurisée
  DateTime _extractDate(dynamic dateField) {
    if (dateField == null) return DateTime.now();
    
    if (dateField is Timestamp) {
      return dateField.toDate();
    }
    
    if (dateField is String) {
      try {
        return DateTime.parse(dateField);
      } catch (e) {
        print('⚠️ Erreur parse date: $e');
        return DateTime.now();
      }
    }
    
    if (dateField is DateTime) {
      return dateField;
    }
    
    return DateTime.now();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      final user = auth.user;
      final userId = user?.id;

      if (schoolId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // ✅ Récupérer la classe de l'étudiant depuis la collection 'students'
      if (userId != null) {
        final studentSnapshot = await FirebaseFirestore.instance
            .collection('students')
            .where('userId', isEqualTo: userId)
            .limit(1)
            .get();

        if (studentSnapshot.docs.isNotEmpty) {
          final studentData = studentSnapshot.docs.first.data() as Map<String, dynamic>;
          _studentClassId = studentData['classFirestoreId'] ?? studentData['classId'];
          print('✅ Classe de l\'étudiant: $_studentClassId');
        }
      }

      // Charger les annonces
      final snapshot = await FirebaseFirestore.instance
          .collection('announcements')
          .where('schoolId', isEqualTo: schoolId)
          .orderBy('date', descending: true)
          .get();

      final List<Map<String, dynamic>> loaded = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final audience = data['audience'] ?? 'all';
        final classId = data['classId'];
        
        // ✅ Étudiant : voit "Tout le monde" + "Étudiants" + "Sa classe"
        bool canSee = audience == 'all' || audience == 'students';
        
        if (audience == 'specific_class' && _studentClassId != null) {
          canSee = _studentClassId == classId;
        }
        
        if (canSee) {
          // ✅ Utiliser _extractDate pour gérer les deux types
          final date = _extractDate(data['date']);
          
          loaded.add({
            'id': doc.id,
            'title': data['title'] ?? '',
            'content': data['content'] ?? '',
            'date': date,
            'isPinned': data['isPinned'] ?? false,
            'createdByName': data['createdByName'] ?? 'Admin',
          });
        }
      }

      setState(() {
        _announcements = loaded;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Mes annonces', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _announcements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.campaign_rounded, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune annonce pour vous',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _announcements.length,
                  itemBuilder: (context, index) {
                    final ann = _announcements[index];
                    final date = ann['date'] as DateTime? ?? DateTime.now();
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (ann['isPinned'] == true)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.push_pin, size: 12, color: Colors.orange),
                                        SizedBox(width: 4),
                                        Text('Épinglé', style: TextStyle(fontSize: 10, color: Colors.orange)),
                                      ],
                                    ),
                                  ),
                                const Spacer(),
                                Text(
                                  '${date.day}/${date.month}/${date.year}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ann['title'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ann['content'] ?? '',
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Publié par: ${ann['createdByName']}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
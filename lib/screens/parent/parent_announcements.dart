// lib/screens/parent/parent_announcements.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../models/student_model.dart';

class ParentAnnouncementsScreen extends StatefulWidget {
  const ParentAnnouncementsScreen({super.key});

  @override
  _ParentAnnouncementsScreenState createState() => _ParentAnnouncementsScreenState();
}

class _ParentAnnouncementsScreenState extends State<ParentAnnouncementsScreen> {
  List<Map<String, dynamic>> _announcements = [];
  List<StudentModel> _children = [];
  List<Map<String, dynamic>> _absences = [];
  bool _isLoading = true;
  bool _isLoadingAbsences = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _isLoadingAbsences = true;
    });
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      final userId = auth.user?.id;
      final userEmail = auth.user?.email;

      print('🔍 DEBUG - userId: $userId');
      print('🔍 DEBUG - userEmail: $userEmail');

      if (schoolId == null) {
        setState(() {
          _isLoading = false;
          _isLoadingAbsences = false;
        });
        return;
      }

      // 1️⃣ Récupérer les enfants du parent
      Query parentLinksQuery = FirebaseFirestore.instance
          .collection('parent_student_links');
      
      if (userEmail != null) {
        parentLinksQuery = parentLinksQuery.where('parentEmail', isEqualTo: userEmail);
      } else {
        parentLinksQuery = parentLinksQuery.where('parentUserId', isEqualTo: userId);
      }
      
      final linksSnapshot = await parentLinksQuery.get();
      
      final List<String> childNames = [];
      final List<String> childIds = [];
      
      for (var linkDoc in linksSnapshot.docs) {
        final data = linkDoc.data() as Map<String, dynamic>;
        final childName = data['studentName'];
        final childId = data['studentId'];
        if (childName != null) {
          childNames.add(childName);
          childIds.add(childId);
        }
      }
      
      print('🔍 DEBUG - Enfants trouvés: $childNames');

      // 2️⃣ Récupérer les détails des enfants
      if (childNames.isNotEmpty) {
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('students')
            .where('fullName', whereIn: childNames)
            .get();

        _children = studentsSnapshot.docs.map((doc) {
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
          );
        }).toList();
      }

      // 3️⃣ Récupérer les absences des enfants (UNIQUEMENT les non justifiées)
      _absences = [];
      if (childIds.isNotEmpty) {
        for (var childId in childIds) {
          print('🔍 DEBUG - Recherche absences pour studentId: $childId');
          
          // ✅ Récupérer les absences où reason est NULL ou vide
          final absencesSnapshot = await FirebaseFirestore.instance
              .collection('attendances')
              .where('studentFirestoreId', isEqualTo: childId)
              .where('status', isEqualTo: 'absent')
              // ⚠️ Note: Firestore ne permet pas de filtrer sur 'reason == null'
              // On va donc récupérer toutes les absences et filtrer côté client
              .get();

          print('🔍 DEBUG - ${absencesSnapshot.docs.length} absences trouvées');

          for (var doc in absencesSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            
            // ✅ Vérifier si l'absence est justifiée (reason non null et non vide)
            final reason = data['reason'] as String?;
            final isJustified = reason != null && reason.isNotEmpty;
            
            // ✅ On garde UNIQUEMENT les absences NON justifiées
            if (!isJustified) {
              // Gérer la date
              DateTime date;
              if (data['date'] is Timestamp) {
                date = (data['date'] as Timestamp).toDate();
              } else if (data['date'] is String) {
                try {
                  date = DateTime.parse(data['date'] as String);
                } catch (e) {
                  date = DateTime.now();
                }
              } else {
                date = DateTime.now();
              }
              
              _absences.add({
                'id': doc.id,
                'studentName': data['studentName'] ?? '',
                'studentFirestoreId': childId,
                'date': date,
                'className': data['className'] ?? '',
                'reason': reason ?? '', // reason est null, on met une chaîne vide
                'isJustified': false,
                'status': data['status'] ?? 'absent',
                'subject': data['subject'] ?? '',
                'schoolId': data['schoolId'],
              });
            }
          }
        }
      }

      // 4️⃣ Récupérer les annonces
      final snapshot = await FirebaseFirestore.instance
          .collection('announcements')
          .where('schoolId', isEqualTo: schoolId)
          .orderBy('date', descending: true)
          .get();

      final List<Map<String, dynamic>> loaded = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final audience = data['audience'] ?? 'all';
        
        bool canSee = audience == 'all' || audience == 'parents';
        
        if (canSee) {
          DateTime date;
          if (data['date'] is Timestamp) {
            date = (data['date'] as Timestamp).toDate();
          } else if (data['date'] is String) {
            try {
              date = DateTime.parse(data['date'] as String);
            } catch (e) {
              date = DateTime.now();
            }
          } else {
            date = DateTime.now();
          }
          
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
        _isLoadingAbsences = false;
      });
      
      print('✅ ${_absences.length} absences non justifiées trouvées');
      print('✅ ${_announcements.length} annonces trouvées');
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() {
        _isLoading = false;
        _isLoadingAbsences = false;
      });
    }
  }

  /// ✅ Soumettre une justification d'absence
  Future<void> _submitJustification(String absenceId, String studentName, String reason) async {
    try {
      // ✅ Mettre à jour l'absence avec le motif (reason)
      await FirebaseFirestore.instance
          .collection('attendances')
          .doc(absenceId)
          .update({
        'reason': reason, // ✅ Le champ reason est maintenant rempli
        'justifiedAt': FieldValue.serverTimestamp(),
        'justifiedBy': 'parent',
      });

      // Ajouter un message de notification pour l'école
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': 'parent',
        'senderName': 'Parent',
        'recipientRole': 'admin',
        'subject': 'Justification d\'absence',
        'content': 'Le parent a justifié l\'absence de $studentName. Motif: $reason',
        'studentName': studentName,
        'type': 'justification',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Absence de $studentName justifiée avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      // Recharger les données
      await _loadData();
    } catch (e) {
      print('❌ Erreur justification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// ✅ Afficher le dialogue de justification
  void _showJustificationDialog(Map<String, dynamic> absence) {
    final TextEditingController reasonController = TextEditingController();
    final studentName = absence['studentName'] ?? 'Inconnu';
    final date = absence['date'] as DateTime? ?? DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.note_add_rounded, color: Color(0xFFF59E0B), size: 28),
            const SizedBox(width: 10),
            const Text('Justifier une absence', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '👨‍👩‍👦 Enfant: $studentName',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '📅 Date: ${date.day}/${date.month}/${date.year}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '📚 Matière: ${absence['subject'] ?? 'Non spécifiée'}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            const Text(
              'Motif de l\'absence:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Ex: Maladie, Rendez-vous médical...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                prefixIcon: Icon(Icons.description_rounded),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Veuillez indiquer un motif'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              Navigator.pop(context);
              await _submitJustification(
                absence['id'], 
                studentName, 
                reasonController.text.trim()
              );
            },
            icon: const Icon(Icons.send_rounded),
            label: const Text('Envoyer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Espace Parent', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: const Color(0xFF10B981),
            labelColor: const Color(0xFF10B981),
            unselectedLabelColor: Colors.grey[600],
            tabs: [
              Tab(
                icon: const Icon(Icons.campaign_rounded),
                text: 'Annonces (${_announcements.length})',
              ),
              Tab(
                icon: Badge(
                  label: Text('${_absences.length}'),
                  backgroundColor: _absences.isEmpty ? Colors.transparent : Colors.red,
                  child: const Icon(Icons.warning_rounded),
                ),
                text: 'Absences (${_absences.length})',
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildAnnouncementsTab(),
            _buildAbsencesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_announcements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.campaign_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Aucune annonce',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _announcements.length,
      itemBuilder: (context, index) {
        final ann = _announcements[index];
        return _buildAnnouncementCard(ann);
      },
    );
  }

  Widget _buildAbsencesTab() {
    if (_isLoadingAbsences) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_absences.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, size: 64, color: Colors.green[300]),
            const SizedBox(height: 16),
            Text(
              '✅ Aucune absence à justifier',
              style: TextStyle(color: Colors.green[600], fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Tous vos enfants sont présents',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _absences.length,
      itemBuilder: (context, index) {
        final absence = _absences[index];
        return _buildAbsenceCard(absence);
      },
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final isPinned = announcement['isPinned'] ?? false;
    final date = announcement['date'] as DateTime? ?? DateTime.now();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                CircleAvatar(
                  backgroundColor: isPinned ? Colors.orange : Colors.purple,
                  radius: 20,
                  child: Icon(
                    isPinned ? Icons.push_pin : Icons.campaign,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement['title'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Par: ${announcement['createdByName']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${date.day}/${date.month}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              announcement['content'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsenceCard(Map<String, dynamic> absence) {
    final date = absence['date'] as DateTime? ?? DateTime.now();
    final studentName = absence['studentName'] ?? 'Inconnu';
    final className = absence['className'] ?? '';
    final subject = absence['subject'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.person_off_rounded, color: Color(0xFFEF4444), size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.class_rounded, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            className.isNotEmpty ? 'Classe: $className' : 'Classe non spécifiée',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (subject.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.book_rounded, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              'Matière: $subject',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cette absence n\'a pas encore été justifiée',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showJustificationDialog(absence),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Justifier cette absence'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
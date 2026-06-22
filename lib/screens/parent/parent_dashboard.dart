// lib/screens/parent/parent_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/db_helper.dart';
import '../../models/student_model.dart';
import '../login_screen.dart';
import 'parent_children.dart';
import 'parent_payments.dart';
import 'parent_documents.dart';
import 'parent_messages.dart';
import 'parent_announcements.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  _ParentDashboardState createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard>
    with SingleTickerProviderStateMixin {
  final DBHelper db = DBHelper();
  
  int _selectedIndex = 0;
  late AnimationController _animationController;
  
  List<StudentModel> _children = [];
  int _pendingPayments = 0;
  int _unreadMessages = 0;
  int _totalDocuments = 0;
  int _totalAbsences = 0;
  int _newGradesCount = 0;
  bool _isLoading = true;

  late List<Widget> _pages;
  late List<Map<String, dynamic>> _menuItems;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadDashboardDataFromFirestore();
    
    _menuItems = [
      {'title': 'Accueil', 'icon': Icons.dashboard, 'color': const Color(0xFF3B82F6)},
      {'title': 'Mes enfants', 'icon': Icons.family_restroom, 'color': const Color(0xFF10B981)},
      {'title': 'Paiements', 'icon': Icons.payment, 'color': const Color(0xFFEF4444)},
      {'title': 'Documents', 'icon': Icons.folder, 'color': const Color(0xFF8B5CF6)},
      {'title': 'Messages', 'icon': Icons.message, 'color': const Color(0xFFEC4899)},
      {'title': 'Annonces', 'icon': Icons.campaign, 'color': const Color(0xFFF97316)},
    ];
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les données du dashboard depuis Firestore
  Future<void> _loadDashboardDataFromFirestore() async {
    setState(() => _isLoading = true);
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?.id;
    final userEmail = auth.user?.email;
    final schoolId = auth.currentSchoolId;
    
    if (userId != null || userEmail != null) {
      try {
        // 1. Récupérer les enfants via les liens parent-enfant
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
        
        // 2. Récupérer les étudiants
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
          
          _children = _children.where((s) => s.schoolId == schoolId).toList();
        }
        
        final childNamesList = _children.map((c) => c.fullName).toList();
        final childIdsList = _children.map((c) => c.userId).toList();
        
        // 3. ✅ Compter les absences non justifiées (basé sur le champ reason)
        _totalAbsences = 0;
        if (childNamesList.isNotEmpty) {
          for (var childName in childNamesList) {
            // ✅ Récupérer les absences où reason est null ou vide
            final absencesSnapshot = await FirebaseFirestore.instance
                .collection('attendances')
                .where('studentName', isEqualTo: childName)
                .where('status', isEqualTo: 'absent')
                .get();
            
            // Filtrer les absences non justifiées (reason null ou vide)
            for (var doc in absencesSnapshot.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final reason = data['reason'] as String?;
              // Si reason est null ou vide, c'est une absence non justifiée
              if (reason == null || reason.isEmpty) {
                _totalAbsences++;
              }
            }
          }
        }
        
        // 4. ✅ Compter les nouvelles notes/moyennes publiées
        _newGradesCount = 0;
        if (childNamesList.isNotEmpty) {
          final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
          
          for (var childName in childNamesList) {
            final gradesSnapshot = await FirebaseFirestore.instance
                .collection('grades')
                .where('studentName', isEqualTo: childName)
                .get();
            
            // Filtrer les notes récentes
            for (var doc in gradesSnapshot.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final publishedAt = data['publishedAt'];
              if (publishedAt != null) {
                DateTime pubDate;
                if (publishedAt is Timestamp) {
                  pubDate = publishedAt.toDate();
                } else if (publishedAt is String) {
                  try {
                    pubDate = DateTime.parse(publishedAt as String);
                  } catch (e) {
                    continue;
                  }
                } else {
                  continue;
                }
                if (pubDate.isAfter(sevenDaysAgo)) {
                  _newGradesCount++;
                }
              }
            }
          }
        }
        
        // 5. Compter les paiements en attente
        if (childNamesList.isNotEmpty) {
          final paymentsSnapshot = await FirebaseFirestore.instance
              .collection('payments')
              .where('fullName', whereIn: childNamesList)
              .where('status', isEqualTo: 'pending')
              .get();
          _pendingPayments = paymentsSnapshot.docs.length;
        }
        
        // 6. Compter les messages non lus
        if (childNamesList.isNotEmpty) {
          final messagesSnapshot = await FirebaseFirestore.instance
              .collection('messages')
              .where('recipientRole', isEqualTo: 'parent')
              .where('read', isEqualTo: false)
              .get();
          
          _unreadMessages = messagesSnapshot.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return childNamesList.contains(data['studentName']);
          }).length;
        }
        
        // 7. Compter les documents validés
        if (childNamesList.isNotEmpty) {
          final documentsSnapshot = await FirebaseFirestore.instance
              .collection('documents')
              .where('fullName', whereIn: childNamesList)
              .where('isValidated', isEqualTo: true)
              .get();
          _totalDocuments = documentsSnapshot.docs.length;
        }
        
        print('✅ Dashboard parent chargé: ${_children.length} enfants');
        print('📊 Absences non justifiées: $_totalAbsences');
        print('📊 Nouvelles notes: $_newGradesCount');
        print('📊 Paiements en attente: $_pendingPayments');
        print('📊 Messages non lus: $_unreadMessages');
        print('📊 Documents: $_totalDocuments');
      } catch (e) {
        print('❌ Erreur chargement dashboard: $e');
        // Fallback vers Hive
        if (userId != null) {
          _children = await db.getStudentsForParent(userId);
          _children = _children.where((s) => s.schoolId == schoolId).toList();
          final allPayments = await db.getAllPayments();
          final childNamesList = _children.map((c) => c.fullName).toList();
          _pendingPayments = allPayments.where((p) => childNamesList.contains(p.fullName) && p.status == 'pending').length;
        }
      }
    }
    
    setState(() => _isLoading = false);
    _animationController.forward(from: 0);
  }

  /// ✅ Afficher le dialogue de justification d'absence
  void _showJustificationDialog(BuildContext context, String childName) {
    final TextEditingController reasonController = TextEditingController();
    
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
              'Enfant: $childName',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
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
              
              await _submitJustification(childName, reasonController.text.trim());
              Navigator.pop(context);
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

  /// ✅ Soumettre une justification d'absence
  Future<void> _submitJustification(String childName, String reason) async {
    try {
      // Récupérer les absences non justifiées de l'élève (reason null ou vide)
      final absencesSnapshot = await FirebaseFirestore.instance
          .collection('attendances')
          .where('studentName', isEqualTo: childName)
          .where('status', isEqualTo: 'absent')
          .get();
      
      final List<Map<String, dynamic>> unJustifiedAbsences = [];
      for (var doc in absencesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final currentReason = data['reason'] as String?;
        if (currentReason == null || currentReason.isEmpty) {
          unJustifiedAbsences.add({
            'id': doc.id,
            'data': data,
          });
        }
      }
      
      if (unJustifiedAbsences.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune absence à justifier pour cet élève'),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
        return;
      }
      
      // Mettre à jour chaque absence avec la justification
      for (var absence in unJustifiedAbsences) {
        await FirebaseFirestore.instance
            .collection('attendances')
            .doc(absence['id'])
            .update({
          'reason': reason, // ✅ Remplir le champ reason
          'justifiedAt': FieldValue.serverTimestamp(),
          'justifiedBy': 'parent',
        });
      }
      
      // Ajouter un message de notification pour l'école
      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': 'parent',
        'senderName': 'Parent',
        'recipientRole': 'admin',
        'subject': 'Justification d\'absence',
        'content': 'Le parent a justifié l\'absence de $childName. Motif: $reason',
        'studentName': childName,
        'type': 'justification',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Absence de $childName justifiée avec succès'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      
      // Recharger les données
      await _loadDashboardDataFromFirestore();
      
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

  Widget _buildHomePage() {
    final auth = Provider.of<AuthProvider>(context);
    
    return RefreshIndicator(
      onRefresh: _loadDashboardDataFromFirestore,
      color: const Color(0xFF10B981),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (auth.currentSchoolId != null && !auth.isSuperAdmin)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [const Icon(Icons.business, size: 18, color: Color(0xFF3B82F6)), const SizedBox(width: 8), Text(auth.schoolName ?? 'Établissement scolaire', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6)))]),
              ),

            FadeTransition(
              opacity: _animationController,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]), borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bonjour,', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(auth.user?.name ?? 'Parent', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Bienvenue sur votre espace parent', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text('Aperçu rapide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildStatCard('Enfants', _children.length.toString(), Icons.family_restroom, const Color(0xFF10B981)),
                  _buildStatCard('Documents', _totalDocuments.toString(), Icons.folder, const Color(0xFF8B5CF6)),
                  _buildStatCard('Paiements', '$_pendingPayments en attente', Icons.payment, const Color(0xFFF59E0B)),
                  _buildStatCard('Absences', '$_totalAbsences à justifier', Icons.warning, const Color(0xFFEF4444)),
                ],
              ),
            
            if (_totalAbsences > 0 || _newGradesCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _totalAbsences > 0 
                        ? const Color(0xFFEF4444).withOpacity(0.1) 
                        : const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _totalAbsences > 0 
                          ? const Color(0xFFEF4444).withOpacity(0.3) 
                          : const Color(0xFF10B981).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_totalAbsences > 0)
                        InkWell(
                          onTap: () {
                            _showAbsencesListDialog(context);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '⚠️ $_totalAbsences absence(s) non justifiée(s)',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                      const Text(
                                        'Cliquez pour justifier',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFEF4444)),
                              ],
                            ),
                          ),
                        ),
                      if (_totalAbsences > 0 && _newGradesCount > 0)
                        const Divider(),
                      if (_newGradesCount > 0)
                        InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('📊 $_newGradesCount nouvelle(s) note(s) disponible(s)'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.grade_rounded, color: Color(0xFF10B981), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '📊 $_newGradesCount nouvelle(s) note(s) publiée(s)',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                      const Text(
                                        'Consultez les résultats de votre enfant',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF10B981)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Mes enfants', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_children.isEmpty)
                      const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Aucun enfant associé')))
                    else
                      ..._children.map((child) => _buildChildItem(child)),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () { setState(() => _selectedIndex = 1); },
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('Voir tous mes enfants'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Derniers messages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_unreadMessages == 0 && _pendingPayments == 0 && _totalDocuments == 0)
                      const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Aucune notification', style: TextStyle(color: Colors.grey))))
                    else ...[
                      if (_unreadMessages > 0)
                        _buildMessageItem('Message de l\'école', '$_unreadMessages message(s) non lu(s)', Icons.message, const Color(0xFFEC4899)),
                      if (_pendingPayments > 0)
                        _buildMessageItem('Paiements en attente', '$_pendingPayments paiement(s) à effectuer', Icons.payment, const Color(0xFFF59E0B)),
                      if (_totalDocuments > 0)
                        _buildMessageItem('Nouveaux documents', '$_totalDocuments document(s) disponible(s)', Icons.folder, const Color(0xFF8B5CF6)),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text('Accès rapide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.9,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _menuItems.length - 1,
              itemBuilder: (context, index) {
                final item = _menuItems[index + 1];
                return _buildQuickMenuItem(
                  item['title'], 
                  item['icon'], 
                  item['color'], 
                  () { setState(() => _selectedIndex = index + 1); }
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAbsencesListDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxHeight: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 28),
                      const SizedBox(width: 10),
                      const Text(
                        'Absences à justifier',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: FutureBuilder(
                      future: _getAbsencesWithDetails(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
                          return const Center(
                            child: Text('Aucune absence à justifier'),
                          );
                        }
                        
                        final absences = snapshot.data as List<Map<String, dynamic>>;
                        
                        return ListView.builder(
                          itemCount: absences.length,
                          itemBuilder: (context, index) {
                            final absence = absences[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFEF4444).withOpacity(0.1),
                                  child: const Icon(Icons.person_off_rounded, color: Color(0xFFEF4444)),
                                ),
                                title: Text(absence['studentName'] ?? 'Inconnu'),
                                subtitle: Text('Date: ${_formatDate(absence['date'])}'),
                                trailing: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showJustificationDialog(context, absence['studentName'] ?? '');
                                  },
                                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                                  label: const Text('Justifier'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF59E0B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// ✅ Récupérer les absences avec détails
  Future<List<Map<String, dynamic>>> _getAbsencesWithDetails() async {
    final List<Map<String, dynamic>> absences = [];
    
    try {
      for (var child in _children) {
        final snapshot = await FirebaseFirestore.instance
            .collection('attendances')
            .where('studentName', isEqualTo: child.fullName)
            .where('status', isEqualTo: 'absent')
            .get();
        
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final reason = data['reason'] as String?;
          // ✅ Seulement les absences non justifiées (reason null ou vide)
          if (reason == null || reason.isEmpty) {
            absences.add({
              'id': doc.id,
              'studentName': child.fullName,
              'date': data['date'],
              'className': child.className,
            });
          }
        }
      }
    } catch (e) {
      print('❌ Erreur récupération absences: $e');
    }
    
    return absences;
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Date inconnue';
    try {
      final DateTime d;
      if (date is Timestamp) {
        d = date.toDate();
      } else if (date is String) {
        d = DateTime.parse(date);
      } else {
        return 'Date inconnue';
      }
      return '${d.day}/${d.month}/${d.year}';
    } catch (e) {
      return 'Date inconnue';
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildChildItem(StudentModel child) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: _getChildColor(child.className), child: Text(child.fullName.isNotEmpty ? child.fullName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      title: Text(child.fullName, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text('Classe : ${child.className}'),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const ParentChildrenScreen())).then((_) => _loadDashboardDataFromFirestore()); },
    );
  }

  Widget _buildMessageItem(String title, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 16)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w500)), Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),])),
        Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
      ],
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

  Widget _buildQuickMenuItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 26)),
          const SizedBox(height: 6),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _pages = [
      _buildHomePage(),
      const ParentChildrenScreen(),
      const ParentPaymentsScreen(),
      const ParentDocumentsScreen(),
      const ParentMessagesScreen(),
      const ParentAnnouncementsScreen(),
    ];
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_menuItems[_selectedIndex]['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.sync), onPressed: _loadDashboardDataFromFirestore),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _showLogoutDialog(context)),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: _menuItems[_selectedIndex]['color'],
        unselectedItemColor: Colors.grey,
        onTap: (index) { setState(() => _selectedIndex = index); },
        items: _menuItems.map((item) => BottomNavigationBarItem(icon: Icon(item['icon']), label: item['title'])).toList(),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(onPressed: () { Provider.of<AuthProvider>(context, listen: false).logout(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)), child: const Text('Déconnexion')),
        ],
      ),
    );
  }
}
// lib/screens/admin/admin_announcements.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';
import 'add_announcement.dart';

// ===================== PALETTE / THEME HELPERS =====================
class _AppColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B5BDB);
  static const Color background = Color(0xFFF4F6FB);
  static const Color cardBorder = Color(0xFFE6E9F2);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  static const Color secondary = Color(0xFF8B5CF6);
}

class AdminAnnouncements extends StatefulWidget {
  final VoidCallback? onChanged;
  const AdminAnnouncements({super.key, this.onChanged});

  @override
  _AdminAnnouncementsState createState() => _AdminAnnouncementsState();
}

class _AdminAnnouncementsState extends State<AdminAnnouncements> {
  final DBHelper db = DBHelper();
  List<Map<String, dynamic>> announcements = [];
  List<Map<String, dynamic>> filteredAnnouncements = [];
  List<Map<String, dynamic>> _justifications = [];
  final TextEditingController searchController = TextEditingController();

  String _selectedAudienceFilter = 'all';
  String _selectedTab = 'announcements';

  final List<Map<String, dynamic>> _audienceFilterOptions = [
    {'id': 'all', 'label': '📢 Toutes', 'icon': Icons.public, 'color': _AppColors.primary},
    {'id': 'students', 'label': '👨‍🎓 Étudiants', 'icon': Icons.school, 'color': _AppColors.info},
    {'id': 'teachers', 'label': '👨‍🏫 Enseignants', 'icon': Icons.person, 'color': _AppColors.success},
    {'id': 'parents', 'label': '👨‍👩‍👦 Parents', 'icon': Icons.family_restroom, 'color': _AppColors.warning},
    {'id': 'staff', 'label': '👔 Personnel', 'icon': Icons.work, 'color': _AppColors.secondary},
    {'id': 'admins', 'label': '👨‍💼 Admins', 'icon': Icons.admin_panel_settings, 'color': _AppColors.danger},
  ];

  @override
  void initState() {
    super.initState();
    _loadAnnouncementsFromFirestore();
    _loadJustificationsFromFirestore();
    searchController.addListener(_filterAnnouncements);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  /// 🔥 Fonction utilitaire pour convertir la date
  DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    
    // Si c'est déjà un Timestamp
    if (dateValue is Timestamp) {
      return dateValue.toDate();
    }
    
    // Si c'est une chaîne de caractères
    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        print('⚠️ Erreur parsing date: $dateValue');
        return DateTime.now();
      }
    }
    
    // Si c'est un DateTime
    if (dateValue is DateTime) {
      return dateValue;
    }
    
    return DateTime.now();
  }

  bool _canSeeAnnouncement(Map<String, dynamic> announcement, User? user) {
    if (user == null) return false;
    
    final audience = announcement['audience'] ?? 'all';
    final targetedRoles = List<String>.from(announcement['targetedRoles'] ?? []);
    final classId = announcement['classId'];
    
    if (user.isSuperAdmin) return true;
    
    switch (audience) {
      case 'all': return true;
      case 'students': return user.role == 'student';
      case 'teachers': return user.role == 'teacher';
      case 'parents': return user.role == 'parent';
      case 'staff': return user.role == 'staff';
      case 'admins': return user.role == 'admin' || user.role == 'super_admin';
      case 'specific_class': return user.role == 'student' && user.schoolId == classId;
      default: return true;
    }
  }

  void _filterAnnouncements() {
    final query = searchController.text.toLowerCase().trim();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = auth.user;
    
    setState(() {
      filteredAnnouncements = announcements.where((a) {
        if (_selectedAudienceFilter != 'all') {
          final audience = a['audience'] ?? 'all';
          if (audience != _selectedAudienceFilter) return false;
        }
        
        if (query.isNotEmpty) {
          final title = (a['title'] ?? "").toLowerCase();
          final content = (a['content'] ?? "").toLowerCase();
          if (!title.contains(query) && !content.contains(query)) return false;
        }
        
        if (currentUser != null) {
          return _canSeeAnnouncement(a, currentUser);
        }
        
        return true;
      }).toList();
    });
  }

  Future<void> _loadAnnouncementsFromFirestore() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;
    final currentUser = auth.user;

    try {
      Query query = FirebaseFirestore.instance.collection('announcements');
      
      if (!auth.isSuperAdmin && schoolId != null) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.orderBy('date', descending: true).get();
      
      final List<Map<String, dynamic>> loadedAnnouncements = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        final audience = data['audience'] ?? 'all';
        final targetedRoles = List<String>.from(data['targetedRoles'] ?? []);
        final audienceLabel = data['audienceLabel'] ?? _getAudienceLabel(audience);
        final audienceDescription = data['audienceDescription'] ?? _getAudienceDescription(audience);
        
        // ✅ Correction: utiliser _parseDate au lieu de (data['date'] as Timestamp)
        final date = _parseDate(data['date']);
        
        final announcement = {
          'id': doc.id,
          'firestoreId': doc.id,
          'title': data['title'] ?? '',
          'content': data['content'] ?? '',
          'date': date.toIso8601String(),
          'schoolId': data['schoolId'],
          'createdBy': data['createdBy'],
          'createdByName': data['createdByName'] ?? 'Admin',
          'audience': audience,
          'targetedRoles': targetedRoles,
          'classId': data['classId'],
          'className': data['className'],
          'audienceLabel': audienceLabel,
          'audienceDescription': audienceDescription,
          'canView': currentUser != null ? _canSeeAnnouncement(data, currentUser) : true,
        };
        
        loadedAnnouncements.add(announcement);
      }
      
      setState(() {
        announcements = loadedAnnouncements;
        _filterAnnouncements();
      });
      
      print('✅ ${loadedAnnouncements.length} annonces chargées');
    } catch (e) {
      print('❌ Erreur chargement annonces: $e');
      final all = await db.getAllAnnouncements();
      setState(() {
        announcements = all;
        _filterAnnouncements();
      });
    }
  }

  /// ✅ Charger les justifications des parents (avec raison)
  Future<void> _loadJustificationsFromFirestore() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      print('🔍 Chargement des justifications...');
      
      Query query = FirebaseFirestore.instance
          .collection('attendances')
          .where('status', isEqualTo: 'absent');
      
      if (!auth.isSuperAdmin && schoolId != null) {
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('students')
            .where('schoolId', isEqualTo: schoolId)
            .get();
        
        final studentNames = studentsSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['fullName'] ?? '';
        }).toList();
        
        if (studentNames.isNotEmpty) {
          query = query.where('studentName', whereIn: studentNames);
        } else {
          setState(() {
            _justifications = [];
          });
          return;
        }
      }
      
      final snapshot = await query.get();
      
      final List<Map<String, dynamic>> loadedJustifications = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        final reason = data['reason'] as String?;
        final justifiedBy = data['justifiedBy'] as String?;
        final justifiedAt = data['justifiedAt'];
        
        if (reason != null && reason.isNotEmpty && justifiedBy == 'parent') {
          // ✅ Correction: utiliser _parseDate pour la date
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
          
          // ✅ Correction: utiliser _parseDate pour justifiedAt
          DateTime justifiedDate;
          if (justifiedAt is Timestamp) {
            justifiedDate = justifiedAt.toDate();
          } else if (justifiedAt is String) {
            try {
              justifiedDate = DateTime.parse(justifiedAt as String);
            } catch (e) {
              justifiedDate = DateTime.now();
            }
          } else {
            justifiedDate = DateTime.now();
          }
          
          loadedJustifications.add({
            'id': doc.id,
            'studentName': data['studentName'] ?? '',
            'className': data['className'] ?? '',
            'date': date,
            'reason': reason,
            'justifiedAt': justifiedDate,
            'justifiedBy': justifiedBy ?? 'parent',
            'status': data['status'] ?? 'absent',
            'subject': data['subject'] ?? '',
            'studentFirestoreId': data['studentFirestoreId'],
          });
        }
      }
      
      loadedJustifications.sort((a, b) {
        final dateA = a['justifiedAt'] as DateTime;
        final dateB = b['justifiedAt'] as DateTime;
        return dateB.compareTo(dateA);
      });
      
      setState(() {
        _justifications = loadedJustifications;
      });
      
      print('✅ ${loadedJustifications.length} justifications chargées');
    } catch (e) {
      print('❌ Erreur chargement justifications: $e');
      setState(() {
        _justifications = [];
      });
    }
  }

  String _getAudienceLabel(String audience) {
    final options = {
      'all': '📢 Tout le monde',
      'students': '👨‍🎓 Étudiants',
      'teachers': '👨‍🏫 Enseignants',
      'parents': '👨‍👩‍👦 Parents',
      'staff': '👔 Personnel',
      'admins': '👨‍💼 Admins',
      'specific_class': '🏫 Classe spécifique',
    };
    return options[audience] ?? 'Tout le monde';
  }

  String _getAudienceDescription(String audience) {
    final descriptions = {
      'all': 'Visible par tous les utilisateurs',
      'students': 'Visible uniquement par les étudiants',
      'teachers': 'Visible uniquement par les enseignants',
      'parents': 'Visible uniquement par les parents',
      'staff': 'Visible uniquement par le personnel',
      'admins': 'Visible uniquement par les administrateurs',
      'specific_class': 'Visible uniquement par les étudiants d\'une classe spécifique',
    };
    return descriptions[audience] ?? 'Visible par tous';
  }

  Future<void> _markJustificationAsProcessed(String justificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('attendances')
          .doc(justificationId)
          .update({
        'processed': true,
        'processedAt': FieldValue.serverTimestamp(),
        'processedBy': 'admin',
      });
      
      await _loadJustificationsFromFirestore();
      _showSnackBar('Justification marquée comme traitée', _AppColors.success);
    } catch (e) {
      _showSnackBar('Erreur: $e', _AppColors.danger);
    }
  }

  Future<void> _deleteAnnouncement(String firestoreId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Voulez-vous vraiment supprimer cette annonce ?'),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: _AppColors.textMuted),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('announcements')
            .doc(firestoreId)
            .delete();
        
        final annsMap = await db.getAnnouncementsMap();
        annsMap.removeWhere((key, value) => value['firestoreId'] == firestoreId);
        await db.updateAnnouncements(annsMap);
        
        await _loadAnnouncementsFromFirestore();
        widget.onChanged?.call();
        
        _showSnackBar('Annonce supprimée', _AppColors.success);
      } catch (e) {
        _showSnackBar('Erreur: $e', _AppColors.danger);
      }
    }
  }

  Future<void> _editAnnouncement(String firestoreId, String newTitle, String newContent) async {
    try {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(firestoreId)
          .update({
        'title': newTitle,
        'content': newContent,
        'date': FieldValue.serverTimestamp(),
      });
      
      await _loadAnnouncementsFromFirestore();
      widget.onChanged?.call();
      
      _showSnackBar('Annonce modifiée', _AppColors.success);
    } catch (e) {
      _showSnackBar('Erreur: $e', _AppColors.danger);
    }
  }

  void _showEditDialog(Map<String, dynamic> announcement) async {
    final titleController = TextEditingController(text: announcement['title']);
    final contentController = TextEditingController(text: announcement['content']);
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.edit_rounded, color: _AppColors.warning),
            ),
            const SizedBox(width: 12),
            const Text("Modifier l'annonce", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "Titre",
                prefixIcon: Icon(Icons.title_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: "Contenu",
                prefixIcon: Icon(Icons.description_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _AppColors.textMuted),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'title': titleController.text.trim(),
                'content': contentController.text.trim()
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.warning,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
    
    if (result != null) {
      await _editAnnouncement(announcement['firestoreId'], result['title']!, result['content']!);
    }
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString.substring(0, 16);
    }
  }

  String _formatDateObject(DateTime date) {
    return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildAudienceBadge(String audience, {String? className}) {
    Color color;
    IconData icon;
    String label;
    
    switch (audience) {
      case 'students':
        color = _AppColors.info;
        icon = Icons.school;
        label = 'Étudiants';
        break;
      case 'teachers':
        color = _AppColors.success;
        icon = Icons.person;
        label = 'Enseignants';
        break;
      case 'parents':
        color = _AppColors.warning;
        icon = Icons.family_restroom;
        label = 'Parents';
        break;
      case 'staff':
        color = _AppColors.secondary;
        icon = Icons.work;
        label = 'Personnel';
        break;
      case 'admins':
        color = _AppColors.danger;
        icon = Icons.admin_panel_settings;
        label = 'Admins';
        break;
      case 'specific_class':
        color = _AppColors.success;
        icon = Icons.class_;
        label = className != null ? 'Classe: $className' : 'Classe spécifique';
        break;
      default:
        color = _AppColors.primary;
        icon = Icons.public;
        label = 'Tout le monde';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// ✅ Widget pour afficher une justification avec la raison
  Widget _buildJustificationCard(Map<String, dynamic> justification) {
    final studentName = justification['studentName'] ?? 'Inconnu';
    final className = justification['className'] ?? '';
    final reason = justification['reason'] ?? 'Non spécifié';
    final date = justification['date'] as DateTime? ?? DateTime.now();
    final justifiedAt = justification['justifiedAt'] as DateTime? ?? DateTime.now();
    final subject = justification['subject'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.note_add_rounded, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '✅ Justification - $studentName',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: _AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.class_rounded, size: 12, color: _AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            className.isNotEmpty ? 'Classe: $className' : 'Classe non spécifiée',
                            style: TextStyle(fontSize: 11, color: _AppColors.textMuted),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.calendar_today_rounded, size: 12, color: _AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            _formatDateObject(date),
                            style: TextStyle(fontSize: 11, color: _AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description_rounded, size: 14, color: const Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      const Text(
                        'Motif de la justification:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    style: TextStyle(fontSize: 14, color: _AppColors.textDark),
                  ),
                  if (subject.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.book_rounded, size: 14, color: _AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Matière: $subject',
                          style: TextStyle(fontSize: 12, color: _AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: _AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        'Justifié le: ${_formatDateObject(justifiedAt)}',
                        style: TextStyle(fontSize: 11, color: _AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _markJustificationAsProcessed(justification['id']),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text('Marquer comme traitée'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _AppColors.success,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showJustificationDetailsDialog(justification);
                    },
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text('Détails'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _AppColors.info,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ Dialogue de détails de la justification
  void _showJustificationDetailsDialog(Map<String, dynamic> justification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.assignment_rounded, color: _AppColors.success),
            const SizedBox(width: 10),
            const Text('Détails de la justification', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('👨‍👩‍👦 Élève', justification['studentName'] ?? 'Inconnu'),
              _buildDetailRow('📚 Classe', justification['className'] ?? 'Non spécifiée'),
              _buildDetailRow('📅 Date d\'absence', _formatDateObject(justification['date'] as DateTime? ?? DateTime.now())),
              _buildDetailRow('📝 Motif', justification['reason'] ?? 'Non spécifié'),
              _buildDetailRow('📚 Matière', justification['subject'] ?? 'Non spécifiée'),
              _buildDetailRow('⏰ Justifié le', _formatDateObject(justification['justifiedAt'] as DateTime? ?? DateTime.now())),
              _buildDetailRow('👤 Justifié par', 'Parent'),
              _buildDetailRow('📊 Statut', 'Absence justifiée ✅'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _markJustificationAsProcessed(justification['id']);
            },
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Traiter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: _AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Gestion des annonces',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19, letterSpacing: 0.2),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_AppColors.primary, _AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Actualiser",
            onPressed: () {
              _loadAnnouncementsFromFirestore();
              _loadJustificationsFromFirestore();
            },
          ),
          if (!auth.isSuperAdmin || auth.currentSchoolId != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: "Ajouter une annonce",
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddAnnouncementScreen()),
                  );
                  if (result == true) _loadAnnouncementsFromFirestore();
                },
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          
          // ✅ Onglets (Annonces / Justifications)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _AppColors.cardBorder),
            ),
            child: Row(
              children: [
                _buildTabButton('Annonces', 'announcements', Icons.campaign_rounded),
                _buildTabButton('Justifications (${_justifications.length})', 'justifications', Icons.note_add_rounded),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          Expanded(
            child: _selectedTab == 'announcements'
                ? _buildAnnouncementsList()
                : _buildJustificationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, String tabId, IconData icon) {
    final isSelected = _selectedTab == tabId;
    final color = isSelected ? _AppColors.primary : _AppColors.textMuted;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = tabId;
            if (tabId == 'justifications') {
              _loadJustificationsFromFirestore();
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? _AppColors.primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementsList() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher une annonce...',
              hintStyle: TextStyle(color: _AppColors.textMuted),
              prefixIcon: Icon(Icons.search_rounded, color: _AppColors.primaryLight),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: _AppColors.textMuted),
                      onPressed: () {
                        searchController.clear();
                        _filterAnnouncements();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _AppColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _AppColors.primaryLight, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onChanged: (_) => _filterAnnouncements(),
          ),
        ),
        
        const SizedBox(height: 12),
        
        Container(
          height: 45,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _audienceFilterOptions.length,
            itemBuilder: (context, index) {
              final option = _audienceFilterOptions[index];
              final isSelected = _selectedAudienceFilter == option['id'];
              final color = option['color'] as Color;
              
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAudienceFilter = option['id'];
                      _filterAnnouncements();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? color : _AppColors.cardBorder,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          option['icon'] as IconData,
                          size: 16,
                          color: isSelected ? Colors.white : color,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          option['label'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : _AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 12),
        
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.campaign_rounded, size: 18, color: _AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(
                "Liste des annonces (${filteredAnnouncements.length})",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _AppColors.textDark),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        Expanded(
          child: filteredAnnouncements.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filteredAnnouncements.length,
                  itemBuilder: (context, index) {
                    final announcement = filteredAnnouncements[index];
                    return _buildAnnouncementCard(announcement);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildJustificationsList() {
    return _justifications.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _AppColors.primary.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.note_add_rounded, size: 56, color: _AppColors.primary.withOpacity(0.4)),
                ),
                const SizedBox(height: 20),
                Text(
                  'Aucune justification de parent',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Text(
                  'Les justifications des parents apparaîtront ici',
                  style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: _justifications.length,
            itemBuilder: (context, index) {
              final justification = _justifications[index];
              return _buildJustificationCard(justification);
            },
          );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _AppColors.primary.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.campaign_rounded, size: 56, color: _AppColors.primary.withOpacity(0.4)),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucune annonce disponible',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _AppColors.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            'Cliquez sur le bouton + pour ajouter une annonce',
            style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final audience = announcement['audience'] ?? 'all';
    final className = announcement['className'];
    final createdByName = announcement['createdByName'] ?? 'Admin';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement['title'] ?? 'Sans titre',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: _AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 12, color: _AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(announcement['date'] ?? ''),
                            style: TextStyle(fontSize: 11, color: _AppColors.textMuted),
                          ),
                          const SizedBox(width: 8),
                          _buildAudienceBadge(audience, className: className),
                        ],
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionButton(
                      icon: Icons.edit_rounded,
                      color: _AppColors.warning,
                      onPressed: () => _showEditDialog(announcement),
                    ),
                    const SizedBox(width: 4),
                    _buildActionButton(
                      icon: Icons.delete_rounded,
                      color: _AppColors.danger,
                      onPressed: () => _deleteAnnouncement(announcement['firestoreId']),
                    ),
                  ],
                ),
              ],
            ),
            if (announcement['content'] != null && announcement['content'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement['content'],
                        style: TextStyle(fontSize: 13, color: _AppColors.textMuted, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person_rounded, size: 12, color: _AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Par: $createdByName',
                            style: TextStyle(fontSize: 10, color: _AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 20),
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }
}
// lib/screens/admin/add_announcement.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../providers/auth_provider.dart';
import '../../models/class_model.dart';

class AddAnnouncementScreen extends StatefulWidget {
  final Map<String, dynamic>? announcementToEdit;
  final String? announcementFirestoreId;
  
  const AddAnnouncementScreen({super.key, this.announcementToEdit, this.announcementFirestoreId});

  @override
  _AddAnnouncementScreenState createState() => _AddAnnouncementScreenState();
}

class _AddAnnouncementScreenState extends State<AddAnnouncementScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final DBHelper db = DBHelper();
  bool _isLoading = false;

  // ✅ Options de ciblage basées sur les rôles existants
  String _selectedAudience = 'all';
  String? _selectedClassId;
  String? _selectedClassName;
  List<ClassModel> _classes = [];
  bool _isLoadingClasses = false;

  final List<Map<String, dynamic>> _audienceOptions = [
    {'id': 'all', 'label': '📢 Tout le monde', 'icon': Icons.public, 'color': Color(0xFF6366F1)},
    {'id': 'students', 'label': '👨‍🎓 Étudiants uniquement', 'icon': Icons.school, 'color': Color(0xFF3B82F6)},
    {'id': 'teachers', 'label': '👨‍🏫 Enseignants uniquement', 'icon': Icons.person, 'color': Color(0xFF10B981)},
    {'id': 'parents', 'label': '👨‍👩‍👦 Parents uniquement', 'icon': Icons.family_restroom, 'color': Color(0xFFF59E0B)},
    {'id': 'staff', 'label': '👔 Personnel uniquement', 'icon': Icons.work, 'color': Color(0xFF8B5CF6)},
    {'id': 'admins', 'label': '👨‍💼 Admins uniquement', 'icon': Icons.admin_panel_settings, 'color': Color(0xFFEF4444)},
    {'id': 'specific_class', 'label': '🏫 Classe spécifique', 'icon': Icons.class_, 'color': Color(0xFF10B981)},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.announcementToEdit != null) {
      _titleCtrl.text = widget.announcementToEdit!['title'] ?? '';
      _contentCtrl.text = widget.announcementToEdit!['content'] ?? '';
      _selectedAudience = widget.announcementToEdit!['audience'] ?? 'all';
      _selectedClassId = widget.announcementToEdit!['classId'];
      _selectedClassName = widget.announcementToEdit!['className'];
    }
    _loadClasses();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    if (_selectedAudience != 'specific_class') return;
    
    setState(() => _isLoadingClasses = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      Query query = FirebaseFirestore.instance.collection('classes');
      if (schoolId != null && !auth.isSuperAdmin) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.get();
      _classes = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return ClassModel(
          firestoreId: doc.id,
          className: data['className'] ?? '',
          level: data['level'] ?? '',
          year: data['year'] ?? '',
          cycleType: data['cycleType'] ?? 'primaire',
          subjects: List<Map<String, dynamic>>.from(data['subjects'] ?? []),
          schoolId: data['schoolId'] ?? '',
          sectionId: data['sectionId'] as String?,
          section: data['section'] as String?,
        );
      }).toList();
      
      if (widget.announcementToEdit != null && _selectedClassId != null) {
        final exists = _classes.any((c) => c.firestoreId == _selectedClassId);
        if (!exists) {
          _selectedClassId = null;
          _selectedClassName = null;
        }
      }
    } catch (e) {
      print('❌ Erreur chargement classes: $e');
    } finally {
      setState(() => _isLoadingClasses = false);
    }
  }

  String _getAudienceLabel(String audienceId) {
    final option = _audienceOptions.firstWhere(
      (o) => o['id'] == audienceId,
      orElse: () => _audienceOptions.first,
    );
    return option['label'] ?? 'Tout le monde';
  }

  /// ✅ Récupérer les rôles ciblés pour le filtrage
  List<String> _getTargetedRoles(String audience) {
    switch (audience) {
      case 'students':
        return ['student'];
      case 'teachers':
        return ['teacher'];
      case 'parents':
        return ['parent'];
      case 'staff':
        return ['staff'];
      case 'admins':
        return ['admin', 'super_admin'];
      case 'all':
      default:
        return ['student', 'teacher', 'parent', 'staff', 'admin', 'super_admin'];
    }
  }

  String _getAudienceDescription(String audience) {
    switch (audience) {
      case 'all':
        return 'Tous les utilisateurs de l\'école';
      case 'students':
        return 'Uniquement les étudiants';
      case 'teachers':
        return 'Uniquement les enseignants';
      case 'parents':
        return 'Uniquement les parents';
      case 'staff':
        return 'Uniquement le personnel administratif';
      case 'admins':
        return 'Uniquement les administrateurs';
      case 'specific_class':
        return _selectedClassName != null 
            ? 'Classe : $_selectedClassName' 
            : 'Classe spécifique (à sélectionner)';
      default:
        return 'Tous les utilisateurs';
    }
  }

  Future<void> _saveAnnouncement() async {
    if (_titleCtrl.text.isEmpty || _contentCtrl.text.isEmpty) {
      _showSnackBar('Veuillez remplir tous les champs', Colors.red);
      return;
    }

    if (_selectedAudience == 'specific_class' && _selectedClassId == null) {
      _showSnackBar('Veuillez sélectionner une classe', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;

      final announcementData = {
        'title': _titleCtrl.text,
        'content': _contentCtrl.text,
        'date': FieldValue.serverTimestamp(),
        'schoolId': schoolId,
        'createdBy': auth.user?.firestoreId,
        'createdByName': auth.user?.name ?? 'Admin',
        'updatedAt': FieldValue.serverTimestamp(),
        // ✅ Champs de ciblage
        'audience': _selectedAudience,
        'targetedRoles': _getTargetedRoles(_selectedAudience),
        'classId': _selectedAudience == 'specific_class' ? _selectedClassId : null,
        'className': _selectedAudience == 'specific_class' ? _selectedClassName : null,
        'audienceLabel': _getAudienceLabel(_selectedAudience),
        'audienceDescription': _getAudienceDescription(_selectedAudience),
      };

      if (widget.announcementToEdit == null) {
        // 🔥 Ajouter dans Firestore
        await FirebaseFirestore.instance.collection('announcements').add(announcementData);
        
        await db.addAnnouncement({
          'title': _titleCtrl.text,
          'content': _contentCtrl.text,
          'date': DateTime.now().toIso8601String(),
          'schoolId': schoolId,
          'audience': _selectedAudience,
          'targetedRoles': _getTargetedRoles(_selectedAudience),
          'classId': _selectedAudience == 'specific_class' ? _selectedClassId : null,
          'className': _selectedAudience == 'specific_class' ? _selectedClassName : null,
        });
        
        _showSnackBar('Annonce publiée avec succès', Colors.green);
      } else {
        if (widget.announcementFirestoreId != null) {
          await FirebaseFirestore.instance
              .collection('announcements')
              .doc(widget.announcementFirestoreId)
              .update(announcementData);
          
          if (widget.announcementToEdit != null && widget.announcementToEdit!['id'] != null) {
            final annsMap = await db.getAnnouncementsMap();
            annsMap[widget.announcementToEdit!['id'].toString()] = {
              ...announcementData,
              'id': widget.announcementToEdit!['id'],
              'date': DateTime.now().toIso8601String(),
            };
            await db.updateAnnouncements(annsMap);
          }
          
          _showSnackBar('Annonce modifiée avec succès', Colors.green);
        }
      }
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Erreur: $e');
      _showSnackBar('Erreur: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final schoolId = auth.currentSchoolId;
    final isEditing = widget.announcementToEdit != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          isEditing ? "Modifier l'annonce" : "Ajouter une annonce",
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Indicateur d'école
            if (!auth.isSuperAdmin && schoolId != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      auth.schoolName ?? 'École',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.blue),
                    ),
                  ],
                ),
              ),

            // Carte titre
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.title, color: Colors.blue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Titre de l'annonce",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        hintText: "Entrez le titre...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Carte contenu
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.description, color: Colors.green, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Contenu",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _contentCtrl,
                      decoration: const InputDecoration(
                        hintText: "Rédigez le contenu de l'annonce...",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        alignLabelWithHint: true,
                      ),
                      maxLines: 8,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ✅ Carte Ciblage
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.visibility, color: Colors.purple, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Qui peut voir cette annonce ?",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ✅ Sélecteur d'audience (avec couleurs personnalisées)
                    ..._audienceOptions.map((option) {
                      final isSelected = _selectedAudience == option['id'];
                      final color = option['color'] as Color;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedAudience = option['id'];
                              if (option['id'] != 'specific_class') {
                                _selectedClassId = null;
                                _selectedClassName = null;
                              }
                            });
                            if (option['id'] == 'specific_class') {
                              _loadClasses();
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? color.withOpacity(0.1) 
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected 
                                    ? color 
                                    : Colors.grey[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  option['icon'] as IconData,
                                  color: isSelected ? color : Colors.grey[600],
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    option['label'] as String,
                                    style: TextStyle(
                                      color: isSelected ? color : Colors.grey[800],
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: color,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),

                    // ✅ Sélecteur de classe (si "Classe spécifique" est sélectionné)
                    if (_selectedAudience == 'specific_class') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Sélectionner une classe",
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            if (_isLoadingClasses)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_classes.isEmpty)
                              const Text(
                                "Aucune classe disponible",
                                style: TextStyle(color: Colors.grey),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedClassId,
                                    hint: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Text("Choisir une classe..."),
                                    ),
                                    isExpanded: true,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    items: _classes.map((classModel) {
                                      final label = '${classModel.className} (${classModel.cycleType ?? 'Primaire'})';
                                      return DropdownMenuItem(
                                        value: classModel.firestoreId,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          child: Text(label),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedClassId = value;
                                        final selectedClass = _classes.firstWhere(
                                          (c) => c.firestoreId == value,
                                          orElse: () => ClassModel(
                                            className: '',
                                            schoolId: '',
                                          ),
                                        );
                                        _selectedClassName = selectedClass.className;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            if (_selectedClassId != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Classe sélectionnée",
                                        style: TextStyle(fontSize: 12, color: Colors.green[600]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    // ✅ Aperçu du ciblage
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "👁️ ${_getAudienceDescription(_selectedAudience)}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                if (_selectedAudience != 'all')
                                  Text(
                                    "🔒 Cette annonce est restreinte",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Bouton Publier
            ElevatedButton(
              onPressed: _isLoading ? null : _saveAnnouncement,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      isEditing ? "Modifier l'annonce" : "Publier l'annonce",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text("Annuler"),
            ),
          ],
        ),
      ),
    );
  }
}
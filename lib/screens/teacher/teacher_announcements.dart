// lib/screens/teacher/teacher_announcements.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';

class TeacherAnnouncementsScreen extends StatefulWidget {
  const TeacherAnnouncementsScreen({super.key});

  @override
  _TeacherAnnouncementsScreenState createState() => _TeacherAnnouncementsScreenState();
}

class _TeacherAnnouncementsScreenState extends State<TeacherAnnouncementsScreen> {
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _filteredAnnouncements = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  
  final List<Map<String, dynamic>> _filterOptions = [
    {'id': 'all', 'label': '📢 Toutes', 'icon': Icons.public, 'color': Color(0xFF3B82F6)},
    {'id': 'school', 'label': '🏫 École', 'icon': Icons.business, 'color': Color(0xFF10B981)},
    {'id': 'teachers', 'label': '👨‍🏫 Enseignants', 'icon': Icons.person, 'color': Color(0xFF8B5CF6)},
  ];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
    _searchController.addListener(_filterAnnouncements);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// ✅ Fonction pour extraire la date de manière sécurisée
  DateTime _extractDate(dynamic dateField) {
    if (dateField == null) return DateTime.now();
    
    // Si c'est déjà un Timestamp
    if (dateField is Timestamp) {
      return dateField.toDate();
    }
    
    // Si c'est une String
    if (dateField is String) {
      try {
        return DateTime.parse(dateField);
      } catch (e) {
        print('⚠️ Erreur parse date: $e');
        return DateTime.now();
      }
    }
    
    // Si c'est un DateTime
    if (dateField is DateTime) {
      return dateField;
    }
    
    return DateTime.now();
  }

  /// ✅ Vérifier si l'utilisateur peut voir l'annonce
  bool _canSeeAnnouncement(Map<String, dynamic> announcement, User? user) {
    if (user == null) return false;
    final audience = announcement['audience'] ?? 'all';
    
    final isAdmin = user.role == 'admin' || user.role == 'super_admin';
    
    if (isAdmin) return true;
    
    switch (audience) {
      case 'all': 
        return true;
      case 'teachers': 
        return user.role == 'teacher';
      case 'staff': 
        return user.role == 'staff';
      case 'admins': 
        return user.role == 'admin' || user.role == 'super_admin';
      case 'students': 
        return false;
      case 'parents': 
        return false;
      case 'specific_class': 
        return false;
      default: 
        return true;
    }
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      final currentUser = auth.user;

      if (schoolId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('announcements')
          .where('schoolId', isEqualTo: schoolId)
          .orderBy('date', descending: true)
          .get();

      final List<Map<String, dynamic>> loaded = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // ✅ Utiliser _extractDate pour gérer les deux types
        final date = _extractDate(data['date']);
        
        final announcement = {
          'id': doc.id,
          'firestoreId': doc.id,
          'title': data['title'] ?? '',
          'content': data['content'] ?? '',
          'date': date,
          'audience': data['audience'] ?? 'all',
          'className': data['className'],
          'createdByName': data['createdByName'] ?? 'Admin',
          'isPinned': data['isPinned'] ?? false,
          'classId': data['classId'],
        };
        if (_canSeeAnnouncement(announcement, currentUser)) {
          loaded.add(announcement);
        }
      }

      setState(() {
        _announcements = loaded;
        _filterAnnouncements();
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterAnnouncements() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredAnnouncements = _announcements.where((a) {
        if (_selectedFilter == 'school') {
          final audience = a['audience'] ?? 'all';
          if (audience != 'all') return false;
        }
        if (_selectedFilter == 'teachers') {
          final audience = a['audience'] ?? 'all';
          if (audience != 'teachers' && audience != 'all') return false;
        }
        
        if (query.isNotEmpty) {
          final title = (a['title'] ?? "").toLowerCase();
          final content = (a['content'] ?? "").toLowerCase();
          if (!title.contains(query) && !content.contains(query)) return false;
        }
        return true;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Annonces', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAnnouncements,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Barre de recherche
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher une annonce...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (_) => _filterAnnouncements(),
                  ),
                ),
                // Filtres
                Container(
                  height: 45,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filterOptions.length,
                    itemBuilder: (context, index) {
                      final option = _filterOptions[index];
                      final isSelected = _selectedFilter == option['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(option['label']),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedFilter = option['id'];
                              _filterAnnouncements();
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: (option['color'] as Color).withOpacity(0.2),
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: isSelected 
                                  ? option['color'] as Color 
                                  : Colors.grey[300]!,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Compteur
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${_filteredAnnouncements.length} annonce(s)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Liste
                Expanded(
                  child: _filteredAnnouncements.isEmpty
                      ? Center(
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
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredAnnouncements.length,
                          itemBuilder: (context, index) {
                            final ann = _filteredAnnouncements[index];
                            return _buildAnnouncementCard(ann);
                          },
                        ),
                ),
              ],
            ),
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
                  backgroundColor: isPinned ? Colors.orange : Colors.blue,
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
            if (announcement['className'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🏫 ${announcement['className']}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.purple[600],
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
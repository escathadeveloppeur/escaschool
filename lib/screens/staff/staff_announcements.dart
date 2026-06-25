// lib/screens/staff/staff_announcements.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../models/user.dart';

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

class StaffAnnouncementsScreen extends StatefulWidget {
  const StaffAnnouncementsScreen({super.key});

  @override
  _StaffAnnouncementsScreenState createState() => _StaffAnnouncementsScreenState();
}

class _StaffAnnouncementsScreenState extends State<StaffAnnouncementsScreen> {
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _filteredAnnouncements = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // 'all', 'students', 'teachers', 'parents', 'staff', 'admins'

  final List<Map<String, dynamic>> _filterOptions = [
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
    _loadAnnouncements();
    _searchController.addListener(_filterAnnouncements);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// ✅ Vérifier si l'utilisateur peut voir l'annonce
  bool _canSeeAnnouncement(Map<String, dynamic> announcement, User? user) {
    if (user == null) return false;
    
    final audience = announcement['audience'] ?? 'all';
    final targetedRoles = List<String>.from(announcement['targetedRoles'] ?? []);
    
    // Le super admin voit tout
    if (user.isSuperAdmin) return true;
    
    // L'admin voit tout
    if (user.isSchoolAdmin) return true;
    
    switch (audience) {
      case 'all':
        return true;
      case 'students':
        return user.role == 'student';
      case 'teachers':
        return user.role == 'teacher';
      case 'parents':
        return user.role == 'parent';
      case 'staff':
        return user.role == 'staff';
      case 'admins':
        return user.role == 'admin' || user.role == 'super_admin';
      case 'specific_class':
        // Pour les étudiants, vérifier la classe
        if (user.role == 'student') {
          final classId = announcement['classId'];
          return user.schoolId == classId;
        }
        return false;
      default:
        return true;
    }
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
        // Essayer de parser la date ISO
        return DateTime.parse(dateValue);
      } catch (e) {
        // Si le parsing échoue, retourner la date actuelle
        print('⚠️ Erreur parsing date: $dateValue');
        return DateTime.now();
      }
    }
    
    // Si c'est un DateTime
    if (dateValue is DateTime) {
      return dateValue;
    }
    
    // Fallback
    return DateTime.now();
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

      // Charger les annonces depuis Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('announcements')
          .where('schoolId', isEqualTo: schoolId)
          .orderBy('date', descending: true)
          .get();

      final List<Map<String, dynamic>> loadedAnnouncements = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // ✅ Correction ici : utiliser _parseDate au lieu de (data['date'] as Timestamp)
        final announcement = {
          'id': doc.id,
          'firestoreId': doc.id,
          'title': data['title'] ?? '',
          'content': data['content'] ?? '',
          'date': _parseDate(data['date']),
          'audience': data['audience'] ?? 'all',
          'targetedRoles': List<String>.from(data['targetedRoles'] ?? []),
          'classId': data['classId'],
          'className': data['className'],
          'audienceLabel': data['audienceLabel'] ?? '',
          'createdByName': data['createdByName'] ?? 'Admin',
          'schoolId': data['schoolId'],
          'pinned': data['pinned'] ?? false,
        };
        
        // Vérifier si l'utilisateur peut voir cette annonce
        if (_canSeeAnnouncement(announcement, currentUser)) {
          loadedAnnouncements.add(announcement);
        }
      }

      setState(() {
        _announcements = loadedAnnouncements;
        _filterAnnouncements();
        _isLoading = false;
      });

      print('✅ ${loadedAnnouncements.length} annonces chargées pour le staff');
    } catch (e) {
      print('❌ Erreur chargement annonces: $e');
      setState(() => _isLoading = false);
      _showSnackBar('Erreur de chargement des annonces', _AppColors.danger);
    }
  }

  void _filterAnnouncements() {
    final query = _searchController.text.toLowerCase().trim();
    
    setState(() {
      _filteredAnnouncements = _announcements.where((a) {
        // Filtrer par audience
        if (_selectedFilter != 'all') {
          final audience = a['audience'] ?? 'all';
          if (audience != _selectedFilter) return false;
        }
        
        // Filtrer par recherche
        if (query.isNotEmpty) {
          final title = (a['title'] ?? "").toLowerCase();
          final content = (a['content'] ?? "").toLowerCase();
          if (!title.contains(query) && !content.contains(query)) return false;
        }
        
        return true;
      }).toList();
    });
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// ✅ Widget pour afficher le badge d'audience
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mes annonces',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAnnouncements,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // Barre de recherche
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher une annonce...',
                hintStyle: TextStyle(color: _AppColors.textMuted),
                prefixIcon: Icon(Icons.search_rounded, color: _AppColors.primaryLight),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: _AppColors.textMuted),
                        onPressed: () {
                          _searchController.clear();
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

          // Filtres d'audience (défilement horizontal)
          Container(
            height: 45,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filterOptions.length,
              itemBuilder: (context, index) {
                final option = _filterOptions[index];
                final isSelected = _selectedFilter == option['id'];
                final color = option['color'] as Color;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedFilter = option['id'];
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

          // Compteur
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.campaign_rounded, size: 16, color: _AppColors.primary),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_filteredAnnouncements.length} annonce(s)',
                  style: TextStyle(color: _AppColors.textMuted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Liste des annonces
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(_AppColors.success),
                    ),
                  )
                : _filteredAnnouncements.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _filteredAnnouncements.length,
                        itemBuilder: (context, index) {
                          final announcement = _filteredAnnouncements[index];
                          return _buildAnnouncementCard(announcement);
                        },
                      ),
          ),
        ],
      ),
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
            'Les annonces de l\'école apparaîtront ici',
            style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final date = announcement['date'] as DateTime? ?? DateTime.now();
    final audience = announcement['audience'] ?? 'all';
    final className = announcement['className'];
    final createdByName = announcement['createdByName'] ?? 'Admin';
    final isPinned = announcement['pinned'] ?? false;

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
                // Icône
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isPinned
                          ? [const Color(0xFFF59E0B), const Color(0xFFEF4444)]
                          : [const Color(0xFFEF4444), const Color(0xFFF97316)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(
                      isPinned ? Icons.push_pin_rounded : Icons.campaign_rounded,
                      color: Colors.white,
                      size: isPinned ? 20 : 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              announcement['title'] ?? 'Sans titre',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: _AppColors.textDark,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isPinned)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.push_pin, size: 10, color: Color(0xFFF59E0B)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Épinglé',
                                    style: TextStyle(fontSize: 9, color: Color(0xFFF59E0B), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 12, color: _AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(date),
                            style: TextStyle(fontSize: 11, color: _AppColors.textMuted),
                          ),
                          const SizedBox(width: 8),
                          // Badge d'audience
                          _buildAudienceBadge(audience, className: className),
                        ],
                      ),
                    ],
                  ),
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
                        style: TextStyle(fontSize: 14, color: _AppColors.textDark, height: 1.5),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.person_rounded, size: 12, color: _AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Publié par: $createdByName',
                            style: TextStyle(fontSize: 11, color: _AppColors.textMuted),
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
}
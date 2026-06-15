// lib/screens/admin/admin_announcements.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../providers/auth_provider.dart';
import 'add_announcement.dart';

// ===================== PALETTE / THEME HELPERS =====================
class _AppColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B5BDB);
  static const Color background = Color(0xFFF4F6FB);
  static const Color cardBorder = Color(0xFFE6E9F2);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textMuted = Color(0xFF6B7280);
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
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAnnouncementsFromFirestore();
    searchController.addListener(_filterAnnouncements);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _filterAnnouncements() {
    final query = searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        filteredAnnouncements = List.from(announcements);
      } else {
        filteredAnnouncements = announcements.where((a) =>
            (a['title'] ?? "").toLowerCase().contains(query) ||
            (a['content'] ?? "").toLowerCase().contains(query)).toList();
      }
    });
  }

  Future<void> _loadAnnouncementsFromFirestore() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;

    try {
      Query query = FirebaseFirestore.instance.collection('announcements');
      
      if (!auth.isSuperAdmin && schoolId != null) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.orderBy('date', descending: true).get();
      
      final List<Map<String, dynamic>> loadedAnnouncements = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        loadedAnnouncements.add({
          'id': doc.id,
          'firestoreId': doc.id,
          'title': data['title'] ?? '',
          'content': data['content'] ?? '',
          'date': data['date'] != null 
              ? (data['date'] as Timestamp).toDate().toIso8601String()
              : DateTime.now().toIso8601String(),
          'schoolId': data['schoolId'],
        });
      }
      setState(() {
        announcements = loadedAnnouncements;
        filteredAnnouncements = loadedAnnouncements;
      });
      
      print('✅ ${loadedAnnouncements.length} annonces chargées');
    } catch (e) {
      print('❌ Erreur chargement annonces: $e');
      final all = await db.getAllAnnouncements();
      setState(() {
        announcements = all;
        filteredAnnouncements = all;
      });
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
              backgroundColor: const Color(0xFFEF4444),
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
        
        _showSnackBar('Annonce supprimée', const Color(0xFF10B981));
      } catch (e) {
        _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
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
      
      _showSnackBar('Annonce modifiée', const Color(0xFF10B981));
    } catch (e) {
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
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
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.edit_rounded, color: Color(0xFFF59E0B)),
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
              backgroundColor: const Color(0xFFF59E0B),
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
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: "Actualiser",
              onPressed: _loadAnnouncementsFromFirestore,
            ),
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
          const SizedBox(height: 16),
          
          // Barre de recherche
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
          
          const SizedBox(height: 16),
          
          // En-tête compteur
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
          
          // Liste des annonces
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
            'Cliquez sur le bouton + pour ajouter une annonce',
            style: TextStyle(fontSize: 13, color: _AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
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
                      color: const Color(0xFFF59E0B),
                      onPressed: () => _showEditDialog(announcement),
                    ),
                    const SizedBox(width: 4),
                    _buildActionButton(
                      icon: Icons.delete_rounded,
                      color: const Color(0xFFEF4444),
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
                  child: Text(
                    announcement['content'],
                    style: TextStyle(fontSize: 13, color: _AppColors.textMuted, height: 1.4),
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
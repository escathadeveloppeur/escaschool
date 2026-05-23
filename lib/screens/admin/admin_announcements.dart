// lib/screens/admin/admin_announcements.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../providers/auth_provider.dart';
import 'add_announcement.dart';

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
  }

  /// 🔥 Charger les annonces depuis Firestore
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
      
      print('✅ ${loadedAnnouncements.length} annonces chargées depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement annonces: $e');
      // Fallback vers Hive
      final all = await db.getAllAnnouncements();
      setState(() {
        announcements = all;
        filteredAnnouncements = all;
      });
    }
  }

  /// 🔥 Supprimer une annonce de Firestore
  Future<void> _deleteAnnouncement(String firestoreId) async {
    try {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(firestoreId)
          .delete();
      
      // Supprimer localement aussi
      final annsMap = await db.getAnnouncementsMap();
      annsMap.removeWhere((key, value) => value['firestoreId'] == firestoreId);
      await db.updateAnnouncements(annsMap);
      
      await _loadAnnouncementsFromFirestore();
      widget.onChanged?.call();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annonce supprimée'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// 🔥 Modifier une annonce dans Firestore
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Annonce modifiée'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void filterAnnouncements(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      filteredAnnouncements = announcements
          .where((a) =>
              (a['title'] ?? "").toLowerCase().contains(q) ||
              (a['date'] ?? "").toLowerCase().contains(q))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text("Liste des annonces",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Spacer(),
              if (!auth.isSuperAdmin || auth.currentSchoolId != null)
                ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddAnnouncementScreen()),
                    );
                    if (result == true) _loadAnnouncementsFromFirestore();
                  },
                  child: Text("Ajouter"),
                ),
            ],
          ),
          SizedBox(height: 10),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: "Rechercher",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
            onChanged: filterAnnouncements,
          ),
          SizedBox(height: 20),
          Expanded(
            child: filteredAnnouncements.isEmpty
                ? Center(child: Text("Aucune annonce pour votre école"))
                : ListView.builder(
                    itemCount: filteredAnnouncements.length,
                    itemBuilder: (_, i) {
                      final a = filteredAnnouncements[i];
                      return Card(
                        child: ListTile(
                          title: Text(a['title'] ?? "Sans titre"),
                          subtitle: Text(a['date']?.substring(0, 16) ?? ""),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit),
                                onPressed: () async {
                                  final result = await showDialog<Map<String, String>>(
                                    context: context,
                                    builder: (_) {
                                      final titleController =
                                          TextEditingController(text: a['title']);
                                      final contentController =
                                          TextEditingController(text: a['content']);
                                      return AlertDialog(
                                        title: Text("Modifier l'annonce"),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: titleController,
                                              decoration: InputDecoration(labelText: "Titre"),
                                            ),
                                            TextField(
                                              controller: contentController,
                                              decoration: InputDecoration(labelText: "Contenu"),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text("Annuler"),
                                          ),
                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.pop(context, {
                                                'title': titleController.text,
                                                'content': contentController.text
                                              });
                                            },
                                            child: Text("Modifier"),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (result != null) {
                                    await _editAnnouncement(a['firestoreId'], result['title']!, result['content']!);
                                  }
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () => _deleteAnnouncement(a['firestoreId']),
                              ),
                            ],
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
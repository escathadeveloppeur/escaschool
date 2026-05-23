// lib/screens/admin/add_announcement.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../providers/auth_provider.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.announcementToEdit != null) {
      _titleCtrl.text = widget.announcementToEdit!['title'] ?? '';
      _contentCtrl.text = widget.announcementToEdit!['content'] ?? '';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  /// 🔥 Sauvegarder directement dans Firestore
  Future<void> _saveAnnouncement() async {
    if (_titleCtrl.text.isEmpty || _contentCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs'), backgroundColor: Colors.red),
      );
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
        'createdBy': auth.user?.id,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.announcementToEdit == null) {
        // 🔥 Ajouter dans Firestore
        await FirebaseFirestore.instance.collection('announcements').add(announcementData);
        
        // Sauvegarder localement aussi
        await db.addAnnouncement({
          'title': _titleCtrl.text,
          'content': _contentCtrl.text,
          'date': DateTime.now().toIso8601String(),
          'schoolId': schoolId,
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Annonce publiée avec succès'), backgroundColor: Colors.green),
        );
      } else {
        // 🔥 Modifier dans Firestore
        if (widget.announcementFirestoreId != null) {
          await FirebaseFirestore.instance
              .collection('announcements')
              .doc(widget.announcementFirestoreId)
              .update(announcementData);
          
          // Sauvegarder localement aussi
          if (widget.announcementToEdit != null && widget.announcementToEdit!['id'] != null) {
            final annsMap = await db.getAnnouncementsMap();
            annsMap[widget.announcementToEdit!['id'].toString()] = {
              ...announcementData,
              'id': widget.announcementToEdit!['id'],
              'date': DateTime.now().toIso8601String(),
            };
            await db.updateAnnouncements(annsMap);
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Annonce modifiée avec succès'), backgroundColor: Colors.green),
          );
        }
      }
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Erreur: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final schoolId = auth.currentSchoolId;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.announcementToEdit == null ? "Ajouter une annonce" : "Modifier l'annonce"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
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
                    Text(auth.schoolName ?? 'École', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.blue)),
                  ],
                ),
              ),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: "Titre",
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentCtrl,
              decoration: const InputDecoration(
                labelText: "Contenu",
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                prefixIcon: Icon(Icons.description),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAnnouncement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.announcementToEdit == null ? "Publier" : "Modifier"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
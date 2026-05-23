// lib/screens/super_admin/widgets/admin_card.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/db_helper.dart';

class AdminCard extends StatelessWidget {
  final Map<String, dynamic> admin;
  final VoidCallback onRefresh;

  const AdminCard({
    super.key,
    required this.admin,
    required this.onRefresh,
  });

  Future<void> _deleteAdmin(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Supprimer ${admin['name']} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Supprimer de Firestore
        if (admin['firestoreId'] != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(admin['firestoreId'])
              .delete();
        }
        
        // Supprimer localement
        final db = DBHelper();
        if (admin['id'] != null) {
          await db.deleteUser(admin['id']);
        }
        
        onRefresh();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Administrateur supprimé'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 28)),
        ),
        title: Text(admin['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(admin['email'], style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: admin['role'] == 'super_admin' ? Colors.orange.withOpacity(0.1) : Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    admin['role'] == 'super_admin' ? 'Super Admin' : 'Admin',
                    style: TextStyle(fontSize: 10, color: admin['role'] == 'super_admin' ? Colors.orange : Colors.purple),
                  ),
                ),
                if (admin['schoolId'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'École ID: ${admin['schoolId']}',
                      style: const TextStyle(fontSize: 10, color: Colors.blue, fontFamily: 'monospace'),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteAdmin(context),
        ),
      ),
    );
  }
}
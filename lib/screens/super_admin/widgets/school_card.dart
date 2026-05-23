// lib/screens/super_admin/widgets/school_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/db_helper.dart';
import '../../../../services/school_service.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../models/university/etablissement_model.dart';

class SchoolCard extends StatelessWidget {
  final EtablissementModel school;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;

  const SchoolCard({
    super.key,
    required this.school,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
  });

  /// Récupérer les statistiques EN DIRECT depuis Firestore avec l'ID LOCAL (int)
  Future<Map<String, int>> _getStatsFromFirestore() async {
    try {
      // ✅ Utiliser l'ID LOCAL (int) comme dans votre base de données
      final schoolLocalId = school.id;
      if (schoolLocalId == null) return {'students': 0, 'teachers': 0, 'admins': 0, 'staff': 0};

      print('📊 Récupération stats pour école ID: $schoolLocalId');

      // Requêtes parallèles vers Firestore avec schoolId = int
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .where('schoolId', isEqualTo: schoolLocalId)
            .where('role', isEqualTo: 'student')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .where('schoolId', isEqualTo: schoolLocalId)
            .where('role', isEqualTo: 'teacher')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .where('schoolId', isEqualTo: schoolLocalId)
            .where('role', isEqualTo: 'admin')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .where('schoolId', isEqualTo: schoolLocalId)
            .where('role', isEqualTo: 'staff')
            .count()
            .get(),
      ]);

      return {
        'students': results[0].count ?? 0,
        'teachers': results[1].count ?? 0,
        'admins': results[2].count ?? 0,
        'staff': results[3].count ?? 0,
      };
    } catch (e) {
      print('❌ Erreur stats Firestore: $e');
      return {'students': 0, 'teachers': 0, 'admins': 0, 'staff': 0};
    }
  }

  Future<void> _toggleSchoolStatus(BuildContext context) async {
    final newStatus = !school.isActive;
    final actionText = newStatus ? 'activer' : 'suspendre';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              newStatus ? Icons.check_circle : Icons.warning,
              color: newStatus ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 12),
            Text(
              newStatus ? 'Activer l\'école' : 'Suspendre l\'école',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment $actionText "${school.nom}" ?\n\n'
          '${newStatus ? 'L\'école pourra à nouveau utiliser toutes les fonctionnalités.' : 'L\'école ne pourra plus accéder aux fonctionnalités jusqu\'à régularisation.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(newStatus ? 'Activer' : 'Suspendre'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final schoolService = SchoolService();
        
        // Mettre à jour DIRECTEMENT dans Firestore
        final schoolDocRef = FirebaseFirestore.instance
            .collection('schools')
            .doc(school.firestoreId);
        
        await schoolDocRef.update({
          'isActive': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        // Mettre à jour localement aussi
        final db = DBHelper();
        await db.updateEtablissementStatus(school.id!, newStatus);
        await db.addLog("Super Admin a ${newStatus ? 'activé' : 'suspendu'} l'école: ${school.nom}");
        
        onRefresh();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('École ${newStatus ? 'activée' : 'suspendue'} avec succès'),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur Firestore: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _getStatsFromFirestore(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {'students': 0, 'teachers': 0, 'admins': 0, 'staff': 0};
        
        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: school.isActive ? Colors.white : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: school.isActive
                  ? null
                  : Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Stack(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: school.isActive
                              ? const LinearGradient(
                                  colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                                )
                              : const LinearGradient(
                                  colors: [Colors.grey, Colors.grey],
                                ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Icon(Icons.business, color: Colors.white, size: 28),
                        ),
                      ),
                      if (!school.isActive)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.block,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          school.nom,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            letterSpacing: -0.3,
                            color: school.isActive ? Colors.black87 : Colors.grey[600],
                          ),
                        ),
                      ),
                      if (!school.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Suspendue',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if (school.type != null && school.type!.isNotEmpty)
                        Text(
                          school.type!,
                          style: TextStyle(
                            fontSize: 12,
                            color: school.isActive ? Colors.grey[600] : Colors.grey[500],
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildStatChip(Icons.school, 'Élèves', stats['students']!, Colors.blue, school.isActive),
                          _buildStatChip(Icons.person, 'Enseignants', stats['teachers']!, Colors.green, school.isActive),
                          _buildStatChip(Icons.admin_panel_settings, 'Admins', stats['admins']!, Colors.purple, school.isActive),
                          _buildStatChip(Icons.work, 'Personnel', stats['staff']!, Colors.orange, school.isActive),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // AFFICHAGE DES ID
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'ID: ${school.id}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          if (school.schoolCode != null && school.schoolCode!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Code: ${school.schoolCode}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF10B981),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: school.isActive
                              ? const Color(0xFFF59E0B).withOpacity(0.1)
                              : const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: Icon(
                            school.isActive ? Icons.block : Icons.check_circle,
                            color: school.isActive ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            size: 20,
                          ),
                          onPressed: () => _toggleSchoolStatus(context),
                          tooltip: school.isActive ? 'Suspendre' : 'Activer',
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFFF59E0B), size: 20),
                          onPressed: onEdit,
                          tooltip: 'Modifier',
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 20),
                          onPressed: onDelete,
                          tooltip: 'Supprimer',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip(IconData icon, String label, int count, Color color, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isActive ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isActive ? color : Colors.grey),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isActive ? color : Colors.grey,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
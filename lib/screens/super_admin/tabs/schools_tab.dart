// lib/screens/super_admin/tabs/schools_tab.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/db_helper.dart';
import '../../../../services/school_service.dart';
import '../../../../models/university/etablissement_model.dart';
import '../../../../models/user.dart';
import '../dialogs/add_school_dialog.dart';
import '../dialogs/edit_school_dialog.dart';
import '../widgets/school_card.dart';

class SchoolsTab extends StatefulWidget {
  const SchoolsTab({super.key});

  @override
  _SchoolsTabState createState() => _SchoolsTabState();
}

class _SchoolsTabState extends State<SchoolsTab> {
  final DBHelper db = DBHelper();
  final SchoolService _schoolService = SchoolService();
  List<EtablissementModel> _etablissements = [];
  List<EtablissementModel> _filteredEtablissements = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDataFromFirestore();
  }

  /// 🔥 CHARGER LES ÉCOLES DIRECTEMENT DEPUIS FIRESTORE
  Future<void> _loadDataFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .get();
      
      _etablissements = snapshot.docs.map((doc) {
        final data = doc.data();
        return EtablissementModel(
          id: data['localId'] ?? 0,
          nom: data['name'] ?? data['nom'] ?? 'Sans nom',
          type: data['type'] ?? 'École',
          adresse: data['address'] ?? data['adresse'],
          telephone: data['phone'] ?? data['telephone'],
          email: data['email'],
          siteWeb: data['website'] ?? data['siteWeb'],
          firestoreId: doc.id,
          isActive: data['isActive'] ?? true,
          schoolCode: data['schoolCode'] ?? '',
        );
      }).toList();
      
      _filteredEtablissements = _etablissements;
      
      print('✅ ${_etablissements.length} écoles chargées depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement Firestore: $e');
      // Fallback vers Hive si Firestore échoue
      _etablissements = await db.getAllEtablissements();
      _filteredEtablissements = _etablissements;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 🔥 RÉCUPÉRER LES STATS DIRECTEMENT DEPUIS FIRESTORE
  Future<Map<String, int>> _getStatsForSchool(String schoolFirestoreId) async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .where('schoolId', isEqualTo: schoolFirestoreId)
            .where('role', isEqualTo: 'student')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .where('schoolId', isEqualTo: schoolFirestoreId)
            .where('role', isEqualTo: 'teacher')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .where('schoolId', isEqualTo: schoolFirestoreId)
            .where('role', isEqualTo: 'admin')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .where('schoolId', isEqualTo: schoolFirestoreId)
            .where('role', isEqualTo: 'staff')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .where('schoolId', isEqualTo: schoolFirestoreId)
            .where('role', isEqualTo: 'parent')
            .count()
            .get(),
      ]);

      return {
        'students': results[0].count ?? 0,
        'teachers': results[1].count ?? 0,
        'admins': results[2].count ?? 0,
        'staff': results[3].count ?? 0,
        'parents': results[4].count ?? 0,
        'total': (results[0].count ?? 0) + (results[1].count ?? 0) + 
                 (results[2].count ?? 0) + (results[3].count ?? 0) + 
                 (results[4].count ?? 0),
      };
    } catch (e) {
      print('❌ Erreur stats Firestore: $e');
      return {'students': 0, 'teachers': 0, 'admins': 0, 'staff': 0, 'parents': 0, 'total': 0};
    }
  }

  Future<void> _syncWithFirebase() async {
    setState(() => _isSyncing = true);
    
    try {
      await _schoolService.syncAllSchoolsToFirestore();
      await _schoolService.syncSchoolsFromFirestoreToLocal();
      await _loadDataFromFirestore();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Synchronisation avec Firebase réussie'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur synchronisation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _filterSchools(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredEtablissements = _etablissements;
      } else {
        _filteredEtablissements = _etablissements.where((e) => 
          e.nom.toLowerCase().contains(query.toLowerCase()) ||
          (e.type?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
          (e.schoolCode?.toLowerCase().contains(query.toLowerCase()) ?? false)
        ).toList();
      }
    });
  }

  void _showAddSchoolDialog() {
    showDialog(
      context: context,
      builder: (context) => AddSchoolDialog(
        onSchoolAdded: () => _loadDataFromFirestore(),
      ),
    );
  }

  void _showEditSchoolDialog(EtablissementModel school) {
    showDialog(
      context: context,
      builder: (context) => EditSchoolDialog(
        school: school,
        onSchoolUpdated: () => _loadDataFromFirestore(),
      ),
    );
  }

  void _showSchoolDetails(EtablissementModel school) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => FutureBuilder<Map<String, int>>(
        future: _getStatsForSchool(school.firestoreId ?? ''),
        builder: (context, statsSnapshot) {
          final stats = statsSnapshot.data ?? {
            'students': 0, 'teachers': 0, 'admins': 0, 'staff': 0, 'parents': 0, 'total': 0
          };
          
          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Container(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 60,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // En-tête
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Icon(Icons.business, size: 30, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                school.nom,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                school.type ?? 'École',
                                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Firestore ID: ${school.firestoreId}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  if (school.schoolCode != null && school.schoolCode!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Code: ${school.schoolCode}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green[600],
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Statistiques globales
                    const Text(
                      'Statistiques globales',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildStatCard('Total utilisateurs', stats['total'] ?? 0, Icons.people, Colors.purple),
                        _buildStatCard('Élèves', stats['students'] ?? 0, Icons.school, Colors.blue),
                        _buildStatCard('Enseignants', stats['teachers'] ?? 0, Icons.person, Colors.green),
                        _buildStatCard('Administrateurs', stats['admins'] ?? 0, Icons.admin_panel_settings, Colors.red),
                        _buildStatCard('Personnel', stats['staff'] ?? 0, Icons.work, Colors.orange),
                        _buildStatCard('Parents', stats['parents'] ?? 0, Icons.family_restroom, Colors.teal),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Coordonnées
                    if (school.adresse != null || school.telephone != null || school.email != null) ...[
                      const Text(
                        'Coordonnées',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (school.adresse != null && school.adresse!.isNotEmpty)
                        _buildContactCard(Icons.location_on, 'Adresse', school.adresse!),
                      if (school.telephone != null && school.telephone!.isNotEmpty)
                        _buildContactCard(Icons.phone, 'Téléphone', school.telephone!),
                      if (school.email != null && school.email!.isNotEmpty)
                        _buildContactCard(Icons.email, 'Email', school.email!),
                      if (school.siteWeb != null && school.siteWeb!.isNotEmpty)
                        _buildContactCard(Icons.language, 'Site web', school.siteWeb!),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Boutons d'action
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditSchoolDialog(school);
                            },
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Modifier'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteSchool(school);
                            },
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('Supprimer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF10B981)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSchool(EtablissementModel school) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Voulez-vous vraiment supprimer l\'école "${school.nom}" ?\n\nFirestore ID: ${school.firestoreId}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 🔥 Supprimer de Firestore
        if (school.firestoreId != null && school.firestoreId!.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('schools')
              .doc(school.firestoreId)
              .delete();
        }
        
        // Supprimer localement
        if (school.id != null) {
          await db.deleteEtablissement(school.id!);
        }
        
        await db.addLog("Super Admin a supprimé l'école: ${school.nom} (Firestore ID: ${school.firestoreId})");
        await _loadDataFromFirestore();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('École supprimée avec succès'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        print('❌ Erreur suppression: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredEtablissements.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.business, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty ? "Aucune école" : "Aucun résultat",
                            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 16),
                          if (_searchQuery.isEmpty)
                            ElevatedButton.icon(
                              onPressed: _showAddSchoolDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Ajouter une école'),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _filteredEtablissements.length,
                      itemBuilder: (context, index) {
                        final school = _filteredEtablissements[index];
                        
                        return SchoolCard(
                          school: school,
                          onTap: () => _showSchoolDetails(school),
                          onEdit: () => _showEditSchoolDialog(school),
                          onDelete: () => _deleteSchool(school),
                          onRefresh: _loadDataFromFirestore,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: _filterSchools,
              decoration: InputDecoration(
                hintText: 'Rechercher une école...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF10B981)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              onPressed: _isSyncing ? null : _syncWithFirebase,
              icon: _isSyncing 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync, color: Color(0xFF10B981)),
              tooltip: 'Synchroniser avec Firebase',
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ElevatedButton.icon(
              onPressed: _showAddSchoolDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text("Ajouter", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
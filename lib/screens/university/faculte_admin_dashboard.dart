// lib/screens/university/faculte_admin_dashboard.dart

import 'package:flutter/material.dart';
import '../../services/db_helper.dart';
import '../../models/university/faculte_model.dart';
import '../../models/university/departement_model.dart';
import 'departement_admin_dashboard.dart';

class FaculteAdminDashboard extends StatefulWidget {
  final int faculteId;
  final String faculteNom;
  
  const FaculteAdminDashboard({
    super.key,
    required this.faculteId,
    required this.faculteNom,
  });

  @override
  _FaculteAdminDashboardState createState() => _FaculteAdminDashboardState();
}

class _FaculteAdminDashboardState extends State<FaculteAdminDashboard> with SingleTickerProviderStateMixin {
  final DBHelper db = DBHelper();
  List<DepartementModel> _departements = [];
  bool _isLoading = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _departements = await db.getDepartementsByFaculte(widget.faculteId);
    setState(() => _isLoading = false);
    _animationController.forward(from: 0);
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

  void _showAddDepartementDialog() {
    final nomController = TextEditingController();
    final codeController = TextEditingController();
    final responsableController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Ajouter un département',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                decoration: InputDecoration(
                  labelText: 'Nom du département *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'Code (ex: INFO, MATH, LET)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.code),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: responsableController,
                decoration: InputDecoration(
                  labelText: 'Nom du responsable',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nomController.text.isEmpty) {
                _showSnackBar('Le nom du département est requis', const Color(0xFFF59E0B));
                return;
              }
              
              final newDepartement = DepartementModel(
                id: DateTime.now().millisecondsSinceEpoch,
                faculteId: widget.faculteId,
                nom: nomController.text,
                code: codeController.text.isNotEmpty ? codeController.text : null,
                responsable: responsableController.text.isNotEmpty ? responsableController.text : null,
                description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
                createdAt: DateTime.now(),
              );
              
              await db.addDepartement(newDepartement);
              await _loadData();
              _showSnackBar('Département ajouté avec succès', const Color(0xFF10B981));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _editDepartement(DepartementModel departement) {
    final nomController = TextEditingController(text: departement.nom);
    final codeController = TextEditingController(text: departement.code ?? '');
    final responsableController = TextEditingController(text: departement.responsable ?? '');
    final descriptionController = TextEditingController(text: departement.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Modifier le département',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                decoration: InputDecoration(
                  labelText: 'Nom du département *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.category),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'Code',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.code),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: responsableController,
                decoration: InputDecoration(
                  labelText: 'Nom du responsable',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nomController.text.isEmpty) {
                _showSnackBar('Le nom du département est requis', const Color(0xFFF59E0B));
                return;
              }
              
              final updatedDepartement = DepartementModel(
                id: departement.id,
                faculteId: widget.faculteId,
                nom: nomController.text,
                code: codeController.text.isNotEmpty ? codeController.text : null,
                responsable: responsableController.text.isNotEmpty ? responsableController.text : null,
                description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
                createdAt: departement.createdAt,
              );
              
              await db.updateDepartement(updatedDepartement);
              await _loadData();
              _showSnackBar('Département modifié avec succès', const Color(0xFF10B981));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  void _deleteDepartement(DepartementModel departement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirmer la suppression',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Voulez-vous vraiment supprimer le département "${departement.nom}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              await db.deleteDepartement(departement.id);
              await _loadData();
              _showSnackBar('Département supprimé avec succès', const Color(0xFF10B981));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.faculteNom,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.add, color: Color(0xFF10B981)),
              onPressed: _showAddDepartementDialog,
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey[100],
              ),
              tooltip: 'Ajouter un département',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey[100],
              ),
              tooltip: 'Actualiser',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              ),
            )
          : Column(
              children: [
                // Statistiques
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF8B5CF6),
                        const Color(0xFF6D28D9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _statCard(Icons.category, "Départements", _departements.length, Colors.white),
                      _statCard(Icons.people, "Étudiants", 0, Colors.white),
                      _statCard(Icons.school, "Enseignants", 0, Colors.white),
                    ],
                  ),
                ),
                
                // Liste des départements
                Expanded(
                  child: _departements.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.category, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun département',
                                style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Cliquez sur + pour ajouter un département',
                                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _showAddDepartementDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Ajouter un département'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _departements.length,
                          itemBuilder: (context, index) {
                            final departement = _departements[index];
                            return FadeTransition(
                              opacity: _animationController,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          const Color(0xFF8B5CF6),
                                          const Color(0xFF6D28D9),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.category, color: Colors.white, size: 28),
                                    ),
                                  ),
                                  title: Text(
                                    departement.nom,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      if (departement.code != null)
                                        Text(
                                          'Code: ${departement.code}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                      if (departement.responsable != null)
                                        Text(
                                          'Responsable: ${departement.responsable}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                      if (departement.description != null && departement.description!.isNotEmpty)
                                        Text(
                                          departement.description!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.visibility, color: Color(0xFF3B82F6), size: 20),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => DepartementAdminDashboard(
                                                  departementId: departement.id,
                                                  departementNom: departement.nom,
                                                ),
                                              ),
                                            );
                                          },
                                          tooltip: 'Gérer',
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.edit, color: Color(0xFFF59E0B), size: 20),
                                          onPressed: () => _editDepartement(departement),
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
                                          onPressed: () => _deleteDepartement(departement),
                                          tooltip: 'Supprimer',
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
              ],
            ),
    );
  }

  Widget _statCard(IconData icon, String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }
}
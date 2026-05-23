// lib/screens/university/university_admin_dashboard.dart

import 'package:flutter/material.dart';
import '../../services/db_helper.dart';
import '../../models/university/etablissement_model.dart';
import '../../models/university/faculte_model.dart';
import 'faculte_admin_dashboard.dart';
import '../mode_selection_screen.dart';

class UniversityAdminDashboard extends StatefulWidget {
  final int etablissementId;
  
  const UniversityAdminDashboard({super.key, required this.etablissementId});

  @override
  _UniversityAdminDashboardState createState() => _UniversityAdminDashboardState();
}

class _UniversityAdminDashboardState extends State<UniversityAdminDashboard> {
  final DBHelper db = DBHelper();
  EtablissementModel? _etablissement;
  List<FaculteModel> _facultes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _etablissement = await db.getAllEtablissement(widget.etablissementId);
    _facultes = await db.getFacultesByEtablissement(widget.etablissementId);
    setState(() => _isLoading = false);
  }

  void _goToModeSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Changer de mode',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Voulez-vous retourner à l\'écran de sélection du mode ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const ModeSelectionScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Oui, changer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_etablissement?.nom ?? 'Administration'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: _goToModeSelection,
            tooltip: 'Changer de mode',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddFaculteDialog(),
            tooltip: 'Ajouter une faculté',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.purple[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statCard('Facultés', _facultes.length, Icons.account_balance, Colors.purple),
                      _statCard('Départements', 0, Icons.category, Colors.blue),
                      _statCard('Étudiants', 0, Icons.people, Colors.green),
                      _statCard('Enseignants', 0, Icons.school, Colors.orange),
                    ],
                  ),
                ),
                
                Expanded(
                  child: _facultes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.account_balance, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'Aucune faculté',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => _showAddFaculteDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Créer une faculté'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _facultes.length,
                          itemBuilder: (context, index) {
                            final faculte = _facultes[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.purple[100],
                                  child: Text(
                                    faculte.nom[0].toUpperCase(),
                                    style: TextStyle(color: Colors.purple),
                                  ),
                                ),
                                title: Text(faculte.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(faculte.code ?? ''),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.settings, color: Color(0xFF3B82F6)),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FaculteAdminDashboard(
                                              faculteId: faculte.id,
                                              faculteNom: faculte.nom,
                                            ),
                                          ),
                                        );
                                      },
                                      tooltip: 'Gérer',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Color(0xFFF59E0B)),
                                      onPressed: () => _editFaculte(faculte),
                                      tooltip: 'Modifier',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Color(0xFFEF4444)),
                                      onPressed: () => _deleteFaculte(faculte),
                                      tooltip: 'Supprimer',
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

  Widget _statCard(String title, int count, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        Text(title, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  void _showAddFaculteDialog() {
    final nomController = TextEditingController();
    final codeController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ajouter une faculté'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomController,
              decoration: const InputDecoration(labelText: 'Nom *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Code (ex: FDS, FLSH)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nomController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Le nom est requis')),
                );
                return;
              }
              
              final newFaculte = FaculteModel(
                id: DateTime.now().millisecondsSinceEpoch,
                etablissementId: widget.etablissementId,
                nom: nomController.text,
                code: codeController.text.isNotEmpty ? codeController.text : null,
                description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
                createdAt: DateTime.now(),
              );
              await db.addFaculte(newFaculte);
              await _loadData();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _editFaculte(FaculteModel faculte) {
    final nomController = TextEditingController(text: faculte.nom);
    final codeController = TextEditingController(text: faculte.code ?? '');
    final descriptionController = TextEditingController(text: faculte.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Modifier la faculté'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomController,
              decoration: const InputDecoration(labelText: 'Nom *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Code'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nomController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Le nom est requis')),
                );
                return;
              }
              
              final updatedFaculte = FaculteModel(
                id: faculte.id,
                etablissementId: widget.etablissementId,
                nom: nomController.text,
                code: codeController.text.isNotEmpty ? codeController.text : null,
                description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
                createdAt: faculte.createdAt,
              );
              await db.updateFaculte(updatedFaculte);
              await _loadData();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  void _deleteFaculte(FaculteModel faculte) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmer'),
        content: Text('Supprimer ${faculte.nom} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              await db.deleteFaculte(faculte.id);
              await _loadData();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
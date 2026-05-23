// lib/screens/university/super_admin_dashboard.dart

import 'package:flutter/material.dart';
import '../../services/db_helper.dart';
import '../../models/university/etablissement_model.dart';
import 'university_admin_dashboard.dart';

class UniversitySuperAdminDashboard extends StatefulWidget {
  const UniversitySuperAdminDashboard({super.key});

  @override
  _UniversitySuperAdminDashboardState createState() => _UniversitySuperAdminDashboardState();
}

class _UniversitySuperAdminDashboardState extends State<UniversitySuperAdminDashboard> {
  final DBHelper db = DBHelper();
  List<EtablissementModel> _etablissements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _etablissements = await db.getAllEtablissements();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Super Admin - Universités'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showAddUniversityDialog(),
            tooltip: 'Ajouter une université',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _etablissements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance, size: 80, color: Colors.grey),
                      SizedBox(height: 20),
                      Text(
                        'Aucune université',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _showAddUniversityDialog(),
                        icon: Icon(Icons.add),
                        label: Text('Créer une université'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _etablissements.length,
                  itemBuilder: (context, index) {
                    final univ = _etablissements[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.purple[100],
                          child: Icon(Icons.account_balance, color: Colors.purple),
                        ),
                        title: Text(
                          univ.nom,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Type: ${univ.type}'),
                        children: [
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildInfoRow('Adresse', univ.adresse ?? 'Non renseignée'),
                                _buildInfoRow('Téléphone', univ.telephone ?? 'Non renseigné'),
                                _buildInfoRow('Email', univ.email ?? 'Non renseigné'),
                                _buildInfoRow('Site web', univ.siteWeb ?? 'Non renseigné'),
                                SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => UniversityAdminDashboard(
                                              etablissementId: univ.id!,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: Icon(Icons.admin_panel_settings),
                                      label: Text('Gérer'),
                                    ),
                                    SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () => _editUniversity(univ),
                                      icon: Icon(Icons.edit),
                                      label: Text('Modifier'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _deleteUniversity(univ),
                                      icon: Icon(Icons.delete, color: Colors.red),
                                      label: Text('Supprimer'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showAddUniversityDialog() {
    final nomController = TextEditingController();
    final typeController = TextEditingController();
    final adresseController = TextEditingController();
    final telephoneController = TextEditingController();
    final emailController = TextEditingController();
    final siteWebController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ajouter une université'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                decoration: InputDecoration(labelText: 'Nom *'),
              ),
              TextField(
                controller: typeController,
                decoration: InputDecoration(labelText: 'Type (Université, Institut...)'),
              ),
              TextField(
                controller: adresseController,
                decoration: InputDecoration(labelText: 'Adresse'),
              ),
              TextField(
                controller: telephoneController,
                decoration: InputDecoration(labelText: 'Téléphone'),
              ),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: siteWebController,
                decoration: InputDecoration(labelText: 'Site web'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
        onPressed: () async {
  final newUniv = EtablissementModel(
    id: DateTime.now().millisecondsSinceEpoch,
    nom: nomController.text,
    type: typeController.text.isEmpty ? 'Université' : typeController.text,
    adresse: adresseController.text,
    telephone: telephoneController.text,
    email: emailController.text,
    siteWeb: siteWebController.text,
    createdAt: DateTime.now(),
    isActive: true,  // Ajouter cette ligne
    schoolCode: EtablissementModel.generateSchoolCode(nomController.text),  // Ajouter cette ligne
  );
  await db.addEtablissement(newUniv);
  await _loadData();
  Navigator.pop(context);
},
            child: Text('Créer'),
          ),
        ],
      ),
    );
  }

  void _editUniversity(EtablissementModel univ) {
    // Implémenter modification
  }

  void _deleteUniversity(EtablissementModel univ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmer'),
        content: Text('Supprimer ${univ.nom} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          TextButton(
            onPressed: () async {
              await db.deleteEtablissement(univ.id!);
              await _loadData();
              Navigator.pop(context);
            },
            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
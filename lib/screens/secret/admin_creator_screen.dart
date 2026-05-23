// lib/screens/secret/admin_creator_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../services/school_service.dart';
import '../../models/university/etablissement_model.dart';

class AdminCreatorScreen extends StatefulWidget {
  const AdminCreatorScreen({super.key});

  @override
  _AdminCreatorScreenState createState() => _AdminCreatorScreenState();
}

class _AdminCreatorScreenState extends State<AdminCreatorScreen> {
  final DBHelper db = DBHelper();
  final SchoolService _schoolService = SchoolService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  List<EtablissementModel> _schools = [];
  EtablissementModel? _selectedSchool;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _selectedRole = 'super_admin';
  
  final List<Map<String, dynamic>> _roles = [
    {'value': 'super_admin', 'label': 'Super Administrateur', 'color': const Color(0xFF8B5CF6)},
    {'value': 'admin', 'label': 'Administrateur d\'école', 'color': const Color(0xFF10B981)},
  ];

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  Future<void> _loadSchools() async {
    setState(() => _isLoading = true);
    _schools = await db.getAllEtablissements();
    setState(() => _isLoading = false);
  }

  Future<void> _createAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedRole == 'admin' && _selectedSchool == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une école'), backgroundColor: Colors.red),
      );
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      final auth = FirebaseAuth.instance;
      
      // Créer dans Firebase Auth
      await auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // Créer dans Firestore
      await FirebaseFirestore.instance.collection('users').add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'schoolId': _selectedSchool?.id,
        'schoolName': _selectedSchool?.nom,
        'schoolCode': _selectedSchool?.schoolCode,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      // Créer localement
      await db.insertUser({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'role': _selectedRole,
        'schoolId': _selectedSchool?.id,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Administrateur créé avec succès !'), backgroundColor: Colors.green),
      );
      
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      setState(() => _selectedSchool = null);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _createSchool() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Créer une école'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nom de l\'école'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Code personnalisé (optionnel)',
                hintText: 'Laisser vide pour génération auto',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    
    if (result == true && nameController.text.isNotEmpty) {
      final schoolCode = codeController.text.isNotEmpty 
          ? codeController.text.toUpperCase()
          : EtablissementModel.generateSchoolCode(nameController.text);
      
      final school = EtablissementModel(
        nom: nameController.text,
        schoolCode: schoolCode,
        isActive: true,
      );
      
      await db.addEtablissement(school);
      
      // Synchroniser Firebase
      await _schoolService.createSchool(school);
      
      await _loadSchools();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('École créée ! Code: $schoolCode'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('ADMIN TOOLS', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Section création école
                    Card(
                      color: Colors.grey[800],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.business, color: Color(0xFF10B981)),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Créer une école',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _createSchool,
                                icon: const Icon(Icons.add),
                                label: const Text('Nouvelle école'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Section création admin
                    Card(
                      color: Colors.grey[800],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.admin_panel_settings, color: Color(0xFF8B5CF6)),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Créer un administrateur',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Nom complet',
                                labelStyle: TextStyle(color: Colors.grey),
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person, color: Color(0xFF8B5CF6)),
                              ),
                              validator: (v) => v!.isEmpty ? 'Nom requis' : null,
                            ),
                            const SizedBox(height: 12),
                            
                            TextFormField(
                              controller: _emailController,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                labelStyle: TextStyle(color: Colors.grey),
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email, color: Color(0xFF8B5CF6)),
                              ),
                              validator: (v) => v!.isEmpty ? 'Email requis' : null,
                            ),
                            const SizedBox(height: 12),
                            
                            TextFormField(
                              controller: _passwordController,
                              style: const TextStyle(color: Colors.white),
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Mot de passe',
                                labelStyle: TextStyle(color: Colors.grey),
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.lock, color: Color(0xFF8B5CF6)),
                              ),
                              validator: (v) => v!.isEmpty ? 'Mot de passe requis' : null,
                            ),
                            const SizedBox(height: 12),
                            
                            DropdownButtonFormField<String>(
                              value: _selectedRole,
                              style: const TextStyle(color: Colors.white),
                              dropdownColor: Colors.grey[800],
                             items: _roles.map<DropdownMenuItem<String>>((role) {
  return DropdownMenuItem<String>(
    value: role['value'] as String,
    child: Text(
      role['label'] as String, 
      style: TextStyle(color: role['color'] as Color),
    ),
  );
}).toList(),
                              onChanged: (value) => setState(() => _selectedRole = value!),
                              decoration: const InputDecoration(
                                labelText: 'Rôle',
                                labelStyle: TextStyle(color: Colors.grey),
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.admin_panel_settings, color: Color(0xFF8B5CF6)),
                              ),
                            ),
                            
                            if (_selectedRole == 'admin') ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<EtablissementModel>(
                                value: _selectedSchool,
                                style: const TextStyle(color: Colors.white),
                                dropdownColor: Colors.grey[800],
                                items: _schools.map((school) {
                                  return DropdownMenuItem(
                                    value: school,
                                    child: Text(school.nom, style: const TextStyle(color: Colors.white)),
                                  );
                                }).toList(),
                                onChanged: (value) => setState(() => _selectedSchool = value),
                                decoration: const InputDecoration(
                                  labelText: 'École',
                                  labelStyle: TextStyle(color: Colors.grey),
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.business, color: Color(0xFF8B5CF6)),
                                ),
                              ),
                            ],
                            
                            const SizedBox(height: 20),
                            
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _createAdmin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Text('Créer l\'administrateur'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Liste des écoles
                    Card(
                      color: Colors.grey[800],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.list, color: Color(0xFF3B82F6)),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Écoles existantes',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            if (_schools.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(32),
                                child: Text('Aucune école', style: TextStyle(color: Colors.grey)),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _schools.length,
                                itemBuilder: (context, index) {
                                  final school = _schools[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[700],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(school.nom, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Code: ${school.schoolCode}',
                                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontFamily: 'monospace'),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy, color: Colors.grey),
                                          onPressed: () {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Code copié: ${school.schoolCode}'), duration: const Duration(seconds: 1)),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
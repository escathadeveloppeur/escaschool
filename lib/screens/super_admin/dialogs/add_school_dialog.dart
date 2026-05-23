// lib/screens/super_admin/dialogs/add_school_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/db_helper.dart';
import '../../../services/school_service.dart';
import '../../../models/university/etablissement_model.dart';
import '../../../providers/auth_provider.dart';

class AddSchoolDialog extends StatefulWidget {
  final VoidCallback onSchoolAdded;

  const AddSchoolDialog({super.key, required this.onSchoolAdded});

  @override
  _AddSchoolDialogState createState() => _AddSchoolDialogState();
}

class _AddSchoolDialogState extends State<AddSchoolDialog> {
  final DBHelper db = DBHelper();
  final SchoolService _schoolService = SchoolService();
  final _formKey = GlobalKey<FormState>();

  final _nomController = TextEditingController();
  final _typeController = TextEditingController();
  final _adresseController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _siteWebController = TextEditingController();

  bool _isLoading = false;

  Future<void> _saveSchool() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nomController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      
      // 1. Créer l'école localement (Hive)
   final newSchool = EtablissementModel(
  id: 0, // Hive générera automatiquement un ID
  nom: _nomController.text,
  type: _typeController.text.isEmpty ? 'École' : _typeController.text,
  adresse: _adresseController.text,
  telephone: _telephoneController.text,
  email: _emailController.text,
  siteWeb: _siteWebController.text,
  createdAt: DateTime.now(),
  isActive: true,  // Ajouter cette ligne
  schoolCode: EtablissementModel.generateSchoolCode(_nomController.text),  // Générer un code unique
);;

      print('📝 Création de l\'école locale: ${newSchool.nom}');
      final localId = await db.addEtablissement(newSchool);
      print('✅ École créée localement avec ID: $localId');
      
      // 2. Synchroniser dans Firebase
      if (auth.isFirebaseConnected) {
        print('☁️ Synchronisation vers Firebase...');
        final firestoreId = await _schoolService.createSchool(newSchool);
        print('✅ École synchronisée dans Firestore avec ID: $firestoreId');
        
        // 3. Mettre à jour l'école locale avec l'ID Firestore
        await db.updateEtablissementFirestoreId(localId, firestoreId);
      
        print('📝 ID Firestore mis à jour localement');
      } else {
        print('⚠️ Firebase non connecté, l\'école sera synchronisée plus tard');
      }
      
      // 4. Ajouter un log
      await db.addLog("Super Admin a ajouté l'école: ${newSchool.nom}");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('École ajoutée avec succès et synchronisée avec Firebase'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onSchoolAdded();
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Erreur: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business, color: Color(0xFF10B981)),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Ajouter une école',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nomController,
                    decoration: const InputDecoration(
                      labelText: 'Nom de l\'école *',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Nom requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _typeController,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      hintText: 'École primaire, Collège, Lycée...',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _adresseController,
                    decoration: const InputDecoration(
                      labelText: 'Adresse',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telephoneController,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _siteWebController,
                    decoration: const InputDecoration(
                      labelText: 'Site web',
                      prefixIcon: Icon(Icons.language),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveSchool,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Ajouter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
// lib/screens/super_admin/dialogs/edit_school_dialog.dart

import 'package:flutter/material.dart';
import '../../../../services/db_helper.dart';
import '../../../../services/school_service.dart';
import '../../../../models/university/etablissement_model.dart';

class EditSchoolDialog extends StatefulWidget {
  final EtablissementModel school;
  final VoidCallback onSchoolUpdated;

  const EditSchoolDialog({super.key, required this.school, required this.onSchoolUpdated});

  @override
  _EditSchoolDialogState createState() => _EditSchoolDialogState();
}

class _EditSchoolDialogState extends State<EditSchoolDialog> {
  final DBHelper db = DBHelper();
  final SchoolService _schoolService = SchoolService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nomController;
  late TextEditingController _typeController;
  late TextEditingController _adresseController;
  late TextEditingController _telephoneController;
  late TextEditingController _emailController;
  late TextEditingController _siteWebController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.school.nom);
    _typeController = TextEditingController(text: widget.school.type);
    _adresseController = TextEditingController(text: widget.school.adresse ?? '');
    _telephoneController = TextEditingController(text: widget.school.telephone ?? '');
    _emailController = TextEditingController(text: widget.school.email ?? '');
    _siteWebController = TextEditingController(text: widget.school.siteWeb ?? '');
  }

  @override
  void dispose() {
    _nomController.dispose();
    _typeController.dispose();
    _adresseController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _siteWebController.dispose();
    super.dispose();
  }

  Future<void> _updateSchool() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedSchool = EtablissementModel(
        id: widget.school.id,
        nom: _nomController.text,
        type: _typeController.text.isEmpty ? 'École' : _typeController.text,
        adresse: _adresseController.text,
        telephone: _telephoneController.text,
        email: _emailController.text,
        siteWeb: _siteWebController.text,
        firestoreId: widget.school.firestoreId,
        createdAt: widget.school.createdAt,
        schoolCode: widget.school.schoolCode,
      );

      // 1. Mettre à jour localement
      if (widget.school.id != null) {
        await db.updateEtablissement(widget.school.id!, updatedSchool);
        print('✅ École mise à jour localement: ${updatedSchool.nom}');
      }
      
      // 2. Mettre à jour dans Firebase si un ID Firestore existe
      if (widget.school.firestoreId != null && widget.school.firestoreId!.isNotEmpty) {
        await _schoolService.updateSchool(widget.school.firestoreId!, updatedSchool);
        print('✅ École mise à jour dans Firestore: ${widget.school.firestoreId}');
      }
      
      // 3. Ajouter un log
      await db.addLog("Super Admin a modifié l'école: ${updatedSchool.nom} (ID: ${widget.school.id})");
      
      widget.onSchoolUpdated();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('École modifiée avec succès'), 
            backgroundColor: Colors.green, 
            behavior: SnackBarBehavior.floating,
          ),
        );
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                    color: const Color(0xFF3B82F6).withOpacity(0.1), 
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit, color: Color(0xFF3B82F6)),
                ),
                const SizedBox(width: 12),
                const Text('Modifier l\'école', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Nom requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _typeController,
                    decoration: const InputDecoration(
                      labelText: 'Type', 
                      prefixIcon: Icon(Icons.category), 
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _adresseController,
                    decoration: const InputDecoration(
                      labelText: 'Adresse', 
                      prefixIcon: Icon(Icons.location_on), 
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telephoneController,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone', 
                      prefixIcon: Icon(Icons.phone), 
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email', 
                      prefixIcon: Icon(Icons.email), 
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _siteWebController,
                    decoration: const InputDecoration(
                      labelText: 'Site web', 
                      prefixIcon: Icon(Icons.language), 
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateSchool,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981), 
                      padding: const EdgeInsets.symmetric(vertical: 12), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                      : const Text('Modifier'),
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
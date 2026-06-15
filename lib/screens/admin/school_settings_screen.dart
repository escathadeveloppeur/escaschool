import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SchoolSettingsScreen extends StatefulWidget {
  const SchoolSettingsScreen({super.key});

  @override
  State<SchoolSettingsScreen> createState() => _SchoolSettingsScreenState();
}

class _SchoolSettingsScreenState extends State<SchoolSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _provinceController;
  late TextEditingController _cityController;
  late TextEditingController _communeController;
  late TextEditingController _schoolNameController;
  late TextEditingController _schoolCodeController;
  late TextEditingController _signaturePrefetController;
  late TextEditingController _signatureChefController;
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _schoolId;
  
  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadSettings();
  }
  
  void _initControllers() {
    _provinceController = TextEditingController();
    _cityController = TextEditingController();
    _communeController = TextEditingController();
    _schoolNameController = TextEditingController();
    _schoolCodeController = TextEditingController();
    _signaturePrefetController = TextEditingController();
    _signatureChefController = TextEditingController();
  }
  
  Future<void> _loadSettings() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _schoolId = auth.currentSchoolId?.toString();
    
    if (_schoolId == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('school_settings')
          .doc(_schoolId)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _provinceController.text = data['province'] ?? '';
        _cityController.text = data['city'] ?? '';
        _communeController.text = data['commune'] ?? '';
        _schoolNameController.text = data['schoolName'] ?? '';
        _schoolCodeController.text = data['schoolCode'] ?? '';
        _signaturePrefetController.text = data['signaturePrefet'] ?? '';
        _signatureChefController.text = data['signatureChef'] ?? '';
      }
    } catch (e) {
      print('Erreur chargement: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      await FirebaseFirestore.instance
          .collection('school_settings')
          .doc(_schoolId)
          .set({
            'province': _provinceController.text.trim(),
            'city': _cityController.text.trim(),
            'commune': _communeController.text.trim(),
            'schoolName': _schoolNameController.text.trim(),
            'schoolCode': _schoolCodeController.text.trim(),
            'signaturePrefet': _signaturePrefetController.text.trim(),
            'signatureChef': _signatureChefController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres enregistrés avec succès'), backgroundColor: Colors.green),
      );
      
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Paramètres du bulletin'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildSection('INFORMATIONS DE L\'ÉCOLE', Icons.school, [
                      _buildTextField(_provinceController, 'Province', 'Ex: LOMAMI', Icons.location_city),
                      const SizedBox(height: 12),
                      _buildTextField(_cityController, 'Ville', 'Ex: MWENE-DITU', Icons.location_on),
                      const SizedBox(height: 12),
                      _buildTextField(_communeController, 'Commune', 'Ex: BONDYI', Icons.map),
                      const SizedBox(height: 12),
                      _buildTextField(_schoolNameController, 'Nom de l\'école', 'Ex: INSTITUT BONDYI', Icons.business),
                      const SizedBox(height: 12),
                      _buildTextField(_schoolCodeController, 'Code de l\'école', 'Ex: 9006613', Icons.qr_code),
                    ]),
                    
                    const SizedBox(height: 20),
                    
                    _buildSection('SIGNATURES OFFICIELLES', Icons.edit_document, [
                      _buildTextField(_signaturePrefetController, 'Préfet des études', 'Nom complet', Icons.person),
                      const SizedBox(height: 12),
                      _buildTextField(_signatureChefController, 'Chef d\'établissement', 'Nom complet', Icons.person_outline),
                    ]),
                    
                    const SizedBox(height: 30),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Enregistrer les paramètres', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF10B981)),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: Column(children: children)),
        ],
      ),
    );
  }
  
  Widget _buildTextField(TextEditingController controller, String label, String hint, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) => value == null || value.trim().isEmpty ? 'Champ requis' : null,
    );
  }
}
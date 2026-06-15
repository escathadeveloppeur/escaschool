// lib/screens/staff/add_staff_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/db_helper.dart';
import '../../services/staff_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/staff_model.dart';

class AddStaffScreen extends StatefulWidget {
  final StaffModel? staff;
  const AddStaffScreen({super.key, this.staff});

  @override
  _AddStaffScreenState createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final DBHelper db = DBHelper();
  final StaffService _staffService = StaffService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _salaryController;

  String _selectedPosition = 'Ménage';
  DateTime _selectedHireDate = DateTime.now();
  bool _isActive = true;
  bool _isLoading = false;

  // Liste des postes disponibles (avec icônes)
  final List<Map<String, dynamic>> _positions = [
    {'value': 'Ménage', 'label': 'Ménage', 'icon': Icons.cleaning_services},
    {'value': 'Sentinelle / Sécurité', 'label': 'Sentinelle / Sécurité', 'icon': Icons.security},
    {'value': 'Chauffeur', 'label': 'Chauffeur', 'icon': Icons.directions_car},
    {'value': 'Cuisinier', 'label': 'Cuisinier', 'icon': Icons.restaurant},
    {'value': 'Jardinier', 'label': 'Jardinier', 'icon': Icons.grass},
    {'value': 'Infirmier', 'label': 'Infirmier', 'icon': Icons.medical_services},
    {'value': 'Bibliothécaire', 'label': 'Bibliothécaire', 'icon': Icons.local_library},
    {'value': 'Secrétaire', 'label': 'Secrétaire', 'icon': Icons.desk},
    {'value': 'Comptable', 'label': 'Comptable', 'icon': Icons.calculate},
    {'value': 'Magasinier', 'label': 'Magasinier', 'icon': Icons.inventory},
    {'value': 'Autre', 'label': 'Autre', 'icon': Icons.work},
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.staff;
    _nameController = TextEditingController(text: s?.fullName ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _emailController = TextEditingController(text: s?.email ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _salaryController = TextEditingController(text: s?.salary.toString() ?? '');
    _selectedPosition = s?.position ?? 'Ménage';
    _selectedHireDate = s?.hireDate ?? DateTime.now();
    _isActive = s?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedHireDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _selectedHireDate = date);
    }
  }

  Future<void> _save() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final String? schoolId = auth.currentSchoolId;

    // 🔥 Vérification que schoolId n'est pas null
    if (schoolId == null) {
      _showSnackBar('Erreur: École non identifiée', const Color(0xFFEF4444));
      setState(() => _isLoading = false);
      return;
    }

    final staff = StaffModel(
      fullName: _nameController.text.trim(),
      position: _selectedPosition,
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      hireDate: _selectedHireDate,
      salary: double.tryParse(_salaryController.text) ?? 0,
      isActive: _isActive,
      schoolId: schoolId,  // 🔥 String
    );

  if (widget.staff == null) {
  // Convertir String en int si addStaff attend int
  final int schoolIdInt = int.tryParse(schoolId ?? '0') ?? 0;
  await _staffService.addStaff(staff, schoolId);
  _showSnackBar('Employé ajouté avec succès', const Color(0xFF10B981));
} else {
  staff.id = widget.staff!.id;
  staff.firestoreId = widget.staff!.firestoreId;
  final int schoolIdInt = int.tryParse(schoolId ?? '0') ?? 0;
  await _staffService.updateStaff(widget.staff!.id!, staff, schoolId);
  _showSnackBar('Employé modifié avec succès', const Color(0xFF10B981));
}

    Navigator.pop(context, true);
  } catch (e) {
    _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
  } finally {
    setState(() => _isLoading = false);
  }
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isEditing = widget.staff != null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          isEditing ? 'Modifier un employé' : 'Ajouter un employé',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Indicateur d'école
              if (auth.currentSchoolId != null && !auth.isSuperAdmin)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.business, size: 18, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 8),
                      Text(
                        auth.schoolName ?? 'Ajout personnel',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6)),
                      ),
                    ],
                  ),
                ),

              // Carte informations personnelles
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person, color: Color(0xFF3B82F6), size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Informations personnelles',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom complet *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => v!.isEmpty ? 'Nom requis' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Adresse',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.home),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Carte informations professionnelles
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.work, color: Color(0xFF10B981), size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Informations professionnelles',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Dropdown pour le poste avec barre de défilement
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedPosition,
                          items: _positions.map<DropdownMenuItem<String>>((position) {
                            return DropdownMenuItem<String>(
                              value: position['value'] as String,
                              child: Row(
                                children: [
                                  Icon(position['icon'] as IconData, size: 20, color: const Color(0xFF10B981)),
                                  const SizedBox(width: 12),
                                  Text(position['label'] as String),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedPosition = value!),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            prefixIcon: Icon(Icons.badge, color: Color(0xFF10B981)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Date d'embauche
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Color(0xFF10B981), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Date d\'embauche: ${_selectedHireDate.day}/${_selectedHireDate.month}/${_selectedHireDate.year}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _salaryController,
                        decoration: const InputDecoration(
                          labelText: 'Salaire mensuel (FCFA)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.euro_symbol),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Salaire requis';
                          if (double.tryParse(v) == null) return 'Montant invalide';
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Statut actif/inactif
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Employé actif'),
                        subtitle: Text(
                          _isActive
                              ? 'Cet employé peut travailler'
                              : 'Cet employé est actuellement inactif',
                        ),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                        activeColor: const Color(0xFF10B981),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Boutons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isEditing ? 'Modifier' : 'Ajouter'),
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
  }
}
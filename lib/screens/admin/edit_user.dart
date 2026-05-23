// lib/screens/admin/edit_user_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../providers/auth_provider.dart';

class EditUserScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onUserUpdated;

  const EditUserScreen({
    super.key,
    required this.user,
    this.onUserUpdated,
  });

  @override
  _EditUserScreenState createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController passwordController;
  late String role;

  final DBHelper db = DBHelper();
  late AnimationController _animationController;

  List<Map<String, String>> get _availableRoles {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isSuperAdmin) {
      return const [
        {'value': 'student', 'label': 'Étudiant'},
        {'value': 'teacher', 'label': 'Enseignant'},
        {'value': 'parent', 'label': 'Parent'},
        {'value': 'staff', 'label': 'Personnel'},
        {'value': 'admin', 'label': 'Administrateur'},
        {'value': 'super_admin', 'label': 'Super Admin'},
      ];
    } else {
      return const [
        {'value': 'student', 'label': 'Étudiant'},
        {'value': 'teacher', 'label': 'Enseignant'},
        {'value': 'parent', 'label': 'Parent'},
        {'value': 'staff', 'label': 'Personnel'},
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    final u = widget.user;
    nameController = TextEditingController(text: u['name']);
    emailController = TextEditingController(text: u['email']);
    passwordController = TextEditingController(text: u['password'] ?? '');
    role = u['role'];
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// 🔥 Mettre à jour l'utilisateur dans Firestore
  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    final authorizedRoles = _availableRoles.map((r) => r['value']).toList();
    if (!authorizedRoles.contains(role)) {
      _showSnackBar('Rôle non autorisé pour votre niveau d’accès', const Color(0xFFEF4444));
      return;
    }

    try {
      final firestoreId = widget.user['firestoreId'];
      if (firestoreId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(firestoreId)
            .update({
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'role': role,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Mettre à jour localement aussi
      await db.updateUser(widget.user['id'], {
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'password': passwordController.text.trim(),
        'role': role,
      });
      
      widget.onUserUpdated?.call();
      _showSnackBar('Utilisateur modifié avec succès', const Color(0xFF10B981));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar('Erreur : $e', const Color(0xFFEF4444));
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Modifier l’utilisateur',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
      ),
      body: FadeTransition(
        opacity: _animationController,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.person, color: Color(0xFF3B82F6), size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Modifier les informations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      controller: nameController,
                      label: 'Nom complet',
                      icon: Icons.person_outline,
                      validator: (value) => value!.isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: emailController,
                      label: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => value!.isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: passwordController,
                      label: 'Mot de passe',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      validator: (value) => value!.isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownForm(
                      value: role,
                      items: _availableRoles,
                      label: 'Rôle',
                      icon: Icons.assignment_ind_outlined,
                      onChanged: (value) { if (value != null) setState(() => role = value); },
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            label: const Text('Annuler'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveUser,
                            icon: const Icon(Icons.save),
                            label: const Text('Enregistrer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
        prefixIcon: Icon(icon, color: const Color(0xFF10B981)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDropdownForm({
    required String value,
    required List<Map<String, String>> items,
    required String label,
    required IconData icon,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((item) => DropdownMenuItem(value: item['value'], child: Text(item['label']!))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
        prefixIcon: Icon(icon, color: const Color(0xFF10B981)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
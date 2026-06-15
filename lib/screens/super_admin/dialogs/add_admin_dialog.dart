// lib/screens/super_admin/dialogs/add_admin_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../../../services/db_helper.dart';

class AddAdminDialog extends StatefulWidget {
  final VoidCallback onAdminAdded;

  const AddAdminDialog({super.key, required this.onAdminAdded});

  @override
  _AddAdminDialogState createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<AddAdminDialog> {
  final DBHelper db = DBHelper();
  final _formKey = GlobalKey<FormState>();

  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'admin';
  String? _selectedSchoolId;
  String? _selectedSchoolName;
  bool _isLoading = false;

  @override
  void dispose() {
    _nomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Vérifier qu'une école est sélectionnée (sauf pour super_admin)
    if (_selectedRole != 'super_admin' && _selectedSchoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une école'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔥 1. CRÉER DANS FIREBASE AUTH (important pour la connexion)
      final userCredential = await firebase_auth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
      
      final uid = userCredential.user!.uid;
      print('✅ Compte Firebase Auth créé avec UID: $uid');
      
      // 🔥 2. Ajouter dans Firestore (collection 'users')
      final userData = {
        'name': _nomController.text,
        'email': _emailController.text.toLowerCase().trim(),
        'role': _selectedRole,
        'schoolId': _selectedRole == 'super_admin' ? null : _selectedSchoolId,
        'schoolName': _selectedRole == 'super_admin' ? null : _selectedSchoolName,
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'firebaseUid': uid,
      };
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(userData);
      
      print('✅ ${_selectedRole} ajouté dans Firestore avec UID: $uid');
      
      // 🔥 3. Ajouter dans users_info
      final userInfoData = {
        'userId': uid,
        'fullName': _nomController.text,
        'userEmail': _emailController.text.toLowerCase().trim(),
        'role': _selectedRole,
        'roleLabel': _selectedRole == 'admin' ? 'Administrateur' : 'Super Administrateur',
        'schoolId': _selectedRole == 'super_admin' ? null : _selectedSchoolId,
        'schoolName': _selectedRole == 'super_admin' ? null : _selectedSchoolName,
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await FirebaseFirestore.instance
          .collection('users_info')
          .doc(uid)
          .set(userInfoData);
      
      // 🔥 4. Sauvegarder localement dans Hive
      await db.insertUser({
        'name': _nomController.text,
        'email': _emailController.text.toLowerCase().trim(),
        'password': _passwordController.text,
        'role': _selectedRole,
        'schoolId': _selectedRole == 'super_admin' ? null : _selectedSchoolId,
        'schoolName': _selectedRole == 'super_admin' ? null : _selectedSchoolName,
        'firestoreId': uid,
        'status': 'approved',
      });
      
      // 🔥 5. Ajouter un log
      await db.addLog("Super Admin a ajouté un ${_selectedRole == 'admin' ? 'administrateur' : 'super administrateur'}: ${_nomController.text} (${_emailController.text})");
      
      widget.onAdminAdded();
      if (mounted) Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedRole == 'admin' ? 'Administrateur' : 'Super Administrateur'} ajouté avec succès'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('❌ Erreur Firebase Auth: ${e.code} - ${e.message}');
      
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'Cet email est déjà utilisé par un autre compte';
          break;
        case 'invalid-email':
          errorMessage = 'Format d\'email invalide';
          break;
        case 'weak-password':
          errorMessage = 'Le mot de passe est trop faible (minimum 6 caractères)';
          break;
        default:
          errorMessage = 'Erreur: ${e.message}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      print('❌ Erreur générale: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: Color(0xFF8B5CF6)),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Ajouter un administrateur',
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
                      labelText: 'Nom complet *',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Nom requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || v.isEmpty ? 'Email requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe *',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Mot de passe requis';
                      if (v.length < 6) return 'Minimum 6 caractères';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Rôle',
                      prefixIcon: Icon(Icons.assignment_ind),
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Administrateur école')),
                      DropdownMenuItem(value: 'super_admin', child: Text('Super Administrateur')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value!;
                        if (value == 'super_admin') {
                          _selectedSchoolId = null;
                          _selectedSchoolName = null;
                        }
                      });
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Sélection de l'école (uniquement pour les admins)
                  if (_selectedRole != 'super_admin')
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('schools')
                          .where('isActive', isEqualTo: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                          );
                        }
                        
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        final schools = snapshot.data!.docs;
                        
                        if (schools.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.warning, color: Colors.orange),
                                SizedBox(height: 8),
                                Text(
                                  'Aucune école disponible',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('Veuillez d\'abord créer une école.'),
                              ],
                            ),
                          );
                        }
                        
                        return DropdownButtonFormField<String>(
                          value: _selectedSchoolId,
                          decoration: const InputDecoration(
                            labelText: 'École *',
                            prefixIcon: Icon(Icons.business),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                          ),
                          items: schools.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final schoolName = data['name'] ?? 'École sans nom';
                            final schoolCode = data['schoolCode'] ?? '';
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    schoolName,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  if (schoolCode.isNotEmpty)
                                    Text(
                                      'Code: $schoolCode',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            final school = schools.firstWhere((doc) => doc.id == value);
                            final data = school.data() as Map<String, dynamic>;
                            setState(() {
                              _selectedSchoolId = value;
                              _selectedSchoolName = data['name'] ?? 'École';
                            });
                          },
                          validator: (value) => value == null ? 'Veuillez sélectionner une école' : null,
                        );
                      },
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
                    onPressed: _isLoading ? null : _saveAdmin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
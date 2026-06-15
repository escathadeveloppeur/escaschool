// lib/screens/register_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../services/db_helper.dart';
import '../services/school_service.dart';
import '../models/university/etablissement_model.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String? prefillEmail;
  
  const RegisterScreen({super.key, this.prefillEmail});
  
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final DBHelper db = DBHelper();
  final SchoolService _schoolService = SchoolService();
  final _formKey = GlobalKey<FormState>();
  
  // Contrôleurs compte
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _schoolCodeController = TextEditingController();
  
  // Contrôleurs informations personnelles (élève)
  final _birthDateController = TextEditingController();
  final _birthPlaceController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  
  // Variables
  String _selectedRole = 'student';
  String _selectedGender = 'Masculin';
  EtablissementModel? _selectedSchool;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isVerifyingCode = false;
  bool _showPersonalInfo = false;
  late AnimationController _animationController;
  String _schoolCodeError = '';
  
  final List<String> _genders = ['Masculin', 'Féminin'];
  
  // Roles disponibles
  final List<Map<String, dynamic>> _roles = [
    {'value': 'student', 'label': 'Étudiant', 'icon': Icons.school, 'color': const Color(0xFF3B82F6)},
    {'value': 'teacher', 'label': 'Enseignant', 'icon': Icons.person, 'color': const Color(0xFF10B981)},
    {'value': 'parent', 'label': 'Parent', 'icon': Icons.family_restroom, 'color': const Color(0xFFF59E0B)},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animationController.forward();
    
    if (widget.prefillEmail != null) {
      _emailController.text = widget.prefillEmail!;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _schoolCodeController.dispose();
    _birthDateController.dispose();
    _birthPlaceController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _parentPhoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _verifySchoolCode() async {
    final code = _schoolCodeController.text.trim().toUpperCase();
    
    if (code.isEmpty) {
      setState(() => _schoolCodeError = 'Veuillez entrer un code d\'école');
      return;
    }
    
    setState(() {
      _isVerifyingCode = true;
      _schoolCodeError = '';
    });
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .where('schoolCode', isEqualTo: code)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        
        setState(() {
          _selectedSchool = EtablissementModel(
            id: data['localId'] ?? 0,
            nom: data['name'] ?? 'École',
            type: data['type'] ?? 'École',
            adresse: data['address'],
            telephone: data['phone'],
            email: data['email'],
            siteWeb: data['website'],
            firestoreId: doc.id,
            isActive: data['isActive'] ?? true,
            schoolCode: data['schoolCode'] ?? '',
          );
          _schoolCodeError = '';
          _showPersonalInfo = true;
        });
        
        _showSnackBar('✅ École trouvée : ${_selectedSchool!.nom}', const Color(0xFF10B981));
      } else {
        setState(() => _schoolCodeError = 'Code invalide. Vérifiez auprès de l\'administration.');
      }
    } catch (e) {
      setState(() => _schoolCodeError = 'Erreur: $e');
    } finally {
      setState(() => _isVerifyingCode = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Les mots de passe ne correspondent pas', const Color(0xFFEF4444));
      return;
    }
    
    if (_selectedSchool == null) {
      _showSnackBar('Code d\'école invalide', const Color(0xFFF59E0B));
      return;
    }
    
    if (!_selectedSchool!.isActive) {
      _showSnackBar('Cette école est actuellement suspendue.', const Color(0xFFEF4444));
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      final success = await authProvider.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _selectedRole,
        _selectedSchool!.firestoreId ?? '',  // String? -> String
      );
      
      if (success) {
        await _savePersonalInfo(authProvider.user?.id.toString());
        
        _showSnackBar('Inscription réussie ! En attente de validation par le staff.', const Color(0xFF10B981));
        
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        });
      } else {
        _showSnackBar('Erreur lors de l\'inscription.', const Color(0xFFEF4444));
      }
    } catch (e) {
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
  
  Future<void> _savePersonalInfo(String? userId) async {
    if (userId == null) return;
    
    final personalData = {
      'userId': userId,
      'userEmail': _emailController.text.trim(),
      'fullName': _nameController.text.trim(),
      'gender': _selectedGender,
      'birthDate': _birthDateController.text.trim(),
      'birthPlace': _birthPlaceController.text.trim(),
      'fatherName': _fatherNameController.text.trim(),
      'motherName': _motherNameController.text.trim(),
      'parentPhone': _parentPhoneController.text.trim(),
      'address': _addressController.text.trim(),
      'role': _selectedRole,
      'schoolId': _selectedSchool?.id,
      'schoolName': _selectedSchool?.nom,
      'status': 'pending',
      'documentsVerified': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    await FirebaseFirestore.instance.collection('users_info').doc(userId).set(personalData);
    
    // Si c'est un étudiant, créer une entrée dans students (sans classe)
    if (_selectedRole == 'student') {
      final studentData = {
        'userId': userId,
        'userEmail': _emailController.text.trim(),
        'fullName': _nameController.text.trim(),
        'gender': _selectedGender,
        'birthDate': _birthDateController.text.trim(),
        'birthPlace': _birthPlaceController.text.trim(),
        'fatherName': _fatherNameController.text.trim(),
        'motherName': _motherNameController.text.trim(),
        'parentPhone': _parentPhoneController.text.trim(),
        'address': _addressController.text.trim(),
        'documentsVerified': false,
        'status': 'pending_validation',
        'schoolId': _selectedSchool?.firestoreId,
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      await FirebaseFirestore.instance.collection('students').add(studentData);
      print('✅ Étudiant créé en attente d\'affectation de classe');
    }
    
    print('✅ Informations personnelles sauvegardées pour $userId');
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // LOGO PERSONNALISÉ
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: Image.asset(
              'assets/images/logo.png',
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                    ),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.school,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'EscaSchool',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F766E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Créez votre compte',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    required String hint, 
    required IconData icon, 
    TextInputType keyboardType = TextInputType.text, 
    int maxLines = 1, 
    String? Function(String?)? validator
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF10B981)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
        filled: true, 
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller, 
    required String label, 
    required bool isVisible, 
    required VoidCallback onToggle, 
    String? Function(String?)? validator
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF10B981)),
        suffixIcon: IconButton(
          icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility, color: Colors.grey[400], size: 20),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
        filled: true, 
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      decoration: InputDecoration(
        labelText: 'Rôle',
        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF10B981)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: Colors.white,
      ),
      items: _roles.map<DropdownMenuItem<String>>((role) {
        return DropdownMenuItem<String>(
          value: role['value'] as String,
          child: Row(
            children: [
              Icon(role['icon'] as IconData, size: 20, color: role['color'] as Color),
              const SizedBox(width: 12),
              Text(role['label'] as String),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedRole = value!),
    );
  }

  Widget _buildSchoolCodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _schoolCodeController,
          decoration: InputDecoration(
            labelText: 'Code de l\'école *',
            hintText: 'Entrez le code fourni par l\'école',
            prefixIcon: const Icon(Icons.business_outlined, color: Color(0xFF10B981)),
            suffixIcon: _isVerifyingCode 
              ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))) 
              : IconButton(icon: const Icon(Icons.search, color: Color(0xFF10B981)), onPressed: _verifySchoolCode),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            filled: true, 
            fillColor: Colors.white,
          ),
          onChanged: (value) { 
            if (_selectedSchool != null) setState(() => _selectedSchool = null); 
            if (_schoolCodeError.isNotEmpty) setState(() => _schoolCodeError = ''); 
          },
          validator: (v) => v == null || v.isEmpty ? 'Code école requis' : null,
        ),
        if (_schoolCodeError.isNotEmpty) 
          Padding(padding: const EdgeInsets.only(top: 8, left: 12), child: Text(_schoolCodeError, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: FadeTransition(
            opacity: _animationController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const Text('Créer un compte', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Inscrivez-vous pour accéder à votre espace', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                          const SizedBox(height: 24),
                          
                          // SECTION 1: Informations du compte
                          _buildSectionTitle('Informations du compte', Icons.account_circle, const Color(0xFF8B5CF6)),
                          const SizedBox(height: 16),
                          
                          _buildTextField(controller: _nameController, label: 'Nom complet', hint: 'Jean Dupont', icon: Icons.person_outline, validator: (v) => v == null || v.isEmpty ? 'Nom requis' : null),
                          const SizedBox(height: 12),
                          
                          _buildTextField(controller: _emailController, label: 'Adresse email', hint: 'jean@exemple.com', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (v) => v == null || v.isEmpty ? 'Email requis' : null),
                          const SizedBox(height: 12),
                          
                          _buildPasswordField(controller: _passwordController, label: 'Mot de passe', isVisible: _isPasswordVisible, onToggle: () => setState(() => _isPasswordVisible = !_isPasswordVisible), validator: (v) => v == null || v.isEmpty ? 'Mot de passe requis' : (v.length < 6 ? 'Minimum 6 caractères' : null)),
                          const SizedBox(height: 12),
                          
                          _buildPasswordField(controller: _confirmPasswordController, label: 'Confirmer le mot de passe', isVisible: _isConfirmPasswordVisible, onToggle: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible), validator: (v) => v == null || v.isEmpty ? 'Confirmation requise' : null),
                          const SizedBox(height: 12),
                          
                          _buildRoleDropdown(),
                          const SizedBox(height: 12),
                          
                          _buildSchoolCodeField(),
                          const SizedBox(height: 12),
                          
                          if (_selectedSchool != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
                              child: Row(children: [const Icon(Icons.check_circle, color: Color(0xFF10B981)), const SizedBox(width: 12), Expanded(child: Text(_selectedSchool!.nom, style: const TextStyle(fontWeight: FontWeight.w600)))]),
                            ),
                          
                          // SECTION 2: Informations personnelles
                          if (_showPersonalInfo) ...[
                            const SizedBox(height: 24),
                            _buildSectionTitle('Informations personnelles', Icons.person, const Color(0xFF3B82F6)),
                            const SizedBox(height: 16),
                            
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              decoration: InputDecoration(
                                labelText: "Sexe",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                prefixIcon: const Icon(Icons.wc),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                              onChanged: (v) => setState(() => _selectedGender = v!),
                              validator: (v) => v == null ? 'Sexe requis' : null,
                            ),
                            const SizedBox(height: 12),
                            
                            _buildTextField(
                              controller: _birthDateController, 
                              label: 'Date de naissance', 
                              hint: 'JJ/MM/AAAA', 
                              icon: Icons.calendar_today,
                              validator: (v) => v == null || v.isEmpty ? 'Date de naissance requise' : null,
                            ),
                            const SizedBox(height: 12),
                            
                            _buildTextField(
                              controller: _birthPlaceController, 
                              label: 'Lieu de naissance', 
                              hint: 'Ville', 
                              icon: Icons.location_city,
                              validator: (v) => v == null || v.isEmpty ? 'Lieu de naissance requis' : null,
                            ),
                            const SizedBox(height: 12),
                            
                            _buildTextField(
                              controller: _fatherNameController, 
                              label: 'Nom du père', 
                              hint: '', 
                              icon: Icons.man,
                            ),
                            const SizedBox(height: 12),
                            
                            _buildTextField(
                              controller: _motherNameController, 
                              label: 'Nom de la mère', 
                              hint: '', 
                              icon: Icons.woman,
                            ),
                            const SizedBox(height: 12),
                            
                            _buildTextField(
                              controller: _parentPhoneController, 
                              label: 'Téléphone du parent', 
                              hint: '+243 XXX XXX XXX', 
                              icon: Icons.phone, 
                              keyboardType: TextInputType.phone,
                              validator: (v) => v == null || v.isEmpty ? 'Téléphone requis' : null,
                            ),
                            const SizedBox(height: 12),
                            
                            _buildTextField(
                              controller: _addressController, 
                              label: 'Adresse', 
                              hint: '', 
                              icon: Icons.home, 
                              maxLines: 2,
                            ),
                            
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Après inscription, votre compte sera examiné par l'administration. Vous serez notifié une fois validé.",
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981), 
                                padding: const EdgeInsets.symmetric(vertical: 16), 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                              ),
                              child: _isSubmitting 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                                : const Text('S\'inscrire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Déjà un compte ?', style: TextStyle(color: Colors.grey[600])),
                              TextButton(
                                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())), 
                                child: const Text('Se connecter', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Footer
                Text(
                  '© 2024 EscaSchool | Tous droits réservés',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
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
  
  // Contrôleurs
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _schoolCodeController = TextEditingController(); // Nouveau pour code école
  
  // Variables
  String _selectedRole = 'student';
  EtablissementModel? _selectedSchool;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isVerifyingCode = false;
  late AnimationController _animationController;
  String _schoolCodeError = '';
  
  // Roles disponibles (sans super_admin dans l'inscription)
  final List<Map<String, dynamic>> _roles = [
    {'value': 'student', 'label': 'Étudiant', 'icon': Icons.school, 'color': const Color(0xFF3B82F6)},
    {'value': 'teacher', 'label': 'Enseignant', 'icon': Icons.person, 'color': const Color(0xFF10B981)},
    {'value': 'parent', 'label': 'Parent', 'icon': Icons.family_restroom, 'color': const Color(0xFFF59E0B)},
    {'value': 'staff', 'label': 'Personnel', 'icon': Icons.work, 'color': const Color(0xFF8B5CF6)},
    {'value': 'admin', 'label': 'Administrateur', 'icon': Icons.admin_panel_settings, 'color': const Color(0xFFEF4444)},
  ];

  @override
  void initState() {
    super.initState();
    print('=== INIT RegisterScreen ===');
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animationController.forward();
    
    // Pré-remplir l'email si fourni
    if (widget.prefillEmail != null) {
      _emailController.text = widget.prefillEmail!;
      print('📧 Email pré-rempli: ${widget.prefillEmail}');
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
    super.dispose();
  }

  /// Vérifier le code de l'école dans Firestore
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
      // Chercher dans Firestore
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
            schoolCode: data['schoolCode'] ?? '',  // ← Correction ici
          );
          _schoolCodeError = '';
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
    print('\n=== DÉBUT DE L\'INSCRIPTION AVEC FIREBASE ===');
    print('📝 Formulaire valide: ${_formKey.currentState?.validate()}');
    
    if (!_formKey.currentState!.validate()) {
      print('❌ Formulaire invalide');
      return;
    }
    
    // Vérifier que les mots de passe correspondent
    if (_passwordController.text != _confirmPasswordController.text) {
      print('❌ Mots de passe ne correspondent pas');
      _showSnackBar('Les mots de passe ne correspondent pas', const Color(0xFFEF4444));
      return;
    }
    print('✅ Mots de passe identiques');
    
    // Vérifier que l'école est sélectionnée
    if (_selectedSchool == null) {
      print('❌ Aucune école trouvée avec ce code');
      _showSnackBar('Code d\'école invalide', const Color(0xFFF59E0B));
      return;
    }
    
    // Vérifier que l'école est active
    if (!_selectedSchool!.isActive) {
      print('❌ École suspendue');
      _showSnackBar('Cette école est actuellement suspendue. Contactez l\'administration.', const Color(0xFFEF4444));
      return;
    }
    
    print('✅ École validée: ${_selectedSchool!.nom} (Code: ${_schoolCodeController.text})');
    
    setState(() => _isSubmitting = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      print('📤 Appel à AuthProvider.register...');
      print('   - name: ${_nameController.text}');
      print('   - email: ${_emailController.text}');
      print('   - role: $_selectedRole');
      print('   - schoolId: ${_selectedSchool!.id}');
      
      final success = await authProvider.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _selectedRole,
        _selectedSchool!.id,
      );
      
      if (success) {
        print('✅ Inscription Firebase réussie !');
        _showSnackBar('Inscription réussie ! Veuillez vous connecter.', const Color(0xFF10B981));
        
        print('🔄 Redirection vers login...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        print('❌ Échec de l\'inscription Firebase');
        _showSnackBar('Erreur lors de l\'inscription. Vérifiez votre connexion.', const Color(0xFFEF4444));
      }
      
    } catch (e) {
      print('❌ ERREUR: $e');
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    } finally {
      setState(() => _isSubmitting = false);
      print('=== FIN DE L\'INSCRIPTION ===\n');
    }
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const Text(
                            'Créer un compte',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Inscrivez-vous pour accéder à votre espace',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          _buildTextField(
                            controller: _nameController,
                            label: 'Nom complet',
                            hint: 'Jean Dupont',
                            icon: Icons.person_outline,
                            validator: (v) => v == null || v.isEmpty ? 'Nom requis' : null,
                          ),
                          const SizedBox(height: 16),
                          
                          _buildTextField(
                            controller: _emailController,
                            label: 'Adresse email',
                            hint: 'jean@exemple.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v == null || v.isEmpty ? 'Email requis' : null,
                          ),
                          const SizedBox(height: 16),
                          
                          _buildPasswordField(
                            controller: _passwordController,
                            label: 'Mot de passe',
                            isVisible: _isPasswordVisible,
                            onToggle: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Mot de passe requis';
                              if (v.length < 6) return 'Minimum 6 caractères';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          _buildPasswordField(
                            controller: _confirmPasswordController,
                            label: 'Confirmer le mot de passe',
                            isVisible: _isConfirmPasswordVisible,
                            onToggle: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Confirmation requise';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          _buildRoleDropdown(),
                          const SizedBox(height: 16),
                          
                          // Champ pour le code de l'école (remplace le dropdown)
                          _buildSchoolCodeField(),
                          const SizedBox(height: 16),
                          
                          // Affichage de l'école trouvée
                          if (_selectedSchool != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedSchool!.nom,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          'Code validé',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          const SizedBox(height: 24),
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (_isSubmitting) ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'S\'inscrire',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Déjà un compte ?',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  );
                                },
                                child: const Text(
                                  'Se connecter',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.w600,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: Icon(Icons.school, size: 45, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Ecole+',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Plateforme de gestion scolaire',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: const Color(0xFF10B981)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
        ),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF10B981)),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey[400],
            size: 20,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
        ),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      onChanged: (value) {
        setState(() {
          _selectedRole = value!;
        });
      },
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
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.search, color: Color(0xFF10B981)),
                    onPressed: _verifySchoolCode,
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: (value) {
            if (_selectedSchool != null) {
              setState(() => _selectedSchool = null);
            }
            if (_schoolCodeError.isNotEmpty) {
              setState(() => _schoolCodeError = '');
            }
          },
        ),
        if (_schoolCodeError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Text(
              _schoolCodeError,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
            ),
          ),
      ],
    );
  }
}
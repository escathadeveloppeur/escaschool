// lib/screens/login_screen.dart

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import './student/student_dashboard.dart';
import './teacher/teacher_dashboard.dart';
import './parent/parent_dashboard.dart';
import './staff/staff_dashboard.dart';
import './admin/admin_dashboard.dart';
import './super_admin/super_admin_dashboard.dart';
import './register_screen.dart';
import '../services/db_helper.dart';
import '../services/sync_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _error = '';
  final DBHelper db = DBHelper();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// ✅ Vérifier si une école est active
  Future<bool> _isSchoolActive(String? schoolId) async {
    if (schoolId == null || schoolId.isEmpty) return true;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .get();
      
      if (!doc.exists) return false;
      
      final data = doc.data();
      final isActive = data?['isActive'] ?? true;
      final statut = data?['statut'] ?? 'Actif';
      
      print('🏫 Vérification école: $schoolId');
      print('   → isActive: $isActive');
      print('   → statut: $statut');
      
      return isActive;
    } catch (e) {
      print('❌ Erreur vérification école: $e');
      return true; // En cas d'erreur, on autorise la connexion
    }
  }

  Future<void> _submit() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    setState(() {
      _error = '';
      _isLoading = true;
    });
    
    final ok = await auth.login(_emailCtrl.text.trim(), _passCtrl.text.trim());
    
    setState(() => _isLoading = false);
    
    if (!ok) {
      final userExists = await db.getUserByEmail(_emailCtrl.text.trim());
      
      if (userExists == null) {
        _showAccountNotFoundDialog();
      } else {
        setState(() {
          _error = 'Mot de passe incorrect';
        });
      }
      return;
    }
    
    final user = auth.user!;
    
    // ✅ Vérifier le statut de l'école avant de rediriger
    final isSchoolActive = await _isSchoolActive(user.schoolId);
    
    if (!isSchoolActive) {
      _showSchoolSuspendedDialog(user);
      return;
    }
    
    await _redirect(user);
  }

  /// ✅ Afficher le dialogue d'école suspendue
  void _showSchoolSuspendedDialog(User user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('École suspendue', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.business_rounded, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        '🚫 École suspendue',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cette école est actuellement suspendue.\nVous ne pouvez pas accéder à vos données.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    user.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    user.email,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              // Déconnecter l'utilisateur
await Provider.of<AuthProvider>(context, listen: false).logout();              // Revenir sur l'écran de connexion
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Se déconnecter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAccountNotFoundDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_off, color: Color(0xFFF59E0B), size: 28),
            SizedBox(width: 12),
            Text('Compte introuvable', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aucun compte associé à cette adresse email :', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: Text(_emailCtrl.text.trim(), style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'monospace')),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text('Souhaitez-vous créer un nouveau compte ?', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => RegisterScreen(prefillEmail: _emailCtrl.text.trim())));
            },
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Créer un compte'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _redirect(User user) async {
    Widget? destination;
    
    switch (user.role) {
      case 'admin':
        destination = const AdminDashboard(); 
        break;
      case 'student':
        destination = const StudentDashboard(); 
        break;
      case 'teacher':
        destination = await _getTeacherDashboard(user);
        break;
      case 'parent':
        destination = const ParentDashboard(); 
        break;
      case 'staff':
        destination = const AdminStaffDashboard(); 
        break;
      case 'super_admin':
        destination = const SuperAdminDashboard(); 
        break;
      default:
        destination = const StudentDashboard();
    }
    
    if (destination != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => destination!));
    } else {
      setState(() {
        _error = 'Problème lors du chargement du tableau de bord. Contactez l\'administration.';
      });
    }
  }

  Future<Widget?> _getTeacherDashboard(User user) async {
    try {
      final professorsSnapshot = await FirebaseFirestore.instance
          .collection('professors')
          .where('userId', isEqualTo: user.id)
          .limit(1)
          .get();
      
      if (professorsSnapshot.docs.isEmpty) {
        final professor = await db.getProfessorByUserId(user.id);
        if (professor == null) {
          setState(() { _error = 'Profil professeur non trouvé. Contactez l\'administration.'; });
          return null;
        }
        
        if (professor['status'] != 'active') {
          setState(() { _error = 'Votre compte professeur est désactivé.'; });
          return null;
        }
        
        final professorId = professor['id'] as int? ?? 0;
        final professorName = professor['fullName'] as String? ?? user.name;
        
        if (professorId <= 0) {
          setState(() { _error = 'ID professeur invalide.'; });
          return null;
        }
        
        return TeacherDashboard(
          professorFirestoreId: professorId.toString(),
          professorName: professorName,
        );
      }
      
      final professorDoc = professorsSnapshot.docs.first;
      final professorData = professorDoc.data();
      final professorFirestoreId = professorDoc.id;
      final professorName = professorData['fullName'] as String? ?? user.name;
      final professorStatus = professorData['status'] as String? ?? 'active';
      
      if (professorStatus != 'active') {
        setState(() { _error = 'Votre compte professeur est désactivé.'; });
        return null;
      }
      
      return TeacherDashboard(
        professorFirestoreId: professorFirestoreId,
        professorName: professorName,
      );
      
    } catch (e) {
      return TeacherDashboard(
        professorFirestoreId: '0',
        professorName: user.name.isNotEmpty ? user.name : "Professeur",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF0F766E), const Color(0xFF14B8A6)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo et titre
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
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
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Gestion scolaire intelligente',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Formulaire de connexion
                  SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Connexion',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Connectez-vous à votre espace',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Champ email
                            TextFormField(
                              controller: _emailCtrl,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'Adresse email',
                                hintText: 'exemple@ecole.com',
                                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF10B981), size: 22),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.grey[200]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.grey[200]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 20),
                            
                            // Champ mot de passe
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: !_isPasswordVisible,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                labelText: 'Mot de passe',
                                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF10B981), size: 22),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.grey[400],
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.grey[200]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.grey[200]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Mot de passe oublié
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Contactez l\'administration pour réinitialiser votre mot de passe'),
                                      backgroundColor: const Color(0xFFF59E0B),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Mot de passe oublié ?',
                                  style: TextStyle(color: Color(0xFF10B981), fontSize: 13),
                                ),
                              ),
                            ),
                            
                            // Message d'erreur
                            if (_error.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFEE2E2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _error,
                                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            const SizedBox(height: 28),
                            
                            // Bouton de connexion
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (_isLoading || auth.isLoading) ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: (_isLoading || auth.isLoading)
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Se connecter',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Lien vers inscription
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Pas encore de compte ?',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const RegisterScreen(),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  child: const Text(
                                    'Créer un compte',
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
                  
                  const SizedBox(height: 32),
                  
                  // Footer
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          '© 2024 EscaSchool | Tous droits réservés',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
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
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    print('=== LOGIN SCREEN INITIALISÉE ===');
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
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

  Future<void> _submit() async {
    print('🔐 Tentative de connexion...');
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    setState(() {
      _error = '';
      _isLoading = true;
    });
    
    final ok = await auth.login(_emailCtrl.text.trim(), _passCtrl.text.trim());
    
    setState(() => _isLoading = false);
    
    if (!ok) {
      print('❌ Connexion échouée');
      final userExists = await db.getUserByEmail(_emailCtrl.text.trim());
      
      if (userExists == null) {
        print('📧 Compte inexistant, proposition création');
        _showAccountNotFoundDialog();
      } else {
        print('🔑 Mot de passe incorrect');
        setState(() {
          _error = 'Mot de passe incorrect';
        });
      }
      return;
    }
    
    print('✅ Connexion réussie pour: ${_emailCtrl.text}');
    final user = auth.user!;
    await _redirect(user);
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ),
    );
  }

  Future<void> _redirect(User user) async {
    print('🔄 Redirection vers dashboard pour rôle: ${user.role}');
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
      print('✅ Navigation vers dashboard');
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => destination!));
    } else {
      print('❌ Impossible de charger le dashboard');
      setState(() {
        _error = 'Problème lors du chargement du tableau de bord. Contactez l\'administration.';
      });
    }
  }

  Future<Widget?> _getTeacherDashboard(User user) async {
    print('📚 Chargement dashboard professeur pour user ID: ${user.id}');
    try {
      // Récupérer le professeur depuis Firestore pour avoir le firestoreId
      final professorsSnapshot = await FirebaseFirestore.instance
          .collection('professors')
          .where('userId', isEqualTo: user.id)
          .limit(1)
          .get();
      
      if (professorsSnapshot.docs.isEmpty) {
        final professor = await db.getProfessorByUserId(user.id);
        if (professor == null) {
          print('❌ Profil professeur non trouvé');
          setState(() { _error = 'Profil professeur non trouvé. Contactez l\'administration.'; });
          return null;
        }
        
        if (professor['status'] != 'active') {
          print('⚠️ Compte professeur désactivé');
          setState(() { _error = 'Votre compte professeur est désactivé.'; });
          return null;
        }
        
        final professorId = professor['id'] as int? ?? 0;
        final professorName = professor['fullName'] as String? ?? user.name;
        
        if (professorId <= 0) {
          print('❌ ID professeur invalide: $professorId');
          setState(() { _error = 'ID professeur invalide.'; });
          return null;
        }
        
        print('✅ Dashboard professeur chargé (fallback Hive): ID=$professorId, Nom=$professorName');
        return TeacherDashboard(
          professorFirestoreId: professorId.toString(),
          professorName: professorName,
        );
      }
      
      // Utiliser le firestoreId depuis Firestore
      final professorDoc = professorsSnapshot.docs.first;
      final professorData = professorDoc.data();
      final professorFirestoreId = professorDoc.id;
      final professorName = professorData['fullName'] as String? ?? user.name;
      final professorStatus = professorData['status'] as String? ?? 'active';
      
      if (professorStatus != 'active') {
        print('⚠️ Compte professeur désactivé');
        setState(() { _error = 'Votre compte professeur est désactivé.'; });
        return null;
      }
      
      print('✅ Dashboard professeur chargé depuis Firestore: firestoreId=$professorFirestoreId, Nom=$professorName');
      return TeacherDashboard(
        professorFirestoreId: professorFirestoreId,
        professorName: professorName,
      );
      
    } catch (e) {
      print('❌ Erreur lors du chargement du dashboard professeur: $e');
      return TeacherDashboard(
        professorFirestoreId: '0',
        professorName: user.name.isNotEmpty ? user.name : "Professeur",
      );
    }
  }

  void _fillTestAccount(String email, String password) {
    print('📝 Remplissage compte test: $email');
    setState(() {
      _emailCtrl.text = email;
      _passCtrl.text = password;
      _error = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Identifiants copiés: $email'), backgroundColor: const Color(0xFF10B981), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    );
  }

  Future<void> _testSync() async {
    print("\n🧪 === TEST SYNCHRONISATION ===");
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final syncService = SyncService();
    
    final hasInternet = await syncService.hasInternet();
    print("1. Internet: ${hasInternet ? '✅ Connecté' : '❌ Pas de connexion'}");
    
    final isFirebaseConnected = await syncService.isFirebaseConnected();
    print("2. Firebase: ${isFirebaseConnected ? '✅ Connecté' : '❌ Non connecté'}");
    
    if (auth.user != null) {
      print("3. Utilisateur: ${auth.user!.email}, Role: ${auth.user!.role}, School ID: ${auth.currentSchoolId}");
      if (auth.currentSchoolId != null) {
        print("4. Synchronisation forcée...");
        await syncService.forceSync(schoolId: auth.currentSchoolId.toString());
        print("   ✅ Terminée");
      }
      final pendingCount = await syncService.getPendingSyncCount();
      print("5. Éléments en attente: $pendingCount");
      final lastSync = await syncService.getLastSyncTimestamp();
      print("6. Dernière sync: ${lastSync ?? 'Jamais'}");
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test terminé: Firebase ${isFirebaseConnected ? "OK" : "KO"}'), backgroundColor: isFirebaseConnected ? Colors.green : Colors.orange, duration: const Duration(seconds: 2)),
      );
    } else {
      print("❌ Aucun utilisateur connecté");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez vous connecter d\'abord'), backgroundColor: Colors.orange));
    }
    print("=== FIN TEST ===\n");
  }

  Future<void> _testFirestoreWrite() async {
    print("\n📝 === TEST ÉCRITURE FIRESTORE ===");
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("❌ Aucun utilisateur connecté");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connectez-vous d\'abord')));
        return;
      }
      
      final docRef = FirebaseFirestore.instance.collection('test_sync').doc('test_${DateTime.now().millisecondsSinceEpoch}');
      await docRef.set({
        'message': 'Test synchronisation',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'email': user.email,
      });
      
      print("✅ Document créé: ${docRef.id}");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Document créé: ${docRef.id}'), backgroundColor: Colors.green));
    } catch (e) {
      print("❌ Erreur: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
    print("=== FIN TEST ===\n");
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
              padding: const EdgeInsets.all(20),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 30),
                      child: Column(
                        children: [
                          Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.school, size: 45, color: Colors.white)),
                          const SizedBox(height: 20),
                          const Text('Ecole+', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 8),
                          Text('Gestion scolaire intelligente', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                        ],
                      ),
                    ),
                    
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Connexion', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Connectez-vous à votre espace', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                            const SizedBox(height: 28),
                            
                            TextFormField(
                              controller: _emailCtrl,
                              decoration: InputDecoration(
                                labelText: 'Adresse email',
                                hintText: 'exemple@ecole.com',
                                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF10B981)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
                                filled: true, fillColor: Colors.grey[50],
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: !_isPasswordVisible,
                              decoration: InputDecoration(
                                labelText: 'Mot de passe',
                                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF10B981)),
                                suffixIcon: IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility, color: Colors.grey[400], size: 20), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
                                filled: true, fillColor: Colors.grey[50],
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Contactez l\'administration pour réinitialiser votre mot de passe'), backgroundColor: const Color(0xFFF59E0B), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
                                child: const Text('Mot de passe oublié ?', style: TextStyle(color: Color(0xFF10B981), fontSize: 13)),
                              ),
                            ),
                            
                            if (_error.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFEE2E2))),
                                child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20), const SizedBox(width: 10), Expanded(child: Text(_error, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)))]),
                              ),
                            
                            const SizedBox(height: 24),
                            
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (_isLoading || auth.isLoading) ? null : _submit,
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                                child: (_isLoading || auth.isLoading) ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Se connecter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _testSync,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.sync, size: 18, color: Colors.white), SizedBox(width: 8), Text('🧪 TEST SYNCHRONISATION', style: TextStyle(fontSize: 14))]),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _testFirestoreWrite,
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.blue, side: const BorderSide(color: Colors.blue), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.cloud_upload, size: 18), SizedBox(width: 8), Text('📝 TEST FIRESTORE', style: TextStyle(fontSize: 14))]),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Pas encore de compte ?', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                TextButton(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                                  child: const Text('Créer un compte', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Container(
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.info_outline, color: Colors.white, size: 16)), const SizedBox(width: 10), const Text('Comptes de test', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14))]),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10, runSpacing: 10,
                              children: [
                                _buildTestBadge('Enseignant', 'teacher@example.com', 'Prof1', Colors.blue),
                                _buildTestBadge('Étudiant', 'student@example.com', 'student123', Colors.green),
                                _buildTestBadge('Admin', 'admin@example.com', 'admin123', Colors.purple),
                                _buildTestBadge('Super Admin', 'super@example.com', 'super123', Colors.orange),
                                _buildTestBadge('Parent', 'parent1@example.com', 'parent123', Colors.teal),
                                _buildTestBadge('Personnel', 'staff@example.com', 'staff123', Colors.grey),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Text('© 2024 Ecole+ | Tous droits réservés', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestBadge(String role, String email, String password, Color color) {
    return GestureDetector(
      onTap: () => _fillTestAccount(email, password),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.person_outline, size: 12, color: Colors.white), const SizedBox(width: 6), Text(role, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500))]),
      ),
    );
  }
}
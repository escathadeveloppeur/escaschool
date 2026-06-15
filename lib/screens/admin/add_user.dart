// lib/screens/admin/add_user.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../models/user.dart';
import '../../services/db_helper.dart';
import '../../services/school_service.dart';
import '../../providers/auth_provider.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  _AddUserScreenState createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();
  final TextEditingController birthPlaceController = TextEditingController();
  final TextEditingController parentPhoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController positionController = TextEditingController();
  
  String role = 'student';
  String gender = 'Masculin';
  String _selectedCycle = 'primaire';
  bool _isLoading = false;
  bool _sendEmailNotification = true;
  late AnimationController _animationController;
  bool _isLoadingClasses = true; // 🔥 Indicateur de chargement des classes

  final DBHelper db = DBHelper();
  final SchoolService _schoolService = SchoolService();

  final List<String> _genders = ['Masculin', 'Féminin'];
  
  final List<Map<String, dynamic>> _roles = [
    {'value': 'student', 'label': 'Étudiant', 'icon': Icons.school, 'color': const Color(0xFF3B82F6), 'needPersonalInfo': true, 'needClass': true},
    {'value': 'teacher', 'label': 'Enseignant', 'icon': Icons.person, 'color': const Color(0xFF10B981), 'needPersonalInfo': true, 'needClass': false},
    {'value': 'parent', 'label': 'Parent', 'icon': Icons.family_restroom, 'color': const Color(0xFFF59E0B), 'needPersonalInfo': true, 'needClass': false},
    {'value': 'staff', 'label': 'Personnel', 'icon': Icons.work, 'color': const Color(0xFF8B5CF6), 'needPersonalInfo': true, 'needClass': false},
    {'value': 'admin', 'label': 'Administrateur', 'icon': Icons.admin_panel_settings, 'color': const Color(0xFFEF4444), 'needPersonalInfo': false, 'needClass': false},
  ];

  final List<Map<String, dynamic>> _cycles = [
    {'id': 'primaire', 'name': 'Primaire', 'icon': Icons.abc, 'color': const Color(0xFF10B981)},
    {'id': 'secondaire', 'name': 'Secondaire', 'icon': Icons.school, 'color': const Color(0xFF8B5CF6)},
  ];

  // LISTE DES CLASSES
  List<Map<String, dynamic>> _allClasses = [];
  List<Map<String, dynamic>> _filteredClasses = [];
  String? _selectedClassId;
  String? _selectedClassName;
  String? _selectedClassLevel;
  String? _selectedClassYear;
  String? _selectedClassCycle;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animationController.forward();
    
    // 🔥 CHARGER LES CLASSES IMMÉDIATEMENT
    _loadClasses();
  }

  @override
  void dispose() {
    _animationController.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    birthDateController.dispose();
    birthPlaceController.dispose();
    parentPhoneController.dispose();
    addressController.dispose();
    positionController.dispose();
    super.dispose();
  }

  /// 🔥 CHARGER LES CLASSES DIRECTEMENT DEPUIS FIRESTORE
  Future<void> _loadClasses() async {
    setState(() {
      _isLoadingClasses = true;
    });
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      print('🔍 Chargement des classes - schoolId: $schoolId');
      
      if (schoolId == null) {
        print('❌ schoolId est null, impossible de charger les classes');
        setState(() {
          _isLoadingClasses = false;
        });
        return;
      }
      
      // 🔥 REQUÊTE DIRECTE VERS FIRESTORE
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      
      print('📊 Nombre de classes trouvées: ${snapshot.docs.length}');
      
      _allClasses = snapshot.docs.map((doc) {
        final data = doc.data();
        print('   - Classe: ${data['className']} (cycle: ${data['cycleType']})');
        return {
          'id': doc.id,
          'name': data['className'] ?? 'Sans nom',
          'level': data['level'] ?? '',
          'year': data['year'] ?? '',
          'cycleType': data['cycleType'] ?? 'primaire',
          'section': data['section'] ?? '',
          'hasSections': data['hasSections'] ?? false,
        };
      }).toList();
      
      // Filtrer les classes selon le cycle sélectionné
      _filterClassesByCycle();
      
      setState(() {
        _isLoadingClasses = false;
      });
      
      print('✅ ${_allClasses.length} classes chargées');
    } catch (e) {
      print('❌ Erreur chargement classes: $e');
      setState(() {
        _isLoadingClasses = false;
      });
    }
  }
  
  /// FILTRER LES CLASSES PAR CYCLE
  void _filterClassesByCycle() {
    setState(() {
      _filteredClasses = _allClasses.where((classItem) {
        final classCycle = classItem['cycleType'] ?? 'primaire';
        return classCycle == _selectedCycle;
      }).toList();
      _selectedClassId = null;
      _selectedClassName = null;
      _selectedClassLevel = null;
      _selectedClassYear = null;
      _selectedClassCycle = null;
    });
    
    print('📊 Classes filtrées pour $_selectedCycle: ${_filteredClasses.length}');
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;
    
    final selectedRole = _roles.firstWhere((r) => r['value'] == role);
    
    // Vérifier la classe si c'est un étudiant
    if (role == 'student' && _selectedClassId == null) {
      _showSnackBar('Veuillez sélectionner une classe pour l\'étudiant', const Color(0xFFF59E0B));
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = auth.user;
      final schoolId = currentUser?.schoolId;
      final schoolName = currentUser?.schoolName;
      
      // 1. Créer dans Firebase Auth
      final userCredential = await firebase_auth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );
      
      final uid = userCredential.user!.uid;
      
      // 2. Créer dans Firestore (collection 'users')
      final userData = {
        'name': nameController.text.trim(),
        'email': emailController.text.trim().toLowerCase(),
        'role': role,
        'roleLabel': selectedRole['label'],
        'schoolId': schoolId,
        'schoolName': schoolName,
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser?.firestoreId,
        'createdByName': currentUser?.name,
      };
      
      await FirebaseFirestore.instance.collection('users').doc(uid).set(userData);
      
      // 3. Créer dans users_info
      final userInfoData = {
        'userId': uid,
        'fullName': nameController.text.trim(),
        'userEmail': emailController.text.trim().toLowerCase(),
        'role': role,
        'roleLabel': selectedRole['label'],
        'gender': gender,
        'phone': phoneController.text.trim(),
        'birthDate': birthDateController.text.trim(),
        'birthPlace': birthPlaceController.text.trim(),
        'parentPhone': parentPhoneController.text.trim(),
        'address': addressController.text.trim(),
        'position': positionController.text.trim(),
        'className': _selectedClassName,
        'classId': _selectedClassId,
        'classLevel': _selectedClassLevel,
        'classYear': _selectedClassYear,
        'classCycleType': _selectedClassCycle,
        'schoolId': schoolId,
        'schoolName': schoolName,
        'status': 'approved',
        'createdBy': currentUser?.firestoreId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await FirebaseFirestore.instance.collection('users_info').doc(uid).set(userInfoData);
      
      // 4. Si c'est un étudiant, créer dans la collection 'students'
      if (role == 'student') {
        final studentData = {
          'userId': uid,
          'userEmail': emailController.text.trim().toLowerCase(),
          'fullName': nameController.text.trim(),
          'gender': gender,
          'className': _selectedClassName,
          'classFirestoreId': _selectedClassId,
          'classLevel': _selectedClassLevel,
          'classYear': _selectedClassYear,
          'classCycleType': _selectedClassCycle,
          'educationLevel': _selectedClassCycle,
          'birthDate': birthDateController.text.trim(),
          'birthPlace': birthPlaceController.text.trim(),
          'parentPhone': parentPhoneController.text.trim(),
          'address': addressController.text.trim(),
          'documentsVerified': false,
          'status': 'active',
          'schoolId': schoolId,
          'schoolName': schoolName,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': currentUser?.firestoreId,
        };
        
        await FirebaseFirestore.instance.collection('students').add(studentData);
      }
      
      // 5. Sauvegarder localement dans Hive
      await db.insertUser({
        'name': nameController.text.trim(),
        'email': emailController.text.trim().toLowerCase(),
        'password': passwordController.text.trim(),
        'role': role,
        'schoolId': schoolId,
        'schoolName': schoolName,
        'firestoreId': uid,
        'status': 'approved',
      });
      
      _showSnackBar('✅ ${selectedRole['label']} créé avec succès', Colors.green);
      Navigator.pop(context, true);
      
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showSnackBar('❌ Cet email est déjà utilisé', Colors.red);
      } else {
        _showSnackBar('❌ Erreur: ${e.message}', Colors.red);
      }
    } catch (e) {
      print('❌ Erreur création: $e');
      _showSnackBar('❌ Erreur: $e', Colors.red);
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedRole = _roles.firstWhere((r) => r['value'] == role);
    final needPersonalInfo = selectedRole['needPersonalInfo'] as bool;
    final needClass = selectedRole['needClass'] as bool;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Ajouter un utilisateur',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF10B981)),
            onPressed: _loadClasses,
            tooltip: 'Actualiser les classes',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF10B981)),
            onPressed: () {
              _showHelpDialog();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: FadeTransition(
          opacity: _animationController,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1: Informations du compte
                    _buildSectionTitle('Informations du compte', Icons.account_circle, const Color(0xFF8B5CF6)),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom complet *',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Nom requis' : null,
                    ),
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Email requis';
                        if (!value.contains('@')) return 'Email invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe *',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Mot de passe requis';
                        if (value.length < 6) return 'Minimum 6 caractères';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Rôle
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(
                        labelText: 'Rôle *',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      ),
                      items: _roles.map<DropdownMenuItem<String>>((r) {
                        return DropdownMenuItem<String>(
                          value: r['value'] as String? ?? '',
                          child: Row(
                            children: [
                              Icon(r['icon'] as IconData, size: 20, color: r['color'] as Color),
                              const SizedBox(width: 10),
                              Text(r['label'] as String),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => role = value!),
                    ),
                    const SizedBox(height: 12),
                    
                    // SECTION 2: Cycle et Classe (uniquement pour étudiants)
                    if (needClass) ...[
                      const SizedBox(height: 8),
                      _buildSectionTitle('Niveau d\'études', Icons.school, const Color(0xFF8B5CF6)),
                      const SizedBox(height: 12),
                      
                      // Sélecteur de cycle (Primaire/Secondaire)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: _cycles.map((cycle) {
                            final isSelected = _selectedCycle == cycle['id'];
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCycle = cycle['id'];
                                    _filterClassesByCycle();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isSelected ? cycle['color'] : Colors.transparent,
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(cycle['icon'], color: isSelected ? Colors.white : cycle['color'], size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        cycle['name'],
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : cycle['color'],
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // 🔥 AFFICHAGE DU CHARGEMENT OU DE LA LISTE DES CLASSES
                      if (_isLoadingClasses)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_filteredClasses.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.warning, size: 32, color: Color(0xFFF59E0B)),
                              const SizedBox(height: 8),
                              Text(
                                _allClasses.isEmpty
                                    ? 'Aucune classe disponible.\nVeuillez d\'abord créer des classes.'
                                    : 'Aucune classe disponible pour le niveau $_selectedCycle.\nVeuillez changer de niveau.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Color(0xFFF59E0B)),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _loadClasses,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Actualiser'),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedClassId,
                          hint: const Text('Sélectionner une classe *'),
                          decoration: const InputDecoration(
                            labelText: 'Classe',
                            prefixIcon: Icon(Icons.class_, color: Color(0xFF10B981)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                          ),
                          items: _filteredClasses.map((c) {
                            return DropdownMenuItem<String>(
                              value: c['id'] as String,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                                  Text('${c['level']} • ${c['year']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            final selected = _filteredClasses.firstWhere((c) => c['id'] == value);
                            setState(() {
                              _selectedClassId = value;
                              _selectedClassName = selected['name'];
                              _selectedClassLevel = selected['level'];
                              _selectedClassYear = selected['year'];
                              _selectedClassCycle = selected['cycleType'];
                            });
                          },
                          validator: (value) => value == null ? 'Classe requise' : null,
                        ),
                    ],
                    
                    // SECTION 3: Informations personnelles
                    if (needPersonalInfo) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle('Informations personnelles', Icons.person, const Color(0xFF3B82F6)),
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        value: gender,
                        decoration: const InputDecoration(
                          labelText: 'Sexe *',
                          prefixIcon: Icon(Icons.wc),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        ),
                        items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (value) => setState(() => gender = value!),
                        validator: (value) => value == null ? 'Sexe requis' : null,
                      ),
                      const SizedBox(height: 12),
                      
                      TextFormField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone',
                          prefixIcon: Icon(Icons.phone),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      
                      TextFormField(
                        controller: birthDateController,
                        decoration: const InputDecoration(
                          labelText: 'Date de naissance',
                          hintText: 'JJ/MM/AAAA',
                          prefixIcon: Icon(Icons.calendar_today),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      TextFormField(
                        controller: birthPlaceController,
                        decoration: const InputDecoration(
                          labelText: 'Lieu de naissance',
                          prefixIcon: Icon(Icons.location_city),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      TextFormField(
                        controller: parentPhoneController,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone parent (pour étudiants)',
                          prefixIcon: Icon(Icons.people),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      
                      TextFormField(
                        controller: addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Adresse',
                          prefixIcon: Icon(Icons.home),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                        ),
                      ),
                    ],
                    
                    // Poste pour le personnel
                    if (role == 'staff') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: positionController,
                        decoration: const InputDecoration(
                          labelText: 'Poste *',
                          prefixIcon: Icon(Icons.work),
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                          hintText: 'Secrétaire, Comptable, Bibliothécaire...',
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Poste requis' : null,
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Option d'envoi d'email
                    SwitchListTile(
                      value: _sendEmailNotification,
                      onChanged: (value) => setState(() => _sendEmailNotification = value),
                      title: const Text('Envoyer une notification par email'),
                      subtitle: const Text('L\'utilisateur recevra ses identifiants par email'),
                      activeColor: const Color(0xFF10B981),
                      contentPadding: EdgeInsets.zero,
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
                            onPressed: _isLoading ? null : _createUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                                : const Text('Créer le compte'),
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Création d\'utilisateur',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lors de la création d\'un utilisateur :',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text('• Les informations sont sauvegardées dans Firebase et localement'),
            const Text('• Un email de notification peut être envoyé'),
            const Text('• Les étudiants doivent être assignés à une classe'),
            const Text('• Les comptes sont automatiquement validés'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Les identifiants créés sont immédiatement utilisables.',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
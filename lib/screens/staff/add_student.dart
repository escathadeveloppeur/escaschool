// lib/screens/staff/add_student.dart

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/qr_service.dart';
import '../../models/student_model.dart';

class AddStudentScreen extends StatefulWidget {
  final Map<String, dynamic>? student;
  final String? firestoreId;
  const AddStudentScreen({super.key, this.student, this.firestoreId});

  @override
  _AddStudentScreenState createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController fullNameController;
  late TextEditingController birthDateController;
  late TextEditingController birthPlaceController;
  late TextEditingController fatherNameController;
  late TextEditingController motherNameController;
  late TextEditingController parentPhoneController;
  late TextEditingController addressController;
  
  List<Map<String, dynamic>> _availableStudentAccounts = [];
  List<Map<String, dynamic>> _availableParentAccounts = [];
  List<Map<String, dynamic>> _availableClasses = [];
  Map<String, dynamic>? _selectedStudentAccount;
  Map<String, dynamic>? _selectedParentAccount;
  Map<String, dynamic>? _selectedClass;
  String _selectedRelation = 'Père';
  
  bool documentsVerified = false;
  String? _generatedQRData;
  bool _isLoading = false;
  bool _loadingAccounts = true;

  final List<String> _relations = ['Père', 'Mère', 'Tuteur', 'Grand-parent', 'Oncle/Tante', 'Autre'];

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    fullNameController = TextEditingController(text: s?['fullName'] ?? '');
    birthDateController = TextEditingController(text: s?['birthDate'] ?? '');
    birthPlaceController = TextEditingController(text: s?['birthPlace'] ?? '');
    fatherNameController = TextEditingController(text: s?['fatherName'] ?? '');
    motherNameController = TextEditingController(text: s?['motherName'] ?? '');
    parentPhoneController = TextEditingController(text: s?['parentPhone'] ?? '');
    addressController = TextEditingController(text: s?['address'] ?? '');
    documentsVerified = s?['documentsVerified'] ?? false;
    
    _loadAvailableAccounts();
    _loadAvailableClasses();
  }

  @override
  void dispose() {
    fullNameController.dispose();
    birthDateController.dispose();
    birthPlaceController.dispose();
    fatherNameController.dispose();
    motherNameController.dispose();
    parentPhoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les comptes disponibles (élèves et parents)
  Future<void> _loadAvailableAccounts() async {
    setState(() => _loadingAccounts = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      // 1. Charger les comptes étudiants existants (rôle 'student')
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();
      
      // Récupérer les étudiants déjà associés
      final existingStudentsSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .get();
      final existingStudentUserIds = existingStudentsSnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['userId'])
          .where((id) => id != null)
          .toList();
      
      _availableStudentAccounts = [];
      for (var doc in studentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (!existingStudentUserIds.contains(doc.id)) {
          _availableStudentAccounts.add({
            'userId': doc.id,
            'email': data['email'] ?? '',
            'name': data['name'] ?? '',
          });
        }
      }
      
      // 2. Charger les comptes parents existants (rôle 'parent')
      final parentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'parent')
          .get();
      
      _availableParentAccounts = [];
      for (var doc in parentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        _availableParentAccounts.add({
          'userId': doc.id,
          'email': data['email'] ?? '',
          'name': data['name'] ?? '',
        });
      }
      
      // Si en mode édition, pré-sélectionner les comptes
      if (widget.student != null) {
        _selectedStudentAccount = _availableStudentAccounts.firstWhere(
          (a) => a['userId'] == widget.student!['userId'],
          orElse: () => {},
        );
        _selectedParentAccount = _availableParentAccounts.firstWhere(
          (a) => a['userId'] == widget.student!['parentUserId'],
          orElse: () => {},
        );
        _selectedRelation = widget.student!['parentRelation'] ?? 'Père';
      }
      
      print('✅ ${_availableStudentAccounts.length} comptes étudiants disponibles');
      print('✅ ${_availableParentAccounts.length} comptes parents disponibles');
    } catch (e) {
      print('❌ Erreur chargement comptes: $e');
    } finally {
      setState(() => _loadingAccounts = false);
    }
  }

  /// 🔥 Charger les classes de l'école depuis Firestore
  Future<void> _loadAvailableClasses() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      Query query = FirebaseFirestore.instance.collection('classes');
      if (schoolId != null && !auth.isSuperAdmin) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.get();
      
      _availableClasses = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'className': data['className'] ?? '',
          'level': data['level'] ?? '',
          'year': data['year'] ?? '',
        };
      }).toList();
      
      // Si en mode édition, pré-sélectionner la classe
      if (widget.student != null && widget.student!['className'] != null) {
        _selectedClass = _availableClasses.firstWhere(
          (c) => c['className'] == widget.student!['className'],
          orElse: () => {},
        );
      }
      
      print('✅ ${_availableClasses.length} classes disponibles');
    } catch (e) {
      print('❌ Erreur chargement classes: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

  /// 🔥 Sauvegarder directement dans Firestore avec liaison des comptes
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar("Veuillez remplir tous les champs obligatoires", const Color(0xFFF59E0B));
      return;
    }
    
    if (_selectedStudentAccount == null) {
      _showSnackBar("Veuillez sélectionner un compte étudiant", const Color(0xFFF59E0B));
      return;
    }
    
    if (_selectedClass == null) {
      _showSnackBar("Veuillez sélectionner une classe", const Color(0xFFF59E0B));
      return;
    }
    
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;

    final studentData = {
      'userId': _selectedStudentAccount!['userId'],
      'userEmail': _selectedStudentAccount!['email'],
      'fullName': fullNameController.text.trim(),
      'className': _selectedClass!['className'],
      'classFirestoreId': _selectedClass!['firestoreId'],
      'classLevel': _selectedClass!['level'],
      'classYear': _selectedClass!['year'],
      'birthDate': birthDateController.text.trim(),
      'birthPlace': birthPlaceController.text.trim(),
      'fatherName': fatherNameController.text.trim(),
      'motherName': motherNameController.text.trim(),
      'parentPhone': parentPhoneController.text.trim(),
      'address': addressController.text.trim(),
      'documentsVerified': documentsVerified,
      'schoolId': schoolId,
      'parentUserId': _selectedParentAccount?['userId'],
      'parentEmail': _selectedParentAccount?['email'],
      'parentRelation': _selectedRelation,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.student == null) {
        final docRef = await FirebaseFirestore.instance.collection('students').add(studentData);
        
        // Créer le lien parent-enfant si un parent est sélectionné
        if (_selectedParentAccount != null) {
          await FirebaseFirestore.instance.collection('parent_student_links').add({
            'parentUserId': _selectedParentAccount!['userId'],
            'parentEmail': _selectedParentAccount!['email'],
            'studentId': docRef.id,
            'studentName': fullNameController.text.trim(),
            'relation': _selectedRelation,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        
        _generatedQRData = QRService.generateStudentQR(
          StudentModel(
            fullName: fullNameController.text.trim(),
            className: _selectedClass!['className'],
            birthDate: birthDateController.text.trim(),
            birthPlace: birthPlaceController.text.trim(),
            fatherName: fatherNameController.text.trim(),
            motherName: motherNameController.text.trim(),
            parentPhone: parentPhoneController.text.trim(),
            address: addressController.text.trim(),
          documentsVerified: documentsVerified,
            schoolId: schoolId ?? 0,
          )
        );
        
        _showSnackBar("Étudiant ajouté avec succès", const Color(0xFF10B981));
      } else {
        if (widget.firestoreId != null) {
          await FirebaseFirestore.instance
              .collection('students')
              .doc(widget.firestoreId)
              .update(studentData);
          _showSnackBar("Étudiant modifié avec succès", const Color(0xFF3B82F6));
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _showSnackBar("Erreur: $e", const Color(0xFFEF4444));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.student == null ? "Ajouter un étudiant" : "Modifier l'étudiant", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
      ),
      body: _loadingAccounts
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Section sélection du compte étudiant
                    _buildSection("Compte utilisateur", Icons.account_circle, const Color(0xFF8B5CF6), [
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedStudentAccount,
                        hint: const Text('Sélectionner un compte étudiant *'),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          prefixIcon: const Icon(Icons.school, color: Color(0xFF8B5CF6)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _availableStudentAccounts.map((account) {
                          return DropdownMenuItem(
                            value: account,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(account['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text(account['email'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStudentAccount = value;
                            if (value != null && fullNameController.text.isEmpty) {
                              fullNameController.text = value['name'];
                            }
                          });
                        },
                        validator: (value) => value == null ? 'Compte étudiant requis' : null,
                      ),
                      if (_availableStudentAccounts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning, size: 16, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Aucun compte étudiant disponible. Les étudiants doivent d'abord s'inscrire via l'application.",
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ]),
                    
                    const SizedBox(height: 16),
                    
                    // Section sélection de la classe (Dropdown au lieu de champ manuel)
                    _buildSection("Informations scolaires", Icons.school, const Color(0xFF10B981), [
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedClass,
                        hint: const Text('Sélectionner une classe *'),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          prefixIcon: const Icon(Icons.class_, color: Color(0xFF10B981)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _availableClasses.map((classItem) {
                          return DropdownMenuItem(
                            value: classItem,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(classItem['className'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text('${classItem['level']} • ${classItem['year']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedClass = value;
                          });
                        },
                        validator: (value) => value == null ? 'Classe requise' : null,
                      ),
                      if (_availableClasses.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning, size: 16, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Aucune classe disponible. Veuillez d'abord créer des classes.",
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ]),
                    
                    const SizedBox(height: 16),
                    
                    _buildSection("Informations personnelles", Icons.person, const Color(0xFF3B82F6), [
                      TextFormField(
                        controller: fullNameController,
                        decoration: const InputDecoration(labelText: "Nom complet *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                        validator: (v) => v!.isEmpty ? "Nom requis" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: birthDateController,
                        decoration: const InputDecoration(labelText: "Date de naissance", border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today), hintText: "JJ/MM/AAAA"),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: birthPlaceController,
                        decoration: const InputDecoration(labelText: "Lieu de naissance", border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_city)),
                      ),
                    ]),
                    
                    const SizedBox(height: 16),
                    
                    // Section liaison parent (optionnel)
                    _buildSection("Lier un parent (Optionnel)", Icons.family_restroom, const Color(0xFF14B8A6), [
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedParentAccount,
                        hint: const Text('Sélectionner un compte parent'),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          prefixIcon: const Icon(Icons.family_restroom, color: Color(0xFF14B8A6)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Aucun parent'),
                          ),
                          ..._availableParentAccounts.map((account) {
                            return DropdownMenuItem(
                              value: account,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(account['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                  Text(account['email'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedParentAccount = value;
                          });
                        },
                      ),
                      
                      if (_selectedParentAccount != null) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedRelation,
                          decoration: InputDecoration(
                            labelText: "Relation",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            prefixIcon: const Icon(Icons.people, color: Color(0xFF14B8A6)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _relations.map((relation) {
                            return DropdownMenuItem(value: relation, child: Text(relation));
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedRelation = value!),
                        ),
                      ],
                    ]),
                    
                    const SizedBox(height: 16),
                    
                    _buildSection("Informations familiales", Icons.home, const Color(0xFFF59E0B), [
                      TextFormField(
                        controller: fatherNameController,
                        decoration: const InputDecoration(labelText: "Nom du père", border: OutlineInputBorder(), prefixIcon: Icon(Icons.man)),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: motherNameController,
                        decoration: const InputDecoration(labelText: "Nom de la mère", border: OutlineInputBorder(), prefixIcon: Icon(Icons.woman)),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: parentPhoneController,
                        decoration: const InputDecoration(labelText: "Téléphone du responsable", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressController,
                        decoration: const InputDecoration(labelText: "Adresse", border: OutlineInputBorder(), prefixIcon: Icon(Icons.home)),
                        maxLines: 2,
                      ),
                    ]),
                    
                    const SizedBox(height: 16),
                    
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: SwitchListTile(
                        title: const Text("Documents vérifiés", style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(documentsVerified ? "Les documents ont été vérifiés" : "En attente de vérification"),
                        value: documentsVerified,
                        onChanged: (v) => setState(() => documentsVerified = v),
                        secondary: Icon(documentsVerified ? Icons.verified : Icons.pending, color: documentsVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    if (_generatedQRData != null)
                      Card(
                        color: const Color(0xFF3B82F6).withOpacity(0.05),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.qr_code, color: Color(0xFF3B82F6)),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('QR Code de l\'élève', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Center(child: QrImageView(data: _generatedQRData!, version: QrVersions.auto, size: 150)),
                              const SizedBox(height: 12),
                              const Text('Scannez ce QR code pour valider la présence', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showFullScreenQR(),
                                      icon: const Icon(Icons.fullscreen),
                                      label: const Text('Agrandir'),
                                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => Navigator.pop(context, true),
                                      icon: const Icon(Icons.done),
                                      label: const Text('Terminer'),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: _isLoading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(widget.student == null ? "Ajouter l'étudiant" : "Modifier l'étudiant", style: const TextStyle(fontSize: 16)),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  void _showFullScreenQR() {
    if (_generatedQRData == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(fullNameController.text.trim(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              QrImageView(data: _generatedQRData!, version: QrVersions.auto, size: 250),
              const SizedBox(height: 16),
              const Text('QR Code - Présence', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color, List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
// lib/screens/admin/add_student_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
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
  List<Map<String, dynamic>> _allClasses = [];
  List<Map<String, dynamic>> _filteredClasses = [];
  List<Map<String, dynamic>> _availableSections = [];
  Map<String, dynamic>? _selectedStudentAccount;
  Map<String, dynamic>? _selectedParentAccount;
  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSection;
  String _selectedRelation = 'Père';
  String _selectedGender = 'Masculin';
  String _selectedCycle = 'primaire';
  
  bool documentsVerified = false;
  String? _generatedQRData;
  bool _isLoading = false;
  bool _loadingAccounts = true;

  final List<String> _relations = ['Père', 'Mère', 'Tuteur', 'Grand-parent', 'Oncle/Tante', 'Autre'];
  final List<String> _genders = ['Masculin', 'Féminin'];
  
  final List<Map<String, dynamic>> _cycles = [
    {'id': 'primaire', 'name': 'Primaire', 'icon': Icons.abc, 'color': const Color(0xFF10B981)},
    {'id': 'secondaire', 'name': 'Secondaire', 'icon': Icons.school, 'color': const Color(0xFF8B5CF6)},
  ];

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
    _selectedGender = s?['gender'] ?? 'Masculin';
    _selectedCycle = s?['classCycleType'] ?? s?['educationLevel'] ?? 'primaire';
    
    _loadAvailableAccounts();
    _loadAllClasses();
    _loadAvailableSections();
    
    if (widget.student != null && widget.student!['className'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _filterClassesByCycleAndSection();
        if (widget.student!['sectionId'] != null) {
          _selectedSection = _availableSections.firstWhere(
            (s) => s['id'] == widget.student!['sectionId'],
            orElse: () => {},
          );
        }
        _selectedClass = _filteredClasses.firstWhere(
          (c) => c['className'] == widget.student!['className'],
          orElse: () => {},
        );
        setState(() {});
      });
    }
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

  Future<void> _loadAvailableAccounts() async {
    setState(() => _loadingAccounts = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();
      
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

  Future<void> _loadAllClasses() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      
      _allClasses = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'className': data['className'] ?? '',
          'level': data['level'] ?? '',
          'year': data['year'] ?? '',
          'cycleType': data['cycleType'] ?? 'primaire',
          'section': data['section'] ?? '',
          'sectionId': data['sectionId'] ?? '',
        };
      }).toList();
      
      _filterClassesByCycleAndSection();
      
      print('✅ ${_allClasses.length} classes disponibles');
    } catch (e) {
      print('❌ Erreur chargement classes: $e');
    }
  }
  
  /// 🔥 Filtrer les classes selon le cycle ET la section sélectionnée
  void _filterClassesByCycleAndSection() {
    setState(() {
      _filteredClasses = _allClasses.where((classItem) {
        final classCycle = classItem['cycleType'] ?? 'primaire';
        
        // Pour le primaire : pas de section
        if (classCycle == 'primaire') {
          return classCycle == _selectedCycle;
        }
        
        // Pour le secondaire : filtrer par section si une section est sélectionnée
        if (classCycle == 'secondaire') {
          if (_selectedSection == null) {
            return false;
          }
          return classCycle == _selectedCycle && classItem['section'] == _selectedSection!['name'];
        }
        
        return false;
      }).toList();
      
      _selectedClass = null;
    });
  }
  
  /// 🔥 Mettre à jour les classes quand la section change
  void _onSectionChanged(Map<String, dynamic>? section) {
    setState(() {
      _selectedSection = section;
      _filterClassesByCycleAndSection();
    });
  }

  Future<void> _loadAvailableSections() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      if (schoolId == null) return;
      
      final snapshot = await FirebaseFirestore.instance
          .collection('sections')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      
      _availableSections = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'description': data['description'] ?? '',
          'subjects': data['subjects'] ?? [],
        };
      }).toList();
      
      print('✅ ${_availableSections.length} sections disponibles');
    } catch (e) {
      print('❌ Erreur chargement sections: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

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
      'gender': _selectedGender,
      'className': _selectedClass!['className'],
      'classFirestoreId': _selectedClass!['firestoreId'],
      'classLevel': _selectedClass!['level'],
      'classYear': _selectedClass!['year'],
      'classCycleType': _selectedClass!['cycleType'],
      'educationLevel': _selectedClass!['cycleType'],
      'sectionId': _selectedSection?['id'],
      'sectionName': _selectedSection?['name'],
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
        
        final qrData = json.encode({
          'type': 'student_attendance',
          'studentId': docRef.id,
          'studentName': fullNameController.text.trim(),
          'className': _selectedClass!['className'],
          'classCycleType': _selectedClass!['cycleType'],
          'sectionName': _selectedSection?['name'],
          'gender': _selectedGender,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        
        setState(() {
          _generatedQRData = qrData;
        });
        
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
    final isSecondary = _selectedCycle == 'secondaire';
    
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
                    // SECTION SÉLECTION DU CYCLE
                    _buildSection("Niveau d'études", Icons.school, const Color(0xFF8B5CF6), [
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
                                    _selectedSection = null;
                                    _filterClassesByCycleAndSection();
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
                    ]),
                    
                    const SizedBox(height: 16),
                    
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
                    
                    // Section sélection de la SECTION (pour secondaire)
                    if (isSecondary) ...[
                      _buildSection("Section", Icons.school, const Color(0xFF8B5CF6), [
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedSection,
                          hint: const Text('Sélectionner une section *'),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            prefixIcon: const Icon(Icons.school, color: Color(0xFF8B5CF6)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _availableSections.map((section) {
                            return DropdownMenuItem(
                              value: section,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(section['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                  if (section['description'] != null && section['description'].isNotEmpty)
                                    Text(section['description'], style: TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            _onSectionChanged(value);
                          },
                          validator: (value) => isSecondary && value == null ? 'Section requise' : null,
                        ),
                      ]),
                      const SizedBox(height: 16),
                    ],
                    
                    // Section sélection de la CLASSE (filtrée par section)
                    _buildSection("Classe", Icons.class_, const Color(0xFF10B981), [
                      if (isSecondary && _selectedSection == null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info, size: 16, color: Color(0xFFF59E0B)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Veuillez d'abord sélectionner une section",
                                  style: TextStyle(color: Color(0xFFF59E0B), fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_filteredClasses.isEmpty && isSecondary && _selectedSection != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning, size: 16, color: Color(0xFFF59E0B)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Aucune classe disponible pour cette section",
                                  style: TextStyle(color: Color(0xFFF59E0B), fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: _selectedClass,
                          hint: Text(_filteredClasses.isEmpty 
                              ? 'Aucune classe disponible' 
                              : 'Sélectionner une classe *'),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            prefixIcon: const Icon(Icons.class_, color: Color(0xFF10B981)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _filteredClasses.map((classItem) {
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
                          onChanged: _filteredClasses.isEmpty ? null : (value) {
                            setState(() {
                              _selectedClass = value;
                            });
                          },
                          validator: (value) => value == null ? 'Classe requise' : null,
                        ),
                      
                      if (_allClasses.isEmpty)
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
                    
                    // Section informations personnelles
                    _buildSection("Informations personnelles", Icons.person, const Color(0xFF3B82F6), [
                      TextFormField(
                        controller: fullNameController,
                        decoration: const InputDecoration(labelText: "Nom complet *", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                        validator: (v) => v!.isEmpty ? "Nom requis" : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: InputDecoration(
                          labelText: "Sexe *",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          prefixIcon: const Icon(Icons.wc, color: Color(0xFF3B82F6)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _genders.map((gender) {
                          return DropdownMenuItem(value: gender, child: Text(gender));
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedGender = value!),
                        validator: (v) => v == null ? 'Sexe requis' : null,
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
                    
                    // Section liaison parent
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
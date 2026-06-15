// lib/screens/staff/add_document.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../providers/auth_provider.dart';

class AddDocumentScreen extends StatefulWidget {
  final Map<String, dynamic>? document;
  final String? firestoreId;
  const AddDocumentScreen({super.key, this.document, this.firestoreId});

  @override
  _AddDocumentScreenState createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final DBHelper db = DBHelper();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> allStudents = [];
  List<Map<String, dynamic>> filteredStudents = [];
  List<Map<String, dynamic>> classes = [];
  Map<String, dynamic>? selectedStudent;
  Map<String, dynamic>? selectedClass;
  String docType = "Bulletin scolaire";
  bool isValidated = false;
  bool _loading = true;
  String _selectedCycle = 'all'; // 'all', 'primaire', 'secondaire'

  final List<Map<String, dynamic>> _cycles = [
    {'id': 'all', 'name': 'Tous', 'icon': Icons.all_inclusive, 'color': Color(0xFF6366F1)},
    {'id': 'primaire', 'name': 'Primaire', 'icon': Icons.abc, 'color': Color(0xFF10B981)},
    {'id': 'secondaire', 'name': 'Secondaire', 'icon': Icons.school, 'color': Color(0xFF8B5CF6)},
  ];

  @override
  void initState() {
    super.initState();
    _loadDataFromFirestore();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// 🔥 Charger les étudiants et classes depuis Firestore
  Future<void> _loadDataFromFirestore() async {
    setState(() => _loading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      // 1. Charger les étudiants
      Query studentQuery = FirebaseFirestore.instance.collection('students');
      if (schoolId != null && !auth.isSuperAdmin) {
        studentQuery = studentQuery.where('schoolId', isEqualTo: schoolId);
      }
      
      final studentsSnapshot = await studentQuery.get();
      allStudents = studentsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'fullName': data['fullName'] ?? '',
          'className': data['className'] ?? '',
          'classCycleType': data['classCycleType'] ?? 'primaire',
          'sectionName': data['sectionName'],
          'schoolId': data['schoolId'],
        };
      }).toList();
      
      // Filtrer les étudiants par cycle
      _filterStudentsByCycle();
      
      // 2. Charger les classes disponibles
      Query classQuery = FirebaseFirestore.instance.collection('classes');
      if (schoolId != null && !auth.isSuperAdmin) {
        classQuery = classQuery.where('schoolId', isEqualTo: schoolId);
      }
      
      final classesSnapshot = await classQuery.get();
      classes = classesSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'className': data['className'] ?? '',
          'level': data['level'] ?? '',
          'year': data['year'] ?? '',
          'cycleType': data['cycleType'] ?? 'primaire',
        };
      }).toList();
      
      // 3. Si en mode édition, pré-sélectionner
      if (widget.document != null) {
        selectedStudent = allStudents.firstWhere(
          (s) => s['fullName'] == widget.document!['fullName'],
          orElse: () => {},
        );
        selectedClass = classes.firstWhere(
          (c) => c['className'] == widget.document!['className'],
          orElse: () => {},
        );
        docType = widget.document!['docType'] ?? "Bulletin scolaire";
        isValidated = widget.document!['isValidated'] ?? false;
        
        // Définir le cycle en fonction de l'étudiant
        if (selectedStudent != null) {
          _selectedCycle = selectedStudent!['classCycleType'] ?? 'all';
        }
      }
      
      print('✅ ${allStudents.length} étudiants chargés');
      print('✅ ${classes.length} classes chargées');
    } catch (e) {
      print('❌ Erreur chargement: $e');
      _showSnackBar("Erreur de chargement", const Color(0xFFEF4444));
    } finally {
      setState(() => _loading = false);
    }
  }

  void _filterStudentsByCycle() {
    setState(() {
      if (_selectedCycle == 'all') {
        filteredStudents = List.from(allStudents);
      } else {
        filteredStudents = allStudents.where((student) {
          final studentCycle = student['classCycleType'] ?? 'primaire';
          return studentCycle == _selectedCycle;
        }).toList();
      }
      
      // Réinitialiser la sélection si l'étudiant n'est plus dans la liste filtrée
      if (selectedStudent != null && 
          !filteredStudents.any((s) => s['firestoreId'] == selectedStudent!['firestoreId'])) {
        selectedStudent = null;
        selectedClass = null;
      }
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  /// 🔥 Sauvegarder directement dans Firestore
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (selectedStudent == null) {
      _showSnackBar("Veuillez sélectionner un étudiant", const Color(0xFFF59E0B));
      return;
    }
    
    if (selectedClass == null) {
      _showSnackBar("Veuillez sélectionner une classe", const Color(0xFFF59E0B));
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;

    final documentData = {
      'studentFirestoreId': selectedStudent!['firestoreId'],
      'fullName': selectedStudent!['fullName'],
      'classFirestoreId': selectedClass!['firestoreId'],
      'className': selectedClass!['className'],
      'classCycleType': selectedStudent!['classCycleType'] ?? 'primaire',
      'sectionName': selectedStudent!['sectionName'],
      'docType': docType,
      'isValidated': isValidated,
      'schoolId': schoolId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.document == null) {
        await FirebaseFirestore.instance.collection('documents').add(documentData);
        _showSnackBar("Document ajouté avec succès", const Color(0xFF10B981));
      } else {
        if (widget.firestoreId != null) {
          await FirebaseFirestore.instance
              .collection('documents')
              .doc(widget.firestoreId)
              .update(documentData);
          _showSnackBar("Document modifié avec succès", const Color(0xFF10B981));
        }
      }
      Navigator.pop(context, true);
    } catch (e) {
      _showSnackBar("Erreur: $e", const Color(0xFFEF4444));
    }
  }

  Widget _buildCycleSelector() {
    return Container(
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
                  _filterStudentsByCycle();
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.document == null ? "Ajouter un document" : "Modifier le document", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white, 
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (auth.currentSchoolId != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16), 
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
                        decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), 
                        child: Row(children: [
                          const Icon(Icons.business, size: 18, color: Color(0xFF3B82F6)), 
                          const SizedBox(width: 8), 
                          Text('École : ${auth.schoolName ?? auth.currentSchoolId}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6)))
                        ]),
                      ),
                    
                    // Sélection de l'étudiant
                    Card(
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
                                  decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.person, color: Color(0xFF3B82F6), size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text("Étudiant", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Sélecteur de cycle
                            _buildCycleSelector(),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<Map<String, dynamic>>(
                              value: selectedStudent,
                              hint: filteredStudents.isEmpty 
                                  ? Text(_selectedCycle == 'all' 
                                      ? "Aucun étudiant disponible" 
                                      : "Aucun étudiant en $_selectedCycle")
                                  : const Text("Choisir un étudiant *"),
                              isExpanded: true,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                prefixIcon: const Icon(Icons.school, color: Color(0xFF3B82F6)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: filteredStudents.map((student) {
                                final isSecondary = student['classCycleType'] == 'secondaire';
                                return DropdownMenuItem(
                                  value: student,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student['fullName'],
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      Row(
                                        children: [
                                          Icon(
                                            isSecondary ? Icons.school : Icons.abc,
                                            size: 12,
                                            color: isSecondary ? Colors.purple : Colors.green,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            student['className'],
                                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                          ),
                                          if (isSecondary && student['sectionName'] != null && student['sectionName'].isNotEmpty) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              ' - ${student['sectionName']}',
                                              style: TextStyle(fontSize: 11, color: Colors.purple[600]),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedStudent = value;
                                  // Auto-sélectionner la classe de l'étudiant si disponible
                                  if (value != null && value['className'] != null) {
                                    selectedClass = classes.firstWhere(
                                      (c) => c['className'] == value['className'],
                                      orElse: () => {},
                                    );
                                  }
                                });
                              },
                              validator: (value) => value == null ? "Étudiant requis" : null,
                            ),
                            if (filteredStudents.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  _selectedCycle == 'all' 
                                      ? "Aucun étudiant disponible"
                                      : "Aucun étudiant en $_selectedCycle",
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Sélection de la classe (pré-remplie automatiquement)
                    Card(
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
                                  decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.class_, color: Color(0xFF10B981), size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text("Classe", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<Map<String, dynamic>>(
                              value: selectedClass,
                              hint: const Text("Choisir une classe *"),
                              isExpanded: true,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                prefixIcon: const Icon(Icons.class_, color: Color(0xFF10B981)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: classes.map((classItem) {
                                final isSecondary = classItem['cycleType'] == 'secondaire';
                                return DropdownMenuItem(
                                  value: classItem,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isSecondary ? Icons.school : Icons.abc,
                                            size: 12,
                                            color: isSecondary ? Colors.purple : Colors.green,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(classItem['className'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                      Text('${classItem['level']} • ${classItem['year']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => selectedClass = value),
                              validator: (value) => value == null ? "Classe requise" : null,
                            ),
                            if (classes.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  "Aucune classe disponible",
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Type de document
                    Card(
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
                                  decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.description, color: Color(0xFF10B981), size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text("Type de document", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: docType,
                              items: const [
                                DropdownMenuItem(value: "Bulletin scolaire", child: Text("Bulletin scolaire")),
                                DropdownMenuItem(value: "Attestation", child: Text("Attestation")),
                                DropdownMenuItem(value: "Certificat de scolarité", child: Text("Certificat de scolarité")),
                                DropdownMenuItem(value: "Pièce d'identité", child: Text("Pièce d'identité")),
                                DropdownMenuItem(value: "Autorisation", child: Text("Autorisation")),
                                DropdownMenuItem(value: "Convocation", child: Text("Convocation")),
                              ],
                              onChanged: (v) => setState(() => docType = v ?? docType), 
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.folder),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Validation du document
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: const Text("Document validé", style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(isValidated ? "Le document a été vérifié et approuvé" : "Document en attente de vérification"),
                        value: isValidated,
                        onChanged: (v) => setState(() => isValidated = v),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isValidated ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isValidated ? Icons.verified : Icons.pending,
                            color: isValidated ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                            child: const Text("Annuler"),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              widget.document == null ? "Ajouter" : "Modifier",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
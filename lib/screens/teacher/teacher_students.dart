// lib/screens/teacher/teacher_students_screen.dart
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/db_helper.dart';
import '../../providers/auth_provider.dart';

class TeacherStudentsScreen extends StatefulWidget {
  final List<String> assignedClasses;
  
  const TeacherStudentsScreen({
    super.key,
    required this.assignedClasses,
  });

  @override
  _TeacherStudentsScreenState createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> {
  final DBHelper db = DBHelper();
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> filteredStudents = [];
  String selectedClass = '';
  String searchQuery = '';
  bool loading = true;
  bool isSyncing = false;
  
  @override
  void initState() {
    super.initState();
    print('\n========== TEACHER STUDENTS SCREEN ==========');
    print('📚 Classes assignées: ${widget.assignedClasses}');
    
    // Initialiser selectedClass uniquement si des classes sont disponibles
    if (widget.assignedClasses.isNotEmpty) {
      selectedClass = widget.assignedClasses.first;
      print('✅ Classe sélectionnée par défaut: $selectedClass');
    } else {
      selectedClass = '';
      print('⚠️ Aucune classe assignée, sélection vide');
    }
    
    _loadStudentsFromFirestore();
  }
  
  /// 🔥 Charger les étudiants depuis Firestore
  Future<void> _loadStudentsFromFirestore() async {
    setState(() => loading = true);
    
    print('\n🔍 [1/2] Chargement des étudiants depuis Firestore...');
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      print('   → School ID: $schoolId');
      print('   → Super Admin: ${auth.isSuperAdmin}');
      print('   → Classes autorisées: ${widget.assignedClasses}');
      
      Query query = FirebaseFirestore.instance.collection('students');
      if (schoolId != null && !auth.isSuperAdmin) {
        query = query.where('schoolId', isEqualTo: schoolId);
        print('   → Filtre appliqué: schoolId == $schoolId');
      }
      
      final snapshot = await query.get();
      print('   → Total étudiants dans Firestore: ${snapshot.docs.length}');
      
      final List<Map<String, dynamic>> allStudents = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'fullName': data['fullName'] ?? 'Sans nom',
          'className': data['className'] ?? '',
          'classFirestoreId': data['classFirestoreId'] ?? '',
          'birthDate': data['birthDate'] ?? '',
          'birthPlace': data['birthPlace'] ?? '',
          'fatherName': data['fatherName'] ?? '',
          'motherName': data['motherName'] ?? '',
          'parentPhone': data['parentPhone'] ?? '',
          'address': data['address'] ?? '',
          'documentsVerified': data['documentsVerified'] ?? false,
          'schoolId': data['schoolId'],
        };
      }).toList();
      
      print('\n🔍 [2/2] Filtrage par classes assignées...');
      
      // Filtrer les étudiants par classes assignées
      setState(() {
        students = allStudents.where((s) {
          final className = s['className'] ?? '';
          final isAssigned = widget.assignedClasses.contains(className);
          if (isAssigned) {
            print('   ✅ Étudiant ${s['fullName']} - Classe: $className');
          }
          return isAssigned;
        }).toList();
        filteredStudents = List.from(students);
      });
      
      print('\n📊 RÉSULTAT: ${students.length} étudiant(s) trouvé(s)');
      print('   Classes: ${widget.assignedClasses}');
      print('=========================================\n');
      
    } catch (e) {
      debugPrint("❌ Erreur chargement élèves: $e");
      _showSnackBar('Erreur de chargement: $e', const Color(0xFFEF4444));
    } finally {
      setState(() => loading = false);
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
  
  void _filterStudents() {
    print('🔍 Filtrage des étudiants: classe="$selectedClass", recherche="$searchQuery"');
    
    setState(() {
      filteredStudents = students.where((s) {
        final matchesClass = selectedClass.isEmpty || s['className'] == selectedClass;
        final matchesSearch = searchQuery.isEmpty ||
            (s['fullName'] as String).toLowerCase().contains(searchQuery.toLowerCase()) ||
            (s['className'] as String).toLowerCase().contains(searchQuery.toLowerCase());
        return matchesClass && matchesSearch;
      }).toList();
    });
    
    print('   → Résultat: ${filteredStudents.length} étudiant(s)');
  }
  
  Future<void> _generateStudentsListPDF() async {
    if (filteredStudents.isEmpty) {
      _showSnackBar('Aucun élève à exporter', const Color(0xFFF59E0B));
      return;
    }
    
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(level: 0, text: 'LISTE DES ÉLÈVES'),
                pw.SizedBox(height: 10),
                pw.Text('Classe: ${selectedClass.isNotEmpty ? selectedClass : "Toutes les classes"}'),
                pw.Text('Date: ${DateTime.now().toLocal().toString().split(' ')[0]}'),
                pw.SizedBox(height: 20),
                
                pw.Table.fromTextArray(
                  context: context,
                  border: pw.TableBorder.all(),
                  headers: ['N°', 'Nom Complet', 'Classe', 'Contact Parent'],
                  data: filteredStudents.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final student = entry.value;
                    return [
                      index.toString(),
                      student['fullName'],
                      student['className'],
                      (student['parentPhone'] as String).isNotEmpty ? student['parentPhone'] : 'Non renseigné',
                    ];
                  }).toList(),
                ),
                
                pw.SizedBox(height: 20),
                pw.Text('Total élèves: ${filteredStudents.length}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            );
          },
        ),
      );
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      print('❌ Erreur PDF: $e');
      _showSnackBar('Erreur lors de la génération du PDF', const Color(0xFFEF4444));
    }
  }
  
  Future<void> _viewStudentDetails(Map<String, dynamic> student) async {
    print('🔍 Affichage détails pour: ${student['fullName']}');
    
    try {
      // Charger les notes depuis Firestore
      final gradesSnapshot = await FirebaseFirestore.instance
          .collection('grades')
          .where('studentName', isEqualTo: student['fullName'])
          .get();
      
      print('   → ${gradesSnapshot.docs.length} note(s) trouvée(s)');
      
      final grades = gradesSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'subject': data['subject'] ?? '',
          'evaluationType': data['evaluationType'] ?? '',
          'score': (data['score'] as num?)?.toDouble() ?? 0.0,
          'maxScore': (data['maxScore'] as num?)?.toDouble() ?? 20.0,
          'date': data['date'] != null ? (data['date'] as Timestamp).toDate() : DateTime.now(),
        };
      }).toList();
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 60,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.blue[100],
                            child: const Icon(Icons.person, size: 30, color: Colors.blue),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student['fullName'],
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                Text("Classe: ${student['className']}"),
                                Text("Contact: ${(student['parentPhone'] as String).isNotEmpty ? student['parentPhone'] : 'Non renseigné'}"),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      const Text(
                        "Informations personnelles",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      
                      _detailRow("Date de naissance", student['birthDate'] ?? 'Non renseignée'),
                      _detailRow("Lieu de naissance", student['birthPlace'] ?? 'Non renseigné'),
                      _detailRow("Adresse", student['address'] ?? 'Non renseignée'),
                      _detailRow("Père", student['fatherName'] ?? 'Non renseigné'),
                      _detailRow("Mère", student['motherName'] ?? 'Non renseignée'),
                      
                      const SizedBox(height: 20),
                      
                      if (grades.isNotEmpty) ...[
                        const Text(
                          "Notes récentes",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            itemCount: grades.length > 5 ? 5 : grades.length,
                            itemBuilder: (context, index) {
                              final grade = grades[index];
                              return ListTile(
                                title: Text(grade['subject']),
                                subtitle: Text("${grade['evaluationType']} - ${grade['date'].toLocal().toString().split(' ')[0]}"),
                                trailing: Text(
                                  "${grade['score']}/${grade['maxScore']}",
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 30),
                      
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _generateStudentReportCard(student, grades);
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.green[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("Générer bulletin individuel"),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      print('❌ Erreur chargement détails: $e');
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    }
  }
  
  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value.isNotEmpty ? value : 'Non renseigné',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _generateStudentReportCard(Map<String, dynamic> student, List<Map<String, dynamic>> grades) async {
    if (grades.isEmpty) {
      _showSnackBar('Aucune note disponible pour cet élève', const Color(0xFFF59E0B));
      return;
    }
    
    try {
      final Map<String, List<Map<String, dynamic>>> gradesBySubject = {};
      
      for (var grade in grades) {
        final subject = grade['subject'] as String;
        if (!gradesBySubject.containsKey(subject)) {
          gradesBySubject[subject] = [];
        }
        gradesBySubject[subject]!.add(grade);
      }
      
      double totalWeighted = 0;
      double totalCoefficient = 0;
      final Map<String, double> subjectAverages = {};
      
      for (var entry in gradesBySubject.entries) {
        double subjectWeighted = 0;
        double subjectCoefficient = 0;
        
        for (var grade in entry.value) {
          final score = grade['score'] as double;
          final maxScore = grade['maxScore'] as double;
          final normalizedScore = (score / maxScore) * 20;
          subjectWeighted += normalizedScore * 1.0;
          subjectCoefficient += 1.0;
        }
        
        final double average = subjectCoefficient > 0 ? subjectWeighted / subjectCoefficient : 0.0;
        subjectAverages[entry.key] = average;
        
        totalWeighted += average * subjectCoefficient;
        totalCoefficient += subjectCoefficient;
      }
      
      final overallAverage = totalCoefficient > 0 ? totalWeighted / totalCoefficient : 0;
      
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(level: 0, text: 'BULLETIN SCOLAIRE'),
                pw.SizedBox(height: 20),
                pw.Text('Élève: ${student['fullName']}'),
                pw.Text('Classe: ${student['className']}'),
                pw.Text('Année scolaire: ${DateTime.now().year}-${DateTime.now().year + 1}'),
                pw.SizedBox(height: 30),
                
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Text('Matière', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Moyenne', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Appréciation', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    ...subjectAverages.entries.map((entry) {
                      return pw.TableRow(
                        children: [
                          pw.Text(entry.key),
                          pw.Text(entry.value.toStringAsFixed(2)),
                          pw.Text(_getAppreciation(entry.value)),
                        ],
                      );
                    }).toList(),
                  ],
                ),
                
                pw.SizedBox(height: 20),
                pw.Text(
                  'Moyenne générale: ${overallAverage.toStringAsFixed(2)}/20',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
                ),
                
                pw.SizedBox(height: 30),
                pw.Text('Observations:'),
                pw.SizedBox(height: 10),
                pw.Text('_________________________________________________________________'),
                pw.SizedBox(height: 10),
                pw.Text('_________________________________________________________________'),
                
                pw.SizedBox(height: 40),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Le Professeur Principal'),
                        pw.SizedBox(height: 5),
                        pw.Text('_________________________'),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Le Directeur'),
                        pw.SizedBox(height: 5),
                        pw.Text('_________________________'),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      print('❌ Erreur génération bulletin: $e');
      _showSnackBar('Erreur lors de la génération du bulletin', const Color(0xFFEF4444));
    }
  }
  
  String _getAppreciation(double average) {
    if (average >= 16) return 'Excellent';
    if (average >= 14) return 'Très bien';
    if (average >= 12) return 'Bien';
    if (average >= 10) return 'Passable';
    return 'Insuffisant';
  }
  
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Mes élèves',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadStudentsFromFirestore,
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey[100],
              ),
              tooltip: 'Actualiser',
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (auth.currentSchoolId != null && !auth.isSuperAdmin)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, size: 18, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    Text(
                      'École : ${auth.schoolName ?? auth.currentSchoolId}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ],
                ),
              ),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedClass.isNotEmpty && widget.assignedClasses.contains(selectedClass) 
                                ? selectedClass 
                                : null,
                            hint: const Text('Toutes les classes'),
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: "Filtrer par classe",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('Toutes les classes'),
                              ),
                              ...widget.assignedClasses.map((classe) {
                                return DropdownMenuItem<String>(
                                  value: classe,
                                  child: Text(classe),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedClass = value ?? '';
                                _filterStudents();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: "Rechercher un élève",
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onChanged: (value) {
                              setState(() {
                                searchQuery = value;
                                _filterStudents();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    if (filteredStudents.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _generateStudentsListPDF,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text("Exporter la liste en PDF"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.red[700],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Message si aucune classe assignée
            if (widget.assignedClasses.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),
                    Icon(Icons.class_, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      "Aucune classe assignée",
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Contactez l'administrateur pour obtenir des classes",
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredStudents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  "Aucun élève trouvé",
                                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  searchQuery.isNotEmpty 
                                      ? "Aucun résultat pour '$searchQuery'"
                                      : "Aucun élève dans cette classe",
                                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredStudents.length,
                            itemBuilder: (context, index) {
                              final student = filteredStudents[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue[100],
                                    child: Text(
                                      (student['fullName'] as String).isNotEmpty 
                                          ? (student['fullName'] as String)[0].toUpperCase() 
                                          : '?',
                                      style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  title: Text(
                                    student['fullName'],
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Classe: ${student['className']}"),
                                      Text("Contact: ${(student['parentPhone'] as String).isNotEmpty ? student['parentPhone'] : 'Non renseigné'}"),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                  onTap: () => _viewStudentDetails(student),
                                ),
                              );
                            },
                          ),
              ),
          ],
        ),
      ),
    );
  }
}
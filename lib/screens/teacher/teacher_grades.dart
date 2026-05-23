// lib/screens/teacher/teacher_grades_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import 'teacher_online_exams.dart';

class TeacherGradesScreen extends StatefulWidget {
  final String teacherName;
  final String professorFirestoreId;
  final List<String> assignedClasses;
  final List<String> assignedSubjects;
  
  const TeacherGradesScreen({
    super.key,
    required this.teacherName,
    required this.professorFirestoreId,
    required this.assignedClasses,
    required this.assignedSubjects,
  });

  @override
  _TeacherGradesScreenState createState() => _TeacherGradesScreenState();
}

class _TeacherGradesScreenState extends State<TeacherGradesScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> grades = [];
  Map<String, List<Map<String, dynamic>>> studentGrades = {};
  
  String selectedClass = '';
  String selectedSubject = '';
  String selectedEvaluation = 'Devoir';
  
  // 🔥 Récupération des matières depuis Firestore (classes collection)
  Map<String, List<Map<String, dynamic>>> _subjectsFromClasses = {};
  List<String> _currentSubjectsForClass = [];
  
  TextEditingController scoreController = TextEditingController();
  TextEditingController maxScoreController = TextEditingController();
  TextEditingController coefficientController = TextEditingController();
  TextEditingController commentController = TextEditingController();
  
  String? _selectedFilePath;
  String? _selectedFileName;
  bool _isUploading = false;
  
  bool _isLoading = true;
  bool _isAddingNote = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║     INITIALISATION TEACHER GRADES SCREEN                   ║');
    print('╚════════════════════════════════════════════════════════════╝\n');
    print('📌 Professeur ID: ${widget.professorFirestoreId}');
    print('📌 Professeur Nom: ${widget.teacherName}');
    print('📌 Classes assignées reçues: ${widget.assignedClasses}');
    print('📌 Matières assignées reçues: ${widget.assignedSubjects}\n');
    
    // Sélectionner la première classe disponible
    if (widget.assignedClasses.isNotEmpty) {
      selectedClass = widget.assignedClasses.first;
      print('✅ Classe sélectionnée par défaut: $selectedClass');
    } else {
      print('⚠️ Aucune classe assignée au professeur!');
    }
    
    _loadDataFromFirestore();
  }

  @override
  void dispose() {
    _animationController.dispose();
    scoreController.dispose();
    maxScoreController.dispose();
    coefficientController.dispose();
    commentController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les données depuis Firestore
  Future<void> _loadDataFromFirestore() async {
    setState(() => _isLoading = true);
    
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║     CHARGEMENT DES DONNÉES - TEACHER GRADES                ║');
    print('╚════════════════════════════════════════════════════════════╝\n');
    print('📌 Professeur ID: ${widget.professorFirestoreId}');
    print('📌 Classe sélectionnée: $selectedClass\n');
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      // ==================== 1. CHARGER LES CLASSES ET LEURS MATIÈRES ====================
      print('🔍 [1/4] Chargement des classes et matières depuis Firestore...');
      print('   → Collection: classes');
      
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .get();
      
      print('   📊 ${classesSnapshot.docs.length} classe(s) trouvée(s)');
      
      // Organiser les matières par classe
      _subjectsFromClasses.clear();
      for (var doc in classesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final className = data['className'] ?? '';
        final subjects = data['subjects'] as List<dynamic>? ?? [];
        
        print('\n   📚 Classe trouvée: $className');
        print('      - ID: ${doc.id}');
        print('      - Matières dans la classe: ${subjects.length}');
        
        if (className.isNotEmpty && subjects.isNotEmpty) {
          _subjectsFromClasses[className] = [];
          for (var subject in subjects) {
            final subjectMap = subject as Map<String, dynamic>;
            final subjectName = subjectMap['name'] ?? '';
            final professorId = subjectMap['professorFirestoreId'] ?? '';
            
            print('         📖 Matière: $subjectName');
            print('            - Professeur assigné ID: $professorId');
            print('            - Professeur actuel ID: ${widget.professorFirestoreId}');
            print('            - Correspond: ${professorId == widget.professorFirestoreId ? "✅ OUI" : "❌ NON"}');
            
            _subjectsFromClasses[className]!.add({
              'name': subjectName,
              'professorFirestoreId': professorId,
              'coefficient': subjectMap['coefficient'] ?? 1.0,
            });
          }
        }
      }
      
      // ==================== 2. FILTRER LES MATIÈRES DU PROFESSEUR ====================
      print('\n🔍 [2/4] Filtrage des matières du professeur...');
      
      if (selectedClass.isNotEmpty && _subjectsFromClasses.containsKey(selectedClass)) {
        final allSubjectsForClass = _subjectsFromClasses[selectedClass]!;
        _currentSubjectsForClass = [];
        
        for (var subject in allSubjectsForClass) {
          final professorId = subject['professorFirestoreId'] ?? '';
          final subjectName = subject['name'] ?? '';
          
          // Vérifier si le professeur est assigné à cette matière
          if (professorId == widget.professorFirestoreId) {
            _currentSubjectsForClass.add(subjectName);
            print('   ✅ Matière autorisée: $subjectName (professeur assigné)');
          } else {
            print('   ⛔ Matière non autorisée: $subjectName (professeur: $professorId)');
          }
        }
        
        print('\n   📊 Total matières autorisées: ${_currentSubjectsForClass.length}');
        
        // Vérifier si la matière sélectionnée existe toujours
        if (_currentSubjectsForClass.isNotEmpty) {
          if (!_currentSubjectsForClass.contains(selectedSubject)) {
            selectedSubject = _currentSubjectsForClass.first;
            print('   ✅ Matière sélectionnée: $selectedSubject');
          }
        } else {
          selectedSubject = '';
          print('   ⚠️ Aucune matière autorisée pour cette classe!');
        }
      } else {
        _currentSubjectsForClass = [];
        selectedSubject = '';
        print('   ⚠️ Aucune matière trouvée pour la classe $selectedClass');
      }
      
      // ==================== 3. CHARGER LES ÉTUDIANTS ====================
      print('\n🔍 [3/4] Chargement des étudiants...');
      
      if (selectedClass.isNotEmpty) {
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('students')
            .where('className', isEqualTo: selectedClass)
            .get();
        
        students = [];
        print('   📊 ${studentsSnapshot.docs.length} étudiant(s) trouvé(s) pour $selectedClass');
        
        for (var doc in studentsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          students.add({
            'firestoreId': doc.id,
            'fullName': data['fullName'] ?? 'Sans nom',
            'className': data['className'] ?? '',
            'parentUserId': data['parentUserId'],
          });
          print('      - ${data['fullName']} (ID: ${doc.id})');
        }
      }
      
      // ==================== 4. CHARGER LES NOTES ====================
      print('\n🔍 [4/4] Chargement des notes...');
      
      if (selectedClass.isNotEmpty && selectedSubject.isNotEmpty) {
        final gradesSnapshot = await FirebaseFirestore.instance
            .collection('grades')
            .where('className', isEqualTo: selectedClass)
            .where('subject', isEqualTo: selectedSubject)
            .get();
        
        grades = [];
        print('   📊 ${gradesSnapshot.docs.length} note(s) trouvée(s) pour $selectedClass - $selectedSubject');
        
        for (var doc in gradesSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          grades.add({
            'id': doc.id,
            'studentFirestoreId': data['studentFirestoreId'] ?? '',
            'studentName': data['studentName'] ?? '',
            'subject': data['subject'] ?? '',
            'evaluationType': data['evaluationType'] ?? '',
            'score': (data['score'] as num?)?.toDouble() ?? 0.0,
            'maxScore': (data['maxScore'] as num?)?.toDouble() ?? 20.0,
            'coefficient': (data['coefficient'] as num?)?.toDouble() ?? 1.0,
            'comments': data['comments'] ?? '',
            'date': data['date'] != null ? (data['date'] as Timestamp).toDate() : DateTime.now(),
          });
        }
        
        // Organiser les notes par étudiant
        studentGrades.clear();
        for (var grade in grades) {
          final studentId = grade['studentFirestoreId'];
          if (!studentGrades.containsKey(studentId)) {
            studentGrades[studentId] = [];
          }
          studentGrades[studentId]!.add(grade);
        }
        
        print('   📊 Notes organisées pour ${studentGrades.length} étudiant(s)');
      }
      
      // ==================== RÉSUMÉ FINAL ====================
      print('\n╔════════════════════════════════════════════════════════════╗');
      print('║                    RÉSUMÉ FINAL                            ║');
      print('╠════════════════════════════════════════════════════════════╣');
      print('║   Classe: $selectedClass');
      print('║   Matières autorisées: ${_currentSubjectsForClass.length}');
      for (var subject in _currentSubjectsForClass) {
        print('║      - $subject');
      }
      print('║   Étudiants: ${students.length}');
      print('║   Notes chargées: ${grades.length}');
      print('╚════════════════════════════════════════════════════════════╝\n');
      
    } catch (e) {
      print('❌❌❌ ERREUR CRITIQUE: $e ❌❌❌');
      _showSnackBar('Erreur de chargement: $e', const Color(0xFFEF4444));
    } finally {
      setState(() => _isLoading = false);
      _animationController.forward(from: 0);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'mp4', 'mov', 'avi'],
      );
      
      if (result != null) {
        PlatformFile file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
          _selectedFilePath = file.path;
        });
        
        _showSnackBar('Fichier sélectionné: ${file.name}', const Color(0xFF10B981));
      }
    } catch (e) {
      print('Erreur sélection fichier: $e');
      _showSnackBar('Erreur lors de la sélection du fichier', const Color(0xFFEF4444));
    }
  }

  Future<void> _pickVideo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.video,
      );
      
      if (result != null) {
        PlatformFile file = result.files.first;
        setState(() {
          _selectedFileName = file.name;
          _selectedFilePath = file.path;
        });
        
        _showSnackBar('Vidéo sélectionnée: ${file.name}', const Color(0xFF10B981));
      }
    } catch (e) {
      print('Erreur sélection vidéo: $e');
      _showSnackBar('Erreur lors de la sélection de la vidéo', const Color(0xFFEF4444));
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFilePath == null) {
      _showSnackBar('Veuillez d\'abord sélectionner un fichier', const Color(0xFFF59E0B));
      return;
    }
    
    setState(() => _isUploading = true);
    
    try {
      await Future.delayed(const Duration(seconds: 2));
      _showSnackBar('Fichier uploadé avec succès: $_selectedFileName', const Color(0xFF10B981));
      setState(() {
        _selectedFilePath = null;
        _selectedFileName = null;
        _isUploading = false;
      });
    } catch (e) {
      print('Erreur upload: $e');
      _showSnackBar('Erreur lors de l\'upload', const Color(0xFFEF4444));
      setState(() => _isUploading = false);
    }
  }

  double _calculateClassAverage() {
    if (students.isEmpty) return 0;
    
    double total = 0;
    int count = 0;
    
    for (var student in students) {
      final studentId = student['firestoreId'];
      final studentGradeList = studentGrades[studentId] ?? [];
      if (studentGradeList.isNotEmpty) {
        final avg = _calculateAverage(studentGradeList);
        total += avg;
        count++;
      }
    }
    
    return count > 0 ? total / count : 0;
  }

  double _calculateAverage(List<Map<String, dynamic>> studentGrades) {
    if (studentGrades.isEmpty) return 0;
    
    double total = 0;
    double totalCoef = 0;
    
    for (var grade in studentGrades) {
      final score = grade['score'] as double;
      final maxScore = grade['maxScore'] as double;
      final coefficient = grade['coefficient'] as double;
      total += (score / maxScore * 20) * coefficient;
      totalCoef += coefficient;
    }
    
    return totalCoef > 0 ? (total / totalCoef).roundToDouble() : 0;
  }

  /// 🔥 Ajouter une note dans Firestore
  Future<void> _addGradeForStudent(Map<String, dynamic> student) async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isAddingNote = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      final score = double.tryParse(scoreController.text) ?? 0;
      final maxScore = double.tryParse(maxScoreController.text) ?? 20;
      final coefficient = double.tryParse(coefficientController.text) ?? 1;
      
      print('\n📝 AJOUT NOTE:');
      print('   → Étudiant: ${student['fullName']}');
      print('   → Classe: $selectedClass');
      print('   → Matière: $selectedSubject');
      print('   → Note: $score/$maxScore');
      print('   → Coef: $coefficient');
      
      final gradeData = {
        'studentFirestoreId': student['firestoreId'],
        'studentName': student['fullName'],
        'className': selectedClass,
        'subject': selectedSubject,
        'evaluationType': selectedEvaluation,
        'score': score,
        'maxScore': maxScore,
        'coefficient': coefficient,
        'comments': commentController.text.isEmpty ? 'Note ajoutée' : commentController.text,
        'date': FieldValue.serverTimestamp(),
        'schoolId': schoolId,
        'createdBy': widget.professorFirestoreId,
      };
      
      await FirebaseFirestore.instance.collection('grades').add(gradeData);
      
      scoreController.clear();
      maxScoreController.clear();
      coefficientController.clear();
      commentController.clear();
      
      await _loadDataFromFirestore();
      _showSnackBar('Note ajoutée pour ${student['fullName']}', const Color(0xFF10B981));
      print('✅ Note ajoutée avec succès');
    } catch (e) {
      print('❌ Erreur: $e');
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    } finally {
      setState(() => _isAddingNote = false);
    }
  }

  /// 🔥 Ajouter une note pour toute la classe
  Future<void> _addGradeForAll() async {
    if (!_formKey.currentState!.validate()) return;
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = auth.currentSchoolId;
    
    final score = double.tryParse(scoreController.text) ?? 0;
    final maxScore = double.tryParse(maxScoreController.text) ?? 20;
    final coefficient = double.tryParse(coefficientController.text) ?? 1;
    
    setState(() => _isAddingNote = true);
    
    try {
      print('\n📝 AJOUT NOTES POUR TOUTE LA CLASSE:');
      print('   → Classe: $selectedClass');
      print('   → Matière: $selectedSubject');
      print('   → Note: $score/$maxScore');
      print('   → Nombre étudiants: ${students.length}');
      
      for (var student in students) {
        final gradeData = {
          'studentFirestoreId': student['firestoreId'],
          'studentName': student['fullName'],
          'className': selectedClass,
          'subject': selectedSubject,
          'evaluationType': selectedEvaluation,
          'score': score,
          'maxScore': maxScore,
          'coefficient': coefficient,
          'comments': commentController.text.isEmpty ? 'Note de classe' : commentController.text,
          'date': FieldValue.serverTimestamp(),
          'schoolId': schoolId,
          'createdBy': widget.professorFirestoreId,
        };
        await FirebaseFirestore.instance.collection('grades').add(gradeData);
      }
      
      scoreController.clear();
      maxScoreController.clear();
      coefficientController.clear();
      commentController.clear();
      
      await _loadDataFromFirestore();
      _showSnackBar('Notes ajoutées pour tous les élèves', const Color(0xFF10B981));
      print('✅ ${students.length} notes ajoutées avec succès');
    } catch (e) {
      print('❌ Erreur: $e');
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    } finally {
      setState(() => _isAddingNote = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Gestion des notes',
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDataFromFirestore,
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            icon: const Icon(Icons.quiz, color: Color(0xFFF59E0B)),
            onPressed: _navigateToOnlineExams,
            tooltip: 'Examens en ligne',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  if (auth.currentSchoolId != null && !auth.isSuperAdmin)
                    Container(
                      margin: const EdgeInsets.all(16),
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

                  // Filtres
                  Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.white,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedClass.isNotEmpty ? selectedClass : null,
                                items: widget.assignedClasses.map((className) {
                                  return DropdownMenuItem(
                                    value: className,
                                    child: Text(className),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  print('\n🔄 Changement de classe: $value');
                                  setState(() {
                                    selectedClass = value!;
                                    selectedSubject = '';
                                    _loadDataFromFirestore();
                                  });
                                },
                                decoration: InputDecoration(
                                  labelText: "Classe",
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  prefixIcon: const Icon(Icons.class_, color: Color(0xFF10B981)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedSubject.isNotEmpty && _currentSubjectsForClass.contains(selectedSubject) 
                                    ? selectedSubject 
                                    : null,
                                items: _currentSubjectsForClass.map((subject) {
                                  return DropdownMenuItem(
                                    value: subject,
                                    child: Text(subject),
                                  );
                                }).toList(),
                                onChanged: _currentSubjectsForClass.isNotEmpty ? (value) {
                                  print('\n🔄 Changement de matière: $value');
                                  setState(() {
                                    selectedSubject = value!;
                                    _loadDataFromFirestore();
                                  });
                                } : null,
                                decoration: InputDecoration(
                                  labelText: "Matière",
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  prefixIcon: const Icon(Icons.book, color: Color(0xFF10B981)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                hint: _currentSubjectsForClass.isEmpty 
                                    ? const Text('Aucune matière assignée') 
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (selectedSubject.isNotEmpty) ...[
                    // Carte Examens en ligne
                    Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFF59E0B).withOpacity(0.1),
                            const Color(0xFFF59E0B).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
                      ),
                      child: InkWell(
                        onTap: _navigateToOnlineExams,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.quiz, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Examens en ligne',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                    Text(
                                      'Gérer et consulter les examens en ligne',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Upload de fichiers
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                      ),
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
                                  child: const Icon(Icons.attach_file, color: Color(0xFF3B82F6), size: 20),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Joindre un fichier (optionnel)',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickFile,
                                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                                    label: const Text('PDF / Image'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      side: BorderSide(color: Colors.grey[300]!),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickVideo,
                                    icon: const Icon(Icons.video_library, size: 18),
                                    label: const Text('Vidéo'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      side: BorderSide(color: Colors.grey[300]!),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedFileName != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Fichier sélectionné', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                          Text(_selectedFileName!, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    if (_isUploading)
                                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    else
                                      IconButton(
                                        icon: const Icon(Icons.cloud_upload, color: Color(0xFF10B981)),
                                        onPressed: _uploadFile,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Formulaire ajout note
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.grade, color: Color(0xFF10B981), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Ajouter une note', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 20),
                              DropdownButtonFormField<String>(
                                value: selectedEvaluation,
                                items: const [
                                  DropdownMenuItem(value: 'Devoir', child: Text('Devoir')),
                                  DropdownMenuItem(value: 'Examen', child: Text('Examen')),
                                  DropdownMenuItem(value: 'Participation', child: Text('Participation')),
                                  DropdownMenuItem(value: 'Projet', child: Text('Projet')),
                                  DropdownMenuItem(value: 'Interrogation', child: Text('Interrogation')),
                                ],
                                onChanged: (value) => setState(() => selectedEvaluation = value!),
                                decoration: InputDecoration(
                                  labelText: "Type d'évaluation",
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  prefixIcon: const Icon(Icons.assignment, color: Color(0xFF10B981)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: scoreController,
                                      decoration: InputDecoration(
                                        labelText: "Note",
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                        prefixIcon: const Icon(Icons.grade, color: Color(0xFF10B981)),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (value) => (value == null || value.isEmpty) ? "Note requise" : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: maxScoreController,
                                      decoration: InputDecoration(
                                        labelText: "Note max",
                                        hintText: "20",
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                        prefixIcon: const Icon(Icons.star_border, color: Color(0xFF10B981)),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: coefficientController,
                                      decoration: InputDecoration(
                                        labelText: "Coefficient",
                                        hintText: "1",
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                        prefixIcon: const Icon(Icons.calculate, color: Color(0xFF10B981)),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: commentController,
                                      decoration: InputDecoration(
                                        labelText: "Commentaire",
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                        prefixIcon: const Icon(Icons.comment, color: Color(0xFF10B981)),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: (students.isEmpty || _isAddingNote || selectedSubject.isEmpty) ? null : _addGradeForAll,
                                  icon: _isAddingNote
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.group_add),
                                  label: Text(_isAddingNote ? 'Ajout en cours...' : 'Pour toute la classe'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Liste des élèves
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.45,
                      child: students.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                                  const SizedBox(height: 16),
                                  Text('Aucun élève dans cette classe', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: students.length,
                              itemBuilder: (context, index) {
                                final student = students[index];
                                final studentId = student['firestoreId'];
                                final studentGradeList = studentGrades[studentId] ?? [];
                                final average = _calculateAverage(studentGradeList);
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
                                  ),
                                  child: ExpansionTile(
                                    leading: Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: studentGradeList.isEmpty
                                              ? [Colors.grey[400]!, Colors.grey[500]!]
                                              : [const Color(0xFF10B981), const Color(0xFF059669)],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          (student['fullName'] as String).isNotEmpty ? (student['fullName'] as String)[0].toUpperCase() : '?',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    title: Text(student['fullName'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${studentGradeList.length} note(s)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                        if (studentGradeList.isNotEmpty)
                                          Row(
                                            children: [
                                              const Icon(Icons.trending_up, size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Moyenne: ${average.toStringAsFixed(2)}/20',
                                                style: TextStyle(
                                                  color: average >= 10 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    trailing: Container(
                                      decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                      child: IconButton(
                                        icon: const Icon(Icons.add, color: Color(0xFF3B82F6)),
                                        onPressed: () => _showAddGradeDialog(student),
                                      ),
                                    ),
                                    children: [
                                      if (studentGradeList.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(32),
                                          child: Center(child: Text('Aucune note enregistrée', style: TextStyle(fontSize: 14))),
                                        )
                                      else
                                        ...studentGradeList.map((grade) {
                                          final percentage = (grade['score'] as double) / (grade['maxScore'] as double) * 20;
                                          return Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: percentage >= 10 ? const Color(0xFF10B981).withOpacity(0.05) : const Color(0xFFF59E0B).withOpacity(0.05),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(width: 4, height: 40, decoration: BoxDecoration(color: percentage >= 10 ? const Color(0xFF10B981) : const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(2))),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(grade['evaluationType'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                                      if ((grade['comments'] as String).isNotEmpty)
                                                        Text(grade['comments'], style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                                    ],
                                                  ),
                                                ),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text('${grade['score']}/${grade['maxScore']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: percentage >= 10 ? const Color(0xFF10B981) : const Color(0xFFF59E0B))),
                                                    Text('coef: ${grade['coefficient']}', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],

                  if (selectedSubject.isEmpty && !_isLoading && _currentSubjectsForClass.isEmpty)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text('Aucune matière assignée', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B))),
                            const SizedBox(height: 8),
                            Text('Vous n\'avez pas de matière dans cette classe', style: TextStyle(color: Colors.grey[500])),
                            const SizedBox(height: 8),
                            Text('Vérifiez que les matières sont assignées à votre ID professeur', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  void _navigateToOnlineExams() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherOnlineExamsScreen(
          professorFirestoreId: widget.professorFirestoreId,
          professorName: widget.teacherName,
          assignedClasses: widget.assignedClasses,
          assignedSubjects: widget.assignedSubjects,
        ),
      ),
    );
  }

  void _showAddGradeDialog(Map<String, dynamic> student) {
    scoreController.clear();
    maxScoreController.clear();
    coefficientController.clear();
    commentController.clear();
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.grade, color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Note pour ${student['fullName']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedEvaluation,
                items: const [
                  DropdownMenuItem(value: 'Devoir', child: Text('Devoir')),
                  DropdownMenuItem(value: 'Examen', child: Text('Examen')),
                  DropdownMenuItem(value: 'Participation', child: Text('Participation')),
                  DropdownMenuItem(value: 'Projet', child: Text('Projet')),
                  DropdownMenuItem(value: 'Interrogation', child: Text('Interrogation')),
                ],
                onChanged: (value) => setState(() => selectedEvaluation = value!),
                decoration: InputDecoration(
                  labelText: "Type d'évaluation",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.assignment, color: Color(0xFF10B981)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: scoreController,
                decoration: InputDecoration(
                  labelText: "Note",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.grade, color: Color(0xFF10B981)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: maxScoreController,
                decoration: InputDecoration(
                  labelText: "Note maximale",
                  hintText: "20",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.star_border, color: Color(0xFF10B981)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: coefficientController,
                decoration: InputDecoration(
                  labelText: "Coefficient",
                  hintText: "1",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.calculate, color: Color(0xFF10B981)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: commentController,
                decoration: InputDecoration(
                  labelText: "Commentaire",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.comment, color: Color(0xFF10B981)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          Navigator.pop(context);
                          await _addGradeForStudent(student);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Ajouter'),
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
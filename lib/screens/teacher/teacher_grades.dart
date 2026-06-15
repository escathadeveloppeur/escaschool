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
  String selectedSemester = 'S1';
  String selectedEvaluation = 'Devoir 1';
  
  // 🔥 Données du professeur (classes et matières assignées)
  List<Map<String, dynamic>> _teacherClasses = [];
  List<String> _teacherSubjectsForClass = [];
  List<Map<String, dynamic>> _teacherClassesData = [];
  
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

  List<Map<String, dynamic>> get _evaluationTypes {
    if (selectedSemester == 'S1') {
      return [
        {'value': 'Devoir 1', 'label': '📝 P1 - Devoir 1 (1er devoir du semestre)', 'icon': Icons.assignment},
        {'value': 'Devoir 2', 'label': '📝 P2 - Devoir 2 (2ème devoir du semestre)', 'icon': Icons.assignment},
        {'value': 'Interrogation', 'label': '❓ Interrogation (question rapide)', 'icon': Icons.quiz},
        {'value': 'Examen', 'label': '📚 EX1 - Examen (fin de semestre)', 'icon': Icons.school},
      ];
    } else {
      return [
        {'value': 'Devoir 1', 'label': '📝 P3 - Devoir 1 (1er devoir du semestre)', 'icon': Icons.assignment},
        {'value': 'Devoir 2', 'label': '📝 P4 - Devoir 2 (2ème devoir du semestre)', 'icon': Icons.assignment},
        {'value': 'Interrogation', 'label': '❓ Interrogation (question rapide)', 'icon': Icons.quiz},
        {'value': 'Examen', 'label': '📚 EX2 - Examen (fin de semestre)', 'icon': Icons.school},
      ];
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadTeacherData();
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

  /// 🔥 Charger les classes où le professeur enseigne
  Future<void> _loadTeacherData() async {
    setState(() => _isLoading = true);
    
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║     CHARGEMENT DES DONNÉES - TEACHER GRADES                ║');
    print('╚════════════════════════════════════════════════════════════╝\n');
    print('📌 Professeur ID: ${widget.professorFirestoreId}\n');
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      // ==================== 1. CHARGER LES CLASSES OÙ LE PROFESSEUR ENSEIGNE ====================
      print('🔍 [1/3] Chargement des classes où le professeur enseigne...');
      
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      
      _teacherClasses = [];
      _teacherClassesData = [];
      
      for (var doc in classesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final className = data['className'] ?? '';
        final subjects = data['subjects'] as List<dynamic>? ?? [];
        
        // Vérifier si le professeur enseigne dans cette classe
        final hasProfessorSubjects = subjects.any((subject) {
          final subjectMap = subject as Map<String, dynamic>;
          return subjectMap['professorFirestoreId'] == widget.professorFirestoreId;
        });
        
        if (hasProfessorSubjects && className.isNotEmpty) {
          _teacherClasses.add({
            'firestoreId': doc.id,
            'className': className,
            'level': data['level'] ?? '',
            'section': data['section'] ?? '',
            'cycleType': data['cycleType'] ?? 'primaire',
          });
          
          _teacherClassesData.add({
            'firestoreId': doc.id,
            'className': className,
            'subjects': subjects,
          });
          
          print('   ✅ Classe trouvée: $className');
        }
      }
      
      print('   📊 ${_teacherClasses.length} classe(s) trouvée(s)');
      
      // Définir la classe sélectionnée par défaut
      if (_teacherClasses.isNotEmpty) {
        if (selectedClass.isEmpty || !_teacherClasses.any((c) => c['className'] == selectedClass)) {
          selectedClass = _teacherClasses.first['className'];
        }
      } else {
        selectedClass = '';
      }
      
      // ==================== 2. CHARGER LES MATIÈRES POUR LA CLASSE SÉLECTIONNÉE ====================
      if (selectedClass.isNotEmpty) {
        await _loadSubjectsForClass(selectedClass);
      }
      
      // ==================== 3. CHARGER LES ÉTUDIANTS ET NOTES ====================
      await _loadStudentsAndGrades();
      
      print('\n✅ Chargement terminé\n');
      _animationController.forward(from: 0);
      
    } catch (e) {
      print('❌ Erreur: $e');
      _showSnackBar('Erreur de chargement: $e', const Color(0xFFEF4444));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 🔥 Charger les matières du professeur pour une classe spécifique
  Future<void> _loadSubjectsForClass(String className) async {
    print('🔍 Chargement des matières pour la classe: $className');
    
    final classData = _teacherClassesData.firstWhere(
      (c) => c['className'] == className,
      orElse: () => {},
    );
    
    if (classData.isEmpty) {
      _teacherSubjectsForClass = [];
      selectedSubject = '';
      print('   ⚠️ Classe non trouvée dans les données');
      return;
    }
    
    final subjects = classData['subjects'] as List<dynamic>? ?? [];
    _teacherSubjectsForClass = [];
    
    for (var subject in subjects) {
      final subjectMap = subject as Map<String, dynamic>;
      final subjectName = subjectMap['name'] ?? '';
      final professorId = subjectMap['professorFirestoreId'] ?? '';
      
      if (professorId == widget.professorFirestoreId && subjectName.isNotEmpty) {
        _teacherSubjectsForClass.add(subjectName);
        print('   ✅ Matière: $subjectName');
      }
    }
    
    if (_teacherSubjectsForClass.isNotEmpty) {
      if (!_teacherSubjectsForClass.contains(selectedSubject)) {
        selectedSubject = _teacherSubjectsForClass.first;
      }
      print('   ✅ Matière sélectionnée: $selectedSubject');
    } else {
      selectedSubject = '';
      print('   ⚠️ Aucune matière assignée pour ce professeur dans cette classe');
    }
  }

  /// 🔥 Charger les étudiants et les notes
  Future<void> _loadStudentsAndGrades() async {
    if (selectedClass.isEmpty) {
      students = [];
      return;
    }
    
    print('🔍 [2/3] Chargement des étudiants pour la classe: $selectedClass');
    
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('students')
        .where('className', isEqualTo: selectedClass)
        .get();
    
    students = [];
    for (var doc in studentsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      students.add({
        'firestoreId': doc.id,
        'fullName': data['fullName'] ?? 'Sans nom',
        'className': data['className'] ?? '',
        'parentUserId': data['parentUserId'],
      });
    }
    print('   📊 ${students.length} étudiant(s) trouvé(s)');
    
    // ==================== CHARGER LES NOTES ====================
    if (selectedClass.isNotEmpty && selectedSubject.isNotEmpty) {
      print('🔍 [3/3] Chargement des notes pour $selectedClass - $selectedSubject');
      
      final gradesSnapshot = await FirebaseFirestore.instance
          .collection('grades')
          .where('className', isEqualTo: selectedClass)
          .where('subject', isEqualTo: selectedSubject)
          .get();
      
      grades = [];
      for (var doc in gradesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        grades.add({
          'id': doc.id,
          'studentFirestoreId': data['studentFirestoreId'] ?? '',
          'studentName': data['studentName'] ?? '',
          'subject': data['subject'] ?? '',
          'semester': data['semester'] ?? 'S1',
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
      
      print('   📊 ${grades.length} note(s) chargée(s) pour ${studentGrades.length} étudiant(s)');
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

  String _getFinalEvaluationType() {
    if (selectedSemester == 'S1') {
      return selectedEvaluation;
    } else {
      if (selectedEvaluation == 'Examen') {
        return 'Examen';
      } else {
        return '${selectedEvaluation} S2';
      }
    }
  }

  Future<void> _addGradeForStudent(Map<String, dynamic> student) async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isAddingNote = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      final score = double.tryParse(scoreController.text) ?? 0;
      final maxScore = double.tryParse(maxScoreController.text) ?? 20;
      final coefficient = double.tryParse(coefficientController.text) ?? 1;
      final evaluationType = _getFinalEvaluationType();
      
      final gradeData = {
        'studentFirestoreId': student['firestoreId'],
        'studentName': student['fullName'],
        'className': selectedClass,
        'subject': selectedSubject,
        'semester': selectedSemester,
        'evaluationType': evaluationType,
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
      
      await _loadStudentsAndGrades();
      _showSnackBar('Note ajoutée pour ${student['fullName']}', const Color(0xFF10B981));
    } catch (e) {
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    } finally {
      setState(() => _isAddingNote = false);
    }
  }

  Future<void> _addGradeForAll() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isAddingNote = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      final score = double.tryParse(scoreController.text) ?? 0;
      final maxScore = double.tryParse(maxScoreController.text) ?? 20;
      final coefficient = double.tryParse(coefficientController.text) ?? 1;
      final evaluationType = _getFinalEvaluationType();
      
      for (var student in students) {
        final gradeData = {
          'studentFirestoreId': student['firestoreId'],
          'studentName': student['fullName'],
          'className': selectedClass,
          'subject': selectedSubject,
          'semester': selectedSemester,
          'evaluationType': evaluationType,
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
      
      await _loadStudentsAndGrades();
      _showSnackBar('Notes ajoutées pour tous les élèves', const Color(0xFF10B981));
    } catch (e) {
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
        title: const Text('Gestion des notes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTeacherData,
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
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))))
          : SingleChildScrollView(
              child: Column(
                children: [
                  if (auth.currentSchoolId != null && !auth.isSuperAdmin)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.business, size: 18, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 8),
                          Text('École : ${auth.schoolName ?? auth.currentSchoolId}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6))),
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
                                hint: _teacherClasses.isEmpty 
                                    ? const Text('Aucune classe assignée') 
                                    : const Text('Sélectionner une classe'),
                                items: _teacherClasses.map<DropdownMenuItem<String>>((c) {
                                  final sectionDisplay = c['section'] != null && c['section'].isNotEmpty
                                      ? ' - ${c['section']}'
                                      : '';
                                  return DropdownMenuItem<String>(
                                    value: c['className'],
                                    child: Text('${c['className']}${sectionDisplay} (${c['level']})'),
                                  );
                                }).toList(),
                                onChanged: _teacherClasses.isNotEmpty ? (value) async {
                                  setState(() {
                                    selectedClass = value!;
                                    selectedSubject = '';
                                  });
                                  await _loadSubjectsForClass(selectedClass);
                                  await _loadStudentsAndGrades();
                                  setState(() {});
                                } : null,
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
                                value: selectedSubject.isNotEmpty && _teacherSubjectsForClass.contains(selectedSubject) 
                                    ? selectedSubject 
                                    : null,
                                hint: _teacherSubjectsForClass.isEmpty 
                                    ? const Text('Aucune matière') 
                                    : const Text('Sélectionner une matière'),
                                items: _teacherSubjectsForClass.map<DropdownMenuItem<String>>((subject) {
                                  return DropdownMenuItem<String>(
                                    value: subject,
                                    child: Text(subject),
                                  );
                                }).toList(),
                                onChanged: _teacherSubjectsForClass.isNotEmpty ? (value) async {
                                  setState(() {
                                    selectedSubject = value!;
                                  });
                                  await _loadStudentsAndGrades();
                                  setState(() {});
                                } : null,
                                decoration: InputDecoration(
                                  labelText: "Matière",
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  prefixIcon: const Icon(Icons.book, color: Color(0xFF10B981)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
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
                          colors: [const Color(0xFFF59E0B).withOpacity(0.1), const Color(0xFFF59E0B).withOpacity(0.05)],
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
                                    const Text('Examens en ligne', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                                    Text('Gérer et consulter les examens en ligne', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
                                const Text('Joindre un fichier (optionnel)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                                value: selectedSemester,
                                items: const [
                                  DropdownMenuItem(value: 'S1', child: Text('📗 Semestre 1 (P1, P2, Interro, EX1)')),
                                  DropdownMenuItem(value: 'S2', child: Text('📘 Semestre 2 (P3, P4, Interro, EX2)')),
                                ],
                                onChanged: (value) => setState(() => selectedSemester = value!),
                                decoration: InputDecoration(
                                  labelText: "Semestre",
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  prefixIcon: const Icon(Icons.calendar_month, color: Color(0xFF10B981)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              DropdownButtonFormField<String>(
                                value: selectedEvaluation,
                                items: _evaluationTypes.map<DropdownMenuItem<String>>((type) {
                                  return DropdownMenuItem<String>(
                                    value: type['value'],
                                    child: Row(
                                      children: [
                                        Icon(type['icon'], size: 18, color: const Color(0xFF10B981)),
                                        const SizedBox(width: 8),
                                        Text(type['label']),
                                      ],
                                    ),
                                  );
                                }).toList(),
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
                                          final semesterLabel = grade['semester'] == 'S1' ? '📗 S1' : '📘 S2';
                                          final typeLabel = grade['evaluationType'] ?? '';
                                          
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
                                                      Row(
                                                        children: [
                                                          Text(semesterLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: grade['semester'] == 'S1' ? Colors.blue : Colors.orange)),
                                                          const SizedBox(width: 8),
                                                          Text(typeLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                                        ],
                                                      ),
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

                  if (selectedSubject.isEmpty && !_isLoading && _teacherSubjectsForClass.isEmpty && selectedClass.isNotEmpty)
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text('Aucune matière assignée', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B))),
                            const SizedBox(height: 8),
                            Text('Vous n\'avez pas de matière dans cette classe', style: TextStyle(color: Colors.grey[500])),
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
                value: selectedSemester,
                items: const [
                  DropdownMenuItem(value: 'S1', child: Text('📗 Semestre 1 (P1, P2, Interro, EX1)')),
                  DropdownMenuItem(value: 'S2', child: Text('📘 Semestre 2 (P3, P4, Interro, EX2)')),
                ],
                onChanged: (value) => setState(() => selectedSemester = value!),
                decoration: InputDecoration(
                  labelText: "Semestre",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  prefixIcon: const Icon(Icons.calendar_month, color: Color(0xFF10B981)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              
              const SizedBox(height: 12),
              
              DropdownButtonFormField<String>(
                value: selectedEvaluation,
                items: _evaluationTypes.map<DropdownMenuItem<String>>((type) {
                  return DropdownMenuItem<String>(
                    value: type['value'],
                    child: Row(
                      children: [
                        Icon(type['icon'], size: 18, color: const Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text(type['label']),
                      ],
                    ),
                  );
                }).toList(),
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
                        Navigator.pop(context);
                        await _addGradeForStudent(student);
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
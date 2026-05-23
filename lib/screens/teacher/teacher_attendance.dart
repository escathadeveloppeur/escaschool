// lib/screens/teacher/teacher_attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/qr_scanner.dart';
import '../../services/qr_service.dart';
import '../../providers/auth_provider.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  final String teacherName;
  final String professorFirestoreId;
  final List<String> assignedClasses;
  final List<String> assignedSubjects;
  
  const TeacherAttendanceScreen({
    super.key,
    required this.teacherName,
    required this.professorFirestoreId,
    required this.assignedClasses,
    required this.assignedSubjects,
  });

  @override
  _TeacherAttendanceScreenState createState() => _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> students = [];
  Map<String, String> attendanceStatus = {};
  Map<String, String> attendanceRemark = {};
  Map<String, bool> attendanceScanned = {};
  Map<String, bool> attendanceAlreadyExists = {}; // 🔥 Pour marquer les présences déjà enregistrées
  
  String selectedClass = '';
  String selectedSubject = '';
  DateTime selectedDate = DateTime.now();
  
  List<String> _teacherSubjectsForClass = [];
  bool _isScanning = false;
  bool _isSaving = false;
  bool _isLoading = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    if (widget.assignedClasses.isNotEmpty) {
      selectedClass = widget.assignedClasses.first;
    }
    _loadDataFromFirestore();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les données depuis Firestore
  Future<void> _loadDataFromFirestore() async {
    setState(() {
      _isLoading = true;
      _isSaving = false;
    });
    
    print('\n╔════════════════════════════════════════════════════════════╗');
    print('║     CHARGEMENT DES PRÉSENCES                               ║');
    print('╚════════════════════════════════════════════════════════════╝\n');
    print('📌 Professeur ID: ${widget.professorFirestoreId}');
    print('📌 Classe sélectionnée: $selectedClass');
    print('📌 Date: ${DateFormat('dd/MM/yyyy').format(selectedDate)}\n');
    
    try {
      // ==================== 1. CHARGER LES MATIÈRES DEPUIS LES CLASSES ====================
      print('🔍 [1/4] Chargement des matières depuis la collection classes...');
      
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .get();
      
      _teacherSubjectsForClass = [];
      
      for (var doc in classesSnapshot.docs) {
        final data = doc.data();
        final className = data['className'] ?? '';
        final subjects = data['subjects'] as List<dynamic>? ?? [];
        
        if (className == selectedClass) {
          print('   📚 Classe trouvée: $className');
          print('      - Matières dans la classe: ${subjects.length}');
          
          for (var subject in subjects) {
            final subjectMap = subject as Map<String, dynamic>;
            final subjectName = subjectMap['name'] ?? '';
            final professorId = subjectMap['professorFirestoreId'] ?? '';
            
            print('         📖 Matière: $subjectName');
            print('            - Professeur assigné: $professorId');
            print('            - Professeur actuel: ${widget.professorFirestoreId}');
            
            if (professorId == widget.professorFirestoreId && subjectName.isNotEmpty) {
              _teacherSubjectsForClass.add(subjectName);
              print('            ✅ AJOUTÉE');
            }
          }
        }
      }
      
      // Sélectionner la première matière si disponible
      if (_teacherSubjectsForClass.isNotEmpty) {
        if (!_teacherSubjectsForClass.contains(selectedSubject)) {
          selectedSubject = _teacherSubjectsForClass.first;
        }
        print('   ✅ Matière sélectionnée: $selectedSubject');
      } else {
        selectedSubject = '';
        print('   ⚠️ Aucune matière assignée pour ce professeur dans cette classe');
      }
      print('');
      
      // ==================== 2. CHARGER LES ÉTUDIANTS ====================
      print('🔍 [2/4] Chargement des étudiants...');
      
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
      print('');
      
      // ==================== 3. VÉRIFIER LES PRÉSENCES EXISTANTES ====================
      if (selectedSubject.isNotEmpty) {
        print('🔍 [3/4] Vérification des présences existantes pour cette date...');
        
        // Créer une plage de dates pour la journée sélectionnée
        final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        final endOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);
        
        final existingAttendance = await FirebaseFirestore.instance
            .collection('attendances')
            .where('className', isEqualTo: selectedClass)
            .where('subject', isEqualTo: selectedSubject)
            .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
            .get();
        
        print('   📊 ${existingAttendance.docs.length} présence(s) existante(s) trouvée(s)');
        
        // Mémoriser les étudiants qui ont déjà une présence
        final existingStudentIds = existingAttendance.docs.map((doc) {
          final data = doc.data();
          return data['studentFirestoreId'] as String?;
        }).where((id) => id != null).toSet();
        
        // ==================== 4. INITIALISER LES ÉTATS ====================
        print('\n🔍 [4/4] Initialisation des états...');
        
        for (var student in students) {
          final studentId = student['firestoreId'];
          final hasExisting = existingStudentIds.contains(studentId);
          
          attendanceAlreadyExists[studentId] = hasExisting;
          
          if (hasExisting) {
            // Récupérer le statut existant
            final existingDoc = existingAttendance.docs.firstWhere(
              (doc) => doc.data()['studentFirestoreId'] == studentId,
              orElse: () => throw Exception('Not found'),
            );
            final existingData = existingDoc.data();
            attendanceStatus[studentId] = existingData['status'] ?? 'present';
            attendanceRemark[studentId] = existingData['reason'] ?? '';
            attendanceScanned[studentId] = true;
            print('   ⏭️ ${student['fullName']} - Présence déjà enregistrée (${attendanceStatus[studentId]})');
          } else {
            attendanceStatus[studentId] = 'present';
            attendanceRemark[studentId] = '';
            attendanceScanned[studentId] = false;
            print('   ✅ ${student['fullName']} - Pas de présence pour cette date');
          }
        }
      } else {
        // Réinitialiser si pas de matière
        for (var student in students) {
          final studentId = student['firestoreId'];
          attendanceStatus[studentId] = 'present';
          attendanceRemark[studentId] = '';
          attendanceScanned[studentId] = false;
          attendanceAlreadyExists[studentId] = false;
        }
      }
      
      print('\n✅ Chargement terminé\n');
      _animationController.forward(from: 0);
      
    } catch (e) {
      print('❌ Erreur chargement: $e');
      _showSnackBar('Erreur de chargement: $e', const Color(0xFFEF4444));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startQRScan() async {
    setState(() => _isScanning = true);
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScanner(
          onScan: (qrData) async {
            Navigator.pop(context, qrData);
          },
          onClose: () {
            Navigator.pop(context, null);
          },
        ),
      ),
    );
    
    setState(() => _isScanning = false);
    
    if (result != null && result is String) {
      await _processQRScan(result);
    }
  }

  Future<void> _processQRScan(String qrData) async {
    final qrInfo = QRService.validateQRCode(qrData);
    
    if (qrInfo == null) {
      _showSnackBar('QR code invalide', const Color(0xFFEF4444));
      return;
    }
    
    final studentFirestoreId = qrInfo['studentId'] as String?;
    if (studentFirestoreId == null) {
      _showSnackBar('QR code invalide', const Color(0xFFEF4444));
      return;
    }
    
    final student = students.firstWhere(
      (s) => s['firestoreId'] == studentFirestoreId,
      orElse: () => {},
    );
    
    if (student.isEmpty) {
      _showSnackBar('Élève non trouvé dans cette classe', const Color(0xFFEF4444));
      return;
    }
    
    // Vérifier si la présence existe déjà
    if (attendanceAlreadyExists[studentFirestoreId] == true) {
      _showSnackBar('⚠️ ${student['fullName']} a déjà une présence pour aujourd\'hui', const Color(0xFFF59E0B));
      return;
    }
    
    if (attendanceScanned[studentFirestoreId] == true) {
      _showSnackBar('⚠️ ${student['fullName']} déjà scanné', const Color(0xFFF59E0B));
      return;
    }
    
    setState(() {
      attendanceStatus[studentFirestoreId] = 'present';
      attendanceScanned[studentFirestoreId] = true;
    });
    
    _showSuccessDialog(student['fullName']);
  }

  void _showSuccessDialog(String studentName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [const Color(0xFF10B981), const Color(0xFF059669)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('Présence validée !', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              const SizedBox(height: 12),
              Text(studentName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now()), style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Continuer', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  void _setStudentStatus(String studentId, String status) {
    // Vérifier si la présence existe déjà
    if (attendanceAlreadyExists[studentId] == true) {
      _showSnackBar('Cette présence est déjà enregistrée, modification non autorisée', const Color(0xFFF59E0B));
      return;
    }
    
    setState(() {
      attendanceStatus[studentId] = status;
      if (status != 'present') {
        attendanceScanned[studentId] = false;
      }
    });
    
    String message = '';
    switch(status) {
      case 'present': message = 'Marqué présent'; break;
      case 'absent': message = 'Marqué absent'; break;
      case 'late': message = 'Marqué en retard'; break;
      case 'excused': message = 'Marqué excusé'; break;
    }
    _showSnackBar(message, const Color(0xFF3B82F6));
  }

  /// 🔥 Sauvegarder les présences dans Firestore
  Future<void> _saveAttendance() async {
    if (selectedSubject.isEmpty) {
      _showSnackBar('Veuillez sélectionner une matière', const Color(0xFFF59E0B));
      return;
    }
    
    setState(() => _isSaving = true);
    
    print('\n💾 SAUVEGARDE DES PRÉSENCES');
    print('   → Classe: $selectedClass');
    print('   → Matière: $selectedSubject');
    print('   → Date: ${DateFormat('dd/MM/yyyy').format(selectedDate)}');
    print('   → Nombre étudiants: ${students.length}\n');
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      int savedCount = 0;
      int skippedCount = 0;
      
      for (var student in students) {
        final studentId = student['firestoreId'];
        
        // Vérifier si la présence existe déjà
        if (attendanceAlreadyExists[studentId] == true) {
          print('   ⏭️ ${student['fullName']} - Présence déjà existante (ignoré)');
          skippedCount++;
          continue;
        }
        
        final status = attendanceStatus[studentId] ?? 'present';
        final remark = attendanceRemark[studentId] ?? '';
        
        final attendanceData = {
          'studentFirestoreId': studentId,
          'studentName': student['fullName'],
          'className': selectedClass,
          'subject': selectedSubject,
          'date': Timestamp.fromDate(selectedDate),
          'status': status,
          'reason': remark.isNotEmpty ? remark : null,
          'schoolId': schoolId,
          'recordedBy': widget.professorFirestoreId,
          'recordedAt': FieldValue.serverTimestamp(),
        };
        
        await FirebaseFirestore.instance.collection('attendances').add(attendanceData);
        savedCount++;
        print('   ✅ ${student['fullName']} - $status');
      }
      
      print('\n📊 RÉSULTAT: $savedCount enregistré(s), $skippedCount ignoré(s)');
      _showSuccessSaveDialog(savedCount);
      
      // Recharger les données pour mettre à jour les états
      await _loadDataFromFirestore();
      
    } catch (e) {
      print('❌ Erreur: $e');
      _showSnackBar('Erreur: $e', const Color(0xFFEF4444));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSuccessSaveDialog(int count) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [const Color(0xFF10B981), const Color(0xFF059669)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.save, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('Présences enregistrées !', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              const SizedBox(height: 12),
              Text('$count élève(s) enregistré(s)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: TextStyle(color: Colors.grey[500])),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('OK', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getScannedCount() {
    return students.where((s) => attendanceScanned[s['firestoreId']] == true).length;
  }

  int _getPresentCount() {
    return students.where((s) => attendanceStatus[s['firestoreId']] == 'present').length;
  }

  int _getAbsentCount() {
    return students.where((s) => attendanceStatus[s['firestoreId']] == 'absent').length;
  }

  int _getLateCount() {
    return students.where((s) => attendanceStatus[s['firestoreId']] == 'late').length;
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'present': return 'Présent';
      case 'absent': return 'Absent';
      case 'late': return 'Retard';
      case 'excused': return 'Excusé';
      default: return 'Présent';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'present': return const Color(0xFF10B981);
      case 'absent': return const Color(0xFFEF4444);
      case 'late': return const Color(0xFFF59E0B);
      case 'excused': return const Color(0xFF3B82F6);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Gestion des présences', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDataFromFirestore,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))))
          : Column(
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
                              items: widget.assignedClasses.map((className) {
                                return DropdownMenuItem(value: className, child: Text(className));
                              }).toList(),
                              onChanged: (value) {
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
                              value: selectedSubject.isNotEmpty && _teacherSubjectsForClass.contains(selectedSubject) 
                                  ? selectedSubject 
                                  : null,
                              items: _teacherSubjectsForClass.map((subject) {
                                return DropdownMenuItem(value: subject, child: Text(subject));
                              }).toList(),
                              onChanged: _teacherSubjectsForClass.isNotEmpty ? (value) {
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
                              hint: _teacherSubjectsForClass.isEmpty 
                                  ? const Text('Aucune matière assignée') 
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDatePicker(),
                    ],
                  ),
                ),

                if (selectedSubject.isNotEmpty) ...[
                  // Statistiques
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatChip('Scannés', _getScannedCount(), students.length, const Color(0xFF10B981)),
                        _buildStatChip('Présents', _getPresentCount(), students.length, const Color(0xFF3B82F6)),
                        _buildStatChip('Absents', _getAbsentCount(), students.length, const Color(0xFFEF4444)),
                        _buildStatChip('Retards', _getLateCount(), students.length, const Color(0xFFF59E0B)),
                      ],
                    ),
                  ),
                  
                  // Bouton QR
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ElevatedButton.icon(
                      onPressed: _isScanning ? null : _startQRScan,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scanner QR code'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ),
                  
                  // Liste des élèves
                  Expanded(
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
                        : FadeTransition(
                            opacity: _animationController,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: students.length,
                              itemBuilder: (context, index) {
                                final student = students[index];
                                final studentId = student['firestoreId'];
                                final isScanned = attendanceScanned[studentId] ?? false;
                                final alreadyExists = attendanceAlreadyExists[studentId] ?? false;
                                final status = attendanceStatus[studentId] ?? 'present';
                                
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Material(
                                    elevation: (isScanned || alreadyExists) ? 4 : 1,
                                    shadowColor: (isScanned || alreadyExists) ? const Color(0xFF10B981).withOpacity(0.3) : Colors.black.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: alreadyExists ? Colors.green.shade50 : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: (isScanned || alreadyExists) ? Border.all(color: const Color(0xFF10B981), width: 2) : null,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                if (isScanned || alreadyExists) 
                                                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                                                if (isScanned || alreadyExists) 
                                                  const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    student['fullName'],
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                      color: (isScanned || alreadyExists) ? const Color(0xFF10B981) : Colors.grey[800],
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(status).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: DropdownButton<String>(
                                                    value: status,
                                                    items: ['present', 'absent', 'late', 'excused'].map((statusValue) {
                                                      return DropdownMenuItem(
                                                        value: statusValue,
                                                        enabled: !alreadyExists, // 🔥 Désactiver si déjà enregistré
                                                        child: Row(
                                                          children: [
                                                            Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: _getStatusColor(statusValue))),
                                                            const SizedBox(width: 8),
                                                            Text(_getStatusText(statusValue)),
                                                          ],
                                                        ),
                                                      );
                                                    }).toList(),
                                                    onChanged: alreadyExists ? null : (value) => _setStudentStatus(studentId, value!),
                                                    underline: const SizedBox(),
                                                    icon: alreadyExists ? const SizedBox() : const Icon(Icons.arrow_drop_down, size: 20),
                                                    style: TextStyle(color: _getStatusColor(status)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            TextField(
                                              decoration: InputDecoration(
                                                hintText: alreadyExists ? "Présence déjà enregistrée" : "Remarque...",
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFF10B981))),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                filled: true,
                                                fillColor: Colors.grey[50],
                                              ),
                                              onChanged: alreadyExists ? null : (value) => attendanceRemark[studentId] = value,
                                              enabled: !alreadyExists,
                                            ),
                                            if (isScanned && !alreadyExists)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 10),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.qr_code, size: 14, color: Color(0xFF10B981)),
                                                    const SizedBox(width: 6),
                                                    Text('Scanné à ${DateFormat('HH:mm').format(DateTime.now())}', style: const TextStyle(fontSize: 11, color: Color(0xFF10B981))),
                                                  ],
                                                ),
                                              ),
                                            if (alreadyExists)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 10),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.lock, size: 14, color: Colors.grey),
                                                    const SizedBox(width: 6),
                                                    Text('Présence déjà enregistrée - Modification non autorisée', 
                                                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),

                  // Bouton enregistrer
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: (students.isEmpty || _isSaving || selectedSubject.isEmpty) ? null : _saveAttendance,
                      icon: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: const Text('Enregistrer les présences'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        minimumSize: const Size(double.infinity, 52),
                      ),
                    ),
                  ),
                ],

                if (selectedSubject.isEmpty && selectedClass.isNotEmpty && !_isLoading)
                  Expanded(
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
              ],
            ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2023),
          lastDate: DateTime(2025),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF10B981), onPrimary: Colors.white)),
            child: child!,
          ),
        );
        if (date != null) {
          setState(() {
            selectedDate = date;
            _loadDataFromFirestore();
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(14), color: Colors.white),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: const TextStyle(fontSize: 16))),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, int value, int total, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(30)),
      child: Column(
        children: [
          Text('$value/$total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
// lib/screens/qr_code_management_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/qr_code_model.dart';
import '../../services/qr_code_management_service.dart';
import '../../services/qr_code_print_service.dart';
import '../../services/student_card_service.dart';
import '../../models/student_card_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/card_print_service.dart';
import '../../widgets/color_picker_widget.dart';

class QRCodeManagementScreen extends StatefulWidget {
  final String schoolId;
  final String schoolName;

  const QRCodeManagementScreen({
    Key? key,
    required this.schoolId,
    required this.schoolName,
  }) : super(key: key);

  @override
  State<QRCodeManagementScreen> createState() => _QRCodeManagementScreenState();
}

class _QRCodeManagementScreenState extends State<QRCodeManagementScreen> {
  List<ClassQRCodeGroup> _qrGroups = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _classes = [];
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _errorMessage;

  static const Color primaryColor = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF3B5BDB);
  static const Color secondaryColor = Color(0xFF10B981);
  static const Color accentColor = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _loadStudentsFromFirestore(),
        _loadClassesFromFirestore(),
      ]);
      
      await _generateQRCodeGroups();
      
      setState(() {
        _isLoading = false;
        if (_qrGroups.isEmpty) {
          _errorMessage = 'Aucun étudiant trouvé. Ajoutez d\'abord des étudiants.';
        }
      });
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loadStudentsFromFirestore() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      Query query = FirebaseFirestore.instance.collection('students');
      
      if (schoolId != null && !auth.isSuperAdmin) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.get();
      
      _students = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'fullName': data['fullName'] ?? '',
          'className': data['className'] ?? '',
          'classFirestoreId': data['classFirestoreId'] ?? '',
          'classCycleType': data['classCycleType'] ?? 'primaire',
          'sectionId': data['sectionId'],
          'sectionName': data['sectionName'],
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
      
      print('✅ ${_students.length} étudiants chargés depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement étudiants: $e');
      throw e;
    }
  }

  Future<void> _loadClassesFromFirestore() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      Query query = FirebaseFirestore.instance.collection('classes');
      if (schoolId != null && !auth.isSuperAdmin) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      
      final snapshot = await query.get();
      
      _classes = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'firestoreId': doc.id,
          'className': data['className'] ?? '',
          'cycleType': data['cycleType'] ?? 'primaire',
          'sectionIds': data['sectionIds'] ?? [],
        };
      }).toList();
      
      print('✅ ${_classes.length} classes chargées depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement classes: $e');
      throw e;
    }
  }

  Future<void> _generateQRCodeGroups() async {
    final Map<String, List<Map<String, dynamic>>> studentsByClass = {};
    
    for (var student in _students) {
      final className = student['className'] ?? 'Sans classe';
      if (!studentsByClass.containsKey(className)) {
        studentsByClass[className] = [];
      }
      studentsByClass[className]!.add(student);
    }

    _qrGroups = [];
    
    for (var entry in studentsByClass.entries) {
      final className = entry.key;
      final classStudents = entry.value;
      
      final classInfo = _classes.firstWhere(
        (c) => c['className'] == className,
        orElse: () => {
          'firestoreId': '',
          'className': className,
          'cycleType': 'primaire',
          'sectionIds': [],
        },
      );
      
      final qrStudents = classStudents.map((student) {
        final studentId = student['firestoreId'] ?? '';
        final fullName = student['fullName'] ?? '';
        final sectionName = student['sectionName'];
        final classCycleType = student['classCycleType'] ?? 'primaire';
        final parentPhone = student['parentPhone'] ?? '';
        
        final qrData = {
          'type': 'student_attendance',
          'studentId': studentId,
          'studentName': fullName,
          'className': className,
          'classCycleType': classCycleType,
          'sectionName': sectionName,
          'parentPhone': parentPhone,
          'schoolId': widget.schoolId,
          'schoolName': widget.schoolName,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        
        return QRCodeData(
          id: studentId,
          studentId: studentId,
          studentName: fullName,
          className: className,
          schoolId: widget.schoolId,
          schoolName: widget.schoolName,
          classCycleType: classCycleType,
          sectionName: sectionName,
          parentPhone: parentPhone,
          generatedAt: DateTime.now(),
          qrCodeData: _encodeQRData(qrData),
          isActive: true,
          version: 1,
        );
      }).toList();
      
      final group = ClassQRCodeGroup(
        className: className,
        schoolId: widget.schoolId,
        schoolName: widget.schoolName,
        classCycleType: classInfo['cycleType'] ?? 'primaire',
        sectionName: null,
        students: qrStudents,
        generatedAt: DateTime.now(),
      );
      
      _qrGroups.add(group);
    }
    
    for (var group in _qrGroups) {
      try {
        await QRCodeManagementService.saveClassQRCodes(group);
      } catch (e) {
        print('⚠️ Erreur sauvegarde locale: $e');
      }
    }
    
    print('✅ ${_qrGroups.length} groupes de QR codes générés');
  }

  String _encodeQRData(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  Future<void> _regenerateStudentQRCode(QRCodeData student) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final newQRCode = await QRCodeManagementService.regenerateStudentQRCode(
        oldQRCode: student,
        schoolName: widget.schoolName,
      );

      final groupIndex = _qrGroups.indexWhere((g) => g.className == student.className);
      if (groupIndex != -1) {
        final studentIndex = _qrGroups[groupIndex].students.indexWhere((s) => s.id == student.id);
        if (studentIndex != -1) {
          _qrGroups[groupIndex].students[studentIndex] = newQRCode;
          await QRCodeManagementService.saveClassQRCodes(_qrGroups[groupIndex]);
          
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ QR code régénéré avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _regenerateStudentCard(QRCodeData student) async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final cardData = StudentCardData(
        studentId: student.id,
        fullName: student.studentName,
        className: student.className,
        classCycleType: student.classCycleType,
        schoolId: widget.schoolId,
        schoolName: widget.schoolName,
        sectionName: student.sectionName,
        parentPhone: student.parentPhone,
        generationDate: DateTime.now(),
      );

      final cardImage = await StudentCardService.generateStudentCard(
        data: cardData,
        width: 800,
        height: 550,
        pixelRatio: 2.0,
      );

      final filePath = await StudentCardService.saveCardToDevice(
        cardImage,
        student.studentName,
      );

      setState(() {
        _isGenerating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Carte régénérée avec succès: $filePath'),
          backgroundColor: Colors.green,
        ),
      );

      await StudentCardService.shareCard(cardImage, student.studentName);

    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteStudentQRCode(QRCodeData student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Confirmer la suppression",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Voulez-vous vraiment supprimer le QR code de ${student.studentName} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await QRCodeManagementService.deleteQRCode(student.id);
        await _loadAllData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ QR code supprimé'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _downloadCard(QRCodeData student) async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final cardData = StudentCardData(
        studentId: student.id,
        fullName: student.studentName,
        className: student.className,
        classCycleType: student.classCycleType,
        schoolId: widget.schoolId,
        schoolName: widget.schoolName,
        sectionName: student.sectionName,
        parentPhone: student.parentPhone,
        generationDate: DateTime.now(),
      );

      final cardImage = await StudentCardService.generateStudentCard(
        data: cardData,
        width: 800,
        height: 550,
        pixelRatio: 2.0,
      );

      final filePath = await StudentCardService.saveCardToDevice(
        cardImage,
        student.studentName,
      );

      setState(() {
        _isGenerating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Carte téléchargée: $filePath'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareCard(QRCodeData student) async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final cardData = StudentCardData(
        studentId: student.id,
        fullName: student.studentName,
        className: student.className,
        classCycleType: student.classCycleType,
        schoolId: widget.schoolId,
        schoolName: widget.schoolName,
        sectionName: student.sectionName,
        parentPhone: student.parentPhone,
        generationDate: DateTime.now(),
      );

      final cardImage = await StudentCardService.generateStudentCard(
        data: cardData,
        width: 800,
        height: 550,
        pixelRatio: 2.0,
      );

      await StudentCardService.shareCard(
        cardImage,
        student.studentName,
      );

      setState(() {
        _isGenerating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Carte partagée avec succès'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _printClassCards(ClassQRCodeGroup group) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('schoolId', isEqualTo: schoolId)
          .where('className', isEqualTo: group.className)
          .get();
      
      final students = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StudentCardData(
          studentId: doc.id,
          fullName: data['fullName'] ?? '',
          className: data['className'] ?? '',
          classCycleType: data['classCycleType'] ?? 'primaire',
          schoolId: widget.schoolId,
          schoolName: widget.schoolName,
          sectionName: data['sectionName'],
          parentPhone: data['parentPhone'] ?? '',
          generationDate: DateTime.now(),
        );
      }).toList();
      
      if (students.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun étudiant dans cette classe'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      await CardPrintService.printClassCards(
        students,
        group.className,
        widget.schoolName,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🖨️ Impression des cartes lancée'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur d\'impression: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveClassCardsPDF(ClassQRCodeGroup group) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;
      
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .where('schoolId', isEqualTo: schoolId)
          .where('className', isEqualTo: group.className)
          .get();
      
      final students = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StudentCardData(
          studentId: doc.id,
          fullName: data['fullName'] ?? '',
          className: data['className'] ?? '',
          classCycleType: data['classCycleType'] ?? 'primaire',
          schoolId: widget.schoolId,
          schoolName: widget.schoolName,
          sectionName: data['sectionName'],
          parentPhone: data['parentPhone'] ?? '',
          generationDate: DateTime.now(),
        );
      }).toList();
      
      if (students.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun étudiant dans cette classe'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      final filePath = await CardPrintService.saveClassCardsPDF(
        students,
        group.className,
        widget.schoolName,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ PDF sauvegardé: $filePath'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _printClassQRCodes(ClassQRCodeGroup classGroup) async {
    try {
      await QRCodePrintService.printQRCodes(classGroup);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🖨️ Impression lancée'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'impression: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _saveClassQRCodePDF(ClassQRCodeGroup classGroup) async {
    try {
      final filePath = await QRCodePrintService.saveQRCodePDF(classGroup);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ PDF sauvegardé: $filePath'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ✅ AFFICHAGE DE LA CARTE - VERSION SIMPLIFIÉE ET PROFESSIONNELLE

  void _showStudentCard(QRCodeData student) {
    Color primaryColor = const Color(0xFF1E3A8A);
    Color secondaryColor = const Color(0xFF10B981);
    Color accentColor = const Color(0xFF8B5CF6);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.92,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Barre de titre
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Carte d\'étudiant',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              Text(
                                student.studentName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            _buildActionButton(
                              icon: Icons.download,
                              color: primaryColor,
                              onPressed: () => _downloadCard(student),
                              tooltip: 'Télécharger',
                            ),
                            const SizedBox(width: 4),
                            _buildActionButton(
                              icon: Icons.share,
                              color: secondaryColor,
                              onPressed: () => _shareCard(student),
                              tooltip: 'Partager',
                            ),
                            const SizedBox(width: 4),
                            _buildActionButton(
                              icon: Icons.close,
                              color: Colors.red,
                              onPressed: () => Navigator.pop(context),
                              tooltip: 'Fermer',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Contenu
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Sélecteur de couleurs
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                ColorPickerWidget(
                                  selectedColor: primaryColor,
                                  onColorSelected: (color) {
                                    setStateModal(() {
                                      primaryColor = color;
                                    });
                                  },
                                  label: 'Couleur principale',
                                ),
                                const SizedBox(height: 12),
                                ColorPickerWidget(
                                  selectedColor: secondaryColor,
                                  onColorSelected: (color) {
                                    setStateModal(() {
                                      secondaryColor = color;
                                    });
                                  },
                                  label: 'Couleur secondaire',
                                ),
                                const SizedBox(height: 12),
                                ColorPickerWidget(
                                  selectedColor: accentColor,
                                  onColorSelected: (color) {
                                    setStateModal(() {
                                      accentColor = color;
                                    });
                                  },
                                  label: 'Couleur d\'accent',
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // ✅ CARTE
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [primaryColor, primaryColor.withOpacity(0.7)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Fond décoratif
                                Positioned(
                                  top: -80,
                                  right: -80,
                                  child: Container(
                                    width: 250,
                                    height: 250,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.03),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -60,
                                  left: -60,
                                  child: Container(
                                    width: 180,
                                    height: 180,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.03),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                
                                // Contenu
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Logo
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.school_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              student.schoolName.toUpperCase(),
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.9),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 16),
                                      
                                      // Corps
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // QR Code
                                          Container(
                                            width: 120,
                                            height: 120,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.15),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 8),
                                                ),
                                              ],
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: QrImageView(
                                                data: student.qrCodeData,
                                                version: QrVersions.auto,
                                                size: 100,
                                                backgroundColor: Colors.white,
                                                foregroundColor: Colors.black,
                                              ),
                                            ),
                                          ),
                                          
                                          const SizedBox(width: 16),
                                          
                                          // Informations
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  student.studentName,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                
                                                const SizedBox(height: 4),
                                                
                                                Container(
                                                  height: 3,
                                                  width: 40,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [secondaryColor, accentColor],
                                                    ),
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                ),
                                                
                                                const SizedBox(height: 10),
                                                
                                                _buildInfoRow('📚 Classe', student.className, isBold: true),
                                                if (student.sectionName != null && student.sectionName!.isNotEmpty)
                                                  _buildInfoRow('📖 Section', student.sectionName!),
                                                if (student.parentPhone != null && student.parentPhone!.isNotEmpty)
                                                  _buildInfoRow('📞 Parent', student.parentPhone!),
                                                
                                                const SizedBox(height: 6),
                                                
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [secondaryColor, secondaryColor.withOpacity(0.7)],
                                                    ),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.qr_code_scanner,
                                                        color: Colors.white,
                                                        size: 12,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Présence - ${student.classCycleType.toUpperCase()}',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w600,
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 12),
                                      
                                      // Pied
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Carte de présence',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.white.withOpacity(0.2),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            'Généré le ${_formatDate(student.generatedAt)}',
                                            style: TextStyle(
                                              fontSize: 8,
                                              color: Colors.white.withOpacity(0.2),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Statut
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: student.isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: student.isActive ? Colors.green : Colors.red,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  student.isActive ? Icons.check_circle : Icons.cancel,
                                  color: student.isActive ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  student.isActive ? '✅ QR code actif' : '❌ QR code inactif',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: student.isActive ? Colors.green : Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'v${student.version}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Actions
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.42,
                                child: ElevatedButton.icon(
                                  onPressed: () => _regenerateStudentQRCode(student),
                                  icon: const Icon(Icons.qr_code, size: 18),
                                  label: const Text('Régénérer QR'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.42,
                                child: ElevatedButton.icon(
                                  onPressed: () => _regenerateStudentCard(student),
                                  icon: const Icon(Icons.credit_card, size: 18),
                                  label: const Text('Régénérer Carte'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.9,
                                child: ElevatedButton.icon(
                                  onPressed: () => _deleteStudentQRCode(student),
                                  icon: const Icon(Icons.delete, size: 18),
                                  label: const Text('Supprimer le QR code'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 📝 Ligne d'information
  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: isBold ? 14 : 12,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 🔵 Bouton d'action
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
    String? tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 22),
        onPressed: onPressed,
        tooltip: tooltip,
        splashRadius: 24,
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des QR codes'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                  SizedBox(height: 16),
                  Text('Chargement des étudiants...'),
                ],
              ),
            )
          : _qrGroups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage ?? 'Aucun étudiant trouvé',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ajoutez d\'abord des étudiants pour générer des QR codes',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadAllData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Recharger'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _qrGroups.length,
                  itemBuilder: (context, index) {
                    final group = _qrGroups[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ExpansionTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [primaryColor, primaryLight],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.class_,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          group.className,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          '${group.students.length} élèves',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: group.students.length,
                              itemBuilder: (context, studentIndex) {
                                final student = group.students[studentIndex];
                                return GestureDetector(
                                  onTap: () => _showStudentCard(student),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [primaryColor, primaryLight],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.3),
                                              width: 2,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              student.studentName.isNotEmpty
                                                  ? student.studentName[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 6),
                                        
                                        Text(
                                          student.studentName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            student.className,
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.8),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 4),
                                        
                                        Container(
                                          width: 35,
                                          height: 35,
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: QrImageView(
                                            data: student.qrCodeData,
                                            version: QrVersions.auto,
                                            size: 29,
                                            backgroundColor: Colors.white,
                                            foregroundColor: Colors.black,
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 2),
                                        
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'v${student.version}',
                                              style: TextStyle(
                                                fontSize: 8,
                                                color: Colors.white.withOpacity(0.4),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: student.isActive ? Colors.green : Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _saveClassCardsPDF(group),
                                    icon: const Icon(Icons.file_download_outlined, size: 16),
                                    label: const Text('Exporter PDF', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _printClassCards(group),
                                    icon: const Icon(Icons.print, size: 16),
                                    label: const Text('Imprimer', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
// lib/screens/staff/staff_attendance_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../models/staff_model.dart';
import '../../models/staff_attendance_model.dart';
import '../../services/staff_attendance_service.dart';
import 'qr_scanner_screen.dart';

class StaffAttendanceScreen extends StatefulWidget {
  const StaffAttendanceScreen({super.key});

  @override
  _StaffAttendanceScreenState createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  final StaffAttendanceService _attendanceService = StaffAttendanceService();
  List<StaffModel> _staffList = [];
  List<StaffAttendanceModel> _todayAttendances = [];
  bool _isLoading = true;
  bool _isCheckingIn = false;
  bool _isScanning = false;
  bool _isGeneratingPDF = false;
  String? _scannedStaffId;
  String? _scannedStaffName;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolId = auth.currentSchoolId;

      final staffSnapshot = await FirebaseFirestore.instance
          .collection('staff')
          .where('schoolId', isEqualTo: schoolId)
          .where('isActive', isEqualTo: true)
          .get();

      _staffList = staffSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return StaffModel(
          id: data['localId'],
          firestoreId: doc.id,
          fullName: data['fullName'] ?? '',
          position: data['position'] ?? '',
          phone: data['phone'],
          email: data['email'],
          address: data['address'],
          hireDate: data['hireDate'] != null ? DateTime.parse(data['hireDate']) : DateTime.now(),
          salary: (data['salary'] ?? 0.0).toDouble(),
          isActive: data['isActive'] ?? true,
          schoolId: data['schoolId'] ?? schoolId,
        );
      }).toList();

      if (schoolId != null && schoolId.isNotEmpty) {
        _todayAttendances = await _attendanceService.getTodayAttendances(schoolId);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('❌ Erreur chargement: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startQRScanner() async {
    setState(() {
      _isScanning = true;
      _scannedStaffId = null;
      _scannedStaffName = null;
    });

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QRScannerScreen(
            onScanned: (staffId, staffName) {
              setState(() {
                _scannedStaffId = staffId;
                _scannedStaffName = staffName;
                _isScanning = false;
              });
              _processScannedStaff(staffId, staffName);
            },
          ),
        ),
      );
    } catch (e) {
      print('❌ Erreur scan QR: $e');
      setState(() => _isScanning = false);
    }
  }

  void _processScannedStaff(String staffId, String staffName) {
    final staff = _staffList.firstWhere(
      (s) => s.firestoreId == staffId,
      orElse: () => throw Exception('Staff non trouvé'),
    );

    if (staff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Personnel non trouvé'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final isCheckedIn = _todayAttendances.any((a) => a.staffId == staffId && a.checkOut == null);
    final hasCheckedOut = _todayAttendances.any((a) => a.staffId == staffId && a.checkOut != null);

    if (hasCheckedOut) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Déjà pointé aujourd\'hui'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (isCheckedIn) {
      _showCheckOutDialog(staff);
    } else {
      _checkIn(staff);
    }
  }

  void _showCheckOutDialog(StaffModel staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Déjà pointé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('👤 ${staff.fullName}'),
            Text('📋 ${staff.position}'),
            const SizedBox(height: 12),
            const Text('Voulez-vous faire le check-out ?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final attendanceId = _getAttendanceId(staff.firestoreId!);
              if (attendanceId != null) {
                _checkOut(attendanceId);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Check-out'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkIn(StaffModel staff) async {
    setState(() => _isCheckingIn = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      
      await _attendanceService.checkIn(
        staffId: staff.firestoreId!,
        staffName: staff.fullName,
        position: staff.position,
        schoolId: staff.schoolId!,
      );

      await _loadData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${staff.fullName} a pointé'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isCheckingIn = false);
    }
  }

  Future<void> _checkOut(String attendanceId) async {
    try {
      await _attendanceService.checkOut(attendanceId);
      await _loadData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Check-out effectué'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isCheckedInToday(String staffId) {
    return _todayAttendances.any((a) => a.staffId == staffId && a.checkOut == null);
  }

  bool _hasCheckedOutToday(String staffId) {
    return _todayAttendances.any((a) => a.staffId == staffId && a.checkOut != null);
  }

  String? _getAttendanceId(String staffId) {
    try {
      final attendance = _todayAttendances.firstWhere(
        (a) => a.staffId == staffId && a.checkOut == null,
        orElse: () => throw Exception('Not found'),
      );
      return attendance.id;
    } catch (e) {
      return null;
    }
  }

  String _getCheckInTime(String staffId) {
    try {
      final attendance = _todayAttendances.firstWhere(
        (a) => a.staffId == staffId,
        orElse: () => throw Exception('Not found'),
      );
      return '${attendance.checkIn.hour.toString().padLeft(2, '0')}:${attendance.checkIn.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }

  /// ✅ Générer le rapport de présence en PDF
  Future<Uint8List> _generateAttendancePDF() async {
    final pdf = pw.Document();
    final date = DateTime.now();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final schoolName = auth.schoolName ?? 'ECOLE SCHOOL';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // En-tête
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      '🏫 ${schoolName.toUpperCase()}',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'RAPPORT DE PRÉSENCE - PERSONNEL',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Date: ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      width: 200,
                      height: 2,
                      decoration: pw.BoxDecoration(
                        gradient: pw.LinearGradient(
                          colors: [PdfColors.blue400, PdfColors.blue800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Statistiques
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildPdfStat('Total', _staffList.length.toString(), PdfColors.purple),
                    _buildPdfStat('Présents', 
                      _todayAttendances.where((a) => a.status == 'present').length.toString(), 
                      PdfColors.green
                    ),
                    _buildPdfStat('En service', 
                      _todayAttendances.where((a) => a.checkOut == null).length.toString(), 
                      PdfColors.blue
                    ),
                    _buildPdfStat('Absents', 
                      (_staffList.length - _todayAttendances.length).toString(), 
                      PdfColors.red
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Liste du personnel
              pw.Text(
                'LISTE DU PERSONNEL',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 8),
              
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 1),
                columnWidths: {
                  0: const pw.FixedColumnWidth(40),
                  1: const pw.FixedColumnWidth(120),
                  2: const pw.FixedColumnWidth(100),
                  3: const pw.FixedColumnWidth(80),
                  4: const pw.FixedColumnWidth(80),
                },
                children: [
                  // En-tête du tableau
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue100,
                    ),
                    children: [
                      _buildPdfCell('N°', isHeader: true),
                      _buildPdfCell('Nom', isHeader: true),
                      _buildPdfCell('Poste', isHeader: true),
                      _buildPdfCell('Check-in', isHeader: true),
                      _buildPdfCell('Statut', isHeader: true),
                    ],
                  ),
                  // Lignes
                  ..._staffList.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final staff = entry.value;
                    final attendance = _todayAttendances.firstWhere(
                      (a) => a.staffId == staff.firestoreId,
                      orElse: () => StaffAttendanceModel(
                        id: '',
                        staffId: staff.firestoreId!,
                        staffName: staff.fullName,
                        position: staff.position,
                        schoolId: staff.schoolId!,
                        date: DateTime.now(),
                        checkIn: DateTime.now(),
                        status: 'absent',
                      ),
                    );
                    final isPresent = attendance.status == 'present';
                    final checkInTime = isPresent 
                        ? '${attendance.checkIn.hour.toString().padLeft(2, '0')}:${attendance.checkIn.minute.toString().padLeft(2, '0')}'
                        : '-';
                    final status = isPresent ? '✅ Présent' : '❌ Absent';

                    return pw.TableRow(
                      children: [
                        _buildPdfCell(index.toString()),
                        _buildPdfCell(staff.fullName),
                        _buildPdfCell(staff.position),
                        _buildPdfCell(checkInTime),
                        _buildPdfCell(status, color: isPresent ? PdfColors.green : PdfColors.red),
                      ],
                    );
                  }).toList(),
                ],
              ),

              pw.SizedBox(height: 16),

              // Pied de page
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total: ${_staffList.length} employés',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'Généré le ${_formatDate(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  pw.Widget _buildPdfStat(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfCell(String text, {bool isHeader = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? (isHeader ? PdfColors.black : PdfColors.black),
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// ✅ Partager le rapport PDF
  Future<void> _sharePDF() async {
    setState(() => _isGeneratingPDF = true);

    try {
      final pdfBytes = await _generateAttendancePDF();
      
      final tempDir = await getTemporaryDirectory();
      final fileName = 'Rapport_Presences_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '📄 Rapport de présence du personnel - ${_formatDate(DateTime.now())}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Rapport partagé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isGeneratingPDF = false);
    }
  }

  /// ✅ Imprimer le rapport
  Future<void> _printPDF() async {
    setState(() => _isGeneratingPDF = true);

    try {
      final pdfBytes = await _generateAttendancePDF();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Rapport_Presences_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur impression: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isGeneratingPDF = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Présences du personnel',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          // ✅ Bouton Rapport PDF
          IconButton(
            icon: _isGeneratingPDF 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444)),
            onPressed: _isGeneratingPDF ? null : _sharePDF,
            tooltip: 'Exporter PDF',
          ),
          IconButton(
            icon: const Icon(Icons.print, color: Color(0xFF0F766E)),
            onPressed: _isGeneratingPDF ? null : _printPDF,
            tooltip: 'Imprimer',
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF0F766E)),
            onPressed: _startQRScanner,
            tooltip: 'Scanner QR',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Bannière de scan
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF0F766E), const Color(0xFF14B8A6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Scanner la carte de service',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Utilisez la caméra pour scanner le QR code',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _startQRScanner,
                        icon: const Icon(Icons.qr_code, size: 18),
                        label: const Text('Scanner'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F766E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Statistiques
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        'Présents',
                        _todayAttendances.where((a) => a.status == 'present').length.toString(),
                        Colors.green,
                        Icons.check_circle,
                      ),
                      _buildStatCard(
                        'En service',
                        _todayAttendances.where((a) => a.checkOut == null).length.toString(),
                        Colors.blue,
                        Icons.timelapse,
                      ),
                      _buildStatCard(
                        'Total',
                        _staffList.length.toString(),
                        Colors.purple,
                        Icons.people,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Liste du personnel
                Expanded(
                  child: _staffList.isEmpty
                      ? const Center(
                          child: Text('Aucun personnel actif'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _staffList.length,
                          itemBuilder: (context, index) {
                            final staff = _staffList[index];
                            final isCheckedIn = _isCheckedInToday(staff.firestoreId!);
                            final hasCheckedOut = _hasCheckedOutToday(staff.firestoreId!);
                            final attendanceId = _getAttendanceId(staff.firestoreId!);
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: isCheckedIn
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isCheckedIn ? Icons.check_circle : Icons.person,
                                      color: isCheckedIn ? Colors.green : Colors.grey,
                                      size: 28,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  staff.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      staff.position,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    if (isCheckedIn) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '✅ Pointé à ${_getCheckInTime(staff.firestoreId!)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.green,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: isCheckedIn
                                    ? (hasCheckedOut
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Text(
                                              '✅ Terminé',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          )
                                        : ElevatedButton.icon(
                                            onPressed: _isCheckingIn || attendanceId == null
                                                ? null
                                                : () => _checkOut(attendanceId),
                                            icon: const Icon(Icons.exit_to_app, size: 16),
                                            label: const Text('Check-out'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          ))
                                    : ElevatedButton.icon(
                                        onPressed: _isCheckingIn
                                            ? null
                                            : () => _checkIn(staff),
                                        icon: const Icon(Icons.login, size: 16),
                                        label: const Text('Check-in'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
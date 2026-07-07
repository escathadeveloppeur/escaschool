// lib/screens/payments/receipt_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import '../../models/receipt_model.dart';

class ReceiptScreen extends StatefulWidget {
  final Map<String, dynamic> paymentData;
  final String paymentId;
  
  const ReceiptScreen({
    super.key,
    required this.paymentData,
    required this.paymentId,
  });

  @override
  _ReceiptScreenState createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  ReceiptModel? receipt;
  bool _isGenerating = true;
  bool _isSaving = false;
  Map<String, dynamic>? _schoolInfo;

  @override
  void initState() {
    super.initState();
    _generateAndSaveReceipt();
  }

  Future<void> _generateAndSaveReceipt() async {
    setState(() => _isGenerating = true);
    
    try {
      final receiptNumber = _generateReceiptNumber();
      
      // ✅ Récupérer les infos de l'école depuis la collection 'schools'
      final schoolId = widget.paymentData['schoolId'];
      Map<String, dynamic>? schoolData;
      
      if (schoolId != null && schoolId.isNotEmpty) {
        // Récupérer depuis la collection schools
        final schoolDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .get();
        
        if (schoolDoc.exists) {
          schoolData = schoolDoc.data() as Map<String, dynamic>;
          print('✅ Infos école récupérées: ${schoolData?['name']}');
        } else {
          print('⚠️ École non trouvée avec ID: $schoolId');
        }
      }
      
      // Si toujours null, utiliser les données du paiement
      if (schoolData == null) {
        schoolData = {
          'name': widget.paymentData['schoolName'] ?? 'ECOLE SCHOOL',
          'phone': widget.paymentData['schoolPhone'] ?? '',
          'email': widget.paymentData['schoolEmail'] ?? '',
          'address': widget.paymentData['schoolAddress'] ?? '',
          'type': widget.paymentData['type'] ?? '',
          'website': widget.paymentData['website'] ?? '',
          'schoolCode': widget.paymentData['schoolCode'] ?? '',
        };
      }
      
      _schoolInfo = schoolData;
      
      final receiptModel = ReceiptModel(
        receiptNumber: receiptNumber,
        paymentId: widget.paymentId,
        studentName: widget.paymentData['fullName'] ?? '',
        className: widget.paymentData['className'] ?? '',
        sectionName: widget.paymentData['sectionName'],
        feeType: widget.paymentData['feeType'] ?? '',
        period: widget.paymentData['monthName'] ?? '',
        year: widget.paymentData['year'] ?? DateTime.now().year,
        amount: widget.paymentData['amount'] ?? 0.0,
        paymentDate: DateTime.now(),
        schoolName: schoolData['name'] ?? schoolData['schoolName'] ?? 'ECOLE SCHOOL',
        schoolAddress: schoolData['address'] ?? schoolData['schoolAddress'] ?? '',
        schoolPhone: schoolData['phone'] ?? schoolData['schoolPhone'] ?? '',
        schoolEmail: schoolData['email'] ?? schoolData['schoolEmail'] ?? '',
        schoolId: widget.paymentData['schoolId'] ?? '',
        generatedAt: DateTime.now(),
      );
      
      final receiptRef = await FirebaseFirestore.instance
          .collection('receipts')
          .add(receiptModel.toFirestore());
      
      receiptModel.firestoreId = receiptRef.id;
      
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(widget.paymentId)
          .update({
            'receiptNumber': receiptNumber,
            'receiptGenerated': true,
            'receiptId': receiptRef.id,
          });
      
      setState(() {
        receipt = receiptModel;
        _isGenerating = false;
      });
    } catch (e) {
      print('❌ Erreur génération reçu: $e');
      setState(() => _isGenerating = false);
      _showSnackBar('Erreur lors de la génération du reçu', Colors.red);
    }
  }

  String _generateReceiptNumber() {
    final now = DateTime.now();
    final random = DateTime.now().millisecondsSinceEpoch % 10000;
    return 'REC-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$random';
  }

  /// 📄 Générer le PDF du reçu
  Future<Uint8List> _generateReceiptPDF() async {
    if (receipt == null) return Uint8List(0);
    
    final pdf = pw.Document();
    final date = DateTime.now();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ✅ En-tête
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.SizedBox(height: 8),
                    pw.Text(
                      '🏫 ${receipt!.schoolName.toUpperCase()}',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    // ✅ Ajouter le type d'école
                    if (_schoolInfo != null && _schoolInfo!['type'] != null)
                      pw.Text(
                        _schoolInfo!['type'],
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey600,
                        ),
                      ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'REÇU DE PAIEMENT',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                        letterSpacing: 3,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'N° ${receipt!.receiptNumber}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey700,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      width: 250,
                      height: 3,
                      decoration: pw.BoxDecoration(
                        gradient: pw.LinearGradient(
                          colors: [PdfColors.blue400, PdfColors.blue800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // ✅ Date et Heure
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '📅 Date: ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                      style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      '🕐 Heure: ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                      style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // ✅ Séparateur
              pw.Container(
                height: 1,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue200,
                ),
              ),
              
              pw.SizedBox(height: 16),
              
              // ✅ Informations École
              _buildPdfSection(
                title: 'INFORMATIONS ÉCOLE',
                emoji: '🏛️',
                children: [
                  pw.Text(
                    receipt!.schoolName,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  if (_schoolInfo != null && _schoolInfo!['type'] != null)
                    pw.Text(
                      '📚 ${_schoolInfo!['type']}',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                  pw.SizedBox(height: 4),
                  if (receipt!.schoolAddress != null && receipt!.schoolAddress!.isNotEmpty)
                    pw.Text(
                      '📍 ${receipt!.schoolAddress!}',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                  if (receipt!.schoolPhone != null && receipt!.schoolPhone!.isNotEmpty)
                    pw.Text(
                      '📞 ${receipt!.schoolPhone!}',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                  if (receipt!.schoolEmail != null && receipt!.schoolEmail!.isNotEmpty)
                    pw.Text(
                      '✉️ ${receipt!.schoolEmail!}',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                  if (_schoolInfo != null && _schoolInfo!['website'] != null)
                    pw.Text(
                      '🌐 ${_schoolInfo!['website']}',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                  if (_schoolInfo != null && _schoolInfo!['schoolCode'] != null)
                    pw.Text(
                      '📋 Code: ${_schoolInfo!['schoolCode']}',
                      style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                ],
              ),
              
              pw.SizedBox(height: 12),
              
              // ✅ Informations Élève
              _buildPdfSection(
                title: 'INFORMATIONS ÉLÈVE',
                emoji: '👤',
                children: [
                  _buildPdfRow('👨‍🎓 Nom', receipt!.studentName),
                  _buildPdfRow('📚 Classe', receipt!.className),
                  if (receipt!.sectionName != null && receipt!.sectionName!.isNotEmpty)
                    _buildPdfRow('📖 Section', receipt!.sectionName!),
                ],
              ),
              
              pw.SizedBox(height: 12),
              
              // ✅ Détails Paiement
              _buildPdfSection(
                title: 'DÉTAILS PAIEMENT',
                emoji: '💳',
                children: [
                  _buildPdfRow('📌 Type', receipt!.feeType),
                  _buildPdfRow('📅 Période', '${receipt!.period} ${receipt!.year}'),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(
                        color: PdfColors.green300,
                        width: 1,
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '💰 Montant total',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800,
                          ),
                        ),
                        pw.Text(
                          '${receipt!.amount.toStringAsFixed(0)} USD',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              pw.SizedBox(height: 16),
              
              // ✅ Statut
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(
                    color: PdfColors.green400,
                    width: 1.5,
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      '✅',
                      style: pw.TextStyle(fontSize: 20),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      'PAIEMENT CONFIRMÉ',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 16),
              
              // ✅ Séparateur
              pw.Container(
                height: 1,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue200,
                ),
              ),
              
              pw.SizedBox(height: 12),
              
              // ✅ Pied de page
              pw.Center(
                child: pw.Text(
                  'Merci pour votre confiance 🙏',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.blue700,
                    fontWeight: pw.FontWeight.normal,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
              
              pw.SizedBox(height: 4),
              
              pw.Center(
                child: pw.Text(
                  'Ce reçu est généré automatiquement et fait foi',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
              
              pw.SizedBox(height: 4),
              
              pw.Center(
                child: pw.Text(
                  'ID Transaction: ${receipt!.receiptNumber}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey400,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    
    return await pdf.save();
  }

  pw.Widget _buildPdfSection({
    required String title,
    required String emoji,
    required List<pw.Widget> children,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Text(
              emoji,
              style: pw.TextStyle(fontSize: 16),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(
              color: PdfColors.grey200,
              width: 1,
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.grey600,
                fontWeight: pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            ':',
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey400,
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.normal,
                color: PdfColors.grey900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 📤 Partager le reçu en PDF
  Future<void> _shareReceiptPDF() async {
    if (receipt == null) return;
    
    setState(() => _isSaving = true);
    
    try {
      final pdfBytes = await _generateReceiptPDF();
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/recu_${receipt!.receiptNumber}.pdf');
      await file.writeAsBytes(pdfBytes);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '📄 Reçu de paiement - ${receipt!.receiptNumber}',
      );
      
      _showSnackBar('Reçu partagé avec succès', Colors.green);
    } catch (e) {
      print('❌ Erreur partage: $e');
      _showSnackBar('Erreur lors du partage', Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// 📄 Imprimer le reçu
  Future<void> _printReceipt() async {
    if (receipt == null) return;
    
    try {
      final pdfBytes = await _generateReceiptPDF();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Reçu_${receipt!.receiptNumber}',
      );
      _showSnackBar('Impression lancée', Colors.green);
    } catch (e) {
      print('❌ Erreur impression: $e');
      _showSnackBar('Erreur lors de l\'impression', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Reçu de paiement',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          if (receipt != null) ...[
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: _isSaving ? null : _shareReceiptPDF,
              tooltip: 'Partager',
            ),
            IconButton(
              icon: const Icon(Icons.print_rounded),
              onPressed: _printReceipt,
              tooltip: 'Imprimer',
            ),
          ],
        ],
      ),
      body: _isGenerating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                  SizedBox(height: 16),
                  Text('Génération du reçu...'),
                ],
              ),
            )
          : receipt == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur lors de la génération',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _generateAndSaveReceipt,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                        ),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Carte du reçu
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // En-tête
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1E3A8A), Color(0xFF3B5BDB)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.receipt_long_rounded,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'REÇU DE PAIEMENT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'N° ${receipt!.receiptNumber}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Corps du reçu
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  // Date
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today,
                                          size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Date: ${receipt!.generatedAt!.day}/${receipt!.generatedAt!.month}/${receipt!.generatedAt!.year}',
                                        style: const TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                  
                                  const Divider(height: 24),
                                  
                                  // École
                                  _buildInfoSection(
                                    icon: Icons.business_rounded,
                                    title: 'ÉCOLE',
                                    children: [
                                      Text(
                                        receipt!.schoolName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (_schoolInfo != null && _schoolInfo!['type'] != null)
                                        Text(
                                          _schoolInfo!['type'],
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                      if (receipt!.schoolAddress != null && receipt!.schoolAddress!.isNotEmpty)
                                        Text(
                                          '📍 ${receipt!.schoolAddress!}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      if (receipt!.schoolPhone != null && receipt!.schoolPhone!.isNotEmpty)
                                        Text(
                                          '📞 ${receipt!.schoolPhone!}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      if (receipt!.schoolEmail != null && receipt!.schoolEmail!.isNotEmpty)
                                        Text(
                                          '✉️ ${receipt!.schoolEmail!}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      if (_schoolInfo != null && _schoolInfo!['website'] != null)
                                        Text(
                                          '🌐 ${_schoolInfo!['website']}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      if (_schoolInfo != null && _schoolInfo!['schoolCode'] != null)
                                        Text(
                                          '📋 Code: ${_schoolInfo!['schoolCode']}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Élève
                                  _buildInfoSection(
                                    icon: Icons.person_rounded,
                                    title: 'ÉLÈVE',
                                    children: [
                                      Text(
                                        receipt!.studentName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        'Classe: ${receipt!.className}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      if (receipt!.sectionName != null)
                                        Text(
                                          'Section: ${receipt!.sectionName}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Paiement
                                  _buildInfoSection(
                                    icon: Icons.payment_rounded,
                                    title: 'DÉTAILS PAIEMENT',
                                    children: [
                                      _buildDetailRow(
                                        'Type:',
                                        receipt!.feeType,
                                      ),
                                      _buildDetailRow(
                                        'Période:',
                                        '${receipt!.period} ${receipt!.year}',
                                      ),
                                      _buildDetailRow(
                                        'Montant:',
                                        '${receipt!.amount.toStringAsFixed(0)} USD',
                                        isAmount: true,
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Statut
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF10B981),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Paiement confirmé',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Reçu valide',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
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
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Boutons d'action
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Fermer'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _shareReceiptPDF,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.share_rounded),
                              label: Text(_isSaving ? 'Partage...' : 'Partager'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B82F6),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isAmount ? FontWeight.bold : FontWeight.normal,
              color: isAmount ? const Color(0xFF10B981) : null,
            ),
          ),
        ],
      ),
    );
  }
}
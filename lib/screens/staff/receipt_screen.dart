// lib/screens/payments/receipt_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _generateAndSaveReceipt();
  }

  Future<void> _generateAndSaveReceipt() async {
    setState(() => _isGenerating = true);
    
    try {
      // Générer un numéro de reçu unique
      final receiptNumber = _generateReceiptNumber();
      
      // Récupérer les infos de l'école
      final schoolDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('school_info')
          .get();
      
      final schoolData = schoolDoc.data();
      
      // Créer le modèle de reçu
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
        schoolName: schoolData?['name'] ?? 'ECOLE SCHOOL',
        schoolAddress: schoolData?['address'],
        schoolPhone: schoolData?['phone'],
        schoolEmail: schoolData?['email'],
        schoolId: widget.paymentData['schoolId'] ?? '',
        generatedAt: DateTime.now(),
      );
      
      // Sauvegarder dans Firestore
      final receiptRef = await FirebaseFirestore.instance
          .collection('receipts')
          .add(receiptModel.toFirestore());
      
      receiptModel.firestoreId = receiptRef.id;
      
      // Mettre à jour le paiement avec le numéro de reçu
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

  Future<void> _shareReceipt() async {
    if (receipt == null) return;
    
    setState(() => _isSaving = true);
    
    try {
      // Générer le texte du reçu
      final receiptText = _generateReceiptText();
      
      // Sauvegarder temporairement
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/recu_${receipt!.receiptNumber}.txt');
      await file.writeAsString(receiptText);
      
      // Partager
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Reçu de paiement - ${receipt!.receiptNumber}',
      );
      
      _showSnackBar('Reçu partagé avec succès', Colors.green);
    } catch (e) {
      print('❌ Erreur partage: $e');
      _showSnackBar('Erreur lors du partage', Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  String _generateReceiptText() {
    if (receipt == null) return '';
    
    final date = DateTime.now();
    
    return '''
═══════════════════════════════════════
            REÇU DE PAIEMENT
═══════════════════════════════════════

N° Reçu: ${receipt!.receiptNumber}
Date: ${date.day}/${date.month}/${date.year}
Heure: ${date.hour}:${date.minute.toString().padLeft(2, '0')}

───────────────────────────────────────
          INFORMATIONS ÉCOLE
───────────────────────────────────────
${receipt!.schoolName}
${receipt!.schoolAddress ?? ''}
Tel: ${receipt!.schoolPhone ?? '-'}
Email: ${receipt!.schoolEmail ?? '-'}

───────────────────────────────────────
          INFORMATIONS ÉLÈVE
───────────────────────────────────────
Nom: ${receipt!.studentName}
Classe: ${receipt!.className}
${receipt!.sectionName != null ? 'Section: ${receipt!.sectionName}' : ''}

───────────────────────────────────────
          DÉTAILS PAIEMENT
───────────────────────────────────────
Type: ${receipt!.feeType}
Période: ${receipt!.period} ${receipt!.year}
Montant: ${receipt!.amount.toStringAsFixed(0)} FCFA

───────────────────────────────────────
          STATUT
───────────────────────────────────────
✓ Paiement confirmé
✓ Reçu généré le ${date.day}/${date.month}/${date.year}

═══════════════════════════════════════
     Merci pour votre confiance
═══════════════════════════════════════
''';
  }

  Future<void> _printReceipt() async {
    // Pour l'impression, vous pouvez utiliser printing package
    _showSnackBar('Impression en développement...', Colors.orange);
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
              onPressed: _isSaving ? null : _shareReceipt,
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
                                      if (receipt!.schoolAddress != null)
                                        Text(
                                          receipt!.schoolAddress!,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      if (receipt!.schoolPhone != null)
                                        Text(
                                          'Tel: ${receipt!.schoolPhone}',
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
                                        '${receipt!.amount.toStringAsFixed(0)} FCFA',
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
                              onPressed: _isSaving ? null : _shareReceipt,
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
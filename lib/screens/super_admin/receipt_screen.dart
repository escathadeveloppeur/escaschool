// lib/screens/payments/receipt_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
  Map<String, dynamic>? _receiptData;
  bool _isGenerating = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _generateReceipt();
  }

  Future<void> _generateReceipt() async {
    setState(() => _isGenerating = true);
    
    try {
      // Récupérer les données du paiement
      final paymentDoc = await FirebaseFirestore.instance
          .collection('payments')
          .doc(widget.paymentId)
          .get();
      
      if (!paymentDoc.exists) {
        throw Exception('Paiement non trouvé');
      }
      
      final data = paymentDoc.data()!;
      final receiptNumber = data['receiptNumber'] ?? _generateReceiptNumber();
      
      // Récupérer les infos de l'école
      final schoolId = data['schoolId'];
      DocumentSnapshot schoolDoc;
      
      if (schoolId != null && schoolId.isNotEmpty) {
        schoolDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .get();
      } else {
        schoolDoc = await FirebaseFirestore.instance
            .collection('settings')
            .doc('school_info')
            .get();
      }
      
      final schoolData = schoolDoc.data() as Map<String, dynamic>?;
      
      // Préparer les données du reçu
      final currency = data['currency'] ?? 'FCFA';
      final currencySymbol = _getCurrencySymbol(currency);
      
      _receiptData = {
        'receiptNumber': receiptNumber,
        'paymentId': widget.paymentId,
        'schoolName': schoolData?['name'] ?? data['schoolName'] ?? 'ÉCOLE SCHOOL',
        'schoolAddress': schoolData?['address'] ?? '',
        'schoolPhone': schoolData?['phone'] ?? '',
        'schoolEmail': schoolData?['email'] ?? '',
        'studentName': data['studentName'] ?? data['fullName'] ?? data['schoolName'] ?? 'Paiement école',
        'className': data['className'] ?? 'Paiement école',
        'sectionName': data['sectionName'],
        'feeType': data['feeType'] ?? 'Minervale',
        'period': data['monthName'] ?? data['month'] ?? '',
        'year': data['year'] ?? DateTime.now().year,
        'amount': data['amount'] ?? 0.0,
        'currency': currency,
        'currencySymbol': currencySymbol,
        'paymentDate': data['paymentDate'] != null 
            ? _parseDate(data['paymentDate'])
            : DateTime.now(),
        'paymentMethod': data['paymentMethod'] ?? 'Espèces',
        'schoolId': schoolId,
        'generatedAt': DateTime.now(),
      };
      
      setState(() {
        _isGenerating = false;
      });
    } catch (e) {
      print('❌ Erreur génération reçu: $e');
      setState(() => _isGenerating = false);
      _showSnackBar('Erreur lors de la génération du reçu', Colors.red);
    }
  }

  String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'FCFA': return 'FCFA';
      case 'USD': return '\$';
      case 'EUR': return '€';
      default: return currency;
    }
  }

  DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is Timestamp) return dateValue.toDate();
    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        return DateTime.now();
      }
    }
    if (dateValue is DateTime) return dateValue;
    return DateTime.now();
  }

  String _generateReceiptNumber() {
    final now = DateTime.now();
    final random = DateTime.now().millisecondsSinceEpoch % 10000;
    return 'REC-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$random';
  }

  Future<void> _shareReceipt() async {
    if (_receiptData == null) return;
    
    setState(() => _isSaving = true);
    
    try {
      final receiptText = _generateReceiptText();
      
      final tempDir = await getTemporaryDirectory();
      final fileName = 'recu_${_receiptData!['receiptNumber']}.txt';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(receiptText);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Reçu de paiement - ${_receiptData!['receiptNumber']}',
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
    if (_receiptData == null) return '';
    
    final data = _receiptData!;
    final date = DateTime.now();
    final currencySymbol = data['currencySymbol'] ?? 'FCFA';
    final amount = data['amount'] ?? 0.0;
    
    return '''
═══════════════════════════════════════════════════
            REÇU DE PAIEMENT
═══════════════════════════════════════════════════

N° Reçu: ${data['receiptNumber']}
Date: ${date.day}/${date.month}/${date.year}
Heure: ${date.hour}:${date.minute.toString().padLeft(2, '0')}

───────────────────────────────────────────────────
          INFORMATIONS ÉCOLE
───────────────────────────────────────────────────
${data['schoolName']}
${data['schoolAddress'] ?? ''}
Tel: ${data['schoolPhone'] ?? '-'}
Email: ${data['schoolEmail'] ?? '-'}

───────────────────────────────────────────────────
          INFORMATIONS PAYEUR
───────────────────────────────────────────────────
Nom: ${data['studentName']}
${data['className'] != 'Paiement école' ? 'Classe: ${data['className']}' : ''}
${data['sectionName'] != null ? 'Section: ${data['sectionName']}' : ''}

───────────────────────────────────────────────────
          DÉTAILS PAIEMENT
───────────────────────────────────────────────────
Type: ${data['feeType']}
Période: ${data['period']} ${data['year']}
Montant: ${amount.toStringAsFixed(0)} $currencySymbol
Mode: ${data['paymentMethod']}

───────────────────────────────────────────────────
          STATUT
───────────────────────────────────────────────────
✓ Paiement confirmé
✓ Reçu généré le ${date.day}/${date.month}/${date.year}

═══════════════════════════════════════════════════
     Merci pour votre confiance
═══════════════════════════════════════════════════
''';
  }

  Future<void> _copyToClipboard() async {
    if (_receiptData == null) return;
    
    final receiptText = _generateReceiptText();
    await Clipboard.setData(ClipboardData(text: receiptText));
    _showSnackBar('Reçu copié dans le presse-papier', Colors.green);
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
          if (_receiptData != null) ...[
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              onPressed: _copyToClipboard,
              tooltip: 'Copier',
            ),
            IconButton(
              icon: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.share_rounded),
              onPressed: _isSaving ? null : _shareReceipt,
              tooltip: 'Partager',
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
          : _receiptData == null
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
                        onPressed: _generateReceipt,
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
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF1E3A8A), Color(0xFF3B5BDB)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.only(
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
                                      'N° ${_receiptData!['receiptNumber']}',
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
                                        'Date: ${DateFormat('dd/MM/yyyy à HH:mm').format(_receiptData!['generatedAt'] as DateTime)}',
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
                                        _receiptData!['schoolName'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (_receiptData!['schoolAddress'] != null && _receiptData!['schoolAddress'].toString().isNotEmpty)
                                        Text(
                                          _receiptData!['schoolAddress'],
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      if (_receiptData!['schoolPhone'] != null && _receiptData!['schoolPhone'].toString().isNotEmpty)
                                        Text(
                                          'Tel: ${_receiptData!['schoolPhone']}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Payeur
                                  _buildInfoSection(
                                    icon: Icons.person_rounded,
                                    title: 'PAYEUR',
                                    children: [
                                      Text(
                                        _receiptData!['studentName'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (_receiptData!['className'] != 'Paiement école')
                                        Text(
                                          'Classe: ${_receiptData!['className']}',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      if (_receiptData!['sectionName'] != null && _receiptData!['sectionName'].toString().isNotEmpty)
                                        Text(
                                          'Section: ${_receiptData!['sectionName']}',
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
                                        _receiptData!['feeType'],
                                      ),
                                      _buildDetailRow(
                                        'Période:',
                                        '${_receiptData!['period']} ${_receiptData!['year']}',
                                      ),
                                      _buildDetailRow(
                                        'Montant:',
                                        '${(_receiptData!['amount'] as double).toStringAsFixed(0)} ${_receiptData!['currencySymbol']}',
                                        isAmount: true,
                                      ),
                                      _buildDetailRow(
                                        'Mode:',
                                        _receiptData!['paymentMethod'],
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
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: Color(0xFF10B981),
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Paiement confirmé',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                        Spacer(),
                                        Text(
                                          'Reçu valide',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
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
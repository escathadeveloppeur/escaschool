// lib/screens/staff/staff_pay_slip_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class StaffPaySlipScreen extends StatelessWidget {
  final Map<String, dynamic> paymentData;

  const StaffPaySlipScreen({super.key, required this.paymentData});

  String _generatePayslipNumber() {
    final now = DateTime.now();
    final random = now.millisecondsSinceEpoch % 10000;
    return 'BUL-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$random';
  }

  String _generatePayslipText() {
    final date = DateTime.now();
    final payslipNumber = _generatePayslipNumber();
    final staffName = paymentData['staffName'] ?? '';
    final position = paymentData['position'] ?? '';
    final month = paymentData['month'] ?? '';
    final year = paymentData['year'] ?? '';
    final baseSalary = paymentData['baseSalary'] ?? 0.0;
    final bonus = paymentData['bonus'] ?? 0.0;
    final deduction = paymentData['deduction'] ?? 0.0;
    final netSalary = paymentData['netSalary'] ?? 0.0;
    final paymentMethod = paymentData['paymentMethod'] ?? '';
    final paymentDate = paymentData['paymentDate'] != null
        ? DateFormat('dd/MM/yyyy').format(paymentData['paymentDate'])
        : DateFormat('dd/MM/yyyy').format(DateTime.now());

    return '''
═══════════════════════════════════════════════════
                  BULLETIN DE PAIE
═══════════════════════════════════════════════════

N° Bulletin: $payslipNumber
Date d'édition: ${date.day}/${date.month}/${date.year}

───────────────────────────────────────────────────
                  INFORMATIONS EMPLOYÉ
───────────────────────────────────────────────────
Nom complet: $staffName
Poste: $position
Période: $month $year

───────────────────────────────────────────────────
                  DÉTAILS DU SALAIRE
───────────────────────────────────────────────────
Salaire de base:     ${baseSalary.toStringAsFixed(0)} FCFA
Prime:              + ${bonus.toStringAsFixed(0)} FCFA
Déduction:          - ${deduction.toStringAsFixed(0)} FCFA
───────────────────────────────────────────────────
NET À PAYER:        ${netSalary.toStringAsFixed(0)} FCFA
───────────────────────────────────────────────────

Mode de paiement: $paymentMethod
Date de paiement: $paymentDate

───────────────────────────────────────────────────
                      STATUT
───────────────────────────────────────────────────
✓ Paiement confirmé
✓ Bulletin généré le ${date.day}/${date.month}/${date.year}

═══════════════════════════════════════════════════
          Merci pour votre confiance
═══════════════════════════════════════════════════
''';
  }

  Future<void> _sharePayslip() async {
    try {
      final payslipText = _generatePayslipText();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/bulletin_${paymentData['staffName']}_${paymentData['month']}_${paymentData['year']}.txt');
      await file.writeAsString(payslipText);
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Bulletin de paie - ${paymentData['staffName']} - ${paymentData['month']} ${paymentData['year']}',
      );
    } catch (e) {
      print('❌ Erreur partage: $e');
    }
  }

  void _copyToClipboard(BuildContext context) {
    final payslipText = _generatePayslipText();
    Clipboard.setData(ClipboardData(text: payslipText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bulletin copié dans le presse-papier'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staffName = paymentData['staffName'] ?? '';
    final month = paymentData['month'] ?? '';
    final year = paymentData['year'] ?? '';
    final baseSalary = paymentData['baseSalary'] ?? 0.0;
    final bonus = paymentData['bonus'] ?? 0.0;
    final deduction = paymentData['deduction'] ?? 0.0;
    final netSalary = paymentData['netSalary'] ?? 0.0;
    final paymentMethod = paymentData['paymentMethod'] ?? '';
    final payslipNumber = _generatePayslipNumber();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Bulletin de paie', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            onPressed: () => _copyToClipboard(context),
            tooltip: 'Copier',
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _sharePayslip,
            tooltip: 'Partager',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Carte du bulletin
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
                        const Icon(Icons.receipt_long_rounded, size: 48, color: Colors.white),
                        const SizedBox(height: 12),
                        const Text(
                          'BULLETIN DE PAIE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'N° $payslipNumber',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Corps
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Date
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              'Émis le: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        
                        // Employé
                        _buildInfoSection(
                          icon: Icons.person_rounded,
                          title: 'EMPLOYÉ',
                          children: [
                            Text(staffName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(paymentData['position'] ?? ''),
                            const SizedBox(height: 4),
                            Text('$month $year', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Salaire
                        _buildInfoSection(
                          icon: Icons.payment_rounded,
                          title: 'DÉTAILS DU SALAIRE',
                          children: [
                            _buildDetailRow('Salaire de base:', '${baseSalary.toStringAsFixed(0)} FCFA'),
                            _buildDetailRow('Prime:', '+ ${bonus.toStringAsFixed(0)} FCFA', color: const Color(0xFF10B981)),
                            _buildDetailRow('Déduction:', '- ${deduction.toStringAsFixed(0)} FCFA', color: const Color(0xFFEF4444)),
                            const Divider(height: 16),
                            _buildDetailRow('NET À PAYER:', '${netSalary.toStringAsFixed(0)} FCFA', isTotal: true),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Paiement
                        _buildInfoSection(
                          icon: Icons.credit_card_rounded,
                          title: 'PAIEMENT',
                          children: [
                            _buildDetailRow('Mode:', paymentMethod),
                            _buildDetailRow('Date:', DateFormat('dd/MM/yyyy').format(paymentData['paymentDate'] ?? DateTime.now())),
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
                              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Paiement confirmé - Bulletin valide',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
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
            
            // Boutons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Fermer'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sharePayslip,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Partager'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildDetailRow(String label, String value, {Color? color, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.grey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: color ?? (isTotal ? const Color(0xFF10B981) : null),
            ),
          ),
        ],
      ),
    );
  }
}
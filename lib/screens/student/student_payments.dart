// lib/screens/student/student_payments.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';

class StudentPaymentsScreen extends StatefulWidget {
  const StudentPaymentsScreen({super.key});

  @override
  _StudentPaymentsScreenState createState() => _StudentPaymentsScreenState();
}

class _StudentPaymentsScreenState extends State<StudentPaymentsScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> payments = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  String? _studentId;
  String? _studentName;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadDataFromFirestore();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les données depuis Firestore
  Future<void> _loadDataFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id;
      final userEmail = authProvider.user?.email;
      
      if (userId != null || userEmail != null) {
        // Récupérer l'étudiant via son compte utilisateur
        Query studentQuery = FirebaseFirestore.instance.collection('students');
        
        if (userEmail != null) {
          studentQuery = studentQuery.where('userEmail', isEqualTo: userEmail);
        } else {
          studentQuery = studentQuery.where('userId', isEqualTo: userId);
        }
        
        final studentSnapshot = await studentQuery.limit(1).get();
        
        if (studentSnapshot.docs.isNotEmpty) {
          final studentData = studentSnapshot.docs.first.data() as Map<String, dynamic>;
          _studentId = studentSnapshot.docs.first.id;
          _studentName = studentData['fullName'];
          
          print('✅ Étudiant trouvé: $_studentName');
          
          // Charger les paiements pour cet étudiant
          final paymentsSnapshot = await FirebaseFirestore.instance
              .collection('payments')
              .where('fullName', isEqualTo: _studentName)
              .get();
          
          payments = [];
          for (var doc in paymentsSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            payments.add({
              'id': doc.id,
              'fullName': data['fullName'] ?? '',
              'className': data['className'] ?? '',
              'month': data['month'] ?? 0,
              'monthName': data['monthName'] ?? '',
              'year': data['year'] ?? 0,
              'feeType': data['feeType'] ?? '',
              'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
              'paymentDate': data['paymentDate'] != null 
                  ? (data['paymentDate'] as Timestamp).toDate().toIso8601String()
                  : '',
              'status': data['status'] ?? 'pending',
            });
          }
          
          // Trier par date (plus récent en premier)
          payments.sort((a, b) {
            final dateA = a['paymentDate'] as String;
            final dateB = b['paymentDate'] as String;
            if (dateA.isEmpty && dateB.isEmpty) return 0;
            if (dateA.isEmpty) return 1;
            if (dateB.isEmpty) return -1;
            return dateB.compareTo(dateA);
          });
          
          print('✅ ${payments.length} paiements chargés');
        } else {
          print('⚠️ Aucun étudiant trouvé');
          payments = [];
        }
      }
      
      _animationController.forward(from: 0);
    } catch (e) {
      print('❌ Erreur chargement: $e');
      _showSnackBar('Erreur de chargement: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
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

  double _getTotalPaid() {
    return payments
        .where((p) => (p['paymentDate'] as String).isNotEmpty)
        .fold(0.0, (sum, p) => sum + (p['amount'] as double));
  }

  double _getTotalPending() {
    return payments
        .where((p) => (p['paymentDate'] as String).isEmpty)
        .fold(0.0, (sum, p) => sum + (p['amount'] as double));
  }

  int _getPaidCount() {
    return payments.where((p) => (p['paymentDate'] as String).isNotEmpty).length;
  }

  int _getPendingCount() {
    return payments.where((p) => (p['paymentDate'] as String).isEmpty).length;
  }

  String _getMonthName(int month) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[month - 1];
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'Non payé';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))),
            SizedBox(height: 16),
            Text('Chargement des paiements...'),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Mes paiements',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDataFromFirestore,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF3B82F6)),
                    ),
                  ],
                ),
              ),

            // Cartes de résumé
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total payé',
                    '${_getTotalPaid().toStringAsFixed(0)} FCFA',
                    '${_getPaidCount()} paiement(s)',
                    Icons.payment,
                    const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'En attente',
                    '${_getTotalPending().toStringAsFixed(0)} FCFA',
                    '${_getPendingCount()} paiement(s)',
                    Icons.pending,
                    const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Statistiques
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payment, size: 16, color: Color(0xFF3B82F6)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${payments.length} paiement(s) total',
                    style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            
            // Liste des paiements
            if (payments.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.payment, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun paiement enregistré',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Les paiements seront affichés ici',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
              )
            else
              ...payments.map((payment) {
                final isPaid = (payment['paymentDate'] as String).isNotEmpty;
                final monthName = payment['monthName'] as String? ?? _getMonthName(payment['month']);
                
                return FadeTransition(
                  opacity: _animationController,
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isPaid
                                ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Icon(
                            isPaid ? Icons.check : Icons.pending,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      title: Text(
                        '$monthName ${payment['year']}',
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
                            payment['feeType'],
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(payment['amount'] as double).toStringAsFixed(0)} FCFA',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? const Color(0xFF10B981).withOpacity(0.1)
                                  : const Color(0xFFF59E0B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isPaid ? 'Payé' : 'En attente',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                          if (isPaid)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _formatDate(payment['paymentDate']),
                                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                              ),
                            ),
                        ],
                      ),
                      onTap: () => _showPaymentDetails(payment),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String amount, String subtitle, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              amount,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDetails(Map<String, dynamic> payment) {
    final isPaid = (payment['paymentDate'] as String).isNotEmpty;
    final monthName = payment['monthName'] as String? ?? _getMonthName(payment['month']);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPaid
                    ? const Color(0xFF10B981).withOpacity(0.1)
                    : const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPaid ? Icons.check_circle : Icons.pending,
                color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Détails du paiement',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Période', '$monthName ${payment['year']}'),
              const SizedBox(height: 8),
              _buildDetailRow('Type', payment['feeType']),
              const SizedBox(height: 8),
              _buildDetailRow('Montant', '${(payment['amount'] as double).toStringAsFixed(0)} FCFA'),
              const SizedBox(height: 8),
              _buildDetailRow('Statut', isPaid ? 'Payé' : 'En attente',
                  valueColor: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
              if (isPaid) ...[
                const SizedBox(height: 8),
                _buildDetailRow('Date de paiement', _formatDate(payment['paymentDate'])),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
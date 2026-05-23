// lib/screens/staff/staff_payments_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import 'add_staff_payment_screen.dart';

class StaffPaymentsScreen extends StatefulWidget {
  final Map<String, dynamic>? staff;

  const StaffPaymentsScreen({super.key, this.staff});

  @override
  _StaffPaymentsScreenState createState() => _StaffPaymentsScreenState();
}

class _StaffPaymentsScreenState extends State<StaffPaymentsScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadPaymentsFromFirestore();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les paiements depuis Firestore (sans orderBy pour éviter l'index)
  Future<void> _loadPaymentsFromFirestore() async {
    if (widget.staff == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final staffFirestoreId = widget.staff!['firestoreId'];
      if (staffFirestoreId == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      // ⚠️ Sans orderBy pour éviter l'erreur d'index
      final snapshot = await FirebaseFirestore.instance
          .collection('staff_payments')
          .where('staffFirestoreId', isEqualTo: staffFirestoreId)
          .get();
      
      _payments = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'month': data['month'] ?? '',
          'year': data['year'] ?? DateTime.now().year,
          'netSalary': (data['netSalary'] as num?)?.toDouble() ?? 0,
          'paymentMethod': data['paymentMethod'] ?? '',
          'paymentDate': data['paymentDate'] != null 
              ? (data['paymentDate'] as Timestamp).toDate().toIso8601String()
              : '',
          'bonus': (data['bonus'] as num?)?.toDouble() ?? 0,
          'deduction': (data['deduction'] as num?)?.toDouble() ?? 0,
          'baseSalary': (data['baseSalary'] as num?)?.toDouble() ?? 0,
        };
      }).toList();
      
      // Trier manuellement par date (plus récent en premier)
      _payments.sort((a, b) => b['paymentDate'].compareTo(a['paymentDate']));
      
      _animationController.forward(from: 0);
      
      print('✅ ${_payments.length} paiements chargés depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement paiements: $e');
      _showSnackBar("Erreur de chargement", const Color(0xFFEF4444));
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'Non payé';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    // Si staff est null, afficher un écran vide
    if (widget.staff == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'Paiements du personnel',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.grey[800],
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.payment, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Sélectionnez un employé pour voir ses paiements',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Paiements - ${widget.staff!['fullName']}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF10B981)),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddStaffPaymentScreen(staff: widget.staff!)),
              );
              if (result == true) await _loadPaymentsFromFirestore();
            },
            tooltip: 'Ajouter paiement',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPaymentsFromFirestore,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          // Carte d'information du personnel
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      (widget.staff!['fullName'] as String).isNotEmpty 
                          ? (widget.staff!['fullName'] as String)[0].toUpperCase() 
                          : '?',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.staff!['fullName'],
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.staff!['position'] ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        'Salaire: ${(widget.staff!['salary'] ?? 0).toStringAsFixed(0)} FCFA/mois',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Liste des paiements
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))))
                : _payments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun paiement enregistré',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AddStaffPaymentScreen(staff: widget.staff!)),
                                );
                                if (result == true) await _loadPaymentsFromFirestore();
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Ajouter un paiement'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _payments.length,
                        itemBuilder: (context, index) {
                          final payment = _payments[index];
                          return FadeTransition(
                            opacity: _animationController,
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.payment, color: Color(0xFF10B981), size: 24),
                                ),
                                title: Text(
                                  '${payment['month']} ${payment['year']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Net: ${(payment['netSalary'] as double).toStringAsFixed(0)} FCFA • ${payment['paymentMethod']}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                    ),
                                    if ((payment['bonus'] as double) > 0)
                                      Text(
                                        'Prime: +${(payment['bonus'] as double).toStringAsFixed(0)} FCFA',
                                        style: TextStyle(fontSize: 11, color: Colors.green[600]),
                                      ),
                                    if ((payment['deduction'] as double) > 0)
                                      Text(
                                        'Déduction: -${(payment['deduction'] as double).toStringAsFixed(0)} FCFA',
                                        style: TextStyle(fontSize: 11, color: Colors.red[600]),
                                      ),
                                    Text(
                                      'Date: ${_formatDate(payment['paymentDate'])}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Payé',
                                    style: TextStyle(color: Color(0xFF10B981), fontSize: 11),
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
}
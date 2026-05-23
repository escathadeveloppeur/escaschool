// lib/screens/super_admin/school_payments_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/stats_service.dart';
import '../../models/university/etablissement_model.dart';

class SchoolPaymentsScreen extends StatefulWidget {
  const SchoolPaymentsScreen({super.key});

  @override
  _SchoolPaymentsScreenState createState() => _SchoolPaymentsScreenState();
}

class _SchoolPaymentsScreenState extends State<SchoolPaymentsScreen> with SingleTickerProviderStateMixin {
  final StatsService _statsService = StatsService();
  List<EtablissementModel> _schools = [];
  List<Map<String, dynamic>> _payments = [];
  String? _selectedSchoolFirestoreId;
  bool _isLoading = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadSchoolsFromFirestore();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// 🔥 Charger les écoles depuis Firestore
  Future<void> _loadSchoolsFromFirestore() async {
    setState(() => _isLoading = true);
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('schools')
          .get();
      
      _schools = snapshot.docs.map((doc) {
        final data = doc.data();
        return EtablissementModel(
          id: data['localId'] ?? 0,
          nom: data['name'] ?? data['nom'] ?? 'Sans nom',
          type: data['type'] ?? 'École',
          adresse: data['address'] ?? data['adresse'],
          telephone: data['phone'] ?? data['telephone'],
          email: data['email'],
          siteWeb: data['website'] ?? data['siteWeb'],
          firestoreId: doc.id,
          isActive: data['isActive'] ?? true,
          schoolCode: data['schoolCode'] ?? '',
        );
      }).toList();
      
      print('✅ ${_schools.length} écoles chargées depuis Firestore');
      
      // Charger les paiements si une école est sélectionnée
      if (_selectedSchoolFirestoreId != null) {
        await _loadPaymentsFromFirestore();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Erreur chargement écoles: $e');
      setState(() => _isLoading = false);
    }
  }

  /// 🔥 Charger les paiements depuis Firestore
  Future<void> _loadPaymentsFromFirestore() async {
    if (_selectedSchoolFirestoreId == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('schoolId', isEqualTo: _selectedSchoolFirestoreId)
          .orderBy('paymentDate', descending: true)
          .get();
      
      _payments = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'month': data['month'] ?? '',
          'year': data['year'] ?? DateTime.now().year,
          'paymentMethod': data['paymentMethod'] ?? 'Espèces',
          'paymentDate': data['paymentDate'] != null 
              ? (data['paymentDate'] as Timestamp).toDate().toIso8601String()
              : DateTime.now().toIso8601String(),
          'schoolId': data['schoolId'],
          'schoolName': _schools.firstWhere(
            (s) => s.firestoreId == _selectedSchoolFirestoreId,
            orElse: () => EtablissementModel(id: 0, nom: 'École', schoolCode: ''),
          ).nom,
        };
      }).toList();
      
      print('✅ ${_payments.length} paiements chargés depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement paiements: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _recordPayment() async {
    if (_selectedSchoolFirestoreId == null) return;
    
    final amountController = TextEditingController();
    int selectedYear = DateTime.now().year;
    String selectedMonth = DateFormat('MMMM', 'fr_FR').format(DateTime.now());
    String paymentMethod = 'Espèces';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enregistrer un paiement'),
        content: SizedBox(
          width: 300,
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Montant (FCFA)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.euro),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedMonth,
                    items: const [
                      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
                      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
                    ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) {
                      setStateDialog(() {
                        selectedMonth = v!;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Mois',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedYear,
                    items: [2023, 2024, 2025, 2026].map((y) => DropdownMenuItem(value: y, child: Text(y.toString()))).toList(),
                    onChanged: (v) {
                      setStateDialog(() {
                        selectedYear = v!;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Année',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    items: const [
                      DropdownMenuItem(value: 'Espèces', child: Text('Espèces')),
                      DropdownMenuItem(value: 'Virement', child: Text('Virement')),
                      DropdownMenuItem(value: 'Mobile Money', child: Text('Mobile Money')),
                    ].toList(),
                    onChanged: (v) {
                      setStateDialog(() {
                        paymentMethod = v!;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Mode de paiement',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context, true);
                
                // 🔥 Enregistrer dans Firestore
                try {
                  await FirebaseFirestore.instance.collection('payments').add({
                    'schoolId': _selectedSchoolFirestoreId,
                    'amount': amount,
                    'month': selectedMonth,
                    'year': selectedYear,
                    'paymentMethod': paymentMethod,
                    'paymentDate': FieldValue.serverTimestamp(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  
                  await _loadPaymentsFromFirestore();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Paiement enregistré'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Montant invalide'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _getSchoolPaymentSummary() async {
    if (_selectedSchoolFirestoreId == null) return {};
    
    double totalPaid = 0;
    for (var payment in _payments) {
      totalPaid += payment['amount'] as double;
    }
    
    final school = _schools.firstWhere(
      (s) => s.firestoreId == _selectedSchoolFirestoreId,
      orElse: () => EtablissementModel(id: 0, nom: 'École', schoolCode: ''),
    );
    
    return {
      'schoolName': school.nom,
      'totalPaid': totalPaid,
      'expectedTotal': 150000, // À adapter
      'balance': 150000 - totalPaid,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Paiements écoles',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadSchoolsFromFirestore();
            },
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: Column(
        children: [
          // Sélecteur d'école
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _selectedSchoolFirestoreId,
                    hint: const Text('Sélectionner une école'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Toutes les écoles')),
                      ..._schools.map((school) => DropdownMenuItem(
                        value: school.firestoreId,
                        child: Text(school.nom),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSchoolFirestoreId = value;
                        _isLoading = true;
                      });
                      if (value != null) {
                        _loadPaymentsFromFirestore();
                      } else {
                        setState(() {
                          _payments = [];
                          _isLoading = false;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.business),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (_selectedSchoolFirestoreId != null)
                  ElevatedButton.icon(
                    onPressed: _recordPayment,
                    icon: const Icon(Icons.add),
                    label: const Text('Paiement'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            ),
          ),

          if (_selectedSchoolFirestoreId != null)
            FutureBuilder(
              future: _getSchoolPaymentSummary(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final summary = snapshot.data!;
                return Container(
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
                  child: Column(
                    children: [
                      Text(
                        summary['schoolName'] ?? 'École',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem('Payé', '${(summary['totalPaid'] ?? 0).toStringAsFixed(0)} FCFA', Icons.payment, Colors.white70),
                          _buildSummaryItem('Attendu', '${(summary['expectedTotal'] ?? 0).toStringAsFixed(0)} FCFA', Icons.trending_up, Colors.white70),
                          _buildSummaryItem(
                            'Solde',
                            '${(summary['balance'] ?? 0).toStringAsFixed(0)} FCFA',
                            Icons.account_balance,
                            (summary['balance'] ?? 0) >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
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
                                  '${(payment['amount'] as double).toStringAsFixed(0)} FCFA',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      '${payment['month']} ${payment['year']} • ${payment['paymentMethod']}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                    ),
                                    Text(
                                      DateFormat('dd/MM/yyyy').format(DateTime.parse(payment['paymentDate'])),
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

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
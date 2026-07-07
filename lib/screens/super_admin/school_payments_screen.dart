// lib/screens/super_admin/school_payments_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/stats_service.dart';
import '../../models/university/etablissement_model.dart';
import 'receipt_screen.dart'; // ✅ Importer l'écran de reçu

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

  /// 🔥 Fonction utilitaire pour convertir les dates
  DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is Timestamp) return dateValue.toDate();
    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        print('⚠️ Erreur parsing date: $dateValue');
        return DateTime.now();
      }
    }
    if (dateValue is DateTime) return dateValue;
    return DateTime.now();
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
        final paymentDate = _parseDate(data['paymentDate']);
        
        return {
          'id': doc.id,
          'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'currency': data['currency'] ?? 'USD', // ✅ Support de la devise
          'month': data['month'] ?? '',
          'year': data['year'] ?? DateTime.now().year,
          'paymentMethod': data['paymentMethod'] ?? 'Espèces',
          'paymentDate': paymentDate.toIso8601String(),
          'schoolId': data['schoolId'],
          'schoolName': _schools.firstWhere(
            (s) => s.firestoreId == _selectedSchoolFirestoreId,
            orElse: () => EtablissementModel(id: 0, nom: 'École', schoolCode: ''),
          ).nom,
          'feeType': data['feeType'] ?? 'Minervale',
          'receiptNumber': data['receiptNumber'],
          'receiptId': data['receiptId'],
        };
      }).toList();
      
      print('✅ ${_payments.length} paiements chargés depuis Firestore');
    } catch (e) {
      print('❌ Erreur chargement paiements: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 🔥 Générer un numéro de reçu unique
  String _generateReceiptNumber() {
    final now = DateTime.now();
    final random = DateTime.now().millisecondsSinceEpoch % 10000;
    return 'REC-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$random';
  }

  /// 🔥 Afficher le dialogue d'ajout de paiement
  Future<void> _showAddPaymentDialog() async {
    if (_selectedSchoolFirestoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord sélectionner une école'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    final amountController = TextEditingController();
    int selectedYear = DateTime.now().year;
    
    const List<String> months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    String selectedMonth = months[DateTime.now().month - 1];
    
    String paymentMethod = 'Espèces';
    String feeType = 'Minervale';
    String selectedCurrency = 'FCFA'; // ✅ Devise par défaut
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.payment_rounded, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 12),
            const Text('Enregistrer un paiement', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ Montant avec devise
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: amountController,
                          decoration: const InputDecoration(
                            labelText: 'Montant',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.euro_rounded),
                            hintText: 'Ex: 50000',
                          ),
                          keyboardType: TextInputType.number,
                          autofocus: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: selectedCurrency,
                          decoration: const InputDecoration(
                            labelText: 'Devise',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'FCFA', child: Text('FCFA')),
                            DropdownMenuItem(value: 'USD', child: Text('💵 USD')),
                            DropdownMenuItem(value: 'EUR', child: Text('💶 EUR')),
                          ],
                          onChanged: (v) {
                            setStateDialog(() {
                              selectedCurrency = v!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  DropdownButtonFormField<String>(
                    value: feeType,
                    decoration: const InputDecoration(
                      labelText: 'Type de frais',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Minervale', child: Text('Minervale')),
                      DropdownMenuItem(value: "Frais de l'État", child: Text("Frais de l'État")),
                      DropdownMenuItem(value: 'Inscription', child: Text('Inscription')),
                      DropdownMenuItem(value: 'Transport', child: Text('Transport')),
                      DropdownMenuItem(value: 'Autre', child: Text('Autre')),
                    ],
                    onChanged: (v) {
                      setStateDialog(() {
                        feeType = v!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  DropdownButtonFormField<String>(
                    value: selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Mois',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                    items: months.map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m),
                    )).toList(),
                    onChanged: (v) {
                      setStateDialog(() {
                        selectedMonth = v!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  DropdownButtonFormField<int>(
                    value: selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Année',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_view_month_rounded),
                    ),
                    items: [2023, 2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(
                      value: y,
                      child: Text(y.toString()),
                    )).toList(),
                    onChanged: (v) {
                      setStateDialog(() {
                        selectedYear = v!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Mode de paiement',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.credit_card_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Espèces', child: Text('💰 Espèces')),
                      DropdownMenuItem(value: 'Virement', child: Text('🏦 Virement')),
                      DropdownMenuItem(value: 'Mobile Money', child: Text('📱 Mobile Money')),
                      DropdownMenuItem(value: 'Chèque', child: Text('📄 Chèque')),
                    ],
                    onChanged: (v) {
                      setStateDialog(() {
                        paymentMethod = v!;
                      });
                    },
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
              if (amount != null && amount > 0) {
                Navigator.pop(context, true);
                
                try {
                  final schoolName = _schools.firstWhere(
                    (s) => s.firestoreId == _selectedSchoolFirestoreId,
                    orElse: () => EtablissementModel(id: 0, nom: 'École', schoolCode: ''),
                  ).nom;
                  
                  final receiptNumber = _generateReceiptNumber();
                  
                  // ✅ Ajouter le paiement
                  final docRef = await FirebaseFirestore.instance.collection('payments').add({
                    'schoolId': _selectedSchoolFirestoreId,
                    'schoolName': schoolName,
                    'amount': amount,
                    'currency': selectedCurrency,
                    'month': selectedMonth,
                    'year': selectedYear,
                    'feeType': feeType,
                    'paymentMethod': paymentMethod,
                    'paymentDate': FieldValue.serverTimestamp(),
                    'createdAt': FieldValue.serverTimestamp(),
                    'status': 'paid',
                    'receiptNumber': receiptNumber,
                    'receiptGenerated': false,
                  });
                  
                  await _loadPaymentsFromFirestore();
                  
                  // ✅ Demander si l'utilisateur veut générer un reçu
                  final shouldGenerateReceipt = await _showReceiptDialog();
                  
                  if (shouldGenerateReceipt && mounted) {
                    // ✅ Générer le reçu
                    final paymentData = {
                      'fullName': schoolName,
                      'className': 'Paiement école',
                      'feeType': feeType,
                      'monthName': selectedMonth,
                      'year': selectedYear,
                      'amount': amount,
                      'currency': selectedCurrency,
                      'paymentMethod': paymentMethod,
                      'schoolId': _selectedSchoolFirestoreId,
                    };
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReceiptScreen(
                          paymentData: paymentData,
                          paymentId: docRef.id,
                        ),
                      ),
                    );
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Paiement de ${amount.toStringAsFixed(0)} $selectedCurrency enregistré'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Veuillez entrer un montant valide'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('Enregistrer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Dialogue pour demander la génération du reçu
  Future<bool> _showReceiptDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 10),
            Text('Générer un reçu ?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Voulez-vous générer un reçu pour ce paiement ?\n\n'
          'Vous pourrez le partager ou l\'imprimer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non, merci'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('Générer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  /// ✅ Générer un reçu pour un paiement existant
  Future<void> _generateReceipt(Map<String, dynamic> payment) async {
    try {
      // Mettre à jour le paiement avec le numéro de reçu
      final receiptNumber = _generateReceiptNumber();
      
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(payment['id'])
          .update({
        'receiptNumber': receiptNumber,
        'receiptGenerated': true,
        'receiptGeneratedAt': FieldValue.serverTimestamp(),
      });
      
      // Préparer les données pour le reçu
      final paymentData = {
        'fullName': payment['schoolName'] ?? '',
        'className': 'Paiement école',
        'feeType': payment['feeType'] ?? 'Minervale',
        'monthName': payment['month'] ?? '',
        'year': payment['year'] ?? DateTime.now().year,
        'amount': payment['amount'] ?? 0.0,
        'currency': payment['currency'] ?? 'FCFA',
        'paymentMethod': payment['paymentMethod'] ?? 'Espèces',
        'schoolId': payment['schoolId'],
      };
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReceiptScreen(
            paymentData: paymentData,
            paymentId: payment['id'],
          ),
        ),
      );
      
      await _loadPaymentsFromFirestore();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur génération reçu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _getSchoolPaymentSummary() async {
    if (_selectedSchoolFirestoreId == null) return {};
    
    double totalPaidFCFA = 0;
    double totalPaidUSD = 0;
    double totalPaidEUR = 0;
    
    for (var payment in _payments) {
      final amount = payment['amount'] as double;
      final currency = payment['currency'] ?? 'FCFA';
      
      switch (currency) {
        case 'FCFA':
          totalPaidFCFA += amount;
          break;
        case 'USD':
          totalPaidUSD += amount;
          break;
        case 'EUR':
          totalPaidEUR += amount;
          break;
      }
    }
    
    final school = _schools.firstWhere(
      (s) => s.firestoreId == _selectedSchoolFirestoreId,
      orElse: () => EtablissementModel(id: 0, nom: 'École', schoolCode: ''),
    );
    
    return {
      'schoolName': school.nom,
      'totalPaidFCFA': totalPaidFCFA,
      'totalPaidUSD': totalPaidUSD,
      'totalPaidEUR': totalPaidEUR,
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
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _loadSchoolsFromFirestore();
            },
            tooltip: 'Actualiser',
          ),
          if (_selectedSchoolFirestoreId != null)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: _showAddPaymentDialog,
              tooltip: 'Ajouter un paiement',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
              ),
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
                      const DropdownMenuItem(value: null, child: Text('📚 Toutes les écoles')),
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
                      prefixIcon: const Icon(Icons.business_rounded),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ✅ Résumé des paiements avec devises
          if (_selectedSchoolFirestoreId != null && _payments.isNotEmpty)
            FutureBuilder(
              future: _getSchoolPaymentSummary(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final summary = snapshot.data!;
                
                List<Widget> currencyItems = [];
                
                if ((summary['totalPaidFCFA'] ?? 0) > 0) {
                  currencyItems.add(_buildCurrencyItem('FCFA', summary['totalPaidFCFA'] ?? 0, Colors.green));
                }
                if ((summary['totalPaidUSD'] ?? 0) > 0) {
                  currencyItems.add(_buildCurrencyItem('USD', summary['totalPaidUSD'] ?? 0, Colors.blue));
                }
                if ((summary['totalPaidEUR'] ?? 0) > 0) {
                  currencyItems.add(_buildCurrencyItem('EUR', summary['totalPaidEUR'] ?? 0, Colors.orange));
                }
                
                if (currencyItems.isEmpty) {
                  currencyItems.add(
                    const Text('Aucun paiement', style: TextStyle(color: Colors.white70)),
                  );
                }
                
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
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: currencyItems,
                      ),
                    ],
                  ),
                );
              },
            ),

          // Liste des paiements
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _payments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.06),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.payment_rounded, size: 56, color: const Color(0xFF10B981).withOpacity(0.4)),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Aucun paiement enregistré',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sélectionnez une école et cliquez sur +',
                              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _payments.length,
                        itemBuilder: (context, index) {
                          final payment = _payments[index];
                          final paymentDate = DateTime.parse(payment['paymentDate']);
                          final currency = payment['currency'] ?? 'FCFA';
                          final currencySymbol = currency == 'FCFA' ? 'FCFA' : currency;
                          
                          return FadeTransition(
                            opacity: _animationController,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[200]!),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.payment_rounded, color: Color(0xFF10B981), size: 24),
                                ),
                                title: Text(
                                  '${(payment['amount'] as double).toStringAsFixed(0)} $currencySymbol',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      '${payment['month']} ${payment['year']} • ${payment['paymentMethod']} • ${payment['feeType'] ?? 'Minervale'}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                    Text(
                                      DateFormat('dd/MM/yyyy à HH:mm').format(paymentDate),
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                    ),
                                    if (payment['receiptNumber'] != null)
                                      Text(
                                        'Reçu: ${payment['receiptNumber']}',
                                        style: TextStyle(fontSize: 11, color: const Color(0xFF10B981), fontFamily: 'monospace'),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // ✅ Bouton Reçu
                                    IconButton(
                                      icon: Icon(
                                        Icons.receipt_long_rounded,
                                        color: payment['receiptNumber'] != null 
                                            ? const Color(0xFF10B981) 
                                            : Colors.grey[400],
                                      ),
                                      onPressed: payment['receiptNumber'] != null
                                          ? () => _generateReceipt(payment)
                                          : null,
                                      tooltip: 'Générer le reçu',
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Payé',
                                        style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
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

  /// ✅ Widget pour afficher un élément de devise
  Widget _buildCurrencyItem(String currency, double amount, Color color) {
    final symbol = currency == 'FCFA' ? 'FCFA' : currency;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${amount.toStringAsFixed(0)} $symbol',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
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